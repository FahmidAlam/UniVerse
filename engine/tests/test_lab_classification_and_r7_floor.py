from __future__ import annotations

import sys
from pathlib import Path

TESTS_DIR = Path(__file__).resolve().parent
ENGINE_DIR = TESTS_DIR.parent
if str(ENGINE_DIR) not in sys.path:
    sys.path.insert(0, str(ENGINE_DIR))
if str(TESTS_DIR) not in sys.path:
    sys.path.insert(0, str(TESTS_DIR))

import distribution  # noqa: E402
import ingest  # noqa: E402
import solver  # noqa: E402
from test_r1_r16_solver_rules import (  # noqa: E402
    PERIODS_6_WITH_BREAK,
    _make_policy_config,
    build_workbook,
    make_row,
)


def _solve(xlsx_bytes: bytes, cfg_override: dict, time_limit_s: float = 10.0) -> dict:
    cfg = solver.load_config(override=cfg_override)
    draft = distribution.DistributionDraft.create(xlsx_bytes)
    ds = distribution.normalize(
        draft,
        weeks_in_term=cfg["weeks_in_term"],
        fixed_sessions_per_week=cfg.get("fixed_sessions_per_week"),
        committee_policy=cfg.get("committee_policy"),
        courses_catalog=cfg.get("courses_catalog") or None,
    )
    return solver.solve(ds, cfg, time_limit_s=time_limit_s, return_outcomes=True)


def test_phy_1272_conducted_by_eee_in_physics_lab_has_zero_lab_room_violations():
    xlsx = build_workbook([
        make_row(
            batch="66",
            section="A",
            code="PHY-1272",
            title="Physics Lab",
            dept="EEE",
            teacher="PH1",
            classes=28,
            credit=1.5,
        ),
        make_row(
            batch="66",
            section="A",
            code="EEE-1202",
            title="Electrical Circuits Lab",
            dept="EEE",
            teacher="EE1",
            classes=28,
            credit=1.5,
        ),
    ])
    cfg = _make_policy_config(
        periods=PERIODS_6_WITH_BREAK,
        policy_overrides={"physics_lab_course_codes": ["PHY-1272"]},
        rooms=[
            {"name": "RAB-301", "capacity": 60, "is_lab": False, "is_active": True},
            {"name": "ACL-1", "capacity": 45, "is_lab": True, "room_pool_role": "cse_lab", "is_active": True},
            {"name": "ECL-1", "capacity": 45, "is_lab": True, "room_pool_role": "ecl_lab", "is_active": True},
            {"name": "PHYSICS_LAB", "capacity": 45, "is_lab": True, "room_pool_role": "physics_lab", "is_active": True},
        ],
        teachers=[
            {"acronym": "PH1", "employment_type": "permanent", "off_days": ["Friday", "Saturday"]},
            {"acronym": "EE1", "employment_type": "permanent", "off_days": ["Friday", "Saturday"]},
        ],
    )
    res = _solve(xlsx, cfg)
    assert res["outcome"] in ("OPTIMAL", "FEASIBLE")
    val = res["validation"]
    assert val["lab_room_violations"] == 0
    assert val["unplaced_rooms"] == 0
    phy_rows = [r for r in res["rows"] if r["subject_code"] == "PHY-1272"]
    eee_rows = [r for r in res["rows"] if r["subject_code"] == "EEE-1202"]
    assert len(phy_rows) == 2 and all(r["room"] == "PHYSICS_LAB" for r in phy_rows)
    assert len(eee_rows) == 2 and all(r["room"] == "ECL-1" for r in eee_rows)


