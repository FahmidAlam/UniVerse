# UniVerse — Standalone React Web Implementation Roadmap

> **Purpose:** Safe, dependency-aware phased roadmap bridging the approved strategic blueprint ([`WEB_ARCHITECTURE_DESIGN_BLUEPRINT.md`](WEB_ARCHITECTURE_DESIGN_BLUEPRINT.md)) and verified repository truth ([`WEB_SOURCE_VERIFICATION_REPORT.md`](WEB_SOURCE_VERIFICATION_REPORT.md)).
> **Safety Rule:** Approving a frontend milestone **never** implies authorization for Flutter, Python FastAPI, PostgreSQL/RLS schema, Edge Function, or hosting changes. Each non-frontend boundary carries an explicit **Separate Owner Authorization Required** gate.

---

## Cross-Phase Architecture Map

```text
Phase 0: Source Verification, Governance, SQL Quarantine Audit & Package Verification (Docs + Read-Only SQL)
   │
   ▼
Phase 1: Academic Ledger Design System, Public Entry, Auth Hardening & Capability Registry
   ├── 1A: Mocked Frontend, Academic Ledger Tokens & Dashboard Readiness Cleanup (Frontend-Only)
   └── 1B: Live Staging Auth Verification (GATED until clean non-prod project approved)
   │
   ▼
Phase 2: Admin Dashboard & Verified Baseline Configuration CRUD (Frontend-Only against existing DB contracts)
   │
   ▼
Phase 3: Track 1 — Operational Routine Console & Custom 2D Timetable Grid
   ├── 3A: Grid, Manage Published, FastAPI Generate & Guarded Publish (Frontend-Only against existing APIs)
   └── 3B: Rendered `.xlsx` Upload Review (GATED behind separate authorization of additive FastAPI parse endpoint)
   │
   ▼
Phase 4: Track 2 — Committee Scheduling Workbench (Gates A–D; includes Durable Job Storage in Gate D)
   ├── 4A: Database Catalog/Distribution Promotion & Policy Schema (SEPARATE DB AUTHORIZATION)
   └── 4B: Frontend Workbench & Progressive Gate Unlocking (Frontend-Only)
   │
   ▼
Phase 5: Security Hardening, Cross-Platform Regression & Cutover
   ├── 5A: FastAPI 5-Step Dual-Client JWT & CORS Hardening (SEPARATE ENGINE + FLUTTER COORDINATION)
   ├── 5B: Supabase RLS & Storage Bucket Scoping (SEPARATE DB AUTHORIZATION)
   └── 5C: Cloudflare Pages Deployment, CI/CD, Android + iOS Compatibility & Cutover (SEPARATE HOSTING/AUTH AUTHORIZATION)
```

---

## Phase 0 — Source Verification, Governance Alignment & Environment Readiness

### 1. Objective
Resolve governance/documentation contradictions, establish live hosted Supabase state via owner-executed read-only SQL, confirm npm package compatibility with React 19, and identify the approved testing environment before editing any `apps/web/` feature code.

### 2. Exact Scope
- **Documentation & Governance Updates:** `AGENTS.md`, `CLAUDE.md`, `PROJECT_STRUCTURE.md`, `.agents/skills/react-web-academic-design-system/SKILL.md`, `.agents/skills/react-web-motion-and-craft/SKILL.md`, `docs/implementation/web_phase_0_1_spatial_orbit_foundation.md`.
- **Read-Only Hosted Inspection (No Mutations):** Owner executes read-only SQL queries in Supabase Dashboard → SQL Editor.
- **Zero Application Code / Migration Changes:** No edits to `apps/web/src/`, `lib/`, `engine/`, or `supabase/migrations/`.

### 3. Relevant Existing Files & Affected Areas
- [`AGENTS.md`](../../AGENTS.md), [`CLAUDE.md`](../../CLAUDE.md), [`PROJECT_STRUCTURE.md`](../../PROJECT_STRUCTURE.md)
- [`.agents/skills/react-web-academic-design-system/SKILL.md`](../../.agents/skills/react-web-academic-design-system/SKILL.md)
- [`.agents/skills/react-web-motion-and-craft/SKILL.md`](../../.agents/skills/react-web-motion-and-craft/SKILL.md)
- [`.agents/skills/react-admin-backend-contracts/SKILL.md`](../../.agents/skills/react-admin-backend-contracts/SKILL.md)
- [`docs/implementation/web_phase_0_1_spatial_orbit_foundation.md`](../implementation/web_phase_0_1_spatial_orbit_foundation.md)
- [`apps/web/package.json`](../../apps/web/package.json)
- [`supabase/reconciliation/storage_realtime_inventory.sql`](../../supabase/reconciliation/storage_realtime_inventory.sql)

### 4. Dependencies
- Completion of this audit's three baseline documents (done).

### 5. Entry Criteria
- Owner reviews [`WEB_SOURCE_VERIFICATION_REPORT.md`](WEB_SOURCE_VERIFICATION_REPORT.md) and approves reconciling project rules from `Spatial Orbit Engine` to `UniVerse Academic Ledger`.

### 6. Work Items
1. **Reconcile Governance & Skills:**
   - Update `AGENTS.md` and `CLAUDE.md` to explicitly distinguish **Flutter Mobile (`lib/`, Obsidian Orbit, Android + continuous iOS compatibility)** from **Standalone React Web (`apps/web/`, UniVerse Academic Ledger)**, removing the contradictory prohibition against React Web while preserving Flutter Mobile protection rules.
   - Update `react-web-academic-design-system` and `react-web-motion-and-craft` skills to codify **UniVerse Academic Ledger** (Light-first, `Source Serif 4`, `IBM Plex Sans`, `IBM Plex Mono`, Charcoal Ink + provisional Deep Botanical Pine, flat/restrained motion, video-backed dense table & accessibility principles) and retire **Spatial Orbit Engine**.
   - Fix `docs/implementation/web_phase_0_1_spatial_orbit_foundation.md` lines 51 and 79 (`approved_users` → `public.whitelists`), and fix `CLAUDE.md:42` (`/auth-callback` / `AuthCallbackLocation` inaccuracy).
   - Add `apps/web/` and React Web skills to `PROJECT_STRUCTURE.md`.
2. **Git Working-Tree Inspection & Checkpoint Hygiene:**
   - Record exact current branch (`feature/react-admin-web-v1`), `git status --short`, modified tracked files, and untracked deliverables without running `git reset`, `git clean`, `git stash`, `git push`, or unrequested commits.
   - Recommend an owner-authorized **documentation-only checkpoint commit** once Phase 0 reconciliation is reviewed before Phase 1 code edits begin.
3. **Verify Preferred Stack Compatibility (`npm view` Registry Dry Check Only):**
   - Documented in [`WEB_PHASE_0_COMPATIBILITY_AND_AUDIT_ADDENDUM.md`](WEB_PHASE_0_COMPATIBILITY_AND_AUDIT_ADDENDUM.md) (no packages installed in Phase 0):
     - Confirm React `19.3.1` compatibility across `@tanstack/react-table` (`9.3.1` latest vs. `8.21.3` stable), `@tanstack/react-virtual` (`3.14.26`), `recharts` (`3.11.0`, **requires `react-is@^19`**), `cmdk` (`1.1.1`), `react-hook-form` (`7.92.0`), `zod` (`4.6.7`), `@hookform/resolvers` (`7.0.8`), `zustand` (`5.1.0`), `motion` vs. removing installed `framer-motion@^12.16.0` (both `14.14.0`), `vitest` (`4.1.12` V4 matching `vite@6.4.6` vs. `5.1.1`), `@playwright/test` (`1.65.1`), `shadcn` (`4.23.0`) + `radix-ui` (`1.8.1`), and audit unused `@radix-ui/react-switch`.
