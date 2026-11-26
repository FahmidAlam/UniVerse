"""Dual-client Supabase JWT + admin-role verification for FastAPI."""

from __future__ import annotations

import hashlib
import logging
import os
import threading
import time
from dataclasses import dataclass
from typing import Callable

import httpx
from fastapi import Header, HTTPException

logger = logging.getLogger("universe.engine.auth")

DEFAULT_LOCAL_ORIGINS = [
    "http://localhost:5173",
    "http://127.0.0.1:5173",
]

_CACHE_TTL_SECONDS = 60.0
_CACHE_LOCK = threading.Lock()
_VERIFICATION_CACHE: dict[str, tuple[float, "VerifiedCaller"]] = {}


@dataclass(frozen=True)
class VerifiedCaller:
    user_id: str
    role: str


TokenVerifier = Callable[[str], VerifiedCaller]


def get_auth_mode() -> str:
    mode = os.environ.get("ENGINE_AUTH_MODE", "optional").strip().lower()
    return mode if mode in {"optional", "enforced"} else "optional"


def get_allowed_origins() -> list[str]:
    raw = os.environ.get("ALLOWED_ORIGINS", "").strip()
    if not raw:
        return list(DEFAULT_LOCAL_ORIGINS)
    origins = [origin.strip().rstrip("/") for origin in raw.split(",") if origin.strip()]
    return origins or list(DEFAULT_LOCAL_ORIGINS)


def clear_verification_cache() -> None:
    with _CACHE_LOCK:
        _VERIFICATION_CACHE.clear()


def _extract_bearer_token(authorization: str | None) -> str | None:
    if not authorization:
        return None
    parts = authorization.strip().split(" ", 1)
    if len(parts) != 2 or parts[0].lower() != "bearer":
        return None
    token = parts[1].strip()
    return token or None


def _is_opaque_supabase_key(key: str) -> bool:
    """True for Supabase 2027 opaque API keys (`sb_publishable_...`, `sb_secret_...`)."""
    return key.strip().startswith("sb_")


def _supabase_credentials() -> tuple[str, str, str] | None:
    url = os.environ.get("SUPABASE_URL", "").strip().rstrip("/")
    service_key = (
        os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()
        or os.environ.get("SUPABASE_SECRET_KEY", "").strip()
    )
    anon_key = (
        os.environ.get("SUPABASE_ANON_KEY", "").strip()
        or os.environ.get("SUPABASE_PUBLISHABLE_KEY", "").strip()
    )
    api_key = service_key or anon_key
    if not url or not api_key:
        return None
    return url, api_key, service_key


def _build_profile_headers(
    *,
    api_key: str,
    service_key: str,
    caller_token: str,
) -> dict[str, str]:
    """Construct PostgREST headers compatible with legacy JWT and 2027 `sb_` keys.

    - Always sends `apikey`.
    - When `service_key` is an opaque `sb_secret_...` key, omits `Authorization: Bearer`
      so PostgREST does not attempt to parse an opaque secret key as a JWT (`401`).
    - When `service_key` is a legacy JWT (`eyJ...`), sends `Authorization: Bearer <service_key>`.
    - When no `service_key` is configured, falls back to caller's user JWT (`Authorization: Bearer <caller_token>`).
    """
    headers: dict[str, str] = {
        "apikey": service_key or api_key,
        "Accept": "application/json",
    }
    if service_key:
        if not _is_opaque_supabase_key(service_key):
            headers["Authorization"] = f"Bearer {service_key}"
    else:
        headers["Authorization"] = f"Bearer {caller_token}"
    return headers


def verify_supabase_token(token: str) -> VerifiedCaller:
    """Verify a Supabase access token via GoTrue and check public.profiles.role."""
    cache_key = hashlib.sha256(token.encode("utf-8")).hexdigest()
    now = time.monotonic()
    with _CACHE_LOCK:
        cached = _VERIFICATION_CACHE.get(cache_key)
        if cached and cached[0] > now:
            return cached[1]

    creds = _supabase_credentials()
    if creds is None:
        raise HTTPException(
            status_code=503,
            detail="Engine auth is enforced but Supabase credentials are not configured.",
        )

    supabase_url, api_key, service_key = creds
    with httpx.Client(timeout=10.0) as client:
        user_resp = client.get(
            f"{supabase_url}/auth/v1/user",
            headers={
                "apikey": api_key,
                "Authorization": f"Bearer {token}",
            },
        )
        if user_resp.status_code != 200:
            raise HTTPException(status_code=401, detail="Invalid or expired session token.")

        user_data = user_resp.json()
        user_id = user_data.get("id") if isinstance(user_data, dict) else None
        if not user_id:
            raise HTTPException(status_code=401, detail="Invalid session user payload.")

        profile_headers = _build_profile_headers(
            api_key=api_key,
            service_key=service_key,
            caller_token=token,
        )
        profile_resp = client.get(
            f"{supabase_url}/rest/v1/profiles",
            params={"id": f"eq.{user_id}", "select": "role"},
            headers=profile_headers,
        )
        if profile_resp.status_code != 200:
            raise HTTPException(status_code=503, detail="Unable to verify caller role.")

        rows = profile_resp.json()
        role = ""
        if isinstance(rows, list) and rows and isinstance(rows[0], dict):
            role = str(rows[0].get("role") or "").strip().lower()

    caller = VerifiedCaller(user_id=str(user_id), role=role)
    with _CACHE_LOCK:
        _VERIFICATION_CACHE[cache_key] = (now + _CACHE_TTL_SECONDS, caller)
    return caller


_active_verifier: TokenVerifier = verify_supabase_token


def set_token_verifier(verifier: TokenVerifier | None) -> None:
    """Override token verifier in tests; pass None to restore default."""
    global _active_verifier
    _active_verifier = verifier or verify_supabase_token


def require_admin_caller(
    authorization: str | None = Header(default=None),
) -> VerifiedCaller | None:
    """FastAPI dependency enforcing gradual-to-strict admin JWT verification."""
    mode = get_auth_mode()
    token = _extract_bearer_token(authorization)

    if token is None:
        if mode == "enforced":
            raise HTTPException(status_code=401, detail="Missing or invalid Bearer token.")
        logger.warning("Unauthenticated /api/timetable request allowed (ENGINE_AUTH_MODE=optional)")
        return None

    try:
        caller = _active_verifier(token)
    except HTTPException as exc:
        if mode == "enforced":
            raise
        logger.warning(
            "Token verification failed in optional mode (%s): %s",
            exc.status_code,
            exc.detail,
        )
        return None

    if caller.role != "admin":
        if mode == "enforced":
            raise HTTPException(status_code=403, detail="Admin role required.")
        logger.warning(
            "Non-admin caller %s (role=%s) allowed in optional mode",
            caller.user_id,
            caller.role or "none",
        )
        return caller

    return caller
