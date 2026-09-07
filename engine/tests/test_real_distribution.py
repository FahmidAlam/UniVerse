"""Regression guard against the real Summer-2025 distribution.

The workbook carries teacher PII and is gitignored, so these tests skip when it
is absent (CI, a fresh clone). Locally they pin the exact numbers the defect
analysis established, so a future parser change cannot quietly reintroduce the
inflated routine.

Set UNIVERSE_SOLVE=1 to also run the full CP-SAT solve (~90s).
"""

from __future__ import annotations

import os
from pathlib import Path

import pytest

import ingest
import solver

WORKBOOK = (Path(__file__).resolve().parents[1]
            / "routine generation files" / "Main_Distribution_Summer25.xlsx")

pytestmark = pytest.mark.skipif(
    not WORKBOOK.exists(),
    reason="real distribution workbook not present (gitignored PII)")


@pytest.fixture(scope="module")
def ds():
    return ingest.ingest_path(str(WORKBOOK), weeks_in_term=14)


def test_one_offering_per_cohort_and_course(ds):
    keys = [(o["cohort"], o["code"]) for o in ds["offerings"]]
    assert len(keys) == len(set(keys))
    assert ds["meta"]["offerings"] == 325
    assert ds["meta"]["rows"] == 356


def test_the_eighteen_shared_offerings_are_collapsed(ds):
    shared = [o for o in ds["offerings"] if len(o["teachers"]) > 1]
    assert len(shared) == 18
    # Each was producing four weekly classes instead of two.
    assert all(o["required_sessions"] == 2 for o in shared)
    assert ds["meta"]["sessions"] == 656


def test_shared_offerings_print_under_the_same_teacher_as_the_official_routine(ds):
    """Verified against CSE Routine Summer'25 Version 2.0.xlsx."""
    expected = {("64-A", "CSE-2111"): "DCP",
                ("64-B", "CSE-2111"): "DCP",
                ("66-D", "CSE-1101"): "PRP",
                ("60-A", "CSE-4113"): "ZMM",
                ("58-B+C", "CSE-4233"): "DCP"}
    got = {(o["cohort"], o["code"]): o["teachers"][0] for o in ds["offerings"]}
    for key, teacher in expected.items():
        assert got[key] == teacher, key


def test_cse_4116_needs_three_classes_a_week(ds):
    """38 whole-term classes over 14 weeks. The published routine puts it on
    Sun P1, Mon P1 and Tue P4; the old engine gave it two slots."""
    for o in ds["offerings"]:
        if o["code"] == "CSE-4116":
            assert o["classes_total"] == 38
            assert o["required_sessions"] == 3
    assert ds["meta"]["sessions_per_week_histogram"] == {2: 319, 3: 6}


def test_non_timetabled_courses_are_typed_not_dropped(ds):
    by_code = {}
    for e in ds["excluded"]:
        by_code.setdefault(e["code"], []).append(e)
    assert set(by_code) == {"CSE-3240", "CSE-4140", "CSE-4801",
                            "ACM-1000", "ACM-2000"}
    for code in ("CSE-3240", "CSE-4140", "CSE-4801"):
        assert all(e["reason"] == ingest.EXCLUDE_NO_TEACHER for e in by_code[code])
    for code in ("ACM-1000", "ACM-2000"):
        assert all(e["reason"] == ingest.EXCLUDE_NO_BATCH for e in by_code[code])
    assert len(ds["excluded"]) == 15


@pytest.mark.skipif(os.environ.get("UNIVERSE_SOLVE") != "1",
                    reason="set UNIVERSE_SOLVE=1 to run the full solve")
def test_the_real_distribution_solves_completely(ds):
    cfg = solver.load_config()
    res = solver.solve(ds, cfg, time_limit_s=120)
    v = res["validation"]
    assert v["missing_courses"] == 0
    assert v["under_scheduled"] == 0
    assert v["over_scheduled"] == 0
    assert v["unexpected_courses"] == 0
    assert v["ok"] is True
    assert len(res["rows"]) + len(res["service_rows"]) == ds["meta"]["sessions"]
