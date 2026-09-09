"""The same course must not meet twice on one day.

This used to be a soft penalty (`different_days`, weight 8) and nothing more.
On the deployed engine — two workers on a shared CPU, a short budget — the
solver returns FEASIBLE with the penalties only partly paid, so a course could
land on Sunday P1 *and* Sunday P4 and the routine still called itself valid.
An academic rule does not belong in the objective function, so it is now a hard
constraint in the model AND a correctness failure in the validator.

It is scoped to one (cohort, course). Theory<->sessional pairing is a rule
about two DIFFERENT course codes and is unaffected: CSE-1101 and CSE-1102 are
still required to share a day in adjacent periods.
"""

from __future__ import annotations

from collections import defaultdict

from conftest import DEFAULT_PERIODS, build_workbook, make_config, make_row, period

import ingest
import solver

FAST = 10.0


def run(rows, time_limit=FAST, **cfg_kw):
    cfg = solver.load_config(override=make_config(**cfg_kw))
    ds = ingest.ingest_bytes(build_workbook(rows),
                             weeks_in_term=cfg["weeks_in_term"])
    return ds, cfg, solver.solve(ds, cfg, time_limit_s=time_limit)


def days_of(res, cohort, code):
    return [r["day"] for r in res["rows"] + res["service_rows"]
            if f"{r['batch']}-{r['section']}" == cohort
            and r["subject_code"] == code]


def same_day_pairs(res):
    seen = defaultdict(int)
    for r in res["rows"] + res["service_rows"]:
        seen[(r["batch"], r["section"], r["subject_code"], r["day"])] += 1
    return sum(v - 1 for v in seen.values() if v > 1)


# ── the rule itself ──────────────────────────────────────────────────────

def test_two_sessions_of_one_course_land_on_different_days():
    ds, cfg, res = run([make_row(code="CSE-1101", teacher="AAA", classes=28)])
    d = days_of(res, "66-A", "CSE-1101")
    assert len(d) == 2
    assert len(set(d)) == 2
    assert res["validation"]["same_day_sessions"] == 0


def test_three_sessions_use_three_different_days():
    ds, cfg, res = run([make_row(code="CSE-4116", teacher="AAA", classes=38)])
    d = days_of(res, "66-A", "CSE-4116")
    assert len(d) == 3
    assert len(set(d)) == 3


def test_the_rule_holds_when_the_grid_is_tight():
    """Test M: two sessions that would naturally fall on the same day.

    One teaching day of four periods is not enough room for a course needing
    two meetings, so a solver that only *preferred* different days would double
    up here. With the constraint hard, this must come back infeasible instead
    of quietly producing an invalid routine.
    """
    try:
        _, _, res = run([make_row(code="CSE-1101", teacher="AAA", classes=28)],
                        days=["Sunday"])
    except RuntimeError as e:
        assert "CSE-1101" in str(e) or "feasible" in str(e).lower()
        return
    assert same_day_pairs(res) == 0


def test_a_squeezed_solve_still_obeys_the_rule():
    """The failure mode that started this: many cohorts, a short budget.

    The solver may return FEASIBLE rather than OPTIMAL here, which is exactly
    when the old soft penalty went unpaid. A hard constraint holds regardless
    of how much search time it got.
    """
    rows = [make_row(batch="66", section=s, code=c, teacher=t, classes=28)
            for s in ("A", "B", "C", "D")
            for c, t in (("CSE-1101", "AAA"), ("CSE-1103", "BBB"),
                         ("CSE-1105", "CCC"))]
    _, _, res = run(rows, time_limit=3.0)
    assert same_day_pairs(res) == 0
    assert res["validation"]["same_day_sessions"] == 0


# ── it does not fight theory<->sessional pairing ─────────────────────────

