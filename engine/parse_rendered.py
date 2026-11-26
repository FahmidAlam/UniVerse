"""Phase 3B non-mutating rendered-workbook parser with 1:1 Dart RoutineWorkbookParser parity.

Reads Leading University 7-day rendered sheets (Sunday–Saturday) and fallback
tabular routine workbooks strictly read-only from OOXML XML (never executing
macros, external links, or formulas, and never mutating input bytes or DB state).
"""

from __future__ import annotations

import io
import posixpath
import re
import xml.etree.ElementTree as ET
import zipfile
from dataclasses import dataclass
from typing import Any

import room_policy

WEEK_DAYS: tuple[str, ...] = (
    "Sunday",
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
)
WEEK_DAYS_SHORT: tuple[str, ...] = ("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat")

_FIRST_DATA_ROW = 3
_FALLBACK_SESSION_COLS: tuple[str, ...] = ("D", "E", "F", "H", "I", "J", "K")
_DEFAULT_PERIOD_SLOTS: dict[str, tuple[str, str, int]] = {
    "D": ("08:50:00", "10:05:00", 1),
    "E": ("10:05:00", "11:20:00", 2),
    "F": ("11:20:00", "12:35:00", 3),
    "H": ("13:10:00", "14:25:00", 4),
    "I": ("14:25:00", "15:40:00", 5),
    "J": ("15:40:00", "16:55:00", 6),
    "K": ("19:00:00", "20:20:00", 7),
}

_PENDING_TEACHER_TOKENS = frozenset(
    {"FACULTY-PENDING", "PENDING", "TBA", "TBD", "UNASSIGNED"}
)
_NON_SERVICE_TEXT_BATCHES = frozenset({"retake", "improvement", "retake/improvement"})
_SERVICE_SECTION_RE = re.compile(r"^\s*\d+(?:st|nd|rd|th)\s+sem", re.IGNORECASE)

_LAST_AFTERNOON_HOUR = 7
_MINUTES_PER_HALF_DAY = 12 * 60
_MINUTES_PER_DAY = 24 * 60

_CLOCK_RE = re.compile(
    r"(\d{1,2})(?::(\d{1,2}))?(?::(\d{1,2}))?\s*(a\.?m\.?|p\.?m\.?)?",
    re.IGNORECASE,
)
_MERIDIEM_END_RE = re.compile(r"(a\.?m\.?|p\.?m\.?)\s*$", re.IGNORECASE)
_BARE_CLOCK_RE = re.compile(r"^\s*\d{1,2}(?::\d{1,2})?\s*$")
_COURSE_CODE_EXACT_RE = re.compile(r"^[A-Z]{2,5}[- ]?\d{3,4}[A-Z]?$")
_COURSE_CODE_SEARCH_RE = re.compile(r"[A-Z]{2,5}[- ]?\d{3,4}[A-Z]?")
_BATCH_LABEL_RE = re.compile(r"\bbatch\s*[:#-]?\s*(\d+)\b", re.IGNORECASE)
_SECTION_LABEL_RE = re.compile(r"\b(?:section|sec)\s*[:#-]?\s*([A-Z0-9+]+)\b", re.IGNORECASE)
_ROOM_ALIAS_FOOTER_RE = re.compile(r"room\s*alias(?:es)?\s*[:\-]\s*(.+)", re.IGNORECASE)
_ROOM_ALIAS_PAIR_RE = re.compile(r"^\s*([^=:\->]+?)\s*(?:=|->|=>|:)\s*(.+?)\s*$")
_LAST_DIGIT_RE = re.compile(r"(\d)\s*$")


# ---------------------------------------------------------------------------
# ClockTime parity (`lib/core/utils/clock_time.dart`)
# ---------------------------------------------------------------------------


def clock_from_minutes(total_minutes: int) -> str:
    wrapped = total_minutes % _MINUTES_PER_DAY
    return f"{wrapped // 60:02d}:{wrapped % 60:02d}:00"


def clock_to_minutes(value: str) -> int | None:
    parts = value.split(":")
    if len(parts) < 2:
        return None
    try:
        hour = int(parts[0].strip())
        minute = int(parts[1].strip())
    except ValueError:
        return None
    return hour * 60 + minute


def clock_normalize(value: str) -> str | None:
    text = value.strip()
    if not text:
        return None

    # Excel serial time fraction of a day (0.5 == 12:00)
    try:
        serial = float(text)
    except ValueError:
        serial = None
    if serial is not None and 0.0 <= serial < 1.0:
        return clock_from_minutes(int(round(serial * _MINUTES_PER_DAY)))

    match = _CLOCK_RE.search(text)
    if match is None:
        return None

    hour_str = match.group(1)
    try:
        hour = int(hour_str)
        minute = int(match.group(2)) if match.group(2) is not None else 0
        second = int(match.group(3)) if match.group(3) is not None else 0
    except ValueError:
        return None
    if hour > 24 or minute > 59 or second > 59:
        return None

    meridiem_raw = match.group(4)
    meridiem = meridiem_raw.lower().replace(".", "") if meridiem_raw else None
    if meridiem == "pm":
        if hour < 12:
            hour += 12
    elif meridiem == "am":
        if hour == 12:
            hour = 0
    elif 1 <= hour <= _LAST_AFTERNOON_HOUR and not (
        len(hour_str) == 2 and match.group(3) is not None
    ):
        hour += 12

    if hour >= 24:
        hour -= 24

    return f"{hour:02d}:{minute:02d}:{second:02d}"


def clock_normalize_or(value: str) -> str:
    return clock_normalize(value) or value.strip()


