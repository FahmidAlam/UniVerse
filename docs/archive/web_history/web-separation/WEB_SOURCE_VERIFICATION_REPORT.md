# UniVerse — Standalone React Web Source Verification Report

> **Audit Scope:** Strictly read-only repository inspection of `apps/web/`, `lib/`, `engine/`, `supabase/`, `.github/`, `.agents/`, and project governance/architecture documentation on working tree branch `feature/react-admin-web-v1`.
> **Verification Date:** 21 November 2026
> **Safety Compliance:** Zero application code, Flutter code, Python engine code, SQL migrations, or package dependencies were modified. No live Supabase writes, Supabase CLI commands, or hosted auth tests were executed. All secrets/tokens are redacted (`<REDACTED>`).

---

## Evidence Classification Legend

| Tag | Meaning |
|---|---|
| `VERIFIED` | Directly observed and confirmed in inspected repository source files or local command output. |
| `PARTIALLY VERIFIED` | Relevant source exists in the repository, but end-to-end behavior depends on unverified runtime/hosted state or has partial gaps. |
| `CONTRADICTED` | Inspected repository source directly conflicts with prior documentation, phase reports, or the approved strategic blueprint. |
| `NOT VERIFIED` | Required source, external service state, or hosted configuration is absent from the local repository and cannot be confirmed without external inspection. |
| `RECOMMENDATION` | Architectural or remediation advice derived from verified findings rather than an assertion of existing behavior. |

---

## Executive Summary of Critical Findings

1. **Discrepancy Confirmed (`approved_users` vs. `public.whitelists`):** Prior Phase 0/1 documentation (`docs/implementation/web_phase_0_1_spatial_orbit_foundation.md:51,79`) erroneously claims `AuthProvider.tsx` checks `approved_users`. Source inspection proves `AuthProvider.tsx:214-219`, Flutter (`app_constants.dart:102`), `invite-admin` (`handler.js:75`), and SQL (`006_enable_rls_all_tables.sql:94`) universally use **`public.whitelists`**.
2. **Design System Mismatch in `apps/web/`:** Existing `apps/web/` implements the superseded **Spatial Orbit Engine** theme (Light+Dark switcher, dark slate `#0F...`/OKLCH, spectral cyan-emerald, `Space Grotesk`, 3D CSS perspective tilt, fluted bezel, continuous orbital SVG animations). Aligning with the newly approved **UniVerse Academic Ledger** blueprint (`Source Serif 4`, light-first, Deep Botanical Pine, Charcoal Ink, flat 2D/restrained motion) requires replacing `tokens.css`, `app.css`, `index.html`, `ThemeProvider`/`ThemeSwitcher`, and `SpatialOrbitStage.tsx`.
3. **Flutter Mobile Safe from `profiles`/`timetable_faculty` RLS Tightening:** `TeacherLocationService` and `RoomStatusService` query **only `public.routines`** (`is_active = true`). Non-admin Flutter users only query their **own** `public.profiles` row (`id = user.id`) and never read `timetable_faculty` or `timetable_rooms`. Tightening `profiles_select` and `timetable_*` SELECT policies will **not** break Student or Teacher mobile flows.
4. **FastAPI Unauthenticated & Wildcard CORS:** `engine/main.py:18-23,104-189` uses `allow_origins=["*"]` with zero JWT or API-key authentication on any endpoint, stores jobs in a volatile process-local dictionary (`JOBS`), and Flutter sends no `Authorization` header (`timetable_engine_service.dart:153-259`).
5. **Permanent Wipe Risk in `publish_routine()` & Co-Teacher Blocker:** `014_publish_routine_safeupdate.sql:78-79` runs `delete from public.routines where true;` without archiving deleted rows in `routine_versions`. Additionally, `public.routines` lacks multi-teacher columns, forcing client code to reject publishing any routine containing co-teachers (`requiresSharedTeacherStorage == true`).
6. **Silent Persistence Gaps & RPC Signature Mismatches in Flutter Config/Scheduling:** `CatalogCourse` and `CohortBatch` are 100% in-memory in Dart; `TimetableRoom.toMap()` and `TimetableFaculty.toMap()` emit 11 Phase A columns absent from SQL while `TimetableConfigService` silently swallows DB errors (`catch (_) {}`); and `SupabaseSchedulingWorkspaceGateway` calls `append_course_distribution_correction` with wrong parameter names/count (`6` `p_*` params vs. `8` SQL params) and wrong column names (`version`/`scope_id` vs. `revision_version`/`scheduling_scope_id`).

---

## 1. Repository Structure

### `F-01` — Workspace Layout & Pre-Existing `apps/web/` Foundation
- **Category:** Repository Structure
- **Status:** `VERIFIED`
- **File Paths:** `apps/web/`, `lib/`, `engine/`, `supabase/`, `docs/`, `.agents/skills/`
- **Relevant Evidence:** Directory listings via `Get-ChildItem`
- **What Source Demonstrates:** `apps/web/` exists and contains 34 authored source/config files (`package.json`, `vite.config.ts`, `tsconfig*.json`, `index.html`, `.env.example`, `src/App.tsx`, `src/main.tsx`, `src/styles/`, `src/services/`, `src/shared/`, `src/features/`), plus local `node_modules/` and build output `dist/`. `lib/`, `engine/`, and `supabase/` remain intact alongside it.
- **Agreement / Conflict:** Confirms the existence of the reported Phase 0/1 React web foundation at `apps/web/`.
- **Consequences:** Phase 1 implementation can evolve `apps/web/` incrementally rather than bootstrapping from scratch, after auditing/replacing Spatial Orbit assets.
- **Recommended Follow-Up:** Archive or refactor superseded `Spatial Orbit` components during Roadmap Phase 1.

### `F-02` — Uncommitted Working-Tree State on Branch `feature/admin-web-extension`
- **Category:** Repository Structure
- **Status:** `VERIFIED`
- **File Paths:** `AGENTS.md`, `CLAUDE.md`, `.agents/skills/react-web-academic-design-system/SKILL.md`, `.agents/skills/react-web-motion-and-craft/SKILL.md`, `apps/`, `docs/architecture/WEB_*.md`, `docs/implementation/web_phase_0_1_spatial_orbit_foundation.md`
- **Relevant Evidence:** `git status --short` output
- **What Source Demonstrates:** Four tracked files (`AGENTS.md`, `CLAUDE.md`, and two `.agents/skills/react-web-*` files) have uncommitted modifications introducing `Spatial Orbit Engine` rules, and `apps/` plus four `docs/` design/completion files are untracked.
- **Agreement / Conflict:** Explains why governance docs currently reflect the superseded `Spatial Orbit Engine` work performed immediately prior to this audit.
- **Consequences:** All uncommitted user work must remain untouched during this read-only audit; governance alignment should occur explicitly in Phase 0.
- **Recommended Follow-Up:** Preserve current working tree; reconcile governance files only after owner approves Phase 0.

---

## 2. React Web Implementation (`apps/web/`)

### `F-03` — `apps/web/package.json` Installed vs. Preferred Dependencies
- **Category:** React Web Implementation
- **Status:** `VERIFIED`
- **File Path:** [`apps/web/package.json`](../../../apps/web/package.json)
- **Configuration Keys:** `dependencies` (lines 12–24), `devDependencies` (lines 25–34), `scripts` (lines 6–11)
- **What Source Demonstrates:**
  - **Installed & matching blueprint:** `react@^19.1.0`, `react-dom@^19.1.0`, `react-router-dom@^7.6.2`, `@tanstack/react-query@^5.80.7`, `@supabase/supabase-js@^2.50.0`, `@phosphor-icons/react@^2.1.7`, `tailwindcss@^4.1.8`, `@tailwindcss/vite@^4.1.8`, `vite@^6.3.5`, `typescript@^5.8.3`, `@radix-ui/react-dialog@^1.1.14`, `@radix-ui/react-dropdown-menu@^2.1.15`, `@radix-ui/react-tooltip@^1.2.7`.
  - **Installed but unused in `apps/web/src/`:** `@radix-ui/react-switch@^1.2.5` (line 16).
  - **Installed overlapping/older naming:** `framer-motion@^12.16.0` (line 20) instead of `motion`.
  - **Preferred stack not yet installed:** `shadcn/ui` CLI/components, `cmdk`, `@tanstack/react-table` (v8/v9), `@tanstack/react-virtual`, `recharts` (v3), `react-hook-form`, `zod`, `zustand`, `vitest`, `@playwright/test`.
- **Agreement / Conflict:** Partially aligns with the preferred stack; lacks form, table, virtualization, chart, client state, combobox, and testing packages. Note also that the blueprint references **TanStack Table v9** and **Recharts v3**, whose React 19 compatibility and stable package versions require verification before installation.
- **Consequences:** Attempting to implement dense Course Distribution tables, load charts, or automated tests without first checking React 19 peer dependencies could introduce build breaks or overlapping libraries (`motion` vs `framer-motion`).
- **Recommended Follow-Up:** Audit npm registry peer dependencies for `@tanstack/react-table` (v8 vs v9), `recharts` v3, `cmdk`, and `motion` vs `framer-motion` in Phase 0 before installing.

### `F-04` — Superseded `Spatial Orbit Engine` Visual Theme Conflicts with `UniVerse Academic Ledger`
- **Category:** React Web Implementation
- **Status:** `CONTRADICTED`
- **File Paths:** [`apps/web/index.html`](../../../apps/web/index.html), [`apps/web/src/styles/tokens.css`](../../../apps/web/src/styles/tokens.css), [`apps/web/src/styles/app.css`](../../../apps/web/src/styles/app.css), [`apps/web/src/shared/theme/ThemeProvider.tsx`](../../../apps/web/src/shared/theme/ThemeProvider.tsx), [`apps/web/src/shared/components/ThemeSwitcher.tsx`](../../../apps/web/src/shared/components/ThemeSwitcher.tsx), [`apps/web/src/features/onboarding/components/SpatialOrbitStage.tsx`](../../../apps/web/src/features/onboarding/components/SpatialOrbitStage.tsx)
- **Relevant Symbols:** `html[data-theme="dark"]` (`tokens.css:82-126`), `ThemeSwitcher` (`ThemeSwitcher.tsx:18-70`), `orbitSpinCw` / `orbitSpinCcw` / `conduitFlow` (`app.css:221-295`), `planeTransform` (`SpatialOrbitStage.tsx:152`)
- **What Source Demonstrates:**
  - `index.html:16` loads `Space Grotesk`, `IBM Plex Sans`, and `JetBrains Mono` (not `Source Serif 4` or `IBM Plex Mono`).
  - `tokens.css:28-126` implements both Light (`H=228°`) and Deep Space Slate Dark (`H=230°`) themes with Spectral Cyan-Emerald accent (`H=182°–186°`), rather than light-first Academic Ledger with Charcoal Ink primary and Deep Botanical Pine accent.
  - `ThemeProvider.tsx` and `ThemeSwitcher.tsx` expose a live Light / Dark / System switcher and pre-paint theme script (`index.html:20-35`).
  - `SpatialOrbitStage.tsx` implements pointer-reactive 3D perspective tilt (`perspective(1200px) rotateX(...) rotateY(...)`), fluted outer bezel (`.orbit-fluted-bezel`), and continuous counter-rotating orbital SVG rings (`orbit-ring-outer`, `orbit-ring-inner`, `conduit-pulse`).
