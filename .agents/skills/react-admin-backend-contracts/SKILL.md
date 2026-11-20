---
name: react-admin-backend-contracts
description: Authoritative backend, Supabase Auth/RLS/RPC, FastAPI CP-SAT engine, public sandbox boundary, and persistence truth contracts for the UniVerse React Web v1 application (apps/web/). Mandatory before writing any API client, auth flow, onboarding sandbox, or admin persistence code.
---

# UniVerse React Web v1 — Backend, Auth & Persistence Contracts

## 1. Separation, Scope & Public Sandbox Boundaries
### 1.1 Platform Scope
- **Authenticated Web v1 Target:** **Administrators ONLY** in `apps/web/` (React + TypeScript + Vite). Student and Teacher daily operations remain on **Flutter Android** (`lib/`, `android/`, `test/`). No iOS work.
- **Mobile Protection:** Never alter shared Supabase schemas, RPC signatures, or FastAPI endpoints in ways that break existing Flutter Android clients.
- **No Unapproved Hosted Mutations:** Never run Supabase CLI against production (`yxqyrjyzxitrgkhgauli`) or apply migrations without explicit approval. Use staging (`oqwvxplteqtlrhktsplj`) or local mocks during development.

### 1.2 Public Marketable Entry & Interactive Onboarding Sandbox Boundary
- **Allowed Unauthenticated Routes:** `/`, `/onboarding`, `/login`, `/forgot-password`, `/reset-password` (recovery session only), `/access-required`.
- **Interactive Onboarding Sandbox Rules:** Any interactive routine-generation showcase on `/` or `/onboarding` MUST run **100% client-side on curated illustrative fixtures**. It must NEVER call `POST /api/timetable/generate`, NEVER query private Supabase tables, NEVER fabricate database persistence, and NEVER claim unimplemented AI assistant capabilities.
- **`/preview/scheduling` Gate:** Never leave `/preview/scheduling` publicly accessible in production builds—gate it strictly behind authenticated admin sessions (or explicit dev env flag) with persistent `PREVIEW · SIMULATED DATA` disclosure.

---

## 2. Admin-Only Authentication, Whitelist & Invite Bridge Contract
UniVerse uses **Supabase GoTrue with `flowType: 'pkce'`**.

### Admin Gate (Mandatory Difference from Shared Flutter App)
1. On sign-in or session hydration, query `public.profiles` by `id = user.id`.
2. If no `profiles` row exists, check `public.whitelists` where `lower(email) = lower(user.email)` AND `role = 'admin'`. If found, insert own admin profile (enforced server-side by `profiles_guard_role` trigger).
3. **Hard Reject Non-Admins:** If `profile.role !== 'admin'` or no admin whitelist entry exists, block all `/admin/*` routes and route to a clear, helpful screen explaining that Web v1 is the Administrator Console (with Sign Out + Android App guidance for Students & Faculty).
4. Map Postgres trigger error `hint === 'not_whitelisted'` (`SQLSTATE 42501`) cleanly to an explicit Not-Whitelisted state.

### Callback URLs & `invite-admin` PKCE/Implicit Bridge
- Register every web origin (localhost + Cloudflare Pages preview/prod) in Supabase Auth Redirect URLs and Edge Function `AUTH_WEB_CALLBACK_URLS` (exact origin match, no query/hash/wildcards).
- **`invite-admin` Hash Handler:** `POST <SUPABASE_URL>/functions/v1/invite-admin` (`{ email, name, redirect_to }`) uses server-side `inviteUserByEmail()`, returning **implicit** hash tokens (`#access_token=...&refresh_token=...&expires_in=...&token_type=bearer&type=invite`) with no PKCE `code_verifier`.
  - On app bootstrap before router redirects settle, detect `type=invite` in `window.location.hash`, immediately scrub tokens via `window.history.replaceState(null, '', window.location.pathname)`, verify/adopt the session (`user.invited_at` present), and lock the router to `/reset-password` (10-minute recovery timeout).

---

## 3. Python FastAPI CP-SAT Engine Contract (`engine/main.py`)
Base URL via `import.meta.env.VITE_TIMETABLE_BASE_URL` (hosted default: `https://universe-timetable-engine.onrender.com`, Render free plan — expect cold-start spin-up latency and in-memory `JOBS` clearing on spin-down).

