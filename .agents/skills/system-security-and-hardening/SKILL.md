---
name: system-security-and-hardening
description: Zero-trust security, intrusion defense, RLS/Storage isolation, FastAPI JWT/CORS/rate-limiting, untrusted .xlsx parsing safety, CSP headers, and CI/secret hygiene across UniVerse (apps/web/, engine/, supabase/, lib/, .github/). Mandatory before modifying Auth, RLS, Storage, Edge Functions, FastAPI endpoints, file uploads/parsers, CSP _headers, or CI workflows. Do NOT use for pure visual styling or CP-SAT constraint math.
---

# UniVerse System Security & Hardening

Enforce defense-in-depth across browser, API gateway, database, object storage, and CI/CD so third parties, malicious payloads, or misconfigured clients cannot exfiltrate data, escalate privileges, or crash services.

## 1. Identity, Session & Role Escalation Defense

1. **Strict PKCE & Confirmed Email:**
   - Both React Web (`apps/web/src/services/supabase.ts`) and Flutter (`lib/main.dart`) enforce `flowType: 'pkce'` and reject sessions where `email_confirmed_at` is null.
   - Pre-provisioned roles live exclusively in `public.whitelists` (never `approved_users`).
2. **Invite Hash Isolation (`invite-admin` Bridge):**
   - `extractAndScrubInviteHash()` / `adoptInviteSession()` must scrub `#access_token=...&type=invite` via `window.history.replaceState` before router settlement, reject URLs containing `?query` parameters, verify `/auth/v1/user` (`invited_at != null`, `email_confirmed_at != null`), exchange the refresh token (`expires_at > now + 60`), enforce a 10-minute recovery window, and sign out after password update.
3. **Server-Side Gate Authority:**
   - Never rely on client route guards alone. Privilege escalation is blocked server-side by `public.guard_profile_role()` (`SQLSTATE 42501`, `hint = 'not_whitelisted'`), Edge Function admin checks (`profiles.role === 'admin'`), and FastAPI `auth.require_admin_caller`.
   - `supabase/functions/invite-admin/` must validate `redirect_to` against `AUTH_WEB_CALLBACK_URLS` (exact HTTPS or localhost URL, zero wildcards/query/hash; never trust `Origin` headers) **before** writing to `whitelists` or sending email.
   - `supabase/functions/send-push/` must fail closed (`503`) if `PUSH_WEBHOOK_SECRET` is blank and verify `x-webhook-secret` using constant-time XOR comparison.

## 2. PostgreSQL RLS, Grants & Function Hardening

1. **Least-Privilege Default:**
   - Every new table requires `ALTER TABLE ... ENABLE ROW LEVEL SECURITY;`, `REVOKE ALL ON TABLE ... FROM public, anon, authenticated;`, and explicit minimal grants + RLS policies.
   - Never grant `SELECT` on admin/config tables (`timetable_rooms`, `timetable_faculty`, `timetable_settings`, `timetable_runs`, `timetable_course_eligibility`) or cross-user `profiles` to `anon` or non-admin students/teachers.
2. **`SECURITY DEFINER` Hygiene:**
   - Every `SECURITY DEFINER` function must declare `SET search_path = ''` and schema-qualify every object reference (`public.*`, `academic_private.*`, `extensions.*`).
   - Never trust client-supplied `validation.ok = true` booleans as publication authority; validate invariants server-side.
3. **Mandatory Negative Authorization Tests:**
   - Every RLS or Storage migration must include a `BEGIN ... ROLLBACK` test script in `supabase/tests/` proving `anon`, `student`, `teacher`, and out-of-scope callers are rejected while authorized `admin` / owner calls succeed.

## 3. Storage Buckets & Untrusted `.xlsx` Payload Defense

