# UniVerse Project Structure & File Index

This document provides a comprehensive, complete index of all folders and files in the **UniVerse (`universe_v1`)** repository, including a 1-line description of what each file does, where it is used, and how it is or will be used.

---

## 📂 High-Level Repository Architecture

| Directory / File | Description & Usage |
|---|---|
| `.agents/` | Repository-local agent skills, UI/UX design guidelines, and implementation governance for pair-programming agents. |
| `android/` | Android native runner, Gradle build scripts, AndroidManifest permissions, and native splash configuration. |
| `apps/web/` | Standalone React 19 + TypeScript + Vite web application (Administrator Operations Console, public institutional `/`, and student/teacher mobile-app guidance) under **UniVerse Academic Ledger**. |
| `assets/` | Static application assets including app icons, vectors, and illustrative graphics. |
| `docs/` | Authoritative master plans, web-separation architecture docs, phase design specs, visual review galleries, and committee policy audits. |
| `engine/` | Python OR-Tools CP-SAT timetable constraint solver, workbook parser, Excel renderer, and FastAPI microservice. |
| `ios/` | iOS native runner and Xcode workspace (compatibility continuously preserved for deep links/auth/backend; active new iOS feature expansion deferred). |
| `lib/` | Main Flutter mobile application source code organized by feature-first architecture (`core/`, `features/`, `shared/`). |
| `linux/` / `macos/` / `windows/` | Flutter desktop platform configurations and native runner entrypoints. |
| `new genarated routine/` | Archive of generated Excel routine workbooks produced during development and testing. |
| `supabase/` | Supabase Postgres SQL migrations, pgTAP tests, seed datasets, and Deno TypeScript edge functions. |
| `test/` | Automated Flutter unit, widget, layout, navigation, motion, and visual capture regression test suites. |
| `tool/` | Python diagnostics, schema probes, visual capture scripts, and defense diagram generators. |
| `web/` | Web platform runner, `index.html` canvas configuration, manifest, and service worker. |
| `workbook/` | Academic curriculum distributions, room inventory workbooks, and semester constraints (read-only). |
| `AGENTS.md` | Primary operating rules, Flutter Web freeze policy, archive exclusion, and UI/UX skill routing for Codex and Antigravity. |
| `CLAUDE.md` | Primary operating rules, architecture summary, and UI/UX skill routing for Claude Code. |
| `DATABASE_AND_ROUTINE_SYSTEM_ARCHITECTURE.md` | Authoritative database schema, RLS, and routine pipeline architecture reference. |
| `PROJECT_STRUCTURE.md` | Complete file inventory and subsystem directory guide (this document). |
| `README.md` | Project overview, tech stack, quick-start guide, and current milestone status. |
| `analysis_options.yaml` | Dart static analysis configuration with strict lint rules enforcing clean code quality. |
| `pubspec.yaml` | Flutter package dependencies (`go_router`, `supabase_flutter`, `google_fonts`, etc.) and asset declarations. |
| `render.yaml` | Deployment specification for hosting the Python engine microservice on Render. |

---

## 📱 Flutter Application (`lib/`)

### 1. Application Entrypoint
- `lib/main.dart` — Main application entrypoint; initializes Flutter bindings, Supabase client, and boots `AppRouter`.
- `lib/firebase_options.dart` — Firebase configuration options for push notifications on supported platforms.

---

### 2. Core Subsystem (`lib/core/`)

#### `lib/core/constants/`
- `lib/core/constants/app_constants.dart` — Global application constants including academic days, default timeouts, and storage buckets.
- `lib/core/constants/app_enums.dart` — Domain enumerations (`UserRole`, `AuthStatus`, `DayOfWeek`, `RoomType`, `ClassType`).

#### `lib/core/models/`
- `lib/core/models/academic_model.dart` — Domain models for academic courses, departments, semesters, batches, and sections.
- `lib/core/models/notification_model.dart` — In-app notification and campus broadcast data model.
- `lib/core/models/profile_model.dart` — User profile entity with role flags, department, batch, and teacher acronym.
- `lib/core/models/resource_model.dart` — Learning resource model representing course syllabus, slides, and class notes.
- `lib/core/models/routine_model.dart` — Timetable schedule entry model (`RoutineEntry`) representing a single scheduled class slot with teacher and section matching helpers.
- `lib/core/models/timetable_config_model.dart` — Configuration model for timetable solver constraints, time windows, and day-offs.
- `lib/core/models/whitelist_model.dart` — Whitelist entry model used for pre-registering authorized faculty and admin emails.

#### `lib/core/platform/`
- `lib/core/platform/auth_callback_cleanup.dart` — Platform abstraction interface for cleaning OAuth PKCE tokens from the browser URL.
- `lib/core/platform/auth_callback_cleanup_web.dart` — Web implementation that uses `dart:html` / `package:web` to rewrite the URL bar after OAuth.
- `lib/core/platform/auth_callback_cleanup_stub.dart` — No-op stub for non-web platforms.
- `lib/core/platform/file_downloader.dart` — Cross-platform file download coordinator for saving exported routines and reports.
- `lib/core/platform/file_downloader_interface.dart` — Abstract interface defining byte downloading capabilities across platforms.
- `lib/core/platform/file_downloader_io.dart` — Native platform implementation saving downloaded files to local desktop/mobile storage.
- `lib/core/platform/file_downloader_web.dart` — Web platform implementation triggering browser file downloads via Blob and anchor tag.
- `lib/core/platform/file_downloader_stub.dart` — Fallback stub for unsupported platforms.

#### `lib/core/router/`
- `lib/core/router/app_router.dart` — Central `GoRouter` definition with role guards, transition choreography (`_transitionPage`), and redirect logic.
- `lib/core/router/app_shell.dart` — Mobile adaptive scaffold shell wrapping bottom navigation and `UAnimatedSwap` view transitions.
- `lib/core/router/route_names.dart` — Strongly-typed URL constants for every route in the UniVerse ecosystem.

#### `lib/core/services/`
- `lib/core/services/push_service.dart` — Push notification service integrating Firebase Cloud Messaging (FCM) and device token registration.

