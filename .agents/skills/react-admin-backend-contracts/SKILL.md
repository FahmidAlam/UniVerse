---
name: react-admin-backend-contracts
description: Authoritative backend, Supabase Auth/RLS/RPC, FastAPI CP-SAT engine (JWT + CORS), public sandbox boundary, and persistence truth contracts for the UniVerse React Web application (apps/web/). Mandatory before writing any API client, auth flow, onboarding sandbox, or admin persistence code.
---

# UniVerse React Web — Backend, Auth & Persistence Contracts

## 1. Platform Separation & Public Sandbox Boundaries
- **Authenticated Web Target:** **Administrators ONLY** in `apps/web/` (React 19 + TypeScript + Vite). Student and Teacher daily workflows live on **Flutter Mobile** (`lib/`, Android + continuous iOS compatibility). Legacy Flutter Web (`web/`, `lib/features/admin/`) is **frozen** as a read-only fallback until Production Cutover + Phase 3B complete.
- **Shared Backend Safety:** Never alter shared Supabase schemas, RPC signatures, or FastAPI contracts in ways that break Android or iOS mobile clients (`com.example.universe://` deep links, auth callbacks, `routines`/`cancellations`/`notifications`/`resources` contracts).
- **Hosted Environment Governance (No Supabase CLI):**
  - **Staging (`oqwvxplteqtlrhktsplj`):** Owner-approved isolated staging project (`37` tables including `20261022140809`, `20261106130000`, and Phase 5B RLS/storage hardening `20261122160000`). Powers Cloudflare Pages **Environment A (Committee Review)**.
  - **Production (`yxqyrjyzxitrgkhgauli`):** Strictly protected; Phase 4A-1 + Phase 5B SQL promotion and **Environment B** cutover require separate explicit owner execution via `docs/deployment/`.
- **Public Entry Sandbox (`/`):** Unauthenticated routes (`/`, `/login`, `/forgot-password`, `/reset-password`, `/access-required`) must **never** call `POST /api/timetable/generate` or query private tables. Interactive routine previews on `/` run 100% client-side on labeled illustrative fixtures. Keep `/preview/scheduling` disabled in production (`VITE_ENABLE_SCHEDULING_PREVIEW_ROUTE=false`).

---

## 2. Admin-Only Authentication, Whitelist & Invite Bridge (`services/supabase.ts`)
UniVerse uses **Supabase GoTrue (`flowType: 'pkce'`)**.

1. **Admin Role Gate:**
   - Hydrate `public.profiles` where `id = user.id`.
   - If missing, query `public.whitelists` where `lower(email) = lower(user.email)` AND `role = 'admin'`; if matched, insert own admin profile (guarded server-side by `guard_profile_role()` trigger; handle `SQLSTATE 42501` / `hint === 'not_whitelisted'`).
   - **Reject Non-Admins:** If `profile.role !== 'admin'`, block all `/admin/*` routes and render `/access-required` (Sign Out + Flutter Mobile app guidance for Students/Teachers).
2. **`invite-admin` Implicit Hash Bridge (`extractAndScrubInviteHash` / `adoptInviteSession`):**
   - `POST <SUPABASE_URL>/functions/v1/invite-admin` returns implicit hash tokens (`#access_token=...&type=invite`).
   - Before router redirects settle, scrub the URL hash via `window.history.replaceState`, verify `/auth/v1/user` (`id`, `invited_at`, `email_confirmed_at`), exchange the refresh token, verify `expires_at > now + 60`, adopt the session, and route to `/reset-password`.
   - Register exact web origins (no wildcards/query/hash) in Supabase Auth Redirect URLs and Edge Function `AUTH_WEB_CALLBACK_URLS`.

---

## 3. Python FastAPI CP-SAT Engine Contract (`engine/main.py` + `engine/auth.py`)
Base URL via `import.meta.env.VITE_TIMETABLE_BASE_URL` (hosted: `https://universe-timetable-engine.onrender.com`).

