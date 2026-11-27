"""Comprehensive Stage 5B tests for R1-R16, D1-D6, independent validation, and FastAPI outcomes."""

from __future__ import annotations

import time
import pytest
from conftest import build_workbook, make_row, period
from fastapi import HTTPException
from fastapi.testclient import TestClient

import auth
import domain
import ingest
import main
import room_policy
import solver

WEEKDAYS = [
    "Sunday",
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
]

PERIODS_7_WITH_BREAK = [
    period(1, "08:50", "10:05", "D"),
    period(2, "10:10", "11:25", "E"),
    period(3, "11:30", "12:45", "F"),
    period(4, "12:50", "14:05", "H"),  # Break sits after P4 (25m)
    period(5, "14:30", "15:45", "I"),
    period(6, "15:50", "17:05", "J"),
    period(7, "17:10", "18:25", "K"),
]

PERIODS_6_WITH_BREAK = [
    period(1, "08:50", "10:05", "D"),
    period(2, "10:10", "11:25", "E"),
    period(3, "11:30", "12:45", "F"),  # Break sits after P3 (25m)
    period(4, "13:10", "14:25", "H"),
    period(5, "14:30", "15:45", "I"),
    period(6, "15:50", "17:05", "J"),
]


def _make_policy_config(
    *,
    teachers: list[dict],
    rooms: list[dict] | None = None,
    periods: list[dict] | None = None,
    days: list[str] | None = None,
    policy_overrides: dict | None = None,
    sections: list[dict] | None = None,
    courses: list[dict] | None = None,
    friday_no_p4: bool = True,
    allow_online_periods: bool = False,
    online_periods: list[int] | None = None,
) -> dict:
    snap = domain.CommitteePolicySnapshot().to_dict()
    if policy_overrides:
        snap.update(policy_overrides)
    default_rooms = rooms if rooms is not None else [
        {"name": "RAB-301", "is_lab": False, "is_gallery": False, "room_pool_role": "general", "capacity": 60, "is_active": True},
        {"name": "RAB-302", "is_lab": False, "is_gallery": False, "room_pool_role": "general", "capacity": 60, "is_active": True},
        {"name": "ACL-1", "is_lab": True, "is_gallery": False, "room_pool_role": "cse_lab", "capacity": 45, "is_active": True},
        {"name": "ACL-2", "is_lab": True, "is_gallery": False, "room_pool_role": "cse_lab", "capacity": 45, "is_active": True},
    ]
    return {
        "days": days or list(WEEKDAYS),
        "rooms": default_rooms,
        "teachers": teachers,
        "policy_snapshot": snap,
        **({"sections": sections} if sections is not None else {}),
        **({"courses": courses} if courses is not None else {}),
        "settings": {
            "semester_label": "Fall 2026",
            "periods": periods or PERIODS_6_WITH_BREAK,
            "weeks_in_term": 14,
            "friday_no_p4": friday_no_p4,
            "online_periods": online_periods if online_periods is not None else [8],
            "allow_online_periods": allow_online_periods,
            "weights": {"different_days": 8, "compactness": 3, "spread": 2, "late_slot": 1},
        },
    }


def _solve_policy(rows: list[dict], raw_cfg: dict, time_limit_s: float = 10.0) -> tuple[dict, dict, dict]:
    cfg = solver.load_config(override=raw_cfg)
    ds = ingest.ingest_bytes(
        build_workbook(rows),
        weeks_in_term=cfg["weeks_in_term"],
        fixed_sessions_per_week=cfg.get("fixed_sessions_per_week"),
        committee_policy=cfg.get("committee_policy"),
        courses_catalog=cfg.get("courses_catalog"),
    )
    res = solver.solve(ds, cfg, time_limit_s=time_limit_s, return_outcomes=True)
    return ds, cfg, res


def _is_consecutive_pair(d1: str, d2: str) -> bool:
    i1, i2 = WEEKDAYS.index(d1), WEEKDAYS.index(d2)
    return (i2 - i1) % 7 in (1, 6)


# ── R1 & R2 (D1): Independent Section Weekends & Batch Off-Day Fairness ─────

