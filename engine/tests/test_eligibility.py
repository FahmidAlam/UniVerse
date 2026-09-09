"""Faculty-course eligibility.

This is a gate on the DISTRIBUTION, not an instruction to the scheduler. The
workbook names the teacher for every offering and CP-SAT only chooses
(day, period) — it has never selected a teacher. So what these tests pin is
that a workbook handing a course to an unqualified teacher cannot be published,
and that turning the feature on does not fail the teachers nobody has
configured yet.
"""

from __future__ import annotations

from conftest import build_workbook, make_config, make_row

import ingest
import solver


def elig(*entries):
    """`("EBH", "CSE-1101", 1)` -> the config shape the Flutter app sends."""
    return [{"acronym": a, "course_code": c, "eligible": True, "priority": p}
            for a, c, p in entries]


def run(rows, eligibility=None, time_limit=10.0):
    raw = make_config(teachers=("AAA", "BBB", "CCC"))
    if eligibility is not None:
        raw["eligibility"] = eligibility
    cfg = solver.load_config(override=raw)
    ds = ingest.ingest_bytes(build_workbook(rows),
                             weeks_in_term=cfg["weeks_in_term"])
    return cfg, solver.solve(ds, cfg, time_limit_s=time_limit)


# ── normalization ────────────────────────────────────────────────────────

def test_eligibility_is_read_case_insensitively():
    cfg = solver.load_config(override=make_config(
        eligibility=elig(("ebh", "cse-1101", 1))))
    e = cfg["eligibility"]
    assert e["eligible"] == {"EBH": {"CSE-1101"}}
    assert e["priority"][("EBH", "CSE-1101")] == 1
    assert e["declared"] == {"EBH"}


def test_an_ineligible_row_is_recorded_but_grants_nothing():
    cfg = solver.load_config(override=make_config(eligibility=[
        {"acronym": "AAA", "course_code": "CSE-1101", "eligible": False},
    ]))
    e = cfg["eligibility"]
    assert e["eligible"].get("AAA", set()) == set()
    # Still declared: the admin HAS configured this teacher, so they can fail.
    assert "AAA" in e["declared"]


def test_malformed_rows_are_ignored_rather_than_crashing():
    cfg = solver.load_config(override=make_config(eligibility=[
        {"acronym": "", "course_code": "CSE-1101"},
        {"acronym": "AAA"},
        "not a dict",
        {"acronym": "AAA", "course_code": "CSE-1101", "priority": "high"},
    ]))
    e = cfg["eligibility"]
    assert e["eligible"] == {"AAA": {"CSE-1101"}}
    assert ("AAA", "CSE-1101") not in e["priority"]


# ── the gate ─────────────────────────────────────────────────────────────

def test_an_unconfigured_teacher_is_never_reported():
    """Unconfigured means unknown, not unqualified. Switching the feature on
    with an empty table must not fail every offering at once."""
    cfg, res = run([make_row(code="CSE-1101", teacher="AAA")], eligibility=[])
    assert res["validation"]["ineligible_assignments"] == 0
    assert res["validation"]["ok"] is True


def test_a_configured_teacher_teaching_a_listed_course_passes():
    cfg, res = run([make_row(code="CSE-1101", teacher="AAA")],
                   eligibility=elig(("AAA", "CSE-1101", 1)))
    assert res["validation"]["ineligible_assignments"] == 0
    assert res["validation"]["ok"] is True


def test_a_configured_teacher_teaching_an_unlisted_course_fails():
    cfg, res = run([make_row(code="CSE-2205", teacher="AAA")],
                   eligibility=elig(("AAA", "CSE-1101", 1),
                                    ("AAA", "CSE-1102", 2)))
    v = res["validation"]
    assert v["ineligible_assignments"] == 2  # both weekly sessions
    assert v["ok"] is False


def test_the_failure_names_the_teacher_course_cohort_and_what_they_may_teach():
    cfg, res = run([make_row(code="CSE-2205", teacher="AAA")],
                   eligibility=elig(("AAA", "CSE-1101", 1)))
    d = res["validation"]["details"]["ineligible_assignments"][0]
    assert d["teacher"] == "AAA"
    assert d["code"] == "CSE-2205"
    assert d["cohort"] == "66-A"
    assert d["eligible_for"] == ["CSE-1101"]
    assert d["day"] and d["period"]


def test_only_the_configured_teacher_is_judged():
    """AAA is configured and off-list; BBB is not configured at all."""
    cfg, res = run(
        [make_row(code="CSE-2205", teacher="AAA"),
         make_row(code="CSE-3301", teacher="BBB")],
        eligibility=elig(("AAA", "CSE-1101", 1)))
    d = res["validation"]["details"]["ineligible_assignments"]
    assert {x["teacher"] for x in d} == {"AAA"}


def test_a_co_teacher_is_judged_too():
    """A split offering carries both teachers; the second one is just as
    capable of being unqualified as the one printed on the grid."""
    rows = [make_row(code="CSE-2111", teacher="AAA", classes=14),
            make_row(code="CSE-2111", teacher="BBB", classes=14)]
    cfg, res = run(rows, eligibility=elig(("AAA", "CSE-2111", 1),
                                          ("BBB", "CSE-9999", 1)))
    d = res["validation"]["details"]["ineligible_assignments"]
    assert {x["teacher"] for x in d} == {"BBB"}


def test_eligibility_does_not_change_who_teaches_the_course():
    """The gate reports; it never reassigns. The workbook still wins."""
    cfg, res = run([make_row(code="CSE-2205", teacher="AAA")],
                   eligibility=elig(("BBB", "CSE-2205", 1)))
    assert {r["teacher_code"] for r in res["rows"]} == {"AAA"}
