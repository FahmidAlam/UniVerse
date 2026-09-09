
from __future__ import annotations

import io
from pathlib import Path

import openpyxl
from openpyxl.formatting.formatting import ConditionalFormattingList
from openpyxl.styles import Border, Side

TEMPLATE = Path(__file__).parent / "templates" / "CSE_Routine_TEMPLATE.xlsx"

DAYS = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
HEADER_ROW = 2
DATA_FIRST_ROW = 3
#: Bottom of the template's designed cohort block, and therefore the maximum
#: number of cohort rows a day sheet may hold (see `_cohort_capacity`). Rows
#: below the routine are erased and hidden, so nothing lives past the last
#: cohort — this is a capacity limit, not a content boundary.
DATA_LAST_ROW = 90
BREAK_COL = 7

#: Column-2 labels that mark the printed page furniture BELOW the cohort block
#: (bus timings, headcounts, teacher-on-duty). These must survive a render;
#: everything above them is cohort space and gets cleared.
_FURNITURE_LABELS = {"bus time", "student no.", "student no", "total"}
SESSION_COLS = [4, 5, 6, 8, 9, 10, 11]
GRID_COLS = [2, 3] + SESSION_COLS
_THIN = Side(style="thin", color="FF000000")
_THICK = Side(style="thick", color="FF000000")


def _data_last_row(ws) -> int:
    """Last row of the cohort block on this sheet, found rather than assumed.

    The template ships more cohort rows than we ever write, and two of them
    carry hard-coded classes left over from the workbook it was cloned from:

        Friday row 59:  ACM  Junior   ACM-1000 *** GL
        Friday row 83:  ACM  Senior   ACM-2000 *** GL

    `DATA_LAST_ROW` used to be 82, so row 59 was cleared and row 83 was not.
    Every rendered Friday therefore printed a phantom `ACM-2000 *** GL` that
    the solver knew nothing about — which double-booked room GL, because the
    solver had already given that slot to a real class.

    Deriving the boundary from the sheet means no future stray row can leak,
    whatever the template picks up.
    """
    limit = ws.max_row or DATA_FIRST_ROW
    for r in range(DATA_FIRST_ROW, limit + 1):
        for c in (1, 2):
            v = ws.cell(row=r, column=c).value
            if isinstance(v, str) and v.strip().lower() in _FURNITURE_LABELS:
                return r - 1
    return min(limit, DATA_LAST_ROW)


def cohort_groups(cohorts: list[str]) -> list[dict]:
    """Group the render order into explicit batch blocks.

    Rendering needs to know where a batch ENDS so the heavy separator lands
    there and nowhere else. Deriving that from adjacent strings at the point of
    use is fragile; deriving it once, here, makes it data:

        [{"batch": "70", "cohorts": ["70-A", "70-B"], "first": 0, "last": 1},
         {"batch": "69", "cohorts": ["69-A"],         "first": 2, "last": 2}]

    Batch identity is whatever precedes the first "-", so this works for any
    numbering the distribution happens to use. `cohorts` is already in render
    order, so groups are contiguous by construction.
    """
    groups: list[dict] = []
    for i, c in enumerate(cohorts):
        batch = c.partition("-")[0]
        if groups and groups[-1]["batch"] == batch:
            groups[-1]["cohorts"].append(c)
            groups[-1]["last"] = i
        else:
            groups.append({"batch": batch, "cohorts": [c],
                           "first": i, "last": i})
    return groups


def _batch_cell(batch: str):
    """Write numeric batches as ints (66) not floats (66.0); keep text as-is."""
    try:
        return int(batch)
    except (TypeError, ValueError):
        return batch


