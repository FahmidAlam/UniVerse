from __future__ import annotations

import json
import sys
import time
from pathlib import Path
from typing import Any

import httpx
import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient

TESTS_DIR = Path(__file__).resolve().parent
ENGINE_DIR = TESTS_DIR.parent
if str(ENGINE_DIR) not in sys.path:
    sys.path.insert(0, str(ENGINE_DIR))
if str(TESTS_DIR) not in sys.path:
    sys.path.insert(0, str(TESTS_DIR))

import auth  # noqa: E402
import distribution  # noqa: E402
import job_store  # noqa: E402
import main  # noqa: E402
import preflight  # noqa: E402
import solver  # noqa: E402
from test_r1_r16_solver_rules import (  # noqa: E402
    PERIODS_6_WITH_BREAK,
    _make_policy_config,
    build_workbook,
    make_row,
)


def _solve_xlsx(
    xlsx_bytes: bytes,
    override_cfg: dict[str, Any],
    *,
    time_limit_s: float = 8.0,
) -> dict[str, Any]:
    cfg = solver.load_config(override=override_cfg)
    draft = distribution.DistributionDraft.create(xlsx_bytes)
    dataset = distribution.normalize(
        draft,
        weeks_in_term=cfg["weeks_in_term"],
        fixed_sessions_per_week=cfg.get("fixed_sessions_per_week"),
        committee_policy=cfg.get("committee_policy"),
        courses_catalog=cfg.get("courses_catalog") or None,
    )
    return solver.solve(
        dataset,
        cfg,
        time_limit_s=time_limit_s,
        return_outcomes=True,
    )


def test_hybrid_r7_resolves_undeclared_and_partial_permanent_off_days_and_ignores_unassigned():
    xlsx = build_workbook([
        make_row(batch="66", section="A", code="CSE-1201", teacher="AA", classes=28, credit=1.5),
        make_row(batch="66", section="A", code="CSE-1203", teacher="BB", classes=28, credit=1.5),
    ])
    cfg = _make_policy_config(
        periods=PERIODS_6_WITH_BREAK,
        policy_overrides={"auto_resolve_undeclared_off_days": True},
        teachers=[
            # 0 declared off-days (assigned) -> solver resolves 2 off-days
            {"acronym": "AA", "employment_type": "permanent", "off_days": []},
            # 1 declared off-day (assigned) -> pins Thu + solver resolves 1 more
            {"acronym": "BB", "employment_type": "permanent", "off_days": ["Thursday"]},
            # Unassigned idle permanent & guest -> must NOT raise INPUT_ERROR
            {"acronym": "IDLE_PERM", "employment_type": "permanent", "off_days": []},
            {"acronym": "IDLE_GUEST", "employment_type": "guest", "available_slots": []},
        ],
    )
    res = _solve_xlsx(xlsx, cfg)
    assert res["outcome"] in ("OPTIMAL", "FEASIBLE")

    resolved_list = res["stats"].get("resolved_faculty_off_days") or []
    by_acro = {item["acronym"]: item for item in resolved_list}
    assert "AA" in by_acro
    assert by_acro["AA"]["provenance"] == "solver_resolved"
    assert len(by_acro["AA"]["resolved_off_days"]) == 2
    assert len(by_acro["AA"]["active_teaching_days"]) <= 5

    assert "BB" in by_acro
    assert by_acro["BB"]["provenance"] == "partial_hybrid"
    assert "Thursday" in by_acro["BB"]["resolved_off_days"]
    assert len(by_acro["BB"]["resolved_off_days"]) == 2

    # Confirm zero classes actually scheduled on any resolved off-day
    for acro, meta in by_acro.items():
        off_set = set(meta["resolved_off_days"])
        for row in [*res["rows"], *res["service_rows"]]:
            teachers = set(row.get("teachers") or ([row["teacher_code"]] if row.get("teacher_code") else []))
            if acro in teachers:
                assert row["day"] not in off_set


def test_strict_r7_rejects_undeclared_when_hybrid_disabled_but_ignores_unassigned():
    xlsx = build_workbook([
        make_row(batch="66", section="A", code="CSE-1201", teacher="AA", classes=28, credit=1.5),
    ])
    strict_bad = _make_policy_config(
        periods=PERIODS_6_WITH_BREAK,
        policy_overrides={"auto_resolve_undeclared_off_days": False},
        teachers=[
            {"acronym": "AA", "employment_type": "permanent", "off_days": []},
        ],
    )
    res_bad = _solve_xlsx(xlsx, strict_bad)
    assert res_bad["outcome"] == "INPUT_ERROR"
    assert any(c.get("rule") == "R7" for c in res_bad.get("conflicts") or [])

    # Assigned permanent has 2 off-days; idle unassigned faculty has 0 off-days + guest has 0 slots -> must solve cleanly
    strict_ok = _make_policy_config(
        periods=PERIODS_6_WITH_BREAK,
        policy_overrides={"auto_resolve_undeclared_off_days": False},
        teachers=[
            {"acronym": "AA", "employment_type": "permanent", "off_days": ["Friday", "Saturday"]},
            {"acronym": "IDLE_PERM", "employment_type": "permanent", "off_days": []},
            {"acronym": "IDLE_GUEST", "employment_type": "guest", "available_slots": []},
        ],
    )
    res_ok = _solve_xlsx(xlsx, strict_ok)
    assert res_ok["outcome"] in ("OPTIMAL", "FEASIBLE")


