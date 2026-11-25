# UniVerse — Backend Architecture & NotebookLM Reference Pack (`docs/backend/`)

**Freshness Date:** 2026-11-24  
**Scope:** Authoritative, code-verified, zero-secret reference pack covering the entire UniVerse backend (`supabase/`, `engine/`, Firebase/FCM, Google OAuth, Cloudflare Pages, Render, and GitHub Actions CI/CD) across **Standalone React Web (`apps/web/`)** and **Flutter Mobile (`lib/`, Android + continuous iOS compatibility)**.  
**Primary Audience:** NotebookLM grounding corpus and engineering onboarding prior to **Wave 2** (`Phase 4A-1/4A-2`, `Phase 5` Production Cutover, and `Phase 3B` server-side `.xlsx` parsing).

---

## 1. Document Index (Upload All 5 Core Files to NotebookLM)

| File | Scope & Key Contents |
| :--- | :--- |
| [`01_SUPABASE_DATABASE_AND_SECURITY_ARCHITECTURE.md`](01_SUPABASE_DATABASE_AND_SECURITY_ARCHITECTURE.md) | Complete 37-table schema across Layer 1 (18 baseline tables), Layer 2 (`20261022140809` 15 catalog tables + `academic_private`), and Layer 3 (`20261106130000` 4 distribution tables); Mermaid ER diagram; Production (`yxqyrjyzxitrgkhgauli`) vs. Staging (`oqwvxplteqtlrhktsplj`) diff; complete RLS & Storage policy matrix (`20261122160000` Phase 5B hardening); GoTrue PKCE + `whitelists` + `guard_profile_role()` + `invite-admin` & `send-push` Edge Functions. |
| [`02_TIMETABLE_ENGINE_AND_SOLVER_ARCHITECTURE.md`](02_TIMETABLE_ENGINE_AND_SOLVER_ARCHITECTURE.md) | Module-by-module Python 3.12 / FastAPI / OR-Tools CP-SAT architecture (`main.py`, `auth.py`, `distribution.py`, `ingest.py`, `solver.py`, `room_policy.py`, `render.py`, `domain.py`, `legacy_mapping.py`); HTTP multipart/JSON schemas; Phase 5A dual-client JWT + `ALLOWED_ORIGINS` CORS; live Render `GET /` probe & 512 MB spin-down behavior; code-verified **R1–R16 + D1–D6 + CD1** rule matrix; React Web vs. Flutter caller split, 20-counter validation, Phase 3B, and Gate D requirements. |
| [`03_FIREBASE_PUSH_AND_EXTERNAL_INTEGRATIONS.md`](03_FIREBASE_PUSH_AND_EXTERNAL_INTEGRATIONS.md) | Firebase project metadata (`universe-e1a60`, Android-only `DefaultFirebaseOptions`), Flutter `PushService` + `register_device_token` RPC; end-to-end push pipeline (`notifications` insert → `send_push_on_notification` DB webhook → `send-push` Edge Function `PUSH_WEBHOOK_SECRET` + `audience.js` + Web Crypto RS256 OAuth minting → FCM HTTP v1 → stale-token pruning); Production vs. Staging webhook isolation; Google OAuth 2.0 & Android/iOS/Web deep-link contracts (`com.example.universe://`, `io.supabase.universe`, iOS `GIDClientID` gap). |
| [`04_END_TO_END_DATA_FLOWS_AND_INFRASTRUCTURE.md`](04_END_TO_END_DATA_FLOWS_AND_INFRASTRUCTURE.md) | 5 cross-system sequence/data flows with Mermaid diagrams (Auth/Invite, Student/Teacher Routine + Realtime Cancellations, Track 1 Solve & 3-Step Publish, Track 2 Revisions & Gates A–D, Resource Storage & Broadcast/Push); 5-job `.github/workflows/validate.yml` + `supabase_keep_alive.yml` drift analysis; Render Shared-Service constraint (`ENGINE_AUTH_MODE=optional` vs. `enforced`); Cloudflare Pages Env A/B (`_redirects`, `_headers` CSP); **Wave 2 Backend Change Impact Matrix** across SQL, FastAPI, Flutter Mobile, and React Web. |
| [`05_FRONTEND_BACKEND_INTEGRATION_MATRIX.md`](05_FRONTEND_BACKEND_INTEGRATION_MATRIX.md) | Route-by-route **React Web (`apps/web/`)** and flow-by-flow **Flutter Mobile (`lib/`, active Student/Teacher vs. frozen legacy Admin/Web)** backend wiring matrices (exact services, Supabase tables/columns/RPCs/Edge Functions/Storage buckets, FastAPI Bearer JWT calls, TanStack Query keys, Realtime vs. polling, `localStorage`/`SharedPreferences`); shared cross-client serialization guardrails (`HH:MM:SS`, `B+C`, `is_service`, `notifications.type`, `idx: 8 Col L`); and exact **Wave 2 UI Touchpoint Map**. |

