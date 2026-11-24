# UniVerse React Web v1 — Phase 2B Micro-Fixes & Phase 3 Completion Report

## 1. Execution Summary

Completed all **3 Phase 2B micro-fixes** and full **Phase 3 (Track 1 Operational Routine Console & Custom 2D Academic Timetable Matrix)** strictly inside `apps/web/` and targeted documentation (`docs/architecture/` & `docs/implementation/`). Zero edits were made to `lib/`, `android/`, `ios/`, `test/`, `engine/`, `supabase/`, or `apps/web/.env.local`.

---

## 2. Part 1 — Phase 2B Micro-Fixes

1. **`idx: 8, Col L` Online Slot Compatibility with Python Engine (`engine/solver.py`, `engine/render.py` -> `settingsService.ts`, `buildEngineConfig.ts`):**
   - **Read-Only Engine Audit Result:**
     - `engine/solver.py` (`_normalize_config`, `solve`): filters `usable = [p for p in periods if int(p['idx']) not in excluded]`, checks `len({int(p['idx']) for p in usable}) == len(usable)`, and validates non-overlapping monotonic time spans via `_minutes()`. It uses dictionary lookups (`pmeta = {int(p['idx']): p}`, `slot_rank = {p: i for i, p in enumerate(pidx)}`) and does **not** require contiguous indices `1..N`.
     - `engine/render.py` (`render_bytes`, `_write_period_headers`, `_break_span`): builds `pcol = {int(p['idx']): column_index_from_string(p['col'])}`, validates unique `idx` and unique `col` with `col >= 4` and `col != break_col` (`7` / `G`), and adds `set(pcol.values())` to `session_cols` so `Col L` (`12`) is cleared, headed, and populated cleanly across all 3 configurations:
       - (a) 7 regular slots (`P1–P7`, `idx: 1..7`, `D..K`) with `allow_online_periods: false`
       - (b) 7 regular slots (`P1–P7`, `idx: 1..7`, `D..K`) + separate online slot (`idx: 8`, `col: "L"`, `allow_online_periods: true`)
       - (c) 6 regular slots (`P1–P6`, `idx: 1..6`, `D..J`) + separate online slot (`idx: 8`, `col: "L"`, `allow_online_periods: true`)
   - **Hardening Applied:** Added `ensureSolverSafePeriods()` in [`apps/web/src/features/admin/services/settingsService.ts`](../../apps/web/src/features/admin/services/settingsService.ts) (used by `toSettingsUpsertPayload()` and [`buildEngineConfig.ts`](../../apps/web/src/features/routine/services/buildEngineConfig.ts)) to guarantee unique integer `idx`, unique uppercase `col` (never overlapping `A..C` or break column `G`), and `HH:MM` 24-hour clocks. Verified across all 3 modes in [`engineConfig.test.ts`](../../apps/web/tests/unit/engineConfig.test.ts).

2. **Eliminated Redundant Dual Dirty Bars on `TimetableSettingsPage.tsx`:**
   - Removed the duplicate top-right inline unsaved bar in [`apps/web/src/features/admin/pages/TimetableSettingsPage.tsx`](../../apps/web/src/features/admin/pages/TimetableSettingsPage.tsx), retaining a single docked, non-occluding `StickyDirtyBar` (`data-testid="sticky-dirty-bar"`) at the bottom of the workspace. Verified visually in [`09_settings_dirty_fixed_1440x900.png`](../screenshots/web_phase_3/09_settings_dirty_fixed_1440x900.png) and asserted in [`phase3.spec.ts`](../../apps/web/tests/e2e/phase3.spec.ts).

3. **Synced 2 Stale Table Cells in `WEB_PHASE_2_DESIGN_BRIEF.md`:**
   - Updated the `rooms` and `faculty` notes in the Route Governance Summary table of [`docs/architecture/WEB_PHASE_2_DESIGN_BRIEF.md`](../architecture/WEB_PHASE_2_DESIGN_BRIEF.md) to reflect strictly pinned 8-column baseline queries with zero non-DB probes.

---

## 3. Part 2 — Phase 3 Implementation (Track 1)