def clock_repair_sequence(
    slots: list[tuple[str, str]],
) -> list[tuple[str, str]]:
    out: list[tuple[str, str]] = []
    previous_start = -1
    for start_raw, end_raw in slots:
        start = clock_to_minutes(start_raw)
        end = clock_to_minutes(end_raw)
        if start is None or end is None:
            out.append((start_raw, end_raw))
            continue

        if start < previous_start and start + _MINUTES_PER_HALF_DAY < _MINUTES_PER_DAY:
            start += _MINUTES_PER_HALF_DAY
        if end <= start and end + _MINUTES_PER_HALF_DAY < _MINUTES_PER_DAY:
            end += _MINUTES_PER_HALF_DAY

        previous_start = start
        out.append((clock_from_minutes(start), clock_from_minutes(end)))
    return out


# ---------------------------------------------------------------------------
# Internal structures & OOXML helpers
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class _PeriodSlot:
    start: str
    end: str
    idx: int | None = None


@dataclass(frozen=True)
class _ParsedCell:
    subject_code: str
    teacher_code: str
    teachers: tuple[str, ...]
    room: str


@dataclass(frozen=True)
class _RawRoutineCell:
    day: str
    batch: str
    section: str
    time_start: str
    time_end: str
    subject_code: str
    teacher_code: str
    teachers: tuple[str, ...]
    room: str
    subject: str | None = None
    teacher_name: str | None = None
    semester: int | None = None
    period: int | None = None
    explicit_service: bool | None = None


def _local_name(tag: str) -> str:
    if "}" in tag:
        return tag.rsplit("}", 1)[1]
    return tag


def _attr(elem: ET.Element, local_name: str) -> str | None:
    for key, val in elem.attrib.items():
        if _local_name(key) == local_name:
            return val
    return None


def _clean_text(value: str | None) -> str:
    if not value:
        return ""
    return re.sub(r"\s+", " ", value).strip()


def _column_index(col: str) -> int:
    value = 0
    for ch in col.upper():
        o = ord(ch)
        if 65 <= o <= 90:
            value = value * 26 + (o - 64)
    return value


def _col_of(ref: str) -> str:
    return re.sub(r"\d", "", ref).upper()


def _row_of(ref: str) -> int | None:
    digits = re.sub(r"[A-Za-z]", "", ref)
    try:
        return int(digits)
    except ValueError:
        return None


def _normal_sheet_path(target: str) -> str:
    clean = target.replace("\\", "/")
    if clean.startswith("/"):
        return clean[1:]
    if clean.startswith("xl/"):
        return clean
    return posixpath.normpath(f"xl/{clean}")


def _find_zip_member(zf: zipfile.ZipFile, path: str) -> bytes | None:
    normalized = path.replace("\\", "/")
    for info in zf.infolist():
        if info.filename.replace("\\", "/") == normalized:
            return zf.read(info)
    return None


def _read_shared_strings(zf: zipfile.ZipFile) -> list[str]:
    raw = _find_zip_member(zf, "xl/sharedStrings.xml")
    if raw is None:
        return []
    root = ET.fromstring(raw)
    strings: list[str] = []
    for elem in root.iter():
        if _local_name(elem.tag) == "si":
            parts = [
                child.text or ""
                for child in elem.iter()
                if _local_name(child.tag) == "t"
            ]
            strings.append("".join(parts))
    return strings


def _read_sheet_paths(zf: zipfile.ZipFile) -> list[tuple[str, str]]:
    wb_raw = _find_zip_member(zf, "xl/workbook.xml")
    rels_raw = _find_zip_member(zf, "xl/_rels/workbook.xml.rels")
    if wb_raw is None or rels_raw is None:
        return []

    rel_by_id: dict[str, str] = {}
    rels_root = ET.fromstring(rels_raw)
    for elem in rels_root.iter():
        if _local_name(elem.tag) != "Relationship":
            continue
        rel_id = _attr(elem, "Id")
        target = _attr(elem, "Target")
        if rel_id and target:
            rel_by_id[rel_id] = _normal_sheet_path(target)

    out: list[tuple[str, str]] = []
    wb_root = ET.fromstring(wb_raw)
    for elem in wb_root.iter():
        if _local_name(elem.tag) != "sheet":
            continue
        name = _attr(elem, "name")
        rel_id = _attr(elem, "id")
        path = rel_by_id.get(rel_id) if rel_id else None
        if name and path:
            out.append((name.strip(), path))
    return out


def _cell_text(cell: ET.Element, shared_strings: list[str]) -> str:
    cell_type = _attr(cell, "t")
    if cell_type == "inlineStr":
        return "".join(
            child.text or ""
            for child in cell.iter()
            if _local_name(child.tag) == "t"
        )

    value: str | None = None
    for child in cell:
        if _local_name(child.tag) == "v":
            value = child.text or ""
            break

    if value is None:
        return ""
    if cell_type == "s":
        try:
            idx = int(value)
        except ValueError:
            return ""
        if 0 <= idx < len(shared_strings):
            return shared_strings[idx]
        return ""
    return value


def _read_grid(xml_bytes: bytes, shared_strings: list[str]) -> dict[int, dict[str, str]]:
    root = ET.fromstring(xml_bytes)
    grid: dict[int, dict[str, str]] = {}
    for elem in root.iter():
        if _local_name(elem.tag) != "c":
            continue
        ref = _attr(elem, "r")
        if not ref:
            continue
        row = _row_of(ref)
        if row is None:
            continue
        text = _cell_text(elem, shared_strings).strip()
        if not text:
            continue
        grid.setdefault(row, {})[_col_of(ref)] = text
    return grid


# ---------------------------------------------------------------------------
# Header, time, cell, and room-alias parsing
# ---------------------------------------------------------------------------