| Method & Path | Purpose | Exact Contract |
| :--- | :--- | :--- |
| `GET /` | Health check (**NOT `/health`**) | `200 { service: "universe-timetable-engine", version: "2.0.0", ok: true }`. Timeout `5s`. |
| `POST /api/timetable/generate` | Submit solve (`multipart/form-data`) | Fields: `file` (`.xlsx`), `config` (JSON string), optional `source_contract` (JSON object), `time_limit_s` (`180`). Returns `200 { job_id }`. Timeout `90s`. |
| `GET /api/timetable/status/{job_id}` | Poll job progress | Poll every `2s`, max `240` polls (~8 min). Back off `+4s` on `429` without incrementing failure count; fail on 5th consecutive non-429 error. States: `queued`, `ingesting`, `solving`, `rendering`, `done`, `failed`. |
| `GET /api/timetable/result/{job_id}` | Fetch solved rows + validation | Returns `rows`, `service_rows`, `stats`, `validation`, `source_contract`, `report`, `has_workbook`. |
| `GET /api/timetable/download/{job_id}` | Download `.xlsx` | Binary `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`. |

- **Security Tracking Note:** `engine/main.py` currently uses `allow_origins=["*"]` and zero JWT authentication. Keep engine invocations strictly behind authenticated admin UI in `apps/web/`, and track JWT + CORS origin hardening in backend phase.

---

## 4. Persistence Truth Table (Zero Fabricated Persistence)
### A. Live Persisted in Production Supabase Today
- **Routines & Versions:** `routines`, `routine_versions`, `timetable_runs`, RPC `publish_routine(...)`, Storage bucket `timetables` (`CSE_Routine_<label>_<epoch_ms>.xlsx`).
  - **Empty Config Pre-Publish Guard:** Production `timetable_rooms`, `timetable_faculty`, `timetable_settings`, and `timetable_course_eligibility` currently contain **0 rows**, and `publish_routine` runs `DELETE FROM public.routines WHERE true;`. Warn/block publishing an unconstrained schedule.
  - **Co-Teacher Pre-Publish Guard:** Refuse publication if any row has multiple teachers (`teachers.length > 1`), as `public.routines` only holds a single scalar `teacher_code` column.
- **Baseline Config Tables (Exact Existing Columns Only):**
  - `timetable_settings` (singleton `id = 1`).
  - `timetable_rooms`: `id, name, building, is_lab, is_gallery, capacity, is_active, dept, campus, features`.
  - `timetable_faculty`: `id, acronym, full_name, dept, designation, off_days, is_active, courses, home_department_id`.
  - `timetable_course_eligibility`: `id, acronym, course_code, is_eligible, priority`.
- **Operations & Access:** `profiles`, `whitelists`, `notifications`, `resources` + Storage bucket `resources`.
- **Realtime Truth:** Production `supabase_realtime` publishes ONLY `public.cancellations` (not `routines` or `notifications`). Use TanStack Query focus-refetch + explicit Refresh buttons.

### B. NOT Persisted in Production Yet (Fail-Closed / Explicitly Staged)
- **Courses Catalog & Batches/Sections (`ManageCourses`, `ManageBatches`):** Currently 100% in-memory in Flutter. Do NOT build fake DB save toasts in React.
- **Extended Phase A Faculty/Room Columns** (`classification`, `building_and_floor`, `in_active_semester_pool`, `bound_course_codes`, `declared_window_matrix`, `employment_type`, `is_sust_adjunct`, `sust_compactness_mode`, `is_external_guest`, `has_external_block`, `slot_matrix`): **Do NOT exist in Postgres yet.** Never swallow failed DB writes silently.
- **5-Stage Scheduling Workbench (`/admin/scheduling`):** Must stay **fail-closed (`Gates A–D locked`)** until `20261022140809_academic_catalog.sql` and `20261106130000_course_distribution_contract.sql` are promoted. When wiring Gate B later, use the true SQL signature (`revision_version`, `scheduling_scope_id`, 8 named params on `append_course_distribution_correction`).