> **Historical Root Architecture Doc:** [`../../DATABASE_AND_ROUTINE_SYSTEM_ARCHITECTURE.md`](../../DATABASE_AND_ROUTINE_SYSTEM_ARCHITECTURE.md) (authored 2026-11-10) predates React Web v1 (`apps/web/`), Phase 5A (`engine/auth.py`), and Phase 5B (`20261122160000_phase_5b_rls_and_storage_hardening.sql`). Always treat the 5 files in `docs/backend/` as authoritative where they supersede the 2026-11-10 snapshot.

---

## 2. Mandatory Evidence Classification Legend

Every section and factual claim in this pack carries one of three explicit epistemic tags:

| Tag | Meaning & Today's Verification Boundary (2026-11-24) |
| :--- | :--- |
| `[VERIFIED: Live Plugin]` | Directly observed today (2026-11-24) via live probe. Today, live `GET https://universe-timetable-engine.onrender.com/` was probed directly (1st attempt timed out at 25s during Render free-tier cold start; 2nd attempt returned `HTTP 200` in `948 ms` with `{"service":"universe-timetable-engine","version":"2.0.0","ok":true}`). |
| `[VERIFIED: Repo Source]` | Directly verified in repository SQL migrations, Python modules, TypeScript/Dart services, workflow YAML, Android/iOS manifests, or committed read-only SQL audit transcripts (citing exact file paths). |
| `[UNVERIFIED: External Dashboard / No Plugin Access]` | Cannot be live-queried in this session without external dashboard access or re-authenticated MCP credentials: **(a)** `supabase_mcp` returned `oauth2: cannot fetch token: 404 Not Found ({"message":"No such refresh token found"})` today, so live SQL queries could not be re-run today (recorded 2026-11-21 and 2026-11-23 SQL audit snapshots from repo docs are cited as `[VERIFIED: Repo Source]` with live current-day drift marked `[UNVERIFIED]`); **(b)** no Firebase MCP server is installed (`firebase` skills only, zero live Firebase Console tools); **(c)** Cloudflare Pages Dashboard, Render Dashboard secret values, and Google Cloud Console OAuth settings are external to the repo. |

---

## 3. Zero-Secret & Zero-PII Guarantee

- **Zero Secrets:** Every API key, Supabase anon/publishable JWT, service-role key, webhook secret (`PUSH_WEBHOOK_SECRET`), Firebase `apiKey`, and Google Cloud private key (`FCM_SERVICE_ACCOUNT`) is redacted as `<REDACTED>`. Only non-secret identifiers (Supabase project refs `yxqyrjyzxitrgkhgauli` and `oqwvxplteqtlrhktsplj`, Firebase project ID `universe-e1a60`, bucket IDs, public hostnames, and environment variable *names*) are recorded.
- **Zero PII:** Zero personal emails, student IDs, names, password hashes, or FCM device tokens from Production, Staging, or gitignored `.xlsx` workbooks appear anywhere in `docs/backend/`.