#### `lib/core/theme/`
- `lib/core/theme/app_colors.dart` — Obsidian Orbit color token system defining the 5-tier lightness ramp, orange brand accents, and status containers.
- `lib/core/theme/app_motion.dart` — Centralized motion tokens (`micro`, `fast`, `medium`, `slow`), easing curves (`magnetic`, `snappy`), and reduced-motion policy.
- `lib/core/theme/app_spacing.dart` — 4px optical spacing grid (`xs: 4px` to `xxxl: 32px`), control heights (`52px`/`36px`), and border radii.
- `lib/core/theme/app_text_styles.dart` — Typography ramp using Inter with tabular numeric features, operational 24px caps, and WCAG AA contrast.
- `lib/core/theme/app_theme.dart` — Centralized Material 3 `ThemeData.dark` definition incorporating Obsidian Orbit tokens and normalized button constraints.

#### `lib/core/utils/`
- `lib/core/utils/clock_time.dart` — Robust 24-hour time parser and comparator (`ClockTime`) for class start/end calculations.
- `lib/core/utils/date_utils.dart` — Formatting helpers for academic semesters, week days, countdown timers, and schedule dates.
- `lib/core/utils/extensions.dart` — Dart language extensions on `BuildContext`, `String`, and collections for ergonomic UI development.
- `lib/core/utils/room_identity.dart` — Canonical room name normalization utility matching rooms across workbooks and databases.
- `lib/core/utils/safe_change_notifier.dart` — Base `ChangeNotifier` subclass that prevents calling `notifyListeners()` after disposal or mid-build.
- `lib/core/utils/validators.dart` — Form input validators for university email addresses, student IDs, passwords, and room codes.

---

### 3. Feature Modules (`lib/features/`)

#### `lib/features/admin/` (Administration & Timetable Engine Management)
- **Controllers:**
  - `admin_dashboard_controller.dart` — Coordinates admin dashboard state, readiness metrics, and quick stats with DI seams.
  - `broadcast_controller.dart` — Manages composing and dispatching urgent campus-wide broadcasts.
  - `course_eligibility_controller.dart` — Controls faculty course assignment eligibility and allocation rules.
  - `manage_users_controller.dart` — Handles searching, filtering, and role modifications for student/teacher accounts.
  - `resource_admin_controller.dart` — Manages university curriculum files, slide uploads, and folder structures.
  - `routine_admin_controller.dart` — Oversees active routine versions, archive states, and publish status gates.
  - `routine_upload_controller.dart` — Handles parsing, validating, and publishing uploaded Excel schedule workbooks.
  - `timetable_faculty_controller.dart` — Manages faculty availability, preferred teaching windows, and off-day rules.
  - `timetable_gen_controller.dart` — Interacts with backend engine to trigger and monitor OR-Tools timetable generation jobs.
  - `timetable_rooms_controller.dart` — Manages room inventory, theory vs. lab assignments, and student capacity limits.
  - `timetable_settings_controller.dart` — Configures global solver constraints (session lengths, slot times, max consecutive hours).
  - `whitelist_controller.dart` — Manages authorized email addresses for teacher and admin role approvals.
- **Scheduling Workspace (`lib/features/admin/scheduling/`):**
  - `controllers/scheduling_workspace_controller.dart` — State machine governing the 5-tab scheduling preview workspace (`Readiness`, `Distribution`, `Config`, `Generate`, `Review`) and gateway abstraction.
  - `fixtures/scheduling_preview_fixtures.dart` — High-fidelity synthetic preview fixtures for offline scheduling workbench evaluation.
  - `models/scheduling_workspace_models.dart` — Domain models for editable course distributions, solver constraints, and validation diagnostics.
  - `widgets/scheduling_header_bar.dart` — Desktop header bar showing active semester, preview mode badge, and primary action buttons.
  - `widgets/scheduling_revision_bar.dart` — Versioning toolbar managing distribution draft revisions and click-to-copy hash.
  - `widgets/configuration/scheduling_configuration_pane.dart` — UI panel for editing daily time slots, room pools, and faculty constraint sets (`R1`–`R15`).
  - `widgets/distribution/distribution_filters_bar.dart` — Filter bar for sorting and searching distribution rows with upfront option counts.
  - `widgets/distribution/distribution_list_mobile.dart` — Mobile adaptive vertical list view for course distribution records.
  - `widgets/distribution/distribution_record_inspector.dart` — 5-part academic provenance inspector for editing course offering constraints.
  - `widgets/distribution/distribution_table_desktop.dart` — High-density tabular grid with "Checkbox Off = Gray" signaling and hover reveal.
  - `widgets/generate/scheduling_generate_pane.dart` — Solver execution pane with priority weights, execution telemetry, and conflict alerts.
  - `widgets/readiness/scheduling_readiness_pane.dart` — 3-tier preflight validation checklist verifying curriculum, room, and faculty integrity before solve.
  - `widgets/review/scheduling_review_pane.dart` — Post-solve review matrix with section grid, faculty timetable, room occupancy, and tactile Slide-to-Confirm publication gate.
- **Screens:**
  - `admin_dashboard_screen.dart` — Administrative command center featuring 4-stage readiness checklist, load breakdown bar chart, and dual-track launchpad.
  - `admin_registration_screen.dart` — Dedicated enrollment screen for invited campus administrators.
  - `admin_routine_screen.dart` — Master administrative routine operations screen with `USegmentedControl` and `IndexedStack` state preservation.
  - `broadcast_history_screen.dart` — History view of all past campus broadcasts and push notifications sent to students/faculty.
  - `campus_broadcast_screen.dart` — Screen for drafting and broadcasting announcements targeting specific batches or departments.
  - `generate_timetable_screen.dart` — Specialized wizard screen with 4-node visual solver timeline and Service Recovery Paradox error card.
  - `manage_course_eligibility_screen.dart` — Matrix screen assigning teacher qualifications to departmental course offerings.
  - `manage_faculty_screen.dart` — Screen for configuring teacher off-days, max daily load, and department allocations.
  - `manage_resources_screen.dart` — Admin screen for organizing, approving, or removing uploaded learning resources.
  - `manage_rooms_screen.dart` — Screen for editing campus room numbers, seat capacities, and computer lab designations.
  - `manage_users_screen.dart` — User directory screen for inspecting user profiles and role assignment.
  - `resource_library_screen.dart` — Administrative document library viewer.
  - `routine_management_screen.dart` — Version control screen with upfront slot counts, hover/focus editing actions, and adaptive modal editor.
  - `scheduling_workspace_screen.dart` — Full-page container for the interactive 5-tab Scheduling Workspace with 1024px collision fix and 390px ergonomics.
  - `timetable_grid_screen.dart` — Full-canvas weekly timetable grid viewer with above-control filters, live match counts, docked 340px inspector at $\ge 1100\text{px}$, and swipeable day agenda below $860\text{px}$.
  - `timetable_settings_screen.dart` — Settings screen for customizing academic shift times, lunch breaks, and prayer slots.
  - `upload_routine_screen.dart` — Drag-and-drop Excel routine upload screen with 3-step post-parse publication pipeline and secondary warning recovery.
