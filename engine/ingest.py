"""Distribution ingest + normalization.

    Raw distribution workbook  ->  Normalized academic data  ->  Solver

This module is the ONLY place in the engine that knows a spreadsheet exists.
Everything downstream (solver, render, validation) works on the normalized
`Offering` / `Session` records produced here, so a change to the workbook's
layout can never reach the scheduling algorithm.

Two rules drive the normalization and both are departures from the older
row-per-session behaviour:

1.  The unit of academic truth is the **offering** — one (cohort, course
    code) pair — not a spreadsheet row. A course split between two teachers
    is written as two rows whose "No. Of Classes" sum to the term total; it
    is still ONE offering occupying its normal weekly slots. Treating each
    row as its own course was inflating the routine (18 offerings, 36 extra
    weekly classes, in the Summer-2025 file).

2.  The number of weekly sessions is **derived**, never assumed:

        required_sessions = ceil(total No. Of Classes / weeks_in_term)

    Verified against the published Summer-2025 routine: 28 classes -> 2/week,
    19 -> 2/week, and CSE-4116's 38 -> 3/week (Sun P1, Mon P1, Tue P4).
    The old hard-coded "every course meets twice" under-scheduled that course.

Nothing is ever dropped silently. A row that cannot become a scheduled
offering is recorded in `excluded` with a typed reason and its row number.
"""

from __future__ import annotations

import io
import math
import re
from collections import Counter, defaultdict
from dataclasses import asdict, dataclass, field

import openpyxl

SHEET = "Course Distribution"
HEADER_ROW = 5
DATA_START = 6

SERVICE_SECTION = re.compile(r"^(GED|WD|WE)", re.IGNORECASE)

#: Fallback when the workbook carries no usable session count for an offering.
DEFAULT_SESSIONS_PER_WEEK = 2
#: A single offering meeting more often than this is almost certainly a data
#: error rather than a real academic requirement; we still schedule it, but say so.
MAX_PLAUSIBLE_SESSIONS = 6

# Typed exclusion reasons. Anything not scheduled must carry one of these.
EXCLUDE_NO_CODE = "no_course_code"
EXCLUDE_NO_BATCH = "no_batch"
EXCLUDE_NO_TEACHER = "no_teacher"

EXCLUSION_DETAIL = {
    EXCLUDE_NO_CODE: "Row has no course code.",
    EXCLUDE_NO_BATCH: "Row has no batch — not a timetabled cohort offering.",
    EXCLUDE_NO_TEACHER: (
        "Row has no teacher — typically a project/thesis/internship course "
        "that is not timetabled."
    ),
}


@dataclass
class Offering:
    """One (cohort, course) requirement taken from the distribution."""

    oid: int
    code: str
    title: str
    batch: str
    section: str
    cohort: str
    credit: float | None
    #: "Conducting Department" — the department that OWNS the course. This is
    #: independent of who teaches it and of whose students take it: a CSE
    #: teacher may take a GED course, and a CSE batch takes MAT/PHY/EEE
    #: courses. Kept distinct from `is_service` for exactly that reason.
    course_dept: str | None
    #: "No. Of Students" — capacity input for room sizing. Parsed and carried;
    #: room assignment does not consult it yet.
    students: int | None
    classes_total: int | None
    required_sessions: int
    sessions_basis: str
    #: Sheet order. `teachers[0]` is the one printed in the routine cell; the
    #: rest co-teach the same slots later in the term and must stay free then.
    teachers: list[str]
    is_lab: bool
    is_service: bool
    source_rows: list[int] = field(default_factory=list)

    @property
    def teacher(self) -> str:
        return self.teachers[0]


@dataclass
class Session:
    """One weekly meeting the solver has to place."""

    sid: int
    oid: int
    code: str
    title: str
    teacher: str
    teachers: list[str]
    batch: str
    section: str
    cohort: str
    is_lab: bool
    is_service: bool
    occurrence: int


def _norm_batch(v) -> str | None:
    if v is None:
        return None
    if isinstance(v, (int, float)):
        return str(int(v))
    s = str(v).strip()
    return s or None


def _as_int(v) -> int | None:
    try:
        return int(round(float(v)))
    except (TypeError, ValueError):
        return None


def _as_float(v) -> float | None:
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


def _last_digit(code: str) -> int | None:
    m = re.search(r"(\d+)\s*$", code or "")
    return int(m.group(1)[-1]) if m else None


