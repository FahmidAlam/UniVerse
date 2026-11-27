"""CP-SAT timetable solver + post-generation validation.

Works only on the normalized records produced by `ingest.py` — it has no
knowledge of spreadsheets.

Phase 1 (CP-SAT) assigns every session a (day, period).
Phase 2 (greedy) assigns rooms.
Phase 3 validates the result against the distribution it came from; a routine
that loses a required course, or gives one the wrong amount of teaching time,
is a FAILURE, not a warning.
"""

from __future__ import annotations

import json
import os
import re
import time
from collections import defaultdict
from pathlib import Path

from ortools.sat.python import cp_model
import domain
import policy_constraints
from room_policy import (
    is_cse_course,
    is_ecl_room,
    is_eee_course,
    is_physics_lab_course,
    is_physics_lab_room,
    room_key,
)

CONFIG_PATH = Path(__file__).parent / "config.json"

SOLVER_WORKERS = int(os.environ.get("SOLVER_WORKERS", "8"))

#: How many offending items each validation list carries back to the client.
#: The counts are always exact; only the examples are capped.
DETAIL_LIMIT = 50


def _minutes(clock):
    match = re.fullmatch(r'(\d{1,2}):(\d{2})(?::(\d{2}))?', str(clock))
    if not match:
        raise ValueError('Period times must use HH:MM or HH:MM:SS')
    h, m, s = int(match[1]), int(match[2]), int(match[3] or 0)
    if h > 24 or m > 59 or s > 59 or (h == 24 and (m or s)):
        raise ValueError('Invalid clock boundary')
    return h * 60 + m + s / 60


def _groups(batch, section):
    """CSE import adapter: source-specified joint sections reserve all members.

    This does not create canonical aliases or infer membership in routine UI.
    """
    return {(str(batch), member.strip()) for member in str(section).split('+')}


def load_config(override: dict | None = None) -> dict:
    if override:
        return _normalize_config(override)
    return _normalize_config(json.loads(CONFIG_PATH.read_text(encoding="utf-8")))