- **Services:**
  - `academic_config_service.dart` — Backend service fetching and persisting academic catalog hierarchies (departments, courses, semesters).
  - `admin_service.dart` — Core admin service handling high-privilege RPCs, room queries, and administrative operations.
  - `engine_connectivity_service.dart` — Health check and network client communicating with the Python solver microservice.
  - `generation_profile.dart` — Helper service bundling semester constraints into the standardized JSON payload required by the engine.
  - `routine_workbook_parser.dart` — Dart-side Excel parser extracting routine entries and room schedules from uploaded `.xlsx` files.
  - `timetable_config_service.dart` — Service managing database read/write operations for timetable configurations.
  - `timetable_engine_service.dart` — Dispatcher sending solve requests to Supabase Edge Functions or the direct solver API.
- **Widgets:**
  - `admin_card_grid.dart` — Responsive grid displaying operational summary cards on the admin dashboard.
  - `admin_desktop_shell.dart` — Full-height desktop shell with persistent sidebar navigation, engine health pill, breadcrumbs, and single-header enforcement.
  - `admin_schedule_slot.dart` — Administrative schedule slot component with semantic left border accents (theory, lab, joint), cohort/faculty tags, and room alias tooltips.

#### `lib/features/auth/` (Authentication, Pre-Auth Story & Account Security)
- **Controllers:**
  - `auth_controller.dart` — Global authentication state machine managing user sessions, sign-in/up flows, role detection, and sign-out.
- **Screens:**
  - `auth_error_screen.dart` — Graceful error screen explaining connection or session failures with diagnostic details and retry buttons.
  - `email_login_screen.dart` — Standard email and password sign-in form with validation and password visibility toggle.
  - `email_signup_screen.dart` — New user registration form with email validation, password strength checklist, and pre-auth guidance.
  - `faculty_register_screen.dart` — Teacher onboarding form capturing teacher acronym/code, department, and live Teaching Lens preview.
  - `forgot_password_screen.dart` — Password recovery request screen with 60-second cooldown protection.
  - `login_screen.dart` — Primary entrypoint screen featuring Google OAuth sign-in, email login entry, and 58/42 split showcase.
  - `not_whitelisted_screen.dart` — Informational gate screen explaining departmental whitelist requirements for teacher/admin roles.
  - `onboarding_screen.dart` — 3-stage interactive routine-generation narrative introducing UniVerse's intelligent engine.
  - `placeholder_screen.dart` — Lightweight fallback screen used during route resolution transitions.
  - `reset_password_screen.dart` — Secure password update screen verifying recovery tokens and enforcing password match rules.
  - `role_selection_screen.dart` — Role intent selection screen (`Student`, `Teacher`, `Admin`) with top-lit access governance modal dialog.
  - `splash_screen.dart` — Minimalist Obsidian Orbit startup screen verifying stored auth tokens before route dispatch.
  - `student_register_screen.dart` — Student registration form capturing Student ID, Batch, Section, and live Routine Lens preview.
  - `verify_email_screen.dart` — Email verification screen with 5-second polling, OTP manual input, and safe refresh diagnostics.
- **Services:**
  - `auth_callback_policy.dart` — State machine governing deep-link auth callbacks and preventing duplicate redirect handling.
  - `auth_service.dart` — Direct Supabase GoTrue client wrapper managing session tokens, password resets, and user metadata.
  - `invitation_callback_bridge.dart` — Bridge connecting external invitation links with the Flutter navigation hierarchy.
  - `invitation_callback_coordinator.dart` — Manages admin invitation verification tokens and deep link parameter extraction.
- **Widgets:**
  - `auth_responsive_shell.dart` — Adaptive layout wrapper providing a 58/42 desktop split, centered tablet card, and keyboard-safe mobile layout.
  - `google_sign_in_button.dart` — High-contrast branded Google Sign-In button with loading indicators.
  - `onboard_slide.dart` — Mobile vertical illustration card rendering individual onboarding stage graphics and copy.
  - `orbit_status.dart` — Shared vector status mark rendering continuous orbital rings for splash, verify, and error states.
  - `password_requirements.dart` — Real-time visual checklist tracking password length and match requirements.
  - `registration_lens_preview.dart` — Dynamic preview card demonstrating how student/teacher inputs map to published timetable schedules.
  - `routine_convergence_showcase.dart` — Pure-Flutter vector instrument illustrating academic inputs converging into an organized timetable.

#### `lib/features/dashboard/` (Student Hub)
- `controllers/student_dashboard_controller.dart` — Manages student dashboard data fetching, joint-section resolution, next class calculation, and tomorrow's first class preview.
- `screens/student_dashboard_screen.dart` — Student command center featuring 62/38 desktop split, 68px telemetry strip, and temporal Hero Card (`LiveClassCard`, `NextClassCard`, `MessageHeroCard`).

#### `lib/features/find_teacher/` (Faculty Directory & Real-Time Availability)
- `controllers/find_teacher_controller.dart` — Handles faculty directory searches, department filtering, and active schedule lookups.
- `screens/find_teacher_screen.dart` — Searchable faculty directory with department tabs and real-time teaching status indicators.
- `screens/teacher_detail_screen.dart` — Detailed teacher profile showing weekly schedule, current room location, and contact information.
- `services/teacher_location_service.dart` — Derives a teacher's real-time campus room location by cross-referencing published routines with the clock.
- `widgets/teacher_location_card.dart` — Top-lit status card displaying a teacher's current class, occupied room, and next availability window.

