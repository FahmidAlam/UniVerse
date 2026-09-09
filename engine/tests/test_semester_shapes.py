"""The engine must not know which term it is.

Every one of these runs a DIFFERENT institutional shape through the same code
with no configuration change: other batch numbers, other section counts, other
courses, other faculty. Summer-2025 is a fixture, not the specification, so
nothing here uses batch 66 as a reference point.
"""

from __future__ import annotations

import io

import openpyxl
import pytest
from conftest import build_workbook, make_config, make_row

import ingest
import render
import solver

FAST = 10.0


def shape(spec, courses=(("CSE-1101", "T1"), ("CSE-1103", "T2")), **cfg_kw):
    """`spec` is {batch: [sections]}. Returns (dataset, cfg, result)."""
    rows = [make_row(batch=b, section=s, code=c, teacher=t, classes=28)
            for b, sections in spec.items()
            for s in sections
            for c, t in courses]
    teachers = sorted({t for _, t in courses})
    cfg = solver.load_config(override=make_config(teachers=teachers, **cfg_kw))
    ds = ingest.ingest_bytes(build_workbook(rows),
                             weeks_in_term=cfg["weeks_in_term"])
    return ds, cfg, solver.solve(ds, cfg, time_limit_s=FAST)


# ── Tests A-D: whatever batches and sections the distribution happens to have

@pytest.mark.parametrize("spec, expected", [
    # Test A
    ({"67": ["A", "B"], "68": ["A", "B", "C"], "69": ["A"]},
     ["69-A", "68-A", "68-B", "68-C", "67-A", "67-B"]),
    # Test B — the batches have all rolled over
    ({"68": ["A"], "69": ["A", "B"], "70": ["A", "B", "C"]},
     ["70-A", "70-B", "70-C", "69-A", "69-B", "68-A"]),
    # Test C — a batch with a single section
    ({"71": ["A"]}, ["71-A"]),
    # Test D — a batch with many sections
    ({"72": list("ABCDEFGH")}, [f"72-{s}" for s in "ABCDEFGH"]),
])
def test_render_order_is_derived_from_the_data(spec, expected):
    ds, cfg, res = shape(spec)
    assert ds["cohorts"] == expected


def test_a_non_numeric_cohort_sorts_deterministically_after_numeric_ones():
    ds, cfg, res = shape({"70": ["A"], "69": ["A"]})
    cohorts = {"70-A", "69-A", "BuA-A", "ENG-A"}
    order = ingest._ordered_cohorts(cohorts)
    assert order[:2] == ["70-A", "69-A"]
    # Non-numeric batches follow every numeric one, and tie-break on the full
    # cohort name so the order cannot change between runs of the same input.
    assert order[2:] == ["BuA-A", "ENG-A"]
    assert all(ingest._ordered_cohorts(cohorts) == order for _ in range(5))


def test_batch_groups_follow_the_current_distribution():
    ds, cfg, res = shape({"68": ["A"], "69": ["A", "B"],
                          "70": ["A", "B", "C"]})
    groups = render.cohort_groups(ds["cohorts"])
    assert [(g["batch"], len(g["cohorts"])) for g in groups] == [
        ("70", 3), ("69", 2), ("68", 1)]
    assert [g["last"] for g in groups] == [2, 4, 5]


def test_a_single_section_batch_is_its_own_group():
    groups = render.cohort_groups(["71-A"])
    assert groups == [{"batch": "71", "cohorts": ["71-A"],
                       "first": 0, "last": 0}]


# ── Test E/F: session counts and shared offerings, on new batch numbers ──

def test_a_three_session_course_still_gets_three_days():
    ds, cfg, res = shape({"70": ["A"]},
                         courses=(("CSE-4116", "T1"),))
    # 28 classes / 14 weeks = 2 by default; override to the 38-class case
    rows = [make_row(batch="70", section="A", code="CSE-4116",
                     teacher="T1", classes=38)]
    cfg = solver.load_config(override=make_config(teachers=["T1"]))
    ds = ingest.ingest_bytes(build_workbook(rows),
                             weeks_in_term=cfg["weeks_in_term"])
    res = solver.solve(ds, cfg, time_limit_s=FAST)
    days = [r["day"] for r in res["rows"]]
    assert len(days) == 3 and len(set(days)) == 3


def test_a_split_offering_on_a_new_batch_is_still_one_offering():
    rows = [make_row(batch="70", section="A", code="CSE-2111",
                     teacher="T1", classes=14),
            make_row(batch="70", section="A", code="CSE-2111",
                     teacher="T2", classes=14)]
    cfg = solver.load_config(override=make_config(teachers=["T1", "T2"]))
    ds = ingest.ingest_bytes(build_workbook(rows),
                             weeks_in_term=cfg["weeks_in_term"])
    res = solver.solve(ds, cfg, time_limit_s=FAST)
    assert len(res["rows"]) == 2
    assert res["validation"]["over_scheduled"] == 0


# ── Tests G/H: cross-department teaching is one person's calendar ────────

def test_one_teacher_taking_a_cse_and_a_ged_course_is_never_double_booked():
    """Test G. The teacher's home department is irrelevant to the clash rule:
    both classes occupy the same human being."""
    rows = [make_row(batch="70", section="A", code="CSE-1101", teacher="T1"),
            make_row(batch="70", section="B", code="GED-1201", teacher="T1")]
    cfg = solver.load_config(override=make_config(teachers=["T1"]))
    ds = ingest.ingest_bytes(build_workbook(rows),
                             weeks_in_term=cfg["weeks_in_term"])
    res = solver.solve(ds, cfg, time_limit_s=FAST)
    slots = [(r["day"], r["period"]) for r in res["rows"] + res["service_rows"]]
    assert len(slots) == len(set(slots))
    assert res["validation"]["teacher_clashes"] == 0


