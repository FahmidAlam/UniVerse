"""Tests for FastAPI Phase 5A dual-client JWT verification and env-driven CORS."""

from __future__ import annotations

import importlib
import sys
from pathlib import Path

import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient

ENGINE_DIR = Path(__file__).resolve().parents[1]
if str(ENGINE_DIR) not in sys.path:
    sys.path.insert(0, str(ENGINE_DIR))

import auth  # noqa: E402
import main  # noqa: E402


@pytest.fixture(autouse=True)
def _reset_auth_state(monkeypatch: pytest.MonkeyPatch):
    auth.set_token_verifier(None)
    auth.clear_verification_cache()
    monkeypatch.delenv("ENGINE_AUTH_MODE", raising=False)
    monkeypatch.delenv("SUPABASE_URL", raising=False)
    monkeypatch.delenv("SUPABASE_ANON_KEY", raising=False)
    monkeypatch.delenv("SUPABASE_SERVICE_ROLE_KEY", raising=False)
    yield
    auth.set_token_verifier(None)
    auth.clear_verification_cache()


def test_health_is_public_without_auth(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("ENGINE_AUTH_MODE", "enforced")
    client = TestClient(main.app)
    resp = client.get("/")
    assert resp.status_code == 200
    body = resp.json()
    assert body["ok"] is True
    assert body["service"] == "universe-timetable-engine"
    assert body["auth_mode"] == "enforced"


def test_enforced_mode_rejects_missing_and_invalid_tokens(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("ENGINE_AUTH_MODE", "enforced")

    def fake_verifier(token: str) -> auth.VerifiedCaller:
        if token == "invalid-jwt":
            raise HTTPException(status_code=401, detail="Invalid or expired session token.")
        return auth.VerifiedCaller(user_id="u1", role="admin")

    auth.set_token_verifier(fake_verifier)
    main.JOBS["job-1"] = {"state": "queued", "progress": 0.0}
    try:
        client = TestClient(main.app)

        # Missing Authorization header -> 401
        r_missing = client.get("/api/timetable/status/job-1")
        assert r_missing.status_code == 401

        # Malformed Authorization header -> 401
        r_malformed = client.get(
            "/api/timetable/status/job-1",
            headers={"Authorization": "Basic abc"},
        )
        assert r_malformed.status_code == 401

        # Invalid token -> 401
        r_invalid = client.get(
            "/api/timetable/status/job-1",
            headers={"Authorization": "Bearer invalid-jwt"},
        )
        assert r_invalid.status_code == 401

        # Also check POST /api/timetable/generate rejects unauthenticated calls
        r_gen = client.post(
            "/api/timetable/generate",
            files={"file": ("dist.xlsx", b"dummy", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")},
        )
        assert r_gen.status_code == 401
    finally:
        main.JOBS.pop("job-1", None)


def test_enforced_mode_rejects_non_admin_and_allows_admin(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("ENGINE_AUTH_MODE", "enforced")

    def fake_verifier(token: str) -> auth.VerifiedCaller:
        if token == "student-jwt":
            return auth.VerifiedCaller(user_id="student-1", role="student")
        if token == "teacher-jwt":
            return auth.VerifiedCaller(user_id="teacher-1", role="teacher")
        if token == "admin-jwt":
            return auth.VerifiedCaller(user_id="admin-1", role="admin")
        raise HTTPException(status_code=401, detail="Invalid token.")

    auth.set_token_verifier(fake_verifier)
    main.JOBS["job-2"] = {"state": "queued", "progress": 0.0}
    try:
        client = TestClient(main.app)

        assert (
            client.get(
                "/api/timetable/status/job-2",
                headers={"Authorization": "Bearer student-jwt"},
            ).status_code
            == 403
        )
        assert (
            client.get(
                "/api/timetable/status/job-2",
                headers={"Authorization": "Bearer teacher-jwt"},
            ).status_code
            == 403
        )

        ok = client.get(
            "/api/timetable/status/job-2",
            headers={"Authorization": "Bearer admin-jwt"},
        )
        assert ok.status_code == 200
        assert ok.json()["job_id"] == "job-2"
    finally:
        main.JOBS.pop("job-2", None)


def test_enforced_mode_fails_closed_when_supabase_env_missing(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("ENGINE_AUTH_MODE", "enforced")
    # Default verifier with no SUPABASE_URL / keys must return 503, never 200.
    main.JOBS["job-3"] = {"state": "queued", "progress": 0.0}
    try:
        client = TestClient(main.app)
        resp = client.get(
            "/api/timetable/status/job-3",
            headers={"Authorization": "Bearer some-jwt"},
        )
        assert resp.status_code == 503
    finally:
        main.JOBS.pop("job-3", None)


def test_optional_mode_allows_missing_and_invalid_tokens_with_warnings(
    monkeypatch: pytest.MonkeyPatch, caplog: pytest.LogCaptureFixture
):
    monkeypatch.setenv("ENGINE_AUTH_MODE", "optional")

    def fake_verifier(token: str) -> auth.VerifiedCaller:
        if token == "bad-jwt":
            raise HTTPException(status_code=401, detail="Bad token.")
        return auth.VerifiedCaller(user_id="admin-1", role="admin")

    auth.set_token_verifier(fake_verifier)
    main.JOBS["job-opt"] = {"state": "queued", "progress": 0.0}
    try:
        client = TestClient(main.app)
        with caplog.at_level("WARNING"):
            r1 = client.get("/api/timetable/status/job-opt")
            r2 = client.get(
                "/api/timetable/status/job-opt",
                headers={"Authorization": "Bearer bad-jwt"},
            )
            r3 = client.get(
                "/api/timetable/status/job-opt",
                headers={"Authorization": "Bearer good-admin-jwt"},
            )
        assert r1.status_code == 200
        assert r2.status_code == 200
        assert r3.status_code == 200
        assert "optional" in caplog.text.lower()
    finally:
        main.JOBS.pop("job-opt", None)


def test_cors_preflight_allows_configured_origins_and_rejects_disallowed(
    monkeypatch: pytest.MonkeyPatch,
):
    monkeypatch.setenv(
        "ALLOWED_ORIGINS",
        "https://universe-admin-review.pages.dev, https://universe-admin.pages.dev",
    )
    importlib.reload(main)
    try:
        client = TestClient(main.app)

        allowed = client.options(
            "/api/timetable/generate",
            headers={
                "Origin": "https://universe-admin-review.pages.dev",
                "Access-Control-Request-Method": "POST",
                "Access-Control-Request-Headers": "Authorization, Content-Type",
            },
        )
        assert allowed.status_code == 200
        assert (
            allowed.headers.get("access-control-allow-origin")
            == "https://universe-admin-review.pages.dev"
        )

        disallowed = client.options(
            "/api/timetable/generate",
            headers={
                "Origin": "https://evil.example.com",
                "Access-Control-Request-Method": "POST",
            },
        )
        assert disallowed.headers.get("access-control-allow-origin") is None
    finally:
        monkeypatch.delenv("ALLOWED_ORIGINS", raising=False)
        importlib.reload(main)
