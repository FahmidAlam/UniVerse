# UniVerse — Backend Architecture & NotebookLM Reference Pack (`docs/backend/`)

**Freshness Date:** 2026-11-28

**Scope:** Authoritative, code-verified, zero-secret reference pack covering the entire UniVerse backend (`supabase/`, `engine/`, Firebase/FCM, Google OAuth, Cloudflare Pages, Render, and GitHub Actions CI/CD) across **Standalone React Web (`apps/web/`)** and **Flutter Mobile (`lib/`, Android + continuous iOS compatibility)**.

**Primary Audience:** NotebookLM grounding corpus and engineering onboarding covering **Production Cutover (Environment B)**, **Phase 5B RLS/Storage hardening**, **Phase 3B rendered `.xlsx` parsing**, **Stage 5A–5C (Wave 2B / Phase 4A-2 · Gates C–D)**, Render 512 MB solver tuning + orphan-job sweep, **dynamic 3-tier Course Room-Pool Classification**, and **interactive React Web preflight review/override modals**.

---

## 1. Document Index (Upload All 5 Core Files to NotebookLM)

| File | Scope & Key Contents |
| :--- | :--- |
| [`01_SUPABASE_DATABASE_AND_SECURITY_ARCHITECTURE.md`](01_SUPABASE_DATABASE_AND_SECURITY_ARCHITECTURE.md) | Complete 37-table schema across Layer 1 (18 baseline tables), Layer 2 (`20261022140809` 15 catalog tables + `academic_private`), and Layer 3 (`20261106130000` 4 distribution tables); Mermaid ER diagram; live `supabase_mcp`-verified Production (`yxqyrjyzxitrgkhgauli`, 37 tables + Phase 5B + explicit bucket limits/MIMEs) vs. Staging (`oqwvxplteqtlrhktsplj`) diff; complete RLS & Storage policy matrix (`20261122160000`); GoTrue PKCE + `whitelists` + `guard_profile_role()` + live `invite-admin` & `send-push` Edge Functions. |
| [`02_TIMETABLE_ENGINE_AND_SOLVER_ARCHITECTURE.md`](02_TIMETABLE_ENGINE_AND_SOLVER_ARCHITECTURE.md) | Module-by-module Python 3.12 / FastAPI / OR-Tools CP-SAT architecture (`main.py`, `auth.py`, `security_guards.py`, `parse_rendered.py`, `distribution.py`, `ingest.py`, `solver.py`, `room_policy.py`, `render.py`, `domain.py`, `legacy_mapping.py`); HTTP multipart/JSON schemas including live Phase 3B `POST /api/timetable/parse-rendered-workbook`; `engine/auth.py` 2027 `sb_` opaque key support & live Render `ENGINE_AUTH_MODE=enforced` probe; OOXML ZIP-bomb/macro preflight & `429` rate-limiting; code-verified **R1–R16 + D1–D6 + CD1** rule matrix; React Web vs. Flutter caller split, 20-counter validation, and Stage 5 Gate D requirements. |
| [`03_FIREBASE_PUSH_AND_EXTERNAL_INTEGRATIONS.md`](03_FIREBASE_PUSH_AND_EXTERNAL_INTEGRATIONS.md) | Firebase project metadata (`universe-e1a60`, Android-only `DefaultFirebaseOptions`), Flutter `PushService` + `register_device_token` RPC; end-to-end push pipeline (`notifications` insert → `send_push_on_notification` DB webhook → `send-push` Edge Function `PUSH_WEBHOOK_SECRET` + `audience.js` + Web Crypto RS256 OAuth minting → FCM HTTP v1 → stale-token pruning); Production vs. Staging webhook isolation; Google OAuth 2.0 & Android/iOS/Web deep-link contracts (`https://universe-admin-exi.pages.dev/`, `com.example.universe://`, `com.example.universe_v1://`, `io.supabase.universe`, iOS `GIDClientID` gap); `app_constants.dart` legacy `eyJ...` anon key retirement note ahead of early 2027. |
| [`04_END_TO_END_DATA_FLOWS_AND_INFRASTRUCTURE.md`](04_END_TO_END_DATA_FLOWS_AND_INFRASTRUCTURE.md) | 5 cross-system sequence/data flows with Mermaid diagrams (Auth/Invite, Student/Teacher Routine + Realtime Cancellations, Track 1 Solve & 3-Step Publish, Track 2 Revisions & Gates A–D, Resource Storage & Broadcast/Push); 5-job `.github/workflows/validate.yml` + secret-backed `sb_`-safe `supabase_keep_alive.yml`; Render `ENGINE_AUTH_MODE=enforced` & `ALLOWED_ORIGINS`; Cloudflare Pages Env A (`https://universe-bfi.pages.dev`) / Env B (`https://universe-admin-exi.pages.dev`) (`_redirects`, `_headers` CSP); **Wave 2 Backend Change Impact Matrix** (Prod Cutover, Phase 5B, Phase 3B complete; Stage 5 / Wave 2B `Phase 4A-2` next). |
| [`05_FRONTEND_BACKEND_INTEGRATION_MATRIX.md`](05_FRONTEND_BACKEND_INTEGRATION_MATRIX.md) | Route-by-route **React Web (`apps/web/`)** (including live `/admin/routine?tab=upload`, `/admin/routine?tab=archive` Archive v2a 2D Grid Preview + direct Storage download, and truthful Gate A–B badge probing) and flow-by-flow **Flutter Mobile (`lib/`, active Student/Teacher vs. frozen legacy Admin/Web)** backend wiring matrices; shared cross-client serialization guardrails (`HH:MM:SS`, `B+C`, `is_service`, `notifications.type`, `idx: 8 Col L`); and exact **Wave 2B (Stage 5) UI Touchpoint Map** aligned 100% with **R1–R16**. |