### Module A: Shared Routine & Engine Services + Store
- [`apps/web/src/core/utils/roomIdentity.ts`](../../apps/web/src/core/utils/roomIdentity.ts): Cycle-safe `RoomIdentity.key()` / `RoomIdentity.currentKey()` (`PHY LAB -> RAB-106`) plus `splitJointSections()`, `matchesJointSection()`, and `jointSectionsOverlap()` (`B+C` parity with Flutter `RoutineEntry.matchesStudent`).
- [`apps/web/src/features/routine/types.ts`](../../apps/web/src/features/routine/types.ts): Typed contracts for `RoutineRow`, `RoutineVersionRecord`, `EngineConfigPayload`, `EngineStatusResponse`, `EngineResultResponse`, `EngineValidation`, and `PublishPipelineResult`.
- [`apps/web/src/features/routine/services/routineService.ts`](../../apps/web/src/features/routine/services/routineService.ts): Live CRUD over `public.routines` & `public.routine_versions` (`is_active = true`), `ClockTime.toHms()` (`HH:MM:SS`) normalization, and client-side `detectRoutineClashes()` checking Teacher, Room (ignoring `"TBA"` and resolving room aliases), and Cohort (`B+C` joint overlap) clashes.
- [`apps/web/src/features/routine/services/buildEngineConfig.ts`](../../apps/web/src/features/routine/services/buildEngineConfig.ts): Dynamic assembly of FastAPI `config` JSON from active `timetable_rooms`, active `timetable_faculty`, `timetable_course_eligibility`, and `timetable_settings` (`id = 1`), emitting zero Phase A non-DB keys and `HH:MM` period clocks.
- [`apps/web/src/features/routine/services/generationProfile.ts`](../../apps/web/src/features/routine/services/generationProfile.ts): Unsigned 32-bit IEEE `crc32()`, Zod-validated `GenerationProfileV1` (`universe-generation-profile-v1`, 1 MB limit, `distribution` vs. `fixed` policy, cycle-checked `room_aliases`), `verifyGenerationProfileSource()`, and private draft exporter (`universe-routine-draft-v1`).
- [`apps/web/src/features/routine/services/validationGate.ts`](../../apps/web/src/features/routine/services/validationGate.ts): Exact 20-counter `blockingValidationErrorFor()` parity port, `inspectValidationCounters()`, `requiresSharedTeacherStorage()` / `findCoTeacherBlockers()` scanning both `rows` and `service_rows` (`F-22`), and `assessBaselineConfigForPublish()` (`F-20`).
- [`apps/web/src/features/routine/services/timetableEngineService.ts`](../../apps/web/src/features/routine/services/timetableEngineService.ts): Zod-validated FastAPI HTTP client (`POST /api/timetable/generate`, `GET /api/timetable/status/{job_id}`, `result/{job_id}`, `download/{job_id}`), bounded polling (`2,000 ms` × `240`, `+4,000 ms` `429` backoff without incrementing error count, fail on 5th consecutive non-429 error, `404 Unknown job_id` -> `EngineJobError("engine-restart")`), and 3-step `publishRoutinePipeline()` (Storage bucket `timetables` -> `publish_routine` RPC -> best-effort `timetable_runs` + optional `notifications` with Service Recovery `retryRecordTimetableRun`).
- [`apps/web/src/features/routine/store/routineOperationsStore.ts`](../../apps/web/src/features/routine/store/routineOperationsStore.ts): Zustand store preserving solver polling state, candidate results, workbook selection, and matrix lens/view state across lazy tab switches and `/admin/timetable/grid`.

### Module B: Custom 2D Academic Timetable Matrix
- [`apps/web/src/features/routine/components/AcademicTimetableMatrix.tsx`](../../apps/web/src/features/routine/components/AcademicTimetableMatrix.tsx) & [`TimetableGridPage.tsx`](../../apps/web/src/features/routine/pages/TimetableGridPage.tsx):
  - Zero Gregorian calendar libraries; custom CSS/table 2D grid with `O(1)` `Map<string, RoutineRow[]>` indexing, `@tanstack/react-virtual` row virtualization (`> 35` entries), smart `Sunday` default when `> 120` active rows, and `Section | Faculty | Room` unclipped lens switcher + `Matrix | Compact List` toggle (auto-defaulting to `Compact List` on `< 768px`).
  - Connected `36px` filter bar with `/` search, `cmdk` entity combobox, `Include Service Courses` toggle, upfront day counts, live match counter, and `Live Published` vs. `Candidate Preview` source switch.
  - Sticky `IBM Plex Mono` `tabular-nums` period headers, `Midday Break (Col G)` thick divider, Friday P4 Jummah hatching, semantic slot cards (`.slot-theory`, `.slot-lab`, `.slot-joint`, `.slot-conflict`), teacher hover crosshairs, corner-triangle override indicators + Radix Tooltips, and 100% full-width default opening a closable `360px` docked inspector (`>= 1100px`) or Radix drawer (`< 1100px`) with `[X]` / `Esc` close and Live Quick Add / Edit / Delete via [`RoutineSlotForm.tsx`](../../apps/web/src/features/routine/components/RoutineSlotForm.tsx).