def test_ged_theory_vs_sessional_and_phase1_general_lab_pool_prevents_tba():
    assert ingest._infer_is_lab("GED-1116", "Introduction to Management", 3.0) is False
    assert ingest._infer_is_lab("GED-2192", "Statistics", 3.0) is False
    assert ingest._infer_is_lab("GED-2122", "Computer Programming Sessional", 1.5) is True
    assert ingest._infer_is_lab("CSE-1102", "Structured Programming", 1.5) is True

    # 3 concurrent-capable labs (2 CSE + 1 GED sessional) competing for ONLY 1 general lab room
    # alongside 2 ECL rooms & 1 Physics room. Phase 1 must bound CSE+generic <= 1 so TBA == 0!
    xlsx = build_workbook([
        make_row(batch="66", section="A", code="CSE-1102", title="Programming Lab", dept="CSE", teacher="T1", classes=28, credit=1.5),
        make_row(batch="66", section="B", code="CSE-1102", title="Programming Lab", dept="CSE", teacher="T2", classes=28, credit=1.5),
        make_row(batch="66", section="C", code="GED-2122", title="Computer Programming Sessional", dept="GED", teacher="T3", classes=28, credit=1.5),
        make_row(batch="66", section="D", code="GED-1116", title="Introduction to Management", dept="BuA", teacher="T4", classes=28, credit=3.0),
    ])
    cfg = {
        "days": ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"],
        "periods": PERIODS_6_WITH_BREAK,
        "rooms": [
            {"name": "RAB-301", "capacity": 60, "is_lab": False, "is_active": True},
            {"name": "ACL-1", "capacity": 45, "is_lab": True, "is_active": True},
            {"name": "ECL-1", "capacity": 45, "is_lab": True, "is_active": True},
            {"name": "ECL-2", "capacity": 45, "is_lab": True, "is_active": True},
            {"name": "PHYSICS_LAB", "capacity": 45, "is_lab": True, "is_active": True},
        ],
        "teachers": {
            "T1": {"off_days": []},
            "T2": {"off_days": []},
            "T3": {"off_days": []},
            "T4": {"off_days": []},
        },
        "weeks_in_term": 14,
    }
    res = _solve(xlsx, cfg)
    assert res["outcome"] in ("OPTIMAL", "FEASIBLE")
    assert res["validation"]["unplaced_rooms"] == 0
    assert res["validation"]["lab_room_violations"] == 0
    ged_theory = [r for r in res["rows"] if r["subject_code"] == "GED-1116"]
    assert len(ged_theory) == 2 and all(r["room"] == "RAB-301" for r in ged_theory)


def test_legacy_baseline_mode_enforces_hybrid_r7_at_least_two_off_days():
    # Legacy Baseline Mode (no policy_snapshot, no explicit employment_type) with undeclared off_days
    xlsx = build_workbook([
        make_row(batch="66", section="A", code="CSE-1101", title="C1", dept="CSE", teacher="FBM", classes=28, credit=3.0),
        make_row(batch="66", section="B", code="CSE-1103", title="C2", dept="CSE", teacher="FBM", classes=28, credit=3.0),
        make_row(batch="66", section="C", code="CSE-1105", title="C3", dept="CSE", teacher="FBM", classes=28, credit=3.0),
        make_row(batch="66", section="D", code="CSE-1107", title="C4", dept="CSE", teacher="FBM", classes=28, credit=3.0),
        make_row(batch="66", section="E", code="CSE-1109", title="C5", dept="CSE", teacher="FBM", classes=28, credit=3.0),
        make_row(batch="66", section="F", code="CSE-1111", title="C6", dept="CSE", teacher="FBM", classes=28, credit=3.0),
    ])
    cfg = {
        "days": ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"],
        "periods": PERIODS_6_WITH_BREAK,
        "rooms": [
            {"name": "RAB-301", "capacity": 60, "is_lab": False, "is_active": True},
            {"name": "RAB-302", "capacity": 60, "is_lab": False, "is_active": True},
        ],
        "teachers": {
            "FBM": {"full_name": "Faculty FBM", "off_days": [], "is_active": True},
        },
        "weeks_in_term": 14,
    }
    res = _solve(xlsx, cfg)
    assert res["outcome"] in ("OPTIMAL", "FEASIBLE")
    fbm_days = {r["day"] for r in res["rows"] if r["teacher_code"] == "FBM"}
    assert len(fbm_days) <= 5, f"Expected <= 5 teaching days (>= 2 off-days), got {sorted(fbm_days)}"


