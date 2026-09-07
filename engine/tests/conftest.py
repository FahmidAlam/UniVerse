"""Shared fixtures for the timetable engine tests.

Everything here builds distribution workbooks in memory. The real
`routine generation files/*.xlsx` carry teacher PII and are gitignored, so no
test may depend on them; `test_real_distribution.py` skips itself when they
are absent.
"""

from __future__ import annotations

import io
import sys
from pathlib import Path

import openpyxl
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

HEADERS = ["Batch", "Section", "Course Code", "Course Title", "Credit",
           "Prerequisite", "Conducting Department", "No. Of Students",
           "Teacher", "No. Of Classes", "Class Duration", "Class/Week"]


def make_row(batch="66", section="A", code="CSE-1101", title=None, credit=3.0,
             teacher="AAA", classes=28, duration=1.5, per_week=2, dept=None,
             students=None):
    """One distribution row. `classes` is the WHOLE-TERM class count."""
    return {"batch": batch, "section": section, "code": code,
            "title": title or f"Course {code}", "credit": credit,
            "teacher": teacher, "classes": classes, "duration": duration,
            "per_week": per_week, "dept": dept, "students": students}


def build_workbook(rows, sheet="Course Distribution") -> bytes:
    """Render rows into a workbook shaped like the real distribution:
    banner rows 1-4, headers on row 5, data from row 6."""
    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = sheet
    ws.cell(row=1, column=1, value="LEADING UNIVERSITY\nDepartment of CSE")
    ws.cell(row=3, column=1, value="List of Offered Courses")
    for c, h in enumerate(HEADERS, start=1):
        ws.cell(row=5, column=c, value=h)
    for i, r in enumerate(rows):
        rr = 6 + i
        ws.cell(row=rr, column=1, value=r["batch"])
        ws.cell(row=rr, column=2, value=r["section"])
        ws.cell(row=rr, column=3, value=r["code"])
        ws.cell(row=rr, column=4, value=r["title"])
        ws.cell(row=rr, column=5, value=r["credit"])
        ws.cell(row=rr, column=7, value=r["dept"])
        ws.cell(row=rr, column=8, value=r["students"])
        ws.cell(row=rr, column=9, value=r["teacher"])
        ws.cell(row=rr, column=10, value=r["classes"])
        ws.cell(row=rr, column=11, value=r["duration"])
        ws.cell(row=rr, column=12, value=r["per_week"])
    buf = io.BytesIO()
    wb.save(buf)
    return buf.getvalue()


def period(idx, start, end, col):
    return {"idx": idx, "label": f"{start}-{end}", "start": start,
            "end": end, "col": col}


#: Four back-to-back periods so lab/theory adjacency is always satisfiable.
DEFAULT_PERIODS = [
    period(1, "08:50", "10:05", "D"),
    period(2, "10:05", "11:20", "E"),
    period(3, "11:20", "12:35", "F"),
    period(4, "13:10", "14:25", "H"),
]

DEFAULT_DAYS = ["Sunday", "Monday", "Tuesday", "Wednesday",
                "Thursday", "Friday", "Saturday"]


def make_config(teachers=("AAA", "BBB", "CCC"), off_days=None, periods=None,
                days=None, n_lab=3, n_theory=4, **settings):
    """DB-shaped config (rooms[]/teachers[]/settings{}) — the shape the app
    actually sends, so the tests exercise `_normalize_config` too."""
    off_days = off_days or {}
    rooms = [{"name": f"LAB-{i}", "is_lab": True, "is_gallery": False}
             for i in range(1, n_lab + 1)]
    rooms += [{"name": f"R-{100 + i}", "is_lab": False, "is_gallery": False}
              for i in range(1, n_theory + 1)]
    base = {
        "semester_label": "Test Term",
        "periods": periods if periods is not None else DEFAULT_PERIODS,
        "friday_no_p4": False,
        "weeks_in_term": 14,
        "weights": {"different_days": 8, "compactness": 3, "late_slot": 1},
    }
    base.update(settings)
    return {
        "days": days if days is not None else DEFAULT_DAYS,
        "rooms": rooms,
        "teachers": [{"acronym": t, "full_name": f"Teacher {t}",
                      "off_days": list(off_days.get(t, []))} for t in teachers],
        "settings": base,
    }


@pytest.fixture
def wb_bytes():
    return build_workbook


@pytest.fixture
def cfg():
    return make_config