def test_r1_r2_independent_weekends_override_joint_and_batch_fairness():
    # Batch 60 has A (override Saturday+Sunday), B+C joint, and D.
    # T1 has off_days Friday+Saturday; T2 has off_days Sunday+Monday.
    rows = [
        make_row(batch="60", section="A", code="CSE-1101", teacher="T1", classes=28),
        make_row(batch="60", section="B+C", code="CSE-1103", teacher="T2", classes=28),
        make_row(batch="60", section="B", code="CSE-1105", teacher="T1", classes=28),
        make_row(batch="60", section="C", code="CSE-1107", teacher="T1", classes=28),
        make_row(batch="60", section="D", code="CSE-1109", teacher="T2", classes=28),
    ]
    raw = _make_policy_config(
        teachers=[
            {"acronym": "T1", "employment_type": "permanent", "off_days": ["Friday", "Saturday"]},
            {"acronym": "T2", "employment_type": "permanent", "off_days": ["Sunday", "Monday"]},
        ],
        policy_overrides={
            "section_weekend_overrides": [
                {"batch": "60", "section": "A", "weekend_days": ["Saturday", "Sunday"], "calendar_system": "bi_semester"}
            ],
            "batch_max_off_day_spread": 1,
        },
    )
    ds, cfg, res = _solve_policy(rows, raw)
    assert res["outcome"] in ("OPTIMAL", "FEASIBLE")
    assert res["validation"]["ok"] is True
    assert res["validation"]["policy_violation_count"] == 0

    sec_days: dict[str, set[str]] = {"A": set(), "B": set(), "C": set(), "D": set()}
    for r in res["rows"]:
        for m in str(r["section"]).split("+"):
            sec_days[m.strip()].add(r["day"])

    # Section A honors explicit Saturday+Sunday cyclic weekend override
    assert sec_days["A"].isdisjoint({"Saturday", "Sunday"})
    # Every section has at least one consecutive 2-day weekend
    off_counts = {}
    for sec, active in sec_days.items():
        free = [d for d in WEEKDAYS if d not in active]
        off_counts[sec] = len(free)
        assert any(a in free and b in free for a, b in zip(WEEKDAYS, WEEKDAYS[1:] + WEEKDAYS[:1]))
    # Batch max - min off-day spread <= 1
    assert max(off_counts.values()) - min(off_counts.values()) <= 1

    # Tampering validator: give section D classes on 6 days (1 off-day) vs A's 5 off-days -> caught by R1 & R2
    tampered = list(res["rows"]) + [
        {"day": d, "period": 1, "time_start": "08:50", "time_end": "10:05", "subject": "X", "subject_code": "CSE-1109",
         "teacher_code": "T2", "teachers": ["T2"], "room": "RAB-301", "batch": "60", "section": "D", "semester": 1,
         "is_active": True, "is_service": False, "is_lab": False}
        for d in ("Tuesday", "Wednesday", "Thursday", "Friday", "Saturday")
        if d not in sec_days["D"]
    ]
    v_bad = solver._validate(ds, cfg, tampered, cfg["days"], {int(p["idx"]): p for p in cfg["periods"]})
    assert v_bad["ok"] is False
    assert v_bad["policy_violations"].get("r1_section_weekend_violations", 0) >= 1 or v_bad["policy_violations"].get("r2_batch_fairness_violations", 0) >= 1


# ── R3: Section Compactness (Forbid >= 2 Consecutive Empty Slots) ───────────

def test_r3_forbids_two_slot_internal_gap_while_allowing_one_slot_and_break():
    # Force section 66-A on Sunday only (override Mon..Sat? No, only 2 classes forced on Sunday via teacher avail)
    # T1 guest only available Sunday P1 and P5 (leaving P2, P3, P4 between them = 3 empty slots!) -> INFEASIBLE
    rows_gap3 = [
        make_row(batch="66", section="A", code="CSE-1101", teacher="T1", classes=28, credit=3.0),
    ]
    raw_gap3 = _make_policy_config(
        periods=PERIODS_6_WITH_BREAK,
        teachers=[
            {
                "acronym": "T1",
                "employment_type": "guest",
                "off_days": [],
                "available_slots": [
                    {"day": "Sunday", "period_idx": 1},
                    {"day": "Sunday", "period_idx": 4},  # 2 internal empty slots (P2, P3) between P1 and P4
                ],
            }
        ],
        policy_overrides={"allow_sessional_across_break": False, "max_section_internal_gap": 1},
    )
    # T1 has 2 sessions of CSE-1101 (3.0cr theory -> must be on different days anyway, wait -> test with 2 separate 1-session courses on Sunday!)
    rows_two_courses = [
        make_row(batch="66", section="A", code="CSE-1101", teacher="T1", classes=14, credit=3.0),
        make_row(batch="66", section="A", code="CSE-1103", teacher="T2", classes=14, credit=3.0),
    ]
    raw_bad_gap = _make_policy_config(
        periods=PERIODS_6_WITH_BREAK,
        teachers=[
            {"acronym": "T1", "employment_type": "guest", "available_slots": [{"day": "Sunday", "period_idx": 1}]},
            {"acronym": "T2", "employment_type": "guest", "available_slots": [{"day": "Sunday", "period_idx": 4}]},
        ],
    )
    _, _, res_bad = _solve_policy(rows_two_courses, raw_bad_gap)
    assert res_bad["outcome"] == "INFEASIBLE"

    # Now P1 and P3 on Sunday (1 empty teachable slot P2) -> VALID!
    raw_ok_1gap = _make_policy_config(
        periods=PERIODS_6_WITH_BREAK,
        teachers=[
            {"acronym": "T1", "employment_type": "guest", "available_slots": [{"day": "Sunday", "period_idx": 1}]},
            {"acronym": "T2", "employment_type": "guest", "available_slots": [{"day": "Sunday", "period_idx": 3}]},
        ],
    )
    _, _, res_ok_1gap = _solve_policy(rows_two_courses, raw_ok_1gap)
    assert res_ok_1gap["outcome"] in ("OPTIMAL", "FEASIBLE")
    assert res_ok_1gap["validation"]["ok"] is True
    assert res_ok_1gap["validation"]["soft_metrics"]["r3_single_slot_holes"] == 1

    # P3 (11:30-12:45) and P4 (13:10-14:25) separated by the midday break have 0 empty teachable slots -> VALID!
    raw_ok_break = _make_policy_config(
        periods=PERIODS_6_WITH_BREAK,
        teachers=[
            {"acronym": "T1", "employment_type": "guest", "available_slots": [{"day": "Sunday", "period_idx": 3}]},
            {"acronym": "T2", "employment_type": "guest", "available_slots": [{"day": "Sunday", "period_idx": 4}]},
        ],
    )
    _, _, res_ok_break = _solve_policy(rows_two_courses, raw_ok_break)
    assert res_ok_break["outcome"] in ("OPTIMAL", "FEASIBLE")
    assert res_ok_break["validation"]["ok"] is True
    assert res_ok_break["validation"]["soft_metrics"]["r3_single_slot_holes"] == 0


