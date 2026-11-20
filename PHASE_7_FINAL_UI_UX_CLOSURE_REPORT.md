# Phase 7 final UI/UX closure - 9 November 2026

The requested UI work and the follow-up local readiness fixes are implemented. The full repository suite now passes: 325 tests passed, 1 intentionally skipped, 0 failed. Device sign-in and hosted workflows remain separate acceptance checks.

## Changes and contract correlation

| Surface | State/model and existing backend contract | Boundary |
|---|---|---|
| Broadcast history search/audience | `BroadcastController.recent`, `NotificationItem.title/body/targetRole`; existing notification fetch/delete service | Client filtering; deletion retains existing service/auth policy |
| Resource filters/upload | `ResourceAdminController.all/category/semester`, `Resource.category/semester`; existing resources create/delete/storage service | Client filters; existing upload and student-notification behavior preserved |
| Registration | `WhitelistController.load/invite/addTeacher/remove`, `WhitelistEntry`; existing `AdminService` whitelist and invitation methods | Governance clarified; authorization and account deletion policy unchanged |
| R15 faculty/room matrices | `TimetableSettings.periods` via `TimetableConfigService.fetchSettings`; existing session maps for R4/R5/R8 and R10/R11 | Grid sizing reads configuration; editing remains session-only, explicitly labeled |
| Sibling tabs | Existing GoRouter route URLs | Selection follows route; no route names or guards changed |

The four secondary screens accept externally owned controllers and dispose only controllers they create. Existing services resolve Supabase lazily. They suppress local app bars inside `DesktopShellScope` and use bounded workspaces/top-lit surfaces. Broadcast and resource histories have live match counts and 1px row dividers. Adaptive deletion confirmations reuse the shared overlay. Resource upload retains all existing validation, file/link and notification behavior.

`StudentDashboardScreen` and `TeacherDashboardScreen` no longer attach the duplicate end drawer or drawer button. The Explore FAB was owned by `AppShell`, so its home-route attachment was removed there. Shared drawer/FAB widget files remain intact. Bottom navigation, account actions, Campus lookup and back-routing logic remain present.

## Verification evidence

- `flutter analyze --no-pub`: 0 issues.
- Phase 7 targeted suite: 16/16 passed.
- Combined Phase 4-7 suite: 40/40 passed. Final run including `scheduling_workspace_comprehensive_test.dart`: 50/50 passed.
- `git diff --check`: clean; Git emits existing LF/CRLF conversion warnings.
- Final full `flutter test --no-pub`: **325 passed, 1 skipped, 0 failed**. This includes the versioned golden comparisons, asynchronous query-change regressions, mobile 1.3x campus layouts and the new secondary-teacher detail regression.
- Screenshots: eight local fixture renders in `docs/screenshots/phase_7/`, covering the four screens at 390x844 and 1440x900. These are widget renders, not live authenticated browser evidence. Mobile and desktop captures were opened for inspection. Font rendering in some inherited Material label surfaces is a harness limitation; screenshots alone do not establish typography acceptance.

## Follow-up investigation and fixes

All nine failures identified in the earlier full run were investigated and resolved:

- **Room/teacher mobile cards:** Room identifier and provenance competed for one unbounded row. Room identifiers now have a bounded, ellipsized text area; published-routine provenance sits below the header on both campus card types. Both campus lookup screens pass at 390px, 1.3x mobile text scaling, and 1440px.
- **Teacher detail correctness:** Read-only `TeacherDetailView` now uses `RoutineEntry.matchesTeacher`, retaining a shared meeting when the selected teacher is a secondary teacher. A regression test verifies this behavior.
- **Outdated navigation and timetable assertions:** Tests now target `RoomDetailView` / `TeacherDetailView`, where retained state lives, and assert current labels, typed schedule slots and actual dropdown controls. Async stale-response rejection, collision preservation, shared-teacher rendering, room normalization and filters remain asserted.
- **Corrupted policy labels:** Repaired the malformed dash characters in the configuration pane's R1-R16 and weekday labels.
- **Golden baseline reconciliation:** All 22 historical Phase 5 PNGs remain unchanged. The capture test now compares against `docs/screenshots/phase_7/regression/`. Nine scheduling captures differ due to the implemented Phase 6/7 revision ribbon, rule configuration, readiness, generation and review presentations; all nine were opened and inspected. The other 13 are byte-identical to the historical captures. A subsequent full test run passed with normal comparisons, without `--update-goldens`. Each capture now also asserts that Flutter reported no layout/runtime exception.

Final logs are local ignored artifacts: `.dart_tool/phone_readiness_full_test.log`, `.dart_tool/phone_readiness_analyze.log`, and `.dart_tool/phone_readiness_diff_check.log`.

## Phone and web preview configuration

The original `dart_defines.json` points `TIMETABLE_BASE_URL` at `http://10.0.2.2:8000`, an Android-emulator address. It was preserved. A separate ignored `.dart_tool/device_preview_defines.json` copies its values and uses the repository-default hosted engine URL instead. A read-only GET of `https://universe-timetable-engine.onrender.com/` returned HTTP 200 with the expected `ok` and service identity. This establishes process health only; no solve or publication was requested. The server's health route is `/`, not `/health`.

Build and browser-smoke results are recorded below after completion.

## Acceptance boundary

No hosted services, migrations, OAuth/email configuration, solver, route guards or live scheduling capability gates were changed. The only endpoint override is in the local ignored preview-build input. `isLiveWorkspaceOperational == false` remains protected. No production mutations, commits or pushes were performed. Browser keyboard traversal, assistive-technology acceptance and DevTools profiling were not executed; widget Escape tests are the keyboard evidence for this pass.