- **Agreement / Conflict:** Directly **conflicts** with Part A §3 of the strategic blueprint (*Light-first, dark mode deferred, do not inherit Spatial Orbit dark-cyan web prototype, use Source Serif 4 + IBM Plex Sans + IBM Plex Mono, Charcoal Ink + Deep Botanical Pine, avoid 3D-heavy interfaces and unnecessary animation*).
- **Consequences:** Continuing to build admin routes on `tokens.css` and `SpatialOrbitStage.tsx` would propagate the rejected visual system and fonts.
- **Recommended Follow-Up:** Replace `tokens.css`, `app.css`, `index.html`, `ThemeProvider`/`ThemeSwitcher` (retiring dark mode toggle), and `SpatialOrbitStage.tsx` in Phase 1 before implementing Phase 2–4 admin pages.

### `F-05` — React Web Route Implementation vs. Stub Matrix
- **Category:** React Web Implementation
- **Status:** `VERIFIED`
- **File Paths:** [`apps/web/src/App.tsx`](../../../apps/web/src/App.tsx), [`apps/web/src/features/admin/AdminShell.tsx`](../../../apps/web/src/features/admin/AdminShell.tsx), [`apps/web/src/features/admin/pages/AdminRouteStubPage.tsx`](../../../apps/web/src/features/admin/pages/AdminRouteStubPage.tsx), [`apps/web/src/features/auth/pages/LandingPage.tsx`](../../../apps/web/src/features/auth/pages/LandingPage.tsx)
- **Relevant Symbols:** `App` (`App.tsx:77-283`), `AdminRouteGuard` (`App.tsx:33-54`), `PublicRouteGuard` (`App.tsx:56-75`), `AdminRouteStubPage` (`AdminRouteStubPage.tsx:12-82`)
- **What Source Demonstrates:**
  - **6 routes have concrete page implementations:** `/` (`PublicAuthLayout` + empty `LandingPage`), `/login` (`LoginPage`), `/forgot-password` (`ForgotPasswordPage`), `/reset-password` (`ResetPasswordPage`), `/access-required` (`AccessRequiredPage`), and `/admin/dashboard` (`AdminDashboardPage`).
  - **13 admin routes are placeholders rendering `AdminRouteStubPage`:** `/admin/routine`, `/admin/timetable/grid` (`live-wired-next`), `/admin/scheduling` (`preview-locked`), `/admin/timetable/courses`, `/admin/timetable/batches` (`staged-no-db`), and `/admin/timetable/rooms`, `/admin/timetable/faculty`, `/admin/timetable/course-eligibility`, `/admin/timetable/settings`, `/admin/broadcast`, `/admin/users`, `/admin/resources`, `/admin/profile` (`live-wired-next`).
  - Note also that sibling Flutter routes `/admin/registration`, `/admin/broadcast/history`, `/admin/resources/library` (`app_router.dart`) do not have separate routes in `apps/web/src/App.tsx` (represented as combined descriptions on `/admin/users`, `/admin/broadcast`, `/admin/resources`).
- **Agreement / Conflict:** Agrees with the blueprint's Phase 0/1 status and fail-closed honesty model (`AdminRouteStubPage` accurately distinguishes `live-wired-next`, `staged-no-db`, and `preview-locked`).
- **Consequences:** All operational Track 1, baseline CRUD, and Track 2 workflows remain unimplemented in React Web.
- **Recommended Follow-Up:** Implement real routes in Roadmap Phases 2–4 while retaining `staged-no-db` and `preview-locked` guards where backend contracts are absent.

### `F-06` — Public Landing Sandbox Is Strictly Client-Only
- **Category:** React Web Implementation
- **Status:** `VERIFIED`
- **File Paths:** [`apps/web/src/features/onboarding/components/SpatialOrbitStage.tsx`](../../../apps/web/src/features/onboarding/components/SpatialOrbitStage.tsx), [`apps/web/src/features/onboarding/data/routineFixtures.ts`](../../../apps/web/src/features/onboarding/data/routineFixtures.ts)
- **Relevant Symbols:** `buildSandboxSlots`, `AUTO_SCENARIOS`, `SpatialOrbitStage`
- **What Source Demonstrates:** All landing page preview data comes statically from `routineFixtures.ts`. Neither `PublicAuthLayout.tsx` nor `SpatialOrbitStage.tsx` invokes `supabase` or `engineHealth`.
- **Agreement / Conflict:** **Agrees** with blueprint security requirement (zero unauthenticated FastAPI or private Supabase calls on `/`).
- **Consequences:** Safe baseline pattern to preserve when replacing `SpatialOrbitStage` with the Academic Ledger 2D preview in Phase 1.
- **Recommended Follow-Up:** Keep the new Academic Ledger public showcase strictly client-fixture-driven.

### `F-07` — `AdminDashboardPage` & `adminDashboardService` Exact Queries & Dev Preview Gate
- **Category:** React Web Implementation
- **Status:** `VERIFIED`
- **File Paths:** [`apps/web/src/features/admin/pages/AdminDashboardPage.tsx`](../../../apps/web/src/features/admin/pages/AdminDashboardPage.tsx), [`apps/web/src/features/admin/services/adminDashboardService.ts`](../../../apps/web/src/features/admin/services/adminDashboardService.ts)
- **Relevant Symbols:** `fetchAdminDashboardCounts` (`adminDashboardService.ts:43-92`), `AdminDashboardPage` (`AdminDashboardPage.tsx:32-467`)
- **What Source Demonstrates:**
  - Executes `head: true, count: 'exact'` queries against `profiles`, `routines`, `notifications`, `timetable_rooms`, `timetable_faculty`, `timetable_course_eligibility`, plus active `routine_versions.semester_label`.
  - Uses `isDevPreview` (`import.meta.env.DEV && !isSupabaseConfigured`, `AuthProvider.tsx:85`) to return illustrative static counts (`getDevPreviewCounts()`, zero DB writes) only when `.env.local` is unconfigured in dev mode.
  - Surfaces an empty-config warning banner (`hasEmptyConfig`, lines 134–163) when rooms/faculty/eligibility counts equal `0`.
  - Note: Stage 03 (`AdminDashboardPage.tsx:317-347`) currently renders a hardcoded illustrative filename `CSE_Course_Distribution_Spring_2026_Final_v4.xlsx` and hardcoded SHA `9f4c8a...e21b` (lines 47–48, 319–325) rather than reading live database state!
- **Agreement / Conflict:** Partially agrees (honest DB count queries and empty-config guard), but hardcoded placeholder SHA/filename on Stage 03 conflicts with truthful backend-derived readiness rules.
- **Consequences:** Administrators viewing Stage 03 on a live Supabase instance could misinterpret the hardcoded `.xlsx` filename and SHA as live database state.
- **Recommended Follow-Up:** Remove hardcoded filename/SHA from Stage 03 **in Phase 1** so dashboard readiness remains strictly backend-derived (`timetable_course_eligibility`, `timetable_settings`, `routine_versions`).

### `F-08` — `EngineHealthBadge` Polls Root `GET /` Correctly
- **Category:** React Web Implementation
- **Status:** `VERIFIED`
- **File Paths:** [`apps/web/src/services/engineHealth.ts`](../../../apps/web/src/services/engineHealth.ts), [`apps/web/src/shared/components/EngineHealthBadge.tsx`](../../../apps/web/src/shared/components/EngineHealthBadge.tsx)
- **Relevant Symbols:** `checkEngineHealth` (`engineHealth.ts:23-96`), `EngineHealthBadge` (`EngineHealthBadge.tsx:6-72`)
- **What Source Demonstrates:** Polls `${baseUrl}/` (`GET /`, 5s timeout, `refetchInterval: 60_000`) and validates `body.ok === true && body.service === "universe-timetable-engine"`, distinguishing `online`, `cold-start` (502/503/timeout), and `unavailable`. Note: `EngineHealthBadge` is rendered inside `AdminShell.tsx:322` (authenticated only), not on public routes.
- **Agreement / Conflict:** Agrees with `engine/main.py:104-106` (`GET /` returns exact contract; `/health` does not exist).
- **Consequences:** Ready to carry forward into Academic Ledger `AdminShell`.
- **Recommended Follow-Up:** Retain `engineHealth.ts` and restyle `EngineHealthBadge.tsx` in Phase 1/2.

---

## 3. Authentication and Authorization

### `F-09` — Explicit Investigation: `approved_users` vs. `public.whitelists`
- **Category:** Authentication and Authorization
- **Status:** `CONTRADICTED` (Phase 0/1 prose) / `VERIFIED` (code & SQL)
- **File Paths:** [`docs/implementation/web_phase_0_1_spatial_orbit_foundation.md`](../../../docs/implementation/web_phase_0_1_spatial_orbit_foundation.md) (lines 51, 79), [`apps/web/src/features/auth/AuthProvider.tsx`](../../../apps/web/src/features/auth/AuthProvider.tsx) (lines 171, 214–219), [`lib/core/constants/app_constants.dart`](../../../lib/core/constants/app_constants.dart) (line 102), [`supabase/functions/invite-admin/handler.js`](../../../supabase/functions/invite-admin/handler.js) (line 75), [`supabase/migrations/006_enable_rls_all_tables.sql`](../../../supabase/migrations/006_enable_rls_all_tables.sql) (lines 61, 94)
- **Relevant Symbols:** `resolveAdminGate` (`AuthProvider.tsx:174-275`), `AppConstants.tableWhitelists`
- **What Source Demonstrates:**
  - `docs/implementation/web_phase_0_1_spatial_orbit_foundation.md:51,79` falsely reports that `AuthProvider.tsx` checks `approved_users`.
  - A repository-wide regex search (`Select-String` across `.dart`, `.ts*`, `.sql`, `.py`, `.md`) confirms **`approved_users` appears zero times in any source code or SQL file**.
  - `AuthProvider.tsx:214-219` actually queries `.from("whitelists")`, matching `public.whitelists` in SQL (`006`, `016`, `20261021214512`), Flutter (`AuthService`, `AdminService`), and `invite-admin/handler.js`.