def render_bytes(rows: list[dict], cohorts: list[str], config: dict,
                 template_path: Path | None = None) -> bytes:
    tpl = template_path or TEMPLATE
    if not Path(tpl).exists():
        raise FileNotFoundError(
            f"Template not found at {tpl}. Run tools/make_template.py once.")
    wb = openpyxl.load_workbook(tpl)

    pcol = {int(p["idx"]): openpyxl.utils.column_index_from_string(p["col"])
            for p in config["periods"]}

    row_of = {c: DATA_FIRST_ROW + i for i, c in enumerate(cohorts)}

    by_cohort: dict[str, list[dict]] = {}
    for r in rows:
        key = f"{r['batch']}-{r['section']}" if r["section"] else str(r["batch"])
        by_cohort.setdefault(key, []).append(r)

    for day in DAYS:
        if day not in wb.sheetnames:
            continue
        ws = wb[day]

        _write_period_headers(ws, day, config)

        # The block is exactly as tall as this term's cohort list. It used to
        # be sized by scanning the template for its page furniture, which is
        # NOT in the same place on every sheet: Tuesday and Wednesday carry a
        # stray "BUS TIME" row at 59 while every other day has it at 83+. That
        # capped those two sheets at 56 cohorts and would have silently
        # dropped the rest. Capacity is now checked and reported instead.
        last_data = DATA_FIRST_ROW + len(cohorts) - 1
        capacity = _cohort_capacity(ws)
        if len(cohorts) > capacity:
            raise RuntimeError(
                f"The {day} sheet of the routine template has room for "
                f"{capacity} cohorts but this term has {len(cohorts)}. "
                f"Its page furniture starts at row {capacity + DATA_FIRST_ROW}. "
                f"Move the furniture down in the template, or reduce the "
                f"number of sections.")

        _clear_break_merges(ws, config, last_data)
        _normalize_live_formatting(ws, last_data)

        for rr in range(DATA_FIRST_ROW, last_data + 1):
            for cc in SESSION_COLS:
                _safe_clear(ws, rr, cc)

        groups = cohort_groups(cohorts)
        for rr in range(DATA_FIRST_ROW, last_data + 1):
            c = cohorts[rr - DATA_FIRST_ROW]
            batch, _, section = c.partition("-")
            ws.cell(row=rr, column=2, value=_batch_cell(batch))
            ws.cell(row=rr, column=3, value=section or None)
            ws.row_dimensions[rr].hidden = False

        _apply_cohort_borders(ws, groups, len(cohorts), last_data)

        for cohort, sess in by_cohort.items():
            rr = row_of.get(cohort)
            if rr is None:
                continue
            for s in sess:
                if s["day"] != day:
                    continue
                col = pcol.get(int(s["period"]))
                if col is None or col == BREAK_COL:
                    continue
                text = f"{s['subject_code']} {s['teacher_code']} {s['room']}"
                ws.cell(row=rr, column=col, value=text)

        if last_data >= DATA_FIRST_ROW:
            _rebuild_break_column(ws, day, last_data, last_data, config)

        _clear_below_routine(ws, last_data)

    _strip_legacy_scaffolding(wb)

    buf = io.BytesIO()
    wb.save(buf)
    return buf.getvalue()


def _normalize_live_formatting(ws, data_last: int) -> None:
    """Force every cell of the live cohort block back to plain black-on-white.

    Nothing in this engine has ever set a font or a fill — the renderer writes
    `cell.value` and nothing else. The red classes in the generated routine
    came entirely from the template: 27 cells inside the cohort grid carry an
    explicit red font (Sunday H45/F48/F58, Thursday F48/F49/F53/F59, ...) and
    three carry a green or yellow fill, all of them leftover hand annotation
    from the Summer-2025 workbook this template was cloned from. Whatever class
    the solver happened to place at those coordinates inherited the colour and
    appeared to mean something. It never did.

    Clearing `.value` does not clear formatting, so the colour has to be reset
    explicitly. Only anomalies are touched: a font keeps its name, size and
    weight and only loses a non-black colour, and a fill is reset only when it
    is neither white nor empty.
    """
    from copy import copy

    from openpyxl.cell.cell import MergedCell
    from openpyxl.styles import Font, PatternFill

    white = PatternFill(fill_type="solid", start_color="FFFFFFFF",
                        end_color="FFFFFFFF")
    for rr in range(DATA_FIRST_ROW, data_last + 1):
        for cc in GRID_COLS:
            cell = ws.cell(row=rr, column=cc)
            if isinstance(cell, MergedCell):
                continue
            f = cell.font
            rgb = f.color.rgb if (f.color and f.color.type == "rgb") else None
            if isinstance(rgb, str) and rgb.upper() not in ("FF000000", "00000000"):
                nf = copy(f)
                nf.color = Font(color="FF000000").color
                cell.font = nf
            fill = cell.fill
            frgb = (fill.fgColor.rgb
                    if (fill.patternType == "solid" and fill.fgColor
                        and fill.fgColor.type == "rgb") else None)
            if isinstance(frgb, str) and frgb.upper() not in ("FFFFFFFF", "00000000"):
                cell.fill = copy(white)