4. **Database Audit, Quarantine Resolution & Dashboard Readiness (Without Supabase CLI):**
   - Production Supabase (`yxqyrjyzxitrgkhgauli`) remains strictly **read-only**.
   - Owner executed the read-only SQL diagnostic packet on both `yxqyrjyzxitrgkhgauli` and `oqwvxplteqtlrhktsplj` (results recorded in [`WEB_PHASE_0_COMPATIBILITY_AND_AUDIT_ADDENDUM.md`](WEB_PHASE_0_COMPATIBILITY_AND_AUDIT_ADDENDUM.md) §4): `oqwvxplteqtlrhktsplj` holds `37` tables, `0` rows across all tables, and zero `send-push` webhooks, and is **owner-approved as the non-production staging project** (quarantine lifted).
   - Owner confirmed **Deep Botanical Pine** for Phase 1A (`tokens.css`); Supabase Auth Redirect URLs, Edge Function `AUTH_WEB_CALLBACK_URLS`, and Cloudflare Pages target remain external checks prior to Phase 1B / 5C.

### 7. Verification & Test Requirements
- Markdown formatting & internal relative link checks across all updated governance/architecture docs; grep verification for residual conflicting Spatial Orbit mandates, React Web prohibitions, TypeScript parser mandates, or `approved_users` typos; `git status --short` scope verification.
- Recorded owner output from the read-only SQL Editor diagnostic packet attached to [`WEB_PHASE_0_COMPATIBILITY_AND_AUDIT_ADDENDUM.md`](WEB_PHASE_0_COMPATIBILITY_AND_AUDIT_ADDENDUM.md) §4 (complete).
- Verified npm package compatibility matrix and clean staging designation (`oqwvxplteqtlrhktsplj`) recorded before Phase 1A / 1B.

### 8. Risks
- Skipping dashboard-level Auth Redirect URL / Edge Function checks before Phase 1B staging tests could still cause callback rejection even though staging DB isolation is verified.
- Installing unverified React 19 peer packages (e.g., Recharts v3 without `react-is@19` or installing both `motion` and `framer-motion`) causes bundling or duplicate dependency issues.

### 9. Rollback Considerations
- All Phase 0 changes are documentation-only; trivially reversible via standard file review without mutating runtime code, dependencies, or databases.

### 10. Exit Criteria
- Governance contradictions resolved and aligned to **UniVerse Academic Ledger**; `F-29`/`F-30`/`F-31` and live SQL diagnostics (`F-20`) verified and recorded.
- Owner-approved non-production Supabase staging target confirmed (`oqwvxplteqtlrhktsplj`, `0` rows, zero push webhooks; quarantine lifted).
- Deep Botanical Pine confirmed for Phase 1A; package compatibility matrix signed off.

### 11. Separate Owner Authorization Required
- **Completed for Phase 0:** Owner SQL diagnostics executed on both projects, `oqwvxplteqtlrhktsplj` designated as clean staging, and Deep Botanical Pine confirmed for Phase 1A.
- **Required Next:** Owner approval of the Phase 1A UI/UX design brief ([`WEB_PHASE_1A_DESIGN_BRIEF.md`](WEB_PHASE_1A_DESIGN_BRIEF.md)) and npm package changes before installing dependencies or editing `apps/web/`.

---

## Phase 1 — Design System, Public Web Foundation & Capability Model

### 1. Objective
Replace the superseded **Spatial Orbit Engine** theme and 3D stage in `apps/web/` with the approved light-first **UniVerse Academic Ledger** design system, build the scholarly public institutional landing page, harden the PKCE/invite-admin auth boundary, establish the centralized Capability Registry, **remove hardcoded Stage 03 illustrative filename/SHA placeholders from `AdminDashboardPage.tsx`**, and configure Vitest + Playwright + opaque-sRGB WCAG AA contrast tests.

### 2. Exact Scope
Split into two distinct gates:
- **Sub-Phase 1A — Mocked Frontend & Design System (Frontend-Only, Local Dev / Mocked Supabase):** Design tokens, fonts, CSS, user-controlled public preview, `AdminShell`, backend-derived dashboard readiness cleanup, auth client hardening, capability registry, and local Vitest + Playwright verification. Zero hosted staging dependency.
- **Sub-Phase 1B — Live Staging Auth Verification (GATED SUB-STEP):** Live PKCE login, Google OAuth, password recovery, and `invite-admin` link verification against **owner-approved staging project `oqwvxplteqtlrhktsplj`** (after confirming Supabase Auth Redirect URLs & `AUTH_WEB_CALLBACK_URLS`; never against production `yxqyrjyzxitrgkhgauli`).
- **Zero Changes To:** Flutter (`lib/`, `android/`, `ios/`, `test/`), FastAPI (`engine/`), PostgreSQL schemas/RLS (`supabase/`), or hosting deployment.

### 3. Relevant Existing Files & Affected Areas
- [`apps/web/package.json`](../../apps/web/package.json), [`apps/web/index.html`](../../apps/web/index.html)
- [`apps/web/src/styles/tokens.css`](../../apps/web/src/styles/tokens.css), [`apps/web/src/styles/app.css`](../../apps/web/src/styles/app.css)
- [`apps/web/src/shared/theme/ThemeProvider.tsx`](../../apps/web/src/shared/theme/ThemeProvider.tsx), [`apps/web/src/shared/components/ThemeSwitcher.tsx`](../../apps/web/src/shared/components/ThemeSwitcher.tsx) (to be retired/simplified for light-first)
- [`apps/web/src/features/onboarding/components/SpatialOrbitStage.tsx`](../../apps/web/src/features/onboarding/components/SpatialOrbitStage.tsx) & [`routineFixtures.ts`](../../apps/web/src/features/onboarding/data/routineFixtures.ts) (replace with flat 2D Academic Ledger public preview)
- [`apps/web/src/features/auth/PublicAuthLayout.tsx`](../../apps/web/src/features/auth/PublicAuthLayout.tsx), [`AuthProvider.tsx`](../../apps/web/src/features/auth/AuthProvider.tsx), [`LoginPage.tsx`](../../apps/web/src/features/auth/pages/LoginPage.tsx), [`ForgotPasswordPage.tsx`](../../apps/web/src/features/auth/pages/ForgotPasswordPage.tsx), [`ResetPasswordPage.tsx`](../../apps/web/src/features/auth/pages/ResetPasswordPage.tsx), [`AccessRequiredPage.tsx`](../../apps/web/src/features/auth/pages/AccessRequiredPage.tsx), [`AndroidCompanionStrip.tsx`](../../apps/web/src/features/auth/components/AndroidCompanionStrip.tsx)
- [`apps/web/src/services/supabase.ts`](../../apps/web/src/services/supabase.ts)
- [`apps/web/src/features/admin/AdminShell.tsx`](../../apps/web/src/features/admin/AdminShell.tsx)

### 4. Dependencies
- Phase 0 exit criteria completed (approved testing target, verified package versions, confirmed accent color token).