- **Agreement / Conflict:** Source code **agrees** with the database schema (`public.whitelists`) and **contradicts** the Phase 0/1 completion report (`web_phase_0_1_spatial_orbit_foundation.md`).
- **Consequences:** Relying on the Phase 0/1 report rather than code could mislead engineers or prompt an unnecessary `approved_users` migration.
- **Recommended Follow-Up:** Correct `web_phase_0_1_spatial_orbit_foundation.md` in Phase 0; keep all code bound to `public.whitelists`.

### `F-10` — React Web Admin-Only Gate & Non-Admin Rejection
- **Category:** Authentication and Authorization
- **Status:** `VERIFIED`
- **File Paths:** [`apps/web/src/features/auth/AuthProvider.tsx`](../../../apps/web/src/features/auth/AuthProvider.tsx) (lines 174–275, 319–337, 372–379), [`apps/web/src/features/auth/pages/AccessRequiredPage.tsx`](../../../apps/web/src/features/auth/pages/AccessRequiredPage.tsx), [`apps/web/src/App.tsx`](../../../apps/web/src/App.tsx) (lines 33–75)
- **Relevant Symbols:** `resolveAdminGate`, `isNotWhitelistedError`, `AdminRouteGuard`
- **What Source Demonstrates:**
  - `resolveAdminGate` queries `public.profiles` (`id = user.id`). If `role === "admin"`, sets `status = "authenticated"`. If any other role (`student`, `teacher`), sets `deniedReason = "non_admin_role"`, `status = "accessDenied"`, routing to `/access-required`.
  - If no `profiles` row exists, checks `public.whitelists` (`ilike("email", emailLower).eq("role", "admin")`) and inserts the user's `profiles` row (`role: "admin"`), guarded server-side by `guard_profile_role()` (`hint === "not_whitelisted"` / `code === "42501"`).
  - **Subtle defect noticed (`AuthProvider.tsx:334`):** Inside `onAuthStateChange`, the callback references React state `status !== "passwordRecovery"` inside a closure whose `useEffect` dependency array omits `status` (`eslint-disable-line react-hooks/exhaustive-deps`, line 345). During password recovery, `status` in the closed-over listener stays stale (`"loading"` or `"unauthenticated"`), so an auth event emitting `SIGNED_IN` after `PASSWORD_RECOVERY` could bypass the guard unless tracked via a `useRef`.
  - **Redirect-to behavior (`AuthProvider.tsx:398,425`):** `signInWithGoogle` and `sendPasswordReset` pass `redirectTo: ${window.location.origin}/`. Note that unlike Flutter (`AuthCallbackPolicy._browserCallback()`), React does not check a client-side `VITE_AUTH_WEB_CALLBACK_URLS` list before calling GoTrue, relying instead on Supabase Auth's server-side Redirect URLs allowlist.
- **Agreement / Conflict:** Aligns with blueprint admin-only security; stale `status` closure in `onAuthStateChange` is a real edge-case bug.
- **Consequences:** Potential race if `SIGNED_IN` fires during an active `passwordRecovery` window.
- **Recommended Follow-Up:** Refactor `status` check in `onAuthStateChange` to use a `statusRef` in Phase 1; confirm every local and Cloudflare Pages origin is in Supabase Auth Redirect URLs.

### `F-11` — Invite-Admin Edge Function & Implicit-to-PKCE Bridge
- **Category:** Authentication and Authorization
- **Status:** `PARTIALLY VERIFIED`
- **File Paths:** [`supabase/functions/invite-admin/index.ts`](../../../supabase/functions/invite-admin/index.ts), [`supabase/functions/invite-admin/handler.js`](../../../supabase/functions/invite-admin/handler.js), [`supabase/functions/invite-admin/callback_policy.js`](../../../supabase/functions/invite-admin/callback_policy.js), [`apps/web/src/services/supabase.ts`](../../../apps/web/src/services/supabase.ts) (lines 27–141), [`apps/web/src/features/auth/AuthProvider.tsx`](../../../apps/web/src/features/auth/AuthProvider.tsx) (lines 283–300), [`apps/web/src/features/auth/pages/ResetPasswordPage.tsx`](../../../apps/web/src/features/auth/pages/ResetPasswordPage.tsx), [`lib/features/auth/services/invitation_callback_bridge.dart`](../../../lib/features/auth/services/invitation_callback_bridge.dart) (lines 49–139)
- **Relevant Symbols:** `createInvitationHandler`, `resolveInvitationCallback`, `extractAndScrubInviteHash`, `adoptInviteSession`
- **What Source Demonstrates:**
  - `invite-admin/handler.js` verifies caller JWT -> checks `profiles.role === 'admin'` via service role -> validates `redirect_to` against `AUTH_WEB_CALLBACK_URLS` -> upserts `whitelists` (`role: 'admin'`) -> calls `admin.auth.admin.inviteUserByEmail(...)`.
  - Because `inviteUserByEmail` originates server-side without a browser PKCE `code_verifier`, GoTrue redirects with `#access_token=...&refresh_token=...&expires_in=...&token_type=bearer&type=invite`.
  - `apps/web/src/services/supabase.ts` scrubs the hash via `window.history.replaceState(null, "", window.location.pathname)`, verifies `/auth/v1/user` (`verifiedUser.invited_at`), exchanges the refresh token via `/auth/v1/token?grant_type=refresh_token`, and calls `supabase.auth.setSession(...)`, then `AuthProvider` activates `startRecoveryWindow()` (10-minute timer) routing to `/reset-password`.
  - **Gap vs. Flutter's `InvitationCallbackBridge`:** Flutter (`invitation_callback_bridge.dart:69,87,123`) additionally rejects any callback with query params (`!uri.hasQuery`), verifies `user.emailConfirmedAt != null`, and enforces `session.expiresAt > now + 60s`. React's `adoptInviteSession` omits the `!window.location.search`, `email_confirmed_at`, and minimum TTL checks.
  - **Profile provisioning timing:** After setting password in `ResetPasswordPage.tsx:124`, the user is signed out (`signOut() -> /login`) and must sign in once; `resolveAdminGate` then inserts their `public.profiles` row from `public.whitelists`.
  - **Hosted unknowns:** `invite-admin/index.ts:1-3` explicitly warns that positive invitation/email delivery remains untested in production and `AUTH_WEB_CALLBACK_URLS` in the deployed Edge Function is unverified.
- **Agreement / Conflict:** Core bridge agrees with Flutter's documented solution; minor hardening gaps and untested hosted delivery are identified.
- **Consequences:** Unapproved web origins in `AUTH_WEB_CALLBACK_URLS` will reject invites (`400: Invitation callback is not approved.`); missing `email_confirmed_at` / query checks slightly weaken invite validation compared to Flutter.
- **Recommended Follow-Up:** Add query-param, `email_confirmed_at`, and minimum TTL checks to `adoptInviteSession` in Phase 1; verify Edge Function deployment and `AUTH_WEB_CALLBACK_URLS` with owner in Phase 0/5.

---

## 4. Flutter Mobile Compatibility

### `F-12` — Flutter Does NOT Send Supabase JWTs to FastAPI
- **Category:** Flutter Mobile Compatibility
- **Status:** `VERIFIED`
- **File Paths:** [`lib/features/admin/services/timetable_engine_service.dart`](../../../lib/features/admin/services/timetable_engine_service.dart) (lines 146–259), [`lib/features/admin/services/engine_connectivity_service.dart`](../../../lib/features/admin/services/engine_connectivity_service.dart) (lines 22–41)
- **Relevant Symbols:** `TimetableEngineService.generate`, `pollStatus`, `fetchResult`, `downloadWorkbook`, `EngineConnectivityService.check`
- **What Source Demonstrates:** Every HTTP call from Flutter to FastAPI (`POST /api/timetable/generate`, `GET /api/timetable/status|result|download/{job_id}`, `GET /`) constructs standard `http.MultipartRequest` or `http.get` requests with **zero `Authorization` headers** or Supabase bearer tokens. Moreover, only Admin workflows call FastAPI; Student and Teacher mobile features never touch the FastAPI microservice.
- **Agreement / Conflict:** Confirms the exact concern raised in Part B §2: adding mandatory JWT auth to FastAPI **will break Flutter Admin calls** unless Flutter `TimetableEngineService` is updated simultaneously or retired in favor of React Web for admin generation.
- **Consequences:** Student and Teacher Flutter Mobile workflows are completely unaffected by FastAPI authentication changes; however, any legacy Flutter Admin screen still calling FastAPI would receive `401`/`403` once FastAPI enforces JWTs.
- **Recommended Follow-Up:** Defer strict FastAPI JWT enforcement to Phase 5A following the approved 5-step sequence: inspect Flutter headers (`F-12`), update both Flutter (`TimetableEngineService`) and React Web for dual-client JWT headers, add env-driven CORS and gradual JWT verification without solver redesign, test Android, iOS compatibility, and React Web before strict enforcement, then enable production enforcement once proven.