def _cohort_capacity(ws) -> int:
    """How many cohort rows a day sheet may hold.

    A single documented limit, identical on every sheet. It is deliberately
    NOT measured from the template any more:

      * Deriving it from the page furniture made it sheet-dependent, because
        the furniture is not in the same place on every sheet — Tuesday and
        Wednesday carry a stray "BUS TIME" at row 59 against 83+ elsewhere.
        That silently capped those two days at 56 cohorts.
      * Deriving it from the styled row run gives ~704, since the template
        sets a row height far past its designed print area. A limit that can
        never fire is not a limit.

    `DATA_LAST_ROW` is the bottom of the template's designed cohort block, so
    this is the honest answer, uniform and predictable. A term that genuinely
    outgrows it should be a deliberate template change, not a silent stretch
    into unstyled rows.
    """
    return DATA_LAST_ROW - DATA_FIRST_ROW + 1


def _is_furniture_row(ws, row: int) -> bool:
    """A printed page-furniture row (bus timings, headcounts).

    The engine does not generate these and they describe a term that has
    ended, so they are removed like everything else under the routine. The
    predicate is kept because the tests assert they are gone.
    """
    for c in (1, 2):
        v = ws.cell(row=row, column=c).value
        if isinstance(v, str) and v.strip().lower() in _FURNITURE_LABELS:
            return True
    return False


def _clear_below_routine(ws, last_data: int) -> None:
    """Erase and hide every row below the routine.

    The template's tail is a museum of one finished term: a "TBA* = TO BE
    ANNOUNCED LATER" legend, a red banner bar, a per-day teacher-on-duty
    roster of real faculty acronyms, a green "66 Batch Section Distribution"
    student-ID table, leftover BREAK letters, and spare cohort rows. None of
    it is regenerated, so all of it used to ship inside every routine.

    Two earlier attempts were not enough. Clearing `.value` left the red bar
    and the green table as empty coloured rectangles, because a fill is not a
    value. Wiping only *below* the furniture missed Tuesday and Wednesday,
    whose templates carry a stray "BUS TIME" at row 59 — 24 rows above the
    real furniture — leaving a visible gap of empty rows in the middle of
    those two sheets and a stray "K" at row 67.

    So the rule is now total: every row under the routine is stripped of
    values, fills, borders, merges and font colour, and hidden. That includes
    the page furniture itself — the bus timings and headcounts are last
    term's numbers, the engine has no way to regenerate them, and they are
    not part of the routine. Whatever the template carries, and wherever it
    carries it, every day sheet now ends at the last cohort row.

    (To print bus times again, they would have to become configuration the
    admin maintains, like periods and rooms — not template residue.)
    """
    from copy import copy

    from openpyxl.cell.cell import MergedCell
    from openpyxl.styles import Border, Font, PatternFill

    blank_fill = PatternFill(fill_type=None)
    blank_border = Border()
    black = Font(color="FF000000").color
    limit = ws.max_row or last_data
    first = last_data + 1
    if first > limit:
        return

    for m in list(ws.merged_cells.ranges):
        if m.max_row >= first and m.min_row >= first:
            ws.unmerge_cells(str(m))

    width = max(ws.max_column or 15, 15)
    for r in range(first, limit + 1):
        ws.row_dimensions[r].hidden = True
        for c in range(1, width + 1):
            cell = ws.cell(row=r, column=c)
            if isinstance(cell, MergedCell):
                continue
            if cell.value is not None:
                cell.value = None
            if cell.fill.patternType is not None:
                cell.fill = blank_fill
            b = cell.border
            # A cleared side is `None`, not a Side carrying style=None.
            if any(s is not None and s.style
                   for s in (b.left, b.right, b.top, b.bottom)):
                cell.border = blank_border
            # Red hand-annotation fonts survive on these rows even with no
            # value. Invisible today, but the guarantee is worth keeping
            # absolute: nothing under the routine carries the old term's
            # styling.
            f = cell.font
            rgb = f.color.rgb if (f.color and f.color.type == "rgb") else None
            if isinstance(rgb, str) and rgb.upper() not in ("FF000000",
                                                            "00000000"):
                nf = copy(f)
                nf.color = black
                cell.font = nf