def _header_key(text: str) -> str:
    key = text.lower()
    key = re.sub(r"[_\-./()]+", " ", key)
    return re.sub(r"\s+", " ", key).strip()


def _field_for_header(text: str) -> str | None:
    h = _header_key(text)
    if not h:
        return None
    mapping = {
        "day": {"day", "weekday", "week day", "class day"},
        "time": {"time", "time slot", "slot", "class time", "period", "schedule"},
        "start_time": {"start", "start time", "time start", "from"},
        "end_time": {"end", "end time", "time end", "to"},
        "subject": {"subject", "course", "course title", "subject title", "title", "course name"},
        "subject_code": {"code", "course code", "subject code", "course no", "course number"},
        "teacher_code": {"teacher", "teacher code", "faculty", "faculty code", "acronym", "teacher acronym"},
        "teacher_name": {"teacher name", "faculty name", "instructor", "instructor name"},
        "room": {"room", "class room", "room no", "room number", "venue"},
        "batch": {"batch", "batch no", "batch number"},
        "section": {"section", "sec"},
        "semester": {"semester", "sem"},
        "is_service": {"is service", "service", "service course"},
    }
    for field, aliases in mapping.items():
        if h in aliases:
            return field
    return None


def _day_from_text(text: str) -> str | None:
    lower = text.strip().lower()
    if not lower:
        return None
    for day in WEEK_DAYS:
        dl = day.lower()
        if lower == dl or lower.startswith(dl) or dl in lower:
            return day
    for idx, short in enumerate(WEEK_DAYS_SHORT):
        sl = short.lower()
        if lower == sl or lower.startswith(sl):
            return WEEK_DAYS[idx]
    return None


def _meridiem_of(text: str) -> str | None:
    m = _MERIDIEM_END_RE.search(text)
    if not m:
        return None
    return m.group(1).lower().replace(".", "")


def _parse_endpoints(start: str, end: str) -> _PeriodSlot | None:
    s = re.sub(r"^\(\s*", "", start.strip())
    e = re.sub(r"\s*\)$", "", end.strip())
    a = clock_normalize(_clean_text(s))
    b = clock_normalize(_clean_text(e))
    if a is None or b is None:
        return None

    am = _meridiem_of(s)
    bm = _meridiem_of(e)
    inherited_start = a
    inherited_end = b
    if am is None and bm is not None and _BARE_CLOCK_RE.match(s):
        inherited_start = clock_normalize(_clean_text(f"{s} {bm}")) or a
    elif bm is None and am is not None and _BARE_CLOCK_RE.match(e):
        inherited_end = clock_normalize(_clean_text(f"{e} {am}")) or b

    s_min = clock_to_minutes(inherited_start)
    e_min = clock_to_minutes(inherited_end)
    if s_min is not None and e_min is not None and s_min < e_min:
        return _PeriodSlot(inherited_start, inherited_end)
    return _PeriodSlot(a, b)


def _time_range(combined: str = "", start: str = "", end: str = "") -> _PeriodSlot | None:
    separate = _parse_endpoints(start, end)
    if separate is not None:
        return separate

    normalized = (
        combined.replace("–", "-")
        .replace("—", "-")
        .replace("to", "-")
    )
    parts = re.split(r"\s*-\s*", normalized)
    if len(parts) >= 2:
        return _parse_endpoints(parts[0], parts[1])
    return None


def _periods_by_column(periods: list[dict[str, Any]]) -> dict[str, _PeriodSlot]:
    out: dict[str, _PeriodSlot] = {}
    for raw in periods:
        if not isinstance(raw, dict):
            continue
        col = str(raw.get("col") or "").strip().upper()
        start = raw.get("start")
        end = raw.get("end")
        if not col or start is None or end is None:
            continue
        raw_idx = raw.get("idx")
        idx = int(raw_idx) if isinstance(raw_idx, int) or (isinstance(raw_idx, str) and raw_idx.isdigit()) else None
        out[col] = _PeriodSlot(
            clock_normalize_or(str(start)),
            clock_normalize_or(str(end)),
            idx=idx,
        )

    if out:
        cols = sorted(out.keys(), key=_column_index)
        repaired = clock_repair_sequence([(out[c].start, out[c].end) for c in cols])
        return {
            cols[i]: _PeriodSlot(repaired[i][0], repaired[i][1], idx=out[cols[i]].idx)
            for i in range(len(cols))
        }

    return {
        col: _PeriodSlot(start, end, idx=idx)
        for col, (start, end, idx) in _DEFAULT_PERIOD_SLOTS.items()
    }


def _clean_batch(value: str | None) -> str:
    text = _clean_text(value)
    if text.endswith(".0"):
        return text[:-2]
    try:
        as_num = float(text)
        if as_num.is_integer():
            return str(int(as_num))
    except ValueError:
        pass
    m = _BATCH_LABEL_RE.search(text)
    if m:
        return m.group(1)
    return text


def _clean_section(value: str | None) -> str:
    text = _clean_text(value).upper()
    m = _SECTION_LABEL_RE.search(text)
    return m.group(1) if m else text


def _is_cohort_header(batch: str, section: str) -> bool:
    return _field_for_header(batch) == "batch" or _field_for_header(section) == "section"


def _normalize_course_code(value: str) -> str:
    text = _clean_text(value).upper()
    m = _COURSE_CODE_SEARCH_RE.search(text)
    return m.group(0).replace(" ", "-") if m else text


def _split_teacher_tokens(raw_token: str) -> tuple[str, tuple[str, ...]]:
    token = raw_token.strip().upper()
    if not token or token in _PENDING_TEACHER_TOKENS:
        return "", ()
    parts = [
        p.strip().upper()
        for p in re.split(r"[/,]+", token)
        if p.strip() and p.strip().upper() not in _PENDING_TEACHER_TOKENS
    ]
    deduped = tuple(dict.fromkeys(parts))
    if not deduped:
        return "", ()
    return deduped[0], deduped