#### `lib/features/notifications/` (Campus Communications)
- `controllers/notification_controller.dart` — Manages in-app notification streams, unread badges, and read-receipt synchronization.
- `screens/notifications_screen.dart` — Notification feed displaying class cancellations, schedule updates, and campus broadcasts.
- `services/notification_service.dart` — Supabase Realtime client listening for inserted broadcast notices and updating local state.

#### `lib/features/profile/` (User Account Settings)
- `controllers/profile_controller.dart` — Manages updating user profile details, notification preferences, and password changes.
- `screens/profile_screen.dart` — User profile view showing academic metadata (Student ID, Batch, Section, Teacher Acronym) and sign-out action.
- `services/profile_service.dart` — Service executing Supabase queries to update user profiles in the `profiles` table.

#### `lib/features/resources/` (Academic Course Materials)
- `controllers/resource_controller.dart` — Handles browsing, searching, and downloading course notes, slides, and syllabus documents.
- `screens/resources_screen.dart` — Categorized file library organized by semester, course code, and material type.
- `services/resource_service.dart` — Storage service interacting with Supabase Storage buckets to generate signed download URLs.

#### `lib/features/rooms/` (Campus Room Utilization & Vacancy Lookup)
- `controllers/rooms_controller.dart` — Manages querying campus rooms and calculating real-time vacancy based on active class routines.
- `screens/rooms_screen.dart` — Campus room grid displaying free vs. occupied rooms with real-time countdown timers.
- `screens/room_detail_screen.dart` — Detailed schedule view for a specific room showing complete daily slot occupancies.
- `services/room_status_service.dart` — Computes room occupancy status by comparing current clock time with routine start/end windows.
- `widgets/room_status_card.dart` — Top-lit card showing room capacity, active class, occupying teacher, and next free time slot.

#### `lib/features/routine/` (Timetable Viewer)
- `controllers/routine_controller.dart` — Fetches published routine slots, filters by student batch/section or teacher code, and supports swipe day navigation.
- `screens/routine_screen.dart` — Core timetable viewer with Connected Filter & View Context Bar (`USegmentedControl`), $\ge 860\text{px}$ weekly matrix default, swipeable day agenda, and $\ge 40\text{m}$ break dividers.
- `services/routine_service.dart` — Fetches active published routine entries from the `routines` Supabase table.

#### `lib/features/teacher/` (Faculty Hub)
- `controllers/manage_classes_controller.dart` — Controls date-scoped class cancellations, master-detail selection, and truthful two-step side-effect recovery.
- `controllers/teacher_dashboard_controller.dart` — Manages faculty dashboard data, today's teaching load summary, and cancellation telemetry.
- `screens/manage_classes_screen.dart` — Surgical teacher class management screen with occurrence date banner, 55/45 master-detail split on desktop vs floating sheet on mobile, and two-step recovery.
- `screens/teacher_dashboard_screen.dart` — Faculty command center featuring teacher code badge, teaching load summary, and inline `Manage Occurrence` action pills.
- `services/teacher_service.dart` — Service handling teacher schedule retrieval and `CancellationOutcome` two-step result classification.

---

### 4. Shared Primitives & Design System (`lib/shared/`)

#### `lib/shared/utils/`
- `lib/shared/utils/nav_utils.dart` — Navigation helpers managing context-aware routing, modal dismissals, and fallback routes.
- `lib/shared/utils/phosphor_compat.dart` — Phosphor icon compatibility layer ensuring consistent icon mapping across screens.

#### `lib/shared/widgets/`
- `app_bottom_nav.dart` — Mobile bottom navigation bar with dual visual cues (active pill container + bold label) and `SafeArea` clearance.
- `app_drawer.dart` — Slide-out navigation drawer used on compact mobile admin views.
- `campus_lookup_switcher.dart` — Sliding segmented control switching seamlessly between Teacher and Room lookup modes.
- `chat_bubble.dart` — Chat/announcement message bubble styling for broadcast feeds.
- `class_card.dart` — Standard timetable class block card with 3px semantic accent bar, teacher badges, `trailingAction` slot, and `isSelected` highlight.
- `day_selector.dart` — Horizontal day-of-week selector strip for jumping between timetable days (`Sun`–`Thu`).
- `desktop_shell_scope.dart` — Inherited widget providing desktop shell state, breadcrumbs, and user account popup menus.
- `explore_fab_menu.dart` — Expandable floating action button providing quick lookup shortcuts on mobile dashboards.
- `info_row.dart` — Standardized key-value metadata row with high-contrast text and icons.
- `live_class_card.dart` — Active class hero card with 3px orange left accent bar, real clock-based progress bar, time elapsed, cohort pill, and styled room badge.
- `message_hero_card.dart` — Top-lit status card with 3px semantic accent bar summarizing daily class completion and previewing tomorrow's first lecture.
- `next_class_card.dart` — Upcoming class preview card with 3px cyan info accent bar, countdown timer, cohort pill, and styled room badge.
- `notification_tile.dart` — List tile component representing an individual broadcast notice or class update.
- `quick_action_card.dart` — Grid action card providing one-tap navigation to frequent tasks (e.g. Find Room, View Routine).
- `resource_card.dart` — File download card displaying document title, file type badge, and size.
- `role_card.dart` — Role selection card with role icon, category badge, and hover/press micro-interactions.
- `role_desktop_shell.dart` — Universal desktop layout shell featuring a persistent sidebar, user account pill, and animated body transitions.
- `scrollable_empty.dart` — Scrollable empty-state container allowing pull-to-refresh gestures even when lists are empty.
- `settings_tile.dart` — Standardized settings row with leading icon, title, subtitle, and trailing switch or chevron.
- `shell_back_scope.dart` — Back-navigation interceptor managing nested route pops within shell scaffolds.
- `stat_card.dart` — Metric summary card displaying large tabular numbers and compact 68px matched-height telemetry mode.
- `u_adaptive_overlay.dart` — Shared adaptive overlay primitive rendering a centered top-lit modal dialog (`[Esc]` dismissible) on desktop/tablet ($\ge 768\text{px}$) and a single-handle floating bottom sheet on mobile ($< 768\text{px}$).
- `u_animated_swap.dart` — Shared keyed crossfade, slide, and scale transition primitive that immediately renders rest states under reduced motion.
- `u_app_bar.dart` — Obsidian Orbit styled application bar with back buttons and action slots.
- `u_avatar.dart` — Network user avatar with fallback initials and token-compliant borders.
- `u_badge.dart` — Semantic status badge with container fills and optional pulsing live dots.
- `u_blocking_overlay.dart` — Modal barrier overlay preventing user input during asynchronous save operations.
- `u_bottom_nav.dart` — Core reusable bottom navigation widget adhering to Obsidian Orbit visual guidelines.
- `u_button.dart` — High-contrast primary/secondary button with top specular highlight, hover/press scaling, and loading spinners.
- `u_card.dart` — Obsidian Orbit surface card featuring vertical gradients, 1px top highlight, and hover lift effects.
- `u_chip.dart` — Filter and category tag chip with 36px touch target compliance and pressable scale response.
- `u_divider.dart` — Subtle 1px divider line using semantic border tokens.
- `u_empty_state.dart` — Four-variant state presenter (`firstUse`, `noMatches`, `error`, `lockedCapability`).
- `u_loading.dart` — Design system skeleton shimmer loader and branded circular progress indicator.
- `u_local_avatar.dart` — Local initials avatar with deterministic palette selection based on user name.
- `u_pressable_scale.dart` — Tactile interaction wrapper providing pointer-down compression (`0.975`) and desktop hover expansion (`1.012`).
- `u_responsive_workspace.dart` — Post-sidebar `LayoutBuilder` workspace primitives (`UResponsiveWorkspace`, `UMasterDetailWorkspace`, `UAdaptiveCardGrid`, and `USearchFilterBar` with `/` desktop shortcut).
- `u_section_header.dart` — Typography header separating dashboard sections with optional trailing action buttons.
- `u_segmented_control.dart` — Accessible sliding segmented selector with animated thumb, keyboard navigation, and screen-reader support.
- `u_text_field.dart` — Form text input field featuring animated outer focus glow, validation error styling, and label hints.
- `weekly_schedule_view.dart` — High-craft academic matrix with 3px semantic cell accents, sticky time headers, today row highlight, cell detail modal inspection, and `RoutineBreakDivider`.