def _safe_clear(ws, row: int, col: int) -> None:
    """Set a cell to None unless it is a non-anchor cell of a merged range
    (writing those raises in openpyxl)."""
    from openpyxl.cell.cell import MergedCell
    cell = ws.cell(row=row, column=col)
    if isinstance(cell, MergedCell):
        return
    cell.value = None


def _strip_legacy_scaffolding(wb) -> None:
    """Strip every macro-era interactive artifact the source workbook carried
    over, so the generated routine is a plain, static spreadsheet (the new
    system no longer uses any of this scaffolding):

      - AutoFilters + their auto-generated `_FilterDatabase` defined names,
      - conditional-formatting rules,
      - structured Tables (e.g. 'Teacher Day Off'),
      - broken `#REF!` defined names (dead dynamic ranges the old dropdowns fed
        from).

    None of these affect the routine's visible content, styling, or layout.
    They also make lightweight/mobile xlsx viewers blank the whole sheet, which
    is why the day-sheets came up empty on a phone while the artifact-free
    sheets rendered fine. (The template has no VBA — it is a plain .xlsx, not a
    macro-enabled .xlsm — so there is no executable code to remove.)"""
    for ws in wb.worksheets:
        ws.auto_filter.ref = None
        ws.conditional_formatting = ConditionalFormattingList()
        for table_name in list(ws.tables.keys()):
            del ws.tables[table_name]

    for name in [n for n, dn in wb.defined_names.items()
                 if dn.value and "#REF!" in dn.value]:
        del wb.defined_names[name]


def _fmt_clock(hhmm: str) -> tuple[str, str]:
    """'13:10' -> ('1:10', 'PM'). Hours <= 12 keep two digits (08:50, 12:35);
    afternoon hours convert to 12-hour without a leading zero (13->1), matching
    the source workbook's hand-typed header style."""
    # Tolerate "HH:MM" and "HH:MM:SS" alike — config periods reach us from a
    # hand-edited DB table, and a stray seconds field used to abort the job
    # with "too many values to unpack (expected 2)".
    parts = hhmm.split(":")
    h, m = int(parts[0]), int(parts[1])
    ampm = "AM" if h < 12 else "PM"
    hh = f"{h:02d}" if h <= 12 else f"{h - 12}"
    return f"{hh}:{m:02d}", ampm


def _period_label(start: str, end: str) -> str:
    """Header label 'start-endAM/PM' (AM/PM taken from the end time)."""
    s, _ = _fmt_clock(start)
    e, ap = _fmt_clock(end)
    return f"{s}-{e}{ap}"


def _set_header_value(ws, row: int, col: int, text: str) -> None:
    """Set a header cell's text, preserving its style; skip merged interiors."""
    from openpyxl.cell.cell import MergedCell
    cell = ws.cell(row=row, column=col)
    if isinstance(cell, MergedCell):
        return
    cell.value = text


def _write_period_headers(ws, day: str, config: dict) -> None:
    """Rewrite row 2's period-time labels from config (in-person periods +
    computed break). Online column and Batch/Section headers are left as-is.

    Which periods are in-person and which are blocked on a given day come from
    the normalized config, so the header matches whatever the solver was
    actually allowed to use. `friday_no_p4` is honoured only as a fallback for
    callers that pass a raw, un-normalized config.
    """
    excluded = config.get("excluded_periods")
    if excluded is None:
        excluded = {7}
    blocked = config.get("blocked_periods")
    if blocked is None:
        blocked = {"Friday": {4}} if config.get("friday_no_p4", True) else {}
    day_blocked = set(blocked.get(day, ()))

    in_person = sorted((p for p in config["periods"]
                        if int(p["idx"]) not in excluded),
                       key=lambda p: int(p["idx"]))
    day_periods = [p for p in in_person if int(p["idx"]) not in day_blocked]
    for p in day_periods:
        col = openpyxl.utils.column_index_from_string(p["col"])
        _set_header_value(ws, HEADER_ROW, col, _period_label(p["start"], p["end"]))
    for a, b in zip(day_periods, day_periods[1:]):
        if a["end"] != b["start"]:
            _set_header_value(ws, HEADER_ROW, BREAK_COL,
                              _period_label(a["end"], b["start"]))
            break


