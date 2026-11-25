# Advisor showcase checkpoint — 2 November 2026

**SHOWCASE READY WITH LIMITATIONS** for the verified local Android rehearsal.
This does not supersede the [production NOT READY assessment](10-merge-deployment-readiness-2026-11-02.md).
No hosted data, deployment, branch, commit or remote was changed.

## Changes and source interpretation

- R5: Generate accepts a source-matched JSON run profile with the complete
  engine configuration and explicit meeting-count policy. Importing it does
  not change database settings and always makes the run a private preview.
  Profiles are matched by workbook byte length/CRC32, not authenticated approvals.
  Profile-first selection, mismatches and configuration changes fail safely.
- Summer's 338 offerings require 682 meetings under the explicit 14-week
  source-derived policy: six CSE-4116 offerings need three meetings/week
  (38/14 rounded up); the other 332 need two. The database's fixed-two policy
  yields 676. These six meetings were a policy mismatch, not missing rows.
  Contact-hour conversion and current academic progression remain unapproved.
- R4: all known teachers survive preview and private JSON draft persistence;
  student B/C filters include the single source B+C meeting. Teacher readers
  match all available identities. Existing hosted rows cannot recover identities
  already discarded by the legacy schema. XLSX prints the primary teacher;
  the UI explicitly directs users to JSON for the complete teacher list.
- R6: invalid validation results and shared-teacher loss block client
  publication. Imported profiles cannot publish. Private workbook downloads
  never upload to Storage, including when the profile is cleared mid-download.
  This does not repair the legacy server publication RPC or manual CRUD paths.
- R7: current room readers recognize PHY LAB/phy lab/RAB-106 as one physical
  identity; previews use run-specific aliases. No RAB-106 → RKB-106 correction
  or permanent RAB-104 usage restriction was introduced.

Runtime files: `generation_profile.dart`, `timetable_gen_controller.dart`,
`timetable_engine_service.dart`, `timetable_config_service.dart`,
`generate_timetable_screen.dart`, `timetable_grid_screen.dart`,
`routine_model.dart`, `routine_service.dart`, `room_identity.dart`,
`rooms_controller.dart`, `room_detail_screen.dart`, and `app_router.dart`.
Focused tests: `generation_profile_test.dart`, `routine_identity_test.dart`,
`showcase_controller_test.dart`, and `showcase_preview_test.dart`.
Existing unrelated working-tree edits were preserved.

## Actual Android workflow evidence

Native Android file pickers selected both XLSX files and their matching profiles.
The actual Generate screen/controller/HTTP service uploaded to local FastAPI,
polled real CP-SAT jobs and displayed real results. No mocked engine responses
were used. The private entrypoint uses production feature code but deliberately
does not initialize hosted services; normal login/admin navigation was not
device-retested. Preview publication was disabled throughout.

| Device job | Source | Verified result |
|---|---|---|
| `dfbd4e2632c9` | Original Summer 2025 distribution | FEASIBLE; 682 meetings; independent issues `{}`; 36 shared-teacher meetings; 26 pending-faculty meetings retained |
| `fd42d3782fa8` | Fall 2026 observed-only reconstruction | FEASIBLE; 796 meetings; independent issues `{}`; 6 shared-teacher meetings; all 8 retake meetings retained |
| `86a64b960002` | Fall with intentionally unavailable lab rooms | INFEASIBLE; API state `failed`; Android displayed “Generation failed”; no result presented |

Both device-saved JSON drafts matched every generated row and teacher array.
The downloaded Fall workbook had zero missing/unexpected cells and zero header
errors in independent reconciliation. Actual grid inspection showed Summer
B+C with both teachers, Fall 11:50–12:50 midday periods, and retake assignments.
A wrong source/profile pairing was rejected without another generation POST.

The positive runs used the core fixes including the two privacy-race fixes.
Final message formatting and explanatory UI text were subsequently tested and
built; that latest APK installed on a separate fresh private emulator and ran
the negative test. The two positive solves were not repeated after text polish.
The user's Pixel_9 data was not wiped; the fresh emulator lives under the ignored
`.task1-local/showcase-avd-home` directory.

Regression evidence: full Flutter suite **113 passed** before final text polish;
final focused suite **34 passed**, `flutter analyze lib test` **no issues**;
real-source Python count checks **3 passed, 6 deselected**. The previous broader
engine suite was not rerun because this checkpoint changes no Python engine code.
Final targeted whitespace check passed (Git emitted only a line-ending warning).

Private evidence is under `.task1-local/showcase/`: `*-device-verification.json`,
both `*-device-draft.json` files, `fall-device-workbook-checks.json`,
`negative-device-status.json`, and screenshots. Test/build/API logs remain in
`.task1-local`. These files contain private data and must remain ignored.

## Demonstration runbook for 3 November

1. Use the paired `summer-distribution.xlsx` / `summer-profile.json` or
   `fall-distribution.xlsx` / `fall-profile.json` in `.task1-local/showcase`.
   Never use `negative-profile.json` for a normal demonstration.
2. The verified local API is `127.0.0.1:8713`, with two solver workers. If it is
   not already running, launch from the repository root in PowerShell:

   ```powershell
   $env:SOLVER_WORKERS = '2'
   engine/.venv/Scripts/python.exe -m uvicorn main:app --app-dir engine --host 127.0.0.1 --port 8713
   ```

3. The private fixture APK is
   `.task1-local/showcase-app/build/app/outputs/flutter-apk/app-debug.apk`;
   its entrypoint is `.task1-local/showcase_entry.dart`. It uses emulator
   `10.0.2.2:8713`, so it is **not a physical-phone or Render demonstration APK**.
   Use Android Studio's device view for the running private emulator, or start
   that private AVD visibly. Do not wipe the user's existing AVD.
4. Select the workbook and matching JSON profile in either order. Generate and
   allow several minutes for the 180-second solver budget plus parsing/rendering.
   Show validation, inspect student/teacher/room filters and save the private
   JSON draft. XLSX download is optional. Do not publish.

## Remaining limits and next step

Fall is reconstructed from observed live meetings, not an authoritative new
distribution: employment/off-days, unknown room permissions and academic totals
are not certified. Summer is historical; neither profile establishes current
batch progression. Pending faculty remain explicitly unresolved. Seasonal times
and room usage are profile-specific. The possible RAB/RKB typo stays unresolved.

Render deployment, updated remote engine behavior, physical-phone connectivity,
normal authenticated navigation and production publication are **not verified**
by this local fixture. R1–R3 and the other production findings remain deferred.
User owns the merge and must include the intended new runtime files/tests while
excluding private artifacts and unrelated presentation/diagram edits. Next:
rehearse the visible local demo; then verify a separately authorized test
deployment and normal APK workflow before claiming remote showcase readiness.