# ── R4 & R5: CSE External Blocks & Guest Whitelist ──────────────────────────

def test_r4_r5_external_blocks_and_guest_whitelist_enforced():
    rows = [
        make_row(batch="66", section="A", code="CSE-1101", teacher="PERM1", classes=28, credit=3.0),
        make_row(batch="66", section="A", code="PHY-1101", teacher="GUEST1", classes=28, credit=3.0),
    ]
    # Guest with empty available_slots -> INPUT_ERROR (R5), never unrestricted
    raw_missing_guest = _make_policy_config(
        teachers=[
            {"acronym": "PERM1", "employment_type": "permanent", "off_days": ["Friday", "Saturday"]},
            {"acronym": "GUEST1", "employment_type": "guest", "available_slots": []},
        ],
    )
    _, _, res_err = _solve_policy(rows, raw_missing_guest)
    assert res_err["outcome"] == "INPUT_ERROR"
    assert any(c["rule"] == "R5" and c["entity_id"] == "GUEST1" and c["proven"] is True for c in res_err["conflicts"])

    # Valid guest whitelist + R4 external clock block on PERM1 Sunday morning
    raw_ok = _make_policy_config(
        teachers=[
            {
                "acronym": "PERM1",
                "employment_type": "permanent",
                "off_days": ["Friday", "Saturday"],
                "external_blocked_slots": [
                    {"day": "Sunday", "period_idx": 1},
                    {"day": "Monday", "start": "10:00", "end": "11:30"},  # overlaps P2 (10:10-11:25)
                ],
            },
            {
                "acronym": "GUEST1",
                "employment_type": "guest",
                "available_slots": [
                    {"day": "Tuesday", "period_idx": 2},
                    {"day": "Wednesday", "period_idx": 3},
                ],
            },
        ],
    )
    _, _, res_ok = _solve_policy(rows, raw_ok)
    assert res_ok["outcome"] in ("OPTIMAL", "FEASIBLE")
    assert res_ok["validation"]["ok"] is True

    perm_slots = {(r["day"], r["period"]) for r in res_ok["rows"] if r["teacher_code"] == "PERM1"}
    guest_slots = {(r["day"], r["period"]) for r in res_ok["rows"] if r["teacher_code"] == "GUEST1"}
    assert ("Sunday", 1) not in perm_slots
    assert ("Monday", 2) not in perm_slots
    assert guest_slots == {("Tuesday", 2), ("Wednesday", 3)}


# ── R6 (D4) & R7 (D3): Adjunct Distinct-Course Span & Permanent Off-Days ────