1. **Bucket Scoping & Limits:**
   - Write access on `storage.objects` must remain strictly scoped per bucket (Phase 5B `20261122160000`): `timetables` (`public.is_admin()` only), `resources` (`teacher` or `admin`), `avatars` and `assignments` (`(storage.foldername(name))[1] = auth.uid()::text` or authorized staff).
   - When configuring or promoting buckets, enforce explicit `file_size_limit` (e.g., `<= 15 MiB` for `.xlsx` routines, `<= 50 MiB` for `resources`) and `allowed_mime_types`—never leave buckets unbounded (`null`) in production.
   - Sanitize user-provided filenames (strip path traversal `..`, `/`, `\`, control chars) before constructing storage paths.
2. **Untrusted Workbook & XML Bomb Protection (`engine/security_guards.py` & `apps/web/`):**
   - Treat every `.xlsx` file as untrusted ZIP/XML input.
   - Before invoking `openpyxl.load_workbook(...)` or OOXML XML readers in `engine/distribution.py`, `engine/ingest.py`, or Phase 3B `engine/parse_rendered.py`, enforce `security_guards.validate_xlsx_upload(...)`: verify `.xlsx` extension & `PK\x03\x04` ZIP magic bytes, cap compressed upload size (`<= 15 MiB`), cap total uncompressed archive size (`<= 100 MiB`) & max compression ratio (ZIP/XML bomb protection), cap worksheet count (`<= 100`), reject macro-bearing (`xl/vbaProject.bin`), encrypted (`EncryptedPackage`/OLE2), ActiveX, or embedded executable payloads, never evaluate external links or macros, and preserve original source bytes/SHA-256 unchanged.

## 4. FastAPI Abuse Prevention, 2027 Supabase Keys, CORS & Browser CSP

1. **Compute Exhaustion & Rate Limiting (`engine/security_guards.py` + `engine/main.py`):**
   - Render runs on 512 MB RAM (`SOLVER_WORKERS=2`). Protect expensive endpoints (`POST /api/timetable/generate` and `POST /api/timetable/parse-rendered-workbook`) with `validate_xlsx_upload`, `ConcurrencyGuard` concurrent-solve caps (`MAX_CONCURRENT_SOLVES=2`), and sliding-window per-caller `RateLimiter` returning `HTTP 429` with `Retry-After` (handled cleanly by React Web and Flutter clients).
   - Keep `GET /` unauthenticated and lightweight for health probes; require `Depends(auth.require_admin_caller)` on all `/api/timetable/*` endpoints (`ENGINE_AUTH_MODE=enforced` in Production).
2. **2027 Supabase API Key Standard (`engine/auth.py` + `.github/workflows/supabase_keep_alive.yml`):**
   - Legacy `eyJ...` anon/service_role JWTs retire in early 2027 in favor of opaque `sb_publishable_...` and `sb_secret_...` keys.
   - Always pass API keys in the `apikey` header. Against `/auth/v1/user`, send `apikey: <key>` + `Authorization: Bearer <caller_user_jwt>` (user session tokens remain JWTs). Against PostgREST (`/rest/v1/*`), **never** place an opaque `sb_secret_...` or `sb_publishable_...` key inside `Authorization: Bearer` (which triggers PostgREST `401` JWT parse errors); attach `Authorization: Bearer` only for legacy `eyJ...` keys or end-user JWTs.
3. **Exact-Origin CORS & Strict CSP:**
   - Never restore `allow_origins=["*"]`. Configure `ALLOWED_ORIGINS` with exact `https://` origins (no trailing slashes).
   - Maintain `apps/web/public/_headers` CSP with `script-src 'self'` (zero `'unsafe-inline'`, relying on external `/theme-init.js`), `frame-ancestors 'none'`, `object-src 'none'`, and explicit `connect-src` allowlists.
4. **Secret & PII Hygiene:**
   - Never commit `.env.local`, `dart_defines.json`, raw workbooks (`engine/routine generation files/*.xlsx`), `SUPABASE_SERVICE_ROLE_KEY`, `FCM_SERVICE_ACCOUNT`, or hardcoded JWTs in `.github/workflows/*.yml` (always read `${{ secrets.* }}`).