def _normalize_config(cfg: dict) -> dict:
    """Accept either the engine config.json shape or the DB-sourced shape
    (rooms[], faculty[], settings{}) and normalise to one internal form.

    Everything the university can change between terms — days taught, period
    times, which periods are unavailable on which day, term length — arrives
    here as data. None of it may become a literal further down.
    """
    settings = cfg.get("settings", cfg)
    raw_policy = (
        cfg.get("policy_snapshot")
        or settings.get("policy_snapshot")
        or cfg.get("committee_policy")
        or settings.get("committee_policy")
    )
    committee_policy: domain.CommitteePolicySnapshot | None = None
    if isinstance(raw_policy, domain.CommitteePolicySnapshot):
        committee_policy = raw_policy
    elif isinstance(raw_policy, dict):
        committee_policy = domain.CommitteePolicySnapshot.from_dict(raw_policy)

    days = cfg.get("days") or settings.get("days") or [
        "Sunday", "Monday", "Tuesday", "Wednesday",
        "Thursday", "Friday", "Saturday"]
    periods = list(cfg.get("periods") or settings.get("periods") or [])
    weights = settings.get("weights", {"different_days": 8, "compactness": 3,
                                       "spread": 2, "late_slot": 1})

    weeks = settings.get("weeks_in_term", cfg.get("weeks_in_term", 14))
    try:
        weeks = max(1, int(weeks))
    except (TypeError, ValueError):
        weeks = 14

    # Periods the solver may use. `online_periods` (e.g. the 19:00 slot) are
    # real teachable periods that simply aren't drawn on the printed grid;
    # they are schedulable only when explicitly enabled.
    excluded = _int_set(settings.get("excluded_periods", cfg.get("excluded_periods")))
    online = settings.get("online_periods", cfg.get("online_periods"))
    if online is None:
        # Legacy default, now expressed as data: the printed template's last
        # column is the 7:00pm "OL Class" slot the department holds in reserve.
        # It used to be dropped by a hard-coded `idx <= 6` filter in solve();
        # Timetable Settings can now enable it without a code change.
        online = [7]
    online_set = _int_set(online)
    allow_online = bool(
        settings.get(
            "allow_online_periods",
            cfg.get(
                "allow_online_periods",
                committee_policy.allow_online_slot if committee_policy else False,
            ),
        )
    )
    if committee_policy is not None and committee_policy.allow_online_slot:
        allow_online = True
    if not allow_online:
        excluded |= online_set

    # R15: honor daily_slot_count (6 vs 7 regular on-campus periods) when committee policy is active
    if committee_policy is not None:
        regular_candidates = sorted(
            (p for p in periods if int(p["idx"]) not in excluded and int(p["idx"]) not in online_set),
            key=lambda p: _minutes(p["start"]),
        )
        if len(regular_candidates) > committee_policy.daily_slot_count:
            for extra_p in regular_candidates[committee_policy.daily_slot_count:]:
                excluded.add(int(extra_p["idx"]))

    usable = [p for p in periods if int(p['idx']) not in excluded]
    if len({int(p['idx']) for p in usable}) != len(usable):
        raise ValueError('Duplicate period identifiers')
    spans = sorted((_minutes(p['start']), _minutes(p['end'])) for p in usable)
    if any(end <= start for start, end in spans):
        raise ValueError('Periods must be forward same-day intervals')
    if any(b[0] < a[1] for a, b in zip(spans, spans[1:])):
        raise ValueError('Configured clock periods overlap; use a non-overlapping grid')

    # Per-day unavailable periods, e.g. {"Friday": [4]}. `friday_no_p4` is the
    # legacy single-purpose flag; it is folded in so old configs keep working.
    blocked: dict[str, set[int]] = {}
    for day, plist in (settings.get("blocked_periods",
                                    cfg.get("blocked_periods")) or {}).items():
        blocked.setdefault(str(day), set()).update(_int_set(plist))
    friday_no_p4 = bool(
        settings.get(
            "friday_no_p4",
            cfg.get(
                "friday_no_p4",
                committee_policy.friday_no_p4 if committee_policy else True,
            ),
        )
    )
    if committee_policy is not None and committee_policy.friday_no_p4:
        friday_no_p4 = True
    if friday_no_p4:
        blocked.setdefault("Friday", set()).add(4)

    aliases = cfg.get('room_aliases', settings.get('room_aliases')) or {}
    unavailable = {room_key(r, aliases) for r in
                   (cfg.get('unavailable_rooms', settings.get('unavailable_rooms')) or [])}
    active_pool_filter = (
        {room_key(name, aliases) for name in committee_policy.active_room_pool}
        if committee_policy is not None and committee_policy.active_room_pool
        else set()
    )

    rooms = []
    physical = {}
    has_extended_room_fields = False
    for raw in cfg.get('rooms') or []:
        key = room_key(raw['name'], aliases)
        if key in unavailable or not raw.get('is_active', True):
            continue
        if active_pool_filter and key not in active_pool_filter:
            continue
        if any(k in raw for k in ("room_pool_role", "available_slots")):
            has_extended_room_fields = True
        if key in physical:
            old = physical[key]
            if any(old.get(field) != raw.get(field) for field in ('is_lab', 'capacity')):
                raise ValueError('Room aliases have conflicting type/capacity metadata')
            continue
        physical[key] = raw
        rooms.append(raw)

    lab_rooms, theory_rooms = [], []
    for r in rooms:
        name = r["name"]
        role = str(r.get("room_pool_role") or "").strip().lower()
        if r.get("is_lab") or role in ("cse_lab", "ecl_lab", "physics_lab"):
            lab_rooms.append(name)
        else:
            # R14: Never drop named general classrooms (e.g. "Seminar Hall") via digit heuristic
            theory_rooms.append(name)

    if 'rooms' not in cfg:
        def unique_rooms(values):
            by_key = {}
            for label in values:
                key = room_key(label, aliases)
                if key not in unavailable and (not active_pool_filter or key in active_pool_filter):
                    by_key.setdefault(key, label)
            return list(by_key.values())
        lab_rooms = unique_rooms(cfg.get('lab_rooms', []))
        theory_rooms = unique_rooms(cfg.get('theory_rooms', []))
        if {room_key(r, aliases) for r in lab_rooms} & {room_key(r, aliases) for r in theory_rooms}:
            raise ValueError('Conflicting room kinds for physical aliases')

    room_meta_map = {r['name']: r for r in rooms}
    ecl_lab_rooms = [
        r for r in lab_rooms
        if (str(room_meta_map.get(r, {}).get("room_pool_role") or "").lower() == "ecl_lab")
        or (str(room_meta_map.get(r, {}).get("room_pool_role") or "general").lower() == "general" and is_ecl_room(r, aliases))
    ]
    ecl_set = set(ecl_lab_rooms)
    physics_lab_rooms = [
        r for r in lab_rooms
        if r not in ecl_set and is_physics_lab_room(room_meta_map.get(r, r), aliases)
    ]
    phy_set = set(physics_lab_rooms)
    cse_lab_rooms = [r for r in lab_rooms if r not in ecl_set and r not in phy_set]

    teachers = cfg.get("teachers") or cfg.get("faculty") or {}
    off_days: dict[str, set[str]] = {}
    names: dict[str, str] = {}
    teacher_profiles: dict[str, dict] = {}
    has_extended_teacher_fields = False

    def _ingest_teacher(ac_raw: str, t: dict) -> None:
        nonlocal has_extended_teacher_fields
        ac = str(ac_raw).strip()
        if not ac or not t.get("is_active", True):
            return
        ac_upper = ac.upper()
        off_list = [str(d).strip() for d in (t.get("off_days") or []) if str(d).strip()]
        off_days[ac] = set(off_list)
        if ac_upper != ac:
            off_days[ac_upper] = set(off_list)
        if t.get("full_name"):
            names[ac] = t["full_name"]
            if ac_upper != ac:
                names[ac_upper] = t["full_name"]

        explicit_emp = "employment_type" in t
        if explicit_emp or any(
            k in t
            for k in (
                "allow_three_off_days",
                "is_sust_adjunct",
                "external_blocked_slots",
                "available_slots",
                "preferred_slots",
            )
        ):
            has_extended_teacher_fields = True
        teacher_profiles[ac_upper] = {
            "acronym": ac_upper,
            "employment_type": str(t.get("employment_type") or "permanent").strip().lower(),
            "explicit_employment_type": explicit_emp,
            "off_days": tuple(off_list),
            "allow_three_off_days": bool(t.get("allow_three_off_days", False)),
            "is_sust_adjunct": bool(t.get("is_sust_adjunct", False)),
            "external_blocked_slots": list(t.get("external_blocked_slots") or []),
            "available_slots": list(t.get("available_slots") or []),
            "preferred_slots": list(t.get("preferred_slots") or []),
            "is_active": bool(t.get("is_active", True)),
            "dept": t.get("dept"),
        }

    if isinstance(teachers, dict):
        for ac, t in teachers.items():
            if isinstance(t, dict):
                _ingest_teacher(ac, t)
    else:
        for t in teachers:
            if isinstance(t, dict) and t.get("acronym"):
                _ingest_teacher(t["acronym"], t)

    raw_sections = list(cfg.get("sections") or settings.get("sections") or [])
    sections_catalog: dict[tuple[str, str], dict] = {}
    for sec in raw_sections:
        if not isinstance(sec, dict) or not sec.get("is_active", True):
            continue
        b = str(sec.get("batch") or "").strip()
        s = str(sec.get("section") or "").strip().upper()
        if b and s:
            sections_catalog[(b, s)] = sec

    raw_courses = list(cfg.get("courses") or settings.get("courses") or [])
    courses_catalog: dict[str, dict] = {}
    for c in raw_courses:
        if not isinstance(c, dict) or not c.get("is_active", True):
            continue
        code_u = str(c.get("code") or "").strip().upper()
        if code_u:
            courses_catalog[code_u] = c

    physics_codes_raw = {
        str(c).strip().upper()
        for c in (cfg.get("physics_lab_course_codes") or settings.get("physics_lab_course_codes") or [])
        if str(c).strip()
    }
    if committee_policy is not None:
        physics_codes_raw.update(committee_policy.physics_lab_course_codes)
    for code_u, c_meta in courses_catalog.items():
        if c_meta.get("is_physics_lab"):
            physics_codes_raw.add(code_u)

    has_extended_policy_fields = bool(
        committee_policy is not None
        or has_extended_teacher_fields
        or has_extended_room_fields
        or raw_sections
        or raw_courses
    )

    return {
        "days": days,
        "periods": periods,
        "break_col": settings.get('break_col', cfg.get('break_col', 'G')),
        "break_after_period": settings.get('break_after_period', cfg.get('break_after_period')),
        "online_periods": sorted(online_set),
        "allow_online_periods": allow_online,
        "excluded_periods": excluded,
        "blocked_periods": blocked,
        "weeks_in_term": weeks,
        "weights": weights,
        "lab_rooms": lab_rooms,
        "ecl_lab_rooms": ecl_lab_rooms,
        "physics_lab_rooms": physics_lab_rooms,
        "cse_lab_rooms": cse_lab_rooms,
        "theory_rooms": theory_rooms,
        "room_metadata": room_meta_map,
        "room_aliases": aliases,
        "unavailable_rooms": unavailable,
        "off_days": off_days,
        "names": names,
        "teacher_profiles": teacher_profiles,
        "committee_policy": committee_policy,
        "physics_lab_course_codes": sorted(physics_codes_raw),
        "raw_section_overrides": raw_sections,
        "sections_catalog": sections_catalog,
        "courses_catalog": courses_catalog,
        "strict_adjunct_day_bands": bool(
            cfg.get("strict_adjunct_day_bands", settings.get("strict_adjunct_day_bands", False))
        ),
        "has_extended_policy_fields": has_extended_policy_fields,
        "semester_label": settings.get("semester_label"),
        "semester_map": settings.get("semester_map", cfg.get("semester_map")) or {},
        "lab_adjacency": cfg.get("lab_adjacency",
                                 settings.get("lab_adjacency", "hard")),
        "allow_same_day_sessions": bool(
            settings.get("allow_same_day_sessions",
                         cfg.get("allow_same_day_sessions", False))),
        "same_day_exempt_courses": {
            str(c).strip().upper()
            for c in (settings.get("same_day_exempt_courses",
                                   cfg.get("same_day_exempt_courses")) or [])
            if str(c).strip()
        },
        "fixed_sessions_per_week": _positive_int(
            settings.get("fixed_sessions_per_week",
                         cfg.get("fixed_sessions_per_week"))),
        "eligibility": _normalize_eligibility(
            settings.get("eligibility", cfg.get("eligibility"))),
    }


def _normalize_eligibility(raw) -> dict:
    """Normalize the faculty-course eligibility table into lookup form.

    Shape in:  [{"acronym": "EBH", "course_code": "CSE-1101",
                 "eligible": true, "priority": 1}, ...]
    Shape out: {"eligible": {ACRONYM: {CODE, ...}},
                "priority": {(ACRONYM, CODE): int},
                "declared": {ACRONYM, ...}}

    `declared` is the set of teachers the admin has actually configured. A
    teacher with no rows is "not configured", not "eligible for nothing" —
    otherwise switching the feature on would fail every offering in the
    distribution at once. Only a teacher who HAS a configured course list can
    violate it.
    """
    eligible: dict[str, set[str]] = {}
    priority: dict[tuple[str, str], int] = {}
    declared: set[str] = set()
    for item in (raw or []):
        if not isinstance(item, dict):
            continue
        ac = str(item.get("acronym") or "").strip().upper()
        code = str(item.get("course_code") or "").strip().upper()
        if not ac or not code:
            continue
        declared.add(ac)
        if item.get("eligible", True):
            eligible.setdefault(ac, set()).add(code)
            pr = item.get("priority")
            if pr is not None:
                try:
                    priority[(ac, code)] = int(pr)
                except (TypeError, ValueError):
                    pass
    return {"eligible": eligible, "priority": priority, "declared": declared}


