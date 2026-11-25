# Implementation Report: Browser-Based Admin Foundation (Phase 1)

**Date:** 5 November 2026  
**Milestone:** Phase 1 — Browser-Based Admin Foundation  
**Branch:** `feature/admin-web-extension`  
**Engineer / Author:** Antigravity (Flutter Engineer under established Codex Architecture)  
**Primary Architectural Authority:** Codex  

---

> Acceptance correction (5 November 2026): this is the original author handoff. The independent review and remediation status in [report 21](21-browser-admin-independent-review.md) govern acceptance. Compilation and VM tests do not establish live OAuth, email, RLS or physical mobile compatibility. Phase 2a remains conditional.

## 1. Executive Summary

Phase 1 adds browser compilation, platform file adapters and desktop administrator routes/layouts within the existing UniVerse Flutter application. It does not redesign the backend or scheduling domain.

Dashboard, generation, upload, routine management, faculty, rooms, settings, eligibility, broadcasts and user-management screens have desktop entry points. This is implementation scope, not a claim that every workflow has passed browser or backend integration acceptance. Existing mobile code paths remain; physical Android/iOS behavior is unverified. Report 21 records the acceptance gate and demonstrated workflows.

---

## 2. Implemented Browser Functionality

### A. Flutter Web Compatibility & Build
- Resolved compilation for Flutter Web (`flutter build web --dart-define-from-file=dart_defines.json` builds in release mode with zero errors).
- Decoupled native-only runtime dependencies (`dart:io`, `path_provider`, `open_filex`) behind a platform boundary (`FileDownloader`).
- Preserved Flutter's feature-first structure (`ChangeNotifier`, `GoRouter`, `Supabase`, and existing theme tokens).

### B. Browser Authentication & Callbacks
- Refactored `AuthService` so that OAuth (Google) and email verification / password reset workflows pass browser-compatible redirects (explicit approved callback URLs from `AUTH_WEB_CALLBACK_URLS`; ordinary sign-in remains PKCE) rather than the native custom deep link (`com.example.universe://`).
- Enhanced `AuthController.initialize()` to automatically resolve post-login whitelist auto-provisioning for whitelisted teachers and admins on web login who do not yet have a profile row created.
- Retained GoRouter role guards: direct URL navigation to `/admin/*` routes strictly checks authentication and redirects non-admin users to their appropriate dashboard.

### C. Desktop-First Admin Interface (`AdminDesktopShell`)
- Implemented a persistent administrative sidebar on screens with width $\ge 800\text{ px}$:
  - UniVerse brand mark and "Admin Portal" badge.
  - Categorized navigation links: Timetable Engine (Dashboard, Routine Workbench, Routine Preview), Configuration (Faculty & Day-offs, Room Pools, Timetable Settings, Course Eligibility), Communication & Users (Campus Broadcast, User Whitelist, Academic Resources, Admin Profile).
  - Current administrator profile badge and quick sign-out action with confirmation dialog.
- Implemented an administrative top header:
  - Contextual breadcrumbs and section titles.
  - Bounded HTTP engine-health status with checking, connected, unavailable and unknown states. A healthy process does not guarantee solver feasibility.
  - Quick action shortcut ("Generate Routine").
- Preserved existing mobile layout on narrow viewports ($< 800\text{ px}$) and for student/teacher actors.

### D. Responsive Admin Screens & Features
- **Admin Dashboard:** Stats grid uses remaining content width, text scale and a minimum card height and quick action cards (3-4 columns on desktop with links to all administrative functions).
- **Routine Management:** Segmented view ("Manage", "Generate", "Upload") constrained to a centered 480 px bar on desktop; routine entries render in a 2-column grid on desktop.
- **Generate Timetable & Upload Routine:** Centered desktop workbench containers (max-width 1000 px) with stats grids sized against available content width and text scale.
- **Room Management:** Room pools lay out in side-by-side 2-column cards on desktop.
- **Faculty Management:** Teacher listings render in a 2-column grid on desktop screens.
- **Timetable Preview Grid:** Added desktop-scaled cell dimensions (160 px slot width, 80 px cohort width, 84 px height) for comfortable legibility, with a dedicated empty-state action button directing admins back to the generator if refreshed without cached rows.

### E. Browser File Handling
- Workbook file selection: Reuses `FilePicker.platform.pickFiles(withData: true)` which operates directly on in-memory bytes on web.
- Workbook download: On web, `TimetableGenController.downloadAndOpen()` triggers an automatic browser file download (`CSE_Routine_<semester>.xlsx`) using an HTML anchor element without calling native file I/O or `OpenFilex`.
- Private draft export: On web, `TimetableGenController.saveDraft()` triggers an automatic browser download of `routine_draft_<timestamp>.json`.
- Native file paths retain document/temp saves and `OpenFilex`. VM regression evidence does not replace physical-device file-picker/opening checks.