def _parse_session_text(text: str) -> _ParsedCell | None:
    parts = [p for p in text.strip().split() if p]
    if len(parts) < 3:
        return None

    code = parts[0].strip().upper()
    rest_idx = 1
    # Support spaced course code like "CSE 1101 EBH RAB-302"
    if (
        len(parts) >= 4
        and re.match(r"^[A-Z]{2,5}$", parts[0].upper())
        and re.match(r"^\d{3,4}[A-Z]?$", parts[1].upper())
    ):
        code = f"{parts[0].upper()}-{parts[1].upper()}"
        rest_idx = 2

    if not _COURSE_CODE_EXACT_RE.match(code):
        return None

    teacher_code, teachers = _split_teacher_tokens(parts[rest_idx])
    room = " ".join(parts[rest_idx + 1 :]).strip()
    if not room:
        return None
    return _ParsedCell(
        subject_code=code.replace(" ", "-"),
        teacher_code=teacher_code,
        teachers=teachers,
        room=room,
    )


def _parse_session_cells(text: str) -> list[_ParsedCell]:
    rows: list[_ParsedCell] = []
    for line in re.split(r"[\r\n;]+", text):
        parsed = _parse_session_text(line)
        if parsed is not None:
            rows.append(parsed)
    if len(rows) > 1:
        return rows

    whole = _parse_session_text(re.sub(r"[\r\n]+", " ", text))
    if whole is not None:
        return [whole]
    return rows


def _extract_room_alias_footers(grid: dict[int, dict[str, str]]) -> dict[str, str]:
    aliases: dict[str, str] = {}
    for cells in grid.values():
        for raw_text in cells.values():
            m = _ROOM_ALIAS_FOOTER_RE.search(raw_text)
            if not m:
                continue
            body = m.group(1)
            for chunk in re.split(r"[,;\r\n]+", body):
                pair = _ROOM_ALIAS_PAIR_RE.match(chunk.strip())
                if not pair:
                    continue
                lhs = _clean_text(pair.group(1)).upper()
                rhs = _clean_text(pair.group(2)).upper()
                if lhs and rhs and lhs != rhs:
                    aliases[lhs] = rhs
    return aliases


def _cohort_columns_for_day_sheet(grid: dict[int, dict[str, str]]) -> tuple[str, str]:
    for row_no in sorted(grid.keys())[:16]:
        batch_col: str | None = None
        section_col: str | None = None
        for col, text in grid[row_no].items():
            field = _field_for_header(text)
            if field == "batch":
                batch_col = col
            elif field == "section":
                section_col = col
        if batch_col and section_col:
            return batch_col, section_col
    return "B", "C"


def _day_sheet_slots(
    grid: dict[int, dict[str, str]],
    period_by_col: dict[str, _PeriodSlot],
    batch_col: str,
    section_col: str,
    warnings: list[str],
    day: str,
    configured_columns: set[str],
) -> dict[str, _PeriodSlot]:
    slots: dict[str, _PeriodSlot] = dict(period_by_col)
    row_numbers = sorted(grid.keys())

    for row_no in row_numbers[:16]:
        for col, text in grid[row_no].items():
            if col in (batch_col, section_col):
                continue
            slot = _time_range(combined=text)
            if slot is not None:
                configured = period_by_col.get(col)
                if (
                    col in configured_columns
                    and configured is not None
                    and (configured.start != slot.start or configured.end != slot.end)
                ):
                    warnings.append(
                        f"{day} column {col}: workbook time "
                        f"{slot.start}-{slot.end} differs from configured time "
                        f"{configured.start}-{configured.end}; workbook time retained."
                    )
                slots[col] = _PeriodSlot(
                    slot.start,
                    slot.end,
                    idx=configured.idx if configured is not None else None,
                )

    routine_cols: set[str] = set()
    for row_no in row_numbers:
        if row_no < _FIRST_DATA_ROW:
            continue
        cells = grid[row_no]
        if not _clean_batch(cells.get(batch_col)):
            continue
        for col, text in cells.items():
            if col in (batch_col, section_col) or col in slots:
                continue
            if _parse_session_cells(text):
                routine_cols.add(col)

    fallback_slots = [
        _PeriodSlot(start, end, idx=idx)
        for col in _FALLBACK_SESSION_COLS
        for start, end, idx in (_DEFAULT_PERIOD_SLOTS[col],)
    ]
    for i, col in enumerate(sorted(routine_cols, key=_column_index)):
        if i >= len(fallback_slots):
            break
        slots[col] = fallback_slots[i]

    return {col: slots[col] for col in sorted(slots.keys(), key=_column_index)}


