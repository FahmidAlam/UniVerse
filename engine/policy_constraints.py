"""Stage 5B R1-R16 & D1-D6 CP-SAT policy constraints, diagnostics, and validator.

Keeps committee policy modeling, grid/break topology, D6 structured conflict
diagnostics, and independent post-placement validation cleanly separated from
spreadsheet ingestion and FastAPI HTTP routing.
"""

from __future__ import annotations

import math
import re
from collections import defaultdict
from dataclasses import dataclass
from typing import Any

from ortools.sat.python import cp_model

import domain
from room_policy import (
    classify_lab_kind,
    is_cse_course,
    is_ecl_room,
    is_eee_course,
    is_physics_lab_course,
    is_physics_lab_room,
    parse_room_pool_override,
    room_key,
    slot_overlaps_window,
    slot_within_window,
    to_minutes,
)

MIN_MIDDAY_BREAK_MINUTES = 15.0

OUTCOME_OPTIMAL = "OPTIMAL"
OUTCOME_FEASIBLE = "FEASIBLE"
OUTCOME_INFEASIBLE = "INFEASIBLE"
OUTCOME_TIME_LIMIT = "TIME_LIMIT_EXHAUSTED"
OUTCOME_UNKNOWN = "UNKNOWN"
OUTCOME_INPUT_ERROR = "INPUT_ERROR"

ROUTE_BY_ENTITY = {
    "faculty": "/admin/timetable/faculty",
    "room": "/admin/timetable/rooms",
    "section": "/admin/timetable/batches",
    "course": "/admin/timetable/courses",
    "policy": "/admin/scheduling",
    "settings": "/admin/timetable/settings",
}


class SolverOutcomeError(RuntimeError):
    """RuntimeError subclass carrying structured D6 outcome & conflict payload."""

    def __init__(self, message: str, payload: dict[str, Any]) -> None:
        super().__init__(message)
        self.payload = payload
        self.outcome = payload.get("outcome", OUTCOME_INFEASIBLE)
        self.conflicts = payload.get("conflicts", [])


@dataclass(frozen=True)
class GridTopology:
    """Ordered teachable period indices and dynamic midday break structure (R15)."""

    regular_pidx: list[int]
    online_pidx: list[int]
    break_after_period: int | None
    day_teachable_pidx: dict[int, list[int]]
    pre_break_pidx: dict[int, list[int]]
    post_break_pidx: dict[int, list[int]]
    non_break_adj_pairs: dict[int, list[tuple[int, int]]]
    break_adj_pairs: dict[int, list[tuple[int, int]]]
    neighbors: dict[int, list[int]]


def atomic_groups(batch: Any, section: Any) -> set[tuple[str, str]]:
    """Expand joint sections (e.g. `B+C`) into atomic `(batch, section)` members."""
    b_str = str(batch)
    raw_sec = str(section or "").strip()
    if not raw_sec:
        return {(b_str, "")}
    return {(b_str, member.strip()) for member in raw_sec.split("+") if member.strip()}


def build_grid_topology(
    days: list[str],
    periods: list[dict[str, Any]],
    online_periods: set[int],
    blocked_periods: dict[str, set[int]],
    break_after_period: int | None = None,
) -> GridTopology:
    """Compute teachable slot order and dynamic midday break topology from config."""
    regular = sorted(
        (p for p in periods if int(p["idx"]) not in online_periods),
        key=lambda p: to_minutes(str(p["start"])),
    )
    online = sorted(
        (p for p in periods if int(p["idx"]) in online_periods),
        key=lambda p: to_minutes(str(p["start"])),
    )
    regular_pidx = [int(p["idx"]) for p in regular]
    online_pidx = [int(p["idx"]) for p in online]

    resolved_break: int | None = None
    if break_after_period is not None and int(break_after_period) in regular_pidx[:-1]:
        resolved_break = int(break_after_period)
    elif len(regular) >= 2:
        best_gap = 0.0
        for prev, nxt in zip(regular, regular[1:]):
            gap = to_minutes(str(nxt["start"])) - to_minutes(str(prev["end"]))
            if gap >= MIN_MIDDAY_BREAK_MINUTES and gap > best_gap:
                best_gap = gap
                resolved_break = int(prev["idx"])

    break_pos = (
        regular_pidx.index(resolved_break)
        if resolved_break is not None and resolved_break in regular_pidx
        else None
    )

    day_teachable_pidx: dict[int, list[int]] = {}
    pre_break_pidx: dict[int, list[int]] = {}
    post_break_pidx: dict[int, list[int]] = {}
    non_break_adj_pairs: dict[int, list[tuple[int, int]]] = {}
    break_adj_pairs: dict[int, list[tuple[int, int]]] = {}
    global_neighbors: dict[int, set[int]] = {int(p["idx"]): set() for p in periods}

    for di, dname in enumerate(days):
        day_blocked = blocked_periods.get(dname, set())
        base_seq = regular_pidx if regular_pidx else online_pidx
        seq = [p for p in base_seq if p not in day_blocked]
        day_teachable_pidx[di] = seq

        if break_pos is not None and regular_pidx:
            pre_set = set(regular_pidx[: break_pos + 1])
            post_set = set(regular_pidx[break_pos + 1 :])
            pre_break_pidx[di] = [p for p in seq if p in pre_set]
            post_break_pidx[di] = [p for p in seq if p in post_set]
        else:
            pre_break_pidx[di] = list(seq)
            post_break_pidx[di] = []

        nb_pairs: list[tuple[int, int]] = []
        br_pairs: list[tuple[int, int]] = []
        for idx_a, idx_b in zip(regular_pidx, regular_pidx[1:]):
            if idx_a in day_blocked or idx_b in day_blocked:
                continue
            if resolved_break is not None and idx_a == resolved_break:
                br_pairs.append((idx_a, idx_b))
            else:
                nb_pairs.append((idx_a, idx_b))
                global_neighbors.setdefault(idx_a, set()).add(idx_b)
                global_neighbors.setdefault(idx_b, set()).add(idx_a)

        non_break_adj_pairs[di] = nb_pairs
        break_adj_pairs[di] = br_pairs

    neighbors = {p: sorted(nbs) for p, nbs in global_neighbors.items()}
    return GridTopology(
        regular_pidx=regular_pidx,
        online_pidx=online_pidx,
        break_after_period=resolved_break,
        day_teachable_pidx=day_teachable_pidx,
        pre_break_pidx=pre_break_pidx,
        post_break_pidx=post_break_pidx,
        non_break_adj_pairs=non_break_adj_pairs,
        break_adj_pairs=break_adj_pairs,
        neighbors=neighbors,
    )


def make_conflict(
    *,
    rule: str,
    code: str,
    entity_type: str,
    entity_id: str,
    message: str,
    proven: bool,
    severity: str = "blocker",
    suggested_route: str | None = None,
) -> dict[str, Any]:
    return {
        "rule": rule,
        "severity": severity,
        "code": code,
        "entity_type": entity_type,
        "entity_id": entity_id,
        "message": message,
        "suggested_route": suggested_route or ROUTE_BY_ENTITY.get(entity_type, "/admin/scheduling"),
        "proven": bool(proven),
    }


def effective_physics_codes(cfg: dict[str, Any]) -> set[str]:
    codes: set[str] = set()
    policy: domain.CommitteePolicySnapshot | None = cfg.get("committee_policy")
    if policy is not None:
        codes.update(str(c).strip().upper() for c in policy.physics_lab_course_codes if str(c).strip())
    for c_code in cfg.get("physics_lab_course_codes") or ():
        if str(c_code).strip():
            codes.add(str(c_code).strip().upper())
    for c_code, c_meta in (cfg.get("courses_catalog") or {}).items():
        if isinstance(c_meta, dict) and c_meta.get("is_physics_lab"):
            codes.add(str(c_code).strip().upper())
    return codes


def room_is_open_at(
    room_name: str,
    day_name: str,
    period_idx: int,
    pmeta: dict[int, dict[str, Any]],
    cfg: dict[str, Any],
) -> bool:
    """True when `room_name` is available at `(day_name, period_idx)` under R10/R11."""
    meta = (cfg.get("room_metadata") or {}).get(room_name) or {}
    avail = meta.get("available_slots")
    role = str(meta.get("room_pool_role") or "").strip().lower()
    if avail:
        pm = pmeta.get(int(period_idx))
        return any(slot_within_window(w, day_name, int(period_idx), pm) for w in avail)
    # If `available_slots` is explicitly empty on an ECL/Physics room, treat as zero availability.
    if "available_slots" in meta and role in ("ecl_lab", "physics_lab"):
        return False
    return True


def room_fits_students(room_name: str, students: int | None, cfg: dict[str, Any]) -> bool:
    if students is None:
        return True
    cap = (cfg.get("room_metadata") or {}).get(room_name, {}).get("capacity")
    return cap is None or int(students) <= int(cap)


def resolved_room_pools(cfg: dict[str, Any]) -> tuple[list[str], list[str], list[str], list[str], list[str]]:
    """Return `(lab_rooms, ecl_rooms, phy_rooms, cse_rooms, theory_rooms)` with raw-config fallback."""
    aliases = cfg.get("room_aliases") or {}
    lab_rooms = list(cfg.get("lab_rooms") or [])
    theory_rooms = list(cfg.get("theory_rooms") or [])
    room_meta = cfg.get("room_metadata") or {}

    if cfg.get("ecl_lab_rooms") is not None:
        ecl_rooms = list(cfg["ecl_lab_rooms"])
    else:
        ecl_rooms = [
            r for r in lab_rooms
            if (str(room_meta.get(r, {}).get("room_pool_role") or "").lower() == "ecl_lab")
            or (str(room_meta.get(r, {}).get("room_pool_role") or "general").lower() == "general" and is_ecl_room(r, aliases))
        ]
    ecl_set = set(ecl_rooms)

    if cfg.get("physics_lab_rooms") is not None:
        phy_rooms = list(cfg["physics_lab_rooms"])
    else:
        phy_rooms = [
            r for r in lab_rooms
            if r not in ecl_set and is_physics_lab_room(room_meta.get(r, r), aliases)
        ]
    phy_set = set(phy_rooms)

    if cfg.get("cse_lab_rooms") is not None:
        cse_rooms = list(cfg["cse_lab_rooms"])
    else:
        cse_rooms = [r for r in lab_rooms if r not in ecl_set and r not in phy_set]

    return lab_rooms, ecl_rooms, phy_rooms, cse_rooms, theory_rooms