def _break_span(day: str, config: dict) -> int:
    """How many columns the BREAK block covers on this day.

    The template ships Friday's break pre-merged across G:H because the
    department historically did not teach Friday period 4, whose column is H.
    The renderer used to hard-code that as `if day == "Friday"`. Once per-day
    blocked periods became admin-editable, the two could disagree — and when
    Friday P4 IS taught the renderer did not merely draw the wrong thing, it
    aborted the whole job with `'MergedCell' object attribute 'value' is
    read-only`, because it tried to write a class into a merged cell.

    So the span is derived from the configuration instead: the column beside
    the break is absorbed into it only when no period the solver may actually
    use on this day occupies that column.
    """
    excluded = config.get("excluded_periods") or set()
    blocked = config.get("blocked_periods") or {}
    day_blocked = set(blocked.get(day, ()))
    for pr in config.get("periods", []):
        idx = int(pr["idx"])
        if idx in excluded or idx in day_blocked:
            continue
        if openpyxl.utils.column_index_from_string(pr["col"]) == BREAK_COL + 1:
            return 1
    return 2


def _clear_break_merges(ws, config: dict, data_last: int) -> None:
    """Drop every merge over the break columns, header row included.

    Must run BEFORE any class or header is written: the template's Friday
    sheet arrives with G2:H2 and a full-height G:H block already merged, and
    writing into a merged cell raises.
    """
    for m in list(ws.merged_cells.ranges):
        if (m.max_col >= BREAK_COL and m.min_col <= BREAK_COL + 1
                and m.min_row >= HEADER_ROW and m.min_row <= data_last):
            ws.unmerge_cells(str(m))