def test_r6_r7_adjunct_distinct_course_dedup_and_permanent_offdays():
    # ADJ1 teaches CSE-3101 in BOTH 60-A and 60-B (=1 distinct course) + CSE-3103 in 60-A (=2 distinct courses -> <= 2 days)
    rows = [
        make_row(batch="60", section="A", code="CSE-3101", teacher="ADJ1", classes=28, credit=3.0),
        make_row(batch="60", section="B", code="CSE-3101", teacher="ADJ1", classes=28, credit=3.0),
        make_row(batch="60", section="A", code="CSE-3103", teacher="ADJ1", classes=28, credit=3.0),
        make_row(batch="60", section="B", code="CSE-3105", teacher="PERM1", classes=14, credit=3.0),
    ]
    # First verify PERM1 with 3 off-days WITHOUT allow_three_off_days -> INPUT_ERROR (R7)
    raw_bad_r7 = _make_policy_config(
        teachers=[
            {"acronym": "ADJ1", "employment_type": "adjunct", "off_days": []},
            {"acronym": "PERM1", "employment_type": "permanent", "off_days": ["Thursday", "Friday", "Saturday"], "allow_three_off_days": False},
        ],
    )
    _, _, res_bad_r7 = _solve_policy(rows, raw_bad_r7)
    assert res_bad_r7["outcome"] == "INPUT_ERROR"
    assert any(c["rule"] == "R7" and c["entity_id"] == "PERM1" for c in res_bad_r7["conflicts"])

    # Now authorize 3 off-days on PERM1 (4 attendance days, only 1 class -> 3 empty attendance days allowed!)
    raw_ok = _make_policy_config(
        teachers=[
            {"acronym": "ADJ1", "employment_type": "adjunct", "off_days": []},
            {"acronym": "PERM1", "employment_type": "permanent", "off_days": ["Thursday", "Friday", "Saturday"], "allow_three_off_days": True},
        ],
    )
    _, _, res_ok = _solve_policy(rows, raw_ok)
    assert res_ok["outcome"] in ("OPTIMAL", "FEASIBLE")
    assert res_ok["validation"]["ok"] is True

    adj_days = {r["day"] for r in res_ok["rows"] if r["teacher_code"] == "ADJ1"}
    assert len(adj_days) <= 2
    r6_stats = res_ok["validation"]["soft_metrics"]["r6_adjunct_workload"]
    assert r6_stats[0]["teacher"] == "ADJ1"
    assert r6_stats[0]["distinct_course_count"] == 2
    assert r6_stats[0]["in_band"] is True

    perm_days = {r["day"] for r in res_ok["rows"] if r["teacher_code"] == "PERM1"}
    assert perm_days.isdisjoint({"Thursday", "Friday", "Saturday"})
    assert len(perm_days) == 1  # Empty attendance days allowed (D3)


# ── R8 & R9: Faculty Preferences & SUST Adjunct Compactness ─────────────────

def test_r8_r9_preferences_and_sust_compactness():
    # SUST1 teaches 2 single-session courses on Sunday (forced by off_days Mon..Sat except Sunday? Use guest or off_days)
    rows = [
        make_row(batch="66", section="A", code="MAT-1101", teacher="SUST1", classes=14, credit=3.0),
        make_row(batch="66", section="B", code="MAT-1103", teacher="SUST1", classes=14, credit=3.0),
        make_row(batch="66", section="C", code="CSE-1101", teacher="PERM1", classes=28, credit=3.0),
    ]
    # Check R9 hard gap <= 2: place SUST1 at P1 and P5 on Sunday (3 internal empty slots P2,P3,P4) -> INFEASIBLE
    raw_sust_bad = _make_policy_config(
        periods=PERIODS_6_WITH_BREAK,
        teachers=[
            {
                "acronym": "SUST1",
                "employment_type": "adjunct",
                "is_sust_adjunct": True,
                "off_days": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"],
                "external_blocked_slots": [
                    {"day": "Sunday", "period_idx": 2},
                    {"day": "Sunday", "period_idx": 3},
                    {"day": "Sunday", "period_idx": 4},
                    {"day": "Sunday", "period_idx": 6},
                ],
            },
            {"acronym": "PERM1", "employment_type": "permanent", "off_days": ["Friday", "Saturday"]},
        ],
    )
    _, _, res_sust_bad = _solve_policy(rows, raw_sust_bad)
    assert res_sust_bad["outcome"] == "INFEASIBLE"

    # Now allow Sunday P1, P2, P3, P4 for SUST1 and set preferred_slots for PERM1
    raw_ok = _make_policy_config(
        periods=PERIODS_6_WITH_BREAK,
        teachers=[
            {
                "acronym": "SUST1",
                "employment_type": "adjunct",
                "is_sust_adjunct": True,
                "off_days": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"],
            },
            {
                "acronym": "PERM1",
                "employment_type": "permanent",
                "off_days": ["Friday", "Saturday"],
                "preferred_slots": [
                    {"day": "Sunday", "period_idx": 1, "priority": 1},
                    {"day": "Monday", "period_idx": 1, "priority": 1},
                ],
            },
        ],
    )
    _, _, res_ok = _solve_policy(rows, raw_ok)
    assert res_ok["outcome"] in ("OPTIMAL", "FEASIBLE")
    assert res_ok["validation"]["ok"] is True
    # SUST1 prefers single half of break -> 0 split_break_days
    assert res_ok["validation"]["soft_metrics"]["r9_sust_compactness"]["split_break_days"] == 0
    # PERM1 lands in preferred slots (100% satisfaction)
    assert res_ok["validation"]["soft_metrics"]["r8_faculty_preferences"]["satisfaction_pct"] == 100.0


# ── R10 & R11: ECL Lab Windows & Physics Lab Exclusive Binding ──────────────

