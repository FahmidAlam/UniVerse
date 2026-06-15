# ============================================================
# FILE: engine/render.py
# PURPOSE: Render solved sessions into a workbook identical in format
#   to CSE_Routine_Summer_25_Version_2_0.xlsx. Clones the real workbook
#   as a styled template (preserving the banner, headers, the vertical
#   BREAK column, bus rows and all formatting), then:
#     - writes ONE canonical 55-row cohort map identically to every
#       day-sheet (structurally fixes the §6.1 "66-H row shift" bug),
#     - clears any legacy session/cohort cells,
#     - writes each session as "<CODE> <TEACHER> <ROOM>" in the right
#       (cohort-row, period-column) cell,
#     - leaves Friday's Period-4 column (H) empty.
#
# Returns the rendered workbook as bytes (for HTTP download / upload to
# Supabase Storage).
# ============================================================

from __future__ import annotations

import io
from pathlib import Path

import openpyxl

TEMPLATE = Path(__file__).parent / "templates" / "CSE_Routine_TEMPLATE.xlsx"

DAYS = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
DATA_FIRST_ROW = 3
DATA_LAST_ROW = 59          # rows 60/61 are BUS TIME / STUDENT NO.
BREAK_COL = 7               # column G — never written
# Period columns that may hold a session (D,E,F,H,I,J,K = 4,5,6,8,9,10,11).
SESSION_COLS = [4, 5, 6, 8, 9, 10, 11]


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

    # period idx -> column letter, from config
    pcol = {int(p["idx"]): openpyxl.utils.column_index_from_string(p["col"])
            for p in config["periods"]}

    # canonical cohort -> row (rows 3..3+len-1)
    row_of = {c: DATA_FIRST_ROW + i for i, c in enumerate(cohorts)}

    # rows grouped by cohort
    by_cohort: dict[str, list[dict]] = {}
    for r in rows:
        key = f"{r['batch']}-{r['section']}" if r["section"] else str(r["batch"])
        by_cohort.setdefault(key, []).append(r)

    for day in DAYS:
        if day not in wb.sheetnames:
            continue
        ws = wb[day]

        # 1) clear legacy session cells + stray cohort labels
        for rr in range(DATA_FIRST_ROW, DATA_LAST_ROW + 1):
            for cc in SESSION_COLS:
                _safe_clear(ws, rr, cc)

        # 2) write canonical cohort labels (B=batch, C=section), clearing
        #    any rows beyond the canonical set.
        for rr in range(DATA_FIRST_ROW, DATA_LAST_ROW + 1):
            idx = rr - DATA_FIRST_ROW
            if idx < len(cohorts):
                c = cohorts[idx]
                batch, _, section = c.partition("-")
                ws.cell(row=rr, column=2, value=_batch_cell(batch))
                ws.cell(row=rr, column=3, value=section or None)
            else:
                _safe_clear(ws, rr, 2)
                _safe_clear(ws, rr, 3)

        # 3) write this day's sessions
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

    buf = io.BytesIO()
    wb.save(buf)
    return buf.getvalue()


def _safe_clear(ws, row: int, col: int) -> None:
    """Set a cell to None unless it is a non-anchor cell of a merged range
    (writing those raises in openpyxl)."""
    from openpyxl.cell.cell import MergedCell
    cell = ws.cell(row=row, column=col)
    if isinstance(cell, MergedCell):
        return
    cell.value = None


if __name__ == "__main__":
    import ingest
    import solver

    ds = ingest.ingest_path("routine generation files/Main_Distribution_Summer25.xlsx")
    cfg = solver.load_config()
    res = solver.solve(ds, cfg, time_limit_s=20.0)
    data = render_bytes(res["rows"], ds["cohorts"], cfg)
    out = Path(__file__).parent / "out_routine.xlsx"
    out.write_bytes(data)
    print(f"rendered {len(res['rows'])} sessions -> {out} ({len(data)} bytes)")