def offering_room_pool(
    offering: dict[str, Any],
    cfg: dict[str, Any],
    physics_codes: set[str],
) -> tuple[list[str], str]:
    """Return `(eligible_room_names, pool_kind_label)` for an offering."""
    is_lab = bool(offering.get("is_lab"))
    code = str(offering.get("code") or "").strip().upper()
    dept = offering.get("course_dept")
    lab_rooms, ecl_rooms, physics_rooms, cse_rooms, theory_rooms = resolved_room_pools(cfg)

    if is_lab:
        lab_kind = classify_lab_kind(
            code,
            dept,
            physics_lab_course_codes=physics_codes,
            is_physics_lab=bool(offering.get("is_physics_lab")),
            room_pool_override=offering.get("room_pool_override"),
        )
        if lab_kind == "physics":
            return list(physics_rooms), "Physics lab"
        if lab_kind == "ecl":
            return list(ecl_rooms), "ECL lab"
        return (list(cse_rooms) if cse_rooms else list(lab_rooms)), "CSE lab"
    return list(theory_rooms), "theory"


def apply_policy_to_dataset(dataset: dict[str, Any], cfg: dict[str, Any]) -> dict[str, Any]:
    """Enrich offerings with Gate C catalogs and R12/R13 session counts without mutating source bytes."""
    courses_catalog: dict[str, dict[str, Any]] = cfg.get("courses_catalog") or {}
    course_room_overrides: dict[str, str] = cfg.get("course_room_overrides") or {}
    sections_catalog: dict[tuple[str, str], dict[str, Any]] = cfg.get("sections_catalog") or {}
    policy: domain.CommitteePolicySnapshot | None = cfg.get("committee_policy")
    physics_codes = effective_physics_codes(cfg)
    weeks = max(1, int(cfg.get("weeks_in_term", 14)))

    offerings = [dict(o) for o in dataset.get("offerings", [])]
    warnings = list(dataset.get("warnings") or [])
    policy_warnings = list(dataset.get("policy_warnings") or [])

    changed = False
    for o in offerings:
        code = str(o.get("code") or "").strip().upper()
        cat = courses_catalog.get(code)
        explicit_pool = parse_room_pool_override(course_room_overrides.get(code))
        if explicit_pool is None and cat:
            explicit_pool = (
                parse_room_pool_override(cat.get("room_pool"))
                or parse_room_pool_override(cat.get("room_pool_override"))
                or parse_room_pool_override(cat.get("notes"))
            )

        if cat:
            if o.get("credit") is None and cat.get("credit") is not None:
                o["credit"] = float(cat["credit"])
            if not o.get("course_dept") and cat.get("dept_code"):
                o["course_dept"] = cat["dept_code"]

        if explicit_pool is not None:
            o["room_pool_override"] = explicit_pool
            if explicit_pool == "theory":
                o["is_lab"] = False
                o["is_physics_lab"] = False
            elif explicit_pool == "physics_lab":
                o["is_lab"] = True
                o["is_physics_lab"] = True
            else:
                o["is_lab"] = True
                o["is_physics_lab"] = False
            changed = True
        elif cat:
            if cat.get("class_type") in ("lab", "theory"):
                o["is_lab"] = cat["class_type"] == "lab"
                if cat["class_type"] == "theory":
                    o["is_physics_lab"] = False
                changed = True
            if cat.get("is_physics_lab") or cat.get("requires_physics_lab"):
                o["is_physics_lab"] = True
                o["is_lab"] = True
                changed = True

        if (
            o.get("room_pool_override") not in ("theory", "cse_lab", "ecl_lab")
            and is_physics_lab_course(code, physics_codes)
        ):
            o["is_physics_lab"] = True
            o["is_lab"] = True

        if o.get("students") is None:
            sec_key = (str(o.get("batch") or "").strip(), str(o.get("section") or "").strip().upper())
            sec_meta = sections_catalog.get(sec_key)
            if sec_meta and sec_meta.get("student_count") is not None:
                o["students"] = int(sec_meta["student_count"])

        if policy is not None:
            credit = o.get("credit")
            is_lab = bool(o.get("is_lab"))
            is_service = bool(o.get("is_service"))
            dept = o.get("course_dept")
            old_req = int(o.get("required_sessions", 2))
            classes_total = o.get("classes_total")
            source_natural = (
                max(1, math.ceil(int(classes_total) / weeks))
                if classes_total is not None and int(classes_total) > 0
                else None
            )

            if is_lab and credit is not None:
                cr = float(credit)
                if abs(cr - 1.0) < 1e-6 or abs(cr - 1.5) < 1e-6:
                    expected = 2
                    if (source_natural is not None and source_natural != expected) or old_req != expected:
                        msg = (
                            f"{code} {o['cohort']}: R12 requires {expected} weekly classes for a "
                            f"{cr}-credit sessional (distribution had {source_natural or old_req}/wk)."
                        )
                        warnings.append(msg)
                        policy_warnings.append(
                            make_conflict(
                                rule="R12",
                                code="r12_credit_count_override",
                                entity_type="course",
                                entity_id=code,
                                message=msg,
                                severity="warning",
                                proven=True,
                            )
                        )
                    if old_req != expected:
                        o["required_sessions"] = expected
                        o["sessions_basis"] = "r12_credit_policy"
                        changed = True
                elif abs(cr - 2.0) < 1e-6:
                    expected = 3
                    if (source_natural is not None and source_natural != expected) or old_req != expected:
                        msg = (
                            f"{code} {o['cohort']}: R12 requires {expected} weekly classes for a "
                            f"2.0-credit sessional (distribution had {source_natural or old_req}/wk)."
                        )
                        warnings.append(msg)
                        policy_warnings.append(
                            make_conflict(
                                rule="R12",
                                code="r12_credit_count_override",
                                entity_type="course",
                                entity_id=code,
                                message=msg,
                                severity="warning",
                                proven=True,
                            )
                        )
                    if old_req != expected:
                        o["required_sessions"] = expected
                        o["sessions_basis"] = "r12_credit_policy"
                        changed = True
            elif (not is_lab) and (not is_service) and is_cse_course(code, dept) and credit is not None:
                cr = float(credit)
                if policy.low_credit_cse_theory_consecutive and any(
                    abs(cr - c) < 1e-6 for c in (1.0, 1.5, 2.0)
                ):
                    expected = 2
                    if (source_natural is not None and source_natural != expected) or old_req != expected:
                        msg = (
                            f"{code} {o['cohort']}: R13/D2 requires {expected} consecutive weekly classes "
                            f"for a {cr}-credit CSE theory course (distribution had {source_natural or old_req}/wk)."
                        )
                        warnings.append(msg)
                        policy_warnings.append(
                            make_conflict(
                                rule="R13",
                                code="r13_credit_count_override",
                                entity_type="course",
                                entity_id=code,
                                message=msg,
                                severity="warning",
                                proven=True,
                            )
                        )
                    if old_req != expected:
                        o["required_sessions"] = expected
                        o["sessions_basis"] = "r13_credit_policy"
                        changed = True
                elif abs(cr - 3.0) < 1e-6 and o.get("sessions_basis") == "fixed" and source_natural is not None:
                    if old_req != source_natural:
                        o["required_sessions"] = source_natural
                        o["sessions_basis"] = "classes_total"
                        changed = True

    sessions = list(dataset.get("sessions") or [])
    if changed or courses_catalog:
        new_sessions: list[dict[str, Any]] = []
        sid = 0
        for o in offerings:
            teachers = list(o.get("teachers") or [])
            primary = teachers[0] if teachers and not o.get("pending_faculty_source_rows") else None
            for occ in range(1, int(o["required_sessions"]) + 1):
                new_sessions.append(
                    {
                        "sid": sid,
                        "oid": o["oid"],
                        "code": o["code"],
                        "title": o["title"],
                        "teacher": primary,
                        "teachers": teachers,
                        "batch": o["batch"],
                        "section": o["section"],
                        "cohort": o["cohort"],
                        "is_lab": bool(o.get("is_lab")),
                        "is_service": bool(o.get("is_service")),
                        "occurrence": occ,
                    }
                )
                sid += 1
        sessions = new_sessions

    out = dict(dataset)
    out["offerings"] = offerings
    out["sessions"] = sessions
    out["warnings"] = warnings
    out["policy_warnings"] = policy_warnings
    return out