def test_r10_r11_ecl_and_physics_lab_exclusive_windows():
    rows = [
        make_row(batch="66", section="A", code="EEE-2102", teacher="T1", classes=28, credit=1.5, dept="EEE"),
        make_row(batch="66", section="A", code="PHY-1104", teacher="T2", classes=28, credit=1.5, dept="PHY"),
        make_row(batch="66", section="A", code="PHY-1101", teacher="T2", classes=14, credit=3.0, dept="PHY"),
    ]
    raw = _make_policy_config(
        rooms=[
            {"name": "RAB-301", "is_lab": False, "is_gallery": False, "room_pool_role": "general", "is_active": True},
            {"name": "ACL-1", "is_lab": True, "is_gallery": False, "room_pool_role": "cse_lab", "is_active": True},
            {
                "name": "ECL-1",
                "is_lab": True,
                "is_gallery": False,
                "room_pool_role": "ecl_lab",
                "is_active": True,
                "available_slots": [
                    {"day": "Tuesday", "period_idx": 2},
                    {"day": "Thursday", "period_idx": 2},
                ],
            },
            {
                "name": "PHY-LAB-1",
                "is_lab": True,
                "is_gallery": False,
                "room_pool_role": "physics_lab",
                "is_active": True,
                "available_slots": [
                    {"day": "Wednesday", "period_idx": 3},
                    {"day": "Sunday", "period_idx": 3},
                ],
            },
        ],
        teachers=[
            {"acronym": "T1", "employment_type": "permanent", "off_days": ["Friday", "Saturday"]},
            {"acronym": "T2", "employment_type": "permanent", "off_days": ["Friday", "Saturday"]},
        ],
        policy_overrides={"physics_lab_course_codes": ["PHY-1104"]},
    )
    _, _, res = _solve_policy(rows, raw)
    assert res["outcome"] in ("OPTIMAL", "FEASIBLE")
    assert res["validation"]["ok"] is True

    eee_rows = [r for r in res["rows"] if r["subject_code"] == "EEE-2102"]
    phy_lab_rows = [r for r in res["rows"] if r["subject_code"] == "PHY-1104"]
    phy_th_rows = [r for r in res["rows"] if r["subject_code"] == "PHY-1101"]

    # EEE-2102 placed strictly in ECL-1 within its 2 approved windows
    assert len(eee_rows) == 2
    assert all(r["room"] == "ECL-1" for r in eee_rows)
    assert {(r["day"], r["period"]) for r in eee_rows} == {("Tuesday", 2), ("Thursday", 2)}
    # PHY-1104 placed strictly in PHY-LAB-1 within its 2 approved windows
    assert len(phy_lab_rows) == 2
    assert all(r["room"] == "PHY-LAB-1" for r in phy_lab_rows)
    assert {(r["day"], r["period"]) for r in phy_lab_rows} == {("Wednesday", 3), ("Sunday", 3)}
    # Non-listed PHY-1101 theory uses general theory room, NEVER physics_lab
    assert all(r["room"] == "RAB-301" for r in phy_th_rows)
    assert not room_policy.is_physics_lab_course("PHY-1102", ["PHY-1104"])

    # When only 1 open window is given for a 2-session lab, solver proves INFEASIBLE (never leaks to ACL-1)
    raw["rooms"][3]["available_slots"] = [{"day": "Wednesday", "period_idx": 3}]
    _, _, res_inf = _solve_policy(rows, raw)
    assert res_inf["outcome"] == "INFEASIBLE"
    assert res_inf["proven_infeasible"] is True


# ── R12 (D5): 2-Credit Sessional & Scoped Break-Crossing Permission ─────────

def test_r12_d5_sessional_break_crossing_gate_and_same_lab_pair():
    # Force T1 to ONLY have Sunday P3, Sunday P4, and Monday P1 available!
    # P3 (11:30-12:45) and P4 (13:10-14:25) cross the midday break in PERIODS_6_WITH_BREAK.
    # For a 2.0-credit sessional (3 classes/wk):
    # - When allow_sessional_across_break=False: P3+P4 CANNOT be paired, and day_sum <= 1+day_pair forbids 2 on Sunday -> INFEASIBLE!
    # - When allow_sessional_across_break=True: P3+P4 pairs cleanly in the SAME lab room + Monday P1 -> OPTIMAL!
    rows = [
        make_row(batch="66", section="A", code="CSE-2202", teacher="T1", classes=28, credit=2.0),  # 28 classes disagrees with 2.0cr (expects 3/wk)
    ]
    guest_t1 = {
        "acronym": "T1",
        "employment_type": "guest",
        "available_slots": [
            {"day": "Sunday", "period_idx": 3},
            {"day": "Sunday", "period_idx": 4},
            {"day": "Monday", "period_idx": 1},
        ],
    }

    raw_disabled = _make_policy_config(
        periods=PERIODS_6_WITH_BREAK,
        teachers=[guest_t1],
        policy_overrides={"allow_sessional_across_break": False},
    )
    ds_dis, _, res_dis = _solve_policy(rows, raw_disabled)
    assert any("R12" in w for w in ds_dis["warnings"])
    assert res_dis["outcome"] == "INFEASIBLE"

    raw_enabled = _make_policy_config(
        periods=PERIODS_6_WITH_BREAK,
        teachers=[guest_t1],
        policy_overrides={"allow_sessional_across_break": True},
    )
    _, _, res_en = _solve_policy(rows, raw_enabled)
    assert res_en["outcome"] in ("OPTIMAL", "FEASIBLE")
    assert res_en["validation"]["ok"] is True
    assert len(res_en["rows"]) == 3
    sunday_rows = sorted((r for r in res_en["rows"] if r["day"] == "Sunday"), key=lambda r: r["period"])
    assert [r["period"] for r in sunday_rows] == [3, 4]
    assert sunday_rows[0]["room"] == sunday_rows[1]["room"]
    assert res_en["validation"]["soft_metrics"]["r12_sessional_pairs"]["paired_two_credit_labs"] == 1
    assert res_en["validation"]["soft_metrics"]["r12_sessional_pairs"]["allow_sessional_across_break"] is True


