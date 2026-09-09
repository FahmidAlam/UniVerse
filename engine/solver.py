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

CONFIG_PATH = Path(__file__).parent / "config.json"

SOLVER_WORKERS = int(os.environ.get("SOLVER_WORKERS", "8"))

#: How many offending items each validation list carries back to the client.
#: The counts are always exact; only the examples are capped.
DETAIL_LIMIT = 50


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
    days = cfg.get("days") or settings.get("days") or [
        "Sunday", "Monday", "Tuesday", "Wednesday",
        "Thursday", "Friday", "Saturday"]
    periods = cfg.get("periods") or settings.get("periods")
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
    allow_online = bool(settings.get("allow_online_periods",
                                     cfg.get("allow_online_periods", False)))
    if not allow_online:
        excluded |= _int_set(online)

    # Per-day unavailable periods, e.g. {"Friday": [4]}. `friday_no_p4` is the
    # legacy single-purpose flag; it is folded in so old configs keep working.
    blocked: dict[str, set[int]] = {}
    for day, plist in (settings.get("blocked_periods",
                                    cfg.get("blocked_periods")) or {}).items():
        blocked.setdefault(str(day), set()).update(_int_set(plist))
    if settings.get("friday_no_p4", cfg.get("friday_no_p4", True)):
        blocked.setdefault("Friday", set()).add(4)

    rooms = cfg.get("rooms") or []
    lab_rooms, theory_rooms = [], []
    for r in rooms:
        name = r["name"]
        if r.get("is_lab"):
            lab_rooms.append(name)
        elif r.get("is_gallery") or any(ch.isdigit() for ch in name):
            theory_rooms.append(name)
    if not rooms:
        lab_rooms = cfg.get("lab_rooms", [])
        theory_rooms = cfg.get("theory_rooms", [])

    teachers = cfg.get("teachers", {})
    off_days: dict[str, set[str]] = {}
    names: dict[str, str] = {}
    if isinstance(teachers, dict):
        for ac, t in teachers.items():
            off_days[ac] = set(t.get("off_days") or [])
            if t.get("full_name"):
                names[ac] = t["full_name"]
    else:
        for t in teachers:
            ac = t.get("acronym")
            if ac:
                off_days[ac] = set(t.get("off_days") or [])
                if t.get("full_name"):
                    names[ac] = t["full_name"]

    return {
        "days": days,
        "periods": periods,
        "excluded_periods": excluded,
        "blocked_periods": blocked,
        "weeks_in_term": weeks,
        "weights": weights,
        "lab_rooms": lab_rooms,
        "theory_rooms": theory_rooms,
        "off_days": off_days,
        "names": names,
        "semester_label": settings.get("semester_label"),
        "semester_map": settings.get("semester_map", cfg.get("semester_map")) or {},
        "lab_adjacency": cfg.get("lab_adjacency",
                                 settings.get("lab_adjacency", "hard")),
        # An offering meeting twice in one day is an academic rule, not a
        # preference, so it is enforced in the model rather than penalised.
        # Both escape hatches are data: a global switch, and a per-course
        # exemption list for genuinely block-taught courses.
        "allow_same_day_sessions": bool(
            settings.get("allow_same_day_sessions",
                         cfg.get("allow_same_day_sessions", False))),
        "same_day_exempt_courses": {
            str(c).strip().upper()
            for c in (settings.get("same_day_exempt_courses",
                                   cfg.get("same_day_exempt_courses")) or [])
            if str(c).strip()
        },
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
          progress: _Progress | None = None) -> dict:
    progress = progress or _Progress()
    cfg = config
    days = cfg["days"]
    periods = [p for p in cfg["periods"]
               if int(p["idx"]) not in cfg["excluded_periods"]]
    if not periods:
        raise RuntimeError(
            "No usable periods in the configuration. Every configured period is "
            "excluded — check Timetable Settings.")
    pidx = [int(p["idx"]) for p in periods]
    pmeta = {int(p["idx"]): p for p in periods}
    blocked = cfg["blocked_periods"]
    off_days = cfg["off_days"]
    n_lab = len(cfg["lab_rooms"])
    n_theory = len(cfg["theory_rooms"])
    w = cfg["weights"]

    adj_mode = cfg.get("lab_adjacency", "hard")
    same_day_ok = bool(cfg.get("allow_same_day_sessions", False))
    same_day_exempt = cfg.get("same_day_exempt_courses") or set()
    neighbors = {p: [q for q in pidx if q != p and
                     (pmeta[p]["end"] == pmeta[q]["start"] or
                      pmeta[q]["end"] == pmeta[p]["start"])]
                 for p in pidx}

    sessions = dataset["sessions"]
    offerings = dataset.get("offerings", [])
    offering_of = {o["oid"]: o for o in offerings}

    sessions_by_oid: dict[int, list[dict]] = defaultdict(list)
    for s in sessions:
        sessions_by_oid[s["oid"]].append(s)

    def teachers_of(s) -> list[str]:
        return s.get("teachers") or [s["teacher"]]

    def valid_slots(s) -> list[tuple[int, int]]:
        """(day, period) options for a session. Every teacher sharing the
        offering must be free — a co-teacher takes the same slot later in the
        term, so the slot has to suit all of them."""
        out = []
        blocked_days = set()
        for t in teachers_of(s):
            blocked_days |= off_days.get(t, set())
        for di, dname in enumerate(days):
            if dname in blocked_days:
                continue
            day_blocked = blocked.get(dname, set())
            for p in pidx:
                if p in day_blocked:
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
            raise RuntimeError(_no_slot_message(s, cfg, days, pidx, teachers_of(s)))
        model.AddExactlyOne(vs)

    # A teacher is busy for every offering they are attached to, co-taught or not.
    by_teacher: dict[str, list[dict]] = defaultdict(list)
    by_cohort: dict[str, list[dict]] = defaultdict(list)
    for s in sessions:
        for t in teachers_of(s):
            by_teacher[t].append(s)
        by_cohort[s["cohort"]].append(s)

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
            lab_terms = [x[(s["sid"], di, p)] for s in sessions
                         if s["is_lab"] and (s["sid"], di, p) in x]
            th_terms = [x[(s["sid"], di, p)] for s in sessions
                        if not s["is_lab"] and (s["sid"], di, p) in x]
            if lab_terms:
                model.Add(sum(lab_terms) <= n_lab)
            if th_terms:
                model.Add(sum(th_terms) <= n_theory)

    penalties = []

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

    # One offering may not meet twice on the same day.
    #
    # HARD by default. This used to be a soft penalty only, which is why a
    # rushed solve on the deployed engine (2 workers, short budget) returned
    # technically-valid routines with a course sitting on, say, Sunday P1 and
    # Sunday P4: the solver simply had not paid the penalty down yet. A rule
    # this academic does not belong in the objective function.
    #
    # It applies per (cohort, course), so it does NOT touch theory<->sessional
    # pairing: CSE-1101 and CSE-1102 are different offerings and are still
    # required to share a day in adjacent periods by `lab_adjacency`.
    #
    # `allow_same_day_sessions` in the configuration relaxes it globally, and
    # `same_day_exempt_courses` exempts individual course codes, so a genuine
    # block-taught course can be declared instead of the rule being dropped.
    for oid, group in sessions_by_oid.items():
        if len(group) < 2:
            continue
        exempt = same_day_ok or offering_of.get(oid, {}).get("code") in same_day_exempt
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

    lt_pairs = _build_pairs(offerings, sessions_by_oid)
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

    if status not in (cp_model.OPTIMAL, cp_model.FEASIBLE):
        raise RuntimeError(_infeasible_message(
            solver.StatusName(status), sessions, teachers_of, slots_for,
            offering_of, days, pidx))

    placed = []
    for s in sessions:
        for (d, p) in slots_for[s["sid"]]:
            if solver.Value(x[(s["sid"], d, p)]) == 1:
                placed.append({"s": s, "day": d, "period": p})
                break
    progress(0.88)

    rows, service_rows, room_failures = _assign_rooms(dataset, cfg, placed,
                                                      days, pmeta)
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

    return {
        "rows": rows,
        "service_rows": service_rows,
        "stats": {
            "status": solver.StatusName(status),
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
                        offering_of, days, pidx) -> str:
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
        lines.append(
            "No single teacher is over-committed, so the clash is structural: "
            "room capacity, lab/theory adjacency, or cohort load. Try relaxing "
            "lab_adjacency to 'soft', adding rooms, or raising the time limit.")
    return " ".join(lines) if len(lines) == 2 else "\n".join(lines)


def _assign_rooms(dataset, cfg, placed, days, pmeta):
    busy: dict[tuple[int, int], set[str]] = {}
    lab_pool = cfg["lab_rooms"]
    theory_pool = cfg["theory_rooms"]
    names = cfg["names"]
    semester_map = cfg.get("semester_map") or {}

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

    def pick(pool, d, p):
        for r in pool:
            if r not in busy.get((d, p), set()):
                return r
        return None

    # Greedy first-fit is safe here, and that is a property of the model rather
    # than luck: CP-SAT already caps concurrent labs at len(lab_rooms) and
    # concurrent theory at len(theory_rooms) for every (day, period), and the
    # two pools are disjoint. So a free room of the right kind always exists
    # and this pass cannot invalidate a schedule the solver called feasible.
    # Labs are served first only to keep the assignment stable and readable.
    #
    # "TBA" below therefore means the pools were misconfigured (an empty pool,
    # or a lab session with no lab rooms at all), never "the scheduler gave
    # up". It is a hard validation failure with a named cause — it is NOT the
    # template's "TBA*", which is a human "to be announced later" marker the
    # engine has never produced and must not start producing.
    placed.sort(key=lambda q: (not q["s"]["is_lab"],))
    room_failures: list[dict] = []

    rows, service_rows = [], []
    for i, q in enumerate(placed):
        s, d, p = q["s"], q["day"], q["period"]
        pool = lab_pool if s["is_lab"] else theory_pool
        room = pick(pool, d, p)
        if room is None:
            room = "TBA"
            kind = "lab" if s["is_lab"] else "theory"
            room_failures.append({
                "cohort": s["cohort"], "code": s["code"],
                "teacher": s["teacher"], "day": days[d], "period": p,
                "room_kind": kind, "pool_size": len(pool),
                "in_use_here": sorted(busy.get((d, p), set())),
                "reason": (f"No free {kind} room at {days[d]} P{p}: the "
                           f"{kind} pool has {len(pool)} room(s) and all are "
                           f"taken." if pool else
                           f"No {kind} rooms are configured at all."),
                "fix": (f"Add a {kind} room in Manage Rooms, or free one by "
                        f"moving another class out of {days[d]} P{p}."),
            })
        busy.setdefault((d, p), set()).add(room)
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
            "teachers": s.get("teachers") or [s["teacher"]],
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
    lab_set = set(cfg["lab_rooms"])
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
                            "teacher": o["teachers"][0],
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

    elig = cfg.get("eligibility") or {}
    elig_map = elig.get("eligible") or {}
    elig_declared = elig.get("declared") or set()

    def _who(r) -> dict:
        return {"cohort": f"{r['batch']}-{r['section']}" if r["section"]
                else str(r["batch"]),
                "code": r["subject_code"], "teacher": r["teacher_code"],
                "day": r["day"], "period": r["period"], "room": r["room"]}

    for r in all_rows:
        for t in (r.get("teachers") or [r["teacher_code"]]):
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
        seen_c[(r["batch"], r["section"], r["day"], r["period"])].append(r)
        if r["room"] != "TBA":
            seen_r[(r["room"], r["day"], r["period"])].append(r)
        else:
            tba_d.append(_who(r))
        if r["period"] in blocked.get(r["day"], set()):
            blocked_d.append(_who(r))
        if r["is_lab"] and r["room"] not in lab_set and r["room"] != "TBA":
            lab_bad_d.append(_who(r))
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
    # says otherwise. It was the first thing to degrade when the deployed
    # solver ran out of time while this was only a soft penalty.
    same_day_ok = bool(cfg.get("allow_same_day_sessions", False))
    exempt = cfg.get("same_day_exempt_courses") or set()
    per_offering_day: dict[tuple, list] = defaultdict(list)
    for r in all_rows:
        cohort = f"{r['batch']}-{r['section']}" if r["section"] else str(r["batch"])
        per_offering_day[(cohort, r["subject_code"], r["day"])].append(r)
    same_day, same_day_d = 0, []
    for (cohort, code, day), rs in per_offering_day.items():
        if len(rs) < 2 or same_day_ok or str(code).upper() in exempt:
            continue
        same_day += len(rs) - 1
        same_day_d.append({"cohort": cohort, "code": code, "day": day,
                           "periods": sorted(x["period"] for x in rs),
                           "teacher": rs[0]["teacher_code"]})

    fatal = (len(missing), len(under), len(over), len(unexpected),
             tclash, cclash, rclash, len(dayoff_d), len(blocked_d),
             len(lab_bad_d), len(tba_d), len(bad_slot_d), len(bad_day_d),
             same_day, len(inelig_d))

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
        "same_day_rule": "off" if same_day_ok else "enforced",
        # traceability — what failed, for which course, cohort and teacher
        "details": {
            "missing_courses": missing[:DETAIL_LIMIT],
            "under_scheduled": under[:DETAIL_LIMIT],
            "over_scheduled": over[:DETAIL_LIMIT],
            "unexpected_courses": unexpected[:DETAIL_LIMIT],
            "teacher_clashes": tclash_d[:DETAIL_LIMIT],
            "cohort_clashes": cclash_d[:DETAIL_LIMIT],
            "room_clashes": rclash_d[:DETAIL_LIMIT],
            "same_day_sessions": same_day_d[:DETAIL_LIMIT],
            "ineligible_assignments": inelig_d[:DETAIL_LIMIT],
            "dayoff_violations": dayoff_d[:DETAIL_LIMIT],
            "blocked_period_violations": blocked_d[:DETAIL_LIMIT],
            "lab_room_violations": lab_bad_d[:DETAIL_LIMIT],
            "unplaced_rooms": tba_d[:DETAIL_LIMIT],
            "invalid_time_slots": bad_slot_d[:DETAIL_LIMIT],
            "invalid_days": bad_day_d[:DETAIL_LIMIT],
        },
        "ok": all(v == 0 for v in fatal),
    }


if __name__ == "__main__":
    import sys
    import ingest

    path = sys.argv[1] if len(sys.argv) > 1 else \
        "routine generation files/Main_Distribution_Summer25.xlsx"
    cfg = load_config()
    ds = ingest.ingest_path(path, weeks_in_term=cfg["weeks_in_term"])
    res = solve(ds, cfg, time_limit_s=float(sys.argv[2]) if len(sys.argv) > 2 else 60.0)
    print(json.dumps({"stats": res["stats"], "validation": res["validation"]},
                     indent=2))
    print(f"\nfirst 8 of {len(res['rows'])} CSE rows:")
    for r in res["rows"][:8]:
        print(f"  {r['batch']}-{r['section']:4} {r['day']:9} P{r['period']} "
              f"{r['time_start']}-{r['time_end']} {r['subject_code']:10} "
              f"{r['teacher_code']:4} {r['room']}")