def _positive_int(v) -> int | None:
    """A positive int, or None for "not configured"."""
    try:
        n = int(v)
    except (TypeError, ValueError):
        return None
    return n if n > 0 else None


def _int_set(v) -> set[int]:
    out: set[int] = set()
    for item in (v or []):
        try:
            out.add(int(item))
        except (TypeError, ValueError):
            continue
    return out


class _Progress:
    def __init__(self, cb=None):
        self.cb = cb

    def __call__(self, value: float):
        if self.cb:
            self.cb(value)


def _last_digit_pos(code: str):
    """(int last digit, match) of the trailing number, or (None, None)."""
    m = re.search(r"(\d)\s*$", code)
    return (int(m.group(1)), m) if m else (None, None)


def _build_pairs(offerings: list[dict],
                 sessions_by_oid: dict[int, list[dict]]) -> list[tuple[dict, dict]]:
    """Match each lab offering to its sibling theory offering and return the
    per-occurrence (theory_session, lab_session) pairs to keep adjacent.

    Pairing key = the department's even-digit rule: a lab `code` ending in an
    even digit `d` pairs with the theory whose code is identical except the last
    digit is `d-1` (e.g. CSE-1102 <-> CSE-1101), in the same cohort. Now that a
    cohort has exactly one offering per course code, this is a direct lookup —
    the old teacher-matching fallback is gone with the duplicate rows that
    forced it. Standalone labs yield no pair and stay unconstrained.
    """
    by_cc = {(o["cohort"], o["code"]): o for o in offerings}

    pairs: list[tuple[dict, dict]] = []
    for o in offerings:
        d, m = _last_digit_pos(o["code"])
        if d is None or d % 2 != 0:
            continue
        theory = by_cc.get((o["cohort"], o["code"][:m.start(1)] + str(d - 1)
                            + o["code"][m.end(1):]))
        if theory is None:
            continue
        tsess = sorted(sessions_by_oid[theory["oid"]], key=lambda s: s["occurrence"])
        lsess = sorted(sessions_by_oid[o["oid"]], key=lambda s: s["occurrence"])
        for occ in range(min(len(tsess), len(lsess))):
            pairs.append((tsess[occ], lsess[occ]))
    return pairs


