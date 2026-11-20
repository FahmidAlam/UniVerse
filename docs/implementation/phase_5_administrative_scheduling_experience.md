# Phase 5: Administrative Scheduling Experience & Live Routine Operations

## 1. Executive Summary & Design Philosophy

UniVerse Redesign Phase 5 delivers a comprehensive overhaul of the university administrative command center, live timetable routine operations, and the clip-free interactive scheduling workbench.

Following the successful completion of Phases 0 through 4 (foundation, visual identity, onboarding/auth, and student/teacher experiences), Phase 5 addresses the administrative control surfaces:
- **Admin Command Center:** `AdminDashboardScreen` (`/admin/dashboard`)
- **Live Routine Operations:** `AdminRoutineScreen` (`/admin/routine`) with its integrated operational tools:
  - `RoutineManagementScreen` (`?tab=manage` — Published slots list/grid, upfront slot count, adaptive modal editor)
  - `GenerateTimetableScreen` (`?tab=generate` — Live FastAPI + Google OR-Tools CP-SAT pipeline)
  - `UploadRoutineScreen` (`?tab=upload` — Rendered Routine XLSX workbook importer)
  - `TimetableGridScreen` (`/admin/timetable/grid` — Responsive filter bar with upfront counts)
- **Scheduling Workbench · Preview:** `SchedulingWorkspaceScreen` (`/admin/scheduling` & `/preview/scheduling`) across all 5 stages:
  - Stage 1: `DistributionTableDesktop`, `DistributionListMobile`, `DistributionFiltersBar`, `DistributionRecordInspector`
  - Stage 2: `SchedulingConfigurationPane` (`R1`–`R15` academic policy constraints)
  - Stage 3: `SchedulingReadinessPane` (Deterministic preflight checks & blockers)
  - Stage 4: `SchedulingGeneratePane` (Solver parameter weights, budget limits, execution monitoring)
  - Stage 5: `SchedulingReviewPane` (Section grid, faculty timetable, room occupancy, atomic publication gate)

### Synthesis of Six Design Research Principles

