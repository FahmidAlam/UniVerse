# Phase 1 information architecture and navigation

Date: 7 November 2026. Reconciled specification following the Product Owner's confirmed conditional approvals. Historical implementation and verification records remain below; they do not establish that the working tree already matches this updated target. No code or theme-token changes are authorized by this reconciliation.

## Implementation plan

Historical completed-pass record only. In particular, its drawer/FAB removal and fixed-width sidebar implementation are superseded as target decisions by the conditions and deferred ledger below; the checked items are not renewed approval of those choices.

- [x] Pin role/mobile navigation and adaptive-shell regressions before implementation.
- [x] Add URI builders and shared Campus route factories; move lists and details into AppShell, with URL fallback and missing-identifier recovery.
- [x] Implement five-tab navigation, admin More directory, Campus switcher, account access, and the 220 px student/teacher desktop sidebar using existing tokens.
- [x] Preserve mobile back registry and two-second exit policy; remove duplicate dashboard drawers/FAB.
- [x] Unify desktop header scope and synchronize routine query tabs without replacing IndexedStack children.
- [x] Verify touched-file analysis, navigation/auth/workspace regression tests and whitespace; record evidence and limitations below.

The reconciled target uses persistent role navigation with content-aware Compact (`<768px`), Medium (`768?1099px`), and Expanded (`>=1100px`) tiers. Do not force a desktop sidebar, multi-column workspace, or Weekly Matrix into insufficient space at `800px`. Choose composition from usable content width measured by `LayoutBuilder` after deducting sidebar/rail width. Admin More continues to expose existing guarded tools; detail identifiers remain encoded in URLs with extra retained for compatibility.

## Responsive rules and routine views

Use the three tiers as initial content-aware ranges, not rigid global viewport switches. A wide browser with a persistent sidebar can still have only Medium or Compact space for its child workspace. Deduct the actual navigation width (including the existing `250px` admin sidebar or `220px` student/teacher sidebar where used) before choosing child layouts. A narrower rail may replace a full sidebar when content needs the space.

Medium content uses a single-column workspace. Expanded content can use two columns only when both remain comfortable. Weekly Matrix becomes the default routine view only when usable width supports readable cells; Day List remains an easy toggle on all desktop/medium widths, and a suitable compact view. Do not equate a viewport reaching a threshold with proof that its child matrix or inspector fits.

## Role and platform navigation matrix

The following is the approved target, not a claim that the current code has been aligned.

| Role/platform | Primary navigation | Secondary and contextual access |
|---|---|---|
| Mobile Student (Compact `<768px`) | Today `/student/dashboard`; Routine `/student/routine`; Campus `/rooms`; Resources `/student/resources`; Alerts `/notifications` | Campus exposes Room Availability and Find Teacher `/find-teacher`, including detail descendants. Account `/profile` and back behavior remain reachable. **AppDrawer and ExploreFabMenu: Temporarily Retained** until replacements are reviewed. |
| Mobile Teacher (Compact `<768px`) | Today `/teacher/dashboard`; Teaching `/teacher/routine`; Campus `/rooms`; Class Tools `/teacher/manage-classes`; Alerts `/notifications` | Campus switcher, detail navigation, and account access remain. **AppDrawer and ExploreFabMenu: Temporarily Retained** until replacements are reviewed. |
| Mobile Admin (Compact `<768px`) | Overview `/admin/dashboard`; Routine `/admin/routine` (Routine Operations); Workbench `/admin/scheduling` (Scheduling Workbench ? Preview); Broadcast `/admin/broadcast`; More | More retains Users `/admin/users`, Registration `/admin/registration`, Faculty `/admin/timetable/faculty`, Rooms `/admin/timetable/rooms`, Course Eligibility `/admin/timetable/course-eligibility`, Settings `/admin/timetable/settings`, Resources `/admin/resources`, Resource Library `/admin/resources/library`, Routine Preview `/admin/timetable/grid`, Broadcast History `/admin/broadcast/history`, Campus Lookup `/rooms`, Profile `/profile`. |
| Desktop Student (Medium and Expanded) | Adaptive rail/sidebar: Today, Routine, Campus Lookup (Room Availability `/rooms` and Find Teacher `/find-teacher`), Resources, Alerts `/notifications` | Single column on Medium; two-column workspace on Expanded only when usable width supports it. Weekly Matrix default when it fits, with easy Day List toggle. Account and Sign Out remain reachable. |
| Desktop Teacher (Medium and Expanded) | Adaptive rail/sidebar: Today `/teacher/dashboard`, Teaching `/teacher/routine`, Campus Lookup, Class Tools `/teacher/manage-classes`, Alerts `/notifications` | Weekly Matrix default only when it fits, with Day List toggle. Expanded: contextual right-hand Class Action inspector; Medium/Compact: modal/sheet. Account and Sign Out remain reachable. |
| Desktop Administrator (`AdminDesktopShell`) | Separate **Routine Operations** `/admin/routine` with `?tab=manage`, `?tab=generate`, `?tab=upload`, and **Scheduling Workbench ? Preview** `/admin/scheduling` | Existing configuration, broadcast, users, resources, profile, and sign-out remain accessible. Measure child workspace width after deducting the actual `250px`/`220px` sidebar or adaptive rail; never force desktop content merely because viewport width reaches `800px`. |