### `F-13` — Non-Admin Flutter Mobile Table Access (`profiles`, `timetable_faculty`, `timetable_rooms`)
- **Category:** Flutter Mobile Compatibility
- **Status:** `VERIFIED`
- **File Paths:** [`lib/features/profile/services/profile_service.dart`](../../../lib/features/profile/services/profile_service.dart) (lines 11–31), [`lib/features/auth/services/auth_service.dart`](../../../lib/features/auth/services/auth_service.dart) (lines 214–218, 252, 275–289, 319–334, 351–357), [`lib/features/find_teacher/services/teacher_location_service.dart`](../../../lib/features/find_teacher/services/teacher_location_service.dart) (lines 11–45), [`lib/features/find_teacher/controllers/find_teacher_controller.dart`](../../../lib/features/find_teacher/controllers/find_teacher_controller.dart) (lines 57–74), [`lib/features/rooms/services/room_status_service.dart`](../../../lib/features/rooms/services/room_status_service.dart) (lines 11–26), [`lib/features/rooms/controllers/rooms_controller.dart`](../../../lib/features/rooms/controllers/rooms_controller.dart) (lines 56–66), [`lib/features/routine/services/routine_service.dart`](../../../lib/features/routine/services/routine_service.dart), [`lib/features/notifications/services/notification_service.dart`](../../../lib/features/notifications/services/notification_service.dart), [`lib/features/teacher/services/teacher_service.dart`](../../../lib/features/teacher/services/teacher_service.dart), [`lib/features/resources/services/resource_service.dart`](../../../lib/features/resources/services/resource_service.dart)
- **Relevant Symbols:** `ProfileService.fetchProfile/updateProfile`, `TeacherLocationService.fetchAllRoutines/fetchUniqueTeachers/streamAllRoutines`, `RoomStatusService.fetchAllRoutines/streamAllRoutines`, `AuthService.handlePostLogin`
- **What Source Demonstrates:** Exhaustive inspection of all `lib/` Supabase queries confirms:
  - **Non-admin reads on `public.profiles`:** Both `ProfileService` and `AuthService` query **only the signed-in user's own row** (`.eq('id', userId)`). Neither `FindTeacherController`, `RoutineService`, nor any student/teacher screen reads other users' `profiles` rows! (Only `AdminService.fetchAllProfiles()` and `AdminService.counts()` select across all profiles.)
  - **Non-admin reads on `public.timetable_faculty` and `public.timetable_rooms`:** **Zero** non-admin Flutter services query `timetable_faculty`, `timetable_rooms`, `timetable_settings`, `timetable_course_eligibility`, or `timetable_runs`.
  - **How Find Teacher & Room Status actually work:** Both `TeacherLocationService` and `RoomStatusService` query **only `public.routines`** (`where is_active = true`), deriving faculty names/acronyms and physical room occupancy strictly from published `routines` rows (including `is_service = true` rows).
  - **All other tables accessed by non-admin Flutter Mobile:** `whitelists` (own email `eq('email', email.toLowerCase())`), `routines` (`is_active = true`), `cancellations` (`select`, teacher `insert`/`delete`), `notifications` (`select`, teacher `insert`), `notification_reads` (own `user_id`), `resources` (`select`), `device_tokens` (`register_device_token` RPC).
- **Agreement / Conflict:** Directly resolves the critical RLS compatibility question in Part B §2:
  - Currently, `006_enable_rls_all_tables.sql:48-49` allows **every authenticated user** (`using (true)`) to read **every user's email, student_id, and profile** in `public.profiles`, and `008_rls_timetable_config.sql:30-31` allows every authenticated user to read all `timetable_*` config tables.
  - Because non-admin mobile code never queries other users' `profiles` or any `timetable_*` tables, **restricting `profiles` SELECT to `id = auth.uid() or public.is_admin()` and restricting `timetable_*` config SELECT to admins/authorized staff will NOT break Android or iOS Student/Teacher workflows**.
- **Consequences:** Safe path exists to eliminate unnecessary PII exposure (`profiles.email`, `profiles.student_id`) across all authenticated mobile accounts in Phase 5B. *(One caveat: verify via read-only inspection whether the `send-push` Edge Function uses `service_role`—if so, it bypasses RLS.)*
- **Recommended Follow-Up:** Include self-only `profiles_select` and admin-scoped `timetable_*` SELECT hardening in Roadmap Phase 5B (after verifying no legacy mobile screens hidden in `lib/features/dashboard/` or `teacher/` read `profiles` broadly—confirmed via repo-wide `tableProfiles` grep).

### `F-14` — Cross-Platform Serialization Contracts Flutter Mobile Depends On
- **Category:** Flutter Mobile Compatibility
- **Status:** `VERIFIED`
- **File Paths:** [`lib/core/models/routine_model.dart`](../../../lib/core/models/routine_model.dart), [`lib/core/constants/app_constants.dart`](../../../lib/core/constants/app_constants.dart), [`lib/features/notifications/services/notification_service.dart`](../../../lib/features/notifications/services/notification_service.dart), [`lib/features/resources/services/resource_service.dart`](../../../lib/features/resources/services/resource_service.dart)
- **What Source Demonstrates:** React Web writes must maintain exact compatibility with Flutter Mobile deserialization:
  - `routines`: `day` (full English weekday e.g. `'Sunday'`), `time_start`/`time_end` (`HH:MM:SS` Postgres `time`, parsed by `RoutineEntry._hm`), `subject`, `subject_code`, `teacher_name`, `teacher_code` (scalar), `room`, `batch`, `section` (joint sections separated by `'+'`, matched by `RoutineEntry.matchesStudent`), `semester` (`int`), `is_active` (`bool`), `is_service` (`bool`).
  - `notifications`: `type` constrained by SQL check `'university' | 'class_cancel' | 'room_change' | 'test_reminder' | 'assignment' | 'exam'` (`20261021214512_reconstructed_baseline.sql:277`).
  - `resources`: public URLs in Storage bucket `resources` at `<semester>/<epoch_ms>_<sanitized_filename>` or `drive_link`.
- **Agreement / Conflict:** Matches blueprint requirement to avoid breaking mobile models/serialization.
- **Consequences:** Writing invalid `time_start`, unsupported `notifications.type`, or omitting `is_service` rows on publish breaks student/teacher parsing or room/teacher occupancy accuracy on Android.
- **Recommended Follow-Up:** Codify shared Zod schemas in `apps/web/` matching these exact types and values.

---

## 5. FastAPI Engine and API Contracts (`engine/`)

### `F-15` — FastAPI Endpoints Lack Authentication and Enforce Wildcard CORS
- **Category:** FastAPI Engine and API Contracts
- **Status:** `VERIFIED`
- **File Path:** [`engine/main.py`](../../../engine/main.py) (lines 16–24, 104–189)
- **Relevant Symbols:** `app.add_middleware(CORSMiddleware, ...)`, `health`, `generate`, `status`, `result`, `download`
- **What Source Demonstrates:**
  - `CORSMiddleware` is configured with `allow_origins=["*"]`, `allow_methods=["*"]`, `allow_headers=["*"]` (lines 18–23).
  - Zero `Depends(...)`, JWT verification, bearer token parsing, or API-key guards exist on `GET /`, `POST /api/timetable/generate`, `GET /api/timetable/status/{job_id}`, `GET /api/timetable/result/{job_id}`, or `GET /api/timetable/download/{job_id}`.
  - Health endpoint is `GET /` (lines 104–106), returning `{"service": "universe-timetable-engine", "version": "2.0.0", "ok": True}`. `GET /health` does not exist (`404`).
- **Agreement / Conflict:** Agrees with `react-admin-backend-contracts` security note; represents an unhardened production exposure if the Render URL is publicly known.
- **Consequences:** Any external caller can trigger CPU/RAM-heavy CP-SAT jobs (DoS on 512 MB Render free plan) or fetch/download `job_id` results if discovered.
- **Recommended Follow-Up:** Keep engine invocations strictly behind authenticated admin UI in Phases 1–3; implement JWT admin verification and origin-restricted CORS in Phase 5A (under separate authorization).

### `F-16` — Volatile In-Memory `JOBS` Store & Render Free-Tier Spin-Down
- **Category:** FastAPI Engine and API Contracts
- **Status:** `VERIFIED`
- **File Paths:** [`engine/main.py`](../../../engine/main.py) (lines 25, 47–101, 134–139), [`render.yaml`](../../../render.yaml) (lines 6–20), [`lib/features/admin/controllers/timetable_gen_controller.dart`](../../../lib/features/admin/controllers/timetable_gen_controller.dart) (lines 59–65, 261–297)
- **Relevant Symbols:** `JOBS: dict[str, dict]`, `_run_job`, `render.yaml` (`plan: free`, `SOLVER_WORKERS: "2"`)
- **What Source Demonstrates:**
  - Jobs run in daemon `threading.Thread` workers mutating an in-process dictionary `JOBS` with no database/Redis backing, no eviction TTL, and no multi-worker state sharing.
  - `render.yaml` specifies Render `plan: free` with `SOLVER_WORKERS="2"` (note: `engine/solver.py:27` defaults `SOLVER_WORKERS` to `"8"` if unset).
  - `TimetableGenController` passes `time_limit_s = 180` (vs. FastAPI default `60.0`), polls every `2s` up to `240` polls (~8 min), backs off `4s` on `429`, and fails on the 5th consecutive non-429 error.
- **Agreement / Conflict:** Matches `react-admin-backend-contracts` §3. Confirms why Track 2 **Gate D (Durable Solving)** cannot be marked complete solely with the existing in-memory `JOBS` dict.
- **Consequences:** Container spin-down, OOM on 512 MB RAM, or page reload drops active `job_id` state (`404 Unknown job_id.`).
- **Recommended Follow-Up:** Track 1 (Phase 3) must expose clear cold-start/retry UI (`Service Recovery Paradox`) and persist `job_id` briefly in session storage for accidental tab focus shifts; Track 2 Gate D (Phase 4) requires durable job tracking.

---

## 6. Supabase Schema and RLS (`supabase/`)

### `F-17` — Public Schema Baseline & Anon/Authenticated Exposure Gaps
- **Category:** Supabase Schema and RLS
- **Status:** `VERIFIED`
- **File Paths:** [`supabase/migrations/006_enable_rls_all_tables.sql`](../../../supabase/migrations/006_enable_rls_all_tables.sql), [`supabase/migrations/008_rls_timetable_config.sql`](../../../supabase/migrations/008_rls_timetable_config.sql), [`supabase/migrations/013_faculty_course_eligibility.sql`](../../../supabase/migrations/013_faculty_course_eligibility.sql), [`supabase/migrations/016_teacher_whitelist_gate.sql`](../../../supabase/migrations/016_teacher_whitelist_gate.sql), [`supabase/reconciliation/20261021214512_reconstructed_baseline.sql`](../../../supabase/reconciliation/20261021214512_reconstructed_baseline.sql)
- **Relevant SQL Objects:** `profiles_select` (`006:48-49`), `timetable_*_select` (`008:30-31`), `read_all` on `timetable_course_eligibility` (`013:43-44`), `storage_auth_*` (`006:274-288`), `guard_profile_role` (`016:37-82`)
- **What Source Demonstrates:**
  - `006:48-49`: `profiles_select` allows `for select to authenticated using (true)` — any signed-in student can query all users' emails and student IDs.
  - `008:30-31`: `timetable_rooms`, `timetable_faculty`, `timetable_settings`, `timetable_runs` allow `for select to authenticated using (true)`.
  - `013:43-44` & `20261021214512:687-688`: `read_all` on `timetable_course_eligibility` is declared **`for select using (true)` without `to authenticated`**, defaulting to role `public` (readable by `anon` if table grants exist—and `20261021214512:779` documents `grant select, insert, update, delete on table ... to anon, authenticated` matching reconstructed baseline metadata).
  - `006:274-288`: Storage policies `storage_public_read` (`using (true)`) and `storage_auth_insert` / `storage_auth_update` / `storage_auth_delete` (`to authenticated using (true)`) lack bucket-level restrictions, allowing any authenticated student to insert/overwrite/delete objects in `timetables` and `resources` buckets.
  - `006:28,36`: `my_role()` and `is_admin()` use `set search_path = public` (older style) whereas newer migrations (`20261022140809`, `20261106130000`) use `set search_path = ''`.
