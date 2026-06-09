# ============================================================
# FILE: engine/solver.py
# PURPOSE: Two-phase department timetable generator.
#   Phase 1 (CP-SAT): assign each class meeting a (day, slot).
#     Hard:  no teacher double-booking, no section double-booking,
#            teacher day-offs, labs occupy consecutive slots inside
#            one block, per-slot room-count <= available rooms.
#     Soft:  spread each section's daily load (penalise heavy days).
#   Phase 2 (greedy): assign a concrete room to every meeting —
#     labs -> lab rooms first, theory -> theory rooms.
#
# Output rows match the Supabase `routines` columns so the Flutter
# client can publish them verbatim and the existing routine viewer
# shows them with no extra code.
# ============================================================

from __future__ import annotations

import json
import time
from dataclasses import dataclass, field
from pathlib import Path

from ortools.sat.python import cp_model

FIXTURES = Path(__file__).parent / "fixtures" / "offerings.json"


# ─── Domain types ─────────────────────────────────────────────

@dataclass
class Session:
    """One atomic class meeting that needs a (day, start_slot)."""
    sid: int
    subject: str
    subject_code: str
    teacher_code: str
    section: str
    is_lab: bool
    length: int  # number of consecutive slots occupied


@dataclass
class Dataset:
    days: list[str]
    slots: list[dict]
    theory_rooms: list[str]
    lab_rooms: list[str]
    teachers: dict[str, dict]  # code -> {name, day_off}
    batch: str
    semester: int
    sessions: list[Session] = field(default_factory=list)


def load_dataset(path: Path | None = None, override: dict | None = None) -> Dataset:
    data = override if override is not None else json.loads((path or FIXTURES).read_text(encoding="utf-8"))
    meta = data.get("meta", {})
    teachers = {t["code"]: t for t in data["teachers"]}

    sessions: list[Session] = []
    sid = 0
    for off in data["offerings"]:
        is_lab = off.get("type") == "lab"
        length = int(off.get("length", 2 if is_lab else 1))
        for _ in range(int(off.get("sessions", 1))):
            sessions.append(Session(
                sid=sid,
                subject=off["subject"],
                subject_code=off["subject_code"],
                teacher_code=off["teacher_code"],
                section=off["section"],
                is_lab=is_lab,
                length=length,
            ))
            sid += 1

    return Dataset(
        days=data["days"],
        slots=data["slots"],
        theory_rooms=data["rooms"]["theory"],
        lab_rooms=data["rooms"]["lab"],
        teachers=teachers,
        batch=str(meta.get("batch", "63")),
        semester=int(meta.get("semester", 5)),
        sessions=sessions,
    )


# ─── Slot blocks (a multi-slot lab must stay inside one block) ──

def _blocks(slots: list[dict]) -> list[list[int]]:
    """Group slot indices by their 'block' tag, preserving order."""
    groups: dict[str, list[int]] = {}
    for s in slots:
        groups.setdefault(s.get("block", "all"), []).append(s["index"])
    return list(groups.values())


def _allowed_starts(slots: list[dict], length: int) -> list[int]:
    """Start slots where a meeting of `length` fits inside one block."""
    if length <= 1:
        return [s["index"] for s in slots]
    starts: list[int] = []
    for block in _blocks(slots):
        for i in range(len(block) - length + 1):
            # Contiguous within the block (indices are consecutive there).
            window = block[i:i + length]
            if window == list(range(window[0], window[0] + length)):
                starts.append(window[0])
    return starts


# ─── Phase 1: CP-SAT day/slot assignment ──────────────────────

class _Progress:
    """Tiny callback hook so the API can report rough progress."""
    def __init__(self, cb=None):
        self.cb = cb

    def __call__(self, value: float):
        if self.cb:
            self.cb(value)