# ── R13 (D2): CSE Low-Credit Consecutive Same-Room Block & 3-Cr Spread ──────

@pytest.mark.parametrize("credit", [1.0, 1.5, 2.0])
def test_r13_d2_low_credit_cse_theory_consecutive_same_day_same_room(credit: float):
    rows = [
        make_row(batch="66", section="A", code="CSE-1201", teacher="T1", classes=28, credit=credit),
        make_row(batch="66", section="A", code="CSE-3101", teacher="T2", classes=28, credit=3.0),
    ]
    raw = _make_policy_config(
        periods=PERIODS_6_WITH_BREAK,
        teachers=[
            {"acronym": "T1", "employment_type": "permanent", "off_days": ["Friday", "Saturday"]},
            {"acronym": "T2", "employment_type": "permanent", "off_days": ["Friday", "Saturday"]},
        ],
    )
    _, _, res = _solve_policy(rows, raw)
    assert res["outcome"] in ("OPTIMAL", "FEASIBLE")
    assert res["validation"]["ok"] is True

    low_rows = sorted((r for r in res["rows"] if r["subject_code"] == "CSE-1201"), key=lambda r: r["period"])
    assert len(low_rows) == 2
    assert low_rows[0]["day"] == low_rows[1]["day"]
    assert low_rows[0]["room"] == low_rows[1]["room"]
    # Never crosses break (P3->P4 is forbidden in PERIODS_6_WITH_BREAK)
    pair = (low_rows[0]["period"], low_rows[1]["period"])
    assert pair in {(1, 2), (2, 3), (4, 5), (5, 6)}

    # 3.0-credit CSE theory spreads across 2 distinct days
    three_cr_rows = [r for r in res["rows"] if r["subject_code"] == "CSE-3101"]
    assert len({r["day"] for r in three_cr_rows}) == 2


# ── R14 & R15: Non-Digit Classroom, Active Pool, 6/7-Slot & Friday Jummah ───

def test_r14_r15_non_digit_room_6_vs_7_slots_and_friday_jummah():
    rows = [make_row(batch="66", section="A", code="CSE-1101", teacher="T1", classes=28, credit=3.0)]
    raw = _make_policy_config(
        rooms=[
            {"name": "Seminar Hall", "is_lab": False, "is_gallery": False, "room_pool_role": "general", "is_active": True},
            {"name": "RAB-999", "is_lab": False, "is_gallery": False, "room_pool_role": "general", "is_active": True},
        ],
        periods=PERIODS_7_WITH_BREAK,
        teachers=[
            {"acronym": "T1", "employment_type": "permanent", "off_days": ["Saturday", "Sunday"]},
        ],
        policy_overrides={
            "active_room_pool": ["Seminar Hall"],
            "daily_slot_count": 6,  # trims P7 from PERIODS_7_WITH_BREAK
            "friday_no_p4": True,
        },
    )
    _, cfg, res = _solve_policy(rows, raw)
    assert res["outcome"] in ("OPTIMAL", "FEASIBLE")
    assert res["validation"]["ok"] is True
    assert cfg["theory_rooms"] == ["Seminar Hall"]
    assert all(r["room"] == "Seminar Hall" for r in res["rows"])
    assert all(r["period"] <= 6 for r in res["rows"])
    assert not any(r["day"] == "Friday" and r["period"] == 4 for r in res["rows"])


# ── D6: Structured Outcomes (INFEASIBLE, TIME_LIMIT_EXHAUSTED, Zero Silent Relaxation)

