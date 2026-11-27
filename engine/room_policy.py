"""Room identity keys, pool predicates, and slot-window matching helpers.

No historical room-purpose or semester rule is a permanent default.
"""
from __future__ import annotations

import re
from typing import Any


def room_key(label: str, aliases: dict | None = None) -> str:
    def normalize(value: object) -> str:
        return " ".join(str(value).upper().split())

    key = normalize(label)
    mapping = {normalize(k): normalize(v) for k, v in (aliases or {}).items()}
    seen = set()
    while key in mapping and mapping[key] != key:
        if key in seen:
            raise ValueError("Cyclic room aliases")
        seen.add(key)
        key = mapping[key]
    return key


def is_ecl_room(label: str, aliases: dict | None = None) -> bool:
    """True if the room's canonical physical identity is an ECL laboratory."""
    key = room_key(label, aliases)
    return bool(re.match(r"^ECL([-_ \d]|$)", key))


def is_physics_lab_room(room: dict[str, Any] | str, aliases: dict | None = None) -> bool:
    """True if the room represents a Physics laboratory (R11).

    Honors explicit `room_pool_role == 'physics_lab'` first, rejects explicit
    non-physics roles (`cse_lab`, `ecl_lab`, `gallery`, `other`), and falls back
    to canonical room name matching `PHY[SICS] LAB` for legacy configs.
    """
    if isinstance(room, dict):
        role = str(room.get("room_pool_role") or "").strip().lower()
        if role == "physics_lab":
            return True
        if "room_pool_role" in room and role in {"cse_lab", "ecl_lab", "gallery", "other"}:
            return False
        if not room.get("is_lab", True):
            return False
        label = str(room.get("name") or "")
    else:
        label = str(room)

    key = room_key(label, aliases)
    return bool(re.match(r"^(?:PHY(?:SICS)?[-_ ]*LAB)\b", key))


def is_physics_lab_course(
    code: str,
    physics_lab_course_codes: set[str] | tuple[str, ...] | list[str] = (),
) -> bool:
    """True strictly when `code` is explicitly declared in `physics_lab_course_codes` (R11).

    Never guesses from broad `PHY` prefixes or course-code parity.
    """
    clean = str(code or "").strip().upper()
    explicit = {
        str(c).strip().upper()
        for c in (physics_lab_course_codes or ())
        if str(c).strip()
    }
    return bool(clean and clean in explicit)


def is_eee_course(code: str, dept: str | None = None) -> bool:
    """True if the course is an EEE-related course (never misclassifies PHY-* courses)."""
    clean_code = str(code).strip().upper()
    if clean_code.startswith("PHY"):
        return False
    clean_dept = str(dept).strip().upper() if dept else ""
    return clean_code.startswith("EEE") or clean_dept == "EEE"


def is_cse_course(code: str, dept: str | None = None) -> bool:
    """True if the course is a CSE course."""
    clean_code = str(code).strip().upper()
    clean_dept = str(dept).strip().upper() if dept else ""
    return clean_code.startswith("CSE") or clean_dept == "CSE"


VALID_ROOM_POOL_OVERRIDES = frozenset({"theory", "cse_lab", "ecl_lab", "physics_lab"})
_ROOM_POOL_TAG_RE = re.compile(r"\[pool:(theory|cse_lab|ecl_lab|physics_lab)\]", re.IGNORECASE)


def parse_room_pool_override(value: Any) -> str | None:
    """Parse an explicit room-pool override ('theory', 'cse_lab', 'ecl_lab', 'physics_lab').

    Accepts either a direct pool token or a structured `[pool:<pool>]` tag embedded
    inside a catalog course's `notes` field (zero-migration persistence).
    """
    if value is None:
        return None
    raw = str(value).strip().lower()
    if raw in VALID_ROOM_POOL_OVERRIDES:
        return raw
    m = _ROOM_POOL_TAG_RE.search(raw)
    if m:
        return m.group(1).lower()
    return None