---

## ⚙️ Timetable Constraint Engine (`engine/`)

### Core Python Modules
- `engine/config.json` — Solver configuration defining campus day shifts, slot durations, room mappings, and penalty weights.
- `engine/distribution.py` — Phase 2a immutable Course Distribution contract, validating course offerings, credit hours, and section allocations.
- `engine/domain.py` — Domain models for teachers, rooms, courses, time slots, and schedule variables.
- `engine/ingest.py` — Ingestion pipeline parsing raw university distribution workbooks into structured solver inputs.
- `engine/legacy_mapping.py` — Translation layer mapping legacy Excel abbreviations to canonical database course and teacher IDs.
- `engine/main.py` — FastAPI HTTP server entrypoint exposing endpoints for solver execution, health checks, and Excel export.
- `engine/Procfile` — Web process command specifying the Gunicorn/Uvicorn startup configuration for Render deployment.
- `engine/render.py` — Formats and renders solver results into stylized, printable university Excel timetable templates.
- `engine/room_policy.py` — Enforces physical room constraints (capacity limits, theory vs. lab assignments, and floor proximity).
- `engine/solver.py` — Google OR-Tools CP-SAT constraint programming engine assembling optimal, conflict-free university routines.
- `engine/runtime.txt` — Specifies the Python runtime version (`python-3.11.x`) for server deployment.
- `engine/requirements.txt` — Production Python dependencies (`ortools`, `fastapi`, `uvicorn`, `openpyxl`, `pandas`, `pydantic`).
- `engine/requirements-dev.txt` — Testing dependencies (`pytest`, `pytest-cov`, `black`, `flake8`).

### Testing & Verification (`engine/tests/`)
- `engine/tests/conftest.py` — Pytest configuration and shared fixtures for solver test runs.
- `engine/tests/test_cross_semester_acceptance.py` — Verifies solver feasibility across multi-semester simultaneous routine generation.
- `engine/tests/test_cse_readiness.py` — Tests solver execution against real CSE departmental requirements.
- `engine/tests/test_distribution_contract.py` — Verifies the Phase 2a course distribution schema and validation rules.
- `engine/tests/test_domain.py` — Tests domain entity instantiations, hashing, and equality rules.
- `engine/tests/test_eligibility.py` — Validates faculty qualification constraints and course matching.
- `engine/tests/test_fixed_sessions.py` — Ensures fixed course sessions (e.g., Friday prayer gaps, seminar slots) remain inviolate.
- `engine/tests/test_ingest.py` — Tests workbook parsing accuracy and error handling for malformed input sheets.
- `engine/tests/test_lab_allocation_and_tba.py` — Validates contiguous multi-hour lab slot assignments and TBA teacher handling.
- `engine/tests/test_legacy_mapping.py` — Tests translation mappings for historical course numbers and room codes.
- `engine/tests/test_normalized_domain.py` — Validates normalization pipelines converting raw inputs to canonical domain objects.
- `engine/tests/test_real_distribution.py` — Executes end-to-end solve simulations using authentic historical department distributions.
- `engine/tests/test_render.py` — Tests that generated Excel workbooks conform to template visual styling and formula rules.
- `engine/tests/test_render_hygiene.py` — Verifies that rendered output files contain zero leftover debug artifacts or corrupted cells.
- `engine/tests/test_same_day.py` — Enforces anti-clustering rules preventing duplicate lectures for the same course on a single day.
- `engine/tests/test_semester_shapes.py` — Tests schedule distribution shapes across junior vs. senior semester loads.
- `engine/tests/test_solver.py` — Core CP-SAT solver constraint validation tests.

### Engine Tools (`engine/tools/`)
- `engine/tools/expand_template.py` — Expands Excel routine templates with dynamic batch and section column ranges.
- `engine/tools/make_engine_doc.py` — Generates solver technical architecture documentation directly from source comments.
- `engine/tools/seed_config.py` — Generates default JSON configuration payloads for engine seeding.