def test_preflight_emits_hybrid_r7_warning_instead_of_blocker():
    base_rooms = [{"name": "302", "capacity": 45, "is_lab": False, "is_gallery": False, "room_pool_role": "general", "is_active": True}]
    base_offerings = [{"course_code": "CSE-1201", "teacher": "AA", "batch": "66", "section": "A", "weekly_sessions": 2}]
    base_faculty = [
        {"acronym": "AA", "name": "Prof AA", "employment_type": "permanent", "off_days": [], "is_active": True},
        {"acronym": "IDLE_G", "name": "Idle Guest", "employment_type": "guest", "available_slots": [], "is_active": True},
    ]

    hybrid_report = preflight.validate_policy_readiness({
        "policy_snapshot": {"auto_resolve_undeclared_off_days": True},
        "faculty": base_faculty,
        "rooms": base_rooms,
        "courses": [{"code": "CSE-1201", "title": "DS", "is_active": True}],
        "sections": [{"batch": "66", "section": "A", "is_active": True}],
        "offerings": base_offerings,
        "settings": {"periods": PERIODS_6_WITH_BREAK},
    })
    assert hybrid_report["ok"] is True
    assert hybrid_report["blockers"] == []
    assert any(c["rule_id"] == "R7" and c["status"] == "warning" for c in hybrid_report["checks"])

    strict_report = preflight.validate_policy_readiness({
        "policy_snapshot": {"auto_resolve_undeclared_off_days": False},
        "faculty": base_faculty,
        "rooms": base_rooms,
        "courses": [{"code": "CSE-1201", "title": "DS", "is_active": True}],
        "sections": [{"batch": "66", "section": "A", "is_active": True}],
        "offerings": base_offerings,
        "settings": {"periods": PERIODS_6_WITH_BREAK},
    })
    assert strict_report["ok"] is False
    assert any(c["rule_id"] == "R7" and c["status"] == "blocker" for c in strict_report["checks"])

    # Unauthorized 3rd off-day remains a hard blocker even in Hybrid Mode
    unauth_three = preflight.validate_policy_readiness({
        "policy_snapshot": {"auto_resolve_undeclared_off_days": True},
        "faculty": [
            {
                "acronym": "AA",
                "name": "Prof AA",
                "employment_type": "permanent",
                "off_days": ["Thu", "Fri", "Sat"],
                "allow_three_off_days": False,
                "is_active": True,
            },
        ],
        "rooms": base_rooms,
        "offerings": base_offerings,
        "settings": {"periods": PERIODS_6_WITH_BREAK},
    })
    assert unauth_three["ok"] is False
    assert any(c["rule_id"] == "R7" and c["status"] == "blocker" for c in unauth_three["checks"])


class _FakeResponse:
    def __init__(self, status_code: int, *, json_data: Any = None, content: bytes = b"", text: str = ""):
        self.status_code = status_code
        self._json_data = json_data
        self.content = content
        self.text = text

    def json(self) -> Any:
        return self._json_data