def _parse_day_sheet(
    day: str,
    xml_bytes: bytes,
    shared_strings: list[str],
    period_by_col: dict[str, _PeriodSlot],
    configured_columns: set[str],
    warnings: list[str],
    discovered_aliases: dict[str, str],
) -> list[_RawRoutineCell]:
    grid = _read_grid(xml_bytes, shared_strings)
    if not grid:
        return []

    discovered_aliases.update(_extract_room_alias_footers(grid))
    batch_col, section_col = _cohort_columns_for_day_sheet(grid)
    slots_by_col = _day_sheet_slots(
        grid=grid,
        period_by_col=period_by_col,
        batch_col=batch_col,
        section_col=section_col,
        warnings=warnings,
        day=day,
        configured_columns=configured_columns,
    )

    rows: list[_RawRoutineCell] = []
    for row_no in sorted(r for r in grid.keys() if r >= _FIRST_DATA_ROW):
        cells = grid[row_no]
        batch = _clean_batch(cells.get(batch_col))
        section = _clean_section(cells.get(section_col))
        if not batch or not section or _is_cohort_header(batch, section):
            continue

        for col, slot in slots_by_col.items():
            value = _clean_text(cells.get(col))
            if not value:
                continue
            parsed_cells = _parse_session_cells(value)
            if not parsed_cells:
                warnings.append(f"{day} row {row_no} column {col} could not be read.")
                continue
            for parsed in parsed_cells:
                rows.append(
                    _RawRoutineCell(
                        day=day,
                        batch=batch,
                        section=section,
                        time_start=slot.start,
                        time_end=slot.end,
                        subject_code=parsed.subject_code,
                        teacher_code=parsed.teacher_code,
                        teachers=parsed.teachers,
                        room=parsed.room,
                        period=slot.idx,
                    )
                )
    return rows


def _find_tabular_header(
    grid: dict[int, dict[str, str]],
    inferred_day: str | None,
) -> tuple[int, dict[str, str]] | None:
    for row_no in sorted(grid.keys())[:40]:
        cols: dict[str, str] = {}
        for col, text in grid[row_no].items():
            field = _field_for_header(text)
            if field:
                cols[col] = field
        fields = set(cols.values())
        has_day = "day" in fields or inferred_day is not None
        has_time = "time" in fields or ("start_time" in fields and "end_time" in fields)
        has_class = "subject_code" in fields or "subject" in fields
        has_teacher = "teacher_code" in fields or "teacher_name" in fields
        has_cohort = "batch" in fields and "section" in fields
        if has_day and has_time and has_class and has_teacher and has_cohort:
            return row_no, cols
    return None


def _parse_bool_flag(text: str) -> bool | None:
    cleaned = text.strip().lower()
    if not cleaned:
        return None
    if cleaned in {"true", "yes", "1", "y"}:
        return True
    if cleaned in {"false", "no", "0", "n"}:
        return False
    return None


def _parse_tabular_row(
    cells: dict[str, str],
    header_cols: dict[str, str],
    row_no: int,
    inferred_day: str | None,
    warnings: list[str],
) -> _RawRoutineCell | None:
    def get_field(field_name: str) -> str:
        for col, f in header_cols.items():
            if f == field_name:
                return _clean_text(cells.get(col))
        return ""

    day = _day_from_text(get_field("day")) or inferred_day
    batch = _clean_batch(get_field("batch"))
    section = _clean_section(get_field("section"))
    subject = get_field("subject")
    code = _normalize_course_code(get_field("subject_code"))
    teacher_code, teachers = _split_teacher_tokens(get_field("teacher_code"))
    teacher_name_raw = get_field("teacher_name")
    room = get_field("room")
    slot = _time_range(
        combined=get_field("time"),
        start=get_field("start_time"),
        end=get_field("end_time"),
    )
    sem_text = get_field("semester")
    try:
        semester = int(sem_text) if sem_text else None
    except ValueError:
        semester = None
    explicit_service = _parse_bool_flag(get_field("is_service"))

    if (
        day is None
        or not batch
        or not section
        or not room
        or slot is None
        or (not code and not subject)
    ):
        has_any = any(
            bool(v)
            for v in (day, batch, section, subject, code, teacher_code, teacher_name_raw, room)
        )
        if has_any:
            warnings.append(
                f"Tabular row {row_no} was skipped because required data is missing."
            )
        return None

    return _RawRoutineCell(
        day=day,
        batch=batch,
        section=section,
        time_start=slot.start,
        time_end=slot.end,
        subject_code=code if code else subject.upper(),
        subject=subject or None,
        teacher_code=teacher_code,
        teachers=teachers,
        teacher_name=teacher_name_raw or None,
        room=room,
        semester=semester,
        explicit_service=explicit_service,
    )


def _semester_for(batch: str, max_batch: int | None, semester_map: dict[str, int]) -> int:
    if batch in semester_map:
        return int(semester_map[batch])
    try:
        n = int(batch)
    except ValueError:
        return 1
    if max_batch is None:
        return 1
    return max(1, min(8, max_batch - n + 1))


def _is_lab_course(subject_code: str, subject_title: str) -> bool:
    m = _LAST_DIGIT_RE.search(subject_code.strip())
    if m and int(m.group(1)) % 2 == 0:
        return True
    lower = subject_title.lower()
    return "sessional" in lower or "lab" in lower


def _is_service_row(batch: str, section: str, explicit_service: bool | None) -> bool:
    if explicit_service is not None:
        return explicit_service
    if not batch.isdigit() and batch.casefold() not in _NON_SERVICE_TEXT_BATCHES:
        return True
    return bool(_SERVICE_SECTION_RE.match(section))


def _infer_period_idx(
    raw_period: int | None,
    time_start: str,
    period_slots: list[_PeriodSlot],
) -> int | None:
    if raw_period is not None:
        return raw_period
    start_min = clock_to_minutes(time_start)
    if start_min is None:
        return None
    for slot in period_slots:
        if slot.idx is None:
            continue
        ps = clock_to_minutes(slot.start)
        pe = clock_to_minutes(slot.end)
        if ps is not None and start_min == ps:
            return slot.idx
        if ps is not None and pe is not None and ps <= start_min < pe:
            return slot.idx
    return None


def _safe_room_key(
    label: str,
    aliases: dict[str, str],
    warnings: list[str],
    cycle_warned: list[bool],
) -> str:
    try:
        return room_policy.room_key(label, aliases)
    except ValueError:
        if not cycle_warned[0]:
            warnings.append(
                "Cyclic room alias configuration detected; fell back to raw normalized room labels."
            )
            cycle_warned[0] = True
        return " ".join(str(label).upper().split())