---

## ⚡ Supabase Backend (`supabase/`)

### Database Migrations (`supabase/migrations/`)
- `001_notification_reads.sql` — Tracks user-specific read receipts for campus notifications.
- `002_drop_profiles_photo_url.sql` — Schema hygiene dropping unused profile image URLs in favor of avatar initials.
- `003_routines_teacher_text.sql` — Adjusts routine teacher fields to support text-based acronyms alongside foreign keys.
- `004_device_tokens.sql` — Creates the `device_tokens` table for FCM push notification delivery.
- `005_register_device_token.sql` — Database function for upserting mobile and web push tokens securely.
- `006_enable_rls_all_tables.sql` — Enforces Row Level Security (RLS) across all public database tables.
- `007_cancellations_schema.sql` — Schema for tracking class cancellations, makeup classes, and cancellation reasons.
- `008_rls_timetable_config.sql` — Restricts timetable configuration mutations strictly to verified campus administrators.
- `009_drop_unused_objects.sql` — Removes deprecated functions and temporary staging tables.
- `011_timetable_schedule_config.sql` — Tables for storing solver parameters, academic shifts, and day mappings.
- `012_routine_versions.sql` — Versioning schema enabling routine archiving, draft states, and safe rollbacks.
- `013_faculty_course_eligibility.sql` — Relational schema mapping faculty qualifications to specific course offerings.
- `014_publish_routine_safeupdate.sql` — Atomic stored procedure for promoting a draft timetable to the live public routine.
- `015_fixed_sessions_per_week.sql` — Adds credit-hour and session-count constraints to course definitions.
- `016_teacher_whitelist_gate.sql` — Security migration enforcing whitelist checks for faculty and admin role assignments.
- `20261022140809_academic_catalog.sql` — Core academic catalog schema establishing departments, courses, and programs.
- `20261106130000_course_distribution_contract.sql` — Phase 2a Course Distribution tables, immutability triggers, and revision audit logs.

### Edge Functions (`supabase/functions/`)
- `supabase/functions/invite-admin/index.ts` — Edge function sending admin invitation emails and provisioning preliminary whitelist entries.
- `supabase/functions/send-push/index.ts` — Webhook-driven edge function dispatching FCM notifications when broadcasts or cancellations occur.

### Verification & Reconciliation (`supabase/tests/` & `supabase/reconciliation/`)
- `supabase/tests/academic_domain.test.sql` — pgTAP unit tests verifying academic catalog integrity and foreign key constraints.
- `supabase/tests/baseline.test.sql` — pgTAP baseline tests verifying table existence and RLS enablement.
- `supabase/tests/course_distribution_contract.test.sql` — pgTAP tests verifying the Course Distribution schema and immutability rules.
- `supabase/tests/course_distribution_authorization.test.sql` — Security tests ensuring non-admins cannot mutate course distributions.
- `supabase/reconciliation/20261021214512_reconstructed_baseline.sql` — Reconstructed SQL baseline used for local schema validation.
- `supabase/reconciliation/export_sanitized_schedule.sql` — Sanitization script producing anonymized timetable datasets for development.

---

## 🧪 Automated Test Suite (`test/`)

| Test File | Coverage & Purpose |
|---|---|
| `test/academic_model_test.dart` | Tests serialization and equality of course, department, and semester models. |
| `test/academic_service_test.dart` | Tests academic configuration service queries and mock API handling. |
| `test/admin_remediation_layout_test.dart` | Verifies responsive layout integrity and error boundaries across administrative views. |
| `test/admin_web_foundation_test.dart` | Validates Phase 1 admin navigation, route access controls, and shell persistence. |
| `test/auth_callback_policy_test.dart` | Verifies OAuth deep link routing and duplicate callback prevention. |
| `test/auth_invitation_bridge_test.dart` | Tests invitation link parameter extraction and routing. |
| `test/auth_invitation_coordinator_test.dart` | Tests admin invitation acceptance lifecycle and token validation. |
| `test/auth_recovery_remediation_test.dart` | Tests email verification polling, session diagnostics, and password recovery states. |
| `test/clock_time_test.dart` | Verifies 24-hour time calculations, parsing, overlaps, and string conversions. |
| `test/domain_card_motion_test.dart` | Verifies `LiveClassCard` real progress calculation, ticker shutdown, and reduced motion compliance. |
| `test/generation_profile_test.dart` | Validates engine JSON payload assembly from academic settings models. |
| `test/google_sign_in_flow_test.dart` | Mocks Google Sign-In authentication handshakes across web and native platforms. |
| `test/phase_1_navigation_and_shell_test.dart` | Tests role navigation, query-only URL updates, and admin desktop layout under `AppTheme.dark`. |
| `test/phase_2_design_system_and_components_test.dart` | Tests Obsidian Orbit token contrast, `UButton`, `UCard`, `UTextField`, `UChip`, and state presenters. |
| `test/phase_3_onboarding_and_auth_experience_test.dart` | Tests onboarding narrative persistence, responsive auth layouts, password checklists, and lens previews. |
| `test/phase_4_student_teacher_experiences_test.dart` | Tests Phase 4 student/teacher dashboards, weekly routine matrix & swipeable day agenda, and surgical teacher class management at $390\times 844$ and $1440\times 900$. |
| `test/phase_5_admin_scheduling_and_operations_test.dart` | Tests Phase 5 Admin Command Center (4-stage readiness checklist, load breakdown), 1024px collision & 390px ergonomics in Scheduling Workbench across all 5 panes (Default-Gray signaling, Slide-to-Confirm), and live Routine Operations (USegmentedControl, 4-node solver timeline, 3-step post-parse upload pipeline, Service Recovery Paradox notices). |
| `test/phase_6_r1_r16_and_supporting_modules_test.dart` | Tests Phase 6 R1–R16 5-category policy architecture, R15 6/7-slot control, CRUD master-detail screens (R4–R14), and supporting campus/admin module overhauls. |
| `test/phase5_visual_capture_test.dart` | Opt-in visual capture suite rendering the 22-screenshot Phase 5 inspection gallery across Admin Command Center, Scheduling Workbench, and Live Routine Operations. |
| `test/phase35_visual_capture_test.dart` | Opt-in visual capture suite rendering the 76-screenshot Phase 3.5 inspection gallery. |
| `test/publish_gate_test.dart` | Validates atomic timetable publishing gates and preflight verification checks. |
| `test/routine_identity_test.dart` | Tests routine slot matching, section parsing, and combined-section resolution. |
| `test/routine_workbook_parser_test.dart` | Verifies Dart-side Excel routine workbook parsing and error diagnosis. |
| `test/scheduling_workspace_comprehensive_test.dart` | End-to-end tests for the 5-tab Phase 2b Scheduling Workspace, filters, and CP-SAT simulation. |
| `test/scheduling_workspace_route_test.dart` | Tests deep linking and sub-tab state persistence for `/admin/scheduling`. |
| `test/shared_motion_test.dart` | Tests centralized `AppMotion` curves, `UAnimatedSwap`, `UPressableScale`, and `USegmentedControl`. |
| `test/showcase_controller_test.dart` | Tests state transitions and step selection in the routine convergence showcase. |
| `test/showcase_preview_test.dart` | Validates showcase vector layout and responsive element sizing. |
| `test/timetable_settings_test.dart` | Tests solver settings persistence and validation. |
| `test/failures/` | Working-tree artifact folder holding visual regression diff masks, master images, and isolated diffs generated during golden test runs. |