def _header_map(ws) -> dict[str, int]:
    out: dict[str, int] = {}
    for c in range(1, (ws.max_column or 30) + 1):
        v = ws.cell(row=HEADER_ROW, column=c).value
        if v:
            out[str(v).strip().lower()] = c
    return out


def _col(hmap: dict[str, int], *prefixes: str) -> int | None:
    """Bind a column by header TEXT, never by position, so the distribution's
    columns can be reordered or extended without breaking the parser."""
    for p in prefixes:
        for k, v in hmap.items():
            if k.startswith(p.lower()):
                return v
    return None


def derive_required_sessions(classes_total: int | None,
                             per_week_hint: int | None,
                             weeks_in_term: int) -> tuple[int, str]:
    """Weekly meetings an offering needs, and the evidence used.

    `No. Of Classes` (whole-term total) is authoritative because it is the only
    column that actually varies per course. `Class/Week` is a constant 2 in
    every row of the Summer-2025 file even for courses that demonstrably meet
    three times a week, so it is only a fallback.
    """
    if classes_total and classes_total > 0 and weeks_in_term > 0:
        return max(1, math.ceil(classes_total / weeks_in_term)), "classes_total"
    if per_week_hint and per_week_hint > 0:
        return per_week_hint, "class_per_week"
    return DEFAULT_SESSIONS_PER_WEEK, "default"


def ingest_bytes(data: bytes, weeks_in_term: int = 14) -> dict:
    return ingest_workbook(
        openpyxl.load_workbook(io.BytesIO(data), data_only=True),
        weeks_in_term=weeks_in_term)


def ingest_path(path: str, weeks_in_term: int = 14) -> dict:
    return ingest_workbook(openpyxl.load_workbook(path, data_only=True),
                           weeks_in_term=weeks_in_term)


