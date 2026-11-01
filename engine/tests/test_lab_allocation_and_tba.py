"""Tests for laboratory room category allocation (EEE -> ECL only, CSE -> non-ECL only)
and Excel routine rendering of TBA for unassigned faculty with legend on Sunday.
"""
import io
import openpyxl
import pytest

from room_policy import is_ecl_room, is_eee_course, is_cse_course, room_key
from solver import solve, load_config
from render import render_bytes, DATA_FIRST_ROW


def test_room_policy_classification():
    """Verify room and course classification with normalization and aliases."""
    # ECL room checks
    assert is_ecl_room("ECL-1")
    assert is_ecl_room("ECL-2")
    assert is_ecl_room("ECL_1")
    assert is_ecl_room("ecl-1")
    assert is_ecl_room("ECL 2")
    assert not is_ecl_room("ACL-1")
    assert not is_ecl_room("GL")
    assert not is_ecl_room("NL")
    assert not is_ecl_room("GALLERY 1")

    # With aliases
    aliases = {"LAB-ECL-A": "ECL-1", "LAB-CSE-A": "ACL-1"}
    assert is_ecl_room("LAB-ECL-A", aliases)
    assert not is_ecl_room("LAB-CSE-A", aliases)

    # Course checks
    assert is_eee_course("EEE-2122")
    assert is_eee_course("eee-2122")
    assert is_eee_course("ANY-101", dept="EEE")
    assert not is_eee_course("CSE-1102")

    assert is_cse_course("CSE-1102")
    assert is_cse_course("cse-4140")
    assert is_cse_course("ANY-101", dept="CSE")
    assert not is_cse_course("EEE-2122")


def test_lab_allocation_eee_and_cse_separation():
    """Verify solver assigns EEE labs strictly to ECL and CSE labs strictly to non-ECL."""
    dataset = {
        "sessions": [
            {
                "sid": 1, "oid": 101, "code": "EEE-2122", "title": "Electronics Lab",
                "teacher": "T1", "teachers": ["T1"], "batch": "66", "section": "A",
                "cohort": "66-A", "is_lab": True, "is_service": False, "occurrence": 1
            },
            {
                "sid": 2, "oid": 102, "code": "CSE-2112", "title": "Algorithms Lab",
                "teacher": "T2", "teachers": ["T2"], "batch": "66", "section": "B",
                "cohort": "66-B", "is_lab": True, "is_service": False, "occurrence": 1
            },
        ],
        "offerings": [
            {
                "oid": 101, "code": "EEE-2122", "title": "Electronics Lab",
                "batch": "66", "section": "A", "cohort": "66-A", "credit": 1.5,
                "course_dept": "EEE", "students": 30, "required_sessions": 1,
                "teachers": ["T1"], "is_lab": True, "is_service": False, "source_rows": [1]
            },
            {
                "oid": 102, "code": "CSE-2112", "title": "Algorithms Lab",
                "batch": "66", "section": "B", "cohort": "66-B", "credit": 1.5,
                "course_dept": "CSE", "students": 30, "required_sessions": 1,
                "teachers": ["T2"], "is_lab": True, "is_service": False, "source_rows": [2]
            },
        ],
        "cohorts": ["66-A", "66-B"],
    }

    config = {
        "days": ["Sunday", "Monday"],
        "periods": [
            {"idx": 1, "start": "09:00", "end": "10:30", "col": "D"},
            {"idx": 2, "start": "10:30", "end": "12:00", "col": "E"},
        ],
        "excluded_periods": [],
        "blocked_periods": {},
        "off_days": {"T1": set(), "T2": set()},
        "weights": {},
        "lab_rooms": ["ACL-1", "ECL-1"],
        "theory_rooms": ["GALLERY 1"],
        "names": {"T1": "Teacher One", "T2": "Teacher Two"},
        "room_metadata": {"ACL-1": {"capacity": 40}, "ECL-1": {"capacity": 40}},
        "room_aliases": {},
        "lab_adjacency": "soft",
    }

    res = solve(dataset, config, time_limit_s=10.0)
    assert res["stats"]["status"] in ("OPTIMAL", "FEASIBLE")
    validation = res["validation"]
    assert validation["ok"] is True
    assert validation["lab_room_violations"] == 0

    rows = res["rows"]
    eee_row = next(r for r in rows if r["subject_code"] == "EEE-2122")
    cse_row = next(r for r in rows if r["subject_code"] == "CSE-2112")

    # EEE lab must be in ECL-1
    assert eee_row["room"] == "ECL-1"
    # CSE lab must be in ACL-1
    assert cse_row["room"] == "ACL-1"