def solve(dataset: dict, config: dict, time_limit_s: float = 60.0,
          progress: _Progress | None = None,
          return_outcomes: bool = False) -> dict:
    progress = progress or _Progress()
    cfg = config
    days = cfg["days"]
    periods = [p for p in cfg["periods"]
               if int(p["idx"]) not in cfg["excluded_periods"]]
    pidx = [int(p["idx"]) for p in periods]
    pmeta = {int(p["idx"]): p for p in periods}
    blocked = cfg["blocked_periods"]
    off_days = cfg["off_days"]
    aliases = cfg.get("room_aliases") or {}
    lab_rooms = cfg.get("lab_rooms", [])
    ecl_lab_rooms = cfg.get("ecl_lab_rooms") or [r for r in lab_rooms if is_ecl_room(r, aliases)]
    physics_lab_rooms = cfg.get("physics_lab_rooms") or []
    cse_lab_rooms = cfg.get("cse_lab_rooms") or [
        r for r in lab_rooms if not is_ecl_room(r, aliases) and r not in set(physics_lab_rooms)
    ]
    w = cfg["weights"]
    committee_policy = cfg.get("committee_policy")
    physics_codes = policy_constraints.effective_physics_codes(cfg)
    structured_mode = bool(
        return_outcomes or committee_policy is not None or cfg.get("has_extended_policy_fields")
    )

    if committee_policy is not None or cfg.get("courses_catalog") or cfg.get("sections_catalog"):
        dataset = policy_constraints.apply_policy_to_dataset(dataset, cfg)

    presolve_conflicts = policy_constraints.check_presolve_inputs(
        dataset, cfg, days, periods, pmeta
    )
    if presolve_conflicts:
        msg = presolve_conflicts[0]["message"]
        payload = {
            "outcome": policy_constraints.OUTCOME_INPUT_ERROR,
            "raw_status": "INPUT_ERROR",
            "termination_reason": "input_validation_failed",
            "proven_infeasible": True,
            "conflicts": presolve_conflicts,
            "error": msg,
            "stats": {
                "status": "INPUT_ERROR",
                "solve_ms": 0,
                "meetings": 0,
                "service_meetings": 0,
                "offerings": len(dataset.get("offerings", [])),
                "cohorts": len(dataset.get("cohorts", [])),
                "teachers": len(dataset.get("teachers_used", [])),
                "objective": 0,
                "lab_theory_pairs": 0,
                "lab_theory_adjacent": 0,
            },
            "validation": None,
        }
        if structured_mode:
            return payload
        raise policy_constraints.SolverOutcomeError(msg, payload)

    online_set = _int_set(cfg.get("online_periods") or [7])
    topology = policy_constraints.build_grid_topology(
        days=days,
        periods=periods,
        online_periods=online_set,
        blocked_periods=blocked,
        break_after_period=cfg.get("break_after_period"),
    )

    adj_mode = cfg.get("lab_adjacency", "hard")
    same_day_ok = bool(cfg.get("allow_same_day_sessions", False))
    same_day_exempt = cfg.get("same_day_exempt_courses") or set()
    neighbors = topology.neighbors

    sessions = dataset["sessions"]
    offerings = dataset.get("offerings", [])
    offering_of = {o["oid"]: o for o in offerings}

    sessions_by_oid: dict[int, list[dict]] = defaultdict(list)
    for s in sessions:
        sessions_by_oid[s["oid"]].append(s)

    def teachers_of(s) -> list[str]:
        return s.get("teachers") or ([s["teacher"]] if s.get("teacher") else [])

    def valid_slots(s) -> list[tuple[int, int]]:
        """(day, period) options for a session. Every teacher sharing the
        offering must be free — a co-teacher takes the same slot later in the
        term, so the slot has to suit all of them."""
        out = []
        blocked_days = set()
        for t in teachers_of(s):
            blocked_days |= off_days.get(t, set())
        off_obj = offering_of.get(s["oid"]) or {}
        for di, dname in enumerate(days):
            if dname in blocked_days:
                continue
            day_blocked = blocked.get(dname, set())
            for p in pidx:
                if p in day_blocked:
                    continue
                if not policy_constraints.session_slot_allowed_by_teachers_and_rooms(
                    s, off_obj, dname, p, pmeta, cfg, physics_codes
                ):
                    continue
                out.append((di, p))
        return out

    model = cp_model.CpModel()
    x: dict[tuple[int, int, int], cp_model.IntVar] = {}
    slots_for: dict[int, list[tuple[int, int]]] = {}
    for s in sessions:
        sl = valid_slots(s)
        slots_for[s["sid"]] = sl
        for (d, p) in sl:
            x[(s["sid"], d, p)] = model.NewBoolVar(f"x_{s['sid']}_{d}_{p}")

    for s in sessions:
        vs = [x[(s["sid"], d, p)] for (d, p) in slots_for[s["sid"]]]
        if not vs:
            msg = _no_slot_message(s, cfg, days, pidx, teachers_of(s))
            c_rule = "R7"
            c_entity_type = "course"
            c_entity_id = f"{s['cohort']} {s['code']}"
            for t in teachers_of(s):
                prof = (cfg.get("teacher_profiles") or {}).get(str(t).strip().upper()) or {}
                if prof.get("employment_type") == "guest":
                    c_rule = "R5"
                    c_entity_type = "faculty"
                    c_entity_id = t
                    break
                if prof.get("external_blocked_slots"):
                    c_rule = "R4"
                    c_entity_type = "faculty"
                    c_entity_id = t
                    break
            payload = {
                "outcome": policy_constraints.OUTCOME_INFEASIBLE,
                "raw_status": "INFEASIBLE",
                "termination_reason": "empty_session_domain",
                "proven_infeasible": True,
                "conflicts": [
                    policy_constraints.make_conflict(
                        rule=c_rule,
                        code="empty_session_domain",
                        entity_type=c_entity_type,
                        entity_id=c_entity_id,
                        message=msg,
                        proven=True,
                    )
                ],
                "error": msg,
                "stats": {
                    "status": "INFEASIBLE",
                    "solve_ms": 0,
                    "meetings": 0,
                    "service_meetings": 0,
                    "offerings": len(offerings),
                    "cohorts": len(dataset.get("cohorts", [])),
                    "teachers": 0,
                    "objective": 0,
                    "lab_theory_pairs": 0,
                    "lab_theory_adjacent": 0,
                },
                "validation": None,
            }
            if structured_mode:
                return payload
            raise policy_constraints.SolverOutcomeError(msg, payload)
        model.AddExactlyOne(vs)

    # A teacher is busy for every offering they are attached to, co-taught or not.
    by_teacher: dict[str, list[dict]] = defaultdict(list)
    by_cohort: dict[tuple[str, str], list[dict]] = defaultdict(list)
    for s in sessions:
        for t in teachers_of(s):
            by_teacher[t].append(s)
        for group in _groups(s['batch'], s['section']):
            by_cohort[group].append(s)

    for di in range(len(days)):
        for p in pidx:
            for group in by_teacher.values():
                terms = [x[(s["sid"], di, p)] for s in group if (s["sid"], di, p) in x]
                if len(terms) > 1:
                    model.Add(sum(terms) <= 1)
            for group in by_cohort.values():
                terms = [x[(s["sid"], di, p)] for s in group if (s["sid"], di, p) in x]
                if len(terms) > 1:
                    model.Add(sum(terms) <= 1)

    penalties: list = []

    policy_meta = policy_constraints.add_policy_constraints(
        model=model,
        x=x,
        slots_for=slots_for,
        sessions=sessions,
        offerings=offerings,
        offering_of=offering_of,
        sessions_by_oid=sessions_by_oid,
        by_cohort=by_cohort,
        by_teacher=by_teacher,
        days=days,
        pidx=pidx,
        pmeta=pmeta,
        topology=topology,
        cfg=cfg,
        penalties=penalties,
    )
    r13_block_oids: set[int] = policy_meta["r13_block_oids"]
    if policy_meta["early_conflicts"]:
        msg = policy_meta["early_conflicts"][0]["message"]
        payload = {
            "outcome": policy_constraints.OUTCOME_INFEASIBLE,
            "raw_status": "INFEASIBLE",
            "termination_reason": "proven_infeasible",
            "proven_infeasible": True,
            "conflicts": policy_meta["early_conflicts"],
            "error": msg,
            "stats": {
                "status": "INFEASIBLE",
                "solve_ms": 0,
                "meetings": 0,
                "service_meetings": 0,
                "offerings": len(offerings),
                "cohorts": len(dataset.get("cohorts", [])),
                "teachers": len(by_teacher),
                "objective": 0,
                "lab_theory_pairs": 0,
                "lab_theory_adjacent": 0,
            },
            "validation": None,
        }
        if structured_mode:
            return payload
        raise policy_constraints.SolverOutcomeError(msg, payload)

    # Occurrences of one offering are interchangeable. Ordering them by slot
    # removes that symmetry, which matters now that an offering can need three
    # sessions instead of always two.
    npp = len(pidx)
    slot_rank = {p: i for i, p in enumerate(pidx)}
    for oid, group in sessions_by_oid.items():
        group = sorted(group, key=lambda s: s["occurrence"])
        if len(group) < 2:
            continue
        ranks = []
        for s in group:
            r = model.NewIntVar(0, len(days) * npp - 1, f"rank_{s['sid']}")
            model.Add(r == sum(x[(s["sid"], d, p)] * (d * npp + slot_rank[p])
                               for (d, p) in slots_for[s["sid"]]))
            ranks.append(r)
        for a, b in zip(ranks, ranks[1:]):
            model.Add(a < b)

    # One offering may not meet twice on the same day (except R13 low-credit blocks
    # and R12 2-credit sessionals which have dedicated pattern rules).
    r12_two_cr_oids = {
        o["oid"]
        for o in offerings
        if committee_policy is not None
        and o.get("is_lab")
        and o.get("credit") is not None
        and abs(float(o["credit"]) - 2.0) < 1e-6
    }
    for oid, group in sessions_by_oid.items():
        if len(group) < 2 or oid in r13_block_oids or oid in r12_two_cr_oids:
            continue
        off_obj = offering_of.get(oid, {})
        three_cr_enforced = (
            committee_policy is not None
            and committee_policy.three_credit_theory_spread
            and not off_obj.get("is_lab")
            and not off_obj.get("is_service")
            and is_cse_course(str(off_obj.get("code") or ""), off_obj.get("course_dept"))
            and off_obj.get("credit") is not None
            and abs(float(off_obj["credit"]) - 3.0) < 1e-6
        )
        exempt = (
            not three_cr_enforced
            and (same_day_ok or off_obj.get("code") in same_day_exempt)
        )
        for di in range(len(days)):
            terms = [x[(s["sid"], di, p)] for s in group for p in pidx
                     if (s["sid"], di, p) in x]
            if len(terms) < 2:
                continue
            if exempt:
                extra = model.NewIntVar(0, len(group) - 1, f"same_{oid}_{di}")
                model.Add(extra >= sum(terms) - 1)
                penalties.append(w.get("different_days", 8) * extra)
            else:
                model.Add(sum(terms) <= 1)

    lt_pairs = [
        (a, b)
        for (a, b) in _build_pairs(offerings, sessions_by_oid)
        if committee_policy is None or a["oid"] not in r13_block_oids
    ]
    if adj_mode == "hard":
        for a, b in lt_pairs:
            asid, bsid = a["sid"], b["sid"]
            for di in range(len(days)):
                at = [x[(asid, di, p)] for p in pidx if (asid, di, p) in x]
                bt = [x[(bsid, di, p)] for p in pidx if (bsid, di, p) in x]
                if at or bt:
                    model.Add(sum(at) == sum(bt))
                for p in pidx:
                    if (asid, di, p) not in x:
                        continue
                    nb = [x[(bsid, di, q)] for q in neighbors[p]
                          if (bsid, di, q) in x]
                    model.Add(sum(nb) >= x[(asid, di, p)])
    elif adj_mode == "soft":
        for a, b in lt_pairs:
            asid, bsid = a["sid"], b["sid"]
            adj = model.NewBoolVar(f"adj_{asid}_{bsid}")
            zs = []
            for di in range(len(days)):
                for p in pidx:
                    if (asid, di, p) not in x:
                        continue
                    for q in neighbors[p]:
                        if (bsid, di, q) not in x:
                            continue
                        z = model.NewBoolVar(f"z_{asid}_{bsid}_{di}_{p}_{q}")
                        model.Add(z <= x[(asid, di, p)])
                        model.Add(z <= x[(bsid, di, q)])
                        zs.append(z)
            if zs:
                model.Add(adj <= sum(zs))
                penalties.append(w.get("lab_adjacency", 10) * (1 - adj))

    for cohort, group in by_cohort.items():
        for di in range(len(days)):
            used = model.NewBoolVar(f"used_{cohort}_{di}")
            terms = [x[(s["sid"], di, p)] for s in group for p in pidx
                     if (s["sid"], di, p) in x]
            for t in terms:
                model.Add(used >= t)
            penalties.append(w.get("compactness", 3) * used)

    last_p = max(pidx)
    for s in sessions:
        for di in range(len(days)):
            if (s["sid"], di, last_p) in x:
                penalties.append(w.get("late_slot", 1) * x[(s["sid"], di, last_p)])

    model.Minimize(sum(penalties))

    solver = cp_model.CpSolver()
    solver.parameters.max_time_in_seconds = time_limit_s
    solver.parameters.num_search_workers = SOLVER_WORKERS
    progress(0.5)
    t0 = time.time()
    status = solver.Solve(model)
    solve_ms = int((time.time() - t0) * 1000)
    progress(0.82)

    raw_status = solver.StatusName(status)
    wall_s = float(solver.WallTime())

    if status not in (cp_model.OPTIMAL, cp_model.FEASIBLE):
        if status == cp_model.INFEASIBLE:
            outcome = policy_constraints.OUTCOME_INFEASIBLE
            term_reason = "proven_infeasible"
            proven_infeasible = True
        elif status == cp_model.MODEL_INVALID:
            outcome = policy_constraints.OUTCOME_INPUT_ERROR
            term_reason = "model_invalid"
            proven_infeasible = False
        elif status == cp_model.UNKNOWN and (
            (time_limit_s > 0 and wall_s >= max(0.0, time_limit_s * 0.7))
            or time_limit_s <= 0.1
        ):
            outcome = policy_constraints.OUTCOME_TIME_LIMIT
            term_reason = "time_limit_no_incumbent"
            proven_infeasible = False
        else:
            outcome = policy_constraints.OUTCOME_UNKNOWN
            term_reason = "solver_unknown"
            proven_infeasible = False

        msg, conflicts = policy_constraints.diagnose_infeasibility(
            raw_status=raw_status,
            termination_reason=term_reason,
            sessions=sessions,
            offerings=offerings,
            offering_of=offering_of,
            slots_for=slots_for,
            days=days,
            pidx=pidx,
            pmeta=pmeta,
            cfg=cfg,
            early_conflicts=[],
        )
        payload = {
            "outcome": outcome,
            "raw_status": raw_status,
            "termination_reason": term_reason,
            "proven_infeasible": proven_infeasible,
            "conflicts": conflicts,
            "error": msg,
            "stats": {
                "status": raw_status,
                "solve_ms": solve_ms,
                "meetings": 0,
                "service_meetings": 0,
                "offerings": len(offerings),
                "cohorts": len(dataset.get("cohorts", [])),
                "teachers": len(by_teacher),
                "objective": 0,
                "lab_theory_pairs": 0,
                "lab_theory_adjacent": 0,
            },
            "validation": None,
        }
        if structured_mode:
            return payload
        raise policy_constraints.SolverOutcomeError(msg, payload)

    placed = []
    for s in sessions:
        for (d, p) in slots_for[s["sid"]]:
            if solver.Value(x[(s["sid"], d, p)]) == 1:
                placed.append({"s": s, "day": d, "period": p})
                break
    progress(0.88)

    rows, service_rows, room_failures = _assign_rooms(
        dataset,
        cfg,
        placed,
        days,
        pmeta,
        policy_meta=policy_meta,
        solver=solver,
    )
    progress(0.96)

    place_of = {q["s"]["sid"]: (q["day"], q["period"]) for q in placed}
    adj_ok = 0
    for a, b in lt_pairs:
        pa, pb = place_of.get(a["sid"]), place_of.get(b["sid"])
        if pa and pb and pa[0] == pb[0] and pb[1] in neighbors.get(pa[1], []):
            adj_ok += 1

    validation = _validate(dataset, cfg, rows + service_rows, days, pmeta)
    if room_failures:
        validation["details"]["unplaced_rooms"] = room_failures[:DETAIL_LIMIT]
    validation["lab_theory_pairs"] = len(lt_pairs)
    validation["lab_theory_adjacent"] = adj_ok
    validation["lab_theory_violations"] = len(lt_pairs) - adj_ok
    if adj_mode == "hard" and validation["lab_theory_violations"] > 0:
        validation["ok"] = False

    outcome = (
        policy_constraints.OUTCOME_OPTIMAL
        if status == cp_model.OPTIMAL
        else policy_constraints.OUTCOME_FEASIBLE
    )
    term_reason = (
        "optimal"
        if status == cp_model.OPTIMAL
        else (
            "time_limit_with_incumbent"
            if (time_limit_s > 0 and wall_s >= max(0.05, time_limit_s * 0.85))
            else "feasible"
        )
    )
    policy_warnings = list(dataset.get("policy_warnings") or [])
    if room_failures:
        for rf in room_failures[:10]:
            policy_warnings.append(
                policy_constraints.make_conflict(
                    rule="R14",
                    code="room_allocation_failed",
                    entity_type="room",
                    entity_id=f"{rf['cohort']} {rf['code']}",
                    message=rf["reason"],
                    proven=True,
                )
            )

    return {
        "outcome": outcome,
        "raw_status": raw_status,
        "termination_reason": term_reason,
        "proven_infeasible": False,
        "conflicts": policy_warnings,
        "rows": rows,
        "service_rows": service_rows,
        "stats": {
            "status": raw_status,
            "outcome": outcome,
            "termination_reason": term_reason,
            "solve_ms": solve_ms,
            "meetings": len(rows),
            "service_meetings": len(service_rows),
            "offerings": len(offerings),
            "cohorts": len(dataset["cohorts"]),
            "teachers": len(by_teacher),
            "objective": int(solver.ObjectiveValue()),
            "lab_theory_pairs": len(lt_pairs),
            "lab_theory_adjacent": adj_ok,
        },
        "validation": validation,
        "soft_metrics": validation.get("soft_metrics"),
    }