def classify_lab_kind(
    code: str,
    dept: str | None = None,
    *,
    physics_lab_course_codes: set[str] | tuple[str, ...] | list[str] = (),
    is_physics_lab: bool = False,
    room_pool_override: str | None = None,
) -> str:
    """Single shared lab-pool classifier used by Phase 1 CP-SAT, Phase 2 room assignment, and Phase 3 validation.

    Returns one of: 'physics' (R11), 'ecl' (R10), or 'cse' (CSE Lab Pool for CSE-* and all other non-ECL/non-Physics labs).
    """
    override = parse_room_pool_override(room_pool_override)
    if override == "physics_lab":
        return "physics"
    if override == "ecl_lab":
        return "ecl"
    if override == "cse_lab":
        return "cse"
    if is_physics_lab or is_physics_lab_course(code, physics_lab_course_codes):
        return "physics"
    if is_eee_course(code, dept):
        return "ecl"
    return "cse"


def to_minutes(clock: str) -> float:
    """Convert HH:MM or HH:MM:SS into minutes since midnight."""
    match = re.fullmatch(r"\s*(\d{1,2}):(\d{2})(?::(\d{2}))?\s*", str(clock))
    if not match:
        raise ValueError(f"Period times must use HH:MM or HH:MM:SS (got {clock!r})")
    h, m, s = int(match[1]), int(match[2]), int(match[3] or 0)
    if h > 24 or m > 59 or s > 59 or (h == 24 and (m or s)):
        raise ValueError(f"Invalid clock boundary: {clock!r}")
    return h * 60 + m + s / 60.0


def _window_fields(window: Any) -> tuple[str, int | None, str | None, str | None]:
    if isinstance(window, dict):
        day = str(window.get("day") or "").strip()
        pidx = window.get("period_idx")
        start = str(window["start"]).strip() if window.get("start") else None
        end = str(window["end"]).strip() if window.get("end") else None
    else:
        day = str(getattr(window, "day", "") or "").strip()
        pidx = getattr(window, "period_idx", None)
        raw_s = getattr(window, "start", None)
        raw_e = getattr(window, "end", None)
        start = str(raw_s).strip() if raw_s else None
        end = str(raw_e).strip() if raw_e else None
    norm_pidx = int(pidx) if pidx is not None and not isinstance(pidx, bool) else None
    return day, norm_pidx, start, end


def slot_overlaps_window(
    window: Any,
    day_name: str,
    period_idx: int,
    period_meta: dict[str, Any] | None,
) -> bool:
    """True if `(day_name, period_idx)` overlaps `window` (for R4 external blocks)."""
    w_day, w_pidx, w_start, w_end = _window_fields(window)
    if w_day.casefold() != str(day_name).strip().casefold():
        return False
    if w_pidx is not None and w_pidx == int(period_idx):
        return True
    if w_start and w_end and period_meta:
        p_start = to_minutes(str(period_meta["start"]))
        p_end = to_minutes(str(period_meta["end"]))
        ws = to_minutes(w_start)
        we = to_minutes(w_end)
        return p_start < we and ws < p_end
    return False


def slot_within_window(
    window: Any,
    day_name: str,
    period_idx: int,
    period_meta: dict[str, Any] | None,
) -> bool:
    """True if `(day_name, period_idx)` fits wholly inside `window` (for R5/R8/R10/R11)."""
    w_day, w_pidx, w_start, w_end = _window_fields(window)
    if w_day.casefold() != str(day_name).strip().casefold():
        return False
    if w_pidx is not None:
        return w_pidx == int(period_idx)
    if w_start and w_end and period_meta:
        p_start = to_minutes(str(period_meta["start"]))
        p_end = to_minutes(str(period_meta["end"]))
        ws = to_minutes(w_start)
        we = to_minutes(w_end)
        return ws <= p_start and p_end <= we
    return False