---

## 3. Files Created and Modified

### Files Created:
1. `lib/core/platform/file_downloader_interface.dart` — Abstract interface for byte and string file downloading.
2. `lib/core/platform/file_downloader_stub.dart` — Fallback stub for unsupported environments.
3. `lib/core/platform/file_downloader_io.dart` — Native implementation using `dart:io`, `path_provider`, and `open_filex`.
4. `lib/core/platform/file_downloader_web.dart` — Web implementation using `dart:html` blob object URLs and click triggers.
5. `lib/core/platform/file_downloader.dart` — Conditional export dispatcher based on `dart.library.html` and `dart.library.io`.
6. `lib/features/admin/widgets/admin_desktop_shell.dart` — Desktop admin shell with persistent navigation sidebar and header.
7. `test/admin_web_foundation_test.dart` — Unit and widget test suite covering platform file downloading, responsive shell switching, timetable grid rendering, and auth provisioning.
8. `docs/implementation/20-browser-admin-foundation.md` — This implementation report.

### Files Modified:
1. `lib/core/router/app_shell.dart` — Added desktop breakpoint detection; renders `AdminDesktopShell` for admin on desktop and standard `AppBottomNav` for mobile/non-admin. Added safe GoRouterState extraction.
2. `lib/core/router/app_router.dart` — Brought administrative screens (`manageRooms`, `manageFaculty`, `timetableSettings`, `manageCourseEligibility`, `timetableGrid`, `manageResources`, `resourceLibrary`, `broadcastHistory`, `adminRegistration`) inside `ShellRoute` so they render inside the desktop workbench on wide screens while hiding bottom nav on mobile.
3. `lib/features/admin/controllers/timetable_gen_controller.dart` — Replaced direct `dart:io` file writing with `getPlatformFileDownloader()` for web-safe XLSX downloads and JSON draft exports.
4. `lib/features/auth/services/auth_service.dart` — Replaced hardcoded native deep links with web-safe conditional redirects on OAuth and email verification/reset.
5. `lib/features/auth/controllers/auth_controller.dart` — Added post-login whitelist check on initialize when user profile is initially null; added safety catch around push token registration.
6. `lib/features/admin/screens/admin_dashboard_screen.dart` — Responsive 4-column stats grid and desktop quick action grid.
7. `lib/features/admin/screens/admin_routine_screen.dart` — Centered max-width desktop segmented tab control.
8. `lib/features/admin/screens/generate_timetable_screen.dart` — Constrained max-width container and 4-column desktop stats grid.
9. `lib/features/admin/screens/upload_routine_screen.dart` — Constrained max-width container and 4-column desktop stats grid.
10. `lib/features/admin/screens/routine_management_screen.dart` — 2-column desktop grid for scheduled routine entries.
11. `lib/features/admin/screens/manage_rooms_screen.dart` — 2-column desktop card layout for room pools.
12. `lib/features/admin/screens/manage_faculty_screen.dart` — 2-column desktop grid for faculty members.
13. `lib/features/admin/screens/timetable_grid_screen.dart` — Desktop cell sizing, layout padding, and empty-state action button.

---

## 4. Components and Services Reused

- **State Management & Controllers:** Preserved `TimetableGenController`, `RoutineUploadController`, `RoutineAdminController`, `TimetableRoomsController`, `TimetableFacultyController`, `TimetableSettingsController`, `CourseEligibilityController`, `AdminDashboardController`, `UserAdminController`, `BroadcastAdminController`, and `ResourceAdminController`. No controllers were rewritten or replaced.
- **Backend Services:** Reused `TimetableEngineService`, `TimetableConfigService`, `RoutineService`, `AuthService`, and Supabase RPCs without alteration.
- **Design Tokens & Theme:** Applied `AppColors`, `AppTextStyles`, `AppSpacing`, `AppTheme.dark`, `PhosphorIconsRegular`, `UCard`, `UButton`, `UChip`, and `UEmptyState`.
- **Navigation:** Maintained `GoRouter` declarative routing, `RouteNames`, and `AppBottomNav` for mobile.

---

## 5. Technical Decisions Made