def check_presolve_inputs(
    dataset: dict[str, Any],
    cfg: dict[str, Any],
    days: list[str],
    periods: list[dict[str, Any]],
    pmeta: dict[int, dict[str, Any]],
) -> list[dict[str, Any]]:
    """Pre-CP-SAT deterministic INPUT_ERROR checks (R1, R5, R7, R10, R11, R15)."""
    conflicts: list[dict[str, Any]] = []

    if not periods:
        conflicts.append(
            make_conflict(
                rule="R15",
                code="no_usable_periods",
                entity_type="settings",
                entity_id="periods",
                message=(
                    "No usable periods in the configuration. Every configured period is "
                    "excluded — check Timetable Settings."
                ),
                proven=True,
            )
        )
        return conflicts

    policy: domain.CommitteePolicySnapshot | None = cfg.get("committee_policy")
    teacher_profiles: dict[str, dict[str, Any]] = cfg.get("teacher_profiles") or {}
    sessions = dataset.get("sessions") or []
    offerings = dataset.get("offerings") or []
    physics_codes = effective_physics_codes(cfg)

    assigned_teachers: dict[str, int] = defaultdict(int)
    for s in sessions:
        for t in (s.get("teachers") or ([s["teacher"]] if s.get("teacher") else [])):
            clean_t = str(t).strip().upper()
            if clean_t:
                assigned_teachers[clean_t] += 1
    for o in offerings:
        if o.get("pending_faculty_source_rows"):
            continue
        for t in (o.get("teachers") or ()):
            clean_t = str(t).strip().upper()
            if clean_t and clean_t not in assigned_teachers:
                assigned_teachers[clean_t] = max(1, int(o.get("required_sessions") or 1))

    auto_resolve = policy.auto_resolve_undeclared_off_days if policy is not None else True

    # R5: Guest faculty assigned to active sessions must declare non-empty available_slots
    for ac, profile in sorted(teacher_profiles.items()):
        if not profile.get("is_active", True):
            continue
        if assigned_teachers.get(ac, 0) == 0:
            continue
        emp = str(profile.get("employment_type") or "permanent").strip().lower()
        if emp == "guest":
            avail = profile.get("available_slots") or []
            if len(avail) == 0:
                conflicts.append(
                    make_conflict(
                        rule="R5",
                        code="guest_missing_availability",
                        entity_type="faculty",
                        entity_id=ac,
                        message=(
                            f"Guest faculty {ac} has 0 declared available slots but is assigned to "
                            f"{assigned_teachers[ac]} weekly session(s). Undeclared guest availability "
                            f"means zero open slots (R5)."
                        ),
                        proven=True,
                    )
                )

    # R7 / R6: Scope off-day checks strictly to assigned faculty; support Hybrid R7 auto-resolve
    for ac, profile in sorted(teacher_profiles.items()):
        if not profile.get("is_active", True):
            continue
        if assigned_teachers.get(ac, 0) == 0:
            continue
        emp = str(profile.get("employment_type") or "permanent").strip().lower()
        off_days = [d for d in (profile.get("off_days") or ()) if d in days]
        if emp == "permanent":
            if not (profile.get("explicit_employment_type", False) or policy is not None):
                continue
            allow_three = bool(profile.get("allow_three_off_days", False))
            if len(off_days) > 3 or (len(off_days) == 3 and not allow_three):
                conflicts.append(
                    make_conflict(
                        rule="R7",
                        code="permanent_invalid_off_days",
                        entity_type="faculty",
                        entity_id=ac,
                        message=(
                            f"Permanent faculty {ac} has {len(off_days)} configured off-day(s) "
                            f"(allow_three_off_days={allow_three}); R7/D3 requires 2 off-days or "
                            f"explicit authorization for 3 off-days."
                        ),
                        proven=True,
                    )
                )
            elif len(off_days) in (0, 1) and not auto_resolve:
                conflicts.append(
                    make_conflict(
                        rule="R7",
                        code="permanent_invalid_off_days",
                        entity_type="faculty",
                        entity_id=ac,
                        message=(
                            f"Permanent faculty {ac} has {len(off_days)} configured off-day(s) "
                            f"with auto_resolve_undeclared_off_days disabled; R7/D3 requires 2 declared off-days."
                        ),
                        proven=True,
                    )
                )
        elif emp == "adjunct":
            if days and set(days) <= set(off_days):
                conflicts.append(
                    make_conflict(
                        rule="R6",
                        code="adjunct_no_teachable_days",
                        entity_type="faculty",
                        entity_id=ac,
                        message=(
                            f"Adjunct faculty {ac} has all {len(days)} academic day(s) marked as off-days, "
                            f"leaving 0 teachable days for {assigned_teachers[ac]} assigned session(s) (R6)."
                        ),
                        proven=True,
                    )
                )

    # R1: Section weekend overrides validation (when passed via sections list or policy_snapshot)
    for sec in cfg.get("raw_section_overrides") or []:
        if not isinstance(sec, dict):
            continue
        raw_days = sec.get("weekend_override_days") or sec.get("weekend_days")
        if raw_days is not None and not domain.is_valid_consecutive_weekend(raw_days):
            label = f"{sec.get('batch', '?')}-{sec.get('section', '?')}"
            conflicts.append(
                make_conflict(
                    rule="R1",
                    code="invalid_section_weekend",
                    entity_type="section",
                    entity_id=label,
                    message=(
                        f"Section {label} declares non-consecutive weekend override {raw_days}; "
                        f"R1 requires 2 consecutive weekdays."
                    ),
                    proven=True,
                )
            )

    pidx = [int(p["idx"]) for p in periods]
    blocked = cfg.get("blocked_periods") or {}

    # R10: ECL labs must have open windows when EEE labs exist
    eee_lab_sessions = [
        s for s in sessions
        if s.get("is_lab")
        and not is_physics_lab_course(s.get("code", ""), physics_codes)
        and is_eee_course(
            s.get("code", ""),
            next((o.get("course_dept") for o in offerings if o["oid"] == s["oid"]), None),
        )
    ]
    if eee_lab_sessions:
        ecl_rooms = cfg.get("ecl_lab_rooms") or []
        open_ecl_slots = sum(
            1
            for r in ecl_rooms
            for dname in days
            for p in pidx
            if p not in blocked.get(dname, set()) and room_is_open_at(r, dname, p, pmeta, cfg)
        )
        if ecl_rooms and open_ecl_slots == 0:
            conflicts.append(
                make_conflict(
                    rule="R10",
                    code="ecl_lab_missing_windows",
                    entity_type="room",
                    entity_id=", ".join(ecl_rooms),
                    message=(
                        f"EEE laboratory course(s) require an ECL lab, but active ECL room(s) "
                        f"({', '.join(ecl_rooms)}) have 0 open available_slots (R10)."
                    ),
                    proven=True,
                )
            )

    # R11: Physics lab courses require active physics_lab room(s) with open windows
    physics_sessions = [
        s for s in sessions
        if s.get("is_lab") and is_physics_lab_course(s.get("code", ""), physics_codes)
    ]
    if physics_sessions:
        phy_rooms = cfg.get("physics_lab_rooms") or []
        if not phy_rooms:
            codes = sorted({str(s["code"]).upper() for s in physics_sessions})
            conflicts.append(
                make_conflict(
                    rule="R11",
                    code="physics_lab_no_room",
                    entity_type="room",
                    entity_id=", ".join(codes),
                    message=(
                        f"Physics lab course(s) {', '.join(codes)} require an active room with "
                        f"room_pool_role='physics_lab' (R11)."
                    ),
                    proven=True,
                )
            )
        else:
            open_phy_slots = sum(
                1
                for r in phy_rooms
                for dname in days
                for p in pidx
                if p not in blocked.get(dname, set()) and room_is_open_at(r, dname, p, pmeta, cfg)
            )
            if open_phy_slots == 0:
                conflicts.append(
                    make_conflict(
                        rule="R11",
                        code="physics_lab_missing_windows",
                        entity_type="room",
                        entity_id=", ".join(phy_rooms),
                        message=(
                            f"Physics lab room(s) ({', '.join(phy_rooms)}) have 0 open "
                            f"available_slots for bound Physics lab courses (R11)."
                        ),
                        proven=True,
                    )
                )

    return conflicts


def session_slot_allowed_by_teachers_and_rooms(
    session: dict[str, Any],
    offering: dict[str, Any],
    day_name: str,
    period_idx: int,
    pmeta: dict[int, dict[str, Any]],
    cfg: dict[str, Any],
    physics_codes: set[str],
) -> bool:
    """True if all attached teachers and at least one eligible room permit `(day_name, period_idx)`."""
    teacher_profiles: dict[str, dict[str, Any]] = cfg.get("teacher_profiles") or {}
    teachers = session.get("teachers") or ([session["teacher"]] if session.get("teacher") else [])
    pm = pmeta.get(int(period_idx))

    for t in teachers:
        prof = teacher_profiles.get(str(t).strip().upper())
        if not prof:
            continue
        for blk in prof.get("external_blocked_slots") or ():
            if slot_overlaps_window(blk, day_name, period_idx, pm):
                return False
        emp = str(prof.get("employment_type") or "permanent").strip().lower()
        if emp == "guest":
            avail = prof.get("available_slots") or ()
            if not avail or not any(slot_within_window(w, day_name, period_idx, pm) for w in avail):
                return False

    # Enforce room-level window & headcount availability when rooms are configured
    pool, _ = offering_room_pool(offering, cfg, physics_codes)
    if pool:
        students = offering.get("students")
        if not any(
            room_is_open_at(r, day_name, period_idx, pmeta, cfg) and room_fits_students(r, students, cfg)
            for r in pool
        ):
            return False

    return True