def test_a_service_class_holds_the_same_teacher_time_as_a_cse_class():
    """Test H. A class taught to another department's cohort is not drawn on
    the CSE grid, but it still occupies the teacher and must clash-check."""
    rows = [make_row(batch="70", section="A", code="CSE-1101", teacher="T1"),
            make_row(batch="BuA", section="GED A", code="GED-1122",
                     teacher="T1")]
    cfg = solver.load_config(override=make_config(teachers=["T1"]))
    ds = ingest.ingest_bytes(build_workbook(rows),
                             weeks_in_term=cfg["weeks_in_term"])
    res = solver.solve(ds, cfg, time_limit_s=FAST)
    assert len(res["rows"]) == 2          # only the CSE cohort is rendered
    assert len(res["service_rows"]) == 2  # but the service class exists
    slots = [(r["day"], r["period"]) for r in res["rows"] + res["service_rows"]]
    assert len(slots) == len(set(slots))
    assert res["validation"]["teacher_clashes"] == 0


def test_course_ownership_is_kept_separate_from_who_is_served():
    """A GED course taken BY a CSE batch is not a service class — it belongs on
    the CSE grid. Only the cohort decides that; `course_dept` records who owns
    the course."""
    rows = [make_row(batch="70", section="A", code="GED-1201", teacher="T1",
                     dept="GED")]
    cfg = solver.load_config(override=make_config(teachers=["T1"]))
    ds = ingest.ingest_bytes(build_workbook(rows),
                             weeks_in_term=cfg["weeks_in_term"])
    off = ds["offerings"][0]
    assert off["course_dept"] == "GED"
    assert off["is_service"] is False


# ── Tests I/J/K: the population changes between terms ────────────────────

def test_a_new_faculty_member_needs_no_code_change():
    """Test J."""
    rows = [make_row(batch="70", section="A", code="CSE-1101",
                     teacher="NEWBIE")]
    cfg = solver.load_config(override=make_config(teachers=["NEWBIE"]))
    ds = ingest.ingest_bytes(build_workbook(rows),
                             weeks_in_term=cfg["weeks_in_term"])
    res = solver.solve(ds, cfg, time_limit_s=FAST)
    assert {r["teacher_code"] for r in res["rows"]} == {"NEWBIE"}
    assert res["validation"]["ok"] is True


def test_a_teacher_absent_from_the_faculty_list_still_schedules():
    """Test I. A leaver is removed from `timetable_faculty`, but if the
    distribution still names them the routine must not silently lose the
    course — they simply have no day-offs on record."""
    rows = [make_row(batch="70", section="A", code="CSE-1101",
                     teacher="GONE")]
    cfg = solver.load_config(override=make_config(teachers=["T1"]))
    ds = ingest.ingest_bytes(build_workbook(rows),
                             weeks_in_term=cfg["weeks_in_term"])
    res = solver.solve(ds, cfg, time_limit_s=FAST)
    assert res["validation"]["missing_courses"] == 0
    assert res["validation"]["ok"] is True


def test_a_completely_different_course_list_just_works():
    """Test K."""
    courses = (("ABC-9001", "T1"), ("XYZ-1234", "T2"), ("QQQ-5555", "T3"))
    ds, cfg, res = shape({"81": ["A", "B"]}, courses=courses)
    got = {r["subject_code"] for r in res["rows"]}
    assert got == {"ABC-9001", "XYZ-1234", "QQQ-5555"}
    assert res["validation"]["ok"] is True


# ── Test L: no room ──────────────────────────────────────────────────────

def test_no_theory_room_at_all_is_a_clear_failure_not_a_silent_tba():
    rows = [make_row(batch="70", section="A", code="CSE-1101", teacher="T1")]
    cfg = solver.load_config(
        override=make_config(teachers=["T1"], n_lab=1, n_theory=0))
    ds = ingest.ingest_bytes(build_workbook(rows),
                             weeks_in_term=cfg["weeks_in_term"])
    with pytest.raises(RuntimeError) as e:
        solver.solve(ds, cfg, time_limit_s=FAST)
    # Structural, and the message must say so rather than printing INFEASIBLE.
    assert "feasible" in str(e.value).lower()
    assert "room" in str(e.value).lower()


# ── the whole shape renders ──────────────────────────────────────────────

def test_a_brand_new_batch_structure_renders_with_correct_batch_rules():
    ds, cfg, res = shape({"68": ["A"], "69": ["A", "B"],
                          "70": ["A", "B", "C"]})
    wb = openpyxl.load_workbook(
        io.BytesIO(render.render_bytes(res["rows"], ds["cohorts"], cfg)))
    ws = wb["Sunday"]
    groups = render.cohort_groups(ds["cohorts"])
    last_rows = {render.DATA_FIRST_ROW + g["last"] for g in groups}
    for i in range(len(ds["cohorts"])):
        r = render.DATA_FIRST_ROW + i
        styles = {ws.cell(r, c).border.bottom.style for c in render.GRID_COLS}
        assert styles == ({"thick"} if r in last_rows else {"thin"}), r
