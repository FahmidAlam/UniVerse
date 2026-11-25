# Phase 0 redesign baseline and decisions

Date: 7 November 2026 (Asia/Dhaka). Scope: the user-approved redesign Phase 0 only. Redesign phase numbering is distinct from the backend implementation roadmap.

## Core value and routine lifecycle

UniVerse's central product differentiator is its **automatic university routine-generation engine**. Course Distribution workbooks with A?L provenance, faculty allocations/off-days, room pools, and scheduling rules connect through the Python FastAPI + OR-Tools CP-SAT pipeline to assemble an organized routine. That routine then powers daily student and teacher consultation and exception updates. The pre-auth onboarding narrative must lead with this automated routine-generation concept rather than generic timetable display.

The lifecycle is Distribution ? Configuration ? Generation ? Validation ? Publication ? Daily Student/Teacher Consultation ? Exceptions. Distribution preserves immutable source evidence and audited corrections; Configuration binds scheduling policies to revisions; Generation assembles a candidate; Validation checks academic correctness; Publication exposes the approved routine. Consultation includes next-class tracking, schedule-derived room availability, faculty teaching-slot lookup, and semester resources; Exceptions communicate faculty-posted cancellations and announcements.

This architecture does not establish that every revision-bound workbench integration is operational. Schedule-derived availability describes timetable occupancy, not real-time physical presence. The historical Phase 0 copy removed unsupported AI claims; the approved onboarding story is specified in the addendum below for the dedicated implementation pass.

## Locked Phase 0 direction

- **Visual Identity (Obsidian Orbit ? Approved with conditions):** Retain `#FF7A00` as the primary accent and explore cool-obsidian surfaces (`#0B0C0E`?`#1F2229`), selective top-lit borders, and improved muted-text contrast without excessive glow, glassmorphism, or decorative gradients. **Condition:** All exact design tokens remain provisional until reviewed on representative screens; this specification does not authorize token replacement.
- **Mobile Navigation (Approved with conditions):** Students: `Today | Routine | Campus | Resources | Alerts`. Teachers: `Today | Teaching | Campus | Class Tools | Alerts`. Campus exposes Room Availability (`/rooms`) and Find Teacher (`/find-teacher`). **Condition:** Keep `AppDrawer` and `ExploreFabMenu` temporarily. Do not remove either until every useful destination/action has a reviewed and approved replacement. Preserve routes, direct navigation, account access, and back behavior. The Phase 1 code reconciliation ledger records where the working tree currently differs.
- **Responsive Strategy (Approved with conditions):** Use content-aware tiers: Compact `<768px`, Medium `768?1099px`, Expanded `>=1100px`. Evaluate layouts against available content width after accounting for sidebars/rails, not rigid global viewport rules. Make Weekly Matrix the default routine view only when it fits comfortably; retain Day List as an easy alternative.
- **Administrative Scheduling Coexistence (Approved):** `/admin/routine` is **Routine Operations**, retaining existing operational management/upload/generation workflows and access to the real Python FastAPI + CP-SAT engine at `/admin/routine?tab=generate`. `/admin/scheduling` is **Scheduling Workbench ? Preview**, explicitly preview-only and fail-closed in Live mode until the actual capabilities are integrated and verified independently under Gates A?D below.
- **Capability boundary:** `hasAcceptedRevisionInDb` establishes accepted-row existence only; `isLiveWorkspaceOperational` remains false in the recorded implementation. No accepted row or phase-completion report authorizes fixture rendering or simulated persistence in Live mode.

## Code changes