def add_policy_constraints(
    *,
    model: cp_model.CpModel,
    x: dict[tuple[int, int, int], cp_model.IntVar],
    slots_for: dict[int, list[tuple[int, int]]],
    sessions: list[dict[str, Any]],
    offerings: list[dict[str, Any]],
    offering_of: dict[int, dict[str, Any]],
    sessions_by_oid: dict[int, list[dict[str, Any]]],
    by_cohort: dict[tuple[str, str], list[dict[str, Any]]],
    by_teacher: dict[str, list[dict[str, Any]]],
    days: list[str],
    pidx: list[int],
    pmeta: dict[int, dict[str, Any]],
    topology: GridTopology,
    cfg: dict[str, Any],
    penalties: list[Any],
) -> dict[str, Any]:
    """Attach R1-R15 hard constraints & soft objectives; return metadata for Phase 2 & D6."""
    policy: domain.CommitteePolicySnapshot | None = cfg.get("committee_policy")
    physics_codes = effective_physics_codes(cfg)
    teacher_profiles: dict[str, dict[str, Any]] = cfg.get("teacher_profiles") or {}

    r13_block_oids: set[int] = set()
    r12_pair_vars: dict[tuple[int, int, int, int], cp_model.IntVar] = {}
    r13_pair_vars: dict[tuple[int, int, int, int], cp_model.IntVar] = {}
    early_conflicts: list[dict[str, Any]] = []

    # Build room-pool open count per (di, p) for physics/theory/lab capacity
    lab_rooms, ecl_rooms, physics_rooms, cse_rooms, theory_rooms = resolved_room_pools(cfg)
    ecl_set = set(ecl_rooms)
    phy_set = set(physics_rooms)
    general_lab_rooms = [r for r in lab_rooms if r not in ecl_set and r not in phy_set]

    for di, dname in enumerate(days):
        for p in pidx:
            open_lab = sum(1 for r in lab_rooms if room_is_open_at(r, dname, p, pmeta, cfg))
            open_th = sum(1 for r in theory_rooms if room_is_open_at(r, dname, p, pmeta, cfg))
            open_ecl = sum(1 for r in ecl_rooms if room_is_open_at(r, dname, p, pmeta, cfg))
            open_cse = sum(1 for r in cse_rooms if room_is_open_at(r, dname, p, pmeta, cfg))
            open_phy = sum(1 for r in physics_rooms if room_is_open_at(r, dname, p, pmeta, cfg))
            open_general_lab = sum(
                1 for r in general_lab_rooms if room_is_open_at(r, dname, p, pmeta, cfg)
            )

            lab_terms = [x[(s["sid"], di, p)] for s in sessions if s["is_lab"] and (s["sid"], di, p) in x]
            th_terms = [x[(s["sid"], di, p)] for s in sessions if not s["is_lab"] and (s["sid"], di, p) in x]
            if lab_terms:
                model.Add(sum(lab_terms) <= open_lab)
            if th_terms:
                model.Add(sum(th_terms) <= open_th)

            eee_terms = []
            cse_terms = []
            phy_terms = []
            non_special_lab_terms = []
            for s in sessions:
                if not s["is_lab"] or (s["sid"], di, p) not in x:
                    continue
                off = offering_of.get(s["oid"]) or {}
                kind = classify_lab_kind(
                    s["code"],
                    off.get("course_dept"),
                    physics_lab_course_codes=physics_codes,
                    is_physics_lab=bool(off.get("is_physics_lab")),
                    room_pool_override=off.get("room_pool_override"),
                )
                var = x[(s["sid"], di, p)]
                if kind == "physics":
                    phy_terms.append(var)
                elif kind == "ecl":
                    eee_terms.append(var)
                elif kind == "cse":
                    cse_terms.append(var)
                    non_special_lab_terms.append(var)
                else:
                    non_special_lab_terms.append(var)

            if eee_terms:
                model.Add(sum(eee_terms) <= open_ecl)
            if cse_terms:
                model.Add(sum(cse_terms) <= open_cse)
            if phy_terms:
                model.Add(sum(phy_terms) <= open_phy)
            if non_special_lab_terms and general_lab_rooms:
                model.Add(sum(non_special_lab_terms) <= open_general_lab)

    # ── R8: Individual faculty preferred slots (Tiered soft objective) ───────
    elig = cfg.get("eligibility") or {}
    elig_prio = elig.get("priority") or {}
    pref_weight_base = policy.faculty_preference_weight if policy is not None else 20

    for s in sessions:
        teachers = s.get("teachers") or ([s["teacher"]] if s.get("teacher") else [])
        code_u = str(s["code"]).strip().upper()
        for t in teachers:
            tu = str(t).strip().upper()
            prof = teacher_profiles.get(tu) or {}
            prefs = prof.get("preferred_slots") or ()
            if prefs and pref_weight_base > 0:
                for (di, p) in slots_for[s["sid"]]:
                    dname = days[di]
                    pm = pmeta.get(p)
                    matched_prio: int | None = None
                    for w in prefs:
                        if slot_within_window(w, dname, p, pm):
                            raw_p = w.get("priority") if isinstance(w, dict) else getattr(w, "priority", None)
                            prio = int(raw_p) if isinstance(raw_p, int) and not isinstance(raw_p, bool) else 1
                            if matched_prio is None or prio < matched_prio:
                                matched_prio = prio
                    if matched_prio is None:
                        penalties.append(pref_weight_base * x[(s["sid"], di, p)])
                    elif matched_prio > 1:
                        # Lower priority number (1) is preferred over 2, 3...
                        tier_pen = min(pref_weight_base // 2, (matched_prio - 1) * max(1, pref_weight_base // 5))
                        if tier_pen > 0:
                            penalties.append(tier_pen * x[(s["sid"], di, p)])

            ep = elig_prio.get((tu, code_u))
            if ep is not None and ep > 1:
                for (di, p) in slots_for[s["sid"]]:
                    penalties.append(min(4, ep - 1) * x[(s["sid"], di, p)])

    # ── R9: SUST adjunct compactness (hard gap <= max_gap, soft one-half-day)
    sust_max_gap = policy.sust_adjunct_max_gap if policy is not None else 2
    sust_single_half = policy.sust_adjunct_single_half_day if policy is not None else True
    for t, t_sessions in by_teacher.items():
        tu = str(t).strip().upper()
        prof = teacher_profiles.get(tu) or {}
        if not prof.get("is_sust_adjunct", False):
            continue
        gap_forbid = sust_max_gap + 1
        for di in range(len(days)):
            seq = topology.day_teachable_pidx.get(di, [])
            if len(seq) >= gap_forbid + 2:
                occ = []
                for p in seq:
                    terms = [x[(s["sid"], di, p)] for s in t_sessions if (s["sid"], di, p) in x]
                    if terms:
                        v = model.NewBoolVar(f"t_occ_{tu}_{di}_{p}")
                        model.Add(v == sum(terms))
                        occ.append(v)
                    else:
                        occ.append(None)
                for i in range(len(seq)):
                    if occ[i] is None:
                        continue
                    for j in range(i + gap_forbid + 1, len(seq)):
                        if occ[j] is None:
                            continue
                        for k in range(i + 1, j - gap_forbid + 1):
                            window = [occ[idx] for idx in range(k, k + gap_forbid) if occ[idx] is not None]
                            # If any middle slot in the window is structurally None (unoccupied), sum(window) is strictly smaller;
                            # all occ[idx] == 0 means occ[i] + occ[j] - sum(window) <= 1 forbids both endpoints being 1.
                            model.Add(occ[i] + occ[j] - sum(window) <= 1)

            if sust_single_half:
                pre_terms = [
                    x[(s["sid"], di, p)]
                    for s in t_sessions
                    for p in topology.pre_break_pidx.get(di, [])
                    if (s["sid"], di, p) in x
                ]
                post_terms = [
                    x[(s["sid"], di, p)]
                    for s in t_sessions
                    for p in topology.post_break_pidx.get(di, [])
                    if (s["sid"], di, p) in x
                ]
                if pre_terms and post_terms:
                    pre_used = model.NewBoolVar(f"sust_pre_{tu}_{di}")
                    post_used = model.NewBoolVar(f"sust_post_{tu}_{di}")
                    split_day = model.NewBoolVar(f"sust_split_{tu}_{di}")
                    for term in pre_terms:
                        model.Add(pre_used >= term)
                    model.Add(pre_used <= sum(pre_terms))
                    for term in post_terms:
                        model.Add(post_used >= term)
                    model.Add(post_used <= sum(post_terms))
                    model.Add(split_day >= pre_used + post_used - 1)
                    penalties.append(25 * split_day)

    # ── Hybrid R7: Resolve undeclared/partial Permanent off-days (0 or 1 -> >= 2)
    auto_resolve = policy.auto_resolve_undeclared_off_days if policy is not None else True
    hybrid_off_day_vars: dict[str, dict[int, cp_model.IntVar]] = {}
    if auto_resolve and len(days) >= 5:
        max_teach_days = len(days) - 2
        for t, t_sessions in sorted(by_teacher.items()):
            if not t_sessions:
                continue
            tu = str(t).strip().upper()
            prof = teacher_profiles.get(tu) or {}
            emp = str(prof.get("employment_type") or "permanent").strip().lower()
            if emp != "permanent":
                continue
            declared_set = {d for d in (prof.get("off_days") or ()) if d in days}
            if len(declared_set) not in (0, 1):
                continue

            # Verify mathematical feasibility: teacher's sessions must fit in <= (len(days) - 2) days
            per_day_slot_caps: list[int] = []
            for di, dname in enumerate(days):
                if dname in declared_set:
                    continue
                distinct_periods = {
                    p for s in t_sessions for p in pidx if (s["sid"], di, p) in x
                }
                per_day_slot_caps.append(len(distinct_periods))
            per_day_slot_caps.sort(reverse=True)
            max_5day_cap = sum(per_day_slot_caps[:max_teach_days])
            if len(t_sessions) > max_5day_cap:
                continue

            pref_days = {
                str(w.get("day") if isinstance(w, dict) else getattr(w, "day", "")).strip()
                for w in (prof.get("preferred_slots") or ())
            }
            ext_days = {
                str(w.get("day") if isinstance(w, dict) else getattr(w, "day", "")).strip()
                for w in (prof.get("external_blocked_slots") or ())
            }
            day_off_map: dict[int, cp_model.IntVar] = {}
            for di, dname in enumerate(days):
                terms = [x[(s["sid"], di, p)] for s in t_sessions for p in pidx if (s["sid"], di, p) in x]
                t_act = model.NewBoolVar(f"perm_act_{tu}_{di}")
                for t_var in terms:
                    model.Add(t_act >= t_var)
                model.Add(t_act <= (sum(terms) if terms else 0))

                t_off = model.NewBoolVar(f"perm_off_{tu}_{di}")
                model.Add(t_act + t_off <= 1)
                if dname in declared_set:
                    model.Add(t_off == 1)
                else:
                    if dname in pref_days:
                        penalties.append(12 * t_off)
                    if dname in ext_days:
                        penalties.append(6 * t_off)
                    if dname not in ("Friday", "Saturday"):
                        penalties.append(1 * t_off)
                day_off_map[di] = t_off
            model.Add(sum(day_off_map.values()) == 2)
            hybrid_off_day_vars[tu] = day_off_map

    if policy is None:
        return {
            "r13_block_oids": r13_block_oids,
            "r12_pair_vars": r12_pair_vars,
            "r13_pair_vars": r13_pair_vars,
            "early_conflicts": early_conflicts,
            "r6_adjunct_info": {},
            "hybrid_off_day_vars": hybrid_off_day_vars,
        }

    # ── R1 & R2 (D1): Independent Section Weekends & Batch Off-Day Fairness ─
    non_service_by_cohort: dict[tuple[str, str], list[dict[str, Any]]] = defaultdict(list)
    for s in sessions:
        if s.get("is_service"):
            continue
        for grp in atomic_groups(s["batch"], s["section"]):
            if grp[1]:  # atomic section
                non_service_by_cohort[grp].append(s)

    override_map: dict[tuple[str, str], tuple[str, str]] = {
        (ov.batch.strip(), ov.section.strip().upper()): ov.weekend_days
        for ov in policy.section_weekend_overrides
    }
    for sec in cfg.get("raw_section_overrides") or []:
        if isinstance(sec, dict) and sec.get("is_active", True):
            raw_wd = sec.get("weekend_override_days") or sec.get("weekend_days")
            if raw_wd and domain.is_valid_consecutive_weekend(raw_wd):
                key = (str(sec.get("batch") or "").strip(), str(sec.get("section") or "").strip().upper())
                override_map.setdefault(key, (str(raw_wd[0]).strip(), str(raw_wd[1]).strip()))

    day_index = {d: i for i, d in enumerate(days)}
    sec_active_vars: dict[tuple[tuple[str, str], int], cp_model.IntVar] = {}
    for sec, sec_sessions in non_service_by_cohort.items():
        for di in range(len(days)):
            v = model.NewBoolVar(f"sec_act_{sec[0]}_{sec[1]}_{di}")
            terms = [x[(s["sid"], di, p)] for s in sec_sessions for p in pidx if (s["sid"], di, p) in x]
            for t_var in terms:
                model.Add(v >= t_var)
            model.Add(v <= (sum(terms) if terms else 0))
            sec_active_vars[(sec, di)] = v

        ov_days = override_map.get((sec[0], sec[1].upper()))
        if ov_days is not None and len(days) == 7:
            for dname in ov_days:
                if dname in day_index:
                    model.Add(sec_active_vars[(sec, day_index[dname])] == 0)
        elif len(days) == 7:
            wk_vars: list[cp_model.IntVar] = []
            def_d0, def_d1 = policy.default_section_weekend
            for k in range(7):
                d_a = k
                d_b = (k + 1) % 7
                wkv = model.NewBoolVar(f"wk_{sec[0]}_{sec[1]}_{k}")
                model.Add(sec_active_vars[(sec, d_a)] == 0).OnlyEnforceIf(wkv)
                model.Add(sec_active_vars[(sec, d_b)] == 0).OnlyEnforceIf(wkv)
                wk_vars.append(wkv)
                pair_names = {days[d_a], days[d_b]}
                if pair_names == {def_d0, def_d1}:
                    penalties.append(2 * (1 - wkv))
            model.AddExactlyOne(wk_vars)

    # R2: Batch max-min off-day spread <= batch_max_off_day_spread
    if len(days) == 7:
        by_batch: dict[str, list[tuple[str, str]]] = defaultdict(list)
        for sec in non_service_by_cohort:
            by_batch[sec[0]].append(sec)
        for batch_id, secs in by_batch.items():
            if len(secs) < 2:
                continue
            off_vars = []
            for sec in secs:
                ov = model.NewIntVar(0, 7, f"off_cnt_{batch_id}_{sec[1]}")
                model.Add(ov == 7 - sum(sec_active_vars[(sec, di)] for di in range(7)))
                off_vars.append(ov)
            mx = model.NewIntVar(0, 7, f"max_off_{batch_id}")
            mn = model.NewIntVar(0, 7, f"min_off_{batch_id}")
            model.AddMaxEquality(mx, off_vars)
            model.AddMinEquality(mn, off_vars)
            model.Add(mx - mn <= policy.batch_max_off_day_spread)

    # ── R3: Section compactness (forbid >= max_section_internal_gap + 1 consecutive holes)
    gap_forbid_sec = policy.max_section_internal_gap + 1
    for sec, sec_sessions in non_service_by_cohort.items():
        for di in range(len(days)):
            seq = topology.day_teachable_pidx.get(di, [])
            if len(seq) < 3:
                continue
            occ = []
            for p in seq:
                terms = [x[(s["sid"], di, p)] for s in sec_sessions if (s["sid"], di, p) in x]
                if terms:
                    v = model.NewBoolVar(f"s_occ_{sec[0]}_{sec[1]}_{di}_{p}")
                    model.Add(v == sum(terms))
                    occ.append(v)
                else:
                    occ.append(None)

            for i in range(len(seq)):
                if occ[i] is None:
                    continue
                for j in range(i + gap_forbid_sec + 1, len(seq)):
                    if occ[j] is None:
                        continue
                    for k in range(i + 1, j - gap_forbid_sec + 1):
                        window = [occ[idx] for idx in range(k, k + gap_forbid_sec) if occ[idx] is not None]
                        model.Add(occ[i] + occ[j] - sum(window) <= 1)

            # Soft penalty for 1-slot internal hole when 1-slot holes are permitted
            if policy.max_section_internal_gap >= 1:
                for i in range(len(seq) - 2):
                    if occ[i] is None or occ[i + 2] is None:
                        continue
                    hole = model.NewBoolVar(f"hole1_{sec[0]}_{sec[1]}_{di}_{i}")
                    mid = occ[i + 1] if occ[i + 1] is not None else 0
                    model.Add(hole >= occ[i] + occ[i + 2] - mid - 1)
                    penalties.append(2 * hole)

    # ── R6 (D4): Adjunct distinct-course workload span ─────────────────────
    adjunct_info: dict[str, dict[str, Any]] = {}
    strict_adjunct = bool(cfg.get("strict_adjunct_day_bands", False))
    bands = policy.adjunct_day_bands
    for t, t_sessions in by_teacher.items():
        tu = str(t).strip().upper()
        prof = teacher_profiles.get(tu) or {}
        if str(prof.get("employment_type") or "permanent").strip().lower() != "adjunct":
            continue
        distinct_codes = sorted({str(s["code"]).strip().upper() for s in t_sessions if str(s.get("code") or "").strip()})
        c = len(distinct_codes)
        band: tuple[int, int] | None = None
        if c == 2:
            band = (1, bands.two_courses_max_days)
        elif c == 3:
            band = (bands.three_courses_min_days, bands.three_courses_max_days)
        elif c >= 4:
            band = (bands.four_plus_courses_min_days, bands.four_plus_courses_max_days)
        adjunct_info[tu] = {"distinct_courses": distinct_codes, "target_band": band}
        if band is None:
            continue

        day_used = []
        for di in range(len(days)):
            terms = [x[(s["sid"], di, p)] for s in t_sessions for p in pidx if (s["sid"], di, p) in x]
            du = model.NewBoolVar(f"adj_du_{tu}_{di}")
            for t_var in terms:
                model.Add(du >= t_var)
            model.Add(du <= (sum(terms) if terms else 0))
            day_used.append(du)

        active_days = model.NewIntVar(0, len(days), f"adj_days_{tu}")
        model.Add(active_days == sum(day_used))
        lo, hi = band
        if strict_adjunct:
            model.Add(active_days >= lo)
            model.Add(active_days <= hi)
        else:
            under = model.NewIntVar(0, len(days), f"adj_under_{tu}")
            over = model.NewIntVar(0, len(days), f"adj_over_{tu}")
            model.Add(under >= lo - active_days)
            model.Add(over >= active_days - hi)
            penalties.append(40 * (under + over))

    # ── R13 (D2): CSE 1/1.5/2-credit consecutive same-day block & 3-cr spread
    for o in offerings:
        oid = o["oid"]
        code = str(o.get("code") or "").strip().upper()
        dept = o.get("course_dept")
        cr = o.get("credit")
        if (
            policy.low_credit_cse_theory_consecutive
            and not o.get("is_lab")
            and not o.get("is_service")
            and is_cse_course(code, dept)
            and cr is not None
            and any(abs(float(cr) - target) < 1e-6 for target in (1.0, 1.5, 2.0))
        ):
            group = sorted(sessions_by_oid[oid], key=lambda s: s["occurrence"])
            if len(group) != 2:
                continue
            r13_block_oids.add(oid)
            s0, s1 = group[0], group[1]
            s0_slots = set(slots_for[s0["sid"]])
            s1_slots = set(slots_for[s1["sid"]])
            students = o.get("students")

            block_vars: list[cp_model.IntVar] = []
            for di, dname in enumerate(days):
                for p_a, p_b in topology.non_break_adj_pairs.get(di, []):
                    if (di, p_a) not in s0_slots or (di, p_b) not in s1_slots:
                        continue
                    has_common_room = any(
                        room_is_open_at(r, dname, p_a, pmeta, cfg)
                        and room_is_open_at(r, dname, p_b, pmeta, cfg)
                        and room_fits_students(r, students, cfg)
                        for r in theory_rooms
                    )
                    if not has_common_room:
                        continue
                    bv = model.NewBoolVar(f"r13_blk_{oid}_{di}_{p_a}_{p_b}")
                    model.Add(x[(s0["sid"], di, p_a)] == 1).OnlyEnforceIf(bv)
                    model.Add(x[(s1["sid"], di, p_b)] == 1).OnlyEnforceIf(bv)
                    r13_pair_vars[(oid, di, p_a, p_b)] = bv
                    block_vars.append(bv)

            if not block_vars:
                early_conflicts.append(
                    make_conflict(
                        rule="R13",
                        code="r13_no_consecutive_slot_pair",
                        entity_type="course",
                        entity_id=f"{o['cohort']} {code}",
                        message=(
                            f"{code} ({o['cohort']}, {cr} cr CSE theory) has no valid 2-slot "
                            f"non-break-crossing same-day consecutive pair with a common theory room."
                        ),
                        proven=True,
                    )
                )
            else:
                model.AddExactlyOne(block_vars)

    # ── R12 (D5): 2-credit sessional 2+1 pattern & break-crossing gate ─────
    for o in offerings:
        oid = o["oid"]
        if not o.get("is_lab") or o.get("credit") is None or abs(float(o["credit"]) - 2.0) >= 1e-6:
            continue
        group = sorted(sessions_by_oid[oid], key=lambda s: s["occurrence"])
        if len(group) < 3:
            continue
        pool, _ = offering_room_pool(o, cfg, physics_codes)
        students = o.get("students")

        all_pair_vars: list[cp_model.IntVar] = []
        for di, dname in enumerate(days):
            candidate_pairs = list(topology.non_break_adj_pairs.get(di, []))
            if policy.allow_sessional_across_break:
                candidate_pairs.extend(topology.break_adj_pairs.get(di, []))

            day_pair_vars: list[cp_model.IntVar] = []
            for p_a, p_b in candidate_pairs:
                terms_a = [x[(s["sid"], di, p_a)] for s in group if (s["sid"], di, p_a) in x]
                terms_b = [x[(s["sid"], di, p_b)] for s in group if (s["sid"], di, p_b) in x]
                if not terms_a or not terms_b:
                    continue
                has_common_lab = any(
                    room_is_open_at(r, dname, p_a, pmeta, cfg)
                    and room_is_open_at(r, dname, p_b, pmeta, cfg)
                    and room_fits_students(r, students, cfg)
                    for r in pool
                )
                if not has_common_lab:
                    continue
                pv = model.NewBoolVar(f"r12_pair_{oid}_{di}_{p_a}_{p_b}")
                model.Add(sum(terms_a) == 1).OnlyEnforceIf(pv)
                model.Add(sum(terms_b) == 1).OnlyEnforceIf(pv)
                r12_pair_vars[(oid, di, p_a, p_b)] = pv
                day_pair_vars.append(pv)
                all_pair_vars.append(pv)

            day_terms = [
                x[(s["sid"], di, p)]
                for s in group
                for p in pidx
                if (s["sid"], di, p) in x
            ]
            if day_terms:
                model.Add(sum(day_terms) <= 1 + sum(day_pair_vars))

        if all_pair_vars:
            model.Add(sum(all_pair_vars) <= 1)
            penalties.append(30 * (1 - sum(all_pair_vars)))

    return {
        "r13_block_oids": r13_block_oids,
        "r12_pair_vars": r12_pair_vars,
        "r13_pair_vars": r13_pair_vars,
        "early_conflicts": early_conflicts,
        "r6_adjunct_info": adjunct_info,
        "hybrid_off_day_vars": hybrid_off_day_vars,
    }


def diagnose_infeasibility(
    *,
    raw_status: str,
    termination_reason: str,
    sessions: list[dict[str, Any]],
    offerings: list[dict[str, Any]],
    offering_of: dict[int, dict[str, Any]],
    slots_for: dict[int, list[tuple[int, int]]],
    days: list[str],
    pidx: list[int],
    pmeta: dict[int, dict[str, Any]],
    cfg: dict[str, Any],
    early_conflicts: list[dict[str, Any]],
) -> tuple[str, list[dict[str, Any]]]:
    """Build structured D6 conflict list + concise summary without suggesting silent relaxation."""
    conflicts: list[dict[str, Any]] = list(early_conflicts)
    physics_codes = effective_physics_codes(cfg)

    def _teachers_of(s: dict[str, Any]) -> list[str]:
        return s.get("teachers") or ([s["teacher"]] if s.get("teacher") else [])

    # 1. Proven teacher pigeonhole deficit
    t_load: dict[str, int] = defaultdict(int)
    t_cap: dict[str, set[tuple[int, int]]] = defaultdict(set)
    for s in sessions:
        for t in _teachers_of(s):
            t_load[t] += 1
            t_cap[t].update(slots_for.get(s["sid"], []))

    over_teachers = sorted(
        ((t, t_load[t], len(t_cap[t])) for t in t_load if t_load[t] > len(t_cap[t])),
        key=lambda r: r[1] - r[2],
        reverse=True,
    )
    for t, need, cap in over_teachers[:5]:
        prof = (cfg.get("teacher_profiles") or {}).get(str(t).strip().upper()) or {}
        rule = "R5" if prof.get("employment_type") == "guest" else "R7"
        conflicts.append(
            make_conflict(
                rule=rule,
                code="teacher_slot_deficit",
                entity_type="faculty",
                entity_id=t,
                message=f"Teacher {t} needs {need} weekly session(s) but only has {cap} usable (day, period) slot(s).",
                proven=True,
            )
        )

    # 2. Proven atomic section pigeonhole deficit
    sec_load: dict[tuple[str, str], int] = defaultdict(int)
    sec_cap: dict[tuple[str, str], set[tuple[int, int]]] = defaultdict(set)
    for s in sessions:
        for grp in atomic_groups(s["batch"], s["section"]):
            sec_load[grp] += 1
            sec_cap[grp].update(slots_for.get(s["sid"], []))
    for grp, need in sorted(sec_load.items()):
        cap = len(sec_cap[grp])
        if need > cap:
            label = f"{grp[0]}-{grp[1]}" if grp[1] else grp[0]
            conflicts.append(
                make_conflict(
                    rule="R1",
                    code="section_slot_deficit",
                    entity_type="section",
                    entity_id=label,
                    message=f"Section {label} needs {need} weekly session(s) but only has {cap} usable slot(s).",
                    proven=True,
                )
            )

    # 3. Proven room pool deficit (R10/R11/R14)
    lab_rooms, ecl_rooms, phy_rooms, cse_rooms, theory_rooms = resolved_room_pools(cfg)

    def _pool_cap(pool: list[str]) -> int:
        return sum(
            1
            for r in pool
            for di, dname in enumerate(days)
            for p in pidx
            if p not in (cfg.get("blocked_periods") or {}).get(dname, set())
            and room_is_open_at(r, dname, p, pmeta, cfg)
        )

    eee_labs = [
        s for s in sessions
        if s["is_lab"]
        and not is_physics_lab_course(s["code"], physics_codes)
        and is_eee_course(s["code"], (offering_of.get(s["oid"]) or {}).get("course_dept"))
    ]
    cse_labs = [
        s for s in sessions
        if s["is_lab"]
        and not is_physics_lab_course(s["code"], physics_codes)
        and is_cse_course(s["code"], (offering_of.get(s["oid"]) or {}).get("course_dept"))
    ]
    phy_labs = [s for s in sessions if s["is_lab"] and is_physics_lab_course(s["code"], physics_codes)]
    th_sess = [s for s in sessions if not s["is_lab"]]

    if eee_labs and (not ecl_rooms or len(eee_labs) > _pool_cap(ecl_rooms)):
        conflicts.append(
            make_conflict(
                rule="R10",
                code="ecl_lab_capacity_deficit",
                entity_type="room",
                entity_id=", ".join(ecl_rooms) or "ECL",
                message=(
                    "No ECL laboratory rooms are configured or available, but EEE laboratory courses require ECL rooms."
                    if not ecl_rooms
                    else f"EEE labs need {len(eee_labs)} weekly slot(s), exceeding ECL room capacity ({_pool_cap(ecl_rooms)})."
                ),
                proven=True,
            )
        )
    if cse_labs and (not cse_rooms or len(cse_labs) > _pool_cap(cse_rooms)):
        conflicts.append(
            make_conflict(
                rule="R14",
                code="cse_lab_capacity_deficit",
                entity_type="room",
                entity_id=", ".join(cse_rooms) or "CSE-LAB",
                message=(
                    "No CSE laboratory rooms are configured or available, but CSE laboratory courses require CSE rooms."
                    if not cse_rooms
                    else f"CSE labs need {len(cse_labs)} weekly slot(s), exceeding CSE lab capacity ({_pool_cap(cse_rooms)})."
                ),
                proven=True,
            )
        )
    if phy_labs and (not phy_rooms or len(phy_labs) > _pool_cap(phy_rooms)):
        conflicts.append(
            make_conflict(
                rule="R11",
                code="physics_lab_capacity_deficit",
                entity_type="room",
                entity_id=", ".join(phy_rooms) or "PHY-LAB",
                message=(
                    f"Physics lab course(s) need {len(phy_labs)} weekly slot(s), exceeding Physics lab room capacity ({_pool_cap(phy_rooms)})."
                ),
                proven=True,
            )
        )
    if th_sess and (not theory_rooms or len(th_sess) > _pool_cap(theory_rooms)):
        conflicts.append(
            make_conflict(
                rule="R14",
                code="theory_room_capacity_deficit",
                entity_type="room",
                entity_id=", ".join(theory_rooms[:4]) or "THEORY",
                message=(
                    "No theory rooms are configured or available for scheduled theory courses."
                    if not theory_rooms
                    else f"Theory courses need {len(th_sess)} weekly slot(s), exceeding theory room capacity ({_pool_cap(theory_rooms)})."
                ),
                proven=True,
            )
        )

    # 4. If CP-SAT proved infeasibility / timed out across interacting rules without a single proven deficit,
    #    emit heuristic diagnostic hints explicitly marked `proven=False` (D6).
    if not conflicts:
        if termination_reason == "time_limit_no_incumbent":
            conflicts.append(
                make_conflict(
                    rule="D6",
                    code="solver_time_limit_exhausted",
                    entity_type="policy",
                    entity_id="time_limit_s",
                    message=(
                        "Solver reached its time limit before finding a valid schedule. "
                        "Raise the solver time budget or review tight policy constraints."
                    ),
                    severity="blocker",
                    proven=False,
                )
            )
        else:
            conflicts.append(
                make_conflict(
                    rule="D6",
                    code="interacting_constraints_conflict",
                    entity_type="policy",
                    entity_id="committee_policy",
                    message=(
                        "No feasible timetable satisfies all hard constraints simultaneously "
                        "(interacting faculty availability, section weekend/gap rules, room pools, "
                        "or course distribution counts). Review Faculty, Rooms, and Section Policies."
                    ),
                    severity="blocker",
                    proven=False,
                )
            )

    lines = [f"No feasible timetable (status={raw_status}, reason={termination_reason})."]
    if over_teachers:
        lines.append("Over-committed teachers (sessions needed vs slots free):")
        lines.extend(
            f"  - {t}: needs {need}, has {cap} usable (day,period) slots"
            for t, need, cap in over_teachers[:5]
        )
    else:
        for c in conflicts[:4]:
            lines.append(f"  - [{c['rule']}] {c['message']}")

    return "\n".join(lines), conflicts


def validate_policy_compliance(
    *,
    dataset: dict[str, Any],
    cfg: dict[str, Any],
    all_rows: list[dict[str, Any]],
    days: list[str],
    pmeta: dict[int, dict[str, Any]],
    topology: GridTopology,
    resolved_off_days_by_teacher: dict[str, list[str]] | None = None,
) -> dict[str, Any]:
    """Independent post-placement validation of R1-R15 hard rules + soft metrics."""
    policy: domain.CommitteePolicySnapshot | None = cfg.get("committee_policy")
    physics_codes = effective_physics_codes(cfg)
    teacher_profiles: dict[str, dict[str, Any]] = cfg.get("teacher_profiles") or {}
    offerings = dataset.get("offerings") or []
    offering_of = {o["oid"]: o for o in offerings}
    required_by_cc = {(o["cohort"], o["code"]): o for o in offerings}
    aliases = cfg.get("room_aliases") or {}

    violations: dict[str, int] = defaultdict(int)
    details: dict[str, list[dict[str, Any]]] = defaultdict(list)

    def _record_violation(key: str, detail: dict[str, Any]) -> None:
        violations[key] += 1
        if len(details[key]) < 50:
            details[key].append(detail)

    # ── Independent R4, R5, R10, R11 checks (active whenever extended fields or policy exist)
    for r in all_rows:
        cohort = f"{r['batch']}-{r['section']}" if r.get("section") else str(r["batch"])
        offering = required_by_cc.get((cohort, r["subject_code"])) or {}
        dname = str(r["day"])
        pidx_val = int(r["period"]) if r.get("period") is not None else None
        pm = pmeta.get(pidx_val) if pidx_val is not None else None
        assigned = r.get("teachers") or ([r["teacher_code"]] if r.get("teacher_code") else [])

        for t in assigned:
            tu = str(t).strip().upper()
            prof = teacher_profiles.get(tu) or {}
            if pidx_val is not None:
                for blk in prof.get("external_blocked_slots") or ():
                    if slot_overlaps_window(blk, dname, pidx_val, pm):
                        _record_violation(
                            "r4_external_block_violations",
                            {"teacher": tu, "code": r["subject_code"], "cohort": cohort, "day": dname, "period": pidx_val},
                        )
                if str(prof.get("employment_type") or "").lower() == "guest":
                    avail = prof.get("available_slots") or ()
                    if not avail or not any(slot_within_window(w, dname, pidx_val, pm) for w in avail):
                        _record_violation(
                            "r5_guest_availability_violations",
                            {"teacher": tu, "code": r["subject_code"], "cohort": cohort, "day": dname, "period": pidx_val},
                        )

        room = str(r.get("room") or "")
        if room and room != "TBA":
            phys = room_key(room, aliases)
            meta = next(
                (m for k, m in (cfg.get("room_metadata") or {}).items() if room_key(k, aliases) == phys),
                {},
            )
            avail = meta.get("available_slots") or ()
            if pidx_val is not None and avail:
                if not any(slot_within_window(w, dname, pidx_val, pm) for w in avail):
                    rule_key = (
                        "r11_physics_lab_violations"
                        if is_physics_lab_room(meta or room, aliases)
                        else "r10_ecl_window_violations"
                    )
                    _record_violation(
                        rule_key,
                        {"room": room, "code": r["subject_code"], "cohort": cohort, "day": dname, "period": pidx_val},
                    )
            if r.get("is_lab") and (
                is_physics_lab_course(r["subject_code"], physics_codes) or offering.get("is_physics_lab")
            ):
                if not is_physics_lab_room(meta or room, aliases):
                    _record_violation(
                        "r11_physics_lab_violations",
                        {"room": room, "code": r["subject_code"], "cohort": cohort, "reason": "Must use physics_lab room"},
                    )

    # ── R9 SUST Adjunct hard max gap check ─────────────────────────────────
    sust_max_gap = policy.sust_adjunct_max_gap if policy is not None else 2
    by_teacher_day: dict[tuple[str, str], set[int]] = defaultdict(set)
    for r in all_rows:
        if r.get("period") is None:
            continue
        for t in (r.get("teachers") or ([r["teacher_code"]] if r.get("teacher_code") else [])):
            by_teacher_day[(str(t).strip().upper(), str(r["day"]))].add(int(r["period"]))

    day_idx_map = {d: i for i, d in enumerate(days)}
    sust_split_days = 0
    sust_checked = 0
    for tu, prof in teacher_profiles.items():
        if not prof.get("is_sust_adjunct"):
            continue
        sust_checked += 1
        for dname, di in day_idx_map.items():
            used = by_teacher_day.get((tu, dname), set())
            if len(used) < 2:
                continue
            seq = topology.day_teachable_pidx.get(di, [])
            positions = [seq.index(p) for p in used if p in seq]
            if len(positions) >= 2:
                lo, hi = min(positions), max(positions)
                run = 0
                max_run = 0
                for pos in range(lo, hi + 1):
                    if seq[pos] not in used:
                        run += 1
                        max_run = max(max_run, run)
                    else:
                        run = 0
                if max_run > sust_max_gap:
                    _record_violation(
                        "r9_sust_gap_violations",
                        {"teacher": tu, "day": dname, "max_internal_gap": max_run, "allowed": sust_max_gap},
                    )
            pre = set(topology.pre_break_pidx.get(di, []))
            post = set(topology.post_break_pidx.get(di, []))
            if (used & pre) and (used & post):
                sust_split_days += 1

    # ── R8 Faculty preference soft metric ──────────────────────────────────
    pref_matched = 0
    pref_total = 0
    for r in all_rows:
        if r.get("period") is None:
            continue
        dname = str(r["day"])
        pidx_val = int(r["period"])
        pm = pmeta.get(pidx_val)
        for t in (r.get("teachers") or ([r["teacher_code"]] if r.get("teacher_code") else [])):
            prof = teacher_profiles.get(str(t).strip().upper()) or {}
            prefs = prof.get("preferred_slots") or ()
            if prefs:
                pref_total += 1
                if any(slot_within_window(w, dname, pidx_val, pm) for w in prefs):
                    pref_matched += 1

    # ── R6 Adjunct distinct-course soft metric ─────────────────────────────
    adjunct_metrics: list[dict[str, Any]] = []
    bands = policy.adjunct_day_bands if policy is not None else domain.AdjunctDayBandPolicy()
    strict_adjunct = bool(cfg.get("strict_adjunct_day_bands", False))
    for tu, prof in sorted(teacher_profiles.items()):
        if str(prof.get("employment_type") or "").lower() != "adjunct":
            continue
        courses_taught = sorted({
            str(r["subject_code"]).strip().upper()
            for r in all_rows
            if tu in [str(x).strip().upper() for x in (r.get("teachers") or ([r["teacher_code"]] if r.get("teacher_code") else []))]
        })
        if not courses_taught:
            continue
        active_days_set = sorted({
            str(r["day"])
            for r in all_rows
            if tu in [str(x).strip().upper() for x in (r.get("teachers") or ([r["teacher_code"]] if r.get("teacher_code") else []))]
        })
        c = len(courses_taught)
        band = (
            (1, bands.two_courses_max_days) if c == 2
            else (bands.three_courses_min_days, bands.three_courses_max_days) if c == 3
            else (bands.four_plus_courses_min_days, bands.four_plus_courses_max_days) if c >= 4
            else None
        )
        in_band = True if band is None else (band[0] <= len(active_days_set) <= band[1])
        if strict_adjunct and not in_band:
            _record_violation(
                "r6_adjunct_band_violations",
                {"teacher": tu, "distinct_courses": courses_taught, "active_days": len(active_days_set), "target_band": list(band) if band else None},
            )
        adjunct_metrics.append(
            {
                "teacher": tu,
                "distinct_courses": courses_taught,
                "distinct_course_count": c,
                "active_days": len(active_days_set),
                "target_band": list(band) if band else None,
                "in_band": in_band,
            }
        )

    # ── Committee Policy Mode hard checks (R1, R2, R3, R12, R13) ───────────
    r12_paired = 0
    r12_total = 0
    r3_single_holes = 0

    if policy is not None:
        # Build atomic section day->periods & active days
        sec_day_periods: dict[tuple[str, str], dict[str, list[int]]] = defaultdict(lambda: defaultdict(list))
        for r in all_rows:
            if r.get("is_service") or r.get("period") is None:
                continue
            for grp in atomic_groups(r["batch"], r["section"]):
                if grp[1]:
                    sec_day_periods[grp][str(r["day"])].append(int(r["period"]))

        # Include non-service offerings even if 0 rows (recomputed independently)
        all_non_service_secs: set[tuple[str, str]] = set(sec_day_periods.keys())
        for o in offerings:
            if not o.get("is_service"):
                for grp in atomic_groups(o["batch"], o["section"]):
                    if grp[1]:
                        all_non_service_secs.add(grp)

        override_map = {
            (ov.batch.strip(), ov.section.strip().upper()): set(ov.weekend_days)
            for ov in policy.section_weekend_overrides
        }
        sec_off_counts: dict[tuple[str, str], int] = {}
        for sec in sorted(all_non_service_secs):
            day_map = sec_day_periods.get(sec, {})
            if len(days) == 7:
                free_days = [d for d in days if not day_map.get(d)]
                sec_off_counts[sec] = len(free_days)
                has_consec = any(
                    (days[k] in free_days and days[(k + 1) % 7] in free_days)
                    for k in range(7)
                )
                if not has_consec:
                    _record_violation(
                        "r1_section_weekend_violations",
                        {"section": f"{sec[0]}-{sec[1]}", "free_days": free_days},
                    )
                ov = override_map.get((sec[0], sec[1].upper()))
                if ov and not ov.issubset(set(free_days)):
                    _record_violation(
                        "r1_section_weekend_violations",
                        {"section": f"{sec[0]}-{sec[1]}", "expected_override": sorted(ov), "free_days": free_days},
                    )

            # R3: internal gap <= max_section_internal_gap
            for dname, plist in day_map.items():
                di = day_idx_map.get(dname)
                if di is None or len(plist) < 2:
                    continue
                seq = topology.day_teachable_pidx.get(di, [])
                used = set(plist)
                positions = [seq.index(p) for p in used if p in seq]
                if len(positions) >= 2:
                    lo, hi = min(positions), max(positions)
                    run = 0
                    for pos in range(lo, hi + 1):
                        if seq[pos] not in used:
                            run += 1
                        else:
                            if run == 1:
                                r3_single_holes += 1
                            if run > policy.max_section_internal_gap:
                                _record_violation(
                                    "r3_section_gap_violations",
                                    {"section": f"{sec[0]}-{sec[1]}", "day": dname, "gap_slots": run, "max_allowed": policy.max_section_internal_gap},
                                )
                            run = 0

        if len(days) == 7:
            batch_secs: dict[str, list[tuple[str, str]]] = defaultdict(list)
            for sec in all_non_service_secs:
                batch_secs[sec[0]].append(sec)
            for batch_id, secs in batch_secs.items():
                if len(secs) < 2:
                    continue
                counts = [sec_off_counts[s] for s in secs]
                spread = max(counts) - min(counts)
                if spread > policy.batch_max_off_day_spread:
                    _record_violation(
                        "r2_batch_fairness_violations",
                        {"batch": batch_id, "off_day_counts": {f"{s[0]}-{s[1]}": sec_off_counts[s] for s in secs}, "spread": spread, "max_allowed": policy.batch_max_off_day_spread},
                    )

        # R12 & R13 pattern checks per offering
        rows_by_cc: dict[tuple[str, str], list[dict[str, Any]]] = defaultdict(list)
        for r in all_rows:
            cohort = f"{r['batch']}-{r['section']}" if r.get("section") else str(r["batch"])
            rows_by_cc[(cohort, r["subject_code"])].append(r)

        for o in offerings:
            cc_rows = rows_by_cc.get((o["cohort"], o["code"]), [])
            code = str(o["code"]).strip().upper()
            cr = o.get("credit")
            is_lab = bool(o.get("is_lab"))
            is_service = bool(o.get("is_service"))
            dept = o.get("course_dept")

            # R13 low-credit CSE theory
            if (
                policy.low_credit_cse_theory_consecutive
                and not is_lab
                and not is_service
                and is_cse_course(code, dept)
                and cr is not None
                and any(abs(float(cr) - c) < 1e-6 for c in (1.0, 1.5, 2.0))
            ):
                if len(cc_rows) != 2:
                    _record_violation("r13_low_credit_theory_violations", {"cohort": o["cohort"], "code": code, "reason": f"Expected 2 classes, got {len(cc_rows)}"})
                else:
                    r0, r1 = sorted(cc_rows, key=lambda item: int(item.get("period") or 0))
                    di = day_idx_map.get(str(r0["day"]))
                    pair = (int(r0["period"]), int(r1["period"])) if r0.get("period") and r1.get("period") else None
                    valid_nb = set(topology.non_break_adj_pairs.get(di, [])) if di is not None else set()
                    if r0["day"] != r1["day"] or pair not in valid_nb or room_key(r0["room"], aliases) != room_key(r1["room"], aliases):
                        _record_violation(
                            "r13_low_credit_theory_violations",
                            {
                                "cohort": o["cohort"],
                                "code": code,
                                "days": [r0["day"], r1["day"]],
                                "periods": [r0.get("period"), r1.get("period")],
                                "rooms": [r0["room"], r1["room"]],
                            },
                        )

            # R12 2-credit sessional consecutive same-lab & D5 break crossing
            if is_lab and cr is not None and abs(float(cr) - 2.0) < 1e-6:
                r12_total += 1
                by_d: dict[str, list[dict[str, Any]]] = defaultdict(list)
                for rr in cc_rows:
                    by_d[str(rr["day"])].append(rr)
                paired_here = False
                for dname, drs in by_d.items():
                    if len(drs) > 2:
                        _record_violation("r12_sessional_pattern_violations", {"cohort": o["cohort"], "code": code, "day": dname, "count": len(drs)})
                    elif len(drs) == 2:
                        drs_s = sorted(drs, key=lambda item: int(item.get("period") or 0))
                        di = day_idx_map.get(dname)
                        pair = (int(drs_s[0]["period"]), int(drs_s[1]["period"]))
                        nb = set(topology.non_break_adj_pairs.get(di, [])) if di is not None else set()
                        br = set(topology.break_adj_pairs.get(di, [])) if di is not None else set()
                        same_room = room_key(drs_s[0]["room"], aliases) == room_key(drs_s[1]["room"], aliases)
                        if pair in br and not policy.allow_sessional_across_break:
                            _record_violation(
                                "r12_sessional_pattern_violations",
                                {"cohort": o["cohort"], "code": code, "day": dname, "periods": list(pair), "reason": "Break-crossing sessional pair disabled (D5)"},
                            )
                        elif not same_room or (pair not in nb and pair not in br):
                            _record_violation(
                                "r12_sessional_pattern_violations",
                                {"cohort": o["cohort"], "code": code, "day": dname, "periods": list(pair), "rooms": [drs_s[0]["room"], drs_s[1]["room"]]},
                            )
                        else:
                            paired_here = True
                if paired_here:
                    r12_paired += 1

    # ── Hybrid R7/R6/R5 Resolved Faculty Off-Days & R7 Hard Compliance ───────
    teacher_active_days: dict[str, set[str]] = defaultdict(set)
    assigned_acronyms: set[str] = set()
    for r in all_rows:
        r_teachers = r.get("teachers") or ([r["teacher_code"]] if r.get("teacher_code") else [])
        for t in r_teachers:
            tu = str(t).strip().upper()
            if tu:
                assigned_acronyms.add(tu)
                if r.get("day"):
                    teacher_active_days[tu].add(str(r["day"]))
    for o in offerings:
        if o.get("pending_faculty_source_rows"):
            continue
        for t in (o.get("teachers") or ()):
            tu = str(t).strip().upper()
            if tu:
                assigned_acronyms.add(tu)

    resolved_faculty_off_days: list[dict[str, Any]] = []
    for tu in sorted(assigned_acronyms):
        prof = teacher_profiles.get(tu) or {}
        emp = str(prof.get("employment_type") or "permanent").strip().lower()
        declared = [d for d in (prof.get("off_days") or ()) if d in days]
        active = [d for d in days if d in teacher_active_days.get(tu, set())]
        free = [d for d in days if d not in teacher_active_days.get(tu, set())]

        if emp == "permanent":
            if resolved_off_days_by_teacher and tu in resolved_off_days_by_teacher:
                resolved = [d for d in resolved_off_days_by_teacher[tu] if d in days]
            elif len(declared) >= 2:
                resolved = list(declared)
            else:
                extra_needed = max(0, 2 - len(declared))
                extra_free = [d for d in free if d not in declared][:extra_needed]
                resolved = list(declared) + extra_free
            provenance = (
                "declared"
                if len(declared) >= 2
                else ("partial_hybrid" if len(declared) == 1 else "solver_resolved")
            )
            if (prof.get("explicit_employment_type", False) or policy is not None) and len(days) >= 2:
                required_min = 3 if (len(declared) == 3 and prof.get("allow_three_off_days")) else 2
                if not set(declared).issubset(set(free)) or len(free) < required_min:
                    _record_violation(
                        "r7_permanent_offday_violations",
                        {
                            "teacher": tu,
                            "declared_off_days": declared,
                            "free_days": free,
                            "required_min": required_min,
                        },
                    )
        elif emp == "adjunct":
            resolved = list(free)
            if declared and set(free) == set(declared):
                provenance = "declared"
            elif declared:
                provenance = "partial_hybrid"
            else:
                provenance = "solver_resolved"
        else:  # guest
            avail_days = {
                str(w.get("day") if isinstance(w, dict) else getattr(w, "day", "")).strip()
                for w in (prof.get("available_slots") or ())
            }
            resolved = [d for d in days if d not in avail_days or d in declared]
            provenance = "declared"

        resolved_faculty_off_days.append(
            {
                "acronym": tu,
                "employment_type": emp,
                "declared_off_days": declared,
                "resolved_off_days": resolved,
                "active_teaching_days": active,
                "provenance": provenance,
            }
        )

    total_policy_violations = sum(violations.values())
    soft_metrics = {
        "r8_faculty_preferences": {
            "matched_slots": pref_matched,
            "total_with_preferences": pref_total,
            "satisfaction_pct": round((pref_matched / pref_total) * 100.0, 1) if pref_total else None,
        },
        "r9_sust_compactness": {
            "sust_faculty_count": sust_checked,
            "split_break_days": sust_split_days,
        },
        "r12_sessional_pairs": {
            "paired_two_credit_labs": r12_paired,
            "total_two_credit_labs": r12_total,
            "allow_sessional_across_break": policy.allow_sessional_across_break if policy else False,
        },
        "r6_adjunct_workload": adjunct_metrics,
        "r3_single_slot_holes": r3_single_holes,
        "resolved_faculty_off_days": resolved_faculty_off_days,
    }

    return {
        "policy_violations": dict(violations),
        "policy_violation_count": total_policy_violations,
        "policy_details": dict(details),
        "soft_metrics": soft_metrics,
        "resolved_faculty_off_days": resolved_faculty_off_days,
    }
