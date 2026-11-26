"""Unit tests for engine/auth.py 2027 Supabase key compatibility & verification cache."""

from __future__ import annotations

import sys
from pathlib import Path

import httpx
import pytest
from fastapi import HTTPException

ENGINE_DIR = Path(__file__).resolve().parents[1]
if str(ENGINE_DIR) not in sys.path:
    sys.path.insert(0, str(ENGINE_DIR))

import auth  # noqa: E402


@pytest.fixture(autouse=True)
def _clean_auth_env(monkeypatch: pytest.MonkeyPatch):
    auth.set_token_verifier(None)
    auth.clear_verification_cache()
    for key in (
        "ENGINE_AUTH_MODE",
        "SUPABASE_URL",
        "SUPABASE_ANON_KEY",
        "SUPABASE_SERVICE_ROLE_KEY",
        "SUPABASE_PUBLISHABLE_KEY",
        "SUPABASE_SECRET_KEY",
    ):
        monkeypatch.delenv(key, raising=False)
    yield
    auth.set_token_verifier(None)
    auth.clear_verification_cache()


class _RecordingClient:
    def __init__(self, responses: dict[str, tuple[int, object]], recorded: list[tuple[str, dict[str, str]]]):
        self._responses = responses
        self._recorded = recorded

    def __enter__(self):
        return self

    def __exit__(self, *args):
        return False

    def get(self, url: str, headers: dict[str, str] | None = None, params: dict[str, str] | None = None):
        hdrs = dict(headers or {})
        self._recorded.append((url, hdrs))
        for suffix, (status, payload) in self._responses.items():
            if url.endswith(suffix):
                return httpx.Response(status, json=payload)
        return httpx.Response(404, json={"error": "not found"})


def test_legacy_jwt_service_key_sends_bearer_on_profiles(monkeypatch: pytest.MonkeyPatch):
    legacy_service_jwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.payload.sig"
    monkeypatch.setenv("SUPABASE_URL", "https://example.supabase.co")
    monkeypatch.setenv("SUPABASE_SERVICE_ROLE_KEY", legacy_service_jwt)

    recorded: list[tuple[str, dict[str, str]]] = []
    responses = {
        "/auth/v1/user": (200, {"id": "admin-uuid-1"}),
        "/rest/v1/profiles": (200, [{"role": "admin"}]),
    }
    monkeypatch.setattr(httpx, "Client", lambda timeout=10.0: _RecordingClient(responses, recorded))

    caller = auth.verify_supabase_token("user-session-jwt-1")
    assert caller == auth.VerifiedCaller(user_id="admin-uuid-1", role="admin")
    assert len(recorded) == 2

    user_url, user_headers = recorded[0]
    assert user_url == "https://example.supabase.co/auth/v1/user"
    assert user_headers["apikey"] == legacy_service_jwt
    assert user_headers["Authorization"] == "Bearer user-session-jwt-1"

    profile_url, profile_headers = recorded[1]
    assert profile_url == "https://example.supabase.co/rest/v1/profiles"
    assert profile_headers["apikey"] == legacy_service_jwt
    assert profile_headers["Authorization"] == f"Bearer {legacy_service_jwt}"


def test_2027_opaque_sb_secret_key_omits_bearer_on_profiles(monkeypatch: pytest.MonkeyPatch):
    opaque_secret = "sb_secret_prod_opaque_token_2027"
    monkeypatch.setenv("SUPABASE_URL", "https://example.supabase.co")
    monkeypatch.setenv("SUPABASE_SERVICE_ROLE_KEY", opaque_secret)

    recorded: list[tuple[str, dict[str, str]]] = []
    responses = {
        "/auth/v1/user": (200, {"id": "admin-uuid-2"}),
        "/rest/v1/profiles": (200, [{"role": "admin"}]),
    }
    monkeypatch.setattr(httpx, "Client", lambda timeout=10.0: _RecordingClient(responses, recorded))

    caller = auth.verify_supabase_token("user-session-jwt-2")
    assert caller == auth.VerifiedCaller(user_id="admin-uuid-2", role="admin")
    assert len(recorded) == 2

    # /auth/v1/user still sends apikey + caller user JWT
    assert recorded[0][1]["apikey"] == opaque_secret
    assert recorded[0][1]["Authorization"] == "Bearer user-session-jwt-2"

    # /rest/v1/profiles sends apikey ONLY (no Authorization: Bearer sb_secret_...)
    profile_headers = recorded[1][1]
    assert profile_headers["apikey"] == opaque_secret
    assert "Authorization" not in profile_headers