def _no_slot_message(s, cfg, days, pidx, teachers) -> str:
    """Traceable failure for a session with an empty domain: name the course,
    the cohort, every teacher involved, and the rule that emptied it."""
    parts = []
    for t in teachers:
        off = sorted(cfg["off_days"].get(t, set()))
        parts.append(f"{t} off {off or 'never'}")
    blocked = {d: sorted(p) for d, p in cfg["blocked_periods"].items() if p}
    return (
        f"No valid slot for {s['code']} ({s['cohort']}, occurrence "
        f"{s['occurrence']}). Teachers: {'; '.join(parts)}. "
        f"Days taught: {days}. Periods available: {pidx}. "
        f"Per-day blocked periods: {blocked or 'none'}. "
        f"Free a day-off, add a period, or reassign the course.")


def _infeasible_message(status_name, sessions, teachers_of, slots_for,
                        offering_of, days, pidx, cfg=None) -> str:
    """Explain WHY the model has no solution instead of returning a bare
    INFEASIBLE. The usual cause is a teacher whose demand exceeds the slots
    their day-offs leave them, so name the worst offenders."""
    load: dict[str, int] = defaultdict(int)
    capacity: dict[str, int] = {}
    for s in sessions:
        for t in teachers_of(s):
            load[t] += 1
            capacity[t] = min(capacity.get(t, 10**9), len(slots_for[s["sid"]]))

    over = sorted(((t, load[t], capacity.get(t, 0)) for t in load
                   if load[t] > capacity.get(t, 0)),
                  key=lambda r: r[1] - r[2], reverse=True)[:5]
    lines = [f"No feasible timetable (status={status_name})."]
    if over:
        lines.append("Over-committed teachers (sessions needed vs slots free):")
        lines += [f"  - {t}: needs {n}, has {cap} usable (day,period) slots"
                  for t, n, cap in over]
        lines.append("Reduce their load, remove a day-off, or add periods.")
    else:
        aliases = (cfg or {}).get("room_aliases") or {}
        lab_rooms = (cfg or {}).get("lab_rooms") or []
        ecl_labs = [r for r in lab_rooms if is_ecl_room(r, aliases)]
        cse_labs = [r for r in lab_rooms if not is_ecl_room(r, aliases)]
        has_eee_lab = any(s.get("is_lab") and is_eee_course(s.get("code", ""), (offering_of.get(s.get("oid")) or {}).get("course_dept")) for s in sessions)
        has_cse_lab = any(s.get("is_lab") and is_cse_course(s.get("code", ""), (offering_of.get(s.get("oid")) or {}).get("course_dept")) for s in sessions)
        if has_eee_lab and not ecl_labs:
            lines.append("No ECL laboratory rooms are configured or available, but EEE laboratory courses require ECL rooms.")
        if has_cse_lab and not cse_labs:
            lines.append("No CSE laboratory rooms are configured or available, but CSE laboratory courses require CSE rooms.")
        lines.append(
            "No single teacher is over-committed, so the clash is structural: "
            "room capacity, lab/theory adjacency, or cohort load across active "
            "constraints. Add rooms, resolve availability blocks, or raise the time limit.")
    return " ".join(lines) if len(lines) == 2 else "\n".join(lines)


