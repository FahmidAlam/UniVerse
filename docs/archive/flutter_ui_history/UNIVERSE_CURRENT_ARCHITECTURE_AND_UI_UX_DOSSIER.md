# UniVerse — Current Architecture and UI/UX Dossier

Investigation date: **8 November 2026 (Asia/Dhaka)**. Workspace: `D:\flutter projects\universe_v1`. This is an exhaustive, evidence-based working-tree and architectural investigation reflecting the complete state of the project through Phases 0, 1, 2a, 2b, 3, 3.5, 4, 5, 6 and the Phase 7 closure work (updated 9 November 2026). It is not a production acceptance certificate or an authorization for hosted writes.

---

## 1. Executive Summary

UniVerse is a production-grade Flutter campus companion application for students, faculty, and university administrators at Leading University, Sylhet, initially focused on Computer Science and Engineering (CSE). Its working core connects Supabase authentication, user profiles, published timetables, academic course resources, campus announcements, date-scoped class cancellations, and push notifications. A companion Python FastAPI service ingests Course Distribution workbooks, solves timetable placements using Google OR-Tools Constraint Programming SAT (CP-SAT), allocates physical rooms, enforces departmental policies, and renders printable university Excel schedules. The frontend strictly adheres to a feature-first architecture (`lib/features/`, `lib/core/`, `lib/shared/`) powered by `ChangeNotifier`/`SafeChangeNotifier`, service abstractions, and `GoRouter`; alternative web frameworks (such as React, Next.js, or HTML wrappers) are neither needed nor authorized.

