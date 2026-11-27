"""Stage 5A (Gate C) tests: CommitteePolicySnapshot, preflight readiness, and endpoint auth."""

from __future__ import annotations

from datetime import date
import io
import sys
from pathlib import Path

import openpyxl
import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient

ENGINE_DIR = Path(__file__).resolve().parents[1]
if str(ENGINE_DIR) not in sys.path:
    sys.path.insert(0, str(ENGINE_DIR))

import auth  # noqa: E402
import domain  # noqa: E402
import main  # noqa: E402
import preflight  # noqa: E402


@pytest.fixture(autouse=True)
def _reset_auth_and_limits(monkeypatch: pytest.MonkeyPatch):
    auth.set_token_verifier(None)
    auth.clear_verification_cache()
    main.PARSE_RATE_LIMITER.reset()
    main.GENERATE_RATE_LIMITER.reset()
    monkeypatch.delenv("ENGINE_AUTH_MODE", raising=False)
    yield
    auth.set_token_verifier(None)
    auth.clear_verification_cache()
    main.PARSE_RATE_LIMITER.reset()
    main.GENERATE_RATE_LIMITER.reset()


def _minimal_xlsx_bytes() -> bytes:
    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = "Course Distribution"
    ws.append(["Batch", "Section", "Code", "Title", "Credit", "Prereq", "Dept", "Students", "Teacher", "Classes", "Duration", "PerWeek"])
    for _ in range(4):
        ws.append([])
    ws.append(["61", "A", "CSE-1101", "Structured Programming", 3.0, "", "CSE", 45, "EBH", 28, 50, 2])
    buf = io.BytesIO()
    wb.save(buf)
    return buf.getvalue()


def _valid_base_payload() -> dict:
    return {
        "policy_snapshot": domain.CommitteePolicySnapshot().to_dict(),
        "faculty": [
            {
                "acronym": "EBH",
                "employment_type": "permanent",
                "off_days": ["Friday", "Saturday"],
                "allow_three_off_days": False,
                "is_active": True,
                "dept": "CSE",
            },
            {
                "acronym": "MRH",
                "employment_type": "guest",
                "off_days": [],
                "available_slots": [{"day": "Sunday", "period_idx": 1}],
                "is_active": True,
                "dept": "Physics",
            },
        ],
        "rooms": [
            {"name": "RAB-301", "room_pool_role": "general", "is_lab": False, "is_gallery": False, "is_active": True},
            {"name": "ACL-1", "room_pool_role": "cse_lab", "is_lab": True, "is_gallery": False, "is_active": True},
            {"name": "ECL-1", "room_pool_role": "ecl_lab", "is_lab": True, "is_gallery": False, "is_active": True, "available_slots": [{"day": "Monday", "period_idx": 2}]},
            {"name": "PHY-LAB", "room_pool_role": "physics_lab", "is_lab": True, "is_gallery": False, "is_active": True, "available_slots": [{"day": "Tuesday", "period_idx": 2}]},
        ],
        "courses": [
            {"code": "PHY-1104", "title": "Physics Lab", "credit": 1.5, "class_type": "lab", "is_service": True, "is_physics_lab": True, "default_weekly_sessions": 2, "is_active": True},
        ],
        "sections": [
            {"batch": "61", "section": "A", "calendar_system": "bi_semester", "weekend_override_days": ["Saturday", "Sunday"], "is_active": True},
        ],
        "settings": {
            "periods": [
                {"idx": 1, "start": "08:50", "end": "10:05"},
                {"idx": 2, "start": "10:10", "end": "11:25"},
            ]
        },
    }


def test_committee_policy_snapshot_round_trip_and_default_false():
    snap = domain.CommitteePolicySnapshot()
    assert snap.allow_sessional_across_break is False
    assert snap.default_section_weekend == ("Friday", "Saturday")
    rebuilt = domain.CommitteePolicySnapshot.from_dict(snap.to_dict())
    assert rebuilt == snap
    assert rebuilt.policy_hash() == snap.policy_hash()
    assert len(snap.policy_hash()) == 64

    # Existing PolicySnapshot with optional committee_policy still round-trips cleanly
    carrier = domain.PolicySnapshot(
        schema_version=1,
        policy_revision_id="40000000-0000-0000-0000-000000000010",
        scope_id="40000000-0000-0000-0000-000000000008",
        term_id="40000000-0000-0000-0000-000000000009",
        resource_revision=1,
        teaching_dates=(date(2026, 10, 25),),
        committee_policy=snap,
    )
    assert domain.PolicySnapshot.from_dict(carrier.to_dict()) == carrier
    assert len(carrier.policy_hash()) == 64