def _assign_rooms(dataset, cfg, placed, days, pmeta,
                  policy_meta: dict | None = None, solver=None):
    busy: dict[tuple[int, int], set[str]] = {}
    names = cfg["names"]
    semester_map = cfg.get("semester_map") or {}
    physics_codes = policy_constraints.effective_physics_codes(cfg)

    numeric_batches = [int(p["s"]["batch"]) for p in placed
                       if p["s"]["batch"].isdigit()]
    max_batch = max(numeric_batches) if numeric_batches else 0

    def semester_for(batch: str) -> int:
        """Which study semester a batch is in.

        An explicit `semester_map` from configuration wins. The fallback assumes
        one intake per term and counts down from the newest batch — correct for a
        bi-semester year but wrong under a tri-semester calendar, which is why
        the map exists. Set it in Timetable Settings rather than relying on this.
        """
        mapped = semester_map.get(batch)
        if mapped is not None:
            try:
                return int(mapped)
            except (TypeError, ValueError):
                pass
        if not batch.isdigit() or max_batch == 0:
            return 1
        return min(8, max(1, max_batch - int(batch) + 1))

    offering_of = {o['oid']: o for o in dataset.get('offerings', [])}

    def sorted_candidates(pool, session):
        students = offering_of.get(session['oid'], {}).get('students')
        if students is None:
            return list(pool)
        return sorted(
            pool,
            key=lambda r: (
                cfg.get('room_metadata', {}).get(r, {}).get('capacity')
                if cfg.get('room_metadata', {}).get(r, {}).get('capacity') is not None
                else float('inf')
            ),
        )

    def pick_multi(pool, slots_dp: list[tuple[int, int]], session):
        students = offering_of.get(session['oid'], {}).get('students')
        for r in sorted_candidates(pool, session):
            if not policy_constraints.room_fits_students(r, students, cfg):
                continue
            if all(
                policy_constraints.room_is_open_at(r, days[d], p, pmeta, cfg)
                and r not in busy.get((d, p), set())
                for d, p in slots_dp
            ):
                return r
        return None

    def _placement_priority(q):
        s = q["s"]
        code = s["code"]
        off = offering_of.get(s["oid"]) or {}
        dept = off.get("course_dept")
        students = off.get("students") or 0
        if s["is_lab"]:
            if policy_constraints.is_physics_lab_course(code, physics_codes) or off.get("is_physics_lab"):
                category_rank = 0
            elif is_eee_course(code, dept):
                category_rank = 1
            elif is_cse_course(code, dept):
                category_rank = 2
            else:
                category_rank = 3
        else:
            category_rank = 4
        return (category_rank, -students, q["day"], q["period"])

    # Identify coupled pairs (R13 consecutive CSE theory blocks & R12 2-cr sessional pairs)
    assigned_room_by_sid: dict[int, str] = {}
    coupled_pairs: list[tuple[dict, dict]] = []
    coupled_sids: set[int] = set()

    if policy_meta is not None and solver is not None:
        placed_by_oid_dp: dict[tuple[int, int, int], dict] = {
            (q["s"]["oid"], q["day"], q["period"]): q for q in placed
        }
        for pair_map in (policy_meta.get("r13_pair_vars") or {}, policy_meta.get("r12_pair_vars") or {}):
            for (oid, di, p_a, p_b), pvar in pair_map.items():
                if solver.Value(pvar) == 1:
                    qa = placed_by_oid_dp.get((oid, di, p_a))
                    qb = placed_by_oid_dp.get((oid, di, p_b))
                    if qa and qb and qa["s"]["sid"] not in coupled_sids and qb["s"]["sid"] not in coupled_sids:
                        coupled_pairs.append((qa, qb))
                        coupled_sids.add(qa["s"]["sid"])
                        coupled_sids.add(qb["s"]["sid"])

    coupled_pairs.sort(key=lambda pair: _placement_priority(pair[0]))
    room_failures: list[dict] = []

    def _record_failure(q, kind, pool):
        s, d, p = q["s"], q["day"], q["period"]
        room_failures.append({
            "cohort": s["cohort"], "code": s["code"],
            "teacher": s["teacher"], "day": days[d], "period": p,
            "room_kind": kind, "pool_size": len(pool),
            "in_use_here": sorted(busy.get((d, p), set())),
            "reason": (f"No free {kind} room at {days[d]} P{p}: the "
                       f"{kind} pool has {len(pool)} room(s) and all are "
                       f"taken or closed." if pool else
                       f"No {kind} rooms are configured at all."),
            "fix": (f"Add a {kind} room in Manage Rooms, or free one by "
                    f"moving another class out of {days[d]} P{p}."),
        })

    for qa, qb in coupled_pairs:
        s_a = qa["s"]
        off = offering_of.get(s_a["oid"]) or {"code": s_a["code"], "is_lab": s_a["is_lab"]}
        pool, kind = policy_constraints.offering_room_pool(off, cfg, physics_codes)
        slots_dp = [(qa["day"], qa["period"]), (qb["day"], qb["period"])]
        room = pick_multi(pool, slots_dp, s_a)
        if room is not None:
            for d, p in slots_dp:
                busy.setdefault((d, p), set()).add(room)
            assigned_room_by_sid[qa["s"]["sid"]] = room
            assigned_room_by_sid[qb["s"]["sid"]] = room
        else:
            # Fallback individually if coupled allocation fails (validator will flag R13/R12 violation cleanly)
            for q in (qa, qb):
                r_single = pick_multi(pool, [(q["day"], q["period"])], q["s"])
                if r_single is None:
                    r_single = "TBA"
                    _record_failure(q, kind, pool)
                busy.setdefault((q["day"], q["period"]), set()).add(r_single)
                assigned_room_by_sid[q["s"]["sid"]] = r_single

    placed_sorted = sorted(placed, key=_placement_priority)
    for q in placed_sorted:
        sid = q["s"]["sid"]
        if sid in assigned_room_by_sid:
            continue
        s, d, p = q["s"], q["day"], q["period"]
        off = offering_of.get(s["oid"]) or {"code": s["code"], "is_lab": s["is_lab"]}
        pool, kind = policy_constraints.offering_room_pool(off, cfg, physics_codes)
        room = pick_multi(pool, [(d, p)], s)
        if room is None:
            room = "TBA"
            _record_failure(q, kind, pool)
        busy.setdefault((d, p), set()).add(room)
        assigned_room_by_sid[sid] = room

    rows, service_rows = [], []
    for i, q in enumerate(placed_sorted):
        s, d, p = q["s"], q["day"], q["period"]
        room = assigned_room_by_sid[s["sid"]]
        meta = pmeta[p]
        row = {
            "id": f"gen-{i}",
            "day": days[d],
            "period": p,
            "time_start": meta["start"],
            "time_end": meta["end"],
            "subject": s["title"],
            "subject_code": s["code"],
            "teacher_name": names.get(s["teacher"]),
            "teacher_code": s["teacher"],
            "room": room,
            "batch": s["batch"],
            "section": s["section"],
            "semester": semester_for(s["batch"]),
            "is_active": True,
            # Engine-side metadata. `RoutineEntry.toMap()` only emits the
            # `routines` columns, so these never reach Postgres.
            "oid": s["oid"],
            "teachers": s.get('teachers') or ([s['teacher']] if s.get('teacher') else []),
            "teacher_state": 'assigned' if s.get('teacher') else 'pending',
            "is_service": s["is_service"],
            "is_lab": s["is_lab"],
        }
        (service_rows if s["is_service"] else rows).append(row)

    day_order = {d: i for i, d in enumerate(days)}
    rows.sort(key=lambda r: (r["batch"], r["section"],
                             day_order.get(r["day"], 99), r["period"]))
    return rows, service_rows, room_failures