def solve(ds: Dataset, time_limit_s: float = 20.0, progress: _Progress | None = None) -> dict:
    progress = progress or _Progress()
    n_days = len(ds.days)
    slot_idx = [s["index"] for s in ds.slots]
    n_slots = len(slot_idx)

    model = cp_model.CpModel()

    # x[sid][d][start] = 1 if session sid starts on day d at slot `start`.
    x: dict[tuple[int, int, int], cp_model.IntVar] = {}
    starts_for: dict[int, list[int]] = {}
    for s in ds.sessions:
        starts = _allowed_starts(ds.slots, s.length)
        starts_for[s.sid] = starts
        day_off = ds.teachers.get(s.teacher_code, {}).get("day_off")
        for d, dname in enumerate(ds.days):
            if dname == day_off:
                continue  # hard: respect teacher day-off
            for st in starts:
                x[(s.sid, d, st)] = model.NewBoolVar(f"x_{s.sid}_{d}_{st}")

    # Each session is scheduled exactly once.
    for s in ds.sessions:
        model.AddExactlyOne(
            x[(s.sid, d, st)]
            for d in range(n_days)
            for st in starts_for[s.sid]
            if (s.sid, d, st) in x
        )

    # occupy(sid, d, ts): linear 0/1 expr — does session occupy time-slot ts on day d.
    def occupy(s: Session, d: int, ts: int):
        terms = []
        for st in starts_for[s.sid]:
            if st <= ts < st + s.length and (s.sid, d, st) in x:
                terms.append(x[(s.sid, d, st)])
        return sum(terms) if terms else 0

    # Hard: no teacher / no section double-booking; cap rooms per slot.
    by_teacher: dict[str, list[Session]] = {}
    by_section: dict[str, list[Session]] = {}
    for s in ds.sessions:
        by_teacher.setdefault(s.teacher_code, []).append(s)
        by_section.setdefault(s.section, []).append(s)

    for d in range(n_days):
        for ts in slot_idx:
            for tcode, group in by_teacher.items():
                model.Add(sum(occupy(s, d, ts) for s in group) <= 1)
            for sec, group in by_section.items():
                model.Add(sum(occupy(s, d, ts) for s in group) <= 1)
            # Room capacity so the greedy Phase 2 always succeeds.
            model.Add(sum(occupy(s, d, ts) for s in ds.sessions if not s.is_lab)
                      <= len(ds.theory_rooms))
            model.Add(sum(occupy(s, d, ts) for s in ds.sessions if s.is_lab)
                      <= len(ds.lab_rooms))

    # Soft: spread each section's daily load. Penalise slot-units beyond a target.
    target_per_day = 4
    penalties = []
    for sec, group in by_section.items():
        for d in range(n_days):
            load = sum(occupy(s, d, ts) for s in group for ts in slot_idx)
            over = model.NewIntVar(0, n_slots, f"over_{sec}_{d}")
            model.Add(over >= load - target_per_day)
            penalties.append(over)
    model.Minimize(sum(penalties))

    solver = cp_model.CpSolver()
    solver.parameters.max_time_in_seconds = time_limit_s
    solver.parameters.num_search_workers = 8

    progress(0.55)
    t0 = time.time()
    status = solver.Solve(model)
    solve_ms = int((time.time() - t0) * 1000)
    progress(0.8)

    if status not in (cp_model.OPTIMAL, cp_model.FEASIBLE):
        raise RuntimeError(f"No feasible timetable (solver status={solver.StatusName(status)}).")

    # Read assignments back.
    placed: list[dict] = []
    for s in ds.sessions:
        for d in range(n_days):
            for st in starts_for[s.sid]:
                if (s.sid, d, st) in x and solver.Value(x[(s.sid, d, st)]) == 1:
                    placed.append({"session": s, "day": d, "start": st})
    progress(0.85)

    rows = _assign_rooms(ds, placed)
    progress(0.97)

    return {
        "rows": rows,
        "stats": {
            "status": solver.StatusName(status),
            "solve_ms": solve_ms,
            "meetings": len(rows),
            "sections": sorted(by_section.keys()),
            "teachers": len(by_teacher),
            "spread_penalty": int(solver.ObjectiveValue()),
        },
        "validation": _validate(ds, rows),
    }