def test_d6_outcomes_infeasible_timeout_and_no_silent_relaxation():
    # 1. Proven INFEASIBLE without suggesting lab_adjacency relaxation
    rows_inf = [
        make_row(batch="66", section="A", code="CSE-1101", teacher="T1", classes=28, credit=2.0),
    ]
    raw_inf = _make_policy_config(
        periods=PERIODS_6_WITH_BREAK,
        teachers=[
            {
                "acronym": "T1",
                "employment_type": "guest",
                # Only isolated non-adjacent slots on different days -> R13 consecutive block impossible
                "available_slots": [
                    {"day": "Sunday", "period_idx": 1},
                    {"day": "Monday", "period_idx": 3},
                ],
            }
        ],
    )
    _, _, res_inf = _solve_policy(rows_inf, raw_inf)
    assert res_inf["outcome"] == "INFEASIBLE"
    assert res_inf["proven_infeasible"] is True
    assert "lab_adjacency" not in res_inf["error"].lower()
    assert any(c["rule"] == "R13" and c["proven"] is True for c in res_inf["conflicts"])

    # 2. TIME_LIMIT_EXHAUSTED on a dense multi-batch model with a 1ms budget
    dense_rows = [
        make_row(batch=str(60 + b), section=s, code=f"CSE-{1101 + 2*c}", teacher=f"T{(b*3+c)%5}", classes=28, credit=3.0)
        for b in range(4)
        for s in ("A", "B", "C")
        for c in range(3)
    ]
    dense_teachers = [
        {"acronym": f"T{i}", "employment_type": "permanent", "off_days": ["Friday", "Saturday"]}
        for i in range(5)
    ]
    raw_dense = _make_policy_config(teachers=dense_teachers, periods=PERIODS_7_WITH_BREAK)
    _, _, res_timeout = _solve_policy(dense_rows, raw_dense, time_limit_s=0.001)
    assert res_timeout["outcome"] in ("TIME_LIMIT_EXHAUSTED", "OPTIMAL", "FEASIBLE")
    if res_timeout["outcome"] == "TIME_LIMIT_EXHAUSTED":
        assert res_timeout["proven_infeasible"] is False
        assert res_timeout["termination_reason"] == "time_limit_no_incumbent"


# ── Combined Multi-Rule Integration Tests ───────────────────────────────────

def test_integration_a_weekends_guest_r13_block_and_r3_compactness():
    rows = [
        make_row(batch="66", section="A", code="CSE-1201", teacher="T1", classes=28, credit=1.5),
        make_row(batch="66", section="A", code="ENG-1101", teacher="GUEST_ENG", classes=28, credit=3.0),
        make_row(batch="66", section="B", code="CSE-1201", teacher="T1", classes=28, credit=1.5),
        make_row(batch="66", section="B", code="ENG-1101", teacher="GUEST_ENG", classes=28, credit=3.0),
    ]
    raw = _make_policy_config(
        periods=PERIODS_6_WITH_BREAK,
        teachers=[
            {"acronym": "T1", "employment_type": "permanent", "off_days": ["Friday", "Saturday"]},
            {
                "acronym": "GUEST_ENG",
                "employment_type": "guest",
                "available_slots": [
                    {"day": "Sunday", "period_idx": 1},
                    {"day": "Sunday", "period_idx": 3},
                    {"day": "Monday", "period_idx": 1},
                    {"day": "Tuesday", "period_idx": 2},
                ],
            },
        ],
    )
    _, _, res = _solve_policy(rows, raw, time_limit_s=15.0)
    assert res["outcome"] in ("OPTIMAL", "FEASIBLE")
    assert res["validation"]["ok"] is True
    assert res["validation"]["policy_violation_count"] == 0


def test_integration_b_ecl_physics_2cr_sessionals_and_sust_on_7_slots():
    rows = [
        make_row(batch="65", section="A", code="EEE-2102", teacher="T1", classes=28, credit=1.5, dept="EEE"),
        make_row(batch="65", section="A", code="PHY-1104", teacher="T2", classes=28, credit=1.5, dept="PHY"),
        make_row(batch="65", section="A", code="CSE-2202", teacher="T1", classes=42, credit=2.0, dept="CSE"),
        make_row(batch="65", section="A", code="MAT-1101", teacher="SUST1", classes=28, credit=3.0, dept="MAT"),
    ]
    raw = _make_policy_config(
        periods=PERIODS_7_WITH_BREAK,
        rooms=[
            {"name": "Seminar Hall", "is_lab": False, "is_gallery": False, "room_pool_role": "general", "is_active": True},
            {"name": "ACL-1", "is_lab": True, "is_gallery": False, "room_pool_role": "cse_lab", "is_active": True},
            {
                "name": "ECL-1",
                "is_lab": True,
                "is_gallery": False,
                "room_pool_role": "ecl_lab",
                "is_active": True,
                "available_slots": [
                    {"day": "Sunday", "period_idx": 1},
                    {"day": "Monday", "period_idx": 1},
                ],
            },
            {
                "name": "PHY-LAB",
                "is_lab": True,
                "is_gallery": False,
                "room_pool_role": "physics_lab",
                "is_active": True,
                "available_slots": [
                    {"day": "Tuesday", "period_idx": 2},
                    {"day": "Wednesday", "period_idx": 2},
                ],
            },
        ],
        teachers=[
            {"acronym": "T1", "employment_type": "permanent", "off_days": ["Friday", "Saturday"]},
            {"acronym": "T2", "employment_type": "permanent", "off_days": ["Friday", "Saturday"]},
            {"acronym": "SUST1", "employment_type": "adjunct", "is_sust_adjunct": True, "off_days": ["Friday", "Saturday"]},
        ],
        policy_overrides={
            "daily_slot_count": 7,
            "physics_lab_course_codes": ["PHY-1104"],
            "allow_sessional_across_break": False,
        },
    )
    _, _, res = _solve_policy(rows, raw, time_limit_s=15.0)
    assert res["outcome"] in ("OPTIMAL", "FEASIBLE")
    assert res["validation"]["ok"] is True
    assert res["validation"]["policy_violation_count"] == 0