### Module C: Operational Routine Console (`/admin/routine`)
- [`apps/web/src/features/routine/pages/AdminRoutinePage.tsx`](../../apps/web/src/features/routine/pages/AdminRoutinePage.tsx): URL-synced (`?tab=grid | manage | generate | upload`) lazy-mounting shell + compact link to Track 2 (`/admin/scheduling`, `Locked · Gates A–D`).
- [`ManagePublishedTab.tsx`](../../apps/web/src/features/routine/components/ManagePublishedTab.tsx): `DataLedgerTable` + `MasterDetailShell` CRUD over `public.routines`, `F-23` manual edit audit disclosure banner, live client-side clash warnings, hover copy, `.row-reveal-action`, and bulk delete.
- [`GenerateRoutineTab.tsx`](../../apps/web/src/features/routine/components/GenerateRoutineTab.tsx): Baseline preflight strip + `F-20` guard, `.xlsx` picker with middle filename truncation, collapsible `GenerationProfileV1` rehearsal profile slot, 4-node visual solver timeline with live `tabular-nums` elapsed timer & `404` Service Recovery card, 20-counter expandable validation diagnostic ledger, `F-22` co-teacher guard, and blocking 3-step `F-21` publish confirmation modal with `[Retry Audit Log]` recovery.
- [`UploadRoutineGatedTab.tsx`](../../apps/web/src/features/routine/components/UploadRoutineGatedTab.tsx): Honest `Gated · Phase 3B` capability card driven by [`capabilityRegistry.ts`](../../apps/web/src/core/capabilities/capabilityRegistry.ts) (zero mock upload inputs).
- Updated [`apps/web/src/App.tsx`](../../apps/web/src/App.tsx) and [`capabilityRegistry.ts`](../../apps/web/src/core/capabilities/capabilityRegistry.ts) wiring `/admin/routine` and `/admin/timetable/grid`.

---

## 4. Verification & Acceptance Evidence

All checks were executed after the final edit:

1. **TypeScript Check (`npm --prefix apps/web run typecheck`):** Passed (`0` errors).
2. **Production Build (`npm --prefix apps/web run build`):** `tsc -b && vite build` passed (`0` errors; `5858` modules transformed; zero `lucide-react`, `framer-motion`, `xlsx`, `exceljs`, or Gregorian calendar libraries in `apps/web/package.json`).
3. **Vitest Suite (`npm --prefix apps/web test`):** **12 test files, 80 tests passed** (`67` existing Phase 1A/2A/2B tests + `13` new Phase 3 tests across [`engineConfig.test.ts`](../../apps/web/tests/unit/engineConfig.test.ts), [`routineValidationGate.test.ts`](../../apps/web/tests/unit/routineValidationGate.test.ts), and [`timetableEnginePolling.test.ts`](../../apps/web/tests/unit/timetableEnginePolling.test.ts)).
4. **Playwright E2E (`npm --prefix apps/web run test:e2e`, Mocked HTTP):** **9 of 9 specs passed** (`phase1a.spec.ts` `4`, `phase2a.spec.ts` `2`, `phase2b.spec.ts` `2`, `phase3.spec.ts` `1`) with zero horizontal overflow (`scrollWidth <= innerWidth`), zero remote Supabase/Render network leaks, and zero unexpected console/page errors across `1440×900`, `1024×768`, and `390×844`.
5. **Visual QA Screenshots (`docs/screenshots/web_phase_3/`):**
   - `01_routine_grid_section_1440x900.png`
   - `02_routine_grid_inspector_1440x900.png`
   - `03_routine_grid_faculty_1440x900.png`
   - `04_routine_manage_1440x900.png`
   - `05_routine_generate_1440x900.png`
   - `06_routine_upload_gated_1440x900.png`
   - `07_routine_grid_1024x768.png`
   - `08_routine_grid_390x844.png`
   - `09_settings_dirty_fixed_1440x900.png`
6. **Edge Cases Noted:**
   - In `ManagePublishedTab` and `AcademicTimetableMatrix`, client-side clash checks cover `Teacher`, `Room` (alias-aware, ignoring `"TBA"`), and `Cohort` (`B+C` overlaps); `public.routines` still does not create a `routine_versions` archive row on manual CRUD (`F-23`), which is explicitly disclosed in the UI banner.
   - `phase2a.spec.ts` was updated with the same Windows-safe `saveScreenshot` retry wrapper already used by `phase1a.spec.ts` to avoid transient Windows file-handle locks during screenshot writes.
