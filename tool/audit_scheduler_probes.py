"""Read-only synthetic probes for the 2026-10-20 readiness audit.

Run with engine/.venv/Scripts/python.exe tool/audit_scheduler_probes.py.
These demonstrate gaps; they are not acceptance tests for correct behavior.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT / "engine"), str(ROOT / "engine" / "tests")]
import ingest
import solver
from conftest import build_workbook, make_config, make_row, period


def probe(name, rows, config, fixed=None):
    ds = ingest.ingest_bytes(build_workbook(rows), fixed_sessions_per_week=fixed)
    result = solver.solve(ds, solver.load_config(config), time_limit_s=5)
    print(json.dumps({
        "probe": name,
        "validation_ok": result["validation"]["ok"],
        "excluded": len(ds["excluded"]),
        "warnings": ds["warnings"],
        "rows": [
            {k: r[k] for k in ("section", "teacher_code", "room", "time_start", "time_end")}
            for r in result["rows"]
        ],
    }))


one_slot = dict(days=["Sunday"], periods=[period(1, "09:00", "10:00", "D")])
probe("combined_section_overlap", [
    make_row(section="B", code="CSE-1101", teacher="AAA", classes=14),
    make_row(section="B+C", code="CSE-1201", teacher="BBB", classes=14),
], make_config(**one_slot))
probe("unknown_teacher", [
    make_row(teacher="NOT_IN_FACULTY", classes=14),
], make_config(**one_slot))
probe("required_row_missing_teacher", [
    make_row(classes=14),
    make_row(code="CSE-1201", teacher="", classes=14),
], make_config(**one_slot))
probe("overlapping_clock_periods", [
    make_row(code="CSE-1101", classes=14),
    make_row(code="CSE-1201", classes=14),
], make_config(days=["Sunday"], periods=[
    period(1, "09:00", "10:30", "D"),
    period(2, "10:00", "11:30", "E"),
]))
small_room = make_config(**one_slot, n_theory=1)
small_room["rooms"][-1]["capacity"] = 20
probe("room_capacity_20_students_100", [
    make_row(students=100, classes=14),
], small_room)
probe("fixed_rate_under_delivery", [
    make_row(code="CSE-4116", classes=38),
], make_config(), fixed=2)