| File | Symbols and behavior |
|---|---|
| `lib/features/admin/screens/scheduling_workspace_screen.dart` | `initState` removes the second query; `_buildTabContent` always locks live mode; `_buildLiveDistributionBoundary` reads controller availability, explains accepted-but-unwired state, links to operational generation and offers Design Preview. Per-pane primary scroll controllers and `dispose` prevent multiple scroll-position attachments during preview tab transitions. |
| `lib/features/admin/scheduling/controllers/scheduling_workspace_controller.dart` | `hasAcceptedRevisionInDb`, `isLiveWorkspaceOperational`, and compatibility getter `isLiveBackendReady` separate existence from readiness. `saveAuditedCorrection`, `sealDraftRevision`, `updatePolicyOverride`, `runSolverPreview`, and `simulatePublishRoutine` refuse live-mode mutation. `resetToBaseline` and `updateSolverConfig` receive the same protection. `togglePreviewMode` clears pending simulation activity flags; delayed solver/publication boundaries recheck mode and disposal before state updates. |
| `lib/features/admin/scheduling/fixtures/scheduling_preview_fixtures.dart` | `previewRevision.totalRows` and accepted-distribution readiness description derive from `records.length`: 23 actual source records. |
| `lib/features/admin/scheduling/widgets/scheduling_revision_bar.dart` | `build` never displays fixture provenance in live mode. Compact and desktop labels say `source warnings`, distinguishing the two source issues from the preview candidate's zero hard schedule collisions. Solving does not erase source evidence. |
| `lib/features/auth/screens/onboarding_screen.dart` | `_slides`: published routine and next-class countdown; campus/faculty lookup and resources; cohort alerts and faculty-posted cancellations. |
| `lib/features/auth/screens/role_selection_screen.dart` | `_roles`: student routines/lookup/alerts, teacher routines/cancellations/broadcasts, admin departmental generation/users/resources. |
| `CLAUDE.md` | Replace obsolete `validator.py` with validation in `engine/solver.py`, and `renderer.py` with `engine/render.py`; record the Phase 0 live/preview boundary. |
| `test/scheduling_workspace_comprehensive_test.dart` | Add live mutation and count regressions; assert independent capabilities and consistent source-warning/readiness copy. Existing five-pane desktop and mobile tests remain. |
| `test/scheduling_workspace_route_test.dart` | Accepted revision still locks all five live panes and triggers one availability load. Explicit preview toggle renders fixtures; returning live hides fixture records/provenance. Pending availability uses a controlled future. |

### Inline comment locations

Each semantic change boundary is marked `// PHASE 0:`. Locations below refer to this Phase 0 working tree; formatting-only changes carry no new behavior.

- `lib/features/admin/screens/scheduling_workspace_screen.dart`: lines 2, 57, 68, 96, 172, 202, 257, 272.
- `lib/features/admin/scheduling/controllers/scheduling_workspace_controller.dart`: lines 110, 230, 339, 432, 457, 465, 477, 498, 508, 516, 524, 532, 544, 550.
- `lib/features/admin/scheduling/fixtures/scheduling_preview_fixtures.dart`: lines 27, 709.
- `lib/features/admin/scheduling/widgets/scheduling_revision_bar.dart`: lines 27, 83, 202.
- `lib/features/auth/screens/onboarding_screen.dart`: lines 24.
- `lib/features/auth/screens/role_selection_screen.dart`: lines 23.
- `test/scheduling_workspace_comprehensive_test.dart`: lines 12, 20, 45, 66, 270, 276.
- `test/scheduling_workspace_route_test.dart`: lines 1, 13, 44, 85.

## Verification output

Local Flutter verification, 7 November 2026. Final commands exited 0.

```powershell
flutter analyze lib/features/admin/screens/scheduling_workspace_screen.dart lib/features/admin/scheduling/controllers/scheduling_workspace_controller.dart lib/features/admin/scheduling/fixtures/scheduling_preview_fixtures.dart lib/features/admin/scheduling/widgets/scheduling_revision_bar.dart lib/features/auth/screens/onboarding_screen.dart lib/features/auth/screens/role_selection_screen.dart test/scheduling_workspace_comprehensive_test.dart test/scheduling_workspace_route_test.dart
```

```text
Analyzing 8 items...
No issues found! (ran in 2.0s)
```

The requested two scheduling suites were run together with the existing auth suites:

```powershell
flutter test test/scheduling_workspace_comprehensive_test.dart test/scheduling_workspace_route_test.dart test/auth_recovery_remediation_test.dart test/auth_invitation_coordinator_test.dart test/auth_invitation_bridge_test.dart test/auth_callback_policy_test.dart --reporter expanded
```

```text
00:04 +53: All tests passed!
```

Regression evidence: before fixes, live correction returned true, revision metadata was 24 versus 23 records, and the screen invoked availability twice. The pending-state test was made deterministic after removing FutureBuilder timing. Expanded preview-toggle coverage then reproduced a shared-primary-scroll-position error; independent pane controllers resolved it. The first count-copy assertion matched both the header and readiness text and was narrowed to the readiness description. Final tests and analysis pass.

Widget coverage includes 1440 x 900 desktop and 390 x 844 phone preview layouts, plus the existing 1280 x 800 locked-state check. This is local widget/unit evidence, not browser screenshots, a browser navigation walkthrough, production capability verification, or live backend acceptance. Auth suites provide existing regression coverage; no dedicated onboarding/role-copy widget suite was present. No hosted reads/writes, migrations, engine changes, auth/service contract changes, or iOS work were performed. Existing routing was inspected but not changed.

Phase 0 stops here. Redesign Phase 1 shell refactoring and Phase 2 visual token changes require subsequent explicit approval.

## Capability Gates A?D & /preview/scheduling Authorization Boundary