---

## 🛠️ Tooling & Scripts (`tool/`)

- `tool/capture_phase35_screenshots.ps1` — PowerShell script executing the visual capture suite to regenerate all 76 golden screenshots.
- `tool/capture_phase3_all.js` — Playwright headless browser script for capturing live web viewports (historical baseline).
- `tool/phase1_browser_reverification.py` — Python script automating browser verification checks for Phase 1 admin web routes.
- `tool/storage_api_probe.py` — Diagnostics probe verifying Supabase Storage bucket CORS and signed upload policies.
- `tool/task1_invite_checks.py` — Verification script probing admin invitation edge functions.
- `tool/task1_local_checks.py` — Local preflight script testing Python environment readiness and OR-Tools library linkage.
- `tool/generate_app_icon.py` — Generates application icon variations across Android, iOS, and Web dimensions.
- `tool/er_diagram.py` / `dfd0.py` / `dfd1.py` / `activity_diagram.py` / `usecase_diagram.py` — Generates architectural defense diagrams.
- `tool/make_defense_pdf.py` / `make_defense_pptx.py` — Generates presentation slide decks and executive PDF summaries.

---

## 📖 Governance, Skills & Documentation

### Agent Skills (`.agents/skills/`)
- `.agents/skills/react-web-academic-design-system/` — Governs **UniVerse Academic Ledger** Theme v3 OKLCH tokens (`X-Grade Carbon Obsidian` Dark + `Crisp Daylight` Light + `X-Azure`), typography (`Source Serif 4`, `IBM Plex Sans`, `IBM Plex Mono`), opaque-sRGB WCAG AA checks, and Landscape A4 print for `apps/web/`.
- `.agents/skills/react-web-motion-and-craft/` — Governs restrained `motion/react` + CSS animations, `prefers-reduced-motion`, user-controlled public specimen, Course Distribution Studio, and async states in `apps/web/`.
- `.agents/skills/react-admin-backend-contracts/` — Governs Supabase PKCE + invite bridge, FastAPI JWT/CORS (`engine/auth.py`), public `/` isolation, and 4-table Gate A–D persistence truth for `apps/web/`.
- `.agents/skills/ui-backend-policy-correlation/` — Enforces 1:1 correlation between UI controls (`apps/web/` & `lib/`), backend contracts, and Routine Committee rules (`R1`–`R16`, `D1`–`D6`, `CD1`).
- `.agents/skills/universe-implementation/` — Multi-layer implementation coordinator with 5 role references (`web-platform`, `admin-distribution-ui`, `scheduling-cp-sat`, `backend-data-integrity`, `testing-reliability`).
- `.agents/skills/universe-ux-principles/` — Governs product-level UX reasoning, academic task clarity, and the 6 unglamorous states across Mobile and Web.
- `.agents/skills/universe-visual-design-system/` — Governs Flutter Mobile (`lib/`) Obsidian Orbit visual tokens, surface hierarchy, and dark/orange palette restraint.
- `.agents/skills/flutter-interaction-motion/` — Governs Flutter Mobile (`lib/`) micro-interactions, `AppMotion` durations, press compression, and reduced-motion stops.
- `.agents/skills/accessibility-performance/` — Governs Flutter Mobile (`lib/`) WCAG AA contrast ratios, `Semantics`, keyboard focus traversal, and rebuild minimization.
- `.agents/skills/visual-ui-qa/` — Governs dual-client visual review, Playwright/DevTools inspection (`apps/web/`), and widget/golden baselines (`lib/`).