def _validate(dataset, cfg, all_rows, days, pmeta) -> dict:
    """Compare the generated routine back against the distribution it came from.

    Course completeness and session allocation are correctness failures, not
    quality metrics: a routine that loses a required course must never be
    publishable. Every failure carries enough identity to act on.
    """
    offerings = dataset.get("offerings", [])
    day_set = set(days)
    valid_slots = {(str(p["start"]), str(p["end"])) for p in pmeta.values()}
    aliases = cfg.get('room_aliases') or {}
    lab_set = {room_key(r,aliases) for r in cfg['lab_rooms']}
    off_days = cfg["off_days"]
    blocked = cfg["blocked_periods"]

    # ── Distribution -> Routine reconciliation ────────────────────────────
    required = {(o["cohort"], o["code"]): o for o in offerings}
    actual: dict[tuple[str, str], int] = defaultdict(int)
    for r in all_rows:
        cohort = f"{r['batch']}-{r['section']}" if r["section"] else r["batch"]
        actual[(cohort, r["subject_code"])] += 1

    missing, under, over, unexpected = [], [], [], []
    for key, o in required.items():
        got = actual.get(key, 0)
        if got == 0:
            missing.append({"cohort": o["cohort"], "code": o["code"],
                            "teacher": o["teachers"][0] if o['teachers'] else None,
                            "required": o["required_sessions"]})
        elif got < o["required_sessions"]:
            under.append({"cohort": o["cohort"], "code": o["code"],
                          "required": o["required_sessions"], "scheduled": got})
        elif got > o["required_sessions"]:
            over.append({"cohort": o["cohort"], "code": o["code"],
                         "required": o["required_sessions"], "scheduled": got})
    for key, got in actual.items():
        if key not in required:
            unexpected.append({"cohort": key[0], "code": key[1], "scheduled": got})

    # ── Conflicts, rules and slot validity ───────────────────────────────
    # Every check below records the offending rows, not just a count: a bare
    # `"teacher_clashes": 2` is not actionable, and chasing it meant re-running
    # the engine by hand. Counts stay exact; only the example lists are capped.
    seen_t: dict[tuple, list] = defaultdict(list)
    seen_c: dict[tuple, list] = defaultdict(list)
    seen_r: dict[tuple, list] = defaultdict(list)
    dayoff_d, blocked_d, lab_bad_d, tba_d, bad_slot_d, bad_day_d = [], [], [], [], [], []
    inelig_d = []
    assignment_d, unknown_room_d, capacity_d, unknown_teacher_d = [], [], [], []
    room_set = {room_key(r,aliases) for r in cfg['lab_rooms']+cfg['theory_rooms']}
    room_metadata = {room_key(k,aliases):v for k,v in cfg.get('room_metadata',{}).items()}
    pending_faculty = 0

    elig = cfg.get("eligibility") or {}
    elig_map = elig.get("eligible") or {}
    elig_declared = elig.get("declared") or set()

    def _who(r) -> dict:
        return {"cohort": f"{r['batch']}-{r['section']}" if r["section"]
                else str(r["batch"]),
                "code": r["subject_code"], "teacher": r["teacher_code"],
                "day": r["day"], "period": r["period"], "room": r["room"]}

    for r in all_rows:
        cohort = f"{r['batch']}-{r['section']}" if r['section'] else str(r['batch'])
        offering = required.get((cohort, r['subject_code']))
        assigned = r.get('teachers') or ([r['teacher_code']] if r.get('teacher_code') else [])
        if not r.get('teacher_code'):
            pending_faculty += 1
        if offering is not None and (
                r.get('teacher_code') != (offering['teachers'][0] if offering['teachers'] and not offering.get('pending_faculty_source_rows') else None) or
                set(assigned) != set(offering['teachers'])):
            assignment_d.append(_who(r))
        physical_room = room_key(r['room'],aliases)
        if r['room'] != 'TBA' and physical_room not in room_set:
            unknown_room_d.append(_who(r))
        students = offering.get('students') if offering else None
        capacity = room_metadata.get(physical_room,{}).get('capacity')
        if students is not None and capacity is not None and students > capacity:
            capacity_d.append(_who(r))
        for t in assigned:
            if t not in off_days:
                unknown_teacher_d.append({**_who(r), 'teacher': t})
            seen_t[(t, r["day"], r["period"])].append(r)
            if r["day"] in off_days.get(t, set()):
                dayoff_d.append({**_who(r), "teacher": t, "off_day": r["day"]})
            # Eligibility is a check on the DISTRIBUTION, not on a solver
            # choice — the workbook names the teacher and the solver never
            # overrides it. A teacher the admin has not configured at all is
            # "unknown", not "ineligible", so only declared teachers can fail.
            tu, cu = t.upper(), str(r["subject_code"]).upper()
            if tu in elig_declared and cu not in elig_map.get(tu, set()):
                inelig_d.append({**_who(r), "teacher": t,
                                 "eligible_for": sorted(elig_map.get(tu, set()))[:8]})
        for batch, section in _groups(r['batch'], r['section']):
            seen_c[(batch, section, r['day'], r['period'])].append(r)
        if r["room"] != "TBA":
            seen_r[(physical_room, r["day"], r["period"])].append(r)
        else:
            tba_d.append(_who(r))
        if r["period"] in blocked.get(r["day"], set()):
            blocked_d.append(_who(r))
        if r["is_lab"] and r["room"] != "TBA":
            dept = (offering or {}).get("course_dept")
            is_eee = is_eee_course(r["subject_code"], dept)
            is_cse = is_cse_course(r["subject_code"], dept)
            is_ecl = is_ecl_room(physical_room, aliases)
            if physical_room not in lab_set:
                lab_bad_d.append({**_who(r), "reason": f"Lab {r['subject_code']} in non-lab room {r['room']}"})
            elif is_eee and not is_ecl:
                lab_bad_d.append({**_who(r), "reason": f"EEE lab {r['subject_code']} in non-ECL room {r['room']}"})
            elif is_cse and is_ecl:
                lab_bad_d.append({**_who(r), "reason": f"CSE lab {r['subject_code']} in ECL room {r['room']}"})
        if (str(r["time_start"]), str(r["time_end"])) not in valid_slots:
            bad_slot_d.append({**_who(r), "time_start": str(r["time_start"]),
                               "time_end": str(r["time_end"])})
        if r["day"] not in day_set:
            bad_day_d.append(_who(r))

    def _clashes(seen, label) -> tuple[int, list]:
        n, out = 0, []
        for key, rs in seen.items():
            if len(rs) < 2:
                continue
            n += len(rs) - 1
            out.append({label: key[0], "day": key[-2], "period": key[-1],
                        "courses": [f"{x['subject_code']} "
                                    f"({x['batch']}-{x['section']})" for x in rs],
                        "rooms": sorted({x["room"] for x in rs})})
        return n, out

    tclash, tclash_d = _clashes(seen_t, "teacher")
    rclash, rclash_d = _clashes(seen_r, "room")
    cclash, cclash_d = 0, []
    for (b, s, d, pd), rs in seen_c.items():
        if len(rs) < 2:
            continue
        cclash += len(rs) - 1
        cclash_d.append({"cohort": f"{b}-{s}" if s else str(b), "day": d,
                         "period": pd,
                         "courses": [x["subject_code"] for x in rs]})

    # ── Same course, same day ────────────────────────────────────────────
    # A correctness failure, not a quality metric, unless the configuration
    # says otherwise. In Committee Policy Mode, R13 low-credit CSE theory blocks
    # and R12 2-credit sessional 2+1 pairs are verified by `validate_policy_compliance`.
    committee_policy = cfg.get("committee_policy")
    same_day_ok = bool(cfg.get("allow_same_day_sessions", False))
    exempt = cfg.get("same_day_exempt_courses") or set()
    per_offering_day: dict[tuple, list] = defaultdict(list)
    for r in all_rows:
        cohort = f"{r['batch']}-{r['section']}" if r["section"] else str(r["batch"])
        per_offering_day[(cohort, r["subject_code"], r["day"])].append(r)
    same_day, same_day_d = 0, []
    for (cohort, code, day), rs in per_offering_day.items():
        if len(rs) < 2:
            continue
        off_obj = required.get((cohort, code)) or {}
        if committee_policy is not None:
            cr = off_obj.get("credit")
            dept = off_obj.get("course_dept")
            is_r13_block = (
                committee_policy.low_credit_cse_theory_consecutive
                and not off_obj.get("is_lab")
                and not off_obj.get("is_service")
                and is_cse_course(str(code), dept)
                and cr is not None
                and any(abs(float(cr) - c) < 1e-6 for c in (1.0, 1.5, 2.0))
            )
            is_r12_two_cr = (
                off_obj.get("is_lab")
                and cr is not None
                and abs(float(cr) - 2.0) < 1e-6
            )
            if is_r13_block or is_r12_two_cr:
                continue
        three_cr_enforced = (
            committee_policy is not None
            and committee_policy.three_credit_theory_spread
            and not off_obj.get("is_lab")
            and not off_obj.get("is_service")
            and is_cse_course(str(code), off_obj.get("course_dept"))
            and off_obj.get("credit") is not None
            and abs(float(off_obj["credit"]) - 3.0) < 1e-6
        )
        if not three_cr_enforced and (same_day_ok or str(code).upper() in exempt):
            continue
        same_day += len(rs) - 1
        same_day_d.append({"cohort": cohort, "code": code, "day": day,
                           "periods": sorted(x["period"] for x in rs),
                           "teacher": rs[0]["teacher_code"]})

    online_set = _int_set(cfg.get("online_periods") or [7])
    periods_list = [p for p in (cfg.get("periods") or []) if int(p["idx"]) not in (cfg.get("excluded_periods") or set())]
    if not periods_list:
        periods_list = list(pmeta.values())
    topology = policy_constraints.build_grid_topology(
        days=days,
        periods=periods_list,
        online_periods=online_set,
        blocked_periods=blocked,
        break_after_period=cfg.get("break_after_period"),
    )
    policy_report = policy_constraints.validate_policy_compliance(
        dataset=dataset,
        cfg=cfg,
        all_rows=all_rows,
        days=days,
        pmeta=pmeta,
        topology=topology,
    )

    fatal = (len(missing), len(under), len(over), len(unexpected),
             tclash, cclash, rclash, len(dayoff_d), len(blocked_d),
             len(lab_bad_d), len(tba_d), len(bad_slot_d), len(bad_day_d),
             same_day, len(inelig_d), len(assignment_d), len(unknown_room_d),
             len(capacity_d), len(unknown_teacher_d),
             policy_report["policy_violation_count"])

    details = {
        "missing_courses": missing[:DETAIL_LIMIT],
        "under_scheduled": under[:DETAIL_LIMIT],
        "over_scheduled": over[:DETAIL_LIMIT],
        "unexpected_courses": unexpected[:DETAIL_LIMIT],
        "teacher_clashes": tclash_d[:DETAIL_LIMIT],
        "cohort_clashes": cclash_d[:DETAIL_LIMIT],
        "room_clashes": rclash_d[:DETAIL_LIMIT],
        "same_day_sessions": same_day_d[:DETAIL_LIMIT],
        "ineligible_assignments": inelig_d[:DETAIL_LIMIT],
        "teacher_assignment_mismatches": assignment_d[:DETAIL_LIMIT],
        "unknown_rooms": unknown_room_d[:DETAIL_LIMIT],
        "room_capacity_violations": capacity_d[:DETAIL_LIMIT],
        "unresolved_teachers": unknown_teacher_d[:DETAIL_LIMIT],
        "dayoff_violations": dayoff_d[:DETAIL_LIMIT],
        "blocked_period_violations": blocked_d[:DETAIL_LIMIT],
        "lab_room_violations": lab_bad_d[:DETAIL_LIMIT],
        "unplaced_rooms": tba_d[:DETAIL_LIMIT],
        "invalid_time_slots": bad_slot_d[:DETAIL_LIMIT],
        "invalid_days": bad_day_d[:DETAIL_LIMIT],
    }
    for k, v in policy_report["policy_details"].items():
        details[k] = v[:DETAIL_LIMIT]

    return {
        # correctness against the distribution
        "required_offerings": len(required),
        "scheduled_offerings": len(actual),
        "missing_courses": len(missing),
        "under_scheduled": len(under),
        "over_scheduled": len(over),
        "unexpected_courses": len(unexpected),
        # conflicts and rules
        "teacher_clashes": tclash,
        "cohort_clashes": cclash,
        "room_clashes": rclash,
        "dayoff_violations": len(dayoff_d),
        "blocked_period_violations": len(blocked_d),
        "lab_room_violations": len(lab_bad_d),
        "unplaced_rooms": len(tba_d),
        "invalid_time_slots": len(bad_slot_d),
        "invalid_days": len(bad_day_d),
        "same_day_sessions": same_day,
        "ineligible_assignments": len(inelig_d),
        "teacher_assignment_mismatches": len(assignment_d),
        "unknown_rooms": len(unknown_room_d),
        "room_capacity_violations": len(capacity_d),
        "unresolved_teachers": len(unknown_teacher_d),
        "pending_faculty_assignments": pending_faculty,
        "same_day_rule": "off" if same_day_ok else "enforced",
        # Stage 5B R1-R16 additive policy counters & soft optimization scorecard
        "policy_violations": policy_report["policy_violations"],
        "policy_violation_count": policy_report["policy_violation_count"],
        "soft_metrics": policy_report["soft_metrics"],
        # traceability — what failed, for which course, cohort and teacher
        "details": details,
        "ok": all(v == 0 for v in fatal),
    }


if __name__ == "__main__":
    import sys
    import ingest

    path = sys.argv[1] if len(sys.argv) > 1 else \
        "routine generation files/Main_Distribution_Summer25.xlsx"
    cfg = load_config()
    ds = ingest.ingest_path(
        path, weeks_in_term=cfg["weeks_in_term"],
        fixed_sessions_per_week=cfg.get("fixed_sessions_per_week"))
    res = solve(ds, cfg, time_limit_s=float(sys.argv[2]) if len(sys.argv) > 2 else 60.0)
    print(json.dumps({"stats": res["stats"], "validation": res["validation"]},
                     indent=2))
    print(f"\nfirst 8 of {len(res['rows'])} CSE rows:")
    for r in res["rows"][:8]:
        print(f"  {r['batch']}-{r['section']:4} {r['day']:9} P{r['period']} "
              f"{r['time_start']}-{r['time_end']} {r['subject_code']:10} "
              f"{r['teacher_code']:4} {r['room']}")
