# ============================================================
# FILE: engine/solver.py
# PURPOSE: Department timetable generator (CP-SAT + greedy rooms),
#   driven by ingest.py output and a config dict (rooms / faculty
#   off-days / period grid / weights). Replaces the demo solver.
#
#   Phase 1 (CP-SAT): assign each session a (day, period).
#     HARD: exactly-once; no teacher / cohort double-book; per-slot
#           room-count <= rooms available (so Phase 2 always succeeds);
#           teacher day-offs; Friday has no Period 4; online column off.
#     SOFT (weighted, minimized):
#           S1 the two sessions of one offering on DIFFERENT days;
#           S3 cohort compactness (fewer distinct class-days);
#           S7 avoid the last in-person period.
#   Phase 2 (greedy): labs -> lab rooms, theory -> theory rooms/galleries.
#
#   Service / non-CSE sessions are solved as resource-only: they hold
#   teacher + room time (so a CSE class never clashes with a teacher's
#   service class) but are NOT emitted as published/rendered rows.
#
# Output rows match the Supabase `routines` columns.
# ============================================================

from __future__ import annotations

import json
import os
import time
from pathlib import Path

from ortools.sat.python import cp_model

CONFIG_PATH = Path(__file__).parent / "config.json"

# CP-SAT worker threads. More workers = faster but more memory. Free
# hosting tiers (e.g. Render 512 MB) can OOM with 8 — override with the
# SOLVER_WORKERS env var (2 is a safe default for constrained instances).
SOLVER_WORKERS = int(os.environ.get("SOLVER_WORKERS", "8"))


# ─── Config ───────────────────────────────────────────────────

def load_config(override: dict | None = None) -> dict:
    if override:
        return _normalize_config(override)
    return _normalize_config(json.loads(CONFIG_PATH.read_text(encoding="utf-8")))


def _normalize_config(cfg: dict) -> dict:
    """Accept either the engine config.json shape or the DB-sourced shape
    (rooms[], faculty[], settings{}) and normalise to one internal form."""
    days = cfg.get("days") or ["Sunday", "Monday", "Tuesday", "Wednesday",
                               "Thursday", "Friday", "Saturday"]
    settings = cfg.get("settings", cfg)
    periods = cfg.get("periods") or settings.get("periods")
    friday_no_p4 = cfg.get("friday_no_p4", settings.get("friday_no_p4", True))
    weights = settings.get("weights", {"different_days": 8, "compactness": 3,
                                       "spread": 2, "late_slot": 1})

    # Rooms: list of {name,is_lab,is_gallery}
    rooms = cfg.get("rooms") or []
    lab_rooms, theory_rooms = [], []
    for r in rooms:
        (lab_rooms if r.get("is_lab") else theory_rooms).append(r["name"])
    if not rooms:  # fall back to flat lists
        lab_rooms = cfg.get("lab_rooms", [])
        theory_rooms = cfg.get("theory_rooms", [])

    # Teachers -> off-days map. Accept dict{acronym:{off_days}} or list[].
    teachers = cfg.get("teachers", {})
    off_days: dict[str, set[str]] = {}
    names: dict[str, str] = {}
    if isinstance(teachers, dict):
        for ac, t in teachers.items():
            off_days[ac] = set(t.get("off_days") or [])
            if t.get("full_name"):
                names[ac] = t["full_name"]
    else:  # list of faculty rows
        for t in teachers:
            ac = t.get("acronym")
            if ac:
                off_days[ac] = set(t.get("off_days") or [])
                if t.get("full_name"):
                    names[ac] = t["full_name"]

    return {
        "days": days,
        "periods": periods,
        "friday_no_p4": friday_no_p4,
        "weights": weights,
        "lab_rooms": lab_rooms,
        "theory_rooms": theory_rooms,
        "off_days": off_days,
        "names": names,
        "semester_label": settings.get("semester_label"),
    }


# ─── Progress hook ────────────────────────────────────────────

class _Progress:
    def __init__(self, cb=None):
        self.cb = cb

    def __call__(self, value: float):
        if self.cb:
            self.cb(value)


# ─── Solve ────────────────────────────────────────────────────