def _extract_config_maps(
    config: dict[str, Any] | None,
) -> tuple[
    list[dict[str, Any]],
    dict[str, str],
    dict[str, str],
    set[str],
    dict[str, int],
    bool,
    dict[str, set[int]],
]:
    cfg = config if isinstance(config, dict) else {}
    settings = cfg.get("settings") if isinstance(cfg.get("settings"), dict) else {}

    periods_raw = settings.get("periods") or cfg.get("periods") or []
    periods = [p for p in periods_raw if isinstance(p, dict)]

    teacher_names: dict[str, str] = {}
    for t in cfg.get("teachers") or []:
        if isinstance(t, dict) and t.get("acronym") and t.get("full_name"):
            teacher_names[str(t["acronym"]).strip().upper()] = str(t["full_name"]).strip()
    if isinstance(cfg.get("teacher_names"), dict):
        for k, v in cfg["teacher_names"].items():
            if k and v:
                teacher_names[str(k).strip().upper()] = str(v).strip()

    room_aliases: dict[str, str] = {}
    raw_aliases = cfg.get("room_aliases") or settings.get("room_aliases") or {}
    if isinstance(raw_aliases, dict):
        for k, v in raw_aliases.items():
            if k and v:
                room_aliases[str(k).strip().upper()] = str(v).strip().upper()

    unavailable_rooms: set[str] = set()
    raw_unavail = cfg.get("unavailable_rooms") or settings.get("unavailable_rooms") or []
    if isinstance(raw_unavail, (list, set, tuple)):
        for r in raw_unavail:
            if r:
                unavailable_rooms.add(str(r).strip())

    semester_map: dict[str, int] = {}
    raw_smap = settings.get("semester_map") or cfg.get("semester_map") or {}
    if isinstance(raw_smap, dict):
        for k, v in raw_smap.items():
            try:
                semester_map[str(k).strip()] = int(v)
            except (TypeError, ValueError):
                continue

    friday_no_p4 = bool(
        settings.get("friday_no_p4", cfg.get("friday_no_p4", True))
    )

    blocked_periods: dict[str, set[int]] = {}
    raw_blocked = settings.get("blocked_periods") or cfg.get("blocked_periods") or {}
    if isinstance(raw_blocked, dict):
        for day_key, p_list in raw_blocked.items():
            if isinstance(p_list, (list, set, tuple)):
                parsed_set: set[int] = set()
                for p_val in p_list:
                    try:
                        parsed_set.add(int(p_val))
                    except (TypeError, ValueError):
                        continue
                if parsed_set:
                    blocked_periods[str(day_key).strip()] = parsed_set

    return (
        periods,
        teacher_names,
        room_aliases,
        unavailable_rooms,
        semester_map,
        friday_no_p4,
        blocked_periods,
    )


