# UniVerse Redesign — Phase 4: Core Student and Teacher Daily Experiences

> **Status:** Complete & Verified  
> **Branch:** `feature/admin-web-extension`  
> **Scope:** `StudentDashboardScreen`, `TeacherDashboardScreen`, `RoutineScreen`, `WeeklyScheduleView`, `ManageClassesScreen`, and shared academic card primitives (`LiveClassCard`, `NextClassCard`, `MessageHeroCard`, `StatCard`, `ClassCard`).

---

## 1. Executive Summary

Phase 4 elevates UniVerse's daily consultation and teaching workflows across desktop web (`>= 768px`) and mobile (`< 768px`) while preserving every existing academic matching rule, time parser, pagination contract, and role navigation shell:

1. **Desktop/Tablet Web (`>= 768px`)** functions as a multi-column academic command center driven strictly by post-sidebar `LayoutBuilder` usable content width (`>= 860px` for dashboards and routines; `>= 900px` for the teacher class management split inspector).
2. **Mobile (`< 768px`)** functions as a focused, single-axis daily companion with matched-height `68px` telemetry strips, zero double-nested card clutter, swipeable day agenda navigation with haptic feedback, and top-lit single-handle contextual bottom sheets.
3. **Every Operational & Temporal State Is Explicitly Designed:**
   - **Live Class in Progress** (`LiveClassCard` with `3px` orange left accent bar, specular top highlight, real clock progress bar, cohort pill, and room badge).
   - **Up Next Today** (`NextClassCard` with `3px` cyan info accent bar, countdown timer, cohort pill, and room badge).
   - **Done for Today** (`MessageHeroCard` with emerald success accent summarizing completed vs. scheduled classes and previewing tomorrow's first class when available).
   - **No Scheduled Classes Today / Weekend** (`MessageHeroCard` with tomorrow's first class preview).
   - **Date-Scoped Class Cancellations & Two-Step Recovery** (`ManageClassesScreen` with unmistakable occurrence date banner, full success vs. amber partial-failure banner when `cancellations` succeeds but `notifications` fails, and 1-tap `"Send 'Class Restored' Notice to Cohort"` after undoing a cancellation).

---

## 2. Workstream Architecture & Desktop vs. Mobile Layout Specs

### Workstream A — Student Dashboard Overhaul
- **Files:**
  - [`lib/features/dashboard/screens/student_dashboard_screen.dart`](../../lib/features/dashboard/screens/student_dashboard_screen.dart)
  - [`lib/features/dashboard/controllers/student_dashboard_controller.dart`](../../lib/features/dashboard/controllers/student_dashboard_controller.dart)
  - [`lib/shared/widgets/live_class_card.dart`](../../lib/shared/widgets/live_class_card.dart)
  - [`lib/shared/widgets/next_class_card.dart`](../../lib/shared/widgets/next_class_card.dart)
  - [`lib/shared/widgets/message_hero_card.dart`](../../lib/shared/widgets/message_hero_card.dart)
  - [`lib/shared/widgets/stat_card.dart`](../../lib/shared/widgets/stat_card.dart)
- **Usable-Width Responsive Tiers (`LayoutBuilder`):**
  - **Expanded Desktop (`usableWidth >= 860px`):** Asymmetric **2-Column Academic Workspace** (`62%` Primary Left Column / `38%` Contextual Right Rail, `24px` gap):
    - **Left Column (`62%`):** Personalized cohort header strip (`Batch X · Section Y (+ B+C Joint)`), `UAnimatedSwap` Hero Card (`LiveClassCard`, `NextClassCard`, or `MessageHeroCard`), and **Today's Chronological Class Timeline** with visual time-axis connectors and `View Full Weekly Matrix ->` button.
    - **Right Contextual Rail (`38%`):** Compact **Today at a Glance** telemetry strip (`Scheduled`, `Completed`, `Cancelled` today using `AppTextStyles.statNumber` tabular numerals), **Recent Cohort Alerts** (`NotificationTile` preview with `See All`), and **Campus Quick Lookup** (`Room Availability`, `Find Teacher`).
  - **Medium (`600px <= usableWidth < 860px`):** Centered bounded workspace (`maxWidth: 760px`) with the 3-pill horizontal telemetry strip, Hero Card, Today's Timeline, and a 2-column bottom split for Recent Alerts and Quick Lookup.
  - **Compact Mobile (`usableWidth < 600px`):** Single-axis vertical flow (`AppSpacing.screenPaddingScrollable`) with a `68px` matched-height telemetry row, zero double-nested card containers around `ClassCard` or `NotificationTile`, and retained `AppDrawer` + `ExploreFabMenu` discovery.

### Workstream B — Teacher Dashboard Overhaul
- **Files:**
  - [`lib/features/teacher/screens/teacher_dashboard_screen.dart`](../../lib/features/teacher/screens/teacher_dashboard_screen.dart)
  - [`lib/features/teacher/controllers/teacher_dashboard_controller.dart`](../../lib/features/teacher/controllers/teacher_dashboard_controller.dart)
- **Teaching-First Hierarchy:**
  - Header strip highlights `Teacher Code: [CODE]` alongside department and today's date so faculty immediately see which acronym drives their schedule matching (`RoutineEntry.matchesTeacher`).
  - **Expanded Desktop (`usableWidth >= 860px`):** **2-Column Teaching Command Center** (`62%` Left / `38%` Right, `24px` gap):
    - **Left Column (`62%`):** Current/Next Teaching Session Hero + **Today's Teaching Timeline** where each `ClassCard` includes cohort/room pills (`Batch · Section`, `Room`) and an inline `Manage Occurrence` action pill linking directly to `/teacher/manage-classes`.
    - **Right Contextual Rail (`38%`):** **Teaching Load Summary** (`Classes Today`, `Active Cohorts`, `Cancellations Posted`), **Quick Class Tools & Campus Lookup** (`Manage Classes / Post Notice`, `Check Free Rooms`, `Faculty Directory`), and **Recent Departmental Alerts**.
  - **Compact Mobile (`usableWidth < 600px`):** Focused single-axis teaching agenda with thumb-friendly `Manage Occurrence` pills on each class card and retained `AppDrawer` + `ExploreFabMenu`.

### Workstream C — Published Routine Experience (Weekly Matrix & Swipeable Day Agenda)
- **Files:**
  - [`lib/features/routine/screens/routine_screen.dart`](../../lib/features/routine/screens/routine_screen.dart)
  - [`lib/features/routine/controllers/routine_controller.dart`](../../lib/features/routine/controllers/routine_controller.dart)
  - [`lib/shared/widgets/weekly_schedule_view.dart`](../../lib/shared/widgets/weekly_schedule_view.dart)
  - [`lib/shared/widgets/class_card.dart`](../../lib/shared/widgets/class_card.dart)
- **Connected Filter & View Context Bar:**
  - Displays the active routine lens (`Batch X · Section Y & Joint Sections` or `Faculty Schedule · [CODE]`), a live slot counter badge (`X classes this week · Y on [Day]`), and `USegmentedControl<RoutineView>` (`Weekly Matrix` ↔ `Day List`).
  - Defaults to `Weekly Matrix` when `usableWidth >= 860px` and `Day List` below `860px`, while preserving manual user overrides across the session.
- **High-Craft Academic Matrix (`WeeklyScheduleView.matrix`):**
  - Renders `AppColors.bgCard` cells with `1px` `AppColors.border` gridlines, a highlighted time-slot header row, and a highlighted **TODAY** row.
  - Each scheduled cell features a `3px` semantic left accent bar (Orange for Theory, Emerald for Lab/Sessional, Cyan for Joint/Co-taught, Red strikethrough badge if cancelled today), bold `subjectCode`, `Room` pill, and `Section`/`Teacher` tag.
  - Tapping any matrix cell opens `showRoutineEntryDetailOverlay` via `showUAdaptiveModal` (centered top-lit modal dialog on desktop `>= 768px`, single-handle floating sheet on mobile `< 768px`) displaying full academic metadata.
- **Swipeable Day Agenda & Break Divider (`Day List`):**
  - Supports horizontal swipe left/right across `Sun` → `Thu` synced with `DaySelector` and `AppMotion.selectionHaptic(context)`.
  - Automatically inserts `RoutineBreakDivider` (`Break / Free Window · [Duration] ([Start] – [End])`) whenever a gap `>= 40 minutes` exists between consecutive classes.

### Workstream D — Surgical Teacher Class Management & Two-Step Recovery
- **Files:**
  - [`lib/features/teacher/screens/manage_classes_screen.dart`](../../lib/features/teacher/screens/manage_classes_screen.dart)
  - [`lib/features/teacher/controllers/manage_classes_controller.dart`](../../lib/features/teacher/controllers/manage_classes_controller.dart)
  - [`lib/features/teacher/services/teacher_service.dart`](../../lib/features/teacher/services/teacher_service.dart)
- **Unmistakable Date-Occurrence Framing:**
  - Top banner explicitly states: `Managing Occurrences for: [Day, Date] · Recurring weekly schedule remains unchanged`.
- **Adaptive Desktop Master-Detail vs. Mobile Floating Sheet:**
  - **Expanded Desktop (`usableWidth >= 900px`):** **Master-Detail Split Workspace** (`55%` filterable class list with `All` / `Scheduled` / `Cancelled` chips; `45%` docked right **Class Action & Cohort Notice Inspector**).
  - **Mobile / Medium (`usableWidth < 900px`):** Tapping a class card opens the same inspector inside a top-lit floating bottom sheet via `showUAdaptiveModal`.
- **Truthful Two-Step Side-Effect Recovery:**
  - **Step 1 (`cancelClassWithOutcome`):** Distinguishes `CancellationOutcome.fullSuccess` from `CancellationOutcome.partialSuccessNotificationFailed` (when the `cancellations` row is saved but the `notifications` insert fails), surfacing an amber warning banner so the teacher can retry the cohort notice without re-cancelling.
  - **Step 2 (`undoCancel` + `sendClassRestoredNotice`):** Clarifies that restoring a class removes the date-scoped cancellation record without retracting previously sent push notifications, and offers a 1-tap `"Send 'Class Restored' Notice to Cohort"` follow-up action.

---

## 3. Inline `// PHASE 4:` Architectural & UX Comment Index

| File | `// PHASE 4:` Decision Summary |
|---|---|
| `lib/features/dashboard/controllers/student_dashboard_controller.dart` | Lazy service access, DI seams, joint-section discovery, and tomorrow first-class preview. |
| `lib/features/dashboard/screens/student_dashboard_screen.dart` | `LayoutBuilder` usable-width tiers (`>=860px` 62/38 split, `600..859px` medium, `<600px` compact), `UAnimatedSwap` hero states, and `68px` telemetry strip. |
| `lib/features/teacher/controllers/teacher_dashboard_controller.dart` | Lazy service access, DI seams, `Teacher Code: [CODE]` badge, and cancellation telemetry. |
| `lib/features/teacher/screens/teacher_dashboard_screen.dart` | Teaching-first command center (`62/38` desktop split) and inline `Manage Occurrence` pills. |
| `lib/features/routine/controllers/routine_controller.dart` | Active lens label, cancellation key lookup, and `stepDay` swipe navigation helper. |
| `lib/features/routine/screens/routine_screen.dart` | Connected Filter & View Context Bar, `>=860px` Weekly Matrix default, swipeable day agenda, and `>=40m` break dividers. |
| `lib/shared/widgets/weekly_schedule_view.dart` | `WeeklyScheduleView.matrix` 2D grid, `3px` semantic cell accents, `showRoutineEntryDetailOverlay`, and `RoutineBreakDivider`. |
| `lib/features/teacher/services/teacher_service.dart` | Lazy Supabase access and `CancellationOutcome` two-step result classification. |
| `lib/features/teacher/controllers/manage_classes_controller.dart` | Master-detail selection state, status filter chips, and two-step cancellation/restoration handlers. |
| `lib/features/teacher/screens/manage_classes_screen.dart` | Occurrence Date Banner, `>=900px` 55/45 split inspector vs. `<900px` floating sheet, and partial-failure/undo recovery UI. |
| `lib/shared/widgets/live_class_card.dart` | `3px` orange left accent bar, cohort pill, and styled room badge. |
| `lib/shared/widgets/next_class_card.dart` | `3px` cyan left accent bar, deterministic `clock` seam, cohort pill, and styled room badge. |
| `lib/shared/widgets/message_hero_card.dart` | Top-lit `UCard`, `3px` semantic accent bar, badge, and tomorrow preview `secondaryText`. |
| `lib/shared/widgets/stat_card.dart` | `compact` `68px` matched-height telemetry pill mode. |
| `lib/shared/widgets/class_card.dart` | `3px` semantic left accent bar, `subjectCode`, `trailingAction`, and master-detail `isSelected` highlight. |

---

## 4. Phase 4 Unslop, 7-Day Institutional Alignment & Phase C Choreography Overhaul

Following the initial Phase 4 baseline, a brutal anti-slop, institutional domain correction (7-day week + Friday Jummah prayer hard constraint), and Phase C Role-Adaptive Profile Studio pass were integrated:

### 1. 7-Day Institutional Week (`Sun–Sat`) & Friday Jummah Prayer (`friday_no_p4`) Sync
- **7-Day DaySelector & Stepper:** `DaySelector` and `RoutineController` upgraded to full 7-day circular wrapping on drag & step (`(currentIndex + delta + 7) % 7`).
- **Friday Jummah Prayer Window:** `WeeklyScheduleView` day list injects a dedicated `Jummah Prayer Break (12:50 PM – 02:05 PM) · No classes (friday_no_p4)` divider between pre- and post-Jummah sessions on Friday. The 2D matrix slot checker marks Period 4 Friday as a hard non-schedulable constraint.
- **7-Day Load Distribution:** `StudentDashboardController` and `TeacherDashboardController` compute `classesCountPerDay` across all 7 days (`Sun, Mon, Tue, Wed, Thu, Fri, Sat`).

### 2. Phase 4 Brutal Unslop Standard
- **`ClassCard` Left Stripe Unslop (`Vibe-Coded #8`):** Removed permanent 3px left stripe from unselected cards. Accent bar is rendered **strictly** when `isSelected == true`, `isCancelled == true`, or `status == ClassStatus.live`.
- **Delete Filler Badges (`Unslop #1`):** Added `hideDefaultCohortPill: true` to student views to omit redundant cohort pills (`Batch 58 · Sec B`) on every row while preserving `B+C Joint` and `Lab` pills.
- **7-Day Weekly Load Mini-Bar (`UWeeklyLoadBarCard`):** Replaced generic 3-box KPI counters on both student and teacher dashboards with an interactive 7-column load distribution card highlighting today in orange.
- **Eliminate Duplicate Navigation Links (`5 SaaS Mistakes`):** Removed `Quick Class Tools & Campus Lookup` from `TeacherDashboardScreen` which redundantly duplicated the primary sidebar navigation.
- **Compact Interactive Date Stepper:** Replaced verbose top yellow banner in `ManageClassesScreen` with `< [Day, Date] >` stepper and `TODAY` pill. Reassurance microcopy moved to inspector sheet footer above action buttons.

### 3. Searchable `UCombobox<T>` & Phase B Distribution Bridge
- Created `UCombobox<T>` with concentric radii (outer container 12px, item 8px), 180ms entrance / 140ms exit animation, type-ahead real-time search, keyboard navigation (`Up`/`Down`, `Enter`, `Esc`), and zero-match fallback.
- Integrated into `ManageCoursesScreen` and `ManageBatchesScreen`.
- Connected `SchedulingWorkspaceController.loadSynthesizedCatalogDistribution()` and `DistributionFiltersBar` (`Sync UI Catalog` button) to preview rows directly from `TimetableConfigService.synthesizeDistributionFromCatalog()`.

### 4. Phase C: Role-Adaptive Interactive Profile Studio & Precision Choreography
- Redesigned `ProfileScreen` into a responsive 2-Column Command Studio on desktop (42% Identity & Security Rail / 58% Role Operational Studio) and single-axis on mobile.
- **Student Studio:** Cohort information, joint sections, 7-day academic week status, and direct routine navigation.
- **Teacher Studio:** Teacher code badge, R6/R7 load policy summary (4–5 teaching days + 2–3 off-days), and interactive R8 preferred teaching days selector (`Sun..Sat`).
- **Admin Studio:** CP-SAT engine status, live catalog readiness counts for Courses/Batches/Faculty/Rooms, and command shortcuts to 2D Grid and Timetable Settings.
- **Choreography:** `UAnimatedSwap` set to `reverseDuration` = 80% of `duration`. Daily class timelines staggered with `UStaggeredListRow` (30ms entrance stagger per row, capped at 6 rows) with reduced-motion support.

---

## 5. Verification Summary

- **Static Analysis:** `flutter analyze --no-pub` → **0 issues** across entire workspace.
- **Phase 4 & Phase C Verification Suites:**
  - `test/phase_c_and_phase4_unslop_7day_test.dart` → **13/13 passing tests**.
  - `test/phase_4_student_teacher_experiences_test.dart` → **6/6 passing tests**.
  - `test/phase_b_coexistence_grid_settings_and_7day_test.dart` → **10/10 passing tests**.
  - `test/phase_a_admin_catalog_crud_test.dart` → **23/23 passing tests**.
  - `test/timetable_settings_test.dart` → **22/22 passing tests**.
  - `test/phase_1_navigation_and_shell_test.dart` → **26/26 passing tests**.
  - `test/phase_5_admin_scheduling_and_operations_test.dart` → **11/11 passing tests**.
  - `test/phase_6_r1_r16_and_supporting_modules_test.dart` → **6/6 passing tests**.
  - `test/scheduling_workspace_comprehensive_test.dart` → **10/10 passing tests**.
- **Total Multi-Phase Regression:** **127/127 passing tests**.
- **Diff Hygiene:** `git diff --check` → **0 whitespace issues**.