### Documentation Files (`docs/`)
- `docs/backend/README.md` — Authoritative 5-file Backend Architecture & NotebookLM Reference Pack index (`2026-11-24`, zero-secret/zero-PII).
- `docs/backend/01_SUPABASE_DATABASE_AND_SECURITY_ARCHITECTURE.md` — Complete 37-table Supabase schema (Layers 1–3 + `academic_private`), Production vs. Staging diff, Phase 5B RLS/Storage matrix, and Edge Functions (`invite-admin`, `send-push`).
- `docs/backend/02_TIMETABLE_ENGINE_AND_SOLVER_ARCHITECTURE.md` — FastAPI + OR-Tools CP-SAT engine architecture, dual-client JWT/CORS (`engine/auth.py`), R1–R16 + D1–D6 + CD1 rule matrix, and Phase 3B / Gate D roadmap.
- `docs/backend/03_FIREBASE_PUSH_AND_EXTERNAL_INTEGRATIONS.md` — Firebase/FCM push pipeline (`PushService` → `send-push` → FCM HTTP v1), Staging webhook isolation, and Android/iOS/Web OAuth deep-link contracts.
- `docs/backend/04_END_TO_END_DATA_FLOWS_AND_INFRASTRUCTURE.md` — 5 end-to-end Mermaid sequence flows, 5-job GitHub Actions CI + Render + Cloudflare Pages Env A/B topology, and Wave 2 Backend Change Impact Matrix.
- `docs/backend/05_FRONTEND_BACKEND_INTEGRATION_MATRIX.md` — Route-by-route React Web (`apps/web/`) and flow-by-flow Flutter Mobile (`lib/`) backend wiring matrices, cross-client serialization guardrails, and Wave 2 UI touchpoint map.
- `docs/architecture/WEB_ARCHITECTURE_DESIGN_BLUEPRINT.md` — Authoritative target architecture and **UniVerse Academic Ledger** design specification for separated React Web + Flutter Mobile.
- `docs/architecture/WEB_SOURCE_VERIFICATION_REPORT.md` — Evidence-based repository audit reconciling existing `apps/web/`, `lib/`, `engine/`, and `supabase/` reality.
- `docs/architecture/WEB_IMPLEMENTATION_ROADMAP.md` — Phased migration and delivery roadmap through Cutover and Wave 2 (`Phase 4A-2` / `Phase 3B`).
- `docs/architecture/WEB_PHASE_0_COMPATIBILITY_AND_AUDIT_ADDENDUM.md` — Live npm dependency compatibility matrix, Phase 0 `send-push`/avatar/iOS audits, and owner-ready Supabase SQL diagnostic packet.
- `docs/architecture/WEB_SEPARATION_CONTRACT_EXTRACTION.md` — Extracted backend, auth, and routine contracts across Flutter Mobile and React Web.
- `docs/deployment/CLOUDFLARE_PAGES_AND_CUTOVER_RUNBOOK.md` — Deployment runbook for Cloudflare Pages Environment A (Committee Review) and Environment B (Production Cutover).
- `docs/deployment/PHASE_4A1_AND_5B_SQL_PROMOTION_RUNBOOK.md` — Owner-gated SQL promotion runbook for Phase 4A-1 and Phase 5B RLS/storage hardening (`supabase/migrations/20261122160000_phase_5b_rls_and_storage_hardening.sql`).
- `docs/implementation/UniVerse_Implementation_Master_Plan_v1_1.md` — Authoritative master roadmap across core platform/engine/database phases.
- `docs/implementation/web_theme_v3_x_obsidian_and_print_fix.md` — Theme v3 (**X-Grade Carbon Obsidian Dark + Crisp Daylight Light + X-Azure**) and Landscape A4 print verification report.
- `docs/implementation/web_phase_5_hardening_cicd_and_4a1_readiness.md` — Phase 5A (`engine/auth.py` dual-client JWT/CORS), Phase 5B RLS/storage hardening, and 5-job CI/CD readiness report.
- `docs/implementation/web_phase_5_staging_verification_and_ci_fix.md` — Live Staging (`oqwvxplteqtlrhktsplj`) verification report.
- `docs/implementation/web_pre_push_audit_and_doc_cleanup.md` — Pre-push whole-project audit and OpenAPI 401 probe fix report.
- `docs/implementation/repo_knowledge_and_assets_refinement.md` — Knowledge-base, `.agents/` skill ecosystem, and visual asset refinement report + final NotebookLM sync list.
- `docs/timetable-audit-2026-10-20/` — Living committee policy & workbook specs (`02`, `16`, `18`, and CI-verified `task2-backfill-status.json`).
- `docs/screenshots/README.md` — Index of active React Web v3 screenshots (`web_theme_v3_x_obsidian_and_print/`) and active Flutter golden baselines (`phase_3/`, `phase_7/`).
- `docs/archive/` — Historical archive (`agent_skills_history/`, `flutter_ui_history/`, `web_history/`, `timetable_audit_history/`, `screenshots/`) excluded from active agent context.
- `docs/backend-setup.md` — Database setup guide, table inventory, and security rule reference.

---

## 🌐 Standalone React Web Application (`apps/web/`)

> **Status:** Production-ready React Web v1 (**UniVerse Academic Ledger** — Theme v3: X-Grade Carbon Obsidian Dark + Crisp Daylight Light + X-Azure). Phases 0–4B, Theme v3, and Phase 5A/5B/5C-Prep + Staging 5B hardening are complete and verified.

```text
apps/web/
├── .env.example
├── .gitignore
├── index.html
├── package.json
├── package-lock.json
├── playwright.config.ts
├── tsconfig.json
├── tsconfig.app.json
├── tsconfig.node.json
├── vite.config.ts
├── public/
│   ├── _headers                      # Cloudflare Pages CSP & security headers
│   ├── _redirects                    # SPA fallback routing
│   └── theme-init.js                 # Pre-paint anti-FOUC Light/Dark/System bootstrap
├── src/
│   ├── App.tsx
│   ├── main.tsx
│   ├── vite-env.d.ts
│   ├── components/ui/                # Shared Academic Ledger primitives & accessible controls
│   ├── features/
│   │   ├── admin/                    # AdminShell, Dashboard, Rooms, Faculty, Eligibility, Settings, Users, Broadcast, Resources, Profile
│   │   ├── auth/                     # AuthProvider, PKCE + invite hash bridge, Landing, Login, Forgot/Reset Password, AccessRequired
│   │   ├── onboarding/               # Public AcademicLedgerPreview & illustrative schedule fixtures
│   │   ├── routine/                  # Track 1 Operational Console: 2D Matrix, Committee Day Sheet (Landscape A4 print), Manage, Generate, Upload
│   │   └── scheduling/               # Track 2 Committee Scheduling Workbench (Gates A–D, Course Distribution Studio, R1–R16 Policy, Review)
│   ├── services/                     # supabase.ts, engineHealth.ts
│   ├── shared/
│   │   ├── components/               # LedgerMark, EngineHealthBadge, ThemeSwitcher
│   │   └── theme/                    # ThemeProvider (Light / Dark / System)
│   └── styles/
│       ├── app.css
│       └── tokens.css                # 4-layer Carbon-Obsidian + Crisp Daylight + 10-step X-Azure OKLCH tokens
└── tests/
    ├── unit/                         # Vitest unit & contract suites
    └── e2e/                          # Playwright browser & print-layout suites
```