- **Agreement / Conflict:** Confirms RLS is enabled across tables, while highlighting real over-permissive SELECT and Storage write policies that require hardening in Phase 5B.
- **Consequences:** Students with extracted `anon` keys + signed-in JWTs could read faculty/student PII or tamper with Storage bucket files until tightened.
- **Recommended Follow-Up:** Tighten `profiles_select`, `timetable_*`, `read_all` (`to authenticated`), and `storage.objects` bucket-scoped policies in Phase 5B (after verifying live production policies in Phase 0).

### `F-18` — Missing Database Backing for `Courses`, `Batches`, and Phase A Extended Columns
- **Category:** Supabase Schema and RLS
- **Status:** `CONTRADICTED` (Flutter UI assumptions) / `VERIFIED` (in SQL & Dart code)
- **File Paths:** [`lib/features/admin/services/timetable_config_service.dart`](../../../lib/features/admin/services/timetable_config_service.dart) (lines 25–302), [`lib/core/models/timetable_config_model.dart`](../../../lib/core/models/timetable_config_model.dart) (lines 67–80, 194–211), [`lib/core/models/admin_catalog_models.dart`](../../../lib/core/models/admin_catalog_models.dart), [`lib/features/admin/screens/manage_rooms_screen.dart`](../../../lib/features/admin/screens/manage_rooms_screen.dart) (lines 49–51), [`lib/features/admin/screens/manage_faculty_screen.dart`](../../../lib/features/admin/screens/manage_faculty_screen.dart) (lines 48–50), [`supabase/reconciliation/20261021214512_reconstructed_baseline.sql`](../../../supabase/reconciliation/20261021214512_reconstructed_baseline.sql) (lines 184–221)
- **Relevant Symbols:** `_inMemoryCourses`, `_inMemoryBatches`, `_inMemoryRooms`, `_inMemoryFaculty`, `TimetableRoom.toMap()`, `TimetableFaculty.toMap()`, `createRoom`, `updateRoom`, `createFaculty`, `updateFaculty`
- **What Source Demonstrates:**
  - **Courses & Batches (`timetable_config_service.dart:26-27,58-112`):** `fetchCatalogCourses`, `createCatalogCourse`, `updateCatalogCourse`, `deleteCatalogCourse`, `fetchBatches`, `createBatch`, `updateBatch`, `deleteBatch` operate **100% on static in-memory Dart lists**. Although `timetable_courses` exists in `20261021214512:184-196`, zero Dart code queries or writes to it.
  - **Silent Schema Mismatch on Rooms & Faculty:**
    - `public.timetable_rooms` baseline columns are `id, name, building, is_lab, is_gallery, capacity, is_active, dept` (plus `campus, features` added by `20261022140809:97` only if applied). `TimetableRoom.toMap()` emits 5 non-existent columns: `classification`, `building_and_floor`, `in_active_semester_pool`, `bound_course_codes`, `declared_window_matrix`.
    - `public.timetable_faculty` baseline columns are `id, acronym, full_name, dept, designation, off_days, is_active, courses` (plus `home_department_id` added by `20261022140809:95`). `TimetableFaculty.toMap()` emits 6 non-existent columns: `employment_type`, `is_sust_adjunct`, `sust_compactness_mode`, `is_external_guest`, `has_external_block`, `slot_matrix`.
    - `TimetableConfigService.createRoom/updateRoom/createFaculty/updateFaculty` wrap Supabase writes in `try { ... } catch (_) {}` (lines 168–170, 187–192, 263–265, 282–287), silently discarding Postgrest column-not-found errors while updating static in-memory lists and returning success to the UI.
    - Furthermore, `ManageRoomsScreen` and `ManageFacultyScreen` keep `_labAvailability`, `_physicsBoundCourses`, `_slotMatrixState`, and `_sustBreakPreference` only in widget state.
- **Agreement / Conflict:** Directly validates the warning in `react-admin-backend-contracts` §4 and conflicts with any assumption that Flutter's Phase A/6 UI controls currently persist to Postgres.
- **Consequences:** Replicating Flutter's `toMap()` payloads in React Web would break live Supabase writes or silently lose R4/R5/R8/R9/R10/R11/R14 policies.
- **Recommended Follow-Up:** In React Web Phase 2, bind `Rooms` and `Faculty` forms strictly to verified database columns, keep `Courses`/`Batches` and extended R1–R16 matrices explicitly gated (`staged-no-db`) until schema migrations are designed and authorized, and never swallow DB errors silently.

### `F-19` — Missing Production Contracts for Canonical Academic Catalog & Course Distribution + Flutter Gateway Mismatches
- **Category:** Supabase Schema and RLS
- **Status:** `CONTRADICTED` (Flutter gateway vs. SQL) & `PARTIALLY VERIFIED` (SQL exists locally, production status unverified)
- **File Paths:** [`supabase/migrations/20261022140809_academic_catalog.sql`](../../../supabase/migrations/20261022140809_academic_catalog.sql), [`supabase/migrations/20261106130000_course_distribution_contract.sql`](../../../supabase/migrations/20261106130000_course_distribution_contract.sql) (lines 16–30, 125–228), [`lib/features/admin/scheduling/controllers/scheduling_workspace_controller.dart`](../../../lib/features/admin/scheduling/controllers/scheduling_workspace_controller.dart) (lines 48–108), [`lib/features/admin/services/timetable_engine_service.dart`](../../../lib/features/admin/services/timetable_engine_service.dart) (lines 180–193)
- **Relevant Symbols:** `SupabaseSchedulingWorkspaceGateway.fetchAvailableScopesAndRevisions`, `appendCellCorrection`, SQL `append_course_distribution_correction`, `read_course_distribution_revision`
- **What Source Demonstrates:**
  - `20261022140809_academic_catalog.sql` and `20261106130000_course_distribution_contract.sql` exist as local migrations. Prior documentation (`UniVerse_Implementation_Master_Plan_v1_1.md:94-95`, `UNIVERSE_CURRENT_ARCHITECTURE_AND_UI_UX_DOSSIER.md:201,516`) reports these exist in secondary test project `oqwvxplteqtlrhktsplj`, **not** in production `yxqyrjyzxitrgkhgauli`.
  - **Two direct bugs exist in Flutter's `SupabaseSchedulingWorkspaceGateway` (`scheduling_workspace_controller.dart`):**
    1. Lines 53–56 query `.from('course_distribution_revisions').select('id, revision_number, version, status, scope_id, created_at')`, whereas SQL `course_distribution_revisions` (`20261106130000:16-30`) defines `revision_version` (not `version`) and does **not** have `scope_id` (`scheduling_scope_id` lives on `course_distribution_sources`).
    2. Lines 84–94 call `append_course_distribution_correction` with 6 `p_*` parameters expecting a JSON object response, whereas SQL (`20261106130000:125-175`) defines **8 parameters** (`target_revision`, `expected_revision_version`, `target_row`, `target_column`, `prior_formula`, `prior_cached_value`, `next_effective_value`, `reason`) and returns scalar `uuid`.
  - By contrast, `TimetableEngineService.fetchAcceptedDistributionRevision` (`timetable_engine_service.dart:183-186`) accurately calls `read_course_distribution_revision(target_revision)`.
- **Agreement / Conflict:** Confirms Track 2 (`/admin/scheduling`) must remain **fail-closed (`Gates A–D locked`)** and exposes critical contract bugs if anyone copied Flutter's `SupabaseSchedulingWorkspaceGateway` into React Web.
- **Consequences:** Copying Flutter's gateway RPC calls verbatim into React Web would fail at runtime even after promoting `20261106130000`.
- **Recommended Follow-Up:** Bind Track 2 Gates A–B in React Web strictly to the actual SQL signatures in `20261106130000_course_distribution_contract.sql` after verifying deployment in the target database.