These are independent capability-level acceptance gates, not phase-completion flags. A phase completion report never unlocks a capability. Partial integration must not unlock unrelated capabilities. Table presence in secondary Supabase `oqwvxplteqtlrhktsplj` establishes neither production `yxqyrjyzxitrgkhgauli` readiness nor write safety. Each capability must remain fail-closed until its own required path is integrated and verified in the intended environment; this reconciliation performs no database verification or writes.

| Gate | Required evidence and integration | Permitted unlock |
|---|---|---|
| **A ? Scoped Revision Selection & Real Source Retrieval** | Authenticated, scoped accepted-revision selection and real source-data retrieval through `read_course_distribution_revision`, replacing `SchedulingPreviewFixtures`. | Read-only Distribution inspection only. |
| **B ? Audited Correction Persistence & Concurrency** | Real audited persistence through `append_course_distribution_correction`; optimistic version checks with `40001` stale rejection; trigger-driven artifact invalidation; real revision sealing without synthetic hashes. | Distribution editing only after **A + B** are verified. |
| **C ? Revision-Bound Configuration & Authoritative Validation** | Configuration bound to persisted `PolicySnapshot`; Readiness bound to an authoritative server/engine `validation_report` artifact, replacing hardcoded row-19/row-24 checks and synthetic percentages. | Configuration and Readiness only after **A + B + C** are verified. |
| **D ? Real Engine Execution, Durable Review & Authorized Publication** | Generate wired to the real FastAPI + CP-SAT job pipeline; durable candidate/review artifacts; Review & Publish wired to an authorized, atomic, re-validating publication RPC, replacing `runSolverPreview` and `simulatePublishRoutine`. | Generate, durable Review, and authorized Publication only after **A + B + C + D** are verified; a working engine connection alone does not authorize publication. |

### /preview/scheduling authorization versus disclosure

A simulation watermark is visual disclosure, not access control. `/admin/scheduling` is protected by admin role guards, while `/preview/scheduling` currently bypasses auth redirects in `app_router.dart`. In the **next authorized routing code pass**, restrict `/preview/scheduling` to authenticated admins in release builds, or gate it behind `kDebugMode` / an explicit preview environment flag. Keep visible Preview labeling throughout the workbench regardless of the access-control choice. This is a deferred security boundary requirement, not a claim that the current route is already restricted.

## Onboarding, Splash & Web Authentication Design Addendum

Approved first-impression specification for the dedicated onboarding/auth phase; no auth or onboarding code is changed by this reconciliation.

### Three-stage pre-auth story

1. **01 ? Intelligent Routine Generation:** Course distribution + faculty allocations + rooms + scheduling rules flow through an automated scheduling engine to form an organized timetable.
2. **02 ? Your University Routine, Made Clear:** Published routines adapt to students (batch and joint sections) and teachers (teaching slots and rooms).
3. **03 ? Your Academic Life, Connected:** Class cancellations, announcements, schedule-derived room/faculty lookup, and semester resources complement the routine.

### Convergence animation storyboard

Use a lightweight three-beat Flutter animation: Beat 1 introduces Course/Faculty/Room input pills; Beat 2 pulses connectors into the central Orbit Engine core; Beat 3 populates a structured timetable grid. This conceptual illustration must never invoke the real solver, fabricate operational outputs, promise guaranteed conflict-free schedules, or expose solver jargon to students. Respect `MediaQuery.disableAnimations` with a static or reduced-motion equivalent.

### Platform-specific composition

- **Expanded Web (`>=1100px`):** Art-directed split-screen starting around 58% animated/interactive engine showcase and 42% bounded onboarding/auth panel, with the panel capped at `420?460px` wide. Adapt these proportions to actual usable width.
- **Medium Web (`768?1099px`):** Proportional 50/50 compact split or centered card with a top interactive showcase strip, without cramping forms or illustrations.
- **Compact Mobile (`<768px`):** Focused vertical composition with a bounded illustration stage, touch-friendly controls, and keyboard-safe scrollable forms.

### Auth variants and startup protections

Tailor compositions for Login; Email Login/Signup; Role Selection (intent only, with server-governed whitelist disclosure); Student/Faculty Registration (live cohort/teacher-code personalization preview); Verify Email (visible feedback if five-second session-refresh polling fails); Forgot/Reset Password; and Splash (zero artificial startup wait). Preserve PKCE, OAuth callbacks, operation epochs, and recovery timeouts throughout. Personalization must reflect actual available data, not invented backend results.

### Code delta note

The `_slides` copy written to `lib/features/auth/screens/onboarding_screen.dart` in the initial Phase 0 pass removed the unsupported AI claim. Update it to this three-stage routine-generation story during the approved **redesign Phase 3 implementation pass**. That redesign phase is distinct from the backend roadmap's Phase 3. This document records the design decision only; implementation still awaits the Product Owner's dedicated code-pass authorization.
