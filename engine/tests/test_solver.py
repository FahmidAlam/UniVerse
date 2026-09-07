"""Scheduling invariants and post-generation validation.

The bar is academic validity, not visual validity: the distribution is a hard
constraint, so a routine that loses a course or shortchanges its teaching time
must come back `ok: False` with the offending course named.
"""

from __future__ import annotations

import pytest
from conftest import DEFAULT_PERIODS, build_workbook, make_config, make_row, period

import ingest
import solver

FAST = 8.0  # seconds; every fixture here is tiny


def run(rows, weeks=14, time_limit=FAST, **cfg_kw):
    raw = make_config(**cfg_kw)
    cfg = solver.load_config(override=raw)
    ds = ingest.ingest_bytes(build_workbook(rows), weeks_in_term=cfg["weeks_in_term"])
    return ds, cfg, solver.solve(ds, cfg, time_limit_s=time_limit)


def all_rows(res):
    return res["rows"] + res["service_rows"]


def count(res, cohort, code):
    return sum(1 for r in all_rows(res)
               if f"{r['batch']}-{r['section']}" == cohort
               and r["subject_code"] == code)


# ── course completeness & credit compliance ──────────────────────────────

def test_every_distribution_course_reaches_the_routine():
    rows = [make_row(section=s, code=c, teacher=t)
            for s in ("A", "B")
            for c, t in (("CSE-1101", "AAA"), ("CSE-1151", "BBB"),
                         ("MAT-1151", "CCC"))]
    ds, cfg, res = run(rows)
    v = res["validation"]
    assert v["required_offerings"] == 6
    assert v["scheduled_offerings"] == 6
    assert v["missing_courses"] == 0
    assert v["unexpected_courses"] == 0
    assert v["ok"] is True


def test_session_count_matches_the_credit_requirement():
    rows = [make_row(code="CSE-1101", teacher="AAA", classes=28),
            make_row(code="CSE-4116", teacher="BBB", classes=38),
            make_row(code="CSE-9101", teacher="CCC", classes=14)]
    ds, cfg, res = run(rows)
    assert count(res, "66-A", "CSE-1101") == 2
    assert count(res, "66-A", "CSE-4116") == 3
    assert count(res, "66-A", "CSE-9101") == 1
    assert res["validation"]["under_scheduled"] == 0
    assert res["validation"]["over_scheduled"] == 0


def test_shorter_term_schedules_the_same_course_more_often():
    rows = [make_row(code="CSE-1101", classes=28)]
    _, _, long_term = run(rows, weeks_in_term=14)
    _, _, short_term = run(rows, weeks_in_term=10)
    assert count(long_term, "66-A", "CSE-1101") == 2
    assert count(short_term, "66-A", "CSE-1101") == 3


# ── team teaching ────────────────────────────────────────────────────────

def test_split_course_is_scheduled_once_not_twice():
    rows = [make_row(code="CSE-2111", teacher="AAA", classes=14),
            make_row(code="CSE-2111", teacher="BBB", classes=14)]
    _, _, res = run(rows)
    assert count(res, "66-A", "CSE-2111") == 2
    assert {r["teacher_code"] for r in all_rows(res)} == {"AAA"}


def test_a_co_teacher_is_never_double_booked():
    """BBB co-teaches 66-A CSE-2111 and solely teaches 66-B CSE-1151. Both must
    still be free for BBB at the same time, because BBB takes the shared slot
    in the second half of the term."""
    rows = [make_row(section="A", code="CSE-2111", teacher="AAA", classes=14),
            make_row(section="A", code="CSE-2111", teacher="BBB", classes=14),
            make_row(section="B", code="CSE-1151", teacher="BBB", classes=28)]
    _, _, res = run(rows)
    busy = [(r["day"], r["period"]) for r in all_rows(res)
            if "BBB" in (r["teachers"] or [])]
    assert len(busy) == len(set(busy))
    assert res["validation"]["teacher_clashes"] == 0


def test_a_co_teachers_day_off_is_respected():
    rows = [make_row(code="CSE-2111", teacher="AAA", classes=14),
            make_row(code="CSE-2111", teacher="BBB", classes=14)]
    _, _, res = run(rows, off_days={"BBB": ["Sunday", "Monday", "Tuesday"]})
    assert {r["day"] for r in all_rows(res)}.isdisjoint(
        {"Sunday", "Monday", "Tuesday"})
    assert res["validation"]["dayoff_violations"] == 0