### 5. Entry Criteria
- Explicit owner approval of the UI/UX design brief for the **UniVerse Academic Ledger** public landing page and shell layout (per mandatory UI/UX approval gate).

### 6. Work Items
1. **Verified Dependency Installation (`apps/web/`):**
   - Install verified testing & core UI packages (`vitest`, `@playwright/test`, `@testing-library/react`, `react-hook-form`, `zod`, `zustand`, `cmdk`, `shadcn/ui` Radix primitives, and finalize `motion` vs. `framer-motion`). Remove unused dependencies if unneeded.
2. **UniVerse Academic Ledger Token System:**
   - Rewrite `apps/web/index.html` to load `Source Serif 4`, `IBM Plex Sans`, and `IBM Plex Mono`, set light-first defaults, and remove dark-mode FOUC script.
   - Rewrite `tokens.css` & `app.css` with OKLCH light-first archival paper neutrals, Charcoal Ink primary actions, Deep Botanical Pine accent (tokenized cleanly for future brand swap), `color-mix(in oklab, ...)` safety, `tabular-nums`, `prefers-contrast: more`, `forced-colors: active`, and `prefers-reduced-motion: reduce`.
   - Retire `ThemeSwitcher.tsx` (deferring dark mode per blueprint).
3. **Public Institutional Landing & Client-Only Showcase:**
   - Replace `SpatialOrbitStage.tsx` (3D tilt, fluted bezel, rotating orbital SVG rings) with a calm **Archival Registrar + Precision Ledger** public landing experience presenting Leading University CSE routine generation, client-side interactive timetable rules toggle (`Friday P4 Jummah`, `R7 Off-Day`, `R15 6/7-Slot`, `Section / Faculty / Room` lens), and crisp Android & iOS mobile companion guidance for Students & Teachers.
   - Guarantee zero unauthenticated calls to Supabase or FastAPI.