def test_2027_sb_publishable_key_only_uses_caller_jwt_for_profiles(monkeypatch: pytest.MonkeyPatch):
    opaque_pub = "sb_publishable_prod_opaque_2027"
    monkeypatch.setenv("SUPABASE_URL", "https://example.supabase.co")
    monkeypatch.setenv("SUPABASE_ANON_KEY", opaque_pub)

    recorded: list[tuple[str, dict[str, str]]] = []
    responses = {
        "/auth/v1/user": (200, {"id": "admin-uuid-3"}),
        "/rest/v1/profiles": (200, [{"role": "admin"}]),
    }
    monkeypatch.setattr(httpx, "Client", lambda timeout=10.0: _RecordingClient(responses, recorded))

    caller = auth.verify_supabase_token("user-session-jwt-3")
    assert caller == auth.VerifiedCaller(user_id="admin-uuid-3", role="admin")
    assert recorded[0][1]["apikey"] == opaque_pub
    assert recorded[0][1]["Authorization"] == "Bearer user-session-jwt-3"
    # Without a service key, PostgREST receives caller's real user JWT for RLS self-read
    assert recorded[1][1]["apikey"] == opaque_pub
    assert recorded[1][1]["Authorization"] == "Bearer user-session-jwt-3"


def test_verification_cache_avoids_duplicate_lookups_within_ttl(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("SUPABASE_URL", "https://example.supabase.co")
    monkeypatch.setenv("SUPABASE_SECRET_KEY", "sb_secret_cached_key")

    recorded: list[tuple[str, dict[str, str]]] = []
    responses = {
        "/auth/v1/user": (200, {"id": "admin-cached"}),
        "/rest/v1/profiles": (200, [{"role": "admin"}]),
    }
    monkeypatch.setattr(httpx, "Client", lambda timeout=10.0: _RecordingClient(responses, recorded))

    first = auth.verify_supabase_token("same-user-jwt")
    second = auth.verify_supabase_token("same-user-jwt")
    assert first == second
    assert len(recorded) == 2  # Only one round-trip for /user + /profiles


def test_invalid_user_token_raises_401_and_profile_error_raises_503(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("SUPABASE_URL", "https://example.supabase.co")
    monkeypatch.setenv("SUPABASE_SERVICE_ROLE_KEY", "sb_secret_key")

    recorded: list[tuple[str, dict[str, str]]] = []
    monkeypatch.setattr(
        httpx,
        "Client",
        lambda timeout=10.0: _RecordingClient({"/auth/v1/user": (401, {"error": "expired"})}, recorded),
    )
    with pytest.raises(HTTPException) as exc_401:
        auth.verify_supabase_token("expired-jwt")
    assert exc_401.value.status_code == 401

    monkeypatch.setattr(
        httpx,
        "Client",
        lambda timeout=10.0: _RecordingClient(
            {"/auth/v1/user": (200, {"id": "u1"}), "/rest/v1/profiles": (500, {"error": "db"})},
            recorded,
        ),
    )
    with pytest.raises(HTTPException) as exc_503:
        auth.verify_supabase_token("good-jwt-profile-down")
    assert exc_503.value.status_code == 503


def test_missing_credentials_fails_closed_with_503():
    with pytest.raises(HTTPException) as exc:
        auth.verify_supabase_token("any-jwt")
    assert exc.value.status_code == 503