### Multi-Phase Evolution & Current Status
1. **Phases 0–3.5 (Obsidian Orbit Visual Identity & Adaptive Shells):** Completed and verified. Establishes the 5-tier Obsidian Orbit dark theme (`AppColors`, `AppTheme.dark`), 4px optical grid (`AppSpacing`), tabular typography (`AppTextStyles`), centralized motion curves (`AppMotion`), adaptive navigation shells (`RoleDesktopShell`, `AuthResponsiveShell`), shared primitives (`UButton`, `UCard`, `UTextField`, `UChip`, `USegmentedControl`, `UAnimatedSwap`, `UPressableScale`, `UAdaptiveOverlay`), and a 76-screenshot visual capture gallery in [`docs/screenshots/phase_3/VISUAL_REVIEW_GALLERY.md`](docs/screenshots/phase_3/VISUAL_REVIEW_GALLERY.md).
2. **Phase 4 (Core Student & Teacher Daily Experiences):** Completed and verified. Delivers:
   - **Student Command Center (`StudentDashboardScreen`):** Post-sidebar `LayoutBuilder` usable-width tiers ($\ge 860\text{px}$ 62/38 desktop split; $600\dots 859\text{px}$ medium; $< 600\text{px}$ compact single-axis flow); temporal Hero Card state machine via `UAnimatedSwap` (`LiveClassCard` with real-time clock bar, `NextClassCard` with countdown timer, `MessageHeroCard` with done/weekend summary and tomorrow's first lecture preview); 68px matched-height telemetry strip; and joint-section awareness (`Batch X · Section Y (+ B+C Joint)`).
   - **Teacher Command Center (`TeacherDashboardScreen`):** Teaching-first hierarchy highlighting `Teacher Code: [CODE]` badge driving schedule matching (`RoutineEntry.matchesTeacher`); 62/38 desktop split with teaching load summary; and inline `Manage Occurrence` action pills linking directly to `/teacher/manage-classes`.
   - **Routine Matrix & Swipeable Day Agenda (`RoutineScreen` & `WeeklyScheduleView`):** Connected Filter & View Context Bar (`USegmentedControl`); $\ge 860\text{px}$ Weekly Matrix default with 3px semantic cell accents (Orange for Theory, Emerald for Lab/Sessional, Cyan for Joint/Co-taught, Red strikethrough for Cancelled) and centered modal detail overlay on desktop ($\ge 768\text{px}$) / floating sheet on mobile ($< 768\text{px}$); swipeable Day Agenda with haptic feedback; and automatic `RoutineBreakDivider` for gaps $\ge 40\text{ minutes}$.
   - **Teacher Class Management (`ManageClassesScreen` & `TeacherService`):** Unmistakable occurrence date banner: `Managing Occurrences for: [Day, Date] · Recurring weekly schedule remains unchanged`; $\ge 900\text{px}$ 55/45 master-detail split vs floating sheet; truthful two-step side-effect recovery distinguishing `CancellationOutcome.fullSuccess` from `CancellationOutcome.partialSuccessNotificationFailed` (amber warning) and offering 1-tap `"Send 'Class Restored' Notice to Cohort"` after undo.
   - **Verification:** 6/6 tests passing in `test/phase_4_student_teacher_experiences_test.dart` at both $390\times 844$ and $1440\times 900$ viewports with zero layout overflows.
3. **Phase 5 (Administrative Scheduling Experience & Live Routine Operations):** Completed and verified. Delivers:
   - **Six Design Research Principles:** (1) "Walmart Receipt" edge alignment & dissolved inner cards; (2) "Checkbox Off = Gray" signaling discipline (calm slate-gray for verified baselines); (3) Upfront option counts & invisible UI on hover/focus; (4) Data-driven visual shapes (departmental load breakdown bar chart, 4-node visual solver timeline); (5) Mural-style readiness (4-stage lifecycle checklist) & Service Recovery Paradox; (6) True usable-width ergonomics (`LayoutBuilder` post-sidebar width) & Slide-to-Confirm publication gate (`_SlideToConfirmPublish`).
   - **Admin Command Center (`AdminDashboardScreen`):** 4-stage readiness checklist (`01 Room Pools`, `02 Faculty`, `03 Course Rules`, `04 Active Routine`), horizontal load breakdown, dual-track launchpad (Live Pipeline vs. Design Preview), and single-header enforcement inside `AdminDesktopShell`.
   - **Live Routine Operations (`AdminRoutineScreen`):** Accessible `USegmentedControl` with `IndexedStack` state preservation; `RoutineManagementScreen` with upfront slot counts and adaptive modal editor; `GenerateTimetableScreen` with 4-node visual timeline and Service Recovery Card; `UploadRoutineScreen` with 3-step post-parse publication pipeline; `TimetableGridScreen` with above-control filters, docked 340px inspector at $\ge 1100\text{px}$, swipeable day agenda below $860\text{px}$, and `AdminScheduleSlot`.
   - **Scheduling Workspace (`SchedulingWorkspaceScreen`):** Full 5-stage preview workbench (Distribution, Configuration, Readiness, Generate, Review) with 1024px collision fix, 390px mobile card ergonomics, and fail-closed live backend boundary (`isLiveWorkspaceOperational == false`).
   - **Visual Review Gallery:** 22 high-fidelity golden captures in `docs/screenshots/phase_5/VISUAL_REVIEW_GALLERY.md`.
4. **Phase 6 (R1–R16 Committee Scheduling Rules UI/UX Integration & Supporting Modules Overhaul):** Completed and verified. Delivers:
   - **Workstream A — R1–R16 Policy Architecture:** Structured 5-Category policy architecture (`Term Grid & Section Calendar`, `Faculty Workload & Compactness`, `Shared Laboratories & Classroom Pools`, `Credit-Based Distribution`, and `UI Governance & Impact Warnings`) inside `SchedulingConfigurationPane` and `TimetableSettingsScreen`. Prominent `USegmentedControl<int>` for Rule R15 (switching 6-Slot vs. 7-Slot daily grids with dynamic visual period-strip preview). Comprehensive preflight readiness checklist linking R4/R5, R7, R10/R11, and R14/R15.
   - **Workstream B — Admin Baseline CRUD Editors (R4–R14):** 55/45 Master-Detail Split on desktop ($\ge 900\text{px}$) and adaptive modal sheet on mobile ($< 900\text{px}$) across `ManageFacultyScreen` (R4 external blocks, R5 guest windows, R6 workload bands, R7 off-day violation badges, R8 preferences, R9 SUST adjunct mode with day-by-slot interactive matrix), `ManageRoomsScreen` (R10 ECL & R11 Physics declared lab availability matrix, R14 dynamic semester pool switch, Physics exclusive course chips), and `ManageCourseEligibilityScreen` (R12/R13 automatic credit-based rule badges and qualified faculty instructor assignments).
   - **Workstream C — Supporting Campus & Admin Modules:** 55/45 Master-Detail Splits with live URL query synchronization (`?room=`, `?teacher=`) and truthful schedule-derived occupancy copy in `RoomsScreen` and `FindTeacherScreen`. Top-lit `UCard` surfaces with dissolved 1px divider rows, manual refresh action, and last-checked timestamp in `NotificationsScreen`. Completely overflow-free responsive layouts across `ResourcesScreen`, `ProfileScreen`, `CampusBroadcastScreen`, and `ManageUsersScreen`. Single-Header Rule strictly enforced across all screens via `DesktopShellScope.isDesktopOf(context)`.
5. **Phase 7 (Final Secondary Admin UI/UX Closure):** Four remaining admin routes now use bounded layouts and Single-Header behavior, linked sibling-route tabs, top-lit surfaces, filter counts and adaptive deletion confirmations. Faculty and room matrices support configured/default 6-slot and 7-slot previews. Dashboard drawer attachments and the shell-owned Explore FAB are retired. See `PHASE_7_FINAL_UI_UX_CLOSURE_REPORT.md`.
6. **Current Working-Tree Condition (9 November 2026):**
   - **Static Analysis:** `flutter analyze --no-pub` reports **0 issues**.
   - **Focused Tests:** Phase 4-7 tests pass **40/40**, including **16/16 Phase 7 tests**. The earlier 50-test Phase 4-6 selection was not the entire repository suite.
   - **Full Repository Tests:** The final full repository run has **325 passed, 1 skipped, 0 failed**. Section 27 records the evidence and remaining device/hosted acceptance limits.
   - **Backend Data Boundaries:** Fail-closed live workspace boundary (`isLiveWorkspaceOperational == false` on `/admin/scheduling`). Safe DI seams across all controllers enabling offline test rendering. No hosted database mutations.

---

## 2. Project Identity and Current Strategic Direction

**VERIFIED:** `pubspec.yaml` identifies the package as `universe`, version `1.0.0+1`, with publication disabled. `AppConstants` defines a dedicated campus companion for Leading University, Sylhet, centered on Computer Science and Engineering (CSE). The application serves three distinct user roles: Student, Teacher, and Administrator. This is a single, unified Flutter application and companion scheduling microservice, not a fragmented set of disconnected web apps.

The strategic direction emphasizes:
1. **Obsidian Orbit Visual Identity:** Dark aesthetic (`#0A0B0E` background, `#12141A` cards, `#181B22` elevated surfaces) with purposeful orange accent (`#FF6B00` brand primary) and semantic status colors.
2. **True Cross-Platform Ergonomics:** Desktop-first web command centers (using post-sidebar `LayoutBuilder` usable content width) paired with first-class, swipeable, single-axis mobile companions.
3. **Truthful Academic Hierarchy:** Clear communication of real timetable states, schedule provenance, time-axis connectors, and honest error recovery.
4. **Strict Architectural Integrity:** Retention of Flutter, Supabase, and Google OR-Tools CP-SAT without unapproved state migrations, rewrites, or hosted database modifications.

---

## 3. Investigation Scope and Evidence Method

### 3.1 Evidence Vocabulary

| Label | Definition |
|---|---|
| **VERIFIED** | A concrete fact directly inspected in source/configuration, existing image evidence, or read-only live metadata. |
| **CODE-DERIVED** | Behavior inferred by tracing executable source code without running an interactive live instance. |
| **REPORTED** | A result documented by prior phase reports, verified within its recorded scope. |
| **PLANNED** | A roadmap requirement whose complete operational path is not yet built. |
| **PARTIAL** | Implementation exists, but end-to-end integration remains incomplete. |
| **UNKNOWN** | Available evidence does not establish the fact. |
| **DEPRECATED** | An explicitly retired artifact or behavior. |

### 3.2 Work Performed
Inspected route definitions, adaptive scaffolds, screen implementations, controllers, services, core models, theme tokens, shared widgets, Python engine solver constraints and renderers, Supabase migrations, edge functions, test suites, and visual review galleries. Verified live metadata across both Supabase projects (`yxqyrjyzxitrgkhgauli` and `oqwvxplteqtlrhktsplj`). Evaluated 76 visual captures from Phase 3.5 and 22 visual captures from Phase 5 across $1440\text{px}$, $1280\text{px}$, $1024\text{px}$, and $390\text{px}$ viewports. Ran static analysis and targeted test suites to assess code health.

---

## 4. Complete Repository Structure

```text
universe_v1/
├── AGENTS.md                         Shared Codex/Antigravity rules, approval gates, and UI/UX skill routing
├── CLAUDE.md                         Claude Code operating rules and architecture summary
├── GLOBAL_FLUTTER_DART_SKILLS_REPORT.md Global skill ecosystem audit and Antigravity discovery documentation
├── PHASE_2B_UI_UX_IMPLEMENTATION_REPORT.md Phase 2b Scheduling Workspace foundation report
├── PROJECT_STRUCTURE.md              Complete repository file inventory and subsystem directory guide
├── README.md                         Project overview, tech stack, and setup instructions
├── UI_UX_SKILLS_INTEGRATION_REPORT.md UI/UX skills integration, workflow lifecycle, and cross-phase execution report
├── UNIVERSE_CURRENT_ARCHITECTURE_AND_UI_UX_DOSSIER.md Authoritative 29-section architecture and UI/UX dossier (this document)
├── .agents/skills/                   Seven project skills: implementation plus six UI/UX skills
│   ├── universe-implementation/      Implementation coordination, 5 specialist references, mcap_config.json
│   ├── universe-ux-principles/       Product-level UX reasoning, academic task clarity, honest progress
│   ├── universe-visual-design-system/ Obsidian Orbit visual tokens, surface hierarchy, theme governance
│   ├── flutter-web-responsive-ui/    Desktop-first layouts, post-sidebar LayoutBuilder, adaptive breakpoints
│   ├── flutter-interaction-motion/   Interaction states, AppMotion tokens, micro-interactions, reduced motion
│   ├── accessibility-performance/    WCAG AA/AAA contrast, keyboard traversal, rebuild minimization
│   └── visual-ui-qa/                 Screenshot comparison protocol, multi-viewport golden inspection
├── lib/
│   ├── main.dart                     Initialization, callbacks, app root and global sign-out overlay
│   ├── firebase_options.dart         Generated Firebase platform configuration
│   ├── core/
│   │   ├── constants/                Environment lookup names, role/table constants, enums
│   │   ├── models/                   Profiles, routines, resources, alerts, academic/config contracts
│   │   ├── platform/                 Conditional web/native downloads and callback URL cleanup
│   │   ├── router/                   AppRouter, RouteNames, AppShell
│   │   ├── services/push_service.dart Android FCM/local notification lifecycle
│   │   ├── theme/                    AppColors, AppSpacing, AppTextStyles, AppTheme, AppMotion
│   │   └── utils/                    Clocks, date logic, room identity, validation, safe notifier
│   ├── features/
│   │   ├── auth/                     Login, registration, verification, recovery, and showcase engine
│   │   ├── dashboard/                Student command center (62/38 desktop split, hero cards, telemetry)
│   │   ├── teacher/                  Teaching command center, load summary, and surgical class management
│   │   ├── routine/                  Routine viewer (weekly matrix, swipeable day agenda, break dividers)
│   │   ├── resources/                Semester folders and learning resource retrieval
│   │   ├── notifications/            Audience filtering, reads, local dismissal, and realtime listener
│   │   ├── profile/                  Profile display, academic metadata, and avatar selection
│   │   ├── rooms/                    Schedule-derived occupancy and room detail viewer
│   │   ├── find_teacher/             Schedule-derived teacher availability and faculty directory
│   │   └── admin/
│   │       ├── screens/              Admin command center, routine operations, grid, and scheduling workspace
│   │       ├── controllers/          Admin state machines, generation/upload pipelines, and readiness metrics
│   │       ├── services/             Supabase admin/config, workbook parsing, engine HTTP
│   │       ├── widgets/              AdminDesktopShell, AdminScheduleSlot, and responsive card grids
│   │       └── scheduling/           Scheduling workspace models, controller, fixtures, and 5 pane families
│   └── shared/
│       ├── widgets/                  Obsidian Orbit U* controls, academic cards, shells, and weekly schedule
│       └── utils/                    Navigation fallback and icon compatibility
├── engine/
│   ├── main.py                       FastAPI routes, in-memory jobs and worker threads
│   ├── distribution.py               Immutable workbook + correction overlay/replay contract
│   ├── ingest.py                     Distribution header/cell parser and session derivation
│   ├── solver.py                     CP-SAT placement, greedy room allocation, validation
│   ├── render.py                     Excel workbook output and hygiene
│   ├── domain.py                     Canonical academic and normalization dataclasses
│   ├── legacy_mapping.py             Reviewed mapping/quarantine helpers
│   ├── room_policy.py                Physical room aliases and departmental room rules
│   ├── config.json                   Engine baseline parameters
│   └── tests/                        Contract, solver, ingestion, room, and rendering tests
├── supabase/
│   ├── migrations/                   001–016 with no 010; academic catalog and course distribution contracts
│   ├── reconciliation/               Reconstructed baseline and verification SQL
│   ├── tests/                        pgTAP and reconciliation checks
│   └── functions/                    invite-admin and send-push edge functions
├── test/                             Automated Flutter unit, widget, layout, motion, and visual capture suites
│   ├── phase_4_student_teacher_experiences_test.dart Passing Phase 4 widget & responsive test suite (6/6)
│   ├── phase_5_admin_scheduling_and_operations_test.dart Phase 5 admin command center and routine test suite
│   ├── phase5_visual_capture_test.dart Phase 5 visual capture suite rendering 22 inspection goldens
│   ├── phase35_visual_capture_test.dart Phase 3.5 visual capture suite rendering 76 inspection goldens
│   └── failures/                     Visual golden diff masks and test failure comparisons
├── docs/
│   ├── implementation/              Master plan, phase specs (Phase 0, 1, 2a, 2b, 3, 4, 5)
│   ├── screenshots/phase_3/         76 golden screenshots and VISUAL_REVIEW_GALLERY.md
│   ├── screenshots/phase_5/         22 golden screenshots and VISUAL_REVIEW_GALLERY.md
│   └── timetable-audit-2026-10-20/   Committee decisions and historical audits
└── pubspec.yaml, analysis_options.yaml, render.yaml
```

---

## 5. High-Level System Architecture

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                                  UNIVERSE FRONTEND                                     │
│  Flutter 3.x (Web Desktop-First · Android Mobile Companion · Tablet Adaptive)         │
│  • Features: Auth, Dashboard, Teacher, Routine, Rooms, FindTeacher, Admin, Scheduling  │
│  • State: ChangeNotifier / SafeChangeNotifier · Router: GoRouter with Role Guards      │
│  • Theme: Obsidian Orbit (AppColors, AppSpacing, AppTextStyles, AppMotion, AppTheme)  │
└───────────────────────────┬────────────────────────────────┬───────────────────────────┘
                            │                                │
                 HTTPS REST │ Realtime WSS                   │ HTTP JSON (Solve & Health)
                            ▼                                ▼
┌───────────────────────────────────────────┐    ┌───────────────────────────────────────┐
│             SUPABASE BACKEND              │    │             PYTHON ENGINE             │
│  • Auth: GoTrue (Google OAuth / Email)    │    │  FastAPI Microservice (Render hosted) │
│  • Database: Postgres 15 with RLS         │    │  • Course Distribution Ingestion     │
│  • Storage: Public Buckets (Routines,     │    │  • Google OR-Tools CP-SAT Solver      │
│    Resources, Avatars)                    │    │  • Physical Room Allocation Rules     │
│  • Edge Functions: Deno TypeScript        │    │  • Academic Validation Diagnostics    │
│    (invite-admin, send-push FCM)          │    │  • OpenPyXL Routine Workbook Renderer │
└───────────────────────────────────────────┘    └───────────────────────────────────────┘
```

---

## 6. Frontend Architecture

### 6.1 State Management & Architecture Pattern
- **Feature-First Organization:** Every domain feature resides in `lib/features/<feature>/` containing dedicated `screens/`, `controllers/`, `services/`, `models/`, and `widgets/`.
- **`SafeChangeNotifier` Foundation:** Subclass of `ChangeNotifier` guarding against `notifyListeners()` invocation after disposal or during widget tree build phases.
- **Dependency Injection Seams:** Controllers expose constructor seams (`service`, `countsLoader`, `initialCounts`, `clock`) allowing deterministic unit and widget testing without live network connections.

### 6.2 Responsive Workspace Strategy: Usable-Width Ergonomics
UniVerse rejects brittle screen-level `MediaQuery.sizeOf(context).width` checks that cause sidebar collision. Instead, all responsive screens utilize **post-sidebar `LayoutBuilder` usable content width** (`constraints.maxWidth`):
- **Expanded Desktop ($\ge 1020\text{px}$ or $\ge 860\text{px}$):** Multi-column academic command centers (62/38 student and teacher splits; 55/45 master-detail class management; 12-column distribution table with docked inspector).
- **Medium Desktop / Tablet ($680\text{px} \le \text{width} < 1020\text{px}$):** Full-width tables and grids with modal dialog inspectors (`showUAdaptiveModal`).
- **Compact Mobile ($< 680\text{px}$ or $< 600\text{px}$):** Touch-first vertical agendas, 68px matched-height telemetry strips, mobile card lists (`DistributionListMobile`), and single-handle floating bottom sheets with zero horizontal clipping at $390\text{px}$.

### 6.3 Motion System & Accessibility
- **`AppMotion` Token Layer:** Standardized durations (`micro: 120ms`, `fast: 200ms`, `medium: 300ms`, `slow: 450ms`) and curves (`magnetic: Cubic(0.2, 0.0, 0.0, 1.0)`, `snappy: Cubic(0.05, 0.7, 0.1, 1.0)`).
- **Reduced-Motion Policy:** `UAnimatedSwap`, `UPressableScale`, and `LiveClassCard` evaluate `MediaQuery.of(context).disableAnimations` and immediately render rest states without transitions.
- **Keyboard Navigation & Traversal:** `/` desktop search focus shortcut (`USearchFilterBar`), `[Esc]` modal overlay dismissal (`showUAdaptiveModal`), and sliding segmented control arrow-key traversal (`USegmentedControl`).

---

## 7. Backend Architecture

### 7.1 Database Structure & RLS
- **Public Tables (Production `yxqyrjyzxitrgkhgauli`):** 18 public tables, all reporting Row Level Security (RLS) enabled: `profiles`, `routines`, `routine_versions`, `routine_runs`, `cancellations`, `notifications`, `notification_reads`, `rooms`, `faculty`, `faculty_course_eligibility`, `timetable_configs`, `timetable_schedule_configs`, `device_tokens`, `resources`, `whitelist`, `batches`, `sections`, `departments`.
- **Additive Contract Tables (Secondary `oqwvxplteqtlrhktsplj`):** Phase 2a tables including `course_distribution_workbooks`, `course_distribution_revisions`, `course_distribution_cell_corrections`, `course_distribution_audit_logs`, `canonical_courses`, `canonical_departments`, `canonical_terms`.
- **Atomic Routines Replacement (`publish_routine`):** Stored procedure validating admin role and replacing all routine rows atomically within a single transaction.

### 7.2 Storage Buckets & Policies
- Storage buckets: `routines`, `resources`, `avatars`. Objects are publicly readable; uploads, replacements, and deletions require authenticated user sessions.

### 7.3 Edge Functions
- `invite-admin`: Admin-authorized endpoint sending invitation emails and pre-registering whitelist records.
- `send-push`: Webhook-driven endpoint triggering Google Firebase Cloud Messaging (FCM) HTTP v1 API for urgent campus announcements and date-scoped class cancellations.

---

## 8. Internal Engines and Business Logic

### 8.1 Python Timetable Solver (`engine/solver.py`)
- **Engine Framework:** Google OR-Tools CP-SAT (Constraint Programming - Satisfiability).
- **Hard Constraints:**
  - Zero teacher overlapping sessions.
  - Zero room double-booking.
  - Zero student section simultaneous session collisions.
  - Mandatory contiguous multi-hour allocations for laboratory sessions (`Lab / Sessional`).
  - Strict university room restrictions (e.g. EEE laboratory rooms reserved exclusively for EEE courses).
- **Soft Objectives & Penalty Minimization:**
  - Faculty compactness (minimizing gaps between teaching slots).
  - Student cohort gap minimization.
  - Non-adjacent day spreading for 3-credit theory courses.
  - Avoidance of late-afternoon period assignments for core curriculum offerings.
- **Room Allocation:** Greedy placement matching section student counts against physical room seat capacities.
- **Renderer (`engine/render.py`):** OpenPyXL template renderer producing styled university timetable spreadsheets with Sunday legend and room directory.

---

## 9. Frontend-to-Backend Integration Map

| User Action / Workflow | Client Component & Controller | Backend RPC / HTTP Endpoint | Security & Fallback Rules |
|---|---|---|---|
| **Google OAuth Sign-In** | `LoginScreen` $\to$ `AuthController` | Supabase GoTrue OAuth (`provider: google`) | Browser PKCE exchange; URL token cleanup via `AuthCallbackCleanup`. |
| **Email Sign-In / Sign-Up** | `EmailLoginScreen` / `EmailSignupScreen` | Supabase GoTrue Auth | Whitelist check for faculty/admin; password strength validation. |
| **Student Routine Consultation** | `StudentDashboardScreen` / `RoutineScreen` | `RoutineService.fetchActiveRoutine` | Filtered by student `batch` and `section`; joint-section discovery. |
| **Faculty Schedule Consultation** | `TeacherDashboardScreen` / `RoutineScreen` | `RoutineService.fetchActiveRoutine` | Filtered by `RoutineEntry.matchesTeacher(code)`. |
| **Date-Scoped Class Cancellation** | `ManageClassesScreen` $\to$ `TeacherService` | `cancellations` insert + `send-push` | 2-step recovery: amber warning on notification failure; 1-tap restored notice. |
| **Administrative Command Center** | `AdminDashboardScreen` $\to$ `AdminDashboardController` | `AdminService.fetchSystemCounts` | 4-stage readiness checklist; DI seams for offline testing. |
| **Live Solver Execution** | `GenerateTimetableScreen` $\to$ `TimetableGenController` | FastAPI `POST /api/timetable/generate` | 4-node visual timeline; bounded polling; Service Recovery Card. |
| **Excel Routine Import** | `UploadRoutineScreen` $\to$ `RoutineUploadController` | Storage upload + `publish_routine` RPC | 3-step post-parse pipeline; secondary log warning recovery. |
| **Live Timetable Grid Inspection** | `TimetableGridScreen` $\to$ `RoutineAdminController` | `routines` table select | Docked 340px inspector at $\ge 1100\text{px}$; swipeable day agenda below $860\text{px}$. |
| **Scheduling Preview Workbench** | `SchedulingWorkspaceScreen` $\to$ `SchedulingWorkspaceController` | In-memory fixtures & simulation | Strictly fail-closed live boundary (`isLiveWorkspaceOperational == false`). |

---

## 10. Supabase Architecture

### 10.1 Database Schema Inventory
- `profiles`: User accounts, roles (`student`, `teacher`, `admin`), student batch/section, faculty acronym.
- `routines`: Active public timetable slots (`day`, `time_label`, `subject_code`, `subject`, `room`, `teacher_codes`, `batch`, `section`).
- `cancellations`: Date-scoped class cancellations with cancellation reasons and teacher timestamps.
- `notifications` & `notification_reads`: Push announcements and per-user read receipt tracking.
- `rooms` & `faculty`: Campus physical space inventory and teaching staff rosters.
- `timetable_configs` & `timetable_schedule_configs`: Academic shifts, periods, and solver tuning parameters.

---

## 11. External Services and Integrations

1. **Google Firebase Cloud Messaging (FCM):** Push notifications on mobile and supported desktop browsers via `push_service.dart` and Deno edge function.
2. **Render Cloud Platform:** Hosts the Python FastAPI OR-Tools constraint microservice (`render.yaml`).
3. **Google Identity (OAuth 2.0):** Single sign-on authentication for university Google accounts.

---

## 12. Complete Route and Screen Inventory

| Route Path | Screen Class | Shell / Layout Target | Key Capabilities & Responsive Architecture |
|---|---|---|---|
| `/` | `SplashScreen` | Standalone | Startup token verification; animated orbit mark; reduced-motion guard. |
| `/onboarding` | `OnboardingScreen` | Standalone | 3-stage interactive routine narrative; PageView; Skip/Done persistence. |
| `/login` | `LoginScreen` | `AuthResponsiveShell` | 58/42 desktop split; Google OAuth; email entry; `RoutineConvergenceShowcase`. |
| `/login/email` | `EmailLoginScreen` | `AuthResponsiveShell` | Bounded card; email/password sign-in; password visibility toggle. |
| `/signup/email` | `EmailSignupScreen` | `AuthResponsiveShell` | Registration; password strength checklist; pre-auth guidance. |
| `/verify-email` | `VerifyEmailScreen` | `AuthResponsiveShell` | 5-second polling; OTP input; session diagnostics. |
| `/forgot-password` | `ForgotPasswordScreen` | `AuthResponsiveShell` | Password recovery; 60-second cooldown protection. |
| `/reset-password` | `ResetPasswordScreen` | `AuthResponsiveShell` | Password update; recovery token verification. |
| `/auth-error` | `AuthErrorScreen` | `AuthResponsiveShell` | Failure diagnostic explanation; sign-out and retry. |
| `/role-selection` | `RoleSelectionScreen` | `AuthResponsiveShell` | Role intent selection (`Student`, `Teacher`, `Admin`); access governance modal. |
| `/register/student` | `StudentRegisterScreen` | `AuthResponsiveShell` | Student ID, batch, section; live Routine Lens preview. |
| `/register/faculty` | `FacultyRegisterScreen` | `AuthResponsiveShell` | Teacher acronym, department; live Teaching Lens preview. |
| `/not-whitelisted` | `NotWhitelistedScreen` | `AuthResponsiveShell` | Faculty/admin whitelist gate explanation; sign-out. |
| `/student/dashboard` | `StudentDashboardScreen` | `AppShell` / Desktop | 62/38 desktop split ($\ge 860\text{px}$); Live/Next/Done Hero Card; 68px telemetry strip. |
| `/student/routine` | `RoutineScreen` | `AppShell` / Desktop | Connected Filter Bar; $\ge 860\text{px}$ Weekly Matrix default; swipeable Day Agenda. |
| `/teacher/dashboard` | `TeacherDashboardScreen` | `AppShell` / Desktop | 62/38 desktop split; Teacher Code badge; teaching load; inline Manage Occurrence. |
| `/teacher/routine` | `RoutineScreen` | `AppShell` / Desktop | Faculty-filtered schedule matrix and swipeable agenda. |
| `/teacher/manage-classes` | `ManageClassesScreen` | `AppShell` / Desktop | Occurrence date banner; 55/45 desktop split vs floating sheet; 2-step recovery. |
| `/notifications` | `NotificationsScreen` | `AppShell` / Desktop | Notification feed; unread badges; read-receipt sync. |
| `/profile` | `ProfileScreen` | `AppShell` / Desktop | User profile; academic metadata; avatar selector; sign-out. |
| `/rooms` | `RoomsScreen` | Standalone / Shell | Campus room grid; free vs. occupied countdown timers. |
| `/rooms/detail` | `RoomDetailScreen` | Standalone / Shell | Detailed daily occupancy schedule for a specific room. |
| `/find-teacher` | `FindTeacherScreen` | Standalone / Shell | Faculty directory; department tabs; real-time status. |
| `/find-teacher/detail` | `TeacherDetailScreen` | Standalone / Shell | Teacher profile; weekly routine; current room location. |
| `/student/resources` | `ResourcesScreen` | `AppShell` / Desktop | Semester folders; resource downloads; signed URLs. |
| `/admin/dashboard` | `AdminDashboardScreen` | `AdminDesktopShell` | 4-stage readiness checklist; horizontal load breakdown; dual-track launchpad. |
| `/admin/routine` | `AdminRoutineScreen` | `AdminDesktopShell` | `USegmentedControl`; `IndexedStack` preserving Manage, Generate, Upload tabs. |
| `/admin/timetable/grid` | `TimetableGridScreen` | `AdminDesktopShell` | Above-control filters; docked 340px inspector at $\ge 1100\text{px}$; swipeable agenda. |
| `/admin/scheduling` | `SchedulingWorkspaceScreen` | `AdminDesktopShell` | 5-stage preview workbench with 1024px collision fix; fail-closed live gate. |
| `/preview/scheduling` | `SchedulingWorkspaceScreen` | Standalone | Unauthenticated design preview route for offline evaluation. |
| `/admin/timetable/rooms` | `ManageRoomsScreen` | `AdminDesktopShell` | Room pool management; capacity limits; lab designations. |
| `/admin/timetable/faculty` | `ManageFacultyScreen` | `AdminDesktopShell` | Teacher off-days, workload limits, department allocation. |
| `/admin/timetable/course-eligibility` | `ManageCourseEligibilityScreen` | `AdminDesktopShell` | Teacher course qualifications and assignment matrix. |
| `/admin/timetable/settings` | `TimetableSettingsScreen` | `AdminDesktopShell` | Solver constraint tuning (shift times, breaks, penalty weights). |
| `/admin/users` | `ManageUsersScreen` | `AdminDesktopShell` | User directory; role modifications; account search. |
| `/admin/registration` | `AdminRegistrationScreen` | `AdminDesktopShell` | Admin invitation forms and whitelist management. |
| `/admin/broadcast` | `CampusBroadcastScreen` | `AdminDesktopShell` | Urgent campus announcement composition and push dispatch. |
| `/admin/broadcast/history` | `BroadcastHistoryScreen` | `AdminDesktopShell` | Broadcast history log with deletion actions. |
| `/admin/resources` | `ManageResourcesScreen` | `AdminDesktopShell` | Resource upload and approval management. |
| `/admin/resources/library` | `ResourceLibraryScreen` | `AdminDesktopShell` | Document library file manager. |

---

## 13. Detailed UI/UX Screen-by-Screen Audit

### 13.1 Reading Guide & Obsidian Orbit Baseline
All screens adhere to Obsidian Orbit design tokens (`AppColors`, `AppSpacing`, `AppTextStyles`, `AppMotion`, `AppTheme.dark`). Screens utilize post-sidebar `LayoutBuilder` usable content width constraints. 4-sided nested cards are systematically dissolved into single top-lit `UCard` containers with 1px dividers.

### 13.2 StudentDashboardScreen — Daily Academic Command Center (Phase 4)
- **Usable-Width Responsive Architecture:**
  - **Expanded Desktop ($\ge 860\text{px}$):** 62% Left Column / 38% Right Column layout ($24\text{px}$ gap).
    - Left: Cohort header strip (`Batch X · Section Y (+ B+C Joint)`), `UAnimatedSwap` Hero Card, and Today's Chronological Class Timeline with time-axis connectors.
    - Right: Compact 68px matched-height telemetry strip (`Scheduled`, `Completed`, `Cancelled` with tabular numerals), Recent Cohort Alerts, and Campus Quick Lookup.
  - **Compact Mobile ($< 600\text{px}$):** Single-axis vertical flow, 68px telemetry strip, zero nested card containers, five-tab bottom navigation and `ProfileAccountAction`; redundant dashboard drawers and Explore FAB retired in UI/UX Phase 7.
- **Hero Card State Machine (`UAnimatedSwap`):**
  - **Live Class:** `LiveClassCard` with 3px orange left accent bar, real-clock progress bar, cohort pill, and styled room badge.
  - **Up Next Today:** `NextClassCard` with 3px cyan info accent bar, countdown timer, cohort pill, and styled room badge.
  - **Done for Today / Weekend:** `MessageHeroCard` with emerald accent summarizing completed classes and previewing tomorrow's first lecture.

### 13.3 TeacherDashboardScreen — Faculty Command Center (Phase 4)
- **Teaching-First Hierarchy:**
  - Header displays `Teacher Code: [CODE]` badge driving schedule matching (`RoutineEntry.matchesTeacher`).
  - **Expanded Desktop ($\ge 860\text{px}$):** 62/38 split. Left: Current/next session hero + Today's Teaching Timeline where each `ClassCard` includes cohort/room pills and inline `Manage Occurrence` action pill linking to `/teacher/manage-classes`. Right: Teaching load summary and campus quick tools.
  - **Compact Mobile ($< 600\text{px}$):** Focused single-axis teaching agenda with thumb-friendly `Manage Occurrence` pills.

### 13.4 RoutineScreen & WeeklyScheduleView — Timetable Matrix & Agenda (Phase 4)
- **Connected Filter Bar:** Displays active routine lens (`Batch X · Section Y` or `Faculty Schedule · [CODE]`), live slot count pill, and `USegmentedControl` toggling `Weekly Matrix` $\leftrightarrow$ `Day List`. Defaults to `Weekly Matrix` at $\ge 860\text{px}$ and `Day List` below $860\text{px}$.
- **Weekly Matrix (`WeeklyScheduleView.matrix`):** 2D timetable grid with `1px` gridlines, highlighted time-slot header, and highlighted **TODAY** row. Cells feature 3px semantic accents (Orange for Theory, Emerald for Lab, Cyan for Joint, Red strikethrough for Cancelled). Tapping a cell opens centered modal on desktop ($\ge 768\text{px}$) or floating sheet on mobile ($< 768\text{px}$) via `showUAdaptiveModal`.
- **Swipeable Day Agenda (`Day List`):** Supports horizontal swipe left/right across `Sun` $\to$ `Thu` synced with `DaySelector` and haptic feedback. Automatically inserts `RoutineBreakDivider` for gaps $\ge 40\text{ minutes}$.

### 13.5 ManageClassesScreen — Surgical Class Actions & Two-Step Recovery (Phase 4)
- **Occurrence Date Banner:** Explicitly displays: `Managing Occurrences for: [Day, Date] · Recurring weekly schedule remains unchanged`.
- **Adaptive Split Inspector:** $\ge 900\text{px}$ 55/45 master-detail split (Left: filterable class list with `All`, `Scheduled`, `Cancelled` chips; Right: docked inspector); $< 900\text{px}$ opens inspector in floating bottom sheet.
- **Truthful Two-Step Recovery:** Surfaces amber warning banner when cancellation succeeds but push notification fails (`CancellationOutcome.partialSuccessNotificationFailed`). Restoring a class offers 1-tap `"Send 'Class Restored' Notice to Cohort"` follow-up.

### 13.6 AdminDashboardScreen — Command Center & Operations Launchpad (Phase 5)
- **Responsive Breakpoint:** $\ge 880\text{px}$ 60/40 two-column layout; $< 880\text{px}$ single column. Suppresses inner app bar inside `AdminDesktopShell`.
- **4-Stage Readiness Checklist:** Actionable lifecycle checklist (`01 Room Pools`, `02 Faculty & Off-Days`, `03 Course Rules`, `04 Active Routine`) with `X / 4 STAGES READY` summary badge.
- **Departmental Load Breakdown:** Horizontal bar chart comparing scheduled hours against department room capacities.
- **Dual-Track Launchpad:** Clear bifurcation between `LIVE PIPELINE` (`/admin/routine`) and `DESIGN PREVIEW` (`/admin/scheduling`).

### 13.7 AdminRoutineScreen & Live Operations (Phase 5)
- **`AdminRoutineScreen`:** Accessible `USegmentedControl` with `IndexedStack` preserving solver polling and parsed workbooks across tab switches (`Manage Published`, `Generate Routine`, `Upload Spreadsheet`).
- **`RoutineManagementScreen`:** Upfront slot count pill (`Showing X slots across Y days`), 2/3-column desktop card grid, and adaptive modal editor.
- **`GenerateTimetableScreen`:** 4-node visual solver timeline (`1. Queued` $\to$ `2. Ingesting` $\to$ `3. CP-SAT Session` $\to$ `4. Rendering`) and Service Recovery Card with 1-tap retry on solver failure.
- **`UploadRoutineScreen`:** 3-step post-parse publication pipeline (`Storage Upload` $\to$ `Routine Slots Publication` $\to$ `Run History Recording`) with secondary warning recovery notice.
- **`TimetableGridScreen`:** Above-control filters, live match counts, docked 340px inspector at $\ge 1100\text{px}$, swipeable day agenda below $860\text{px}$, and `AdminScheduleSlot`.

### 13.8 Scheduling Workspace — 5-Stage Preview Workbench (Phase 5)
- **1024px Sidebar Collision Fix:** Replaced `MediaQuery` width with `LayoutBuilder` usable content width (`usableWidth = constraints.maxWidth`).
- **Three-Tier Architecture:** Expanded ($\ge 1020\text{px}$: 12-col desktop table + docked 360px inspector); Medium ($680\dots 1019\text{px}$: full-width table + modal inspector); Compact ($< 680\text{px}$: touch-first `DistributionListMobile` + bottom sheet).
- **Stage 1 (Distribution):** "Checkbox Off = Gray" signaling discipline (verified baselines stay calm slate-gray); upfront option counts; "Invisible UI" row hover reveal; 5-part academic provenance inspector.
- **Stage 2 (Configuration):** Dissolved `UCard` sections for `R1`–`R15` policies; slate-gray baseline vs amber override badge.
- **Stage 3 (Readiness):** 3-tier preflight blockers (`BLOCKER`, `WARNING`, `PASS`) with direct action buttons (`Resolve in Distribution`, `Adjust Rule`).
- **Stage 4 (Generate):** Priority tier badges, solver parameter weights, and simulated telemetry notice.
- **Stage 5 (Review & Publish):** Section grid, faculty timetable, room occupancy views, and tactile Slide-to-Confirm publication safety slider (`_SlideToConfirmPublish`).
- **Fail-Closed Boundary:** `isLiveWorkspaceOperational == false` strictly blocks live mutations while distribution database contracts are unavailable.

---

## 14. Mobile Experience Audit

- **Zero Horizontal Clipping:** All mobile views ($390\times 844$) operate as single-axis vertical flows with zero horizontal clipping.
- **Ergonomic Touch Targets:** Touch targets meet or exceed $52\text{px}$ for primary actions and $36\text{px}$ for chips and segmented thumbs.
- **Contextual Overlays:** Complex desktop tables and docked inspectors smoothly degrade to top-lit single-handle floating bottom sheets via `showUAdaptiveModal`.
- **Haptic Gestures:** Swipeable Day Agenda in `RoutineScreen` provides tactile haptic feedback on day transitions.

---

## 15. Web Experience Audit

- **Desktop-First Command Centers:** Multi-column layouts utilize post-sidebar canvas widths efficiently:
  - Dashboards: 62% primary / 38% contextual rail.
  - Class Management: 55% class list / 45% docked inspector.
  - Timetable Grid: Full canvas matrix with docked 340px inspector at $\ge 1100\text{px}$.
  - Distribution Table: 12-column provenance grid with docked 360px inspector at $\ge 1020\text{px}$.
- **Keyboard Shortcuts:** `/` focuses the active filter search bar; `[Esc]` closes modal inspectors.
- **Information Density:** Tabular numerals (`AppTextStyles.statNumber`) and compact 68px telemetry strips maximize visible academic context.

---

## 16. Visual Identity and Design System

- **Obsidian Orbit Token System:**
  - Backgrounds: Canvas (`#0A0B0E`), Cards (`#12141A`), Elevated (`#181B22`), Interactive (`#1E222B`).
  - Borders: Subtle (`#252932`), Active Specular (`#3D4351`).
  - Accents: Brand Orange (`#FF6B00`), Theory Accent (`#FF6B00`), Lab/Sessional (`#10B981` Emerald), Joint/Co-taught (`#06B6D4` Cyan), Conflict/Cancelled (`#EF4444` Crimson).
- **"Walmart Receipt" Edge Alignment:** Eliminates nested 4-sided card boxes in favor of single top-lit surfaces with 1px dividers.
- **"Checkbox Off = Gray" Signaling:** Baseline, verified data renders in calm slate-gray; semantic color is reserved exclusively for overrides, conflicts, and warnings.

---

## 17. Onboarding, Splash, and First-Impression Audit

- **SplashScreen:** Centered orbit mark with continuous orbital ring animation, verifying stored auth tokens before route resolution.
- **OnboardingScreen:** 3-stage interactive routine narrative (`onboard_slide.dart`) introducing UniVerse's intelligent engine. Skip and Get Started persist seen status.
- **RoutineConvergenceShowcase:** Pure-Flutter vector instrument in `LoginScreen` illustrating academic constraints converging into an organized timetable.

---

## 18. Component and Widget Architecture

- **`UCard`:** Top-lit surface card featuring vertical gradient, 1px specular top highlight, and hover lift.
- **`UButton`:** 52px/36px normalized button with specular highlight, loading spinners, and press compression.
- **`UTextField`:** Animated focus glow, validation styling, and keyboard shortcut support.
- **`USegmentedControl`:** Sliding segmented control with animated thumb, screen-reader semantics, and arrow key support.
- **`UAnimatedSwap`:** Temporal crossfade, slide, and scale transition primitive with reduced-motion instant rendering.
- **`UPressableScale`:** Tactile interaction wrapper providing pointer-down compression (`0.975`) and desktop hover expansion (`1.012`).
- **`AdminScheduleSlot`:** Phase 5 shared administrative schedule slot component with semantic left border accents, cohort/faculty tags, and room alias tooltips.

---

## 19. Main User Journeys

1. **Student Daily Flow:** Splash $\to$ Dashboard (62/38 split, LiveClassCard with real-clock bar, NextClassCard countdown, 68px telemetry) $\to$ Routine Screen (Weekly Matrix or swipeable Day Agenda) $\to$ Room Vacancy Lookup.
2. **Faculty Daily Flow:** Splash $\to$ Teacher Dashboard (Teacher Code badge, teaching load summary) $\to$ Routine Screen or Manage Classes (Occurrence Date Banner, 55/45 split inspector, date-scoped cancellation with 2-step recovery).
3. **Administrator Operations Flow:** Splash $\to$ Admin Dashboard (4-stage readiness checklist, load breakdown bar chart) $\to$ Admin Routine Operations (USegmentedControl preserving Manage, Generate, Upload tabs) $\to$ Timetable Grid (docked inspector) or Scheduling Workspace (5-stage preview workbench with Slide-to-Confirm publication gate).

---

## 20. Scheduling Architecture and Phase 2b / Phase 5 Status

- **Usable-Width Architecture:** Post-sidebar `LayoutBuilder` eliminates the 1024px sidebar collision, cleanly adapting across Expanded ($\ge 1020\text{px}$), Medium ($680\dots 1019\text{px}$), and Compact ($< 680\text{px}$) tiers.
- **5-Stage Workbench:** Distribution Table/List with 5-part academic provenance inspector $\to$ Policy Configuration with $R1$–$R15$ rules $\to$ Readiness Pane with 3-tier preflight blockers $\to$ Generate Pane with CP-SAT weights $\to$ Review Pane with tactile Slide-to-Confirm publication gate.
- **Fail-Closed Boundary:** `isLiveWorkspaceOperational == false` ensures live mode remains safely locked while contract migrations are pending.
- **Working-Tree Status (9 November 2026):** `SchedulingWorkspaceGateway` abstracts contract access and offline fixtures. Static analysis reports 0 issues. UI/UX Phases 4-7 compile and their focused regression suites pass; repository-wide acceptance remains separate (Section 27).

---

## 21. Performance, Reliability, and Accessibility

- **Paging & Rebuilds:** `RoutineService` pages routine queries at 250 rows. `SafeChangeNotifier` guards against memory leaks and post-dispose notifications.
- **Reduced Motion:** All shared motion primitives (`UAnimatedSwap`, `UPressableScale`, `LiveClassCard`) automatically respect platform reduced-motion preferences.
- **Tabular Numerals:** All operational counts and timetable clocks consume `AppTextStyles.statNumber` and `AppTextStyles.timeCode` using tabular numeric font features to prevent layout jitter during updates.

---

## 22. UI Redesign Safety Map

- **Safe to Modify:** Presentation components, layout compositions, surface styling, typography, spacing, and responsive breakpoints within `lib/features/*/screens/` and `lib/shared/widgets/`.
- **Approval Gate Required:** Any material redesign of user workflows, screen structures, theme systems, or navigation hierarchies requires explicit user approval.
- **Strictly Protected:** Core models (`lib/core/models/`), routing guards (`lib/core/router/`), service signatures (`lib/core/services/`), Supabase migrations (`supabase/migrations/`), and Python solver engine (`engine/solver.py`).

---

## 23. Current Development Roadmap and Phase Status

| Phase | Milestone Name | Status | Verification & Evidence |
|---|---|---|---|
| **Phase 0** | Redesign Baseline & Decisions | **DONE** | Architecture established; theme governance enforced. |
| **Phase 1** | Browser Admin Foundation | **DONE** | Navigation shell, web platform files, role access controls. |
| **Phase 2a** | Accepted Distribution Contract | **DONE** | Immutable contract, Python tests passing (14/14), SQL migration ready. |
| **Phase 2b** | Scheduling Workspace Foundation | **DONE** | 5-stage preview workbench, models, fixtures, initial responsive layout. |
| **Phase 3 / 3.5** | Obsidian Orbit Foundation & Auth Showcase | **DONE** | Design system tokens, shared primitives, 76 golden screenshots. |
| **Phase 4** | Core Student & Teacher Daily Experiences | **DONE & VERIFIED** | 62/38 dashboards, weekly matrix, day agenda, 2-step recovery; 6/6 tests passing. |
| **Phase 5** | Administrative Scheduling & Live Operations | **DONE & VERIFIED** | 4-stage readiness checklist, load breakdown, 1024px collision fix, Slide-to-Confirm, 22 golden screenshots. |
| **Phase 5 Align** | Visual & Structural Alignment | **IMPLEMENTED** | Shell, grid, slot, management, generator and upload alignment preserved by focused tests. |
| **UI/UX Phase 6** | Committee Rules & Supporting Modules | **IMPLEMENTED; FOCUSED TESTS PASS** | R1-R16 presentation and supporting-module work; see `PHASE_6_COMMITTEE_RULES_AND_SUPPORTING_MODULES_REPORT.md`. |
| **UI/UX Phase 7** | Final Admin Routes, R15 Matrices & Navigation Cleanup | **IMPLEMENTED; LOCAL TESTS PASS** | Four secondary screens, URL-backed sibling tabs, configurable matrix row counts and retired mobile dashboard drawer/FAB. Phase 7 targeted tests and the full repository suite pass (Section 27); physical-device and hosted acceptance remain separate. |
| **Master-plan Phase 6** | University Expansion & Multi-Tenancy | **DEFERRED** | Separate backend roadmap milestone; not the UI/UX Phase 6 milestone. |

---

## 24. Planned Features and Future Design Dependencies

| Feature | Backend Dependency | Frontend UI Responsibility |
|---|---|---|
| **Live Source Distribution Edits** | Deploy `course_distribution_contract.sql` to production | Connect `SchedulingWorkspaceGateway` to real Supabase RPCs. |
| **Live CP-SAT Engine Invocations** | Deploy solver microservice on Render with auth | Connect Generate Pane solver buttons to live engine HTTP API. |
| **Atomic Recoverable Routine History** | Versioned routine archive tables | Recoverable version history viewer with 1-tap rollback. |
| **Multi-Department Timetables** | Canonical academic catalog deployment | Multi-department scope selector across admin workbenches. |
| **Interactive AI Assistant** | RAG vector search & backend inference pipeline | Assistant chat interface with citations and honest capability boundaries. |

---

## 25. AI Agents, Skills, Plugins, and Development Workflow

### Multi-Agent Coordination
- **Codex (Terra & Sol):** Reads `AGENTS.md` and loads designated UI/UX skills on demand.
- **Antigravity:** Automatically discovers `AGENTS.md` and progressively loads `.agents/skills/*/SKILL.md`.
- **Claude Code:** Reads `CLAUDE.md` and follows identical skill-routing matrices and approval gates.

### Reusable UI/UX Workflow
All agents follow the unified 11-step lifecycle:
1. Identify Scope $\to$ 2. Inspect Baseline $\to$ 3. Load Relevant Skills $\to$ 4. Understand Problem $\to$ 5. Analyze Opportunities $\to$ 6. Formulate Alternatives $\to$ 7. User Approval Gate $\to$ 8. Implement in Architecture $\to$ 9. Verification $\to$ 10. Visual QA $\to$ 11. Report Evidence.

---

## 26. Recommended Redesign Strategy

1. **Preserve Clean Static Analysis and Focused UI Coverage:** `flutter analyze --no-pub` reports 0 issues. UI/UX Phase 6 is implemented; Phase 7 implementation and focused coverage are in place. Preserve the passing repository-wide checks recorded in Section 27; keep device and hosted acceptance distinct from local tests.
2. **Preserve Verified Phase 4 & Phase 5 Screens:** Do not alter the approved 62/38 student/teacher layouts, weekly matrix, swipeable agenda, 4-stage readiness checklist, or Slide-to-Confirm publication gate.
3. **Progressive Backend Integration:** When the user authorizes database deployment, execute the Phase 2a Course Distribution SQL migration on production Supabase, connect `SchedulingWorkspaceGateway`, and promote the workspace from preview simulation to live operation.

---

## 27. Known Limitations, Working-Tree State, and Verification Boundaries

- **Static Analysis:** `flutter analyze --no-pub` reports 0 issues on 9 November 2026. The older claim of 22 analyzer issues is superseded.
- **Focused Test Status:** Phase 7 has 16 passing widget tests, covering four routes at 390x844 and 1440x900, mobile 1.3x text scale, adaptive deletion modal Escape dismissal, resource filtering, and R15 faculty/room row-count switching. The combined Phase 4-7 run passed 40/40 tests; the final run including scheduling workspace comprehensive tests passed 50/50.
- **Repository-Wide Test Status (follow-up):** Final `flutter test --no-pub` completed with **325 passed, 1 intentionally skipped, 0 failed**. The nine failures from the initial run are resolved: campus-card overflow, outdated route/detail/grid assertions, shared-teacher detail matching, and versioned golden reconciliation. Historical Phase 5 screenshots remain unchanged; the current baseline is `docs/screenshots/phase_7/regression/`. See `PHASE_7_FINAL_UI_UX_CLOSURE_REPORT.md` for precise fixes and limitations.
- **R15 Persistence Boundary:** Both inspectors load daily-grid size from `TimetableSettings.periods` and offer 6/7-slot session previews. Existing matrix selections remain in screen memory; changing grid size preserves hidden selections and does not deploy settings or persist new solver constraints. P4 is a teaching period; the scheduled break is separate.
- **Live Backend Boundaries:** Production Supabase project `yxqyrjyzxitrgkhgauli` lacks Course Distribution contract tables; secondary project `oqwvxplteqtlrhktsplj` has them. Live scheduling mode remains strictly fail-closed.
- **Visual Capture Golden Renders:** Visual inspection gallery in `docs/screenshots/phase_5/VISUAL_REVIEW_GALLERY.md` contains 22 PNG files generated via local widget golden comparison. Solver telemetry in captures is illustrative. No live browser session, production authentication, or live CP-SAT solver call was performed during this investigation.

---

## 28. Technical Glossary

| Term | Definition |
|---|---|
| **CP-SAT** | Constraint Programming - Satisfiability solver from Google OR-Tools. |
| **Obsidian Orbit** | UniVerse's custom dark design system with orange brand accent and 5-tier surface ramp. |
| **Usable Content Width** | Post-sidebar width obtained via `LayoutBuilder` (`constraints.maxWidth`), preventing sidebar collision. |
| **Service Recovery Paradox** | UX principle where a reassuring, transparent error state with actionable retry turns a failure into a positive user experience. |
| **Slide-to-Confirm** | Tactile safety slider requiring deliberate dragging before triggering irreversible actions (e.g. routine publication). |
| **AdminScheduleSlot** | Specialized timetable slot primitive rendering theory/lab/joint accents, cohort tags, and room alias tooltips. |
| **RLS** | Row Level Security enforced on Postgres database tables. |

---

## 29. Source and Evidence Index

| ID | Source File / Artifact | Evidence & Verification Scope |
|---|---|---|
| **E01** | `AGENTS.md`, `CLAUDE.md` | Operating constraints, UI/UX skill routing, and mandatory approval gates. |
| **E02** | `docs/implementation/UniVerse_Implementation_Master_Plan_v1_1.md` | Master roadmap, phase checkpoints, and committee policies. |
| **E03** | `docs/implementation/phase_4_core_student_and_teacher_experiences.md` | Phase 4 student/teacher command centers, weekly matrix, day agenda, and 2-step recovery. |
| **E04** | `docs/implementation/phase_5_administrative_scheduling_experience.md` | Phase 5 admin command center, live routine operations, and clip-free scheduling workbench. |
| **E05** | `test/phase_4_student_teacher_experiences_test.dart` | Passing Phase 4 widget & responsive test suite (6/6 passing). |
| **E06** | `test/phase_5_admin_scheduling_and_operations_test.dart` | Phase 5 admin command center and routine test suite. |
| **E07** | `docs/screenshots/phase_3/VISUAL_REVIEW_GALLERY.md` | 76 Phase 3.5 visual inspection screenshots. |
| **E08** | `docs/screenshots/phase_5/VISUAL_REVIEW_GALLERY.md` | 22 Phase 5 visual inspection screenshots across desktop, medium, and mobile viewports. |
| **E09** | `lib/core/theme/*.dart` | Obsidian Orbit design tokens (`AppColors`, `AppSpacing`, `AppTextStyles`, `AppMotion`, `AppTheme`). |
| **E10** | `lib/features/admin/widgets/admin_schedule_slot.dart` | Phase 5 administrative schedule slot component with semantic accents and room tooltips. |
| **E11** | `engine/solver.py`, `distribution.py`, `render.py` | Python OR-Tools CP-SAT solver, immutable contract, and Excel renderer. |
| **E12** | `supabase/migrations/` | Database schema, RLS policies, catalog tables, and Course Distribution contract. |
| **E13** | Production Supabase metadata (`yxqyrjyzxitrgkhgauli`) | 18 public tables with RLS enabled; lacks Course Distribution contract tables. |
| **E14** | Secondary Supabase metadata (`oqwvxplteqtlrhktsplj`) | Additive Course Distribution contract tables deployed. |