def solve(dataset: dict, config: dict, time_limit_s: float = 60.0,
          progress: _Progress | None = None) -> dict:
    progress = progress or _Progress()
    cfg = config
    days = cfg["days"]
    # In-person periods only: idx 1..6 (drop online P7). Map idx -> meta.
    periods = [p for p in cfg["periods"] if int(p["idx"]) <= 6]
    pidx = [int(p["idx"]) for p in periods]
    pmeta = {int(p["idx"]): p for p in periods}
    off_days = cfg["off_days"]
    n_lab = len(cfg["lab_rooms"])
    n_theory = len(cfg["theory_rooms"])
    w = cfg["weights"]

    sessions = dataset["sessions"]

    def valid_slots(s) -> list[tuple[int, int]]:
        out = []
        tea_off = off_days.get(s["teacher"], set())
        for di, dname in enumerate(days):
            if dname in tea_off:
                continue
            for p in pidx:
                if cfg["friday_no_p4"] and dname == "Friday" and p == 4:
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

    # H1: each session placed exactly once.
    for s in sessions:
        vs = [x[(s["sid"], d, p)] for (d, p) in slots_for[s["sid"]]]
        if not vs:
            raise RuntimeError(
                f"No valid slot for {s['code']} {s['cohort']} (teacher {s['teacher']} "
                f"off-days leave no room). Adjust day-offs or periods.")
        model.AddExactlyOne(vs)

    # Group sessions by teacher / cohort for clash + room constraints.
    by_teacher: dict[str, list[dict]] = {}
    by_cohort: dict[str, list[dict]] = {}
    for s in sessions:
        by_teacher.setdefault(s["teacher"], []).append(s)
        by_cohort.setdefault(s["cohort"], []).append(s)

    for di in range(len(days)):
        for p in pidx:
            # H2 teacher, H3 cohort: <= 1 per (day,period).
            for group in by_teacher.values():
                terms = [x[(s["sid"], di, p)] for s in group if (s["sid"], di, p) in x]
                if len(terms) > 1:
                    model.Add(sum(terms) <= 1)
            for group in by_cohort.values():
                terms = [x[(s["sid"], di, p)] for s in group if (s["sid"], di, p) in x]
                if len(terms) > 1:
                    model.Add(sum(terms) <= 1)
            # H4/H5 room capacity: lab vs theory counts <= rooms available.
            lab_terms = [x[(s["sid"], di, p)] for s in sessions
                         if s["is_lab"] and (s["sid"], di, p) in x]
            th_terms = [x[(s["sid"], di, p)] for s in sessions
                        if not s["is_lab"] and (s["sid"], di, p) in x]
            if lab_terms:
                model.Add(sum(lab_terms) <= n_lab)
            if th_terms:
                model.Add(sum(th_terms) <= n_theory)

    penalties = []

    # S1: two sessions of one offering should be on different days.
    by_offering: dict[tuple, list[dict]] = {}
    for s in sessions:
        by_offering.setdefault((s["cohort"], s["code"], s["teacher"]), []).append(s)
    for key, pair in by_offering.items():
        if len(pair) < 2:
            continue
        s1, s2 = pair[0], pair[1]
        for di in range(len(days)):
            y1 = [x[(s1["sid"], di, p)] for p in pidx if (s1["sid"], di, p) in x]
            y2 = [x[(s2["sid"], di, p)] for p in pidx if (s2["sid"], di, p) in x]
            if not y1 or not y2:
                continue
            same = model.NewBoolVar(f"same_{s1['sid']}_{s2['sid']}_{di}")
            # same >= y1+y2-1  (both on this day -> same=1)
            model.Add(sum(y1) + sum(y2) - 1 <= same)
            penalties.append(w.get("different_days", 8) * same)

    # S3: cohort compactness — minimise distinct class-days per cohort.
    for cohort, group in by_cohort.items():
        for di in range(len(days)):
            used = model.NewBoolVar(f"used_{cohort}_{di}")
            terms = [x[(s["sid"], di, p)] for s in group for p in pidx
                     if (s["sid"], di, p) in x]
            for t in terms:
                model.Add(used >= t)
            penalties.append(w.get("compactness", 3) * used)

    # S7: avoid the last in-person period.
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
        raise RuntimeError(
            f"No feasible timetable (status={solver.StatusName(status)}). "
            "A teacher likely has more sessions than free (day,period) slots.")

    placed = []
    for s in sessions:
        for (d, p) in slots_for[s["sid"]]:
            if solver.Value(x[(s["sid"], d, p)]) == 1:
                placed.append({"s": s, "day": d, "period": p})
                break
    progress(0.88)

    rows, service_rows = _assign_rooms(dataset, cfg, placed, days, pmeta)
    progress(0.96)

    return {
        "rows": rows,
        "service_rows": service_rows,
        "stats": {
            "status": solver.StatusName(status),
            "solve_ms": solve_ms,
            "meetings": len(rows),
            "service_meetings": len(service_rows),
            "cohorts": len(dataset["cohorts"]),
            "teachers": len(by_teacher),
            "objective": int(solver.ObjectiveValue()),
        },
        "validation": _validate(dataset, cfg, rows + service_rows, days),
    }


# ─── Phase 2: greedy room assignment ──────────────────────────