4. **Auth Hardening & Capability Registry:**
   - Fix `AuthProvider.tsx` `onAuthStateChange` stale `status` closure using `statusRef`.
   - Harden `adoptInviteSession` in `supabase.ts` (`!window.location.search`, `email_confirmed_at`, and `expires_at > now + 60` validation matching Flutter's `InvitationCallbackBridge`).
   - Add a centralized **Capability Registry** module (`src/core/capabilities/`) distinguishing `live-persisted`, `staged-no-db`, and `fail-closed` Track 2 Gates A–D so every route and component reads capability status consistently.
5. **Restyle `AdminShell` & Make `/admin/dashboard` Readiness Strictly Backend-Derived:**
   - Remove Spatial Orbit styling and `ThemeSwitcher` from `AdminShell.tsx`; apply Academic Ledger sidebar, 52px header, `EngineHealthBadge`, and admin menu.
   - **Remove hardcoded illustrative `.xlsx` filename and SHA from `AdminDashboardPage.tsx` in Phase 1**, ensuring Stage 01–04 readiness checklist counts and metadata derive strictly from live Supabase + FastAPI state (with `isDevPreview` isolated strictly to unconfigured local dev mode).
6. **Gated Sub-Step 1B — Hosted Staging Auth Smoke Check (Only After Clean Project Clearance):**
   - Once Phase 0 SQL inspection clears an approved staging environment, verify real PKCE Google OAuth, `invite-admin`, password recovery window, and non-admin `/access-required` rejection without writing production tables.

### 7. Verification & Test Requirements
- **Sub-Phase 1A (Local Mocked Verification — Required for Phase 1A Exit):**
  - `npm run typecheck` (`tsc --noEmit`) and `npm run build` (`tsc -b && vite build`) pass with 0 errors.
  - **Vitest:** Automated **opaque-sRGB WCAG AA contrast suite** verifying `>= 4.5:1` / `>= 3:1` over actual composited hex pairs in `tokens.css`; unit tests for `extractAndScrubInviteHash()`, `adoptInviteSession()` error cases, `CapabilityRegistry`, backend-derived dashboard readiness (no hardcoded SHA/filename), and `AuthProvider` gating.
  - **Playwright (Mocked Supabase / Dev Preview):** Landing `/` → `/login` → `/forgot-password` → `/access-required` at `1440×900`, `1024×768`, and `390×844` with zero horizontal overflow, user-controlled timetable preview behavior (zero involuntary auto-loop), `prefers-reduced-motion: reduce`, and zero unauthenticated backend calls from `/`.
- **Sub-Phase 1B (Gated Staging Auth Verification — Separate Approval Required):**
  - Live staging auth redirect & non-admin gating verified strictly on the approved isolated staging project.

### 8. Risks
- Removing `framer-motion` in favor of `motion` without updating imports across `PublicAuthLayout` and `AdminShell` causes build failures—verify import path consistency.
- Running live Auth checks prematurely against staging without confirming Supabase Auth Redirect URLs / Edge Function config fails callbacks—verify dashboard auth URLs before Phase 1B.
- Over-animating the public ledger preview could re-introduce the rejected visual style; enforce strict visual review against Academic Ledger anti-slop rules.

### 9. Rollback Considerations
- Phase 1A is confined exclusively to `apps/web/`; revertible cleanly within `apps/web/` without touching Flutter, FastAPI, or Supabase.

### 10. Exit Criteria
- **1A Exit:** Academic Ledger tokens, typography (`Source Serif 4`, `IBM Plex Sans`, `IBM Plex Mono`), light-first public landing page, backend-derived `AdminDashboardPage` readiness (zero hardcoded SHA/filename), Capability Registry, and Vitest/Playwright mocked tests pass.
- **1B Exit (Gated):** Live staging auth verified after owner approval of a clean non-production Supabase project.

### 11. Separate Owner Authorization Required
- **Design Approval Gate (Phase 1A):** Owner approval of Academic Ledger visual brief/spec before implementing Phase 1A UI.
- **Package Approval (Phase 1A):** Owner sign-off on installing verified npm packages from Phase 0 addendum.
- **Staging Auth Gate (Phase 1B):** Explicit authorization & cleared non-prod Supabase target before any live hosted authentication test.

---

## Phase 2 — Administrative Dashboard & Baseline CRUD

### 1. Objective
Implement verified, database-backed administrative workflows in `apps/web/` strictly bound to **existing production PostgreSQL columns** (`timetable_rooms`, `timetable_faculty`, `timetable_course_eligibility`, `timetable_settings`, `whitelists`, `profiles`, `notifications`, `resources`) without fabricating unsupported Phase A/Catalog saves.

### 2. Exact Scope
- **Frontend-Only (`apps/web/`):** Dashboard restyle + 8 verified admin screens + Zod schemas matching real SQL tables; explicit `staged-no-db` lock screens for `Courses` and `Batches`.
- **Zero Backend/Schema Modifications:** All operations target existing tables, RPCs, Storage buckets, and the `invite-admin` Edge Function.

### 3. Relevant Existing Files & Affected Areas
- [`apps/web/src/features/admin/pages/AdminDashboardPage.tsx`](../../apps/web/src/features/admin/pages/AdminDashboardPage.tsx) & [`adminDashboardService.ts`](../../apps/web/src/features/admin/services/adminDashboardService.ts)
- [`apps/web/src/App.tsx`](../../apps/web/src/App.tsx) (replacing `AdminRouteStubPage` entries for Phase 2 routes)
- Reference Contracts: [`lib/features/admin/services/timetable_config_service.dart`](../../lib/features/admin/services/timetable_config_service.dart), [`admin_service.dart`](../../lib/features/admin/services/admin_service.dart), [`notification_service.dart`](../../lib/features/notifications/services/notification_service.dart), [`resource_service.dart`](../../lib/features/resources/services/resource_service.dart), [`supabase/migrations/011_timetable_schedule_config.sql`](../../supabase/migrations/011_timetable_schedule_config.sql), [`013_faculty_course_eligibility.sql`](../../supabase/migrations/013_faculty_course_eligibility.sql), [`015_fixed_sessions_per_week.sql`](../../supabase/migrations/015_fixed_sessions_per_week.sql), [`supabase/functions/invite-admin/handler.js`](../../supabase/functions/invite-admin/handler.js)

### 4. Dependencies
- Phase 1 exit criteria met (Academic Ledger tokens, Capability Registry, React Hook Form + Zod + cmdk + TanStack Query + Recharts verified & installed).
- Phase 0 live schema verification confirming exact columns present on `timetable_rooms` and `timetable_faculty` in the target Supabase environment.

### 5. Entry Criteria
- Owner approval of UI/UX layouts (master-detail inspector, settings grid, user/whitelist layout) under the Mandatory UI/UX Approval Gate.

### 6. Work Items
1. **Command Center (`/admin/dashboard`):**
   - Evolve the Academic Ledger Readiness Checklist (`Rooms`, `Faculty`, `Eligibility & Settings`, `Active Routine` — already cleared of Phase 0 hardcoded filename/SHA placeholders in Phase 1) with live Phase 2 inspection links and optional Recharts v3 room/load summary charts (explicit axes, flat bar tops, sibling-bar hover dimming) derived strictly from real DB data.
2. **Baseline Configuration Screens (Exact DB Columns Only):**
   - `/admin/timetable/rooms`: CRUD on `public.timetable_rooms` (`id, name, building, is_lab, is_gallery, capacity, is_active, dept`; conditionally include `campus, features` only if confirmed in target DB). Surface an honest notice that R10/R11 lab window matrices and R14 term pools are staged until schema promotion (`F-18`).
   - `/admin/timetable/faculty`: CRUD on `public.timetable_faculty` (`id, acronym, full_name, dept, designation, off_days, is_active, courses`) with client-side R7 off-day validation warnings (`2–3` off-days for permanent staff) and clear disclosure that R4/R5/R9 slot matrices are staged (`F-18`).
   - `/admin/timetable/course-eligibility`: Searchable `cmdk` selector + CRUD on `public.timetable_course_eligibility` (`acronym, course_code, is_eligible, priority`) reading course codes dynamically from `routines` + existing eligibility rows (never hardcoded `SchedulingPreviewFixtures`).
   - `/admin/timetable/settings`: Form bound to singleton `public.timetable_settings` (`id = 1`) covering `semester_label`, `working_days`, `periods` (24-hour `ClockTime` normalization), `weeks_in_term`, `fixed_sessions_per_week`, `blocked_periods` (including `friday_no_p4`), `online_periods`, `allow_online_periods`, `excluded_periods`, `semester_map`, `service_scope`, and `weights`.
3. **Operations & Access Screens:**
   - `/admin/users`: Directory over `public.profiles` (role filters, safe role update), `public.whitelists` teacher/admin management (`addTeacherToWhitelist` / delete), and `invite-admin` Edge Function modal (`email`, `name`, exact `redirect_to` origin).
   - `/admin/broadcast`: Compose targeted announcements (`university`, `class_cancel`, `room_change`, `test_reminder`, `assignment`, `exam` matching `check_notif_type`) and inspect/delete `public.notifications` history.
   - `/admin/resources`: Upload files to Storage bucket `resources` (`<semester>/<epoch_ms>_<sanitized_filename>`) or link Drive URLs, manage `public.resources`, and optionally broadcast resource notifications.
   - `/admin/profile`: Inspect own `public.profiles` row, update permitted profile fields, and sign out.
4. **Honest Staged Routes:**
   - Keep `/admin/timetable/courses` and `/admin/timetable/batches` explicitly gated as `staged-no-db` explaining why in-memory Dart stores are not replicated without database backing.

### 7. Verification & Test Requirements
- Strict TypeScript compilation (`tsc --noEmit`) + production build (`vite build`).
- **Vitest:**
  - Zod schema tests validating `timetable_settings` (`weeks_in_term` 1..52, non-overlapping periods, `ClockTime` 24h conversion), `notifications.type` enum matching SQL `check_notif_type`, and payload builders proving **zero non-existent Phase A column keys** are sent to `timetable_rooms` or `timetable_faculty`.
  - Error-handling tests verifying Supabase rejections trigger recoverable error UI (*Service Recovery Paradox*) rather than swallowed exceptions or fake success toasts.
- **Playwright (Mocked Supabase HTTP or Authorized Non-Prod Staging):**
  - 5-state async coverage (`loading`, `first-use empty`, `zero-filter-match`, `error + retry`, `staged-no-db`) across `1440×900`, `1024×768`, and `390×844`.
  - Verify `invite-admin` invocation passes exact `window.location.origin + '/'` (or approved callback URL) and surfaces Edge Function `400`/`403` errors honestly.

### 8. Risks
- Attempting to persist extended R4–R14 fields before schema promotion will cause Postgrest `400` column errors.
- Invoking `invite-admin` against a project where `AUTH_WEB_CALLBACK_URLS` lacks the test origin fails with `400`—requires Phase 0 verification.

### 9. Rollback Considerations
- Each route in `App.tsx` can independently fall back to `AdminRouteStubPage` via capability flag if a specific integration reveals schema drift.

### 10. Exit Criteria
- All 8 baseline admin pages implemented with real Supabase queries, Zod validation, 5-state async handling, and zero swallowed DB errors.
- `Courses` and `Batches` remain honestly staged (`staged-no-db`).
- All Vitest and Playwright checks pass cleanly.

### 11. Separate Owner Authorization Required
- **Design Approval Gate:** Owner approval of Phase 2 admin screen layouts/wireframes before implementation.
- **Testing against Non-Prod Supabase:** Owner authorization required before running live CRUD or `invite-admin` checks against any hosted Supabase staging project.

---

## Phase 3 — Track 1: Operational Routine Console

### 1. Objective
Deliver Track 1 (`/admin/routine` and `/admin/timetable/grid`) featuring the custom CSS Grid + React 2D academic timetable matrix (Section, Faculty, Room lenses + Compact List toggle), live `public.routines` management (`manage`), FastAPI CP-SAT generation with bounded polling and validation blocking (`generate`), and guarded publication—keeping `grid`, `manage`, and `generate` independent of `.xlsx` upload while gating `upload` behind the provisional additive FastAPI parse/validation endpoint.

### 2. Exact Scope
Split cleanly so core Track 1 operational functionality does not block on backend changes:
- **Sub-Phase 3A — Core Track 1 (`grid`, `manage`, `generate`, Guarded Publish — Frontend-Only against existing APIs):** Custom 2D CSS Grid academic timetable matrix + Compact List view, `Manage Published` CRUD, `Generate Routine` FastAPI client + validation gate + JSON draft / `.xlsx` download, and guarded `publish_routine()` pipeline. **Zero dependency on the `.xlsx` upload parse endpoint; zero backend/solver edits required.** *(In-memory `JOBS` remains volatile in Track 1; durable job storage belongs strictly to Track 2 Gate D.)*
- **Sub-Phase 3B — Rendered `.xlsx` Upload Review (`upload` — Gated Behind Separate FastAPI Endpoint Review & Authorization):** Do **not** port `RoutineWorkbookParser` to TypeScript. Keep `/admin/routine?tab=upload` disabled/gated behind Capability Registry until the provisionally preferred **additive, non-mutating FastAPI parse/validation endpoint** (`engine/main.py`) is separately reviewed, equivalence-tested against shared Dart/Python fixtures (keeping Dart's `RoutineWorkbookParser` unchanged initially), and explicitly authorized by the owner.

### 3. Relevant Existing Files & Affected Areas
- [`apps/web/src/App.tsx`](../../apps/web/src/App.tsx) (`/admin/routine`, `/admin/timetable/grid`)
- [`engine/main.py`](../../engine/main.py), [`engine/solver.py`](../../engine/solver.py) (lines 750–998)
- Reference Dart contracts to match/preserve:
  - [`lib/features/admin/services/timetable_engine_service.dart`](../../lib/features/admin/services/timetable_engine_service.dart)
  - [`lib/features/admin/controllers/timetable_gen_controller.dart`](../../lib/features/admin/controllers/timetable_gen_controller.dart) (`blockingValidationErrorFor` lines 493–556, polling lines 261–297)
  - [`lib/features/admin/controllers/routine_upload_controller.dart`](../../lib/features/admin/controllers/routine_upload_controller.dart)
  - [`lib/features/admin/services/routine_workbook_parser.dart`](../../lib/features/admin/services/routine_workbook_parser.dart) (kept unchanged initially; fixture source for FastAPI parse equivalence)
  - [`lib/core/utils/clock_time.dart`](../../lib/core/utils/clock_time.dart), [`room_identity.dart`](../../lib/core/utils/room_identity.dart)
  - [`lib/core/models/routine_model.dart`](../../lib/core/models/routine_model.dart)
  - [`test/routine_workbook_parser_test.dart`](../../test/routine_workbook_parser_test.dart), [`clock_time_test.dart`](../../test/clock_time_test.dart)

### 4. Dependencies
- Phase 2 exit criteria met (`timetable_rooms`, `timetable_faculty`, `timetable_course_eligibility`, and `timetable_settings` read/write working so `buildEngineConfig()` assembles accurate solver payloads).
- **Sub-Phase 3B Additional Dependency:** Separate review & owner authorization of the additive, non-mutating FastAPI parse/validation endpoint in `engine/main.py` plus shared fixture equivalence tests.

### 5. Entry Criteria
- Owner UI/UX approval of the custom 2D Academic Timetable Grid layout (Section/Faculty/Room lens switcher, Matrix ↔ Compact List toggle, corner-triangle override indicators + Radix tooltips, docked inspector, break dividers, Jummah hatching) and the Track 1 Routine Operations workflow.

### 6. Work Items
1. **Custom CSS Grid + React 2D Timetable Matrix (`/admin/timetable/grid` & Tab 0 — Phase 3A):**
   - Build responsive custom CSS Grid matrix (no Gregorian calendar library) supporting **Section**, **Faculty**, and **Room** perspectives, **Matrix ↔ Compact List** switching, `B+C` joint section handling (`matchesStudent` parity), `is_service` filtering/labeling, midday break divider, Friday P4 Jummah hatching, connected filter bar (`/` shortcut, `cmdk` selects, upfront option-level counts, live tabular match count), corner-triangle override indicators + Radix tooltips, and docked `360px` provenance inspector at `>= 1100px` (modal/sheet below `1100px`).
   - Support inspecting either live `public.routines` rows or in-session generated preview rows (with clear banner when viewing unpublished candidate rows).
2. **Manage Published Routine Tab (`/admin/routine?tab=manage` — Phase 3A):**
   - Full CRUD over `public.routines` with client-side clash warnings (teacher/room/cohort overlap checks before save), explicit disclosure that manual edits modify active student/teacher schedules immediately without creating a new `routine_versions` entry (`F-23`), contextual multi-select bulk actions, Invisible UI hover/focus-within actions, inactive-row dimming, and `HH:MM:SS` `ClockTime` formatting.
3. **CP-SAT Generation Wizard Tab (`/admin/routine?tab=generate` — Phase 3A):**
   - Assemble engine `config` payload dynamically from live Supabase `timetable_rooms`, `timetable_faculty`, `timetable_course_eligibility`, and `timetable_settings` (matching `TimetableConfigService.buildEngineConfig()`, normalizing periods to `HH:MM`).
   - Support uploading a `Course Distribution` `.xlsx` file (and optionally loading a `GenerationProfile` JSON rehearsal profile with CRC32/byte-length check that forces preview-only mode and blocks publication).
   - Submit `multipart/form-data` to `POST /api/timetable/generate` (`time_limit_s: 180`), run bounded `2s` polling up to `240` polls (`+4s` backoff on `429`, fail on 5th consecutive non-429 error), and display a 4-stage solver timeline (`queued → ingesting → solving → rendering`) honoring volatile `JOBS` recovery cleanly (durable job storage remains deferred to Track 2 Gate D).
   - Implement exact 20-counter `blockingValidationErrorFor` gate (`missing_courses`, `under_scheduled`, `over_scheduled`, `unexpected_courses`, `teacher_clashes`, `cohort_clashes`, `room_clashes`, `same_day_sessions`, `ineligible_assignments`, `dayoff_violations`, `blocked_period_violations`, `lab_room_violations`, `unplaced_rooms`, `lab_theory_violations`, `invalid_time_slots`, `invalid_days`, `teacher_assignment_mismatches`, `unknown_rooms`, `room_capacity_violations`, `unresolved_teachers`, plus `ok === true`).
   - Enforce **Co-Teacher Pre-Publish Guard** (`teachers.length > 1` blocks `publish_routine`, allowing only private JSON draft download or `.xlsx` download, `F-22`) and **Empty-Config Pre-Publish Guard** (`F-20`).
   - Support `.xlsx` download via `/api/timetable/download/{job_id}` and private JSON draft export (`universe-routine-draft-v1`).
4. **3-Step Guarded Publication Pipeline (`generate` in Phase 3A; shared by `upload` in Phase 3B):**
   - Explicit confirmation modal disclosing that `publish_routine()` **atomically replaces the entire active `public.routines` table and wipes prior rows** (`F-21`).
   - Step 1: Upload `.xlsx` to Storage bucket `timetables` (`CSE_Routine_<label>_<epoch_ms>.xlsx`).
   - Step 2: Call `supabase.rpc('publish_routine', ...)` passing `rows` + `service_rows` (`is_service: true`).
   - Step 3 (Best-effort with Service Recovery Paradox): Insert `timetable_runs` history row and optional `notifications` broadcast; if Step 3 fails after Step 2 succeeds, preserve published state and surface a clear secondary warning.
5. **Rendered `.xlsx` Upload & Parse Review Tab (`/admin/routine?tab=upload` — Gated Sub-Phase 3B):**
   - Keep `upload` cleanly gated (`staged` / `requires-endpoint-authorization`) until owner separately reviews and authorizes an **additive, non-mutating FastAPI parse/validation endpoint** in `engine/main.py`.
   - Once authorized, validate Python parse/validation output against shared fixtures mirrored from Dart's `RoutineWorkbookParser` (`day` sheets, fallback tabular sheets, `ClockTime.repairSequence`, `RoomIdentity.key`, 5 clash checks), leaving Flutter's Dart parser untouched initially, then wire `/admin/routine?tab=upload` to review returned diagnostics and feed Step 4 guarded publish.

### 7. Verification & Test Requirements
- **Vitest (Phase 3A):**
  - Logic unit tests comparing TypeScript `buildEngineConfig()`, `blockingValidationErrorFor()`, `ClockTime` (`HH:MM` / `HH:MM:SS`), and co-teacher/empty-config/rehearsal-profile publish blockers against canonical fixtures.
  - Mocked polling tests covering `429` backoff, 5-error disconnect threshold, and `failed`/`404` solver state recovery.
- **Python `pytest` + Cross-Parser Fixture Parity (Phase 3B — Gated):**
  - Validate the authorized additive FastAPI parse/validation endpoint against shared JSON/workbook fixtures exported from `test/routine_workbook_parser_test.dart` without touching Flutter's `RoutineWorkbookParser` implementation.
- **Playwright (Phase 3A + 3B):**
  - Mocked FastAPI + Supabase E2E walkthroughs across Grid lenses (`Section`, `Faculty`, `Room`), Matrix ↔ Compact List switch, Manage CRUD, Generate polling timeline + 3-step publish confirmation (and Upload review once Phase 3B is authorized), across `1440px`, `1024px`, and `390px`.
- **Local Integration Check (Only When Explicitly Authorized Against Local FastAPI + Approved Staging DB):**
  - Run `engine/main.py` locally (`uvicorn main:app --port 8000`) against non-PII synthetic test fixture workbook to confirm CORS and live multipart job cycle.

### 8. Risks
- Render free-tier cold starts (`> 5s` health check, `512 MB` OOM, or mid-solve restart wiping volatile `JOBS`) can fail jobs unless polling error recovery clearly distinguishes `404 Unknown job_id` from transient network drops.
- Differences between the additive FastAPI parse endpoint (Phase 3B) and Flutter's existing `RoutineWorkbookParser` could shift slots unless verified against shared fixtures before enabling uploads.

### 9. Rollback Considerations
- Phase 3A adds zero database or engine changes; rolling back reverts `/admin/routine` and `/admin/timetable/grid` without affecting production data or Flutter Mobile. Sub-Phase 3B can stay feature-flagged/gated independently while `grid`, `manage`, and `generate` remain live. Any live `publish_routine()` test must occur strictly on approved clean staging data, keeping `.xlsx` backups in `timetables` bucket.

### 10. Exit Criteria
- **3A Exit:** Custom 2D Timetable Matrix + Compact List verified across all 3 lenses and supported viewports; `grid`, `manage`, `generate`, and guarded publish pass Vitest and Playwright checks with zero regression to Flutter Mobile (`public.routines` contract intact) and `upload` cleanly gated.
- **3B Exit (After Separate Engine Review/Authorization):** Additive FastAPI parse/validation endpoint verified against shared `RoutineWorkbookParser` fixtures; `upload` review flow operational.

### 11. Separate Owner Authorization Required
- **Design Approval Gate (Phase 3A):** Owner approval of 2D Timetable Matrix and Track 1 Routine Operations UI/UX.
- **FastAPI Endpoint Authorization Gate (Phase 3B):** Separate review and explicit owner authorization before implementing the additive, non-mutating `.xlsx` parse/validation endpoint in `engine/main.py`.
- **Local/Staging Solver Execution:** Explicit approval before executing test solves against hosted Render or clean staging Supabase.

---

## Phase 4 — Track 2: Committee Scheduling Workbench (Gates A–D)

### 1. Objective
Implement the advanced Track 2 Committee Scheduling Workbench (`/admin/scheduling`) covering immutable Course Distribution revisions (`CD1` `A`–`L`), audited cell corrections, R1–R16 committee policy configuration, authoritative validation, and recoverable atomic publication—strictly unlocking **Gates A, B, C, and D** only as their backend contracts are promoted and verified.

### 2. Exact Scope
Split cleanly into backend promotion (**4A — Separate Authorization**) and frontend implementation (**4B — Frontend-Only**):
- **Phase 4A (Backend / Database / FastAPI — Separate Authorization Required):**
  - Promote and verify `20261022140809_academic_catalog.sql` and `20261106130000_course_distribution_contract.sql` in target Supabase.
  - Design and migrate persistent storage for Catalog Courses, Batches/Sections (`cohorts`/`student_groups` + R1–R2 weekend rules), Phase A Faculty/Room R4–R14 matrices, and `PolicySnapshot` (Gate C).
  - Implement server-side/FastAPI R1–R16 CP-SAT constraint integration (`engine/solver.py` + `engine/domain.py`), durable solver job persistence, multi-teacher `routines` storage (`teacher_codes`), and snapshot-recoverable `publish_routine()` (Gate D).
- **Phase 4B (Frontend `apps/web/`):**
  - 5-stage workbench UI (`Distribution`, `Configuration`, `Readiness`, `Generate`, `Review & Publish`) wired to the Capability Registry so Gates A–D unlock independently only when verified backend RPCs exist.

### 3. Relevant Existing Files & Affected Areas
- [`supabase/migrations/20261022140809_academic_catalog.sql`](../../supabase/migrations/20261022140809_academic_catalog.sql)
- [`supabase/migrations/20261106130000_course_distribution_contract.sql`](../../supabase/migrations/20261106130000_course_distribution_contract.sql)
- [`supabase/tests/course_distribution_contract.test.sql`](../../supabase/tests/course_distribution_contract.test.sql), [`course_distribution_authorization.test.sql`](../../supabase/tests/course_distribution_authorization.test.sql)
- [`engine/distribution.py`](../../engine/distribution.py), [`engine/domain.py`](../../engine/domain.py), [`engine/solver.py`](../../engine/solver.py)
- [`docs/timetable-audit-2026-10-20/16-committee-traceability-2026-11-04.md`](../timetable-audit-2026-10-20/16-committee-traceability-2026-11-04.md), [`18-committee-decisions-and-policy-baseline-2026-11-04.md`](../timetable-audit-2026-10-20/18-committee-decisions-and-policy-baseline-2026-11-04.md)
- Reference Dart model bugs to avoid: [`lib/features/admin/scheduling/controllers/scheduling_workspace_controller.dart`](../../lib/features/admin/scheduling/controllers/scheduling_workspace_controller.dart) (lines 48–108, `F-19`)

### 4. Dependencies
- Phase 3 exit criteria completed.
- **Gate A/B Frontend Prerequisites:** `20261022140809_academic_catalog.sql` + `20261106130000_course_distribution_contract.sql` applied and pgTAP-verified in target Supabase (`F-19`).
- **Gate C/D Frontend Prerequisites:** Separate backend migrations and FastAPI R1–R16 solver updates verified.

### 5. Entry Criteria
- Owner explicitly authorizes Phase 4A backend contract promotion/migrations for the target environment.
- Owner approves UI/UX design brief for the 12-column Course Distribution table (`TanStack Table + TanStack Virtual`), 5-part provenance inspector, and R1–R16 policy console.

### 6. Work Items
#### Phase 4A — Backend Promotion & Contract Completion (Requires Separate Authorization)
1. Apply and verify `20261022140809` + `20261106130000` (including SQL verification of `course_distribution_*` tables, triggers, RLS, and RPCs via SQL Editor / connected plugin).
2. Add missing schema contracts for **Courses**, **Batches/Sections** (unlocking `/admin/timetable/courses` and `/admin/timetable/batches`), R1–R16 policy snapshots, and `PolicySnapshot` validation (Gate C).
3. Upgrade `engine/solver.py` + `engine/main.py` for remaining R1–R16 committee rules, durable job records, and upgrade `publish_routine()` + Flutter mobile `RoutineEntry` compatibility for co-teacher persistence and recoverable version archives (Gate D).

#### Phase 4B — React Web Track 2 Implementation (`/admin/scheduling`)
1. **Gate A (Distribution Revision Read):**
   - Query `course_distribution_revisions` joined with `course_distribution_sources` using **exact SQL column names** (`revision_version`, `scheduling_scope_id` — avoiding Flutter's `version`/`scope_id` bug, `F-19`).
   - Invoke `read_course_distribution_revision(target_revision)` to load immutable source metadata and correction overlays without modifying source bytes.
2. **Gate B (Audited Corrections & Optimistic Concurrency):**
   - Render virtualized 12-column Course Distribution ledger (`A`–`L`) via `TanStack Table` + `TanStack Virtual`, displaying original formula/cached values (`J`/`L`), proposed edits, correction provenance, and merged-row conflicts.
   - Save cell corrections strictly via the **8-parameter RPC** `append_course_distribution_correction(target_revision, expected_revision_version, target_row, target_column, prior_formula, prior_cached_value, next_effective_value, reason)` (`F-19`).
   - Catch SQLSTATE `40001` (`Stale course distribution revision`), preserve unsaved edit input, reload latest `revision_version`, and display `course_distribution_artifacts` `stale` banners.
3. **Gate C (R1–R16 Policy Persistence & Authoritative Validation):**
   - Unlock persisted R1–R16 policy editors (replacing `staged-no-db` banners on Courses, Batches, and extended Faculty/Room matrices) bound to `PolicySnapshot` and server `validation_report` artifacts.
4. **Gate D (Revision-Bound Solve & Recoverable Atomic Publication):**
   - Trigger `POST /api/timetable/generate` carrying `source_contract` (`source_id`, `revision_id`, `revision_number`, `revision_version`, `status`, `source_sha256`, `corrections`), enforce artifact freshness (`canPublish`), inspect diff against active version, and publish atomically with rollback support.

### 7. Verification & Test Requirements
- **Database (via SQL Editor / pgTAP on test project):** Re-verify all 28 assertions in `course_distribution_contract.test.sql` and `course_distribution_authorization.test.sql`, plus new policy/publish tests.
- **Python (`engine/`):** `pytest` coverage across `test_distribution_contract.py`, `test_distribution_generation_boundary.py`, and new R1–R16 solver tests.
- **Frontend (`apps/web/`):**
  - Vitest tests asserting exact 8-param RPC arguments, `40001` stale-revision conflict recovery, and fail-closed lock behavior whenever any Gate A–D capability flag is `false`.
  - Playwright E2E across all 5 scheduling stages, virtualized table scrolling, formula/cached-value warnings, and conflict inspector navigation.
- **Flutter Mobile Regression Check:** Verify `flutter test` passes if `public.routines` adds co-teacher fields (`RoutineEntry.fromMap` compatibility).

### 8. Risks
- Unlocking Gate B before `20261106130000` is promoted or using Flutter's mismatched 6-param RPC shape guarantees runtime failures.
- Adding co-teacher arrays or modifying `public.routines` without verifying Flutter Mobile's `RoutineEntry.fromMap` and `TeacherLocationService` breaks live Android app features.

### 9. Rollback Considerations
- Each Gate A–D is behind an independent Capability Registry flag—disabling a gate immediately restores fail-closed read-only/locked mode on the frontend without redeploying backend changes.
- Database schema changes in Phase 4A must be strictly additive or provide reversible down-scripts before production promotion.

### 10. Exit Criteria
- All 4 Gates A–D independently verified end-to-end against real database contracts.
- Zero simulated saves; `40001` optimistic concurrency and artifact staleness proven under test.
- Full R1–R16 committee workflow operational in React Web without breaking Flutter Mobile.

### 11. Separate Owner Authorization Required
- **Mandatory Separate Authorization (Phase 4A):** Promoting `20261022140809` / `20261106130000`, authoring new policy/snapshot/co-teacher migrations, modifying `publish_routine()`, and updating `engine/solver.py` / `engine/main.py` all require explicit owner approval separate from approving the Phase 4B React Web UI.

---

## Phase 5 — Security Hardening, Cross-Platform Regression & Production Cutover

### 1. Objective
Close backend security exposures (FastAPI authentication/CORS, Supabase RLS/Storage scoping), verify cross-platform Flutter Android, iOS compatibility, and React Web behavior, establish CI/CD pipelines, and execute production deployment to Cloudflare Pages (or owner-approved host).

### 2. Exact Scope
Split into three independently authorized sub-phases:
- **5A — FastAPI 5-Step Dual-Client JWT & CORS Hardening** (`engine/main.py` + coordinated Flutter `TimetableEngineService` dual-client headers; CP-SAT solver unchanged; durable job storage remains in Track 2 Gate D).
- **5B — Supabase RLS & Storage Hardening** (SQL policies in `supabase/migrations/`).
- **5C — Cloudflare Pages Config, CI/CD, Android + iOS Compatibility & Production Cutover** (`apps/web/public/_redirects`, `.github/workflows/`, hosted Supabase Auth / Edge Functions / Cloudflare Pages).

### 3. Relevant Existing Files & Affected Areas
- [`engine/main.py`](../../engine/main.py) (`CORSMiddleware`, routes)
- [`lib/features/admin/services/timetable_engine_service.dart`](../../lib/features/admin/services/timetable_engine_service.dart) (`F-12`)
- [`supabase/migrations/006_enable_rls_all_tables.sql`](../../supabase/migrations/006_enable_rls_all_tables.sql), [`008_rls_timetable_config.sql`](../../supabase/migrations/008_rls_timetable_config.sql), [`013_faculty_course_eligibility.sql`](../../supabase/migrations/013_faculty_course_eligibility.sql) (`F-17`)
- [`supabase/functions/invite-admin/callback_policy.js`](../../supabase/functions/invite-admin/callback_policy.js)
- [`.github/workflows/validate.yml`](../../.github/workflows/validate.yml)
- `apps/web/public/_redirects`, `apps/web/public/_headers` (new in 5C)

### 4. Dependencies
- Phases 1–3 complete (and Phase 4A/4B complete if launching Track 2 simultaneously, or Track 2 can remain safely locked behind Gates A–D while launching Track 1).
- Phase 0 confirmed no non-admin Flutter Mobile code reads `timetable_*` or other users' `profiles` rows (`F-13`).

### 5. Entry Criteria
- Explicit owner authorization for each sub-phase (`5A`, `5B`, `5C`) individually.
- All frontend Vitest + Playwright suites and Python pytest suites green.

### 6. Work Items
#### Phase 5A — FastAPI 5-Step Dual-Client JWT & CORS Hardening (Separate Engine + Flutter Coordination)
> **Scope Boundary:** Preserve the CP-SAT solver untouched; durable job storage belongs strictly to **Track 2 Gate D**, not minimal Track 1 / Phase 5A security hardening.

1. **Inspect Flutter Request Headers:** Confirm Flutter `TimetableEngineService` baseline (`F-12`: currently sends no `Authorization` header).
2. **Prepare Dual-Client JWT Compatibility:** Update Flutter's `lib/features/admin/services/timetable_engine_service.dart` AND `apps/web/`'s FastAPI client to attach Supabase `Authorization: Bearer <access_token>` on `/api/timetable/*` requests **prior** to server enforcement.
3. **Environment-Driven CORS & Gradual JWT Verification:** Update `engine/main.py` to enforce environment-driven CORS `allow_origins` (replacing `["*"]`) and add non-blocking / gradual Supabase JWT verification mode alongside dual-client telemetry while keeping `GET /` lightweight health status intact.
4. **Verify Both Mobile Clients & React Web Before Enforcement:** Test Flutter Android, iOS compatibility (API requests & callbacks), and React Web against dual-client mode cleanly before strict blocking.
5. **Enforce Production Authentication:** Switch FastAPI JWT (`admin` role) verification to strict enforcement only after dual-client compatibility is demonstrated (`401`/`403` for unauthenticated or non-admin requests).

#### Phase 5B — Supabase RLS & Storage Scoping (Separate Database Authorization)
1. Tighten `profiles_select` from `using (true)` to `id = auth.uid() or public.is_admin()` (safe per `F-13` and `F-29`: non-admin Flutter queries only `eq('id', userId)`, and `send-push` uses `SUPABASE_SERVICE_ROLE_KEY`).
2. Fix `013_faculty_course_eligibility.sql` `read_all` (`to public`) → `to authenticated`, and evaluate restricting `timetable_rooms`, `timetable_faculty`, `timetable_settings`, `timetable_runs`, and `timetable_course_eligibility` SELECT to `public.is_admin()` or `academic_private.can_directory()` (`F-13`, `F-17`).
3. Replace generic `storage_auth_insert/update/delete` (`using (true)`) on `storage.objects` with bucket-scoped rules (`F-30` confirms zero existing `lib/` uploads to `avatars`):
   - `timetables`: `public.is_admin()` only.
   - `resources`: `public.my_role() in ('teacher', 'admin')` (preserving teacher/admin resource uploads while blocking student overwrites).
   - `avatars`: owner-scoped (`(storage.foldername(name))[1] = auth.uid()::text`) or admin-only until mobile upload conventions are formally introduced.
4. Standardize remaining `SECURITY DEFINER` helpers (`my_role`, `is_admin`, `guard_profile_role`, `register_device_token`) to `set search_path = ''` with fully qualified `public.` references.

#### Phase 5C — Hosting, CI/CD & Cross-Platform Regression Cutover (Separate Hosting/Auth Authorization)
1. Add `apps/web/public/_redirects` (`/* /index.html 200`) and security `_headers` (CSP, `X-Frame-Options`, `Referrer-Policy`) for Cloudflare Pages (`F-27`).
2. Extend `.github/workflows/validate.yml` with an `apps/web` CI job (`npm ci`, `npm run typecheck`, `npm test` Vitest, `npm run build`, and Playwright headless smoke checks) plus `deno test` for `supabase/functions/invite-admin/*`.
3. Register exact Cloudflare Pages production/preview URLs in:
   - Supabase Dashboard → Authentication → URL Configuration (**Redirect URLs**).
   - Google Cloud Console OAuth authorized origins/callbacks (if needed by Supabase OAuth flow).
   - `invite-admin` Edge Function `AUTH_WEB_CALLBACK_URLS` secret.
4. Configure Cloudflare Pages environment variables (`VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, `VITE_TIMETABLE_BASE_URL`, `VITE_ENABLE_SCHEDULING_PREVIEW_ROUTE=false`).
5. **Execute Cross-Platform Android & iOS Compatibility Verification:** Run Android regression checks (`flutter test`, `flutter analyze`, real/emulator sign-in + Student/Teacher routine + Find Teacher + Rooms + Cancellation alerts), verify **iOS compatibility preservation** (`ios/Runner/Info.plist` schemes `io.supabase.universe`/`com.example.universe`, `AuthCallbackPolicy`, deep-link / backend contract regression tests—active new iOS feature expansion remains deferred), alongside live React Web smoke walkthrough (Admin login, Google OAuth, `invite-admin`, password reset, Engine health, Dashboard).

### 7. Verification & Test Requirements
- **FastAPI:** Negative auth tests (`401` missing/invalid JWT, `403` non-admin Student/Teacher JWT, `200` valid Admin JWT), gradual-mode compatibility checks, and CORS preflight checks from disallowed vs. allowed origins.
- **Supabase RLS (via SQL Editor negative tests):** Verify Student JWT **cannot** `SELECT` another student's `profiles` row, **cannot** write `timetables` Storage bucket, **cannot** read `timetable_*` config (if restricted), while **still** successfully loading `routines`, `cancellations`, `notifications`, `resources`, and own `profiles` row.
- **CI/CD & Web Production Build:** All `.github/workflows/validate.yml` jobs green; SPA hard-refresh on `/login`, `/admin/dashboard`, `/admin/routine` returns `200` on Cloudflare Pages.
- **Flutter Android & iOS Compatibility Regression:** Full `flutter analyze` and `flutter test` pass; Student/Teacher Android flows and shared iOS URL scheme/callback/API compatibility contracts verified intact.

### 8. Risks
- Tightening `storage.objects` `avatars` policy without checking Flutter's exact avatar upload path prefix breaks mobile avatar updates.
- Enforcing FastAPI JWT auth before updating Flutter's `TimetableEngineService` breaks any admin still using Flutter APK/Web to generate routines.
- Missing a Cloudflare Pages origin in Supabase Auth Redirect URLs or `AUTH_WEB_CALLBACK_URLS` breaks Google OAuth or `invite-admin` links after cutover.

### 9. Rollback Considerations
- **Frontend/Cloudflare Pages:** Instant deployment rollback to previous build in Cloudflare Pages dashboard.
- **FastAPI:** Revert `CORS` / JWT enforcement commit on Render or toggle feature env flag if urgent emergency generation is required.
- **Supabase RLS:** Keep pre-hardening policy restore SQL ready so any broken mobile read can be diagnosed and reverted cleanly via SQL Editor.

### 10. Exit Criteria
- FastAPI authenticated and CORS-restricted; Flutter & React Web synchronized.
- Supabase RLS & Storage policies hardened with zero mobile regression.
- CI/CD green across Python, Deno, SQL, Flutter, and React Web.
- Production React Web live on owner-approved domain with verified PKCE OAuth, `invite-admin`, Track 1 operational flows, and fail-closed Track 2 gates (or unlocked Track 2 if Phase 4 completed).

### 11. Separate Owner Authorization Required
- **Mandatory Separate Authorizations:**
  1. Modifying and redeploying `engine/main.py` on Render (Phase 5A).
  2. Applying RLS/Storage SQL migrations to production Supabase `yxqyrjyzxitrgkhgauli` (Phase 5B).
  3. Creating/deploying Cloudflare Pages site, modifying Supabase Auth Redirect URLs, deploying/configuring Edge Function `AUTH_WEB_CALLBACK_URLS`, and running live production smoke verification (Phase 5C).
