"""Manual, stdlib-only Storage API probe for the disposable timetable project.

Run from an interactive terminal. No CLI secrets, files, privileged keys or SQL.
Endpoints follow supabase/storage-js StorageFileApi.ts (upload/update/list/remove).
"""
from __future__ import annotations

import argparse
import base64
import getpass
import json
import sys
from urllib.error import HTTPError, URLError
from urllib.request import HTTPRedirectHandler, Request, build_opener
from uuid import uuid4

TEST_REF = "oqwvxplteqtlrhktsplj"
BUCKET = "resources"


class ProbeFailure(Exception):
    """Safe-to-share failure; never includes API response text or credentials."""


def validate_target(ref: str) -> str:
    if ref != TEST_REF:
        raise ValueError("Only the confirmed universe-timetable-test reference is allowed")
    return f"https://{TEST_REF}.supabase.co"


def jwt_claims(token: str) -> dict:
    try:
        payload = token.split(".")[1]
        data = json.loads(base64.urlsafe_b64decode(payload + "=" * (-len(payload) % 4)))
        if isinstance(data, dict):
            return data
    except (ValueError, IndexError, UnicodeError):
        pass
    raise ValueError("Invalid key/token format")


def validate_public_key(key: str) -> str:
    if key.startswith("sb_publishable_"):
        return key
    claims = jwt_claims(key)
    if claims.get("role") != "anon" or claims.get("ref", TEST_REF) != TEST_REF:
        raise ValueError("Use only this test project's publishable or legacy anon key")
    return key


def denied(status: int, body: bytes) -> bool:
    if status in (401, 403):
        return True
    if status == 400:
        try:
            return str(json.loads(body).get("statusCode")) in ("401", "403")
        except (ValueError, AttributeError):
            pass
    return False


def require_ok(status: int, body: bytes, label: str) -> bytes:
    if not 200 <= status < 300:
        raise ProbeFailure(f"{label}: HTTP {status}; response withheld to protect credentials")
    return body


def require(condition: bool, label: str) -> None:
    if not condition:
        raise ProbeFailure(label)


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None  # Never forward credentials to a redirect target.


class Api:
    def __init__(self, ref: str, key: str):
        self.url = validate_target(ref)
        self.key = validate_public_key(key)
        self.opener = build_opener(NoRedirect())

    def request(self, method, path, token=None, data=None, public=False):
        require(path.startswith("/") and "://" not in path, "Invalid API path")
        headers = {"Cache-Control": "no-cache"}
        if not public:
            headers["apikey"] = self.key
        if token:
            headers["Authorization"] = "Bearer " + token
        if isinstance(data, dict):
            data = json.dumps(data).encode()
            headers["Content-Type"] = "application/json"
        elif data is not None:
            headers["Content-Type"] = "text/plain"
            headers["x-upsert"] = "false"
        req = Request(self.url + path, data=data, headers=headers, method=method)
        try:
            with self.opener.open(req, timeout=30) as response:
                return response.status, response.read(1_048_576)
        except HTTPError as error:
            return error.code, error.read(1_048_576)
        except (URLError, TimeoutError, OSError):
            raise ProbeFailure("Network/TLS request failed; no credentials or response printed") from None

    def login(self, email, password):
        status, body = self.request("POST", "/auth/v1/token?grant_type=password",
                                    data={"email": email, "password": password})
        require_ok(status, body, "Test-user sign-in")
        try:
            data = json.loads(body)
            token = data["access_token"]
            user = data["user"]
            claims = jwt_claims(token)
            require(user["email"].lower() == email and user["role"] == "authenticated"
                    and claims.get("role") == "authenticated"
                    and claims.get("sub") == user["id"], "Unexpected test-user identity")
            return token, user["id"]
        except (KeyError, ValueError, TypeError):
            raise ProbeFailure("Invalid sign-in response; response withheld") from None

    def listing(self, token, prefix):
        status, body = self.request("POST", f"/storage/v1/object/list/{BUCKET}", token,
                                    {"prefix": prefix, "limit": 100, "offset": 0})
        require_ok(status, body, "List run-specific dummy folder")
        try:
            rows = json.loads(body)
            require(isinstance(rows, list), "Unexpected Storage list response")
            return rows
        except ValueError:
            raise ProbeFailure("Invalid Storage list response") from None

    def remove(self, token, paths):
        status, body = self.request("DELETE", f"/storage/v1/object/{BUCKET}", token,
                                    {"prefixes": paths})
        require_ok(status, body, "Delete exact run-specific dummy paths")