# ─── Phase 2: greedy room assignment ──────────────────────────

def _assign_rooms(ds: Dataset, placed: list[dict]) -> list[dict]:
    slot_meta = {s["index"]: s for s in ds.slots}
    # busy[(day, ts)] -> set of rooms already taken in that time-slot.
    busy: dict[tuple[int, int], set[str]] = {}

    def free_room(pool: list[str], day: int, occupied_ts: list[int]) -> str | None:
        for r in pool:
            if all(r not in busy.get((day, ts), set()) for ts in occupied_ts):
                return r
        return None

    # Labs first — scarcer rooms.
    placed.sort(key=lambda p: (not p["session"].is_lab,))

    rows: list[dict] = []
    for i, p in enumerate(placed):
        s: Session = p["session"]
        day = p["day"]
        st = p["start"]
        occupied = list(range(st, st + s.length))
        pool = ds.lab_rooms if s.is_lab else ds.theory_rooms
        room = free_room(pool, day, occupied)
        if room is None:  # should not happen — Phase 1 capped counts
            room = "TBA"
        for ts in occupied:
            busy.setdefault((day, ts), set()).add(room)

        teacher = ds.teachers.get(s.teacher_code, {})
        rows.append({
            "id": f"gen-{i}",  # synthetic; Postgres assigns the real id on insert
            "day": ds.days[day],
            "time_start": slot_meta[st]["start"],
            "time_end": slot_meta[st + s.length - 1]["end"],
            "subject": s.subject,
            "subject_code": s.subject_code,
            "teacher_name": teacher.get("name"),
            "teacher_code": s.teacher_code,
            "room": room,
            "batch": ds.batch,
            "section": s.section,
            "semester": ds.semester,
            "is_active": True,
        })

    # Stable, human-friendly order for the preview / viewer.
    day_order = {d: i for i, d in enumerate(ds.days)}
    rows.sort(key=lambda r: (r["section"], day_order.get(r["day"], 99), r["time_start"]))
    return rows


# ─── Self-check used by the demo to prove correctness ─────────

def _validate(ds: Dataset, rows: list[dict]) -> dict:
    teacher_clashes = 0
    section_clashes = 0
    dayoff_violations = 0
    seen_teacher: dict[tuple, int] = {}
    seen_section: dict[tuple, int] = {}

    for r in rows:
        key_t = (r["teacher_code"], r["day"], r["time_start"])
        key_s = (r["section"], r["day"], r["time_start"])
        seen_teacher[key_t] = seen_teacher.get(key_t, 0) + 1
        seen_section[key_s] = seen_section.get(key_s, 0) + 1
        day_off = ds.teachers.get(r["teacher_code"], {}).get("day_off")
        if day_off and r["day"] == day_off:
            dayoff_violations += 1

    teacher_clashes = sum(v - 1 for v in seen_teacher.values() if v > 1)
    section_clashes = sum(v - 1 for v in seen_section.values() if v > 1)

    return {
        "teacher_clashes": teacher_clashes,
        "section_clashes": section_clashes,
        "dayoff_violations": dayoff_violations,
        "ok": teacher_clashes == 0 and section_clashes == 0 and dayoff_violations == 0,
    }


# ─── CLI: run the solver standalone and print a summary ───────

if __name__ == "__main__":
    ds = load_dataset()
    result = solve(ds)
    print(json.dumps({"stats": result["stats"], "validation": result["validation"]}, indent=2))
    print(f"\nfirst 6 of {len(result['rows'])} rows:")
    for r in result["rows"][:6]:
        print(f"  {r['section']} {r['day']:9} {r['time_start']}-{r['time_end']} "
              f"{r['subject_code']:9} {r['teacher_code']} {r['room']}")