def test_a_lab_still_shares_its_theory_day_and_the_next_period():
    """CSE-1101 + CSE-1102 are different offerings, so the same-day rule does
    not apply between them — only within each one."""
    rows = [make_row(code="CSE-1101", teacher="AAA", classes=28),
            make_row(code="CSE-1102", teacher="AAA", classes=28)]
    _, _, res = run(rows)
    v = res["validation"]
    assert v["lab_theory_pairs"] == 2
    assert v["lab_theory_violations"] == 0
    assert v["same_day_sessions"] == 0
    assert len(set(days_of(res, "66-A", "CSE-1101"))) == 2
    assert len(set(days_of(res, "66-A", "CSE-1102"))) == 2


# ── validation treats it as a failure, not a note ────────────────────────

def _rows_on_one_day(cfg):
    p = cfg["periods"]
    return [
        {"batch": "66", "section": "A", "subject_code": "CSE-1101",
         "subject": "C", "teacher_code": "AAA", "teachers": ["AAA"],
         "room": "R-101", "day": "Sunday", "period": int(p[i]["idx"]),
         "time_start": p[i]["start"], "time_end": p[i]["end"],
         "is_lab": False, "is_service": False, "semester": 1}
        for i in (0, 2)
    ]


def _dataset_for_one_course():
    cfg = solver.load_config(override=make_config())
    ds = ingest.ingest_bytes(
        build_workbook([make_row(code="CSE-1101", teacher="AAA", classes=28)]),
        weeks_in_term=cfg["weeks_in_term"])
    return ds, cfg


def test_validation_fails_a_routine_with_a_doubled_up_course():
    ds, cfg = _dataset_for_one_course()
    rows = _rows_on_one_day(cfg)
    v = solver._validate(ds, cfg, rows, cfg["days"],
                         {int(p["idx"]): p for p in cfg["periods"]})
    assert v["same_day_sessions"] == 1
    assert v["ok"] is False
    assert v["same_day_rule"] == "enforced"


def test_the_failure_names_the_course_cohort_day_and_periods():
    ds, cfg = _dataset_for_one_course()
    rows = _rows_on_one_day(cfg)
    v = solver._validate(ds, cfg, rows, cfg["days"],
                         {int(p["idx"]): p for p in cfg["periods"]})
    detail = v["details"]["same_day_sessions"][0]
    assert detail["code"] == "CSE-1101"
    assert detail["cohort"] == "66-A"
    assert detail["day"] == "Sunday"
    assert detail["teacher"] == "AAA"
    assert detail["periods"] == [1, 3]


# ── the escape hatches are data, not code ────────────────────────────────

def test_the_rule_can_be_switched_off_in_configuration():
    ds, cfg = _dataset_for_one_course()
    cfg = solver.load_config(
        override=make_config(allow_same_day_sessions=True))
    v = solver._validate(ds, cfg, _rows_on_one_day(cfg), cfg["days"],
                         {int(p["idx"]): p for p in cfg["periods"]})
    assert v["same_day_sessions"] == 0
    assert v["ok"] is True
    assert v["same_day_rule"] == "off"


def test_a_single_course_can_be_exempted_without_relaxing_the_rest():
    ds, cfg = _dataset_for_one_course()
    cfg = solver.load_config(
        override=make_config(same_day_exempt_courses=["cse-1101"]))
    v = solver._validate(ds, cfg, _rows_on_one_day(cfg), cfg["days"],
                         {int(p["idx"]): p for p in cfg["periods"]})
    assert v["same_day_sessions"] == 0
    assert v["ok"] is True


def test_an_exempt_course_may_actually_be_scheduled_twice_in_a_day():
    """The exemption reaches the model, not just the validator: one teaching
    day is only solvable for a two-session course when it is exempt."""
    _, _, res = run([make_row(code="CSE-1101", teacher="AAA", classes=28)],
                    days=["Sunday"], same_day_exempt_courses=["CSE-1101"])
    assert len(days_of(res, "66-A", "CSE-1101")) == 2
    assert res["validation"]["ok"] is True