def test_lab_allocation_infeasible_when_ecl_missing_for_eee():
    """Verify solver raises RuntimeError / INFEASIBLE when EEE lab exists but no ECL lab is configured."""
    dataset = {
        "sessions": [
            {
                "sid": 1, "oid": 101, "code": "EEE-2122", "title": "Electronics Lab",
                "teacher": "T1", "teachers": ["T1"], "batch": "66", "section": "A",
                "cohort": "66-A", "is_lab": True, "is_service": False, "occurrence": 1
            },
        ],
        "offerings": [
            {
                "oid": 101, "code": "EEE-2122", "title": "Electronics Lab",
                "batch": "66", "section": "A", "cohort": "66-A", "credit": 1.5,
                "course_dept": "EEE", "students": 30, "required_sessions": 1,
                "teachers": ["T1"], "is_lab": True, "is_service": False, "source_rows": [1]
            },
        ],
        "cohorts": ["66-A"],
    }

    # Only CSE labs configured (no ECL)
    config = {
        "days": ["Sunday"],
        "periods": [
            {"idx": 1, "start": "09:00", "end": "10:30", "col": "D"},
        ],
        "excluded_periods": [],
        "blocked_periods": {},
        "off_days": {"T1": set(), "T2": set()},
        "weights": {},
        "lab_rooms": ["ACL-1", "ACL-2"],
        "theory_rooms": ["GALLERY 1"],
        "names": {"T1": "Teacher One"},
        "room_metadata": {},
        "room_aliases": {},
        "lab_adjacency": "soft",
    }

    with pytest.raises(RuntimeError) as exc_info:
        solve(dataset, config, time_limit_s=5.0)
    assert "No feasible" in str(exc_info.value) or "No ECL laboratory" in str(exc_info.value)


def test_lab_allocation_infeasible_when_cse_lab_missing_for_cse():
    """Verify solver raises RuntimeError / INFEASIBLE when CSE lab exists but no CSE lab is configured."""
    dataset = {
        "sessions": [
            {
                "sid": 1, "oid": 101, "code": "CSE-2112", "title": "Algorithms Lab",
                "teacher": "T1", "teachers": ["T1"], "batch": "66", "section": "A",
                "cohort": "66-A", "is_lab": True, "is_service": False, "occurrence": 1
            },
        ],
        "offerings": [
            {
                "oid": 101, "code": "CSE-2112", "title": "Algorithms Lab",
                "batch": "66", "section": "A", "cohort": "66-A", "credit": 1.5,
                "course_dept": "CSE", "students": 30, "required_sessions": 1,
                "teachers": ["T1"], "is_lab": True, "is_service": False, "source_rows": [1]
            },
        ],
        "cohorts": ["66-A"],
    }

    # Only ECL labs configured (no CSE labs)
    config = {
        "days": ["Sunday"],
        "periods": [
            {"idx": 1, "start": "09:00", "end": "10:30", "col": "D"},
        ],
        "excluded_periods": [],
        "blocked_periods": {},
        "off_days": {"T1": set(), "T2": set()},
        "weights": {},
        "lab_rooms": ["ECL-1"],
        "theory_rooms": ["GALLERY 1"],
        "names": {"T1": "Teacher One"},
        "room_metadata": {},
        "room_aliases": {},
        "lab_adjacency": "soft",
    }

    with pytest.raises(RuntimeError) as exc_info:
        solve(dataset, config, time_limit_s=5.0)
    assert "No feasible" in str(exc_info.value) or "No CSE laboratory" in str(exc_info.value)


def test_tba_rendering_and_legend():
    """Verify that unassigned faculty renders as TBA (not FACULTY-PENDING),
    and that Sunday carries the explanatory legend below the routine."""
    config = {
        "days": ["Sunday", "Monday"],
        "periods": [
            {"idx": 1, "start": "09:00", "end": "10:30", "col": "D"},
            {"idx": 2, "start": "10:30", "end": "12:00", "col": "E"},
        ],
    }

    rows = [
        # Assigned faculty
        {
            "day": "Sunday", "period": 1, "batch": "66", "section": "A",
            "subject_code": "CSE-1101", "teacher_code": "EBH", "room": "GALLERY 1"
        },
        # Unassigned faculty (empty teacher_code)
        {
            "day": "Sunday", "period": 2, "batch": "66", "section": "A",
            "subject_code": "CSE-4140", "teacher_code": None, "room": "ACL-2"
        },
        # Unassigned faculty with FACULTY-PENDING string
        {
            "day": "Monday", "period": 1, "batch": "66", "section": "A",
            "subject_code": "CSE-3240", "teacher_code": "FACULTY-PENDING", "room": "ACL-3"
        },
    ]
    cohorts = ["66-A"]

    raw = render_bytes(rows, cohorts, config)
    wb = openpyxl.load_workbook(io.BytesIO(raw))

    # Check Sunday
    ws_sun = wb["Sunday"]
    cell_p1 = ws_sun.cell(row=DATA_FIRST_ROW, column=4).value
    cell_p2 = ws_sun.cell(row=DATA_FIRST_ROW, column=5).value

    # Assigned faculty preserved
    assert "CSE-1101 EBH GALLERY 1" in cell_p1
    # Unassigned faculty rendered as TBA (not FACULTY-PENDING)
    assert cell_p2 == "CSE-4140 TBA ACL-2"
    assert "FACULTY-PENDING" not in cell_p2

    # Check Monday
    ws_mon = wb["Monday"]
    cell_mon_p1 = ws_mon.cell(row=DATA_FIRST_ROW, column=4).value
    assert cell_mon_p1 == "CSE-3240 TBA ACL-3"
    assert "FACULTY-PENDING" not in cell_mon_p1

    # Check legend on Sunday at DATA_FIRST_ROW + 2
    legend_row = DATA_FIRST_ROW + 2
    legend_cell = ws_sun.cell(row=legend_row, column=2).value
    assert legend_cell == "TBA = To Be Announced (Faculty not yet assigned)."
    assert ws_sun.row_dimensions[legend_row].hidden is False

    # Check that Monday does NOT repeat the legend
    assert ws_mon.cell(row=legend_row, column=2).value is None