# ── FastAPI /api/timetable/generate -> /status -> /result D6 Contract ───────

def test_fastapi_generate_returns_structured_d6_outcomes_under_enforced_auth(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("ENGINE_AUTH_MODE", "enforced")

    def fake_verifier(token: str) -> auth.VerifiedCaller:
        if token == "admin-jwt":
            return auth.VerifiedCaller(user_id="admin-1", role="admin")
        if token == "student-jwt":
            return auth.VerifiedCaller(user_id="student-1", role="student")
        raise HTTPException(status_code=401, detail="Invalid token.")

    auth.set_token_verifier(fake_verifier)
    main.GENERATE_RATE_LIMITER.reset()
    main.PARSE_RATE_LIMITER.reset()

    try:
        client = TestClient(main.app)
        xlsx = build_workbook([
            make_row(batch="66", section="A", code="CSE-1201", teacher="G1", classes=28, credit=1.5),
        ])

        # Unauthenticated rejected -> 401
        assert client.post(
            "/api/timetable/generate",
            files={"file": ("dist.xlsx", xlsx, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")},
        ).status_code == 401

        # 1. Guest missing slots -> INPUT_ERROR surfaced cleanly via /status and /result
        bad_cfg = _make_policy_config(
            teachers=[{"acronym": "G1", "employment_type": "guest", "available_slots": []}]
        )
        import json
        resp_bad = client.post(
            "/api/timetable/generate",
            headers={"Authorization": "Bearer admin-jwt"},
            files={"file": ("dist.xlsx", xlsx, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")},
            data={"config": json.dumps(bad_cfg), "time_limit_s": "5"},
        )
        assert resp_bad.status_code == 200
        job_bad = resp_bad.json()["job_id"]

        for _ in range(40):
            st = client.get(f"/api/timetable/status/{job_bad}", headers={"Authorization": "Bearer admin-jwt"}).json()
            if st["state"] in ("done", "failed"):
                break
            time.sleep(0.05)

        assert st["state"] == "failed"
        assert st["outcome"] == "INPUT_ERROR"
        assert st["proven_infeasible"] is True
        assert any(c["rule"] == "R5" and c["suggested_route"] == "/admin/timetable/faculty" for c in st["conflicts"])

        res_bad = client.get(f"/api/timetable/result/{job_bad}", headers={"Authorization": "Bearer admin-jwt"})
        assert res_bad.status_code == 200
        assert res_bad.json()["outcome"] == "INPUT_ERROR"

        # 2. Valid guest whitelist -> OPTIMAL with soft_metrics
        ok_cfg = _make_policy_config(
            periods=PERIODS_6_WITH_BREAK,
            teachers=[
                {
                    "acronym": "G1",
                    "employment_type": "guest",
                    "available_slots": [
                        {"day": "Sunday", "period_idx": 1},
                        {"day": "Sunday", "period_idx": 2},
                    ],
                }
            ],
        )
        resp_ok = client.post(
            "/api/timetable/generate",
            headers={"Authorization": "Bearer admin-jwt"},
            files={"file": ("dist.xlsx", xlsx, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")},
            data={"config": json.dumps(ok_cfg), "time_limit_s": "5"},
        )
        assert resp_ok.status_code == 200
        job_ok = resp_ok.json()["job_id"]

        for _ in range(40):
            st_ok = client.get(f"/api/timetable/status/{job_ok}", headers={"Authorization": "Bearer admin-jwt"}).json()
            if st_ok["state"] in ("done", "failed"):
                break
            time.sleep(0.05)

        assert st_ok["state"] == "done"
        assert st_ok["outcome"] in ("OPTIMAL", "FEASIBLE")
        res_ok = client.get(f"/api/timetable/result/{job_ok}", headers={"Authorization": "Bearer admin-jwt"}).json()
        assert res_ok["validation"]["ok"] is True
        assert "soft_metrics" in res_ok["validation"]
    finally:
        auth.set_token_verifier(None)
        auth.clear_verification_cache()
        main.GENERATE_RATE_LIMITER.reset()
        main.PARSE_RATE_LIMITER.reset()