Alerts retain unread badges. Campus exposes both existing lookup routes without breaking direct navigation. Profile remains inside the authenticated shell. Retain AppDrawer and ExploreFabMenu temporarily until **every useful destination/action** has a reviewed and approved replacement; preserving account and back access alone is not sufficient to authorize removal. Existing auth redirects, operation epochs, role guards, and local-back priority remain protected.

## Structural wireframes for the five required contexts

These wireframes express layout intent; exact tokens and width allocations remain subject to representative-screen review.

### Mobile Student ? Compact

```text
[Page heading                         Account]
[Current task / routine / Campus lookup       ]
[AppDrawer: Temporarily Retained              ]
[ExploreFabMenu: Temporarily Retained         ]
[Today | Routine | Campus | Resources | Alerts]
Campus -> Room Availability / Find Teacher
```

### Mobile Teacher ? Compact

```text
[Page heading                         Account]
[Teaching / Campus / contextual Class Tools   ]
[AppDrawer: Temporarily Retained              ]
[ExploreFabMenu: Temporarily Retained         ]
[Today | Teaching | Campus | Class Tools | Alerts]
```

### Desktop Student ? Medium and Expanded

```text
Medium:   [Adaptive rail] [Single-column workspace]
Expanded: [Sidebar] [Routine / Weekly Matrix] [Relevant context]
          [Account] [Weekly Matrix <-> Day List toggle        ]
```

The Expanded two-column arrangement and Weekly Matrix default require sufficient usable content width; otherwise keep a single column and Day List.

### Desktop Teacher ? Medium and Expanded

```text
[Adaptive rail/sidebar: Today / Teaching / Campus Lookup /
 Class Tools / Alerts / Account]
Medium:   [Single-column teaching workspace] -> action modal/sheet
Expanded: [Teaching matrix + Day List toggle] [Class Action inspector]
Compact:  [Focused teaching view]             -> action modal/sheet
```

### Desktop Administrator ? AdminDesktopShell

```text
[Sidebar / rail]                    [Header + page actions]
 Routine Operations                 [Usable child content width]
   Manage / Generate / Upload        [Compact / Medium / Expanded]
 Scheduling Workbench ? Preview      [Live capability locks or]
 Baseline tools / Account            [explicit Design Preview]
```

Deduct the actual `250px`/`220px` sidebar or rail before choosing child columns, matrices, and inspectors. Routine Operations preserves the real Python FastAPI + CP-SAT path at `/admin/routine?tab=generate`; the separate workbench remains preview-only and fail-closed in Live mode under Phase 0 Gates A?D.

## Route durability contract

- Room navigation uses `Uri` encoding and both `/rooms/detail?room=...` and legacy string extra. A nonempty string extra takes precedence; otherwise the URL supplies the identity.
- Faculty navigation uses `/find-teacher/detail?code=...&name=...&dept=...&desig=...` alongside TeacherDetailArgs. Typed, nonempty extra takes precedence; otherwise code is required from the URL, name defaults to code, and department/designation are optional. The current directory model only supplies code/name; absent metadata is not invented.
- Empty/missing identifiers show an explicit recovery state with a working directory button, without loading all schedules. Wrong extra types fall back safely.
- Detail screens reload when GoRouter retains their state across query-only identity changes. Read epochs ignore obsolete responses; missing-to-valid identity transitions reload correctly. The optional routineLoader is a screen-level reader seam; backend service contracts are unchanged.
- `/admin/routine` and unknown tab values select Manage. `?tab=manage`, `?tab=generate`, and `?tab=upload` select exactly one corresponding sidebar destination. Local segmented changes update the URL. The existing IndexedStack and its three child forms remain intact.
- Campus list/detail routes now live inside AppShell. Mobile back still unwinds registered local folder/selection state first, then pushed details/directory recovery, then role home, then requires a second back within two seconds to exit.
- DesktopShellScope makes embedded UAppBars compact page-action strips; subtitles and duplicate brand chrome are suppressed, while contextual back/selection controls remain. Desktop shell headers own account access; mobile UAppBars and the workbench custom header expose the account action.

