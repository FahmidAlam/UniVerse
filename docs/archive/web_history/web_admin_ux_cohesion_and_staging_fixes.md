# UniVerse React Web v1 — Consolidated Staging Bug Fixes, Phase 4B Remediation & Admin UX/UI Cohesion Upgrade

**Date:** 2026-11-22  
**Scope:** Standalone React Web (`apps/web/` only) + completion report (`docs/implementation/web_admin_ux_cohesion_and_staging_fixes.md`) + visual QA screenshots (`docs/screenshots/web_ux_cohesion/`).  
**Boundary Compliance:** Zero modifications to `lib/`, `android/`, `ios/`, `test/`, `engine/`, `supabase/`, or `apps/web/.env.local`. No new npm dependencies installed.

---

## 1. Summary of Changes by Workstream

### Workstream 1 — Critical Live Staging Bug Fixes (P0)
1. **Bug #1 (`EngineResultSchema` optional `source_contract`):**
   - Updated [`timetableEngineService.ts`](file:///d:/flutter%20projects/universe_v1/apps/web/src/features/routine/services/timetableEngineService.ts), [`routine/types.ts`](file:///d:/flutter%20projects/universe_v1/apps/web/src/features/routine/types.ts), and [`GenerateRoutineTab.tsx`](file:///d:/flutter%20projects/universe_v1/apps/web/src/features/routine/components/GenerateRoutineTab.tsx) so `source_contract` is `.optional().nullable()` on `EngineResultSchema` and `EngineStatusSchema` while still validating `source_contract` strictly whenever present.
   - Live Render Track 1 `/api/timetable/result/{job_id}` responses without `source_contract` now parse cleanly, unlocking Candidate Preview, the 20-counter Validation Ledger, `.xlsx` download, and the 3-step Guarded Publication Pipeline.
2. **Bug #2 (Eliminate HTTP `500` `P0002` RPC probes on `/admin/scheduling`):**
   - Replaced nil-UUID (`00000000-...`) `supabase.rpc(...)` calls in [`schedulingCapabilities.ts`](file:///d:/flutter%20projects/universe_v1/apps/web/src/features/scheduling/services/schedulingCapabilities.ts) with PostgREST OpenAPI root schema inspection (`GET /rest/v1/` with `Accept: application/openapi+json` checking `/rpc/read_course_distribution_revision` and `/rpc/append_course_distribution_correction`) alongside `course_distribution_revisions` + `course_distribution_sources` queries (plus a fallback to `read_course_distribution_revision` only when a real `revision.id` exists).
   - Added [`getSupabaseConfig()`](file:///d:/flutter%20projects/universe_v1/apps/web/src/services/supabase.ts) to support the OpenAPI probe. Gates C & D remain unconditionally `locked` in Live Mode.
3. **Row-Level Whitelist Delete Hardening:**
   - Added `e.stopPropagation()` to row-level Edit and Delete whitelist buttons in [`ManageUsersPage.tsx`](file:///d:/flutter%20projects/universe_v1/apps/web/src/features/admin/pages/ManageUsersPage.tsx) so row click handlers never intercept `ConfirmDialog` triggers.

### Workstream 2 — Phase 4B Workbench Defects & `AcademicTimetableMatrix` Reuse (P0)
1. **Dynamic Row 19 Readiness Title:** Updated [`schedulingWorkbenchStore.ts`](file:///d:/flutter%20projects/universe_v1/apps/web/src/features/scheduling/store/schedulingWorkbenchStore.ts) and [`PreflightReadinessStage.tsx`](file:///d:/flutter%20projects/universe_v1/apps/web/src/features/scheduling/components/PreflightReadinessStage.tsx) so resolving Row 19 updates its title dynamically from `"Unassigned Lab Instructor on Row 19 (CSE-2202)"` to `"Lab Instructor Assigned on Row 19 (CSE-2202)"`.
2. **Eliminated Filler `Verified` / `Baseline` Badges:** Removed green `Verified` and `Baseline` pills from normal rows in [`DistributionLedgerStage.tsx`](file:///d:/flutter%20projects/universe_v1/apps/web/src/features/scheduling/components/DistributionLedgerStage.tsx), [`PolicyStudioStage.tsx`](file:///d:/flutter%20projects/universe_v1/apps/web/src/features/scheduling/components/PolicyStudioStage.tsx), and [`PreflightReadinessStage.tsx`](file:///d:/flutter%20projects/universe_v1/apps/web/src/features/scheduling/components/PreflightReadinessStage.tsx), rendering quiet `--ink-muted` text instead and reserving colored badges for exceptions (`Conflict`, `Pending`, `Overlay`, `Override Active`, `Blocker`, `Advisory`).
3. **Stage 5 Real 7-Day `AcademicTimetableMatrix` & Batch 58–61 Alignment:** Replaced Stage 5's hardcoded 4-day / 50-minute toy table in [`ReviewDiffPublishStage.tsx`](file:///d:/flutter%20projects/universe_v1/apps/web/src/features/scheduling/components/ReviewDiffPublishStage.tsx) with the real reusable [`AcademicTimetableMatrix`](file:///d:/flutter%20projects/universe_v1/apps/web/src/features/routine/components/AcademicTimetableMatrix.tsx) (`overrideRows={PREVIEW_CANDIDATE_ROWS}`), updated [`schedulingPreviewFixtures.ts`](file:///d:/flutter%20projects/universe_v1/apps/web/src/features/scheduling/data/schedulingPreviewFixtures.ts) to Leading University CSE batch conventions (`Batch 58–61`, 23 offerings, 75-minute 7-slot periods across `Sun–Sat`), and styled the simulated publish CTA as a secondary button (`Preview Publish Flow (Simulated)`).
4. **Toast Leakage Fix:** Updated [`AdminShell.tsx`](file:///d:/flutter%20projects/universe_v1/apps/web/src/features/admin/AdminShell.tsx) toast dismissal `useEffect` to depend on `[location.pathname, location.search]` so switching `?tab=` or `?stage=` immediately clears stale toasts.
5. **Corner-Triangle Restraint:** Removed `slot-override-corner` from ordinary unmodified `Cls (J)` and `/Wk (L)` cells in [`DistributionLedgerStage.tsx`](file:///d:/flutter%20projects/universe_v1/apps/web/src/features/scheduling/components/DistributionLedgerStage.tsx), reserving corner triangles strictly for audited overrides and formula/cached discrepancies.
6. **Copy Accuracy:** Corrected `"16 policy pillars"` → `"5 policy pillars (R1–R16)"` in [`DistributionLedgerStage.tsx`](file:///d:/flutter%20projects/universe_v1/apps/web/src/features/scheduling/components/DistributionLedgerStage.tsx).

### Workstream 3 — Collapsible Sidebar & Cross-Screen Deep Links (P1)
- **Collapsible Desktop Sidebar ([`AdminShell.tsx`](file:///d:/flutter%20projects/universe_v1/apps/web/src/features/admin/AdminShell.tsx)):** Added `240px ↔ 68px` compact icon rail toggle (`SidebarSimple` + `[` shortcut) persisted in `localStorage` (`universe-sidebar-collapsed`), Radix Tooltips on compact rail items, collapsible nav groups (`OPERATIONS`, `CONFIGURATION`, `DIRECTORY & ALERTS`) keeping the active group open, hairline separation above `STAGED` catalog links, quiet amber `0` attention indicators derived from cached dashboard counts, and a `Full-Screen Matrix →` jump on [`AdminRoutinePage.tsx`](file:///d:/flutter%20projects/universe_v1/apps/web/src/features/routine/pages/AdminRoutinePage.tsx).
- **Cross-Screen Deep Links:** Added `?lens=&entity=&day=&search=&from=` URL query support and contextual `← Back to ...` pill in [`AcademicTimetableMatrix.tsx`](file:///d:/flutter%20projects/universe_v1/apps/web/src/features/routine/components/AcademicTimetableMatrix.tsx), `Inspect R7 Faculty` link on Dashboard, `View Room Schedule →` on Room Pools, and `View Teaching Schedule →` + `?filter=r7` sync on Faculty.

### Workstream 4 — Operational Usability, Visualizations & Staged Reference Views (P1–P2)
1. **Dashboard ([`AdminDashboardPage.tsx`](file:///d:/flutter%20projects/universe_v1/apps/web/src/features/admin/pages/AdminDashboardPage.tsx), [`adminDashboardService.ts`](file:///d:/flutter%20projects/universe_v1/apps/web/src/features/admin/services/adminDashboardService.ts)):** Added interactive 4-step **Routine Lifecycle Workflow Strip**, live **R7 Off-Day Advisory** banner, and backend-derived **Weekly Published Slot Load by Day (`Sun–Sat`)** Recharts v3 bar chart.
2. **Course Eligibility ([`ManageCourseEligibilityPage.tsx`](file:///d:/flutter%20projects/universe_v1/apps/web/src/features/admin/pages/ManageCourseEligibilityPage.tsx), [`eligibilityService.ts`](file:///d:/flutter%20projects/universe_v1/apps/web/src/features/admin/services/eligibilityService.ts)):** Added `Flat Ledger | Assign by Faculty` toggle with `cmdk` faculty selector, filterable derived course checklist, inline priority (`1–5`), batch upsert (`onConflict: "acronym,course_code"`), `StickyDirtyBar`, and Live Coverage Summary Strip.
3. **Faculty ([`ManageFacultyPage.tsx`](file:///d:/flutter%20projects/universe_v1/apps/web/src/features/admin/pages/ManageFacultyPage.tsx)):** Added 7-Day Off-Day Visual Strip (`S M T W T F S`) per row and collapsible Weekly Active Faculty Availability strip (`Sun–Sat`).
4. **Room Pools ([`ManageRoomsPage.tsx`](file:///d:/flutter%20projects/universe_v1/apps/web/src/features/admin/pages/ManageRoomsPage.tsx)):** Added Pool Capacity Summary Strip (`Theory`, `Labs`, `Galleries`, `Inactive`) and inline optimistic Active/Inactive Radix Switch per row with rollback on failure.
5. **Timetable Settings ([`TimetableSettingsPage.tsx`](file:///d:/flutter%20projects/universe_v1/apps/web/src/features/admin/pages/TimetableSettingsPage.tsx)):** Added clickable Visual Daily Period Timeline Strip (`P1–P7`, `Break Col G`, `Fri P4 Jummah Lock`, optional `Online P8`) and inline proportional weight bars on Tab 3.
6. **Staged Catalog Reference Views ([`StagedCoursesReferencePage.tsx`](file:///d:/flutter%20projects/universe_v1/apps/web/src/features/admin/pages/StagedCoursesReferencePage.tsx), [`StagedBatchesReferencePage.tsx`](file:///d:/flutter%20projects/universe_v1/apps/web/src/features/admin/pages/StagedBatchesReferencePage.tsx), [`App.tsx`](file:///d:/flutter%20projects/universe_v1/apps/web/src/App.tsx)):** Replaced stub walls with read-only derived reference tables over `public.routines` (`is_active = true`) featuring persistent `Staged Catalog · Read-Only Reference Derived From Active Published Routine` banners, zero writable inputs, `/` search, and `Inspect in Matrix →` deep links.

### Workstream 5 — Restrained Motion & Interaction Polish (P3)
- Added `150ms ease-out` crossfade + `4px` micro-lift on main tab/stage switches in [`AdminRoutinePage.tsx`](file:///d:/flutter%20projects/universe_v1/apps/web/src/features/routine/pages/AdminRoutinePage.tsx), [`TimetableSettingsPage.tsx`](file:///d:/flutter%20projects/universe_v1/apps/web/src/features/admin/pages/TimetableSettingsPage.tsx), and [`SchedulingWorkbenchPage.tsx`](file:///d:/flutter%20projects/universe_v1/apps/web/src/features/scheduling/pages/SchedulingWorkbenchPage.tsx), obeying `<MotionConfig reducedMotion="user">`.

---

## 2. Automated Verification Results (Executed After Final Edit)

| Check | Command | Result |
|---|---|---|
| TypeScript | `npm --prefix apps/web run typecheck` | **Passed** (`0` errors) |
| Production Build | `npm --prefix apps/web run build` (`tsc -b && vite build`) | **Passed** (`0` errors; `5872` modules transformed) |
| Vitest Unit Suite | `npm --prefix apps/web test` | **Passed** (**15 test files, 97/97 tests** including [`consolidatedFixesAndCohesion.test.tsx`](file:///d:/flutter%20projects/universe_v1/apps/web/tests/unit/consolidatedFixesAndCohesion.test.tsx) and all 30 WCAG AA contrast tests) |
| Playwright E2E (Mocked HTTP) | `npm --prefix apps/web run test:e2e` | **Passed** (**11/11 specs** across `cohesion.spec.ts`, `phase1a`, `phase2a`, `phase2b`, `phase3`, `phase4`; zero console/page errors, zero HTTP 500s, zero horizontal overflow across `1440×900`, `1024×768`, `390×844`) |
| Visual QA Screenshots | `docs/screenshots/web_ux_cohesion/` | **11 captures generated & inspected** (expanded/collapsed sidebar, Eligibility `Assign by Faculty`, Faculty 7-day strips, Settings visual timeline, Staged Courses, Workbench Stages 1/3/5, `1024×768`, `390×844`) |

---

## 3. Items Awaiting Live Staging Re-Verification (`oqwvxplteqtlrhktsplj`)

Because all automated Vitest and Playwright runs use mocked HTTP and stay isolated from `apps/web/.env.local`, the following three live staging checks await owner/live-browser re-verification against `oqwvxplteqtlrhktsplj` and `https://universe-timetable-engine.onrender.com`:
1. **Bug #1 Live Render Publish (Suite 3.3):** Re-submit Track 1 `.xlsx` generation on `/admin/routine?tab=generate` against live Render and confirm Candidate Preview, 20-counter Validation Ledger, `.xlsx` download, and the 3-step Guarded Publication Pipeline complete end-to-end.
2. **Bug #2 Zero-500 Staging Probe (Suite 4):** Visit `/admin/scheduling` in Live Mode against `oqwvxplteqtlrhktsplj` and confirm `0` HTTP `500` responses in Chrome DevTools Network while Gates A & B verify and Gates C & D remain `Locked`.
3. **Suite 1 Fresh First-Login `409` Check:** Sign in once with a fresh whitelisted staging admin account (`stage-admin-test@example.com`) to exercise the first-login `409` profile auto-provisioning path.
