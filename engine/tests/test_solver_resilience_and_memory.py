from __future__ import annotations

import datetime as dt
import importlib
import sys
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

import auth  # noqa: E402
import job_store  # noqa: E402
import main  # noqa: E402
import solver  # noqa: E402


def test_solver_runtime_config_defaults_and_env_bounds(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.delenv("SOLVER_NUM_WORKERS", raising=False)
    monkeypatch.delenv("SOLVER_WORKERS", raising=False)
    monkeypatch.delenv("SOLVER_MAX_MEMORY_MB", raising=False)
    monkeypatch.delenv("SOLVER_LINEARIZATION_LEVEL", raising=False)
    monkeypatch.setattr(solver, "SOLVER_WORKERS", 2)

    defaults = solver.get_solver_runtime_config()
    assert defaults["num_search_workers"] == 2
    assert defaults["max_memory_in_mb"] == 320
    assert defaults["linearization_level"] == 0

    monkeypatch.setenv("SOLVER_NUM_WORKERS", "99")
    monkeypatch.setenv("SOLVER_MAX_MEMORY_MB", "256")
    monkeypatch.setenv("SOLVER_LINEARIZATION_LEVEL", "5")
    clamped = solver.get_solver_runtime_config()
    assert clamped["num_search_workers"] == 8
    assert clamped["max_memory_in_mb"] == 256
    assert clamped["linearization_level"] == 2


def test_status_endpoint_is_lightweight_and_detects_orphaned_solving_jobs(
    monkeypatch: pytest.MonkeyPatch,
):
    monkeypatch.setenv("SUPABASE_URL", "https://example.supabase.co")
    monkeypatch.setenv("SUPABASE_SERVICE_ROLE_KEY", "sb_secret_test_orphan")
    monkeypatch.setenv("ENGINE_AUTH_MODE", "enforced")
    monkeypatch.setenv("STALE_JOB_TIMEOUT_S", "30")

    auth.set_token_verifier(lambda _t: auth.VerifiedCaller(user_id="admin-1", role="admin"))
    job_store.clear_memory_jobs()

    stale_ts = (dt.datetime.now(dt.timezone.utc) - dt.timedelta(seconds=90)).isoformat()
    db_rows: dict[str, dict[str, Any]] = {
        "c47b731e9166": {
            "job_id": "c47b731e9166",
            "state": "solving",
            "progress": 0.57,
            "created_at": stale_ts,
            "updated_at": stale_ts,
        }
    }
    captured_selects: list[str] = []
    captured_patches: list[dict[str, Any]] = []

    class _Resp:
        def __init__(self, status_code: int, data: Any = None):
            self.status_code = status_code
            self._data = data
            self.text = ""

        def json(self) -> Any:
            return self._data

    class _FakeClient:
        def __init__(self, *args: Any, **kwargs: Any):
            pass

        def __enter__(self) -> "_FakeClient":
            return self

        def __exit__(self, *args: Any) -> None:
            return None

        def get(self, url: str, *, params: dict[str, str] | None = None, headers: dict[str, str] | None = None):
            if "/rest/v1/solver_jobs" in url and params:
                captured_selects.append(params.get("select", ""))
                jid = params["job_id"].removeprefix("eq.")
                row = db_rows.get(jid)
                return _Resp(200, [row] if row else [])
            return _Resp(404)

        def patch(self, url: str, *, params: dict[str, str] | None = None, headers: dict[str, str] | None = None, json: Any = None):
            if "/rest/v1/solver_jobs" in url and params and isinstance(json, dict):
                jid = params["job_id"].removeprefix("eq.")
                db_rows[jid].update(json)
                captured_patches.append(dict(json))
                return _Resp(204)
            return _Resp(404)

    monkeypatch.setattr(httpx, "Client", _FakeClient)

    try:
        client = TestClient(main.app)
        resp = client.get(
            "/api/timetable/status/c47b731e9166",
            headers={"Authorization": "Bearer admin-jwt"},
        )
        assert resp.status_code == 200
        body = resp.json()
        assert body["state"] == "failed"
        assert body["termination_reason"] == "engine_restarted"
        assert "restarted mid-solve" in (body.get("error") or "").lower()

        # Status select must NOT fetch massive rows/service_rows/report columns
        assert len(captured_selects) == 1
        assert "rows" not in captured_selects[0].split(",")
        assert "service_rows" not in captured_selects[0].split(",")
        assert "report" not in captured_selects[0].split(",")

        # Orphan terminal state must be persisted back to Postgres
        assert len(captured_patches) == 1
        assert captured_patches[0]["state"] == "failed"
        assert captured_patches[0]["termination_reason"] == "engine_restarted"
    finally:
        auth.set_token_verifier(None)
        job_store.clear_memory_jobs()


def test_locally_active_job_is_never_marked_orphaned(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("STALE_JOB_TIMEOUT_S", "5")
    job_store.clear_memory_jobs()
    old_ts = (dt.datetime.now(dt.timezone.utc) - dt.timedelta(seconds=120)).isoformat()
    job_store._MEMORY_JOBS["active-1"] = {
        "job_id": "active-1",
        "state": "solving",
        "progress": 0.57,
        "created_at": old_ts,
        "updated_at": old_ts,
    }
    job_store.mark_job_active("active-1")
    try:
        st = job_store.get_job_status("active-1")
        assert st is not None
        assert st["state"] == "solving"

        job_store.touch_heartbeat("active-1")
        st2 = job_store.get_job_status("active-1")
        assert st2 is not None
        assert st2["updated_at"] != old_ts
    finally:
        job_store.mark_job_inactive("active-1")
        job_store.clear_memory_jobs()


def test_unhandled_500_preserves_cors_headers_for_allowed_origin(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("ALLOWED_ORIGINS", "https://universe-admin-exi.pages.dev")
    monkeypatch.setenv("ENGINE_AUTH_MODE", "optional")
    importlib.reload(main)

    def _boom(*args: Any, **kwargs: Any):
        raise RuntimeError("synthetic boom")

    monkeypatch.setattr(job_store, "get_job_status", _boom)
    try:
        client = TestClient(main.app, raise_server_exceptions=False)
        ok_origin = client.get(
            "/api/timetable/status/any-job",
            headers={"Origin": "https://universe-admin-exi.pages.dev"},
        )
        assert ok_origin.status_code == 500
        assert ok_origin.json() == {"detail": "Internal timetable engine error."}
        assert (
            ok_origin.headers.get("access-control-allow-origin")
            == "https://universe-admin-exi.pages.dev"
        )

        bad_origin = client.get(
            "/api/timetable/status/any-job",
            headers={"Origin": "https://evil.example.com"},
        )
        assert bad_origin.status_code == 500
        assert bad_origin.headers.get("access-control-allow-origin") is None
    finally:
        monkeypatch.delenv("ALLOWED_ORIGINS", raising=False)
        importlib.reload(main)


def test_startup_orphan_sweep_marks_preexisting_solving_jobs_failed(
    monkeypatch: pytest.MonkeyPatch,
):
    monkeypatch.setenv("SUPABASE_URL", "https://example.supabase.co")
    monkeypatch.setenv("SUPABASE_SERVICE_ROLE_KEY", "sb_secret_test_boot")
    job_store.clear_memory_jobs()

    patched: list[tuple[str, dict[str, Any]]] = []

    class _Resp:
        def __init__(self, status_code: int, data: Any = None):
            self.status_code = status_code
            self._data = data
            self.text = ""

        def json(self) -> Any:
            return self._data

    class _FakeClient:
        def __init__(self, *args: Any, **kwargs: Any):
            pass

        def __enter__(self) -> "_FakeClient":
            return self

        def __exit__(self, *args: Any) -> None:
            return None

        def get(self, url: str, *, params: dict[str, str] | None = None, headers: dict[str, str] | None = None):
            if "/rest/v1/solver_jobs" in url:
                return _Resp(200, [{"job_id": "c47b731e9166", "state": "solving"}])
            return _Resp(404)

        def patch(self, url: str, *, params: dict[str, str] | None = None, headers: dict[str, str] | None = None, json: Any = None):
            if "/rest/v1/solver_jobs" in url and params and isinstance(json, dict):
                patched.append((params["job_id"].removeprefix("eq."), dict(json)))
                return _Resp(204)
            return _Resp(404)

    monkeypatch.setattr(httpx, "Client", _FakeClient)
    try:
        count = job_store.mark_orphaned_jobs_on_startup()
        assert count == 1
        assert len(patched) == 1
        assert patched[0][0] == "c47b731e9166"
        assert patched[0][1]["state"] == "failed"
        assert patched[0][1]["termination_reason"] == "engine_restarted"
    finally:
        job_store.clear_memory_jobs()