To ensure administrative screens clear the "commodity ceiling" and feel authored by the exact same design hand as Screens 1 through 79, Phase 5 synthesizes six key UX/UI principles:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                               PHASE 5 DESIGN PRINCIPLES                                │
├────────────────────────────────────────┬───────────────────────────────────────────────┤
│ 1. "Walmart Receipt" Edge Alignment   │ Dissolved nested 4-sided inner borders into    │
│    & Dissolved Inner Cards            │ single top-lit UCards with 1px dividers.       │
├────────────────────────────────────────┼───────────────────────────────────────────────┤
│ 2. "Checkbox Off = Gray" Signaling     │ Untouched baseline rules stay slate-gray;     │
│    Discipline                         │ semantic colors reserved for overrides/alerts.│
├────────────────────────────────────────┼───────────────────────────────────────────────┤
│ 3. Upfront Filter Context &           │ Live match count pills shown upfront; quick   │
│    "Invisible UI" on Dense Tables     │ actions revealed on desktop row hover/focus.  │
├────────────────────────────────────────┼───────────────────────────────────────────────┤
│ 4. Data-Driven Visual Shapes          │ 12-col provenance table vs. visual timelines  │
│                                       │ and axis-labeled departmental load breakdown. │
├────────────────────────────────────────┼───────────────────────────────────────────────┤
│ 5. Mural-Style Readiness &            │ Actionable 4-stage lifecycle checklist on      │
│    Service Recovery Paradox           │ dashboard; non-destructive recovery cards.    │
├────────────────────────────────────────┼───────────────────────────────────────────────┤
│ 6. True Usable-Width Ergonomics &     │ LayoutBuilder post-sidebar width (no 1024px   │
│    Slide-to-Confirm Publication Gate  │ collision); tactile slide safety control.     │
└────────────────────────────────────────┴───────────────────────────────────────────────┘
```

---

## 2. Workstream Details & Implementation

### Workstream A: Administrative Command Center & Operations Launchpad

1. **`AdminDashboardScreen` (`lib/features/admin/screens/admin_dashboard_screen.dart`):**
   - **Post-Sidebar Responsive Breakpoints:** Uses `LayoutBuilder` usable content width (`>= 880px`: 60% Left / 40% Right two-column layout; `< 880px`: vertically stacked single column).
   - **Shell Single-Header Rule:** When embedded inside `AdminDesktopShell`, suppresses duplicate inner `UAppBar` so only a single authoritative header is visible.
   - **Mural-Style Routine Lifecycle Readiness Checklist:** Persistent, actionable 4-stage readiness checklist:
     - `01 · Room Pools` (evaluates campus room counts; flags `Setup Required` if 0)
     - `02 · Faculty & Off-Days` (tracks qualified faculty teaching roster)
     - `03 · Course Eligibility & Time Grid` (monitors curriculum course rules)
     - `04 · Active Routine & Engine` (verifies live published slots; alerts if unpublished)
     - Summary badge dynamically displays `X / 4 STAGES READY` with instant drill-down routing.
   - **Departmental Schedule & Resource Load Breakdown:** Simple, axis-labeled horizontal load breakdown bar chart with tabular numerals comparing scheduled hours against department room capacities (`Theory Halls`, `Computer Labs`, `Faculty Availability`, `Period Span`).
   - **Dual-Track Scheduling Launchpad:** Clear bifurcation between:
     - `LIVE PIPELINE` (`/admin/routine`) — Live Supabase database routine operations, generator, and XLSX importer.
     - `DESIGN PREVIEW` (`/admin/scheduling`) — Interactive 5-stage preview workbench simulating academic distribution and OR-Tools CP-SAT solving without mutating live production records.
   - **Campus Operations Directory:** Hard-left identity, hard-right action directory linking to Rooms, Faculty, Course Eligibility, Broadcasts, User Management, and Global Settings.

2. **`AdminDashboardController` (`lib/features/admin/controllers/admin_dashboard_controller.dart`):**
   - Added dependency injection seams (`service`, `countsLoader`, `initialCounts`) for testability and offline mock capability without live Supabase calls.
   - Added `hasLoaded` flag and asynchronous lifecycle loading guard.

3. **`AdminService` (`lib/features/admin/services/admin_service.dart`):**
   - Implemented lazy `_supabase` client getter to protect unit and widget tests from premature global client initialization.
   - Added queries for `rooms` count and `courseEligibilities` count to feed the 4-stage readiness checklist.

---

### Workstream B: Scheduling Workbench — 1024px Collision Fix, 390px Ergonomics & Signaling Discipline

1. **`SchedulingWorkspaceScreen` (`lib/features/admin/screens/scheduling_workspace_screen.dart`):**
   - **1024px Sidebar Collision Fix:** Replaced fragile screen-level `MediaQuery.sizeOf(context).width` with `LayoutBuilder` post-sidebar usable content width (`usableWidth = constraints.maxWidth`).
   - **Three-Tier Usable-Width Responsive Architecture:**
     - `Expanded` (`usableWidth >= 1020px`): Full 12-column desktop table (`DistributionTableDesktop`) alongside a docked 360px Record Inspector (`DistributionRecordInspector`).
     - `Medium` (`680px <= usableWidth < 1020px`): Full-width desktop table; Record Inspector opens smoothly in an adaptive modal dialog (`showUAdaptiveModal`) via the toolbar inspector button.
     - `Compact` (`usableWidth < 680px`): Touch-first mobile card list (`DistributionListMobile`) with bottom-sheet inspector; zero horizontal table clipping at 390px.
   - **Unconditional Fail-Closed Preview Boundary:** Retains `isLiveWorkspaceOperational == false`. In live backend mode, clearly communicates that contract migrations are pending and refuses mock fallback.

2. **`SchedulingHeaderBar` (`lib/features/admin/scheduling/widgets/scheduling_header_bar.dart`):**
   - Post-sidebar layout wrapping cleanly at 390px.
   - Prominent `SIMULATED PREVIEW · NO DATABASE WRITES` badge.
   - Compact segmented control toggle between Live Backend and Design Preview.

3. **`SchedulingRevisionBar` (`lib/features/admin/scheduling/widgets/scheduling_revision_bar.dart`):**
   - Post-sidebar layout with adaptive wrapping at `< 1240px`.
   - Click-to-copy revision hash (`rev.sourceHash`) with immediate floating toast feedback.
   - "Seal Revision" draft snapshot dialog with explicit `SIMULATED PREVIEW` notice.

4. **`DistributionFiltersBar` (`lib/features/admin/scheduling/widgets/distribution/distribution_filters_bar.dart`):**
   - **Upfront Option Counts:** Live count pill displayed before/as you click (`Showing X of Y offerings`, `Conflicts (X)`, `Corrected (Y)`, `Pending Teacher (Z)`).
   - Responsive layout adapting search field and dropdowns between single-row and two-row configurations.
   - `onToggleInspector` callback enabling medium-tier desktop layouts to trigger modal inspection.

5. **`DistributionTableDesktop` (`lib/features/admin/scheduling/widgets/distribution/distribution_table_desktop.dart`):**
   - **"Checkbox Off = Gray" Signaling:** Baseline rows (`DistributionRecordStatus.verified`) render with calm, recessive slate-gray (`AppColors.bgElevated` / `AppColors.textSecondary`), reserving signal colors strictly for Conflict (Crimson error), Corrected (Amber warning), and Pending (Cyan info).
   - **"Invisible UI" Row Hover/Focus Reveal:** Secondary quick actions (copy course code, inspect provenance) smoothly appear on desktop row hover/focus without visual clutter.
   - Click-to-copy course code pill with clipboard confirmation.
   - Height-aware layout guard preventing overflows when parent height is constrained.

6. **`DistributionListMobile` (`lib/features/admin/scheduling/widgets/distribution/distribution_list_mobile.dart`):**
   - Touch-friendly 390px card list enforcing the calm slate-gray verified status pill.

7. **`DistributionRecordInspector` (`lib/features/admin/scheduling/widgets/distribution/distribution_record_inspector.dart`):**
   - **"Walmart Receipt" Dissolved Inner Cards:** Replaced nested 4-sided bordered cards with clean 1px top divider lines, hard-left title/identity alignment, and hard-right metric values.
   - 5-part academic provenance model:
     1. Source Workbook Evidence (`Cols A–L`)
     2. Effective Overlay Values
     3. Formula & Cached Evidence (`Cols J & L`)
     4. Deterministic Scheduling Impact Preview
     5. Audit Trail & Correction Form

8. **`SchedulingConfigurationPane` (`lib/features/admin/scheduling/widgets/configuration/scheduling_configuration_pane.dart`):**
   - Consolidated nested cards into single top-lit `UCard` sections per category (`Academic Shift`, `Faculty Compactness`, `Lab Continuity`, `Room Suitability`, `Day Interval`).
   - Default baseline items stay calm slate-gray with quiet `DEFAULT BASELINE` pills.
   - Overridden rules activate an Amber warning badge and a 3px accent left border.

9. **`SchedulingReadinessPane` (`lib/features/admin/scheduling/widgets/readiness/scheduling_readiness_pane.dart`):**
   - 3-tier preflight blocker cards (`BLOCKER`, `WARNING`, `PASS`) dissolved into clean 1px divider rows.
   - Resolved items use quiet slate-gray; unresolved blockers use high-contrast crimson with direct action buttons (`Resolve in Distribution`, `Adjust Rule`).

10. **`SchedulingGeneratePane` (`lib/features/admin/scheduling/widgets/generate/scheduling_generate_pane.dart`):**
    - Priority tier badges (`Strict Priority`, `Balanced`, `Soft Preference`) alongside tabular numerical percentages (`90%`, `80%`, `60%`).
    - Prominent `SIMULATED PREVIEW · NO ENGINE CALL` badge preventing accidental solver expectations.

11. **`SchedulingReviewPane` (`lib/features/admin/scheduling/widgets/review/scheduling_review_pane.dart`):**
    - `USegmentedControl<int>` schedule view switcher (`Section Grid`, `Faculty Schedule`, `Room Occupancy`).
    - **Slide-to-Confirm Safety Control (`_SlideToConfirmPublish`):** Tactile slider requiring deliberate dragging before routine publication can be confirmed in the publication modal, preventing accidental schedule overwrite.
    - Intrinsics-safe implementation utilizing `Align(alignment: Alignment(-1.0 + progress * 2.0, 0.0))` to support `AlertDialog` without layout exceptions.

---

### Workstream C: Live Routine Operations

1. **`AdminRoutineScreen` (`lib/features/admin/screens/admin_routine_screen.dart`):**
   - Replaced basic tab bar with accessible `USegmentedControl<int>` (`Manage Published`, `Generate Routine`, `Upload Spreadsheet`).
   - **State Preservation:** Retained `IndexedStack` to ensure background solver polling, form inputs, and parsed Excel workbooks are never reset when toggling tabs.
   - Compact top quick-link strip (`Room Vacancy Matrix`, `Grid View`, `Scheduling Workbench`).
   - Enforced Single-Header Rule inside `AdminDesktopShell`.

2. **`RoutineManagementScreen` (`lib/features/admin/screens/routine_management_screen.dart`):**
   - Upfront slot count pill (`Showing X slots across Y days`).
   - Adaptive modal Add/Edit slot sheet (`showUAdaptiveModal`).
   - Responsive card grid for published routine slots.

3. **`GenerateTimetableScreen` (`lib/features/admin/screens/generate_timetable_screen.dart`):**
   - **Stage 1 Card:** Unified input source and baseline readiness card (`Input Source: Database Rules & Room Pools`).
   - **Stage 2 4-Node Visual Timeline:** Horizontal node timeline tracking generation progress (`1. Queued` → `2. Ingesting & Validating` → `3. CP-SAT Session & Room Placement` → `4. Rendering Timetable`).
   - **Service Recovery Paradox Card:** Actionable error state on solver failure (`Engine connection failed or constraint unsatisfiable`), displaying diagnosis and one-tap retry.
   - Secondary history write warning handling.

4. **`UploadRoutineScreen` (`lib/features/admin/screens/upload_routine_screen.dart`):**
   - Top-lit file drop card with file format guidance and size validation.
   - **3-Step Post-Parse Publication Pipeline:**
     1. Storage Upload (`supabase/storage/routines`)
     2. Routine Slots Publication (`routines` table)
     3. Run History Recording (`routine_runs` table)
   - **Service Recovery Paradox Notice:** When routine publish succeeds but secondary history logging fails, displays a reassuring warning confirming public schedule activation while offering an audit log retry.

5. **`TimetableGridScreen` (`lib/features/admin/screens/timetable_grid_screen.dart`):**
   - Responsive filter bar with upfront option counts (`Showing X of Y classes`).
   - Actionable dual-action empty state with quick links to Generate and Upload.

---

## 3. Verification & Evidence

### 1. Static Analysis (`flutter analyze --no-pub`)
```
Analyzing universe_v1...
No issues found! (ran in 7.8s)
```
- **0 errors, 0 warnings, 0 lints.**

### 2. Phase 5 Widget & Unit Test Suite (`test/phase_5_admin_scheduling_and_operations_test.dart`)
```
00:00 +0: (setUpAll)
00:00 +0: Workstream A: AdminDashboardScreen Command Center & Readiness Renders 4-stage readiness checklist, labeled load breakdown, and dual-track launchpad across 390px, 1024px, and 1440px without overflow
00:01 +1: Workstream A: AdminDashboardScreen Command Center & Readiness Highlights Setup Required badge when rooms or routine slots are zero
00:02 +2: Workstream B: SchedulingWorkspaceScreen 1024px Fix, 390px Ergonomics & Signaling Fixes 1024px sidebar width collision: uses full-width table + adaptive modal inspector at 1024px inside AdminDesktopShell, and docks inspector at 1440px
00:03 +3: Workstream B: SchedulingWorkspaceScreen 1024px Fix, 390px Ergonomics & Signaling All 5 panes render with zero RenderFlex overflow at 390x844 and enforce Default-Gray signaling + Slide-to-Confirm publish control
00:04 +4: Workstream C: Routine Operations (Manage, Generate, Upload & Grid) AdminRoutineScreen uses USegmentedControl while preserving IndexedStack and upfront slot counts
00:04 +5: Workstream C: Routine Operations (Manage, Generate, Upload & Grid) GenerateTimetableScreen renders 4-Node Visual Timeline during polling and Service Recovery Card on error
00:05 +6: Workstream C: Routine Operations (Manage, Generate, Upload & Grid) UploadRoutineScreen renders 3-Step Post-Parse Pipeline and Service Recovery Paradox notice when secondary log warns
00:05 +7: Workstream C: Routine Operations (Manage, Generate, Upload & Grid) RoutineManagementScreen opens adaptive Add Entry modal and TimetableGridScreen renders cleanly at 390px and 1280px
00:05 +8: (tearDownAll)
00:05 +8: All tests passed!
```
- **8 out of 8 tests passed (100%).**

### 3. Full Regression Test Suite
Execution of all 9 test suites covering Phases 1 through 5:
```powershell
flutter test test/phase_5_admin_scheduling_and_operations_test.dart `
             test/phase_4_student_teacher_experiences_test.dart `
             test/shared_motion_test.dart `
             test/domain_card_motion_test.dart `
             test/phase_3_onboarding_and_auth_experience_test.dart `
             test/phase_2_design_system_and_components_test.dart `
             test/phase_1_navigation_and_shell_test.dart `
             test/scheduling_workspace_route_test.dart `
             test/scheduling_workspace_comprehensive_test.dart