def test_durable_job_store_hydrates_after_memory_wipe_and_uses_2027_secret_headers(
    monkeypatch: pytest.MonkeyPatch,
):
    monkeypatch.setenv("SUPABASE_URL", "https://example.supabase.co")
    monkeypatch.setenv("SUPABASE_SERVICE_ROLE_KEY", "sb_secret_test_123")
    monkeypatch.setenv("ENGINE_AUTH_MODE", "enforced")

    def fake_verifier(token: str) -> auth.VerifiedCaller:
        if token == "admin-jwt":
            return auth.VerifiedCaller(user_id="admin-1", role="admin")
        raise HTTPException(status_code=401, detail="bad token")

    auth.set_token_verifier(fake_verifier)
    main.GENERATE_RATE_LIMITER.reset()
    main.PARSE_RATE_LIMITER.reset()
    job_store.clear_memory_jobs()

    db_rows: dict[str, dict[str, Any]] = {}
    storage_objects: dict[str, bytes] = {}
    captured_headers: list[dict[str, str]] = []

    class FakeHttpClient:
        def __init__(self, *args: Any, **kwargs: Any):
            pass

        def __enter__(self) -> "FakeHttpClient":
            return self

        def __exit__(self, *args: Any) -> None:
            return None

        def post(self, url: str, *, params: dict[str, str] | None = None, headers: dict[str, str] | None = None, json: Any = None, content: bytes | None = None) -> _FakeResponse:
            captured_headers.append(dict(headers or {}))
            if "/rest/v1/solver_jobs" in url and isinstance(json, dict):
                db_rows[json["job_id"]] = dict(json)
                return _FakeResponse(201, text="")
            if "/storage/v1/object/timetables/" in url and content is not None:
                key = url.split("/storage/v1/object/timetables/", 1)[1]
                storage_objects[key] = bytes(content)
                return _FakeResponse(200, text="{}")
            return _FakeResponse(404, text="not found")

        def patch(self, url: str, *, params: dict[str, str] | None = None, headers: dict[str, str] | None = None, json: Any = None) -> _FakeResponse:
            captured_headers.append(dict(headers or {}))
            if "/rest/v1/solver_jobs" in url and params and isinstance(json, dict):
                jid = params["job_id"].removeprefix("eq.")
                db_rows.setdefault(jid, {"job_id": jid}).update(json)
                return _FakeResponse(204, text="")
            return _FakeResponse(404, text="not found")

        def get(self, url: str, *, params: dict[str, str] | None = None, headers: dict[str, str] | None = None) -> _FakeResponse:
            captured_headers.append(dict(headers or {}))
            if "/rest/v1/solver_jobs" in url:
                if params and "job_id" in params:
                    jid = params["job_id"].removeprefix("eq.")
                    row = db_rows.get(jid)
                    return _FakeResponse(200, json_data=[row] if row else [])
                rows = list(db_rows.values())
                if params and "revision_id" in params:
                    rid = params["revision_id"].removeprefix("eq.")
                    rows = [r for r in rows if r.get("revision_id") == rid]
                return _FakeResponse(200, json_data=rows)
            if "/storage/v1/object/timetables/" in url:
                key = url.split("/storage/v1/object/timetables/", 1)[1]
                blob = storage_objects.get(key)
                return _FakeResponse(200, content=blob) if blob is not None else _FakeResponse(404)
            return _FakeResponse(404)

    monkeypatch.setattr(httpx, "Client", FakeHttpClient)

    try:
        client = TestClient(main.app)
        xlsx = build_workbook([
            make_row(batch="66", section="A", code="CSE-1201", teacher="AA", classes=28, credit=1.5),
        ])
        cfg = _make_policy_config(
            periods=PERIODS_6_WITH_BREAK,
            teachers=[{"acronym": "AA", "employment_type": "permanent", "off_days": []}],
        )
        submit = client.post(
            "/api/timetable/generate",
            headers={"Authorization": "Bearer admin-jwt"},
            files={"file": ("dist.xlsx", xlsx, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")},
            data={
                "config": json.dumps(cfg),
                "time_limit_s": "6",
                "revision_id": "rev-123",
                "revision_version": "4",
                "scheduling_scope_id": "scope-1",
                "policy_snapshot_id": "pol-9",
            },
        )
        assert submit.status_code == 200
        job_id = submit.json()["job_id"]

        st: dict[str, Any] = {}
        for _ in range(120):
            st = client.get(
                f"/api/timetable/status/{job_id}",
                headers={"Authorization": "Bearer admin-jwt"},
            ).json()
            if st["state"] in ("done", "failed"):
                break
            time.sleep(0.05)

        assert st["state"] == "done"
        assert st["revision_id"] == "rev-123"
        assert st["revision_version"] == 4
        assert f"solver_jobs/{job_id}.xlsx" in storage_objects

        # Simulate Render restart wiping in-memory JOBS
        job_store.clear_memory_jobs()

        st_after = client.get(
            f"/api/timetable/status/{job_id}",
            headers={"Authorization": "Bearer admin-jwt"},
        )
        assert st_after.status_code == 200
        assert st_after.json()["state"] == "done"
        assert st_after.json()["workbook_storage_path"] == f"solver_jobs/{job_id}.xlsx"

        res_after = client.get(
            f"/api/timetable/result/{job_id}",
            headers={"Authorization": "Bearer admin-jwt"},
        )
        assert res_after.status_code == 200
        res_body = res_after.json()
        assert res_body["has_workbook"] is True
        assert res_body["soft_metrics"] is not None
        assert len(res_body["rows"]) > 0

        dl_after = client.get(
            f"/api/timetable/download/{job_id}",
            headers={"Authorization": "Bearer admin-jwt"},
        )
        assert dl_after.status_code == 200
        assert dl_after.content[:2] == b"PK"

        jobs_list = client.get(
            "/api/timetable/jobs?revision_id=rev-123",
            headers={"Authorization": "Bearer admin-jwt"},
        )
        assert jobs_list.status_code == 200
        listed = jobs_list.json()["jobs"]
        assert any(j["job_id"] == job_id and j["has_workbook"] is True for j in listed)

        # Verify 2027 opaque key header discipline: apikey present, Authorization omitted
        assert len(captured_headers) > 0
        for hdr in captured_headers:
            assert hdr.get("apikey") == "sb_secret_test_123"
            assert "Authorization" not in hdr
    finally:
        auth.set_token_verifier(None)
        job_store.clear_memory_jobs()