def _assign_rooms(dataset, cfg, placed, days, pmeta):
    busy: dict[tuple[int, int], set[str]] = {}
    lab_pool = cfg["lab_rooms"]
    theory_pool = cfg["theory_rooms"]
    names = cfg["names"]

    # Map batch -> a 1..8 semester for display (routines.semester). The
    # newest (highest) batch is semester 1; each older batch is +1. This
    # matches the app's existing convention (e.g. batch 62 -> semester 5).
    numeric_batches = [int(p["s"]["batch"]) for p in placed
                       if p["s"]["batch"].isdigit()]
    max_batch = max(numeric_batches) if numeric_batches else 0

    def semester_for(batch: str) -> int:
        if not batch.isdigit() or max_batch == 0:
            return 1
        return min(8, max(1, max_batch - int(batch) + 1))

    def pick(pool, d, p):
        for r in pool:
            if r not in busy.get((d, p), set()):
                return r
        return None

    placed.sort(key=lambda q: (not q["s"]["is_lab"],))  # labs first

    rows, service_rows = [], []
    for i, q in enumerate(placed):
        s, d, p = q["s"], q["day"], q["period"]
        pool = lab_pool if s["is_lab"] else theory_pool
        room = pick(pool, d, p) or "TBA"
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
            "is_service": s["is_service"],
            "is_lab": s["is_lab"],
        }
        (service_rows if s["is_service"] else rows).append(row)

    day_order = {d: i for i, d in enumerate(days)}
    rows.sort(key=lambda r: (r["batch"], r["section"],
                             day_order.get(r["day"], 99), r["period"]))
    return rows, service_rows


# ─── Validation (§9) ──────────────────────────────────────────

def _validate(dataset, cfg, all_rows, days):
    seen_t, seen_c, seen_r = {}, {}, {}
    dayoff = 0
    fri_p4 = 0
    lab_bad = 0
    tba = 0
    lab_set = set(cfg["lab_rooms"])
    off_days = cfg["off_days"]
    for r in all_rows:
        kt = (r["teacher_code"], r["day"], r["period"])
        kc = (r["batch"], r["section"], r["day"], r["period"])
        kr = (r["room"], r["day"], r["period"])
        seen_t[kt] = seen_t.get(kt, 0) + 1
        seen_c[kc] = seen_c.get(kc, 0) + 1
        if r["room"] != "TBA":
            seen_r[kr] = seen_r.get(kr, 0) + 1
        if r["day"] in off_days.get(r["teacher_code"], set()):
            dayoff += 1
        if cfg["friday_no_p4"] and r["day"] == "Friday" and r["period"] == 4:
            fri_p4 += 1
        # lab course must be in a lab room (use the row's own is_lab so the
        # check can never disagree with how the session was scheduled)
        if r["is_lab"] and r["room"] not in lab_set and r["room"] != "TBA":
            lab_bad += 1
        if r["room"] == "TBA":
            tba += 1

    tclash = sum(v - 1 for v in seen_t.values() if v > 1)
    cclash = sum(v - 1 for v in seen_c.values() if v > 1)
    rclash = sum(v - 1 for v in seen_r.values() if v > 1)

    # placement count: each offering (cohort+code+teacher) -> exactly 2 cells.
    # Teacher is part of the key because a cohort can take one course code
    # from two different teachers (legitimately 4 cells for that code).
    placed_per_off = {}
    for r in all_rows:
        k = (r["batch"], r["section"], r["subject_code"], r["teacher_code"])
        placed_per_off[k] = placed_per_off.get(k, 0) + 1
    bad_count = sum(1 for v in placed_per_off.values() if v != 2)

    return {
        "teacher_clashes": tclash,
        "cohort_clashes": cclash,
        "room_clashes": rclash,
        "dayoff_violations": dayoff,
        "friday_p4_violations": fri_p4,
        "lab_room_violations": lab_bad,
        "unplaced_rooms": tba,
        "offerings_not_twice": bad_count,
        "ok": all(v == 0 for v in
                  (tclash, cclash, rclash, dayoff, fri_p4, lab_bad, tba, bad_count)),
    }


# ─── CLI ──────────────────────────────────────────────────────

if __name__ == "__main__":
    import sys
    import ingest

    path = sys.argv[1] if len(sys.argv) > 1 else \
        "routine generation files/Main_Distribution_Summer25.xlsx"
    ds = ingest.ingest_path(path)
    cfg = load_config()
    res = solve(ds, cfg, time_limit_s=float(sys.argv[2]) if len(sys.argv) > 2 else 60.0)
    print(json.dumps({"stats": res["stats"], "validation": res["validation"]}, indent=2))
    print(f"\nfirst 8 of {len(res['rows'])} CSE rows:")
    for r in res["rows"][:8]:
        print(f"  {r['batch']}-{r['section']:4} {r['day']:9} P{r['period']} "
              f"{r['time_start']}-{r['time_end']} {r['subject_code']:10} "
              f"{r['teacher_code']:4} {r['room']}")
