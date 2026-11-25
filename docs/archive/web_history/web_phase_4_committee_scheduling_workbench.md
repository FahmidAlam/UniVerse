# UniVerse React Web v1 — Phase 3 Fixes & Phase 4B Track 2 Committee Scheduling Workbench

**Date:** 2026-11-22  
**Branch:** `feature/react-admin-web-v1` (building on Phase 3 checkpoint commit `85702a4`)  
**Scope:** Standalone React Web (`apps/web/`) — 8 Phase 3 visual/UX micro-fixes + complete Phase 4B 5-Stage Committee Scheduling Workbench (`/admin/scheduling`) with strict SQL contract parity and fail-closed Track 2 gates.

---

## 1. Part 1 — Phase 3 Visual & UX Fixes (All 8 Implemented & Verified)

1. **Upload Routine Tab Contrast & Active State ([AdminRoutinePage.tsx](file:///d:/flutter%20projects/universe_v1/apps/web/src/features/routine/pages/AdminRoutinePage.tsx)):**
   - Active tab button now renders solid `--action-primary` Charcoal Ink with `--action-primary-ink` foreground and `Phase 3B` renders on a high-contrast elevated/joint pill in both active and inactive states.
2. **Header Collisions & Topbar Clipping ([AdminShell.tsx](file:///d:/flutter%20projects/universe_v1/apps/web/src/features/admin/AdminShell.tsx), [TimetableGridPage.tsx](file:///d:/flutter%20projects/universe_v1/apps/web/src/features/routine/pages/TimetableGridPage.tsx)):**
   - Removed `sticky top-0` from the `52px` `<header>` so scrolled views and full-page Playwright captures never slice page `<h1>` elements.
   - Topbar omits the duplicate `Generate Routine` shortcut CTA on `/admin/routine`, `/admin/timetable/grid`, and `/admin/scheduling`, uses compact mobile labels (`Routine Matrix`, `Workbench`), and renders a desktop breadcrumb label (`Track 1 · Weekly Matrix`) instead of duplicating `<h1>Operational Routine Matrix</h1>`.
3. **Notification Toast Position & Auto-Dismiss ([App.tsx](file:///d:/flutter%20projects/universe_v1/apps/web/src/App.tsx), [AdminShell.tsx](file:///d:/flutter%20projects/universe_v1/apps/web/src/features/admin/AdminShell.tsx)):**
   - Moved Sonner `<Toaster />` to `position="bottom-left"` with `closeButton` and `duration={3500}`.
   - Added `useEffect(() => { toast.dismiss(); }, [location.pathname])` inside `AdminShell` so stale notifications clear immediately on route navigation.
4. **Clean Institutional Copy ([ManagePublishedTab.tsx](file:///d:/flutter%20projects/universe_v1/apps/web/src/features/routine/components/ManagePublishedTab.tsx), [GenerateRoutineTab.tsx](file:///d:/flutter%20projects/universe_v1/apps/web/src/features/routine/components/GenerateRoutineTab.tsx), [validationGate.ts](file:///d:/flutter%20projects/universe_v1/apps/web/src/features/routine/services/validationGate.ts), [TimetableSettingsPage.tsx](file:///d:/flutter%20projects/universe_v1/apps/web/src/features/admin/pages/TimetableSettingsPage.tsx)):**
   - Replaced raw schema strings (`routine_versions`, `Settings Row (id=1)`, `(row id=1)`, `(timetable_course_eligibility)`, `timetable_rooms`, `timetable_faculty`, `timetable_settings`, `publish_routine()`, `public.routines`, `timetable_runs`) and removed all 20 raw `({item.key})` suffixes from the visible Validation Diagnostic Ledger.
5. **Mobile Compact List Alignment & Badges ([AcademicTimetableMatrix.tsx](file:///d:/flutter%20projects/universe_v1/apps/web/src/features/routine/components/AcademicTimetableMatrix.tsx)):**
   - Positioned room badges flush-right alongside `Batch ... · Teacher` on compact `< 640px` layouts while preserving tabular grid columns on `>= 640px`.
   - Replaced vague `Note` badges with explicit `Service` or `Co-Taught` badges.
6. **Horizontal Scroll Edge Fade ([useHorizontalScrollCue.ts](file:///d:/flutter%20projects/universe_v1/apps/web/src/core/hooks/useHorizontalScrollCue.ts), [AcademicTimetableMatrix.tsx](file:///d:/flutter%20projects/universe_v1/apps/web/src/features/routine/components/AcademicTimetableMatrix.tsx), [DataLedgerTable.tsx](file:///d:/flutter%20projects/universe_v1/apps/web/src/components/ui/DataLedgerTable.tsx)):**
   - Shared `useHorizontalScrollCue` hook applies a dynamic right-edge `mask-image` fade whenever `scrollWidth - clientWidth - scrollLeft > 4`.
7. **Pluralization & Search Placeholder ([AcademicTimetableMatrix.tsx](file:///d:/flutter%20projects/universe_v1/apps/web/src/features/routine/components/AcademicTimetableMatrix.tsx)):**
   - Day headers render `1 slot` instead of `1 slots` when count is 1, and search placeholder uses unclipped `Search course, teacher, room (/)` with `min-w-[230px]`.
8. **R15 Badge Restraint ([TimetableSettingsPage.tsx](file:///d:/flutter%20projects/universe_v1/apps/web/src/features/admin/pages/TimetableSettingsPage.tsx)):**
   - Replaced the 7 repetitive `On-Campus` `<Badge tone="theory">` pills in the P1–P7 clock ledger with muted plain text, reserving badge styling for the optional amber `Online Slot` pill.

---

## 2. Part 2 — Phase 4B Track 2 5-Stage Committee Scheduling Workbench (`/admin/scheduling`)

### Strict Backend Contract & Fail-Closed Truthfulness
- **Capabilities ([schedulingCapabilities.ts](file:///d:/flutter%20projects/universe_v1/apps/web/src/features/scheduling/services/schedulingCapabilities.ts)):** `resolveLiveSchedulingGates` and `probeLiveSchedulingCapabilities` enforce fail-closed evaluation per gate (`gateA`–`gateD`). Live Gate A/B unlock only after verifying `course_distribution_revisions(revision_version)` + `read_course_distribution_revision` + `append_course_distribution_correction`; **Gates C and D stay unconditionally locked** in Phase 4B Live Mode.
- **SQL-Exact Service ([courseDistributionService.ts](file:///d:/flutter%20projects/universe_v1/apps/web/src/features/scheduling/services/courseDistributionService.ts)):**
  - Uses exact SQL column names `revision_version` (`course_distribution_revisions`) and `scheduling_scope_id` (`course_distribution_sources`) and catalog columns `academic_terms.label` / `academic_years.label`.
  - Calls `read_course_distribution_revision({ target_revision })` and the 8-parameter `append_course_distribution_correction({ target_revision, expected_revision_version, target_row, target_column, prior_formula, prior_cached_value, next_effective_value, reason })`.
  - Catches `SQLSTATE 40001` (`StaleRevisionError`), preserves the operator's unsaved draft, reloads the latest revision version, and raises `stale-revision-conflict-banner`.
- **Reconciled Design Preview Fixtures ([schedulingPreviewFixtures.ts](file:///d:/flutter%20projects/universe_v1/apps/web/src/features/scheduling/data/schedulingPreviewFixtures.ts)):**
  - Single reconciled 23-offering dataset across Batches 2024–2021, 3 audited overlays (Row 18 Col `I`, Row 24 Col `G`, and Row 32 Col `L` formula `=J32/14` cached `3` -> `2` reconciliation), 2 conflicts (Row 19 pending instructor, Row 24 headcount capacity advisory), 16 `R1–R16` policy items across all 5 committee pillars, readiness checkpoints, simulated optimal/infeasible runs, candidate rows, and diff items.
  - Watermarked banner reads `SIMULATED PREVIEW · 23 CSE sample offerings · ZERO DATABASE WRITES`.

### Delivered Workbench Modules
- Header & URL-Synced Stepper: [SchedulingWorkbenchHeader.tsx](file:///d:/flutter%20projects/universe_v1/apps/web/src/features/scheduling/components/SchedulingWorkbenchHeader.tsx), [SchedulingWorkbenchPage.tsx](file:///d:/flutter%20projects/universe_v1/apps/web/src/features/scheduling/pages/SchedulingWorkbenchPage.tsx)
- Stage 1 (12-Col TanStack Table + Virtualizer + Closable `380px` 5-Part Provenance Inspector + Audited Correction Form): [DistributionLedgerStage.tsx](file:///d:/flutter%20projects/universe_v1/apps/web/src/features/scheduling/components/DistributionLedgerStage.tsx)
- Stage 2 (5 Official Pillars `R1–R16`, 3-Step Chain, Interactive R15 6/7-Slot Strip, Reset to Baseline): [PolicyStudioStage.tsx](file:///d:/flutter%20projects/universe_v1/apps/web/src/features/scheduling/components/PolicyStudioStage.tsx)
- Stage 3 (Preflight Readiness Blockers vs Advisories & Stale Artifact Revalidation): [PreflightReadinessStage.tsx](file:///d:/flutter%20projects/universe_v1/apps/web/src/features/scheduling/components/PreflightReadinessStage.tsx)
- Stage 4 (Bound Source Contract, Soft Objective Weights & 4-Node Solve Simulation): [RevisionSolveStage.tsx](file:///d:/flutter%20projects/universe_v1/apps/web/src/features/scheduling/components/RevisionSolveStage.tsx)
- Stage 5 (Candidate 2D Matrix Preview, Diff Ledger, Artifact Freshness Gate & Simulated Publish Modal): [ReviewDiffPublishStage.tsx](file:///d:/flutter%20projects/universe_v1/apps/web/src/features/scheduling/components/ReviewDiffPublishStage.tsx)

---

## 3. Verification Results (All Run After Final Edit)

- **TypeScript (`npm --prefix apps/web run typecheck`):** 0 errors.
- **Vitest (`npm --prefix apps/web test`):** **14 test files passed / 92 tests passed (92/92)**, including new [phase3FixesRegression.test.tsx](file:///d:/flutter%20projects/universe_v1/apps/web/tests/unit/phase3FixesRegression.test.tsx) (6 tests) and [schedulingContract.test.ts](file:///d:/flutter%20projects/universe_v1/apps/web/tests/unit/schedulingContract.test.ts) (6 tests).
- **Production Bundle (`npm --prefix apps/web run build`):** Succeeded (`dist/assets/` built cleanly; zero `lucide-react`, `framer-motion`, `xlsx`, `exceljs`, or Gregorian calendar libraries present in `apps/web/package.json`).
- **Playwright E2E (`npm --prefix apps/web run test:e2e`):** **10 passed / 0 failed (10/10)** across `phase1a.spec.ts`, `phase2a.spec.ts`, `phase2b.spec.ts`, updated `phase3.spec.ts`, and new [phase4.spec.ts](file:///d:/flutter%20projects/universe_v1/apps/web/tests/e2e/phase4.spec.ts) (`1440×900`, `1024×768`, `390×844` — zero console errors, zero page errors, zero horizontal overflow, zero remote requests).
- **Inspected Phase 4 Screenshots (`docs/screenshots/web_phase_4/`):**
  - `01_p3_fix_upload_tab_1440x900.png`
  - `02_p3_fix_grid_header_1440x900.png`
  - `03_p3_fix_mobile_list_390x844.png`
  - `04_p3_fix_settings_table_1440x900.png`
  - `05_p4_live_gated_1440x900.png`
  - `06_p4_distribution_inspector_1440x900.png`
  - `07_p4_policy_studio_1440x900.png`
  - `08_p4_readiness_preflight_1440x900.png`
  - `09_p4_review_diff_publish_1440x900.png`
  - `10_p4_workbench_1024x768.png`
  - `11_p4_workbench_390x844.png`