1. **Conditional Platform File Handling:** Rather than pulling in heavyweight third-party download plugins, we introduced a light conditional abstraction (`file_downloader.dart`). Native code preserves file writing and opening; web uses standard HTML Blob object URLs and anchor click downloads.
2. **Responsive Shell Selection in `AppShell`:** Instead of maintaining a separate router or entrypoint, `AppShell` dynamically determines whether to render `AdminDesktopShell` or mobile `AppShell` based on `role == 'admin' && constraints.maxWidth >= 800`. This preserves a single source of truth for routing.
3. **Consolidation of Admin Routes under `ShellRoute`:** Secondary admin screens (like `/admin/rooms` and `/admin/settings`) are now part of `ShellRoute`. On desktop, they display inside the admin workbench. On mobile, `isPrimaryTab` checks hide the bottom navigation bar so secondary screens remain full-page views.
4. **Whitelist Post-Login Fallback:** When a whitelisted admin signs in via web OAuth for the first time, Supabase creates the Auth session before a Postgres profile row exists. `AuthController.initialize()` now triggers `handlePostLogin()`, automatically creating the admin profile and granting administrative access.

---

## 6. Verification and Test Results

### 1. Flutter Static Analysis
```powershell
flutter analyze
```
**Result:** Exit 0, **No issues found!**

### 2. Full Flutter Test Suite
```powershell
flutter test --no-pub
```
**Result:** Exit 0, **123 tests passed** (including 8 new tests in `test/admin_web_foundation_test.dart` and 115 pre-existing regression tests). Zero regressions.

### 3. Flutter Web Release Build
```powershell
flutter build web --dart-define-from-file=dart_defines.json
```
**Result:** Exit 0, **Built `build\web` successfully** (tree-shaken icons, release compilation completed in 117.9s).

---

## 7. Known Limitations for Later Phases

1. **Ephemeral Preview State on Browser Refresh:** `TimetableGridScreen` receives `TimetablePreview` through `GoRouterState.extra`. In a browser, hard-refreshing the URL clears `extra`, causing the screen to display the empty state. Phase 2 (Course Distribution & Revision-bound drafts) should introduce persistent draft storage (indexed by draft ID or URL query parameter) so review links can be shared and refreshed.
2. **Academic Calendar & Scoped Allocation:** Existing settings continue to use singleton `timetable_settings` ID 1. Multi-department academic terms and semester-scoped room pools remain future work (Phase 4+).
3. **Editable Course Distribution (CD1):** Phase 1 intentionally does NOT alter the ingest format or implement the editable distribution table. That is scheduled for Phase 2.

---

## 8. Git Status and Diff Summary

### Status at Handoff:
- Branch: `feature/admin-web-extension`
- Untracked files preserved: All pre-existing untracked files (`.github/workflows/validate.yml`, `COMPLETE_PROJECT_AUDIT_REPORT.md`, `OFFLINE_ARCHITECTURE_AUDIT.md`, `PROJECT_STRUCTURE.md`, `supabase/config.toml`, `supabase/migrations/20261022140809_academic_catalog.sql`, `supabase/reconciliation/`, `supabase/tests/`, `tool/test_solve_with_fall_profile.py`, `tool/verify_fall_generated.py`, `workbook/`).
- Pre-existing deletion preserved: `docs/defense/10_Admin_and_Timetable_Engine.pdf`.
- No files were staged, committed, or pushed.
- Production data and remote deployments were untouched.

---

## 9. Handoff to Codex (Next Phase Recommendations)

### What is Completed:
- Browser compilation and runtime file downloading/draft exporting.
- Desktop administrator workbench (`AdminDesktopShell`) with persistent sidebar, header, and responsive layouts across all admin screens.
- Explicit callback validation is implemented; actual provider/email delivery and deployed allowlist configuration remain integration acceptance requirements.
- 123/123 tests passing; zero analyzer warnings.

### Recommended Next Actions for Codex:
1. **Phase 2a (Accepted Distribution Contract), only after report 21 passes:** Define the versioned accepted distribution schema and normalization contract (CD1) as specified in decision record 18, ensuring source corrections preserve immutable originals.
2. **Phase 2b (Editable Course Distribution UI):** Build the desktop-first Course Distribution page inside the newly established `AdminDesktopShell`.
3. **Phase 3 (Shared Validation & Safe Publication):** Enforce server-authoritative validation before publication.


## 10. Remediation verification correction — 5 November 2026

The original 123-test/build claims above are historical author results. Final remediation verification is recorded in [report 21](21-browser-admin-independent-review.md): static analysis clean, 179 Flutter tests pass, synthetic web release build passes, and actual Chrome/real local engine generation, preview, exact-byte XLSX/private JSON export and SDK callback transport were exercised. Browser exports made no backend writes in the private run. Native callback metadata and public URI handling are corrected, with the already installed app_links6.4.1 declared directly; package versions were not upgraded.

Phase 1 is still **not accepted** because genuine OAuth/email delivery, deployed/disposable RLS denials and physical mobile flows remain unverified. Synthetic REST is not Supabase authorization. No Phase 2a work may be inferred from the successful build or tests, and refreshable/shareable preview persistence remains unimplemented.