def _validate_rows(
    all_rows: list[dict[str, Any]],
    *,
    room_aliases: dict[str, str],
    unavailable_rooms: set[str],
    friday_no_p4: bool,
    blocked_periods: dict[str, set[int]],
    p4_window: tuple[int, int] | None,
    warnings: list[str],
) -> dict[str, Any]:
    cycle_warned = [False]

    def physical(label: str) -> str:
        return _safe_room_key(label, room_aliases, warnings, cycle_warned)

    unavailable_keys = {physical(r) for r in unavailable_rooms if r.strip()}

    teacher_slots: dict[str, list[tuple[int, int, dict[str, Any]]]] = {}
    cohort_slots: dict[str, list[tuple[int, int, dict[str, Any]]]] = {}
    room_slots: dict[str, list[tuple[int, int, dict[str, Any]]]] = {}

    invalid_times = 0
    pending_faculty = 0
    unresolved_faculty_names = 0
    unavailable_assignments = 0
    blocked_period_violations = 0

    details: dict[str, list[dict[str, Any]]] = {
        "teacher_clashes": [],
        "cohort_clashes": [],
        "room_clashes": [],
        "invalid_time_slots": [],
        "unavailable_room_assignments": [],
        "blocked_period_violations": [],
    }

    for row in all_rows:
        start = clock_to_minutes(row["time_start"])
        end = clock_to_minutes(row["time_end"])
        if start is None or end is None or start < 0 or end > 1440 or end <= start:
            invalid_times += 1
            details["invalid_time_slots"].append(
                {
                    "day": row["day"],
                    "course": row["subject_code"],
                    "cohort": f"{row['batch']}-{row['section']}",
                    "time_start": row["time_start"],
                    "time_end": row["time_end"],
                }
            )
            continue

        # Blocked period & Friday P4 Jummah check
        day_blocked = set(blocked_periods.get(row["day"], set()))
        if friday_no_p4 and row["day"] == "Friday":
            day_blocked.add(4)
        row_period = row.get("period")
        is_blocked = False
        if row_period is not None and row_period in day_blocked:
            is_blocked = True
        elif (
            friday_no_p4
            and row["day"] == "Friday"
            and p4_window is not None
            and start < p4_window[1]
            and p4_window[0] < end
        ):
            is_blocked = True

        if is_blocked:
            blocked_period_violations += 1
            details["blocked_period_violations"].append(
                {
                    "day": row["day"],
                    "period": row_period or 4,
                    "course": row["subject_code"],
                    "cohort": f"{row['batch']}-{row['section']}",
                    "reason": "Friday P4 Jummah break"
                    if row["day"] == "Friday" and (row_period == 4 or row_period is None)
                    else "Blocked period",
                }
            )

        teachers_list = row.get("teachers") or []
        t_code = row.get("teacher_code")
        supplied_name = (
            re.sub(r"\s+", " ", row["teacher_name"].strip()).upper()
            if row.get("teacher_name")
            else ""
        )

        if teachers_list:
            for tc in teachers_list:
                teacher_slots.setdefault(f"{row['day']}|code:{tc}", []).append(
                    (start, end, row)
                )
        elif t_code:
            teacher_slots.setdefault(f"{row['day']}|code:{t_code}", []).append(
                (start, end, row)
            )
        elif supplied_name:
            teacher_slots.setdefault(f"{row['day']}|name:{supplied_name}", []).append(
                (start, end, row)
            )
            unresolved_faculty_names += 1
        else:
            pending_faculty += 1

        # B+C joint-section membership overlap
        groups = {s.strip() for s in str(row["section"]).split("+") if s.strip()}
        for group in groups:
            cohort_slots.setdefault(f"{row['day']}|{row['batch']}|{group}", []).append(
                (start, end, row)
            )

        room_raw = str(row["room"]).strip()
        if room_raw.upper() != "TBA":
            r_key = physical(room_raw)
            room_slots.setdefault(f"{row['day']}|{r_key}", []).append((start, end, row))
            if r_key in unavailable_keys:
                unavailable_assignments += 1
                details["unavailable_room_assignments"].append(
                    {
                        "day": row["day"],
                        "room": room_raw,
                        "canonical_room": r_key,
                        "course": row["subject_code"],
                        "cohort": f"{row['batch']}-{row['section']}",
                    }
                )

    def count_clashes(
        bucket: dict[str, list[tuple[int, int, dict[str, Any]]]],
        detail_key: str,
    ) -> int:
        total = 0
        for resource_key, intervals in bucket.items():
            intervals.sort(key=lambda item: item[0])
            for i in range(len(intervals)):
                s_i, e_i, row_i = intervals[i]
                for j in range(i + 1, len(intervals)):
                    s_j, e_j, row_j = intervals[j]
                    if s_j >= e_i:
                        break
                    if s_i < e_j:
                        total += 1
                        details[detail_key].append(
                            {
                                "resource": resource_key,
                                "day": row_i["day"],
                                "first": f"{row_i['subject_code']} ({row_i['batch']}-{row_i['section']})",
                                "second": f"{row_j['subject_code']} ({row_j['batch']}-{row_j['section']})",
                            }
                        )
        return total

    teacher_clashes = count_clashes(teacher_slots, "teacher_clashes")
    cohort_clashes = count_clashes(cohort_slots, "cohort_clashes")
    room_clashes = count_clashes(room_slots, "room_clashes")

    non_empty_details = {k: v for k, v in details.items() if v}

    ok = (
        unavailable_assignments == 0
        and invalid_times == 0
        and teacher_clashes == 0
        and cohort_clashes == 0
        and room_clashes == 0
        and blocked_period_violations == 0
    )

    return {
        "teacher_clashes": teacher_clashes,
        "cohort_clashes": cohort_clashes,
        "room_clashes": room_clashes,
        "invalid_time_slots": invalid_times,
        "pending_faculty_assignments": pending_faculty,
        "unresolved_faculty_names": unresolved_faculty_names,
        "unavailable_room_assignments": unavailable_assignments,
        "blocked_period_violations": blocked_period_violations,
        "details": non_empty_details,
        "ok": ok,
    }