def test_preflight_passes_valid_baseline_and_reports_d5_state():
    report = preflight.validate_policy_readiness(_valid_base_payload())
    assert report["ok"] is True
    assert report["allow_sessional_across_break"] is False
    assert report["summary"]["blocker_count"] == 0
    assert "R1" in report["rule_coverage"]
    assert "R12" in report["rule_coverage"]


def test_preflight_blocks_guest_empty_slots_r7_offdays_and_lab_windows():
    payload = _valid_base_payload()
    payload["faculty"][0]["off_days"] = ["Wednesday", "Thursday", "Friday"]  # 3 off-days without allow_three_off_days
    payload["faculty"][1]["available_slots"] = []  # R5 guest empty -> blocker
    payload["rooms"][2]["available_slots"] = []  # R10 ecl_lab empty -> blocker
    payload["rooms"][3]["available_slots"] = []  # R11 physics_lab empty -> blocker
    payload["sections"][0]["weekend_override_days"] = ["Friday", "Sunday"]  # R1 non-consecutive -> blocker

    report = preflight.validate_policy_readiness(payload)
    assert report["ok"] is False
    blocker_rules = {b["rule_id"] for b in report["blockers"]}
    assert {"R1", "R5", "R7", "R10", "R11"}.issubset(blocker_rules)


def test_preflight_allows_three_off_days_when_explicitly_authorized():
    payload = _valid_base_payload()
    payload["faculty"][0]["off_days"] = ["Wednesday", "Thursday", "Friday"]
    payload["faculty"][0]["allow_three_off_days"] = True
    report = preflight.validate_policy_readiness(payload)
    assert report["ok"] is True


def test_preflight_flags_cd1_pending_teacher_and_credit_mismatch():
    payload = _valid_base_payload()
    payload["courses"].append({
        "code": "CSE-1103",
        "title": "Discrete Math",
        "credit": 2.0,
        "class_type": "theory",
        "is_service": False,
        "default_weekly_sessions": 3,
        "is_active": True,
    })
    payload["offerings"] = [
        {"row": 19, "courseCode": "CSE-2202", "teacher": "Pending teacher declaration", "formulaJ": "=E19*9", "cachedJ": None},
    ]
    report = preflight.validate_policy_readiness(payload)
    assert report["ok"] is False
    blocker_ids = {b["id"] for b in report["blockers"]}
    assert "cd1-pending-teachers" in blocker_ids
    assert "cd1-uncached-formulas" in blocker_ids
    warning_ids = {w["id"] for w in report["warnings"]}
    assert "r12-r13-credit-sessions" in warning_ids


def test_validate_policy_readiness_endpoint_enforces_admin_auth(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("ENGINE_AUTH_MODE", "enforced")

    def fake_verifier(token: str) -> auth.VerifiedCaller:
        if token == "admin-jwt":
            return auth.VerifiedCaller(user_id="admin-1", role="admin")
        if token == "teacher-jwt":
            return auth.VerifiedCaller(user_id="teacher-1", role="teacher")
        raise HTTPException(status_code=401, detail="Invalid token.")

    auth.set_token_verifier(fake_verifier)
    client = TestClient(main.app)

    assert client.post("/api/timetable/validate-policy-readiness", json=_valid_base_payload()).status_code == 401
    assert (
        client.post(
            "/api/timetable/validate-policy-readiness",
            json=_valid_base_payload(),
            headers={"Authorization": "Bearer teacher-jwt"},
        ).status_code
        == 403
    )

    ok = client.post(
        "/api/timetable/validate-policy-readiness",
        json=_valid_base_payload(),
        headers={"Authorization": "Bearer admin-jwt"},
    )
    assert ok.status_code == 200
    assert ok.json()["ok"] is True


def test_generate_endpoint_validates_optional_policy_snapshot_without_breaking_legacy(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("ENGINE_AUTH_MODE", "optional")
    client = TestClient(main.app)
    xlsx = _minimal_xlsx_bytes()

    bad = client.post(
        "/api/timetable/generate",
        files={"file": ("dist.xlsx", xlsx, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")},
        data={"config": '{"policy_snapshot": {"default_section_weekend": ["Friday", "Sunday"]}}'},
    )
    assert bad.status_code == 400
    assert "policy_snapshot" in bad.json()["detail"]