## Changed symbols and inline comments

All semantic navigation changes use `// PHASE 1:`. Paths and line numbers below refer to this working tree.

- `lib/shared/widgets/app_bottom_nav.dart`: lines 34, 102, 126.
- `lib/shared/widgets/campus_lookup_switcher.dart`: lines 6.
- `lib/shared/widgets/desktop_shell_scope.dart`: lines 6, 20.
- `lib/shared/widgets/role_desktop_shell.dart`: lines 9, 85, 156.
- `lib/shared/widgets/u_app_bar.dart`: lines 1, 32, 52, 69.
- `lib/shared/widgets/u_bottom_nav.dart`: lines 50.
- `lib/features/teacher/screens/teacher_dashboard_screen.dart`: lines 85, 87.
- `lib/features/rooms/screens/rooms_screen.dart`: lines 1, 47, 65.
- `lib/features/rooms/screens/room_detail_screen.dart`: lines 11, 29, 39, 47, 51, 64, 71, 74, 84, 103.
- `lib/features/rooms/widgets/room_status_card.dart`: lines 128.
- `lib/features/find_teacher/screens/find_teacher_screen.dart`: lines 1, 51, 69.
- `lib/features/find_teacher/screens/teacher_detail_screen.dart`: lines 11, 30, 40, 58, 61, 79, 87, 91, 104, 111, 114, 121, 140.
- `lib/features/find_teacher/widgets/teacher_location_card.dart`: lines 187.
- `lib/features/dashboard/screens/student_dashboard_screen.dart`: lines 82, 84.
- `lib/features/admin/screens/admin_dashboard_screen.dart`: lines 56, 58.
- `lib/features/admin/screens/admin_routine_screen.dart`: lines 30, 113, 183.
- `lib/features/admin/widgets/admin_desktop_shell.dart`: lines 1, 62, 170, 275, 281, 428, 435, 489, 535, 544.
- `lib/features/admin/scheduling/widgets/scheduling_header_bar.dart`: lines 1, 130.
- `lib/core/router/app_router.dart`: lines 143, 258.
- `lib/core/router/app_shell.dart`: lines 13, 84, 156, 181, 184.
- `lib/core/router/route_names.dart`: lines 50, 65.
- `test/admin_remediation_layout_test.dart`: lines 118, 129.
- `test/admin_web_foundation_test.dart`: lines 223, 267.
- `test/phase_1_navigation_and_shell_test.dart`: lines 1, 49, 169, 265, 322, 368.

Key symbols: AppRouter.campusRoutes; RouteNames room/faculty URL builders and routineTab; AppShell responsive composition and back handler; AppBottomNav destinationsFor/selectedIndexFor/adminTools; UBottomNav semantic selection; DesktopShellScope/ProfileAccountAction; RoleDesktopShell; CampusLookupSwitcher; UAppBar.build; AdminDesktopShell tab/nav/header builders; AdminRoutineScreen dependency/tab handling; both detail screens initState/didUpdateWidget/load; Campus cards' detail navigation; three dashboard app bars; SchedulingHeaderBar account action.

## Verification results

Local evidence only, 7 November 2026:

1. Broad regression command:

```powershell
flutter test test/phase_1_navigation_and_shell_test.dart test/admin_web_foundation_test.dart test/admin_remediation_layout_test.dart test/scheduling_workspace_comprehensive_test.dart test/scheduling_workspace_route_test.dart test/auth_recovery_remediation_test.dart test/auth_callback_policy_test.dart --reporter expanded
```

Result: `00:08 +91: All tests passed!` This preceded the final detail-state reload extension.

