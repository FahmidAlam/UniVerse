# UniVerse — Final Automated Full-Stack E2E Audit Report (Wave 2B / Stage 5C)

- **Date:** 2026-11-27
- **Branch:** `fix/final-e2e-audit-polish` (branched from `main` after discovering 6 genuine UI/UX/React defects during E2E testing)
- **Browser Automation:** Playwright `1.65.1` driving installed Google Chrome (`channel: "chrome"`, headless) + `supabase_mcp`
- **Environments Audited:**
  - **Staging (Mutating E2E Authorized):** Supabase `oqwvxplteqtlrhktsplj` + local `uvicorn` (`http://127.0.0.1:8000`, `ENGINE_AUTH_MODE=enforced`) + local Vite (`http://localhost:5173`)
  - **Production (100% Read-Only Probes Only):** Supabase `yxqyrjyzxitrgkhgauli`, Cloudflare Pages `https://universe-admin-exi.pages.dev`, Render Engine `https://universe-timetable-engine.onrender.com`

---

## 1. Executive Summary & Pass/Fail Matrix

All **7 E2E Suites** completed and passed after fixing **6 genuine defects** discovered during live Chrome verification on branch `fix/final-e2e-audit-polish`. Production remained **100% read-only** throughout the audit.

| Suite | Scope | Verdict | Key Verified Evidence |
| :--- | :--- | :--- | :--- |
| **Suite 1** | Auth, Authz, PKCE & Security Boundaries | **PASS** | `/` zero Supabase/FastAPI calls; non-admin bounced to `/access-required` with `0` admin chrome; PKCE `code_challenge_method=s256` & `prompt=select_account`; Prod GoTrue `/settings` `200` (`external.google: true`) & `/authorize` `302`; Render & local engine `200`/`401`/`403`; Edge Functions `401`; `get_advisors(security)` `0` errors on Staging & Prod. |
| **Suite 2** | Gate C Catalogs CRUD + Reload Persistence | **PASS** | Courses (`PHY-9102` + R11), Batches (`99-Z` + R1 override/reset), Faculty (Hybrid R7 0/1 off-days pill, R7 D3 3-day switch, R9 SUST switch, R5 guest picker, R4 Day×Slot + non-overlapping `StickyDirtyBar`), Rooms (`ECL-99` `ecl_lab`/`physics_lab` Day×Slot picker), Course Eligibility & Settings (R15 6/7-slot) all persisted across `Ctrl+R` and cleaned up. |
| **Suite 3** | Full Routine Lifecycle (Generate → Restart → Publish → Modify → Upload → Rollback) | **PASS** | CP-SAT `POST /api/timetable/generate` `200`, `OPTIMAL`, Hybrid R7/R6 (`TFB` `partial_hybrid`, `TFC` `solver_resolved`), `Passed (20/20)`; survived full `uvicorn` restart (`200` on `/status`, `/result`, `/download`, `/jobs`); archiving `publish_routine()` `200` preserved prior 4 rows (`is_active=false`) + `snapshot_rows` + `teacher_codes[]`; Matrix lenses + clash guard + edit + Manage CRUD; Phase 3B upload parse `200` with `0` DB mutations; Archive v2a 2D preview + `.xlsx` download + Archive v2b `restore_routine_version()` `200` restored baseline 4 rows. |
| **Suite 4** | Track 2 Committee Scheduling Workbench (`/admin/scheduling`, Gates A–D) | **PASS** | Header verified `Live · Gates A–D` and `Gate A–D: Verified`; Stage 1 Distribution Ledger loaded synthetic revision `#901 (v1)`; Stage 2 Policy Studio saved `policy_snapshot` (`v1 · 4bf2527bac`, `auto_resolve_undeclared_off_days=true`, `allow_sessional_across_break=false`); Stage 3 `POST /api/timetable/validate-policy-readiness` `200` (10 checks persisted); Stage 4 `GET /api/timetable/jobs` `200` & `POST /api/timetable/generate` `200`; Stage 5 Review/Diff panel verified (`Co-Teachers: text[] array live`). |
| **Suite 5** | Dashboard, Users, Broadcasts, Resources & Profile | **PASS** | `/admin/dashboard` live counts & green `Engine v2.0.0` pill; `/admin/users` Directory (`3` rows) & Whitelists (`3` rows); `/admin/broadcast` create → reload persist → delete cleanly on Staging; `/admin/resources` (`1` row); `/admin/profile` verified signed-in admin details; `0` console/page/HTTP errors. |
| **Suite 6** | Visual Craft, Theme, Reduced Motion & Responsive QA | **PASS** | Light (`oklch(0.982 0.002 250)`) ↔ Dark (`oklch(0.138 0.003 250)`) theme switch verified via `ThemeSwitcher`; `prefers-reduced-motion: reduce` disables looping animations (`0` active `.animate-pulse` after Defect #5 fix); `1440×900`, `1024×768`, and `390×844` across all 7 routes verified `scrollWidth <= innerWidth`, `0` console errors, `0` page errors, `0` unexpected HTTP `>= 400` after Defect #4 and #6 fixes. |
| **Suite 7** | Cross-Stack Automated Regression Sweep | **PASS** | Python engine `285 passed, 1 skipped`; Python tool `18 passed, 7 subtests passed`; Edge Function audience `14 passed`; React Web `typecheck` `0` errors, Vitest `23/23` files (`201/201` tests), `vite build` clean; Flutter `analyze` `0` issues, `flutter test` `188/188` passed. |

---

## 2. Detailed Verification Results by Suite

### Suite 1 — Authentication, Authorization & Security Boundaries
- **Public Entry (`/`):** Confirmed `0` outbound Supabase or FastAPI requests on load, interactive specimen controls functional in Light & Dark modes, `0` console/page errors.
- **Role Gate & Admin Auth:** Non-admin Staging Student session redirected to `/access-required`; direct navigation to `/admin/dashboard` bounced back to `/access-required` with `0` sidebar/admin chrome elements (`sidebar=0`, `adminNavLinks=0`). Staging Admin login reached `/admin/dashboard` with live counts and green `Engine v2.0.0` pill.
- **OAuth PKCE & Callback Hygiene:** `Continue with Google` constructed valid PKCE authorize URL (`provider=google`, `code_challenge`, `code_challenge_method=s256`, `prompt=select_account`, exact `redirect_to`) with `localStorage` PKCE verifier. Navigating to `/?error=access_denied&error_description=User+cancelled` redirected to `/login`, scrubbed query parameters, and rendered `[data-testid="login-error-alert"]`.
- **Production Read-Only Probes:**
  - `GET https://universe-admin-exi.pages.dev/` → `200`; `GET https://universe-bfi.pages.dev/` → `200`.
  - `GET https://yxqyrjyzxitrgkhgauli.supabase.co/auth/v1/settings` (with publishable `apikey`) → `200` (`external.google: true`, `external.email: true`).
  - `GET https://yxqyrjyzxitrgkhgauli.supabase.co/auth/v1/authorize?provider=google&redirect_to=https://universe-admin-exi.pages.dev/` → `302` to Google OAuth with `redirect_uri` targeting `yxqyrjyzxitrgkhgauli.supabase.co/auth/v1/callback`.
  - `GET https://universe-timetable-engine.onrender.com/` → `200` (`version: "2.0.0"`, `auth_mode: "enforced"`).
  - Unauthenticated `POST /api/timetable/generate` & `POST /api/timetable/validate-policy-readiness` → `401` on both Production Render and local Staging `uvicorn`.
  - Non-admin Student JWT `POST /api/timetable/generate` & `POST /api/timetable/validate-policy-readiness` on local Staging `uvicorn` → `403` (`{"detail":"Admin role required."}`).
  - Unauthenticated `POST /functions/v1/send-push` & `POST /functions/v1/invite-admin` → `401` on both Production and Staging.
  - `supabase_mcp/get_advisors(type="security")` on both Production and Staging → **0 errors**, **0** `function_search_path_mutable` warnings, **0** `anon_security_definer_function_executable` warnings.

### Suite 2 — Configuration & Gate C Catalogs (Staging CRUD + Persistence)
- `/admin/timetable/courses`: Created synthetic `PHY-9102` with R11 Physics Lab toggle → persisted after `Ctrl+R` → deleted cleanly.
- `/admin/timetable/batches`: Created `99-Z` with R1 `Thu+Fri` weekend override → persisted after `Ctrl+R` → 1-click Reset persisted → deleted cleanly.
- `/admin/timetable/faculty`: Verified Hybrid R7 badge on `TFB` (`1 of 2 declared`) and synthetic `E2EF` (`0 of 2 declared`), R7 D3 `Allow 3 off-days` switch, R9 SUST adjunct switch, R5 guest slot picker, and R4 Day×Slot matrix with zero overlap from `StickyDirtyBar` → persisted after `Ctrl+R` → deleted cleanly.
- `/admin/timetable/rooms`: Created `ECL-99`, verified `ecl_lab` & `physics_lab` Day×Slot availability window picker → persisted after `Ctrl+R` → deleted cleanly.
- `/admin/timetable/course-eligibility` & `/admin/timetable/settings`: Verified clean load, R15 `6-Slot Grid` / `7-Slot Grid` controls, and zero errors.

### Suite 3 — Full Routine Lifecycle (Staging)
1. **Generate (`/admin/routine?tab=distribution` → `?tab=generate`):** Pasted 2 synthetic offerings (`CSE-1101` assigned to `TFC` with `0` declared off-days; `CSE-1102` assigned to `TFB` with `1` declared off-day). Verified Gate C Policy Preflight Strip, `POST /api/timetable/generate` → `200` (`job_id: 60b6a5cb8caf`), `OPTIMAL` outcome banner, Hybrid R7/R6 `Resolved Faculty Off-Days` table (`TFB` `partial_hybrid` `Fri, Sat`; `TFC` `solver_resolved` `Fri, Sat`), `Soft Optimization Scorecard`, and `Passed (20/20)` validation verdict.
2. **Durable Job Survival Across Engine Restart:** Killed local `uvicorn` (`task-201`), started a fresh `uvicorn` process (`task-376`), and confirmed HTTP `200` on:
   - `GET /api/timetable/status/60b6a5cb8caf` (`state: "done"`, `workbook_storage_path: "solver_jobs/60b6a5cb8caf.xlsx"`)
   - `GET /api/timetable/result/60b6a5cb8caf` (`outcome: "OPTIMAL"`, `4` rows, `validation.ok: true`)
   - `GET /api/timetable/download/60b6a5cb8caf` (`322,709` bytes, valid `PK` OOXML `.xlsx`)
   - `GET /api/timetable/jobs` (`count: 1`, includes `60b6a5cb8caf`)
3. **Non-Destructive Archiving Publication (`publish_routine()`):**
   - Step 1: Storage upload `POST /storage/v1/object/timetables/CSE_Routine_Staging_Test_2026_1795790666599.xlsx` → `200`
   - Step 2: `POST /rest/v1/rpc/publish_routine` → `200` (`row_count: 4`, `archived_count: 4`, `version_id: 37a87a95-e530-4cfc-ba85-b7db65d8653f`)
   - Step 3: `POST /rest/v1/timetable_runs` → `201`
   - SQL verified prior 4 `routines` rows preserved with `is_active = false`, prior version `ce3284ca-ce02-410f-9244-22e3063e84ce` populated `snapshot_rows` (`4` rows), and new active rows populated `teacher_codes[]`.
4. **Routine Modification (`?tab=grid` & `?tab=manage`):** Verified `Section` (`COHORT`), `Faculty` (`FACULTY`), and `Room` (`ROOM`) lenses, `Compact List` toggle, docked slot inspector, live clash guard (`2 schedule clash warning(s) detected`), non-clashing room edit persisted across reload, and Manage tab Add (`POST /rest/v1/routines` `201`) + Delete (`DELETE /rest/v1/routines` `204`) verified cleanly.
5. **Phase 3B Rendered Workbook Upload (`?tab=upload`):** Uploaded downloaded `.xlsx` → `POST /api/timetable/parse-rendered-workbook` → `200`, `[data-testid="upload-2d-preview"]` rendered, `0` DB write requests during parse.
6. **Archive v2a & v2b Rollback (`?tab=archive`):** Verified direct `.xlsx` download, `Preview in 2D Grid` (`Historical Archive Preview — Read-Only`), exit via `Back to Archive Ledger`, and 1-click `Restore Version` (`POST /rest/v1/rpc/restore_routine_version` → `200`, `restored_from_version_id: ce3284ca-ce02-410f-9244-22e3063e84ce`), with SQL confirming the 4 baseline Staging active rows restored.

### Suite 4 — Track 2 Committee Scheduling Workbench (`/admin/scheduling`)
- Header confirmed `Live · Gates A–D` and `Gate A: Verified`, `Gate B: Verified`, `Gate C: Verified`, `Gate D: Verified`.
- **Stage 1:** Loaded synthetic accepted revision `#901 (v1)` with `2` offerings (`CSE-1101`, `CSE-1102`).
- **Stage 2:** Confirmed `auto_resolve_undeclared_off_days=true`, `allow_sessional_across_break=false`, saved `POST /rest/v1/rpc/save_policy_snapshot` → `200`, rendered SHA-256 provenance badge (`v1 · 4bf2527bac`).
- **Stage 3:** `POST /api/timetable/validate-policy-readiness` → `200` (`10` checks evaluated and persisted to `course_distribution_artifacts`).
- **Stage 4:** `GET /api/timetable/jobs` → `200`; `POST /api/timetable/generate` → `200` (created durable job `383e98228763`; expected `INPUT_ERROR: Persisted source contract is incomplete` for minimal synthetic Track 2 fixture).
- **Stage 5:** Verified `live-gate-d-review-panel` and `live-freshness-publish-card` (`Validation: current`, `Co-Teachers: text[] array live`).

### Suites 5 & 6 — Admin Operations, Visual Craft, Theme & Responsive QA
- **Suite 5:** Dashboard, Users (Directory + Whitelists), Broadcasts (create → reload → delete on Staging with zero FCM webhooks), Resources, and Profile all passed with `0` console/page/HTTP errors.
- **Suite 6:** Verified Light ↔ Dark switching via `ThemeSwitcher`, `prefers-reduced-motion: reduce`, and all 21 `(route × viewport)` combinations across `1440×900`, `1024×768`, and `390×844` with `0` horizontal overflow, `0` console errors, `0` page errors, and `0` unexpected `>= 400` responses after applying fixes below.

### Suite 7 — Cross-Stack Automated Regression Sweep
| Check Command | Latest Result |
| :--- | :--- |
| `engine\.venv\Scripts\python.exe -m pytest engine/tests -q` | **285 passed, 1 skipped**, 1 deprecation warning (`exit 0`) |
| `engine\.venv\Scripts\python.exe -m pytest tool/tests -q` | **18 passed, 7 subtests passed** (`exit 0`) |
| `node -e "import('./supabase/functions/send-push/audience_cases.js').then(m => m.runAudienceTests()).then(console.log)"` | **`{ passed: 14 }`** (`exit 0`) |
| `npm --prefix apps/web run typecheck` | **0 TypeScript errors** (`exit 0`) |
| `npm --prefix apps/web test` | **23/23 test files passed · 201/201 tests passed** (`exit 0`) |
| `npm --prefix apps/web run build` | **Built cleanly in 16.82s** (`exit 0`) |
| `flutter analyze --no-pub` | **No issues found!** (`exit 0`) |
| `flutter test --exclude-tags visual_capture` | **188/188 passed** (`exit 0`) |

---

## 3. Genuine Defects Discovered & Fixed (`fix/final-e2e-audit-polish`)

| # | Severity | Root Cause & File | Fix Applied & Verification |
| :--- | :--- | :--- | :--- |
| **1** | Medium | `apps/web/src/features/routine/pages/AdminRoutinePage.tsx`: `workbenchBadgeLabel` stopped at `gatesABCLive` and rendered `"Gates A–C Live · D Locked"` with `<LockSimple />` even when Gate D was unlocked. | Added `gatesABCDLive` branch rendering `"Gates A–D Live"` with `<ShieldCheck />` and `lab` tone. Added unit test in `phase3bUploadAndArchivePreview.test.tsx` + re-verified in Chrome. |
| **2** | Medium | `apps/web/src/features/admin/pages/AdminDashboardPage.tsx`: `Track 2 & Feature Governance` card rendered static `SUBFEATURE_CAPABILITIES` (`Locked · Gates A–D`, `Staged · No DB`) instead of live probed capabilities. | Added `resolveLiveSubfeatureCapabilities()` in `capabilityRegistry.ts` (preserving static fail-closed defaults) and wired shared `["scheduling-live-gates", isDevPreview]` query into `AdminDashboardPage`. Added unit tests in `capabilityRegistry.test.ts` & `adminDashboard.test.tsx` + re-verified in Chrome. |
| **3** | High | `apps/web/src/features/auth/pages/LoginPage.tsx`: `<motion.div key={\`login-shake-${shakeCount}\`}>` unmounted/remounted `<form>` on every validation or auth error shake, wiping typed email/password inputs. | Removed dynamic React `key` and alternated shake keyframes cleanly on `shakeCount % 2` without remounting `<form>`. Added unit test in `oauthPkceFlow.test.tsx` + re-verified in Chrome (including post-signout login transition). |
| **4** | Medium | `apps/web/src/features/routine/components/AcademicTimetableMatrix.tsx`: `renderSlotButton` and Compact List keyed items strictly by `row.id`, emitting React `"Each child in a list should have a unique 'key' prop"` console errors when Archive 2D Preview / parsed `.xlsx` rows lacked DB `id`. | Added deterministic composite fallback key (`row.id ?? ...`) for both 2D Matrix slots and Compact List rows. Re-verified `0` console errors during Archive 2D Preview in Chrome. |
| **5** | Low | `apps/web/src/styles/app.css`: `@media (prefers-reduced-motion: reduce)` zeroed `--dur-*` tokens but left Tailwind `.animate-pulse` / `.animate-bounce` / `.animate-ping` looping animations running (`4` active `pulse:2s` elements observed). | Added `@media (prefers-reduced-motion: reduce)` rule disabling `.animate-pulse`, `.animate-bounce`, `.animate-ping` animations and `scroll-behavior`. Re-verified `0` active pulsing animations under `reducedMotion: 'reduce'` in Chrome. |
| **6** | Medium | `apps/web/src/features/scheduling/components/DistributionLedgerStage.tsx`: Revision selector row (`flex items-center gap-2` + unconstrained `<select>`) overflowed `390×844` mobile viewport (`scrollWidth = 459 > 390`). | Added `max-w-full flex-wrap` on container and `min-w-0 max-w-full flex-1 sm:flex-initial` on `<select>`. Re-verified hydrated `/admin/scheduling` at `390×844` (`scrollWidth = 390`, `overflowX = false`). |

---

## 4. Cleanup Status & Staging SQL Restore Block

- **Completed Automatically:**
  - `apps/web/.env.local` restored back to `VITE_TIMETABLE_BASE_URL=https://universe-timetable-engine.onrender.com`.
  - Temporary local `uvicorn` and `vite` daemons stopped cleanly.
  - All 3 synthetic Staging Storage `.xlsx` objects (`CSE_Routine_Staging_Test_2026_1795790666599.xlsx`, `solver_jobs/60b6a5cb8caf.xlsx`, `solver_jobs/e30ba1360145.xlsx`) deleted via Supabase Storage API (`HTTP 200`).
  - Temporary Playwright scratch scripts and credential files deleted.
- **Owner-Executed Optional Staging SQL Cleanup (Staging `oqwvxplteqtlrhktsplj` only):**
  Because `supabase_mcp` automatically cancelled the destructive `DELETE` SQL confirmation, run the following single transaction in **Staging Supabase Dashboard (`oqwvxplteqtlrhktsplj`) → SQL Editor** to remove the remaining synthetic E2E database rows (`TFC`, synthetic `solver_jobs`/`routine_versions`, synthetic Track 2 `e2e00000-...` rows, and temporary `e2e.audit.*` test users):

```sql
BEGIN;
DELETE FROM public.routines WHERE id NOT IN ('6b37fa7b-ee4c-4a2f-a74a-eedad11b38bf','78eca7a3-c94c-4a96-88a6-74a9a02c62a8','ecbe03cc-a712-4f26-905b-940b0501f16a','fe891713-9f1f-4484-a746-5d0ef945e179');
UPDATE public.routines SET is_active = true WHERE id IN ('6b37fa7b-ee4c-4a2f-a74a-eedad11b38bf','78eca7a3-c94c-4a96-88a6-74a9a02c62a8','ecbe03cc-a712-4f26-905b-940b0501f16a','fe891713-9f1f-4484-a746-5d0ef945e179');
UPDATE public.routine_versions SET is_active = true, snapshot_rows = NULL WHERE id = 'ce3284ca-ce02-410f-9244-22e3063e84ce';
DELETE FROM public.routine_versions WHERE id <> 'ce3284ca-ce02-410f-9244-22e3063e84ce';
DELETE FROM public.solver_jobs;
DELETE FROM public.timetable_runs WHERE created_at >= '2026-11-27 00:00:00+00';
DELETE FROM public.policy_snapshots WHERE id <> 'f8ce6067-d408-4b97-9e77-292e1bf015bb';
DELETE FROM public.timetable_course_eligibility WHERE id = 'e2e00000-0000-4000-8000-000000000021';
DELETE FROM public.timetable_faculty WHERE id = 'e2e00000-0000-4000-8000-000000000020';
DELETE FROM public.course_distribution_artifacts WHERE revision_id = 'e2e00000-0000-4000-8000-000000000016';
ALTER TABLE public.course_distribution_corrections DISABLE TRIGGER USER;
DELETE FROM public.course_distribution_corrections WHERE revision_id = 'e2e00000-0000-4000-8000-000000000016';
ALTER TABLE public.course_distribution_corrections ENABLE TRIGGER USER;
DELETE FROM public.course_distribution_revisions WHERE id = 'e2e00000-0000-4000-8000-000000000016';
ALTER TABLE public.course_distribution_sources DISABLE TRIGGER USER;
DELETE FROM public.course_distribution_sources WHERE id = 'e2e00000-0000-4000-8000-000000000015';
ALTER TABLE public.course_distribution_sources ENABLE TRIGGER USER;
DELETE FROM public.scheduling_scopes WHERE id = 'e2e00000-0000-4000-8000-000000000014';
DELETE FROM public.departments WHERE id = 'e2e00000-0000-4000-8000-000000000013';
DELETE FROM public.academic_terms WHERE id = 'e2e00000-0000-4000-8000-000000000012';
DELETE FROM public.academic_years WHERE id = 'e2e00000-0000-4000-8000-000000000011';
DELETE FROM public.academic_calendars WHERE id = 'e2e00000-0000-4000-8000-000000000010';
DELETE FROM public.profiles WHERE id IN ('e2e00000-0000-4000-8000-000000000001','e2e00000-0000-4000-8000-000000000002');
DELETE FROM public.whitelists WHERE email IN ('e2e.audit.admin@example.com','e2e.audit.student@example.com');
DELETE FROM auth.identities WHERE user_id IN ('e2e00000-0000-4000-8000-000000000001','e2e00000-0000-4000-8000-000000000002');
DELETE FROM auth.users WHERE id IN ('e2e00000-0000-4000-8000-000000000001','e2e00000-0000-4000-8000-000000000002');
COMMIT;
```