### `F-20` — Production & Staging Schema, Row Counts, RLS & Realtime Verified via Owner SQL Audit
- **Category:** Supabase Schema and RLS
- **Status:** `VERIFIED` *(via owner-executed read-only SQL diagnostic packet on 21 November 2026)*
- **File Paths:** [`UNIVERSE_CURRENT_ARCHITECTURE_AND_UI_UX_DOSSIER.md`](../../../UNIVERSE_CURRENT_ARCHITECTURE_AND_UI_UX_DOSSIER.md) (lines 200–201, 516), [`.agents/skills/react-admin-backend-contracts/SKILL.md`](../../../.agents/skills/react-admin-backend-contracts/SKILL.md) (line 55), [`supabase/reconciliation/storage_realtime_inventory.sql`](../../../supabase/reconciliation/storage_realtime_inventory.sql), [`WEB_PHASE_0_COMPATIBILITY_AND_AUDIT_ADDENDUM.md`](../WEB_PHASE_0_COMPATIBILITY_AND_AUDIT_ADDENDUM.md) (§4)
- **What Hosted SQL Diagnostics Confirmed:**
  1. **Production (`yxqyrjyzxitrgkhgauli` — kept strictly read-only):**
     - **18 `public` tables** with `rls_enabled = true` (`force_rls = false`); `supabase_migrations.schema_migrations` is absent; **none** of the 19 catalog/Track 2 tables (`20261022140809` / `20261106130000`) or extended columns (`campus`, `features`, `home_department_id`) are present.
     - **Exact live counts (correcting older dossier claims of 0 baseline rows):** `routines: 796`, `routine_versions: 6`, `timetable_runs: 23`, `timetable_rooms: 30`, `timetable_faculty: 76`, `timetable_settings: 1`, `profiles: 9`, `whitelists: 3`, and **`timetable_course_eligibility: 0`** (empty).
     - Confirmed `send_push_on_notification` webhook trigger enabled on `notifications`, `supabase_realtime` publishing only `public.cancellations`, open `profiles_select` / `read_all` (`to public`) / `anon` table grants (`F-17`), and wildcard `storage_auth_*` policies across all 4 public Storage buckets (`F-30`).
  2. **Secondary Staging (`oqwvxplteqtlrhktsplj` — audited & owner-approved non-production staging):**
     - **37 `public` tables** with `rls_enabled = true` (`18` baseline + all `19` catalog/Track 2 tables from `20261022140809` and `20261106130000`), including `campus`, `features`, `home_department_id`, `course_distribution_revisions.revision_version`, and verified Track 2 RPCs (`read_course_distribution_revision`, 8-param `append_course_distribution_correction`, `academic_catalog`, `publish_routine`).
     - **`0` rows across all baseline and Track 2 tables**, `supabase_functions` schema absent (**zero** push notification webhooks), and `supabase_realtime` publishing only `public.cancellations`.
     - Security observation for Phase 4A/5B: `course_distribution_*_read` policies grant `SELECT` on `roles: ["public"]` where `scheduling_scope_id IS NULL OR academic_private.can_scope(...)` (mitigated for `anon` only by missing `anon` table grant, so `authenticated` users could read unscoped rows until tightened).
- **Consequences:** Production `timetable_course_eligibility` is empty (`0` rows), so Phase 2/3 pre-publish readiness warnings remain essential. Meanwhile, `oqwvxplteqtlrhktsplj` is verified clean (`0` user rows, zero push triggers) and safe as the owner-designated non-production staging project (lifting its Phase 0 quarantine).
- **Recommended Follow-Up:** Keep production (`yxqyrjyzxitrgkhgauli`) read-only during React Web development, target `oqwvxplteqtlrhktsplj` strictly for gated Phase 1B+ staging verification, and scope `course_distribution_*_read` alongside `F-17`/`F-30` RLS hardening in Phase 4A/5B.

---

## 7. Publication and Scheduling Integrity

### `F-21` — `publish_routine()` Permanently Deletes Prior `routines` Rows Without Row Archiving
- **Category:** Publication and Scheduling Integrity
- **Status:** `VERIFIED`
- **File Paths:** [`supabase/migrations/012_routine_versions.sql`](../../../supabase/migrations/012_routine_versions.sql) (lines 42–192), [`supabase/migrations/014_publish_routine_safeupdate.sql`](../../../supabase/migrations/014_publish_routine_safeupdate.sql) (lines 40–104)
- **Relevant SQL Object:** `public.publish_routine(jsonb, text, text, jsonb, jsonb, text)`
- **What Source Demonstrates:**
  - `publish_routine()` validates `public.is_admin()`, rejects empty/non-array `p_rows`, inserts a metadata row into `public.routine_versions`, marks prior active versions `is_active = false`, runs **`delete from public.routines where true;`** (written with `where true` in `014` to pass Postgres `safeupdate`), inserts `p_rows` with `routine_version_id = v_id`, and flips `is_active = true`.
  - **Critical Recovery Limitation:** `public.routine_versions` stores **only summary metadata** (`semester_label`, `source`, `row_count`, `stats`, `validation`, `notes`, `published_at`, `published_by`), **not** a JSON snapshot or historical archive of deleted `public.routines` rows! Once `publish_routine()` executes, previous active `routines` rows are permanently deleted from Postgres.
  - Recovery of a prior routine is currently possible **only** if a `.xlsx` workbook was uploaded to the `timetables` Storage bucket (`CSE_Routine_<label>_<epoch_ms>.xlsx`, recorded in `timetable_runs.file_path`) and is manually re-downloaded, re-parsed, and re-published.
  - Note also that `012:104-106` changed `cancellations.routine_id` FK to `ON DELETE SET NULL` so clearing `routines` does not raise an FK error or wipe `cancellations` history.
- **Agreement / Conflict:** Matches `012` header comment ("`routines` keeps only the active routine's rows"), while **conflicting** with Master Plan §6.2 ("Full historical revisions remain recoverable") and `UNIVERSE_CURRENT_ARCHITECTURE_AND_UI_UX_DOSSIER.md` §24 ("1-tap rollback").
- **Consequences:** An accidental publish of an under-configured or faulty routine cannot be rolled back inside Postgres alone.
- **Recommended Follow-Up:** Keep strong pre-publish confirmation ("Slide-to-Confirm" / explicit modal preview showing active vs. incoming row counts) and always archive `.xlsx` to `timetables` bucket before `publish_routine()` in Track 1 (Phase 3); add row-level routine archiving/snapshot recovery to `publish_routine()` in Phase 4 Gate D (requires separate DB authorization).

### `F-22` — Co-Teacher Persistence Limitation Blocks Multi-Teacher Course Publication
- **Category:** Publication and Scheduling Integrity
- **Status:** `VERIFIED`
- **File Paths:** [`engine/ingest.py`](../../../engine/ingest.py) (lines 95–106), [`engine/solver.py`](../../../engine/solver.py) (lines 759–770), [`lib/core/models/routine_model.dart`](../../../lib/core/models/routine_model.dart) (lines 56–91), [`lib/features/admin/services/timetable_engine_service.dart`](../../../lib/features/admin/services/timetable_engine_service.dart) (lines 306–309), [`supabase/migrations/014_publish_routine_safeupdate.sql`](../../../supabase/migrations/014_publish_routine_safeupdate.sql) (lines 81–91)
- **Relevant Symbols:** `Offering.teacher` / `Offering.teachers`, `RoutineEntry.requiresSharedTeacherStorage`, `TimetableEngineService.publishToRoutines`, `publish_routine`
- **What Source Demonstrates:**
  - `engine/ingest.py` preserves all split/co-teaching acronyms in `Offering.teachers` (and `solver.py` returns both scalar `teacher_code` and array `teachers[]`), holding all co-teachers free during those slots.
  - However, `public.routines` and `publish_routine()` only accept/store a single scalar `teacher_code` and `teacher_name` (`jsonb_to_recordset(p_rows)` omits `teachers`).
  - Therefore, `RoutineEntry.requiresSharedTeacherStorage` (`teacherCodes.any((c) => c != teacherCode)`) intentionally **blocks `publishToRoutines()`** in Flutter (`timetable_engine_service.dart:306-309`), forcing shared-faculty routines into private JSON draft export only.
- **Agreement / Conflict:** Agrees with `react-admin-backend-contracts` §4 ("Co-Teacher Pre-Publish Guard").
- **Consequences:** Any semester containing co-taught courses cannot be published via `publish_routine()` to live students/teachers until Postgres supports multi-teacher storage (or an explicit committee rule dictates single-primary publication).
- **Recommended Follow-Up:** Implement the exact same co-teacher pre-publish guard in React Web Track 1 (Phase 3); defer multi-teacher DB schema extension (`routines.teacher_codes text[]` or join table + mobile compatibility update) to Phase 4 Gate D under separate DB authorization.

### `F-23` — Manual CRUD in `RoutineService` Bypasses Server Validation & Versioning
- **Category:** Publication and Scheduling Integrity
- **Status:** `VERIFIED`
- **File Paths:** [`lib/features/routine/services/routine_service.dart`](../../../lib/features/routine/services/routine_service.dart) (lines 46–56), [`lib/features/admin/controllers/routine_admin_controller.dart`](../../../lib/features/admin/controllers/routine_admin_controller.dart) (lines 69–97)
- **Relevant Symbols:** `RoutineService.create/update/delete`, `RoutineAdminController.save/delete`
- **What Source Demonstrates:** Direct `.insert()`, `.update()`, `.delete()` calls on `public.routines` mutate the active schedule without running clash validation, checking `timetable_settings`, or creating/updating a `routine_versions` entry (so `routine_versions.row_count` drifts).
- **Agreement / Conflict:** Matches `CLAUDE.md:47` ("manual CRUD via `RoutineAdminController` still writes directly until Phase 3 unifies server-authoritative validation").
- **Consequences:** Admins can manually introduce teacher/room/cohort double-bookings directly into production.
- **Recommended Follow-Up:** In React Web Track 1 (Phase 3), preserve live `routines` CRUD parity **with client-side clash warnings and explicit live-mutation disclosure**; unify under server-authoritative validation in Phase 4 Gate C/D.

---

## 8. Excel Parsing

### `F-24` — Architectural Split Between Input Course Distribution Parser (Python) and Output Rendered Routine Parser (Dart)
- **Category:** Excel Parsing
- **Status:** `VERIFIED`
- **File Paths:** [`engine/distribution.py`](../../../engine/distribution.py), [`engine/ingest.py`](../../../engine/ingest.py), [`lib/features/admin/services/routine_workbook_parser.dart`](../../../lib/features/admin/services/routine_workbook_parser.dart)
- **Relevant Symbols:** `DistributionDraft.create`, `ingest.ingest_workbook`, `RoutineWorkbookParser.parse`
- **What Source Demonstrates:** The repository has **two non-overlapping Excel parsers** for completely different workbook types:
  1. **Python (`engine/distribution.py` + `ingest.py` via `openpyxl`):** Parses **input** `Course Distribution` sheets (row 5 header binding by prefix, row 6+ data, columns `A`–`L`, reading both formula text via `data_only=False` and cached values via `data_only=True` for `J`/`L`, raising `ValidationError` on un-cached formulas, computing SHA-256, deduplicating split rows per `(cohort, course code)`).
  2. **Dart (`routine_workbook_parser.dart` via `archive` + `xml`):** Parses **output/rendered** timetable workbooks (`Sunday..Saturday` day-sheet grids starting at row 3, or fallback tabular sheets with headers in rows 1–40). Uses `ClockTime.repairSequence`, `RoomIdentity.key`, and validates 5 clash/slot checks (`teacher_clashes`, `cohort_clashes`, `room_clashes`, `invalid_time_slots`, `unavailable_room_assignments`). Note: Dart's `_parseSessionText` parses `<COURSE_CODE> <SINGLE_TEACHER_TOKEN> <ROOM>` and does not parse multi-teacher `/` expressions in day sheets.
  3. **React Web (`apps/web/`):** Currently contains **zero** Excel parsing code.