2. After read-only review identified query-state reuse, the detail reload/epoch fix and two corresponding regressions were added:

```powershell
flutter test test/phase_1_navigation_and_shell_test.dart --reporter expanded
```

Final result: `00:06 +31: All tests passed!` This covers URL-only route arguments, missing-ID recovery buttons, encoding, retained-state query changes, stale response rejection, exact admin tab/workbench selection, role/recovery guards, More navigation, account navigation, local-back/home/double-back ordering, and role shells at 390, 1024, 1280 and 1440px. Earlier existing admin tests also exercise the 800px breakpoint. The broader suites were not repeated after this focused, passing extension.

3. Final `flutter analyze --no-pub`: `No issues found! (ran in 42.2s)`, exit 0. Final `git diff --check`: no output, exit 0.

Review corrections: the initial desktop sidebar needed a Material surface for ListTile selection painting; legacy tests were updated from the obsolete parent-always-selected behavior to exact tab selection. A read-only reviewer identified detail state reuse; the final tests verify the same State instance reloads and an older request cannot overwrite a newer identity.

A temporary synthetic shell screenshot probe produced `build/phase_1_navigation_evidence/student_390.png`, which was inspected, but the multi-viewport capture timed out. Its temporary test was removed. The image uses a substitute local font/theme and lacks loaded icon fonts, so it is not production visual acceptance evidence. No completed browser walkthrough, browser-refresh network test, Android device test, or hosted data verification is claimed. Valid-detail route tests verify recovered identity and recoverable service failure without a hosted connection; injected reader tests verify successful schedule replacement locally.

All pre-existing Phase 0 changes remain. No hosted writes, migrations, CLI operations, auth-controller changes, theme-token replacement, commits, pushes, or iOS work were performed. Stop here; redesign Phase 2 remains unstarted.

## Phase 1 Code Reconciliation Ledger (Completed 7 November 2026)

The approved alignment pass is complete. Historical evidence above remains preserved; the entries below record the implemented reconciliation and its focused local verification.

| Reconciled scope | Implemented alignment |
|---|---|
| Temporary mobile discovery | Restored `AppDrawer` and `ExploreFabMenu` on student/teacher dashboards. The FAB scales/fades while the end drawer is open; profile access, direct routes, and existing back ordering remain intact. |
| Teacher navigation | Mobile is `Today | Teaching | Campus | Class Tools | Alerts`; desktop presents Teaching, Campus Lookup (Room Availability and Find Teacher), Class Tools, and Alerts while preserving existing routes. |
| Content-aware tiers and routine view | `AppShell` uses Compact `<768px`, Medium `768-1099px`, and Expanded `>=1100px`; Medium uses a 96px role rail or 220px admin sidebar, Expanded retains 220px/250px sidebars. `RoutineScreen` chooses Weekly Matrix only at `>=860px` usable content width and retains an explicit Day List switcher. |
| Admin destination naming | `/admin/routine` is **Routine Operations** with existing Manage/Generate/Upload query tabs; `/admin/scheduling` is **Scheduling Workbench · Preview**. |
| Preview authorization | `kEnableUnauthenticatedSchedulingPreview` permits the unauthenticated preview only in debug or with `ENABLE_SCHEDULING_PREVIEW_ROUTE`; otherwise `/preview/scheduling` redirects unauthenticated users to Login and non-admin users to their home. |

Focused verification on 7 November 2026: `flutter test test/phase_1_navigation_and_shell_test.dart --no-pub` (`+32: All tests passed`), `flutter analyze --no-pub` (no issues), and `git diff --check` (clean). Dashboard/routine constructors currently eagerly construct Supabase-backed services, so direct isolated widget tests for those screens remain unsuitable without a separate dependency-injection pass; shell-tier, route-gate, tab-label, and admin-selection coverage remains isolated.

The pre-auth onboarding story and auth compositions are specified in the Phase 0 addendum for the dedicated redesign Phase 3 code pass. Exact visual tokens remain provisional until representative-screen review. No capability is unlocked by this reconciliation, prior test totals, or a phase-completion report.

### Reconciliation verification boundary

Only the two Phase 0/Phase 1 Markdown specification documents are edited in this task. Historical test outputs and line-number ledgers above are retained unchanged; they describe the previous code, not acceptance of these revised targets. No Flutter tests, code changes, hosted actions, migrations, or skill changes are part of this documentation-only reconciliation.