def run_probe(api: Api, token_a: str, token_b: str) -> None:
    prefix = "timetable-probe-" + uuid4().hex
    owned = prefix + "/user-a.txt"
    anonymous = prefix + "/anonymous.txt"
    paths = [owned, anonymous]
    original = b"Synthetic timetable Storage test. No personal data.\n"
    changed = b"Synthetic replacement by test user B.\n"
    object_url = f"/storage/v1/object/{BUCKET}/{owned}"
    # Establish ownership of this empty namespace before enabling cleanup.
    require(api.listing(token_a, prefix) == [], "Run folder unexpectedly exists")
    print(f"Dummy folder for this run only: {BUCKET}/{prefix}")
    failure = None
    try:
        # Track both attempted paths for cleanup, even if an upload times out.
        status, body = api.request("POST", object_url, token_a, original)
        require_ok(status, body, "User A dummy upload")
        status, body = api.request("GET", f"/storage/v1/object/public/{BUCKET}/{owned}", public=True)
        require_ok(status, body, "Public dummy download without key/token")
        require(body == original, "Public download content mismatch")
        print("PASS: user A upload and credential-free public download")

        status, body = api.request("POST", f"/storage/v1/object/{BUCKET}/{anonymous}", data=original)
        require(denied(status, body), "Anonymous upload did not return an authorization denial")
        status, body = api.request("PUT", object_url, data=changed)
        require(denied(status, body), "Anonymous update did not return an authorization denial")
        status, body = api.request("DELETE", f"/storage/v1/object/{BUCKET}", data={"prefixes": [owned]})
        # RLS-filtered deletes may return success with zero affected objects.
        require(denied(status, body) or 200 <= status < 300,
                "Anonymous delete returned an unrelated error")
        status, body = api.request("GET", object_url, token_a)
        require_ok(status, body, "Verify anonymous writes had no effect")
        require(body == original, "Anonymous mutation changed/deleted the dummy")
        require([row.get("name") for row in api.listing(token_a, prefix)] == ["user-a.txt"],
                "Anonymous upload unexpectedly created an object")
        print("PASS: anonymous upload/update denied; delete had no effect")

        require(any(row.get("name") == "user-a.txt" for row in api.listing(token_b, prefix)),
                "User B cannot list user A dummy under observed legacy policy")
        status, body = api.request("PUT", object_url, token_b, changed)
        require_ok(status, body, "Legacy cross-user update")
        status, body = api.request("GET", object_url, token_a)
        require_ok(status, body, "Verify cross-user update")
        require(body == changed, "Cross-user update content mismatch")
        api.remove(token_b, [owned])
        require(api.listing(token_a, prefix) == [], "Cross-user delete had no effect")
        print("OBSERVED LEGACY GAP: user B can list, replace and delete user A's dummy")
    except (ProbeFailure, KeyboardInterrupt) as error:
        failure = error
    finally:
        try:
            api.remove(token_a, paths)
            require(api.listing(token_a, prefix) == [], "Dummy cleanup not verified")
            print("PASS: exact dummy paths removed and run folder verified empty")
        except ProbeFailure:
            print(f"CLEANUP REQUIRED: test project only, Storage > {BUCKET} > {prefix}")
            failure = ProbeFailure("API cleanup incomplete; do not delete other folders")
    if failure is not None:
        if isinstance(failure, KeyboardInterrupt):
            raise ProbeFailure("Test interrupted; review cleanup result")
        raise failure
    print("PASS: stage 007 Storage API legacy baseline observed; dummy cleanup verified")


def main() -> int:
    argparse.ArgumentParser(description=__doc__).parse_args()
    if not sys.stdin.isatty():
        print("Run in an interactive terminal so credentials can be entered without echo.")
        return 1
    try:
        ref = input("Test project reference (universe-timetable-test): ").strip()
        validate_target(ref)
        key = getpass.getpass("Test project publishable/legacy anon key (hidden): ").strip()
        api = Api(ref, key)
        password_a = getpass.getpass("Password for storage-a@example.invalid (hidden): ")
        token_a, user_a = api.login("storage-a@example.invalid", password_a)
        del password_a
        password_b = getpass.getpass("Password for storage-b@example.invalid (hidden): ")
        token_b, user_b = api.login("storage-b@example.invalid", password_b)
        del password_b
        require(user_a != user_b, "Two distinct test accounts are required")
        run_probe(api, token_a, token_b)
        return 0
    except (ProbeFailure, ValueError) as error:
        print("FAIL:", str(error))
        return 1
    except (KeyboardInterrupt, EOFError):
        print("Stopped; no credentials printed. Review any cleanup message above.")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