- **Agreement / Conflict:** Agrees with the architectural separation goal of avoiding duplicated domain logic across clients: `Course Distribution` (`A`–`L`) parsing stays in Python (`engine/`), and the owner's **provisional preference** for rendered routine `.xlsx` upload is an **additive, non-mutating FastAPI parse/validation endpoint** rather than mandating a parallel TypeScript port of `RoutineWorkbookParser`.
- **Consequences:** Requiring a duplicate TypeScript parser port would reproduce complex ZIP/XML day-sheet heuristics (`ClockTime.repairSequence`, `RoomIdentity.key`) in browser code, whereas keeping Flutter's Dart `RoutineWorkbookParser` unchanged initially and adding a Python parse endpoint avoids client-side parser drift. Adding an endpoint to `engine/main.py` requires **separate review and owner authorization**.
- **Recommended Follow-Up:** Remove any mandatory TypeScript `RoutineWorkbookParser` port assumption. Keep Phase 3 `grid`, `manage`, and `generate` independent of `.xlsx` upload, and gate the Track 1 `.xlsx` upload workflow behind separate review, shared-fixture equivalence validation (matching `test/routine_workbook_parser_test.dart`), and explicit owner authorization of the additive FastAPI parse/validation endpoint.

---

## 9. Realtime and Synchronization

### `F-25` — `supabase_realtime` Publishes Only `cancellations`, Not `routines` or `notifications`
- **Category:** Realtime and Synchronization
- **Status:** `VERIFIED` (in SQL files) / `NOT VERIFIED` (in hosted dashboard)
- **File Paths:** [`supabase/migrations/007_cancellations_schema.sql`](../../../supabase/migrations/007_cancellations_schema.sql) (lines 97–110), [`supabase/reconciliation/004_test_realtime.sql`](../../../supabase/reconciliation/004_test_realtime.sql) (lines 12–33), [`lib/features/find_teacher/services/teacher_location_service.dart`](../../../lib/features/find_teacher/services/teacher_location_service.dart) (lines 39–45), [`lib/features/rooms/services/room_status_service.dart`](../../../lib/features/rooms/services/room_status_service.dart) (lines 20–26), [`lib/features/notifications/services/notification_service.dart`](../../../lib/features/notifications/services/notification_service.dart) (lines 105–115), [`apps/web/src/App.tsx`](../../../apps/web/src/App.tsx) (lines 24–31)
- **What Source Demonstrates:**
  - `007_cancellations_schema.sql` adds **only `public.cancellations`** to `supabase_realtime`, and `004_test_realtime.sql` confirms the reconstructed publication membership contains only `cancellations`.
  - No migration adds `public.routines` or `public.notifications` to `supabase_realtime`—even though Flutter's `TeacherLocationService.streamAllRoutines()`, `RoomStatusService.streamAllRoutines()`, and `NotificationService.subscribeToInserts()` open Postgres Changes channels against `routines` and `notifications`.
  - `apps/web/src/App.tsx:24-31` and `AdminDashboardPage.tsx:184-216` correctly avoid relying on Realtime for `routines`/`notifications`, instead using `TanStack Query` `refetchOnWindowFocus: true` and an explicit `Refresh` button with `Last checked` clock.
- **Agreement / Conflict:** Agrees with `react-admin-backend-contracts` §4 ("Realtime Truth") and blueprint synchronization strategy.
- **Consequences:** Assuming WebSockets push `routines` or `notifications` updates in React Web without dashboard verification would cause stale admin views.
- **Recommended Follow-Up:** Keep TanStack Query focus-refetch + explicit invalidation after mutations across all React Web screens; verify live `pg_publication_tables` in Phase 0.

---

## 10. Testing and CI/CD

### `F-26` — `apps/web/` Lacks Test Frameworks and CI Coverage
- **Category:** Testing and CI/CD
- **Status:** `VERIFIED`
- **File Paths:** [`apps/web/package.json`](../../../apps/web/package.json), [`.github/workflows/validate.yml`](../../../.github/workflows/validate.yml), [`.github/workflows/supabase_keep_alive.yml`](../../../.github/workflows/supabase_keep_alive.yml)
- **What Source Demonstrates:**
  - `apps/web/package.json` defines only `dev`, `build` (`tsc -b && vite build`), `typecheck` (`tsc --noEmit`), and `preview`—zero unit/component tests (`Vitest`), zero E2E tests (`Playwright`), and zero automated WCAG AA contrast checks.
  - `.github/workflows/validate.yml` runs Python domain pytest (`test_domain.py`, `test_normalized_domain.py`, `test_legacy_mapping.py`), `tool/tests`, Deno `send-push` tests, and `tool/task1_local_checks.py --task2` (using `supabase/setup-cli@v1` in CI). It runs **no** `apps/web/` checks, **no** `invite-admin` Deno tests (`handler_test.js`, `callback_policy_test.js`), and **no** Flutter tests.
  - `.github/workflows/supabase_keep_alive.yml` pings `https://yxqyrjyzxitrgkhgauli.supabase.co/rest/v1/` every 3 days to prevent free-tier pausing.
- **Agreement / Conflict:** Highlights a major gap against blueprint requirements (automated WCAG AA contrast verification, Vitest + Playwright).
- **Consequences:** Regressions in auth gating, Academic Ledger contrast tokens, capability locks, or TypeScript builds would not be caught automatically in CI.
- **Recommended Follow-Up:** Configure Vitest + Playwright + automated contrast verification in Phase 1 and add an `apps/web/` CI job (plus `invite-admin` Deno tests) in Phase 5C. *(Note: `validate.yml:48` uses `supabase/setup-cli` in GitHub Actions, whereas local developer workflows forbid Supabase CLI—keep local verification CLI-free.)*

---

## 11. Deployment Readiness

### `F-27` — Missing Cloudflare Pages SPA Routing & Header Configuration
- **Category:** Deployment Readiness
- **Status:** `VERIFIED`
- **File Paths:** [`apps/web/vite.config.ts`](../../../apps/web/vite.config.ts), [`apps/web/.env.example`](../../../apps/web/.env.example), `apps/web/public/` (absent)
- **What Source Demonstrates:**
  - `apps/web/vite.config.ts` compiles a clean BrowserRouter SPA (`createBrowserRouter` / `<BrowserRouter>` in `App.tsx:84`).
  - However, `apps/web/public/_redirects` (or `wrangler.toml` / `_headers`) does **not** exist in the repository (`Get-ChildItem apps/web/public` returned nothing).
  - Additionally, hosted Cloudflare Pages project config, Supabase Auth Redirect URLs, Google OAuth web origin settings, and `invite-admin` `AUTH_WEB_CALLBACK_URLS` env var are `NOT VERIFIED` locally.
- **Agreement / Conflict:** Confirms blueprint observation that Cloudflare Pages hosting is provisional and unconfigured.
- **Consequences:** Deploying `apps/web/dist/` directly to Cloudflare Pages without SPA fallback rules causes HTTP `404` on direct navigation or browser reload of `/login`, `/reset-password`, or `/admin/*`.
- **Recommended Follow-Up:** Add `apps/web/public/_redirects` (`/* /index.html 200`) and security `_headers` before any preview/production Cloudflare Pages deploy in Phase 5C, and obtain owner confirmation of exact origins in Supabase Auth & `AUTH_WEB_CALLBACK_URLS`.

---

## 12. Governance and Documentation Discrepancies

### `F-28` — Contradictory Framework & Theme Rules in `AGENTS.md`, `CLAUDE.md`, and `.agents/skills/`
- **Category:** Governance and Documentation Discrepancies
- **Status:** `CONTRADICTED`
- **File Paths:** [`AGENTS.md`](../../../AGENTS.md) (lines 16, 20, 74, 96, 100), [`CLAUDE.md`](../../../CLAUDE.md) (lines 9, 11, 42, 93–95, 129, 144–145), [`PROJECT_STRUCTURE.md`](../../../PROJECT_STRUCTURE.md), [`.agents/skills/react-web-academic-design-system/SKILL.md`](../../../.agents/skills/react-web-academic-design-system/SKILL.md) (lines 70–98), [`.agents/skills/react-web-motion-and-craft/SKILL.md`](../../../.agents/skills/react-web-motion-and-craft/SKILL.md) (lines 65–82), [`UNIVERSE_CURRENT_ARCHITECTURE_AND_UI_UX_DOSSIER.md`](../../../UNIVERSE_CURRENT_ARCHITECTURE_AND_UI_UX_DOSSIER.md) (lines 9, 200–201)
- **What Source Demonstrates:**
  1. **React Prohibition vs. React Adoption:** `AGENTS.md` §2/§6 and `CLAUDE.md` §1/§6 still instruct *"No unrequested React/Next.js rewrite"* and *"Never replace Flutter with React/Next.js"*, while the end of both files defines `React Web v1 Locked Theme` for `apps/web/`.
  2. **Superseded Design System Locked in Rules:** `AGENTS.md`, `CLAUDE.md`, and both `react-web-*` skills lock **Spatial Orbit Engine** (`Space Grotesk`, light+dark, cyan-emerald, 4-layer kinetic loop), contradicting the owner's new **UniVerse Academic Ledger** blueprint.
  3. **Non-Existent Route/Symbol in `CLAUDE.md`:** `CLAUDE.md:42` documents web `/auth-callback` and `AuthCallbackLocation`, neither of which exists in `lib/` or `apps/web/`.
  4. **Inaccurate Table Names in Dossier:** `UNIVERSE_CURRENT_ARCHITECTURE_AND_UI_UX_DOSSIER.md:200-201, 257-258` lists non-existent table names (`routine_runs`, `rooms`, `faculty`, `faculty_course_eligibility`, `timetable_configs`, `timetable_schedule_configs`, `whitelist`, `batches`, `sections`, `course_distribution_workbooks`, `course_distribution_cell_corrections`, `course_distribution_audit_logs`, `canonical_courses`) instead of the real SQL names (`timetable_runs`, `timetable_rooms`, `timetable_faculty`, `timetable_course_eligibility`, `timetable_settings`, `whitelists`, `cohorts`, `student_groups`, `course_distribution_sources`, `course_distribution_corrections`, `departments`).
  5. **Stale `PROJECT_STRUCTURE.md`:** Omits `apps/web/` and `.agents/skills/react-web-*` / `react-admin-backend-contracts`.
  6. **Misleading Bucket Label in Flutter UI:** `lib/features/admin/screens/upload_routine_screen.dart:268` displays `'Archive source .xlsx to routine-workbooks bucket'`, whereas `AppConstants.bucketTimetables` uploads to `'timetables'`.