def _rebuild_break_column(ws, day: str, last_data: int,
                          data_last: int = DATA_LAST_ROW,
                          config: dict | None = None) -> None:
    """Re-merge the vertical BREAK block to span only the used data rows
    (3..last_data), so its letters always fit the visible table no matter the
    cohort count. The template ships the column merged for the full capacity;
    this shrinks it to the live size. Style is copied from the template's
    existing break cell.

    Width comes from `_break_span`, i.e. from the configured periods, not from
    the day's name.
    """
    from copy import copy

    from openpyxl.cell.cell import MergedCell
    span = _break_span(day, config or {})
    end_col = BREAK_COL + span - 1

    src = ws.cell(DATA_FIRST_ROW, BREAK_COL)
    font, align, fill, border = (copy(src.font), copy(src.alignment),
                                 copy(src.fill), copy(src.border))
    for m in list(ws.merged_cells.ranges):
        if (m.max_col >= BREAK_COL and m.min_col <= end_col
                and DATA_FIRST_ROW <= m.min_row <= data_last):
            ws.unmerge_cells(str(m))
    for r in range(DATA_FIRST_ROW, data_last + 1):
        for c in range(BREAK_COL, end_col + 1):
            cell = ws.cell(r, c)
            if not isinstance(cell, MergedCell):
                cell.value = None

    def _style(cell, text, top=None, bottom=None):
        """Style one BREAK block.

        Borders are set explicitly rather than copied wholesale from the
        template's break cell. That cell is G3 — the top-left of the table —
        so it carries a THICK TOP, and copying it onto every letter block
        stamped a heavy line at the start of each block (rows 14, 25, 36 and
        47 on a 55-cohort routine), cutting across the middle of batches 65,
        62 and 60. The break column is one continuous column visually: only
        its outer edges are heavy, and the letter boundaries inside it draw
        nothing at all.
        """
        cell.font, cell.alignment = copy(font), copy(align)
        cell.fill = copy(fill)
        cell.border = Border(left=border.left, right=border.right,
                             top=top, bottom=bottom)
        cell.value = text

    if span > 1:
        # Wide enough to spell the word out horizontally on one row.
        ws.merge_cells(start_row=DATA_FIRST_ROW, start_column=BREAK_COL,
                       end_row=last_data, end_column=end_col)
        _style(ws.cell(DATA_FIRST_ROW, BREAK_COL), "BREAK",
               top=_THICK, bottom=_THICK)
        return
    letters = "BREAK"
    size = max(1, (last_data - DATA_FIRST_ROW + 1) // len(letters))
    start = DATA_FIRST_ROW
    for i, ch in enumerate(letters):
        end = last_data if i == len(letters) - 1 else min(last_data, start + size - 1)
        ws.merge_cells(start_row=start, start_column=BREAK_COL,
                       end_row=end, end_column=BREAK_COL)
        _style(ws.cell(start, BREAK_COL), ch,
               top=_THICK if start == DATA_FIRST_ROW else None,
               bottom=_THICK if end == last_data else None)
        start = end + 1
        if start > last_data:
            break


def _drop_data_row_merges(ws, row: int) -> None:
    """Unmerge any leftover single-row merge inside the data columns of an
    empty trailing row (e.g. a stale 'A+B' B:C merge), so it can be fully
    blanked. Multi-row merges (the vertical BREAK block) are left intact."""
    for mr in list(ws.merged_cells.ranges):
        if (mr.min_row == row == mr.max_row
                and mr.min_col >= 2 and mr.max_col <= max(GRID_COLS)):
            ws.unmerge_cells(str(mr))


def _vertical_sides(col: int) -> tuple[Side | None, Side | None]:
    """The left and right border of one grid column.

    Verticals were previously inherited from the template, and the template is
    as ragged vertically as it was horizontally: measured across one rendered
    sheet, 50 of 55 rows carried the intended pattern and the other 5 did not
    — one row lost the table's right-hand edge completely, others drew the
    Batch/Section divider thin instead of heavy. Setting them explicitly, like
    the horizontals, means every row is identical by construction.

    The structure is heavy at the table's outer edges and where the cohort
    identity block (Batch, Section) meets the class grid; thin everywhere else.
    """
    first_session = min(SESSION_COLS)
    last_grid = max(GRID_COLS)
    left = _THICK if col in (GRID_COLS[0], first_session) else _THIN
    right = _THICK if col == last_grid else _THIN
    return left, right


def _apply_cohort_borders(ws, groups: list[dict], n_cohorts: int,
                          data_last: int) -> None:
    """Establish the ENTIRE horizontal border state of the live cohort block.

    The heavy rule must fall only where a batch ends:

        70-A  70-B  70-C  ====   69-A  69-B  ====   68-A  ====

    The previous version set only each row's `bottom` and preserved `top`.
    That is why the boldness looked random: in Excel the line drawn between
    two rows is the union of the upper row's bottom AND the lower row's top,
    and this template carries stale THICK tops on rows 18, 27, 32, 34, 41, 46,
    52, 57 and 59 plus ragged per-column bottoms (row 26 is `##.##...#`).
    Those thick tops bled through mid-batch no matter what bottom we wrote.

    So both sides are now written for every row, and each row's top is set to
    exactly the separator chosen for the row above it. The two can no longer
    disagree, and nothing is inherited from the template.
    """
    from openpyxl.cell.cell import MergedCell

    last_of_batch = {g["last"] for g in groups}

    def sep(idx: int) -> Side | None:
        """The line drawn BELOW cohort index `idx`."""
        if idx >= n_cohorts - 1:
            return _THICK          # closes the table
        return _THICK if idx in last_of_batch else _THIN

    for rr in range(DATA_FIRST_ROW, data_last + 1):
        idx = rr - DATA_FIRST_ROW
        if idx < n_cohorts:
            bottom = sep(idx)
            top = _THICK if idx == 0 else sep(idx - 1)
        else:
            # Unused capacity: no separators at all, so a shorter routine
            # cannot leave the previous one's batch lines behind.
            bottom = top = None
        for col in GRID_COLS:
            cell = ws.cell(row=rr, column=col)
            if isinstance(cell, MergedCell):
                continue
            left, right = _vertical_sides(col)
            cell.border = Border(left=left, right=right, top=top, bottom=bottom)


if __name__ == "__main__":
    import ingest
    import solver

    cfg = solver.load_config()
    ds = ingest.ingest_path(
        "routine generation files/Main_Distribution_Summer25.xlsx",
        weeks_in_term=cfg["weeks_in_term"],
        fixed_sessions_per_week=cfg.get("fixed_sessions_per_week"))
    res = solver.solve(ds, cfg, time_limit_s=20.0)
    data = render_bytes(res["rows"], ds["cohorts"], cfg)
    out = Path(__file__).parent / "out_routine.xlsx"
    out.write_bytes(data)
    print(f"rendered {len(res['rows'])} sessions -> {out} ({len(data)} bytes)")