def parse_rendered_workbook(
    file_bytes: bytes,
    *,
    config: dict[str, Any] | None = None,
    subject_titles: dict[str, str] | None = None,
) -> dict[str, Any]:
    """Parse a rendered Leading University 7-day or tabular routine `.xlsx` workbook.

    Strictly read-only and non-mutating: returns structured rows, service_rows,
    warnings, stats, validation, detected_format, and sheet_names.
    """
    (
        periods_cfg,
        teacher_names,
        config_aliases,
        unavailable_rooms,
        semester_map,
        friday_no_p4,
        blocked_periods,
    ) = _extract_config_maps(config)

    normalized_titles = {
        str(k).strip().upper(): str(v).strip()
        for k, v in (subject_titles or {}).items()
        if k and v
    }

    period_by_col = _periods_by_column(periods_cfg)
    configured_columns = {
        str(raw["col"]).strip().upper()
        for raw in periods_cfg
        if raw.get("start") is not None
        and raw.get("end") is not None
        and raw.get("col") is not None
    }

    with zipfile.ZipFile(io.BytesIO(file_bytes), "r") as zf:
        shared_strings = _read_shared_strings(zf)
        sheet_entries = _read_sheet_paths(zf)
        sheet_names = [name for name, _ in sheet_entries]
        sheet_paths = dict(sheet_entries)

        # Match day sheets in canonical week order first, then fuzzy day names
        day_sheets: dict[str, str] = {}
        used_paths: set[str] = set()
        for day in WEEK_DAYS:
            if day in sheet_paths:
                day_sheets[day] = sheet_paths[day]
                used_paths.add(sheet_paths[day])
        for name, path in sheet_entries:
            if path in used_paths:
                continue
            inferred = _day_from_text(name)
            if inferred and inferred not in day_sheets:
                day_sheets[inferred] = path
                used_paths.add(path)

        raw_rows: list[_RawRoutineCell] = []
        day_warnings: list[str] = []
        discovered_aliases: dict[str, str] = {}
        sheets_parsed = 0

        for day, path in day_sheets.items():
            xml_bytes = _find_zip_member(zf, path)
            if xml_bytes is None:
                day_warnings.append(f'Worksheet file for "{day}" was missing.')
                continue
            parsed = _parse_day_sheet(
                day=day,
                xml_bytes=xml_bytes,
                shared_strings=shared_strings,
                period_by_col=period_by_col,
                configured_columns=configured_columns,
                warnings=day_warnings,
                discovered_aliases=discovered_aliases,
            )
            if parsed:
                sheets_parsed += 1
            raw_rows.extend(parsed)

        detected_format = "UniVerse day sheets"
        warnings = day_warnings

        if not raw_rows:
            tabular_warnings: list[str] = []
            tabular_rows: list[_RawRoutineCell] = []
            tabular_sheets_parsed = 0
            for name, path in sheet_entries:
                xml_bytes = _find_zip_member(zf, path)
                if xml_bytes is None:
                    continue
                grid = _read_grid(xml_bytes, shared_strings)
                if not grid:
                    continue
                discovered_aliases.update(_extract_room_alias_footers(grid))
                inferred_day = _day_from_text(name)
                header = _find_tabular_header(grid, inferred_day=inferred_day)
                if header is None:
                    continue
                header_row, header_cols = header
                sheet_found = False
                for row_no in sorted(r for r in grid.keys() if r > header_row):
                    cells = grid[row_no]
                    if all(not _clean_text(v) for v in cells.values()):
                        continue
                    parsed_row = _parse_tabular_row(
                        cells=cells,
                        header_cols=header_cols,
                        row_no=row_no,
                        inferred_day=inferred_day,
                        warnings=tabular_warnings,
                    )
                    if parsed_row is not None:
                        tabular_rows.append(parsed_row)
                        sheet_found = True
                if sheet_found:
                    tabular_sheets_parsed += 1

            if not tabular_rows:
                raise ValueError(
                    "No routine rows were found. Use Leading University day sheets or tabular "
                    "columns like Day, Time/Start/End, Course Code, Teacher, Room, Batch, Section."
                )

            raw_rows = tabular_rows
            warnings = tabular_warnings
            sheets_parsed = tabular_sheets_parsed
            detected_format = "Tabular workbook"

    # Merge footer-discovered aliases with explicit config aliases (config takes priority)
    merged_aliases = {**discovered_aliases, **config_aliases}

    numeric_batches = [int(r.batch) for r in raw_rows if r.batch.isdigit()]
    max_batch = max(numeric_batches) if numeric_batches else None
    period_slot_list = list(period_by_col.values())

    rows: list[dict[str, Any]] = []
    service_rows: list[dict[str, Any]] = []

    for idx, raw in enumerate(raw_rows):
        subject = (
            raw.subject
            or normalized_titles.get(raw.subject_code)
            or raw.subject_code
        )
        t_code = raw.teacher_code if raw.teacher_code else None
        t_name = raw.teacher_name or (teacher_names.get(t_code) if t_code else None)
        semester = (
            raw.semester
            if raw.semester is not None
            else _semester_for(raw.batch, max_batch, semester_map)
        )
        is_service = _is_service_row(raw.batch, raw.section, raw.explicit_service)
        period_idx = _infer_period_idx(raw.period, raw.time_start, period_slot_list)
        teachers_list = list(raw.teachers) if raw.teachers else ([t_code] if t_code else [])

        row_dict: dict[str, Any] = {
            "id": f"upload-{idx}",
            "day": raw.day,
            "time_start": raw.time_start,
            "time_end": raw.time_end,
            "subject": subject,
            "subject_code": raw.subject_code,
            "teacher_name": t_name,
            "teacher_code": t_code,
            "teachers": teachers_list,
            "teacher_state": "assigned" if teachers_list else "pending",
            "room": raw.room,
            "batch": raw.batch,
            "section": raw.section,
            "semester": semester,
            "is_active": True,
            "is_service": is_service,
            "is_lab": _is_lab_course(raw.subject_code, subject),
        }
        if period_idx is not None:
            row_dict["period"] = period_idx

        if is_service:
            service_rows.append(row_dict)
        else:
            rows.append(row_dict)

    all_rows = rows + service_rows

    # Determine P4 time window for Friday Jummah validation
    p4_slot = next((s for s in period_slot_list if s.idx == 4), None)
    if p4_slot is not None:
        p4_start = clock_to_minutes(p4_slot.start)
        p4_end = clock_to_minutes(p4_slot.end)
        p4_window = (p4_start, p4_end) if (p4_start is not None and p4_end is not None) else None
    else:
        p4_window = (13 * 60 + 10, 14 * 60 + 25)

    validation = _validate_rows(
        all_rows,
        room_aliases=merged_aliases,
        unavailable_rooms=unavailable_rooms,
        friday_no_p4=friday_no_p4,
        blocked_periods=blocked_periods,
        p4_window=p4_window,
        warnings=warnings,
    )

    pending = int(validation["pending_faculty_assignments"])
    if pending > 0:
        warnings.append(
            f"{pending} class(es) have faculty pending; course, time and room retained."
        )
    named_unresolved = int(validation["unresolved_faculty_names"])
    if named_unresolved > 0:
        warnings.append(
            f"{named_unresolved} class(es) name a faculty member without a resolved code; "
            "supplied name retained without guessing initials."
        )

    cohorts = {f"{r['batch']}-{r['section']}" for r in all_rows}
    teachers = {
        tc
        for r in all_rows
        for tc in (r.get("teachers") or [])
        if tc
    }
    days = {r["day"] for r in all_rows}

    return {
        "rows": rows,
        "service_rows": service_rows,
        "warnings": warnings,
        "stats": {
            "meetings": len(rows),
            "service_meetings": len(service_rows),
            "total_meetings": len(all_rows),
            "cohorts": len(cohorts),
            "teachers": len(teachers),
            "days": len(days),
            "sheets_parsed": sheets_parsed,
        },
        "validation": validation,
        "detected_format": detected_format,
        "sheet_names": sheet_names,
    }