- **Agreement / Conflict:** Documents extensive drift across governance and architecture reports vs. actual code/blueprint.
- **Consequences:** Future AI agents reading `AGENTS.md`, `CLAUDE.md`, or `.agents/skills/` will follow superseded Spatial Orbit styling or refuse React Web implementation unless governance is updated first.
- **Recommended Follow-Up:** Keep `F-28` historical discrepancy baseline recorded; resolved in Phase 0 (`AGENTS.md`, `CLAUDE.md`, `PROJECT_STRUCTURE.md`, `.agents/skills/react-web-*`, and `web_phase_0_1_spatial_orbit_foundation.md` updated to **UniVerse Academic Ledger** and `public.whitelists` — see [`WEB_PHASE_0_COMPATIBILITY_AND_AUDIT_ADDENDUM.md`](../WEB_PHASE_0_COMPATIBILITY_AND_AUDIT_ADDENDUM.md)).

---

## 13. Consolidated Unavailable Facts & Hosted Unknowns

While PostgreSQL tables, columns, exact baseline row counts, RLS policies, RPC signatures, Storage buckets/policies, triggers, and `supabase_realtime` membership were verified on **both** `yxqyrjyzxitrgkhgauli` and `oqwvxplteqtlrhktsplj` via owner-run SQL diagnostics (`F-20`, [`WEB_PHASE_0_COMPATIBILITY_AND_AUDIT_ADDENDUM.md`](../WEB_PHASE_0_COMPATIBILITY_AND_AUDIT_ADDENDUM.md) §4), the following dashboard/runtime settings **cannot** be determined from SQL queries or repository files alone:

1. **Auth, OAuth & Edge Function Dashboard Configuration (Prod & Staging):**
   - Registered **Site URL** and **Redirect URLs** in Supabase Auth URL Configuration.
   - Google Cloud Console OAuth 2.0 authorized web origins/redirect URIs and iOS native `GIDClientID` / reversed client scheme (`F-31`).
   - Deployed source status and configured Edge Function secrets (`AUTH_WEB_CALLBACK_URLS`, `PUSH_WEBHOOK_SECRET`, `FCM_SERVICE_ACCOUNT`, SMTP sender settings) on both `yxqyrjyzxitrgkhgauli` and staging `oqwvxplteqtlrhktsplj`.
2. **Render Deployment & Hosting:**
   - Live status, cold-start behavior, and actual `SOLVER_WORKERS` / Python version running on `https://universe-timetable-engine.onrender.com`.
   - Cloudflare Pages target project creation/DNS confirmation (Phase 5C). *(Owner has already approved `oqwvxplteqtlrhktsplj` as the clean non-production staging target and confirmed Deep Botanical Pine for Phase 1A.)*

---

## 14. Phase 0 Targeted Read-Only Inspection Addendum

### `F-29` — `supabase/functions/send-push/` Service-Role Credentials & Profile Access
- **Category:** Edge Functions & Push Security
- **Status:** `VERIFIED` (local source) / `NOT VERIFIED` (hosted deployment & webhook trigger state)
- **File Paths:** [`supabase/functions/send-push/index.ts`](../../../supabase/functions/send-push/index.ts), [`supabase/functions/send-push/audience.js`](../../../supabase/functions/send-push/audience.js), [`supabase/functions/send-push/webhook_auth.js`](../../../supabase/functions/send-push/webhook_auth.js)
- **Relevant Symbols:** `createClient(url, serviceKey)`, `resolveNotificationTargets`, `protectWebhook`, `Deno.serve`
- **Verified Behavior:**
  - `index.ts:125-128` loads `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` from `Deno.env.get(...)` and instantiates an admin client (`createClient(url, serviceKey)`), which **bypasses PostgreSQL RLS**.
  - `resolveNotificationTargets` (`audience.js:3-22`) queries `profiles.select('id')` (optionally filtering `.eq('role' | 'batch' | 'section', ...)`) and `device_tokens.select('token').in('user_id', userIds)`. `index.ts:170` deletes invalid `device_tokens`.
  - Inbound requests are wrapped by `protectWebhook` (`webhook_auth.js:3-22`), requiring `x-webhook-secret` to match `PUSH_WEBHOOK_SECRET` (returning `503` if unset, `401` on mismatch/missing). Zero secrets or env values are exposed in source.
- **Unverified Hosted Dependencies:** `index.ts:1-6` explicitly notes `"TEST-ONLY AUTHORIZATION CHANGE - NOT DEPLOYED"`, so live Edge Function deployment, configured secrets, and database webhook attachment in hosted projects remain `NOT VERIFIED`.
- **Recommendation:** Tightening `profiles_select` RLS to self + admin (`id = auth.uid() or public.is_admin()`) in Phase 5B is **safe for `send-push`** because `send-push` executes with `SUPABASE_SERVICE_ROLE_KEY`; verify live Edge Function & trigger presence via Phase 0 SQL inspection before production rollout.

### `F-30` — Flutter Avatar Storage Uploads & `avatars` Bucket Ownership
- **Category:** Flutter Mobile Storage & RLS
- **Status:** `VERIFIED` (local code & migrations) / `NOT VERIFIED` (hosted `storage.objects` contents)
- **File Paths:** [`lib/core/constants/app_constants.dart`](../../../lib/core/constants/app_constants.dart) (line 123), [`lib/features/profile/services/profile_service.dart`](../../../lib/features/profile/services/profile_service.dart), [`lib/features/profile/screens/profile_screen.dart`](../../../lib/features/profile/screens/profile_screen.dart) (lines 330, 341, 343), [`lib/shared/widgets/u_avatar.dart`](../../../lib/shared/widgets/u_avatar.dart), [`lib/shared/widgets/u_local_avatar.dart`](../../../lib/shared/widgets/u_local_avatar.dart), [`lib/features/auth/services/auth_service.dart`](../../../lib/features/auth/services/auth_service.dart) (lines 241, 283, 327), [`supabase/migrations/006_enable_rls_all_tables.sql`](../../../supabase/migrations/006_enable_rls_all_tables.sql) (lines 269–288)
- **Relevant Symbols:** `AppConstants.bucketAvatars`, `ProfileService.updateProfile`, `UAvatar`, `ULocalAvatar`
- **Verified Behavior:**
  - Although `AppConstants.bucketAvatars = 'avatars'` exists (`app_constants.dart:123`), **zero Dart code in `lib/` uploads or deletes files in the `avatars` Storage bucket**.
  - User-selected custom avatars in `ProfileScreen` / `ULocalAvatar` are persisted locally via `SharedPreferences` under key `'avatar_preset_$userId'` (`profile_screen.dart:330-343`, `u_local_avatar.dart:57`), rendering 8 built-in Phosphor icon presets.
  - Remote profile pictures (`profiles.avatar_url`) are populated only during registration/post-login from Google OAuth metadata (`user.userMetadata?['avatar_url']` in `auth_service.dart:241,283,327`) and read via `CachedNetworkImage` (`u_avatar.dart:43`). `ProfileService.updateProfile` only updates `public.profiles` columns (`id = userId`).
  - Meanwhile, `006_enable_rls_all_tables.sql:278-288` currently grants `storage_auth_insert/update/delete` (`to authenticated using (true)`) across **all** buckets indiscriminately.
- **Unverified Hosted Dependencies:** Existing hosted `storage.buckets` configuration and any legacy files in `avatars` remain `NOT VERIFIED` locally.
- **Recommendation:** Replacing wildcard `storage_auth_*` policies in Phase 5B with bucket-scoped rules (e.g., `timetables` admin-only, `resources` teacher/admin-only, and `avatars` strictly user-folder-scoped `(storage.foldername(name))[1] = auth.uid()::text` or disabled for authenticated uploads until intentionally implemented) breaks **zero existing Flutter features**.

### `F-31` — iOS Baseline Configuration (`ios/Runner/Info.plist`)
- **Category:** Mobile Cross-Platform Compatibility
- **Status:** `VERIFIED` (local `ios/` & Dart config) / `NOT VERIFIED` (macOS/Xcode build & hosted Apple/OAuth registration)
- **File Paths:** [`ios/Runner/Info.plist`](../../../ios/Runner/Info.plist) (lines 48–64), [`lib/features/auth/services/auth_callback_policy.dart`](../../../lib/features/auth/services/auth_callback_policy.dart) (lines 26–30), [`lib/features/auth/services/auth_service.dart`](../../../lib/features/auth/services/auth_service.dart) (lines 38–81)
- **Relevant Configuration:** `FlutterDeepLinkingEnabled`, `CFBundleURLTypes` / `CFBundleURLSchemes`, `AuthCallbackPolicy.loginCallback` / `recoveryCallback`
- **Verified Behavior:**
  - `ios/Runner/Info.plist:50-51` sets `<key>FlutterDeepLinkingEnabled</key><false/>` so `app_links` / `supabase_flutter` own auth deep links directly without duplicate framework routing.
  - `Info.plist:58-61` registers two custom `CFBundleURLSchemes`: **`io.supabase.universe`** and **`com.example.universe`**.
  - This matches `AuthCallbackPolicy` (`auth_callback_policy.dart:27,29`), which routes native mobile auth/recovery/invitation callbacks to `com.example.universe://login-callback/` and `com.example.universe://reset-callback/`.
- **Unresolved Dependencies:** `ios/Runner/Info.plist` does **not** declare a `GIDClientID` key or reversed Google iOS URL scheme (`com.googleusercontent.apps.*`), and `AuthService` (`auth_service.dart:38-42`) passes only `serverClientId: AppConstants.googleWebClientId` (no iOS `clientId` or Apple Xcode OAuth verification ran here).
- **Recommendation:** Do **not** modify `ios/` files during Web Phase 0. Preserve `com.example.universe` / `io.supabase.universe` schemes and Auth callback compatibility continuously, distinguish active iOS feature expansion (deferred) from iOS compatibility verification (mandatory in Phase 5A/5C), and record native iOS Google Sign-In (`GIDClientID` / reversed client scheme) as an unresolved iOS-specific build prerequisite for future mobile builds.