# ── conflicts ────────────────────────────────────────────────────────────

def test_no_teacher_cohort_or_room_collisions():
    rows = [make_row(section=s, code=c, teacher=t)
            for s in ("A", "B", "C")
            for c, t in (("CSE-1101", "AAA"), ("CSE-1151", "BBB"),
                         ("MAT-1151", "CCC"))]
    _, _, res = run(rows, time_limit=15)
    v = res["validation"]
    assert (v["teacher_clashes"], v["cohort_clashes"], v["room_clashes"]) == (0, 0, 0)
    assert v["unplaced_rooms"] == 0


def test_labs_land_in_lab_rooms_and_stay_next_to_their_theory():
    rows = [make_row(section=s, code=c, teacher="AAA")
            for s in ("A", "B")
            for c in ("CSE-1101", "CSE-1102")]
    _, _, res = run(rows)
    labs = [r for r in all_rows(res) if r["subject_code"] == "CSE-1102"]
    assert labs and all(r["room"].startswith("LAB-") for r in labs)
    assert res["validation"]["lab_room_violations"] == 0
    assert res["validation"]["lab_theory_violations"] == 0


# ── configuration drives the schedule, not code ──────────────────────────

def test_changing_period_times_changes_the_routine():
    """Summer -> winter timings must need only a settings change."""
    rows = [make_row(code="CSE-1101")]
    winter = [period(1, "09:30", "10:45", "D"), period(2, "10:45", "12:00", "E")]
    _, _, res = run(rows, periods=winter)
    starts = {r["time_start"] for r in all_rows(res)}
    assert starts <= {"09:30", "10:45"}
    assert res["validation"]["invalid_time_slots"] == 0


def test_working_days_come_from_configuration():
    rows = [make_row(code="CSE-1101")]
    _, _, res = run(rows, days=["Monday", "Tuesday"])
    assert {r["day"] for r in all_rows(res)} <= {"Monday", "Tuesday"}
    assert res["validation"]["invalid_days"] == 0


def test_per_day_blocked_periods_are_honoured():
    rows = [make_row(section=s, code="CSE-1101") for s in ("A", "B")]
    _, _, res = run(rows, blocked_periods={"Friday": [4], "Saturday": [1, 2]})
    for r in all_rows(res):
        assert not (r["day"] == "Friday" and r["period"] == 4)
        assert not (r["day"] == "Saturday" and r["period"] in (1, 2))
    assert res["validation"]["blocked_period_violations"] == 0


def test_legacy_friday_no_p4_flag_still_works():
    rows = [make_row(section=s, code="CSE-1101") for s in ("A", "B")]
    _, _, res = run(rows, friday_no_p4=True)
    assert not any(r["day"] == "Friday" and r["period"] == 4 for r in all_rows(res))


def test_online_period_is_held_back_unless_enabled():
    evening = DEFAULT_PERIODS + [period(7, "19:00", "20:20", "K")]
    rows = [make_row(code="CSE-1101")]

    _, cfg, res = run(rows, periods=evening)
    assert 7 in cfg["excluded_periods"]
    assert all(r["period"] != 7 for r in all_rows(res))

    _, cfg, _ = run(rows, periods=evening, allow_online_periods=True)
    assert 7 not in cfg["excluded_periods"]


def test_semester_map_overrides_the_batch_arithmetic():
    """The countdown-from-newest-batch fallback assumes one intake per term,
    which is wrong under a tri-semester calendar."""
    rows = [make_row(batch="66", code="CSE-1101"),
            make_row(batch="64", code="CSE-2111")]
    _, _, default = run(rows)
    by_batch = {r["batch"]: r["semester"] for r in all_rows(default)}
    assert by_batch == {"66": 1, "64": 3}

    _, _, mapped = run(rows, semester_map={"66": 1, "64": 2})
    by_batch = {r["batch"]: r["semester"] for r in all_rows(mapped)}
    assert by_batch == {"66": 1, "64": 2}


# ── validation catches a corrupted routine ───────────────────────────────

def _validate_rows(rows_spec, cfg, ds):
    pmeta = {int(p["idx"]): p for p in cfg["periods"]}
    return solver._validate(ds, cfg, rows_spec, cfg["days"], pmeta)