| Method & Path | Purpose | Exact Contract |
| :--- | :--- | :--- |
| `GET /` | Health check (**NOT `/health`**) | `200 { service: "universe-timetable-engine", version: "2.0.0", ok: true, auth_mode }`. Public (unauthenticated), `5s` timeout. |
| `POST /api/timetable/generate` | Submit solve (`multipart/form-data`) | Fields: `file` (`.xlsx` — uploaded or built in-browser by Course Distribution Studio), `config` (JSON string), optional `source_contract` (JSON), `time_limit_s` (`180`). Returns `200 { job_id }`. |
| `GET /api/timetable/status/{job_id}` | Poll job progress | Poll every `2s`, max `240` polls (~8 min). Back off `+4s` on `429` without incrementing failure count; fail on 5th consecutive non-429 error (`404` = Render spin-down / evicted in-memory `JOBS`). |
| `GET /api/timetable/result/{job_id}` | Fetch solved rows + validation | Returns `rows`, `service_rows`, `stats`, `validation`, `report`, `has_workbook`, and optional `source_contract` (treat `source_contract` as optional until Render redeploys latest `engine/main.py`). |
| `GET /api/timetable/download/{job_id}` | Download rendered `.xlsx` | Binary `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`. |

- **Dual-Client JWT & CORS (`engine/auth.py`):** Protected `/api/timetable/*` routes verify `Authorization: Bearer <supabase_access_token>` + `profiles.role == 'admin'`. `ENGINE_AUTH_MODE=optional` during dual-client rollout; flips to `enforced` at Production Cutover alongside `ALLOWED_ORIGINS` (exact origins, trailing slashes auto-stripped). Both React Web (`timetableEngineService.ts`) and Flutter (`timetable_engine_service.dart`) attach Bearer tokens.

---

## 4. Persistence Truth & Gate Boundaries (Zero Fabricated Persistence)
### A. Live Persisted Contracts
- **Routines & Publication:** `routines`, `routine_versions`, `timetable_runs`, RPC `publish_routine(...)`, Storage bucket `timetables`.
  - **Pre-Publish Guards:** Block publication when `blockingValidationErrorFor` fails, when baseline config tables are empty without explicit confirmation, or when any row has `teachers.length > 1` (`public.routines.teacher_code` is scalar).
- **Baseline Config Tables (Exact Verified Columns Only):**
  - `timetable_settings` (singleton `id = 1`, `ClockTime` normalized `HH:MM:SS` in DB <-> `HH:MM` in engine, dynamic `break_after_period` / `friday_no_p4`).
  - `timetable_rooms`: `id, name, building, is_lab, is_gallery, capacity, is_active, dept, campus, features`.
  - `timetable_faculty`: `id, acronym, full_name, dept, designation, off_days, is_active, courses, home_department_id`.
  - `timetable_course_eligibility`: `id, acronym, course_code, is_eligible, priority` (strictly these columns on batch upserts).
- **Operations & Realtime:** `profiles`, `whitelists`, `notifications`, `resources` + Storage buckets `resources` & `avatars` (Phase 5B RLS owner-folder scoped). `supabase_realtime` publishes ONLY `public.cancellations`; use TanStack Query invalidation + explicit Refresh elsewhere.

### B. Track 2 Capabilities & Wave 2 Staged Boundaries (`schedulingCapabilities.ts`)
- **Live Capability Probe (`probeLiveSchedulingCapabilities`):** Probes the 4 atomic Track 2 tables (`course_distribution_revisions`, `course_distribution_sources`, `course_distribution_corrections`, `course_distribution_artifacts`) via RLS-protected PostgREST reads — **never** call `GET /rest/v1/` OpenAPI root (`401` on publishable keys) and **never** invoke RPCs with nil UUIDs (`P0002` `500`).
- **Gates A & B (`read_course_distribution_revision`, `append_course_distribution_correction`):** Unlock truthfully when the 37-table Track 2 schema is live (active on Staging `oqwvxplteqtlrhktsplj`; locked on Production until Phase 4A-1 promotion). Enforce exact SQL signatures (`revision_version`, `scheduling_scope_id`, 8-param `append_course_distribution_correction`, `SQLSTATE 40001` optimistic concurrency).
- **Gates C & D + Rendered `.xlsx` Upload + Extended Catalogs:** Remain **unconditionally fail-closed** in Live Mode until **Wave 2** ships (`Phase 4A-2`: R1–R16 CP-SAT solver, revision-bound policy/validation artifacts, durable job storage, archiving `publish_routine()`; `Phase 3B`: additive FastAPI rendered-workbook parse endpoint). Never leak preview fixtures into Live Mode.