def ingest_workbook(wb, weeks_in_term: int = 14) -> dict:
    if SHEET not in wb.sheetnames:
        raise ValueError(f'Workbook has no "{SHEET}" sheet. Got: {wb.sheetnames}')
    ws = wb[SHEET]
    h = _header_map(ws)

    cB = _col(h, "batch")
    cS = _col(h, "section")
    cCode = _col(h, "course code")
    cTitle = _col(h, "course title")
    cCredit = _col(h, "credit")
    cDept = _col(h, "conducting")
    cStud = _col(h, "no. of student", "no of student")
    cTea = _col(h, "teacher")
    cNoC = _col(h, "no. of class", "no of class")
    cDur = _col(h, "class duration")
    cWk = _col(h, "class/week", "class /week", "class per week")
    missing = [n for n, c in {"Batch": cB, "Section": cS, "Course Code": cCode,
                              "Teacher": cTea}.items() if c is None]
    if missing:
        raise ValueError(f"Could not find required column(s): {missing}. "
                         f"Headers seen: {sorted(h.keys())}")

    excluded: list[dict] = []
    warnings: list[str] = []
    # Accumulate per offering so a course split across teacher rows stays ONE
    # offering. Keyed by (cohort, course code); insertion order = sheet order.
    acc: dict[tuple[str, str], dict] = {}
    n_rows = 0

    for r in range(DATA_START, (ws.max_row or DATA_START) + 1):
        code = ws.cell(row=r, column=cCode).value
        batch = _norm_batch(ws.cell(row=r, column=cB).value)
        if not code and not batch:
            continue  # blank spacer row, not a real omission
        code = str(code).strip() if code else None
        if not code:
            excluded.append(_exclusion(r, None, batch, None, EXCLUDE_NO_CODE))
            continue
        if not batch:
            excluded.append(_exclusion(r, code, None, None, EXCLUDE_NO_BATCH))
            continue
        n_rows += 1

        section = ws.cell(row=r, column=cS).value
        section = str(section).strip() if section is not None else ""
        title = ws.cell(row=r, column=cTitle).value if cTitle else None
        title = str(title).strip() if title else code
        teacher = ws.cell(row=r, column=cTea).value
        teacher = str(teacher).strip() if teacher is not None else ""
        credit = _as_float(ws.cell(row=r, column=cCredit).value) if cCredit else None
        classes = _as_int(ws.cell(row=r, column=cNoC).value) if cNoC else None
        per_week = _as_int(ws.cell(row=r, column=cWk).value) if cWk else None
        dept = ws.cell(row=r, column=cDept).value if cDept else None
        dept = str(dept).strip() if dept else None
        students = _as_int(ws.cell(row=r, column=cStud).value) if cStud else None

        if cDur:
            dur = _as_float(ws.cell(row=r, column=cDur).value)
            if dur is not None and abs(dur - 1.5) > 1e-6:
                warnings.append(
                    f"Row {r} ({code} {batch}-{section}): Class Duration={dur} "
                    f"(every other row is 1.5).")

        if teacher == "":
            excluded.append(_exclusion(r, code, batch, section, EXCLUDE_NO_TEACHER))
            continue

        cohort = f"{batch}-{section}" if section else f"{batch}"
        key = (cohort, code)
        entry = acc.get(key)
        if entry is None:
            ld = _last_digit(code)
            entry = acc[key] = {
                "code": code, "title": title, "batch": batch, "section": section,
                "cohort": cohort, "credit": credit, "classes_total": 0,
                "has_classes": False, "per_week": per_week, "students": students,
                "dept": dept, "teachers": [], "rows": [],
                # Department convention: a course code ending in an even digit
                # is the sessional/lab half of its odd-digit theory sibling.
                "is_lab": ld is not None and ld % 2 == 0,
                # "We teach this class to ANOTHER department's students."
                # Deliberately NOT the same thing as "the course is not a CSE
                # course": the 106 GED/MAT/EEE/CHE/PHY offerings taken BY CSE
                # batches are not service and must appear on the CSE grid,
                # while the 15 offerings taught to BuA/ENG/CE/Law/THM cohorts
                # are service — they hold real teacher and room time but are
                # not drawn on it. Course ownership lives in `course_dept`.
                "is_service": (not batch.isdigit()) or bool(SERVICE_SECTION.match(section)),
            }
        else:
            if credit is not None and entry["credit"] is not None \
                    and abs(credit - entry["credit"]) > 1e-6:
                warnings.append(
                    f"{code} {cohort}: rows disagree on Credit "
                    f"({entry['credit']} vs {credit}); keeping {entry['credit']}.")

        if teacher not in entry["teachers"]:
            entry["teachers"].append(teacher)
        entry["rows"].append(r)
        if classes is not None:
            entry["classes_total"] += classes
            entry["has_classes"] = True
        if entry["credit"] is None:
            entry["credit"] = credit

    offerings: list[Offering] = []
    sessions: list[Session] = []
    cohorts: set[str] = set()
    teachers_used: set[str] = set()
    sid = 0

    for oid, ((cohort, code), e) in enumerate(acc.items()):
        total = e["classes_total"] if e["has_classes"] else None
        n, basis = derive_required_sessions(total, e["per_week"], weeks_in_term)
        if n > MAX_PLAUSIBLE_SESSIONS:
            warnings.append(
                f"{code} {cohort}: No. Of Classes={total} over {weeks_in_term} weeks "
                f"implies {n} classes/week — check the distribution.")
        if basis == "default":
            warnings.append(
                f"{code} {cohort}: no usable No. Of Classes or Class/Week; "
                f"assuming {n} classes/week.")

        off = Offering(
            oid=oid, code=code, title=e["title"], batch=e["batch"],
            section=e["section"], cohort=cohort, credit=e["credit"],
            course_dept=e["dept"], students=e["students"],
            classes_total=total, required_sessions=n, sessions_basis=basis,
            teachers=list(e["teachers"]), is_lab=e["is_lab"],
            is_service=e["is_service"], source_rows=list(e["rows"]))
        offerings.append(off)

        if len(off.teachers) > 1:
            warnings.append(
                f"{code} {cohort}: shared by {', '.join(off.teachers)} "
                f"({total} classes total) — scheduled as {n} weekly slot(s) "
                f"printed under {off.teacher}; all co-teachers are held free then.")

        teachers_used.update(off.teachers)
        if not off.is_service:
            cohorts.add(cohort)

        for occ in range(1, n + 1):
            sessions.append(Session(
                sid=sid, oid=oid, code=code, title=off.title,
                teacher=off.teacher, teachers=list(off.teachers),
                batch=off.batch, section=off.section, cohort=cohort,
                is_lab=off.is_lab, is_service=off.is_service, occurrence=occ))
            sid += 1

    warnings.extend(_credit_consistency_warnings(offerings))

    shared = [o for o in offerings if len(o.teachers) > 1]
    meta = {
        "rows": n_rows,
        "offerings": len(offerings),
        "shared_offerings": len(shared),
        "sessions": len(sessions),
        "render_sessions": sum(1 for s in sessions if not s.is_service),
        "service_sessions": sum(1 for s in sessions if s.is_service),
        "excluded": len(excluded),
        "cohorts": len(cohorts),
        "teachers": len(teachers_used),
        "weeks_in_term": weeks_in_term,
        "sessions_per_week_histogram": dict(
            sorted(Counter(o.required_sessions for o in offerings).items())),
    }
    return {
        "cohorts": _ordered_cohorts(cohorts),
        "offerings": [asdict(o) for o in offerings],
        "sessions": [asdict(s) for s in sessions],
        "teachers_used": sorted(teachers_used),
        "excluded": excluded,
        "warnings": warnings,
        "meta": meta,
        "weeks_in_term": weeks_in_term,
    }