def _row(code, day="Sunday", period_idx=1, batch="66", section="A",
         teacher="AAA", room="R-101", is_lab=False, start=None, end=None):
    p = {int(q["idx"]): q for q in DEFAULT_PERIODS}[period_idx]
    return {"day": day, "period": period_idx, "batch": batch, "section": section,
            "subject_code": code, "teacher_code": teacher, "teachers": [teacher],
            "room": room, "is_lab": is_lab,
            "time_start": start or p["start"], "time_end": end or p["end"]}


@pytest.fixture
def two_course_dataset():
    rows = [make_row(code="CSE-1101", teacher="AAA"),
            make_row(code="CSE-1151", teacher="BBB")]
    cfg = solver.load_config(override=make_config())
    ds = ingest.ingest_bytes(build_workbook(rows), weeks_in_term=14)
    return ds, cfg


def test_validation_flags_a_dropped_course(two_course_dataset):
    ds, cfg = two_course_dataset
    v = _validate_rows([_row("CSE-1101"), _row("CSE-1101", period_idx=2)], cfg, ds)
    assert v["missing_courses"] == 1
    assert v["details"]["missing_courses"][0]["code"] == "CSE-1151"
    assert v["ok"] is False


def test_validation_flags_under_and_over_scheduling(two_course_dataset):
    ds, cfg = two_course_dataset
    v = _validate_rows([
        _row("CSE-1101"),                                     # needs 2, has 1
        _row("CSE-1151", period_idx=2), _row("CSE-1151", day="Monday"),
        _row("CSE-1151", day="Tuesday"),                      # needs 2, has 3
    ], cfg, ds)
    assert v["under_scheduled"] == 1
    assert v["over_scheduled"] == 1
    assert v["details"]["under_scheduled"][0]["code"] == "CSE-1101"
    assert v["details"]["over_scheduled"][0]["scheduled"] == 3
    assert v["ok"] is False


def test_validation_flags_a_course_not_in_the_distribution(two_course_dataset):
    ds, cfg = two_course_dataset
    v = _validate_rows([
        _row("CSE-1101"), _row("CSE-1101", period_idx=2),
        _row("CSE-1151", period_idx=3), _row("CSE-1151", day="Monday"),
        _row("CSE-9999", day="Tuesday"),
    ], cfg, ds)
    assert v["unexpected_courses"] == 1
    assert v["details"]["unexpected_courses"][0]["code"] == "CSE-9999"
    assert v["ok"] is False


def test_validation_flags_clashes_and_bad_slots(two_course_dataset):
    ds, cfg = two_course_dataset
    v = _validate_rows([
        _row("CSE-1101"), _row("CSE-1101", period_idx=2),
        _row("CSE-1151", teacher="AAA"),          # teacher + cohort + room clash
        _row("CSE-1151", day="Monday", start="07:00", end="08:00"),
    ], cfg, ds)
    assert v["teacher_clashes"] == 1
    assert v["cohort_clashes"] == 1
    assert v["room_clashes"] == 1
    assert v["invalid_time_slots"] == 1
    assert v["ok"] is False


def test_validation_flags_an_unplaced_room(two_course_dataset):
    ds, cfg = two_course_dataset
    v = _validate_rows([
        _row("CSE-1101"), _row("CSE-1101", period_idx=2),
        _row("CSE-1151", period_idx=3), _row("CSE-1151", day="Monday", room="TBA"),
    ], cfg, ds)
    assert v["unplaced_rooms"] == 1
    assert v["ok"] is False


# ── failures explain themselves ──────────────────────────────────────────

def test_a_teacher_with_no_free_day_names_the_course_and_the_rule():
    rows = [make_row(code="CSE-1101", teacher="AAA")]
    with pytest.raises(RuntimeError) as e:
        run(rows, off_days={"AAA": list(make_config()["days"])})
    msg = str(e.value)
    assert "CSE-1101" in msg and "66-A" in msg and "AAA" in msg
    assert "Days taught" in msg


def test_an_overloaded_teacher_is_named_in_the_infeasibility_error():
    """One teacher, one working day, four periods, ten sessions needed."""
    rows = [make_row(code=f"CSE-11{i}1", teacher="AAA") for i in range(5)]
    with pytest.raises(RuntimeError) as e:
        run(rows, days=["Sunday"])
    msg = str(e.value)
    assert "AAA" in msg
    assert "needs 10" in msg


def test_a_configuration_with_no_usable_period_fails_clearly():
    rows = [make_row(code="CSE-1101")]
    with pytest.raises(RuntimeError, match="No usable periods"):
        run(rows, excluded_periods=[1, 2, 3, 4])