def test_fall_2026_five_ged_cases_dynamic_classification_and_cse_lab_routing():
    import room_policy

    # 1. GED-3213 (3 cr, blank dept, "Research Methodology") -> Theory Room
    assert ingest._infer_is_lab("GED-3213", "Research Methodology", 3.0) is False
    # 2. GED-1116 (3 cr, GED, "Introduction to Management") -> Theory Room
    assert ingest._infer_is_lab("GED-1116", "Introduction to Management", 3.0) is False
    # 3. GED-1262 (1 cr, GED, "Computer Aided Engineering Drawing") -> CSE Lab
    assert ingest._infer_is_lab("GED-1262", "Computer Aided Engineering Drawing", 1.0) is True
    assert room_policy.classify_lab_kind("GED-1262", "GED") == "cse"
    # 4. GED-1122 (1.5 cr, blank dept, "Basic Computer Application") -> CSE Lab
    assert ingest._infer_is_lab("GED-1122", "Basic Computer Application", 1.5) is True
    assert room_policy.classify_lab_kind("GED-1122", None) == "cse"
    # 5. GED-2222 (1.5 cr, blank dept, "Computer Programming Sessional") -> CSE Lab
    assert ingest._infer_is_lab("GED-2222", "Computer Programming Sessional", 1.5) is True
    assert room_policy.classify_lab_kind("GED-2222", None) == "cse"

    xlsx = build_workbook([
        make_row(batch="66", section="A", code="GED-3213", title="Research Methodology", dept="", teacher="T1", classes=28, credit=3.0),
        make_row(batch="66", section="A", code="GED-1116", title="Introduction to Management", dept="GED", teacher="T2", classes=28, credit=3.0),
        make_row(batch="66", section="A", code="GED-1262", title="Computer Aided Engineering Drawing", dept="GED", teacher="T3", classes=28, credit=1.0),
        make_row(batch="66", section="A", code="GED-1122", title="Basic Computer Application", dept="", teacher="T4", classes=28, credit=1.5),
        make_row(batch="66", section="A", code="GED-2222", title="Computer Programming Sessional", dept="", teacher="T5", classes=28, credit=1.5),
    ])
    cfg = {
        "days": ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"],
        "periods": PERIODS_6_WITH_BREAK,
        "rooms": [
            {"name": "RAB-301", "capacity": 60, "is_lab": False, "is_active": True},
            {"name": "ACL-1", "capacity": 45, "is_lab": True, "room_pool_role": "cse_lab", "is_active": True},
            {"name": "ECL-1", "capacity": 45, "is_lab": True, "room_pool_role": "ecl_lab", "is_active": True},
            {"name": "PHYSICS_LAB", "capacity": 45, "is_lab": True, "room_pool_role": "physics_lab", "is_active": True},
        ],
        "teachers": {f"T{i}": {"off_days": []} for i in range(1, 6)},
        "weeks_in_term": 14,
    }
    res = _solve(xlsx, cfg)
    assert res["outcome"] in ("OPTIMAL", "FEASIBLE")
    assert res["validation"]["unplaced_rooms"] == 0
    assert res["validation"]["lab_room_violations"] == 0

    by_code: dict[str, list[dict]] = {}
    for row in res["rows"]:
        by_code.setdefault(row["subject_code"], []).append(row)

    for code in ("GED-3213", "GED-1116"):
        assert len(by_code[code]) == 2
        assert all(r["room"] == "RAB-301" and r["is_lab"] is False for r in by_code[code])
    for code in ("GED-1262", "GED-1122", "GED-2222"):
        assert len(by_code[code]) == 2
        assert all(r["room"] == "ACL-1" and r["is_lab"] is True for r in by_code[code])


def test_explicit_catalog_override_flips_course_between_all_four_room_pools():
    xlsx = build_workbook([
        make_row(batch="66", section="A", code="GED-1122", title="Basic Computer Application", dept="", teacher="T1", classes=28, credit=1.5),
    ])
    base_rooms = [
        {"name": "RAB-301", "capacity": 60, "is_lab": False, "is_active": True},
        {"name": "ACL-1", "capacity": 45, "is_lab": True, "room_pool_role": "cse_lab", "is_active": True},
        {"name": "ECL-1", "capacity": 45, "is_lab": True, "room_pool_role": "ecl_lab", "is_active": True},
        {"name": "PHYSICS_LAB", "capacity": 45, "is_lab": True, "room_pool_role": "physics_lab", "is_active": True},
    ]

    cases = [
        ("theory", "theory", False, "RAB-301"),
        ("cse_lab", "lab", False, "ACL-1"),
        ("ecl_lab", "lab", False, "ECL-1"),
        ("physics_lab", "lab", True, "PHYSICS_LAB"),
    ]
    for pool, class_type, is_phy, expected_room in cases:
        cfg = {
            "days": ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"],
            "periods": PERIODS_6_WITH_BREAK,
            "rooms": base_rooms,
            "teachers": {"T1": {"off_days": []}},
            "courses": [
                {
                    "code": "GED-1122",
                    "title": "Basic Computer Application",
                    "dept_code": "GED",
                    "credit": 1.5,
                    "class_type": class_type,
                    "is_physics_lab": is_phy,
                    "is_active": True,
                    "notes": f"[pool:{pool}]",
                }
            ],
            "weeks_in_term": 14,
        }
        res = _solve(xlsx, cfg)
        assert res["outcome"] in ("OPTIMAL", "FEASIBLE")
        assert res["validation"]["unplaced_rooms"] == 0
        assert res["validation"]["lab_room_violations"] == 0
        rows = [r for r in res["rows"] if r["subject_code"] == "GED-1122"]
        assert len(rows) == 2
        assert all(r["room"] == expected_room for r in rows), f"pool={pool} expected {expected_room}, got {rows}"