> **Historical Root Architecture Doc:** [`../../DATABASE_AND_ROUTINE_SYSTEM_ARCHITECTURE.md`](../../DATABASE_AND_ROUTINE_SYSTEM_ARCHITECTURE.md) (authored 2026-11-10) predates React Web v1 (`apps/web/`), Phase 5A (`engine/auth.py`), Phase 5B (`20261122160000_phase_5b_rls_and_storage_hardening.sql`), Production Cutover, and Phase 3B (`engine/parse_rendered.py`). Always treat the 5 files in `docs/backend/` as authoritative where they supersede the 2026-11-10 snapshot.

---

## 2. Mandatory Evidence Classification Legend

Every section and factual claim in this pack carries one of three explicit epistemic tags:

| Tag | Meaning & Today's Verification Boundary (2026-11-27) |
| :--- | :--- |
| `[VERIFIED: Live Plugin]` | Directly observed today (2026-11-27) via live read-only probes: **(a)** `supabase_mcp` (`execute_sql` read-only metadata/aggregate count queries + `list_edge_functions`) executed against both Production (`yxqyrjyzxitrgkhgauli`) and Staging (`oqwvxplteqtlrhktsplj`); **(b)** live `GET https://universe-timetable-engine.onrender.com/` returned `HTTP 200` with `{"service":"universe-timetable-engine","version":"2.0.0","ok":true,"auth_mode":"enforced"}`. |
| `[VERIFIED: Repo Source]` | Directly verified in repository SQL migrations, Python modules, TypeScript/Dart services, workflow YAML, or Android/iOS manifests (citing exact file paths). |
| `[UNVERIFIED: External Dashboard / No Plugin Access]` | Cannot be live-queried in this session without external dashboard access: **(a)** Edge Function / Render / Cloudflare Pages secret values and exact env var strings (`AUTH_WEB_CALLBACK_URLS`, `PUSH_WEBHOOK_SECRET`, `FCM_SERVICE_ACCOUNT`, `SUPABASE_SERVICE_ROLE_KEY`, `ALLOWED_ORIGINS`); **(b)** no Firebase MCP server is installed (`firebase` skills only, zero live Firebase Console / APNs tools); **(c)** Google Cloud Console OAuth client URIs and Cloudflare Pages Dashboard build settings are external to the repo. |

---

## 3. Zero-Secret & Zero-PII Guarantee

- **Zero Secrets:** Every API key, Supabase anon/publishable JWT, service-role key, webhook secret (`PUSH_WEBHOOK_SECRET`), Firebase `apiKey`, and Google Cloud private key (`FCM_SERVICE_ACCOUNT`) is redacted as `<REDACTED>`. Only non-secret identifiers (Supabase project refs `yxqyrjyzxitrgkhgauli` and `oqwvxplteqtlrhktsplj`, Firebase project ID `universe-e1a60`, bucket IDs, public hostnames, and environment variable *names*) are recorded.
- **Zero PII:** Zero personal emails, student IDs, names, password hashes, or FCM device tokens from Production, Staging, or gitignored `.xlsx` workbooks appear anywhere in `docs/backend/`.