```
**Result:**
```
00:24 +113: All tests passed!
```
- **113 out of 113 regression tests passed (100%).**

### 4. Git Whitespace Integrity (`git diff --check`)
```
Command exited with code 0 (no whitespace errors).
```

---

## 4. Architectural Invariants & Safety Summary

1. **Unconditional Live Mode Boundary:** `/admin/scheduling` remains strictly fail-closed when live distribution database contracts are unavailable (`isLiveWorkspaceOperational == false`). Simulated fixtures and CP-SAT solvers run strictly when `isPreviewMode == true`.
2. **State Retention:** Background CP-SAT solving and parsed Excel file states in `AdminRoutineScreen` are preserved via `IndexedStack`, ensuring navigation between tabs never loses active progress.
3. **Backend Contract Preservation:** All backend signatures, RPC calls (`publish_routine`), and parser logic in `RoutineAdminController`, `TimetableGenController`, `RoutineUploadController`, `TimetableEngineService`, and `RoutineWorkbookParser` remain 100% intact.
4. **Design Token Centralization:** All visual styling strictly references Obsidian Orbit tokens (`AppColors`, `AppSpacing`, `AppTextStyles`, `AppMotion`, and `AppTheme.dark`). Zero hardcoded colors or competing theme libraries.
5. **No Mobile Clipping:** Usable widths are driven by `LayoutBuilder`, guaranteeing 0px RenderFlex overflow across `390px` (mobile), `768px` (tablet), `1024px` (compact desktop with sidebar), `1280px` (desktop), and `1440px` (wide desktop).

---

## 5. Visual Artifacts & Screenshot Review Gallery

All 20 high-fidelity visual captures rasterized from the live Flutter widget tree across desktop, tablet/medium desktop, and mobile viewports are documented and viewable in:
- **Visual Review Gallery:** [`docs/screenshots/phase_5/VISUAL_REVIEW_GALLERY.md`](../screenshots/phase_5/VISUAL_REVIEW_GALLERY.md)
- **Screenshot Assets Directory:** `docs/screenshots/phase_5/`
  - Group 1: Administrative Command Center & Readiness (`01`–`04`)
  - Group 2: Scheduling Workbench Usable-Width & Distribution (`05`–`08`)
  - Group 3: Academic Policy Configuration & Preflight Readiness (`09`–`10`)
  - Group 4: CP-SAT Engine Controls & Safe Publication (`11`–`13`)
  - Group 5: Live Routine Operations & Resilience (`14`–`20`)



## 8 November 2026 - Deep visual and structural alignment

This follow-up implements the Product Owner's specified Phase 5 direction in the existing dirty working tree. No controller, service, RPC, auth, student/teacher screen, theme-token or hosted configuration changes were made in this follow-up.

| Files | Result |
|---|---|
| `admin_desktop_shell.dart` | Administrative breadcrumb, structured engine health pill, explicit orange button foreground and font inheritance; usable-width wrapping. |
| `timetable_grid_screen.dart` | Above-control filters, telemetry/reset, All Days pills, full-width desktop matrix, semantic cards, docked 340px inspector at >=1100px usable width, adaptive inspector below that, swipeable day agenda below 860px. Original rows and roomAliases parameters retained. |
| `admin_schedule_slot.dart` | Admin-only shared theory/lab/combined accents, cohort/faculty/room badges, alias tooltip and selection state. |
| `routine_management_screen.dart` | Cohort/day/search filters, published-slot count, 2/3-column desktop cards, hover/focus editing actions, existing adaptive editor. |
| `generate_timetable_screen.dart` | 58/42 operational composition, validated source hash/copy, bound profile, truthful resource readiness, timeline and existing validation/publication gate. |
| `upload_routine_screen.dart` | Parsed summary, typed grid preview before publishing, top-lit existing three-step pipeline. |
| `scheduling_review_pane.dart` | Same shared semantic cards, candidate inspector, unclipped cohort/faculty/room selector, retained prayer/lunch divider. |
| `distribution_filters_bar.dart`, `scheduling_configuration_pane.dart` | Above-control labels and wrapping/scrolling controls. |
| `scheduling_workspace_screen.dart`, `distribution_table_desktop.dart` | Short-height distribution scrolling and independently owned/disposed horizontal/vertical scroll controllers; existing preview gates retained. |
| Phase 5 targeted test and capture harness | Updated published-slot wording, real mobile modal and desktop inspector assertions, explicitly loaded capture component fonts, mobile/medium grid captures added. |

### Local verification

- `flutter analyze --no-pub`: 0 issues.
- `flutter test test/phase_5_admin_scheduling_and_operations_test.dart`: 8/8 passing, including 390px agenda/modal and 1280px docked inspector, 1024px workbench and all five compact panes.
- `flutter test --update-goldens test/phase5_visual_capture_test.dart`: regenerates the Phase 5 gallery (22 PNG files). The update flag is required because this harness uses Flutter golden comparisons.
- `git diff --check`: clean.
- Inspected actual fixture renders: desktop grid 1440, mobile grid 390, medium grid 1024, distribution 390, generator timeline 1440, and candidate review 1440. Grid filters and shell typography are readable; the desktop matrix occupies the remaining canvas beside its docked inspector. No rendering exceptions occurred in the final captures.

### Evidence and limitations

These are local Flutter widget/golden renders with injected fixtures and capture fonts, not a live browser, production authentication, database, solver or publication acceptance run. The captured engine status can be unavailable; fixture solver telemetry is illustrative. Missing source hashes and baseline counts remain explicitly unavailable until an existing validated source contract/profile supplies them. Review remains a fixture preview and live scheduling capability remains fail-closed. No WCAG audit, real device test, or hosted SQL verification is claimed.

On Windows, image preview mapping briefly blocked overwriting existing PNGs. Existing galleries were preserved in timestamped `universe_phase5_gallery_*` directories under the system temporary directory before regeneration; no source work was discarded.