def _exclusion(row: int, code: str | None, batch: str | None,
               section: str | None, reason: str) -> dict:
    return {"row": row, "code": code, "batch": batch, "section": section,
            "reason": reason, "detail": EXCLUSION_DETAIL[reason]}


def _credit_consistency_warnings(offerings: list[Offering]) -> list[str]:
    """Flag offerings whose class count disagrees with how the same credit
    value is treated everywhere else in the file.

    The distribution's Credit column is not currently a scheduling input, but a
    course that carries 3.0 credits while every other 3.0-credit theory course
    has twice its class count is a data error worth surfacing.
    """
    groups: dict[tuple[float | None, bool], list[Offering]] = defaultdict(list)
    for o in offerings:
        if o.credit is not None and o.classes_total:
            groups[(o.credit, o.is_lab)].append(o)

    out: list[str] = []
    for (credit, is_lab), group in sorted(groups.items(), key=lambda kv: (kv[0][0] or 0)):
        if len(group) < 3:
            continue
        modal, _ = Counter(o.classes_total for o in group).most_common(1)[0]
        kind = "lab" if is_lab else "theory"
        for o in group:
            if o.classes_total != modal:
                out.append(
                    f"{o.code} {o.cohort}: {o.classes_total} classes for a "
                    f"{credit}-credit {kind} course; the other {len(group) - 1} "
                    f"have {modal}.")
    return out


def _ordered_cohorts(cohorts: set[str]) -> list[str]:
    """Canonical render order: newest batch first, then section ascending.

    The ordering is DERIVED from the batch numbers present in this term's
    distribution — there is no notion of a current or special batch anywhere
    in it. Whatever the highest number in the file is leads, so 66/65/64
    becomes 70/69/68 with no code change when the batches roll over. A
    non-numeric batch (BuA, ENG, Law) sorts deterministically after every
    numeric one instead of being ranked against them.
    """
    def key(c: str):
        if "-" in c:
            b, s = c.split("-", 1)
        else:
            b, s = c, ""
        try:
            bnum = int(b)
        except ValueError:
            bnum = -1
        # `c` breaks ties. Every non-numeric batch collapses to bnum -1, so
        # without it two such cohorts sharing a section letter would be ordered
        # by the iteration order of the incoming SET — which Python randomises
        # per process, making the rendered row order differ between runs of the
        # same input.
        return (-bnum, s, c)
    return sorted(cohorts, key=key)


if __name__ == "__main__":
    import json
    import sys
    path = sys.argv[1] if len(sys.argv) > 1 else \
        "routine generation files/Main_Distribution_Summer25.xlsx"
    weeks = int(sys.argv[2]) if len(sys.argv) > 2 else 14
    res = ingest_path(path, weeks_in_term=weeks)
    print(json.dumps(res["meta"], indent=2))
    print("cohorts:", res["cohorts"])
    print(f"\nexcluded ({len(res['excluded'])}):")
    for e in res["excluded"]:
        print(f"  row {e['row']:<5} {e['code']} {e['batch']}-{e['section']} :: {e['reason']}")
    multi = [o for o in res["offerings"] if len(o["teachers"]) > 1]
    print(f"\nshared offerings ({len(multi)}):")
    for o in multi:
        print(f"  {o['cohort']:<8} {o['code']:<10} {'+'.join(o['teachers']):<10} "
              f"{o['classes_total']} classes -> {o['required_sessions']}/week")
    odd = [o for o in res["offerings"] if o["required_sessions"] != 2]
    print(f"\nofferings not meeting twice a week ({len(odd)}):")
    for o in odd:
        print(f"  {o['cohort']:<8} {o['code']:<10} cr={o['credit']} "
              f"{o['classes_total']} classes -> {o['required_sessions']}/week")
    print(f"\nwarnings ({len(res['warnings'])}):")
    for w in res["warnings"][:20]:
        print("  -", w)
