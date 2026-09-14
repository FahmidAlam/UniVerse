"""A fixed number of weekly classes for every course.

By default the engine derives each offering's weekly meetings from its own
term total, `ceil(No. Of Classes / weeks_in_term)`. In the Summer-2025
distribution that is 2/week for 319 offerings and 3/week for six — all
CSE-4116, which carries 38 classes — and the published Summer-2025 routine
schedules those six three times a week too.

The department has decided every course should meet exactly twice a week.
`fixed_sessions_per_week` carries that decision as configuration rather than a
literal, so it stays visible and reversible. The cost is real and these tests
pin it: a course needing more than the fixed rate is not fully taught, and the
engine must say so per offering rather than losing the classes quietly.
"""

from __future__ import annotations

from collections import Counter

from conftest import build_workbook, make_config, make_row

import ingest
import solver

FAST = 10.0


def ingest_rows(rows, fixed=None, weeks=14):
    return ingest.ingest_bytes(build_workbook(rows), weeks_in_term=weeks,
                               fixed_sessions_per_week=fixed)


# ── the derivation, unchanged when nothing is fixed ──────────────────────

def test_without_a_fixed_rate_the_class_count_still_decides():
    rows = [make_row(code="CSE-1101", classes=28),
            make_row(code="CSE-4116", classes=38),
            make_row(code="CSE-9101", classes=14)]
    got = {o["code"]: o["required_sessions"] for o in ingest_rows(rows)["offerings"]}
    assert got == {"CSE-1101": 2, "CSE-4116": 3, "CSE-9101": 1}


# ── the fixed rate overrides it ──────────────────────────────────────────

def test_a_fixed_rate_gives_every_course_the_same_count():
    rows = [make_row(code="CSE-1101", classes=28),
            make_row(code="CSE-4116", classes=38),
            make_row(code="CSE-9101", classes=14)]
    ds = ingest_rows(rows, fixed=2)
    assert {o["required_sessions"] for o in ds["offerings"]} == {2}
    assert {o["sessions_basis"] for o in ds["offerings"]} == {"fixed"}


def test_the_fixed_rate_is_reported_in_the_run_metadata():
    ds = ingest_rows([make_row(code="CSE-1101", classes=28)], fixed=2)
    assert ds["meta"]["fixed_sessions_per_week"] == 2
    assert ds["meta"]["sessions_per_week_histogram"] == {2: 1}


def test_a_rate_other_than_two_works_just_as_well():
    """The setting is a number, not a re-hard-coded 2."""
    ds = ingest_rows([make_row(code="CSE-1101", classes=28)], fixed=3)
    assert [o["required_sessions"] for o in ds["offerings"]] == [3]


def test_zero_or_none_restores_the_derivation():
    rows = [make_row(code="CSE-4116", classes=38)]
    for value in (None, 0):
        ds = ingest_rows(rows, fixed=value)
        assert [o["required_sessions"] for o in ds["offerings"]] == [3], value


# ── the cost is never silent ─────────────────────────────────────────────

def test_a_short_changed_course_is_named_with_the_classes_it_loses():
    ds = ingest_rows([make_row(code="CSE-4116", classes=38)], fixed=2)
    short = [w for w in ds["warnings"] if "fixed rate" in w]
    assert len(short) == 1
    w = short[0]
    assert "CSE-4116" in w and "66-A" in w
    assert "38 classes" in w and "3/week" in w and "2/week" in w
    assert "10 class(es)" in w      # 38 - (2 * 14)


def test_a_course_the_fixed_rate_suits_is_not_warned_about():
    ds = ingest_rows([make_row(code="CSE-1101", classes=28)], fixed=2)
    assert [w for w in ds["warnings"] if "fixed rate" in w] == []


def test_every_affected_section_gets_its_own_warning():
    rows = [make_row(section=s, code="CSE-4116", classes=38,
                     teacher=f"T{i}")
            for i, s in enumerate("ABC")]
    ds = ingest_rows(rows, fixed=2)
    short = [w for w in ds["warnings"] if "fixed rate" in w]
    assert len(short) == 3
    assert {"66-A", "66-B", "66-C"} == {w.split()[1].rstrip(":") for w in short}


# ── it reaches the solver through configuration ──────────────────────────

def test_the_setting_is_read_from_the_engine_configuration():
    cfg = solver.load_config(override=make_config(fixed_sessions_per_week=2))
    assert cfg["fixed_sessions_per_week"] == 2


def test_a_missing_or_zero_setting_normalises_to_none():
    for value in (None, 0, "", "abc", -1):
        cfg = solver.load_config(
            override=make_config(fixed_sessions_per_week=value))
        assert cfg["fixed_sessions_per_week"] is None, value


def test_a_fixed_rate_produces_exactly_that_many_classes_in_the_routine():
    rows = [make_row(code="CSE-1101", classes=28),
            make_row(code="CSE-4116", classes=38)]
    cfg = solver.load_config(override=make_config(
        teachers=["AAA"], fixed_sessions_per_week=2))
    ds = ingest.ingest_bytes(
        build_workbook(rows), weeks_in_term=cfg["weeks_in_term"],
        fixed_sessions_per_week=cfg["fixed_sessions_per_week"])
    res = solver.solve(ds, cfg, time_limit_s=FAST)
    per_course = Counter(r["subject_code"] for r in res["rows"])
    assert per_course == {"CSE-1101": 2, "CSE-4116": 2}
    v = res["validation"]
    assert v["ok"] is True
    assert v["under_scheduled"] == 0 and v["over_scheduled"] == 0


def test_the_validator_measures_against_the_fixed_rate_not_the_class_count():
    """Once the rate is configured it IS the requirement, so a course meeting
    twice must not be reported as under-scheduled for needing three."""
    cfg = solver.load_config(override=make_config(
        teachers=["AAA"], fixed_sessions_per_week=2))
    ds = ingest.ingest_bytes(
        build_workbook([make_row(code="CSE-4116", classes=38)]),
        weeks_in_term=cfg["weeks_in_term"],
        fixed_sessions_per_week=cfg["fixed_sessions_per_week"])
    res = solver.solve(ds, cfg, time_limit_s=FAST)
    assert len(res["rows"]) == 2
    assert res["validation"]["under_scheduled"] == 0
    assert res["validation"]["ok"] is True
