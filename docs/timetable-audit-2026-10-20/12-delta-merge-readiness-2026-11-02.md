# Delta Audit and Manual Merge Readiness Report — 2 November 2026

**Assessment: READY TO MERGE WITH LIMITATIONS**  
The updated routine generation engine, normal Flutter application entrypoint, admin authentication and navigation workflow, and transient network polling resilience have been verified. No blocking issues remain for the intended controlled internal team testing. Documented limitations and manual post-merge steps are specified below.

---

## 1. Previous Work Reused

This evaluation relies directly on the verified evidence from:
- `docs/timetable-audit-2026-10-20/10-merge-deployment-readiness-2026-11-02.md`
- `docs/timetable-audit-2026-10-20/11-advisor-showcase-2026-11-02.md`

Key reused evidence:
- **Engine acceptance**: 205 Python tests passed (1 optional skipped); 3 Summer and 3 Fall generation runs verified; 6 application-parser round trips; explanation of 676 vs 682 meetings (14-week source-derived policy vs legacy fixed-two policy).
- **Physical room identity & preview gates**: `RoomIdentity.key` mapping `PHY LAB` / `RAB-106` and run-specific aliases; blocking publication gates on private preview profiles and shared-faculty data loss (R4, R6, R7).
- **Actual Android solver interaction**: Native file pickers, real FastAPI multipart uploads, and real CP-SAT solving producing 682 meetings (Summer) and 796 meetings (Fall), with INFEASIBLE correctly caught.

---

## 2. Audit Findings & Gap Analysis

### A. Normal Flutter Application Entrypoint (`lib/main.dart`)
- **Initialization**: `lib/main.dart` properly initializes `WidgetsFlutterBinding`, Firebase, PushService, Supabase (with PKCE auth flow), `AuthController`, and `AppRouter`.
- **Authentication & Role Redirect**: Login via Google OAuth or email properly queries user profiles. Non-admins attempting to access `/admin/*` are blocked and redirected to `/student/dashboard` or `/teacher/dashboard`.
- **Admin Navigation**: Admins authenticate to `AdminDashboardScreen` (`/admin/dashboard`). From there:
  - Tapping **Generate Timetable** navigates to `/admin/routine?tab=generate`.
  - Tapping **Routine** on bottom nav navigates to `/admin/routine`.
- **Identified Gap (Resolved)**: In `_AdminRoutineScreenState`, a one-time boolean `_readInitialTab` prevented subsequent query parameter changes from updating the active tab if the routine screen had already been visited in the session. This was refactored to track `_lastTabQuery`, ensuring quick actions from the dashboard reliably switch tabs.

### B. Backend & Render Compatibility
- **Backend URL**: The Flutter app references `AppConstants.timetableBaseUrl`, which defaults to `https://universe-timetable-engine.onrender.com`.
- **Service & Repository**: Connected to `https://github.com/FahmidAlam/UniVerse.git` tracking `main`.
- **API Contracts**: `POST /api/timetable/generate`, `GET /api/timetable/status/{job_id}`, `GET /api/timetable/result/{job_id}`, and `GET /api/timetable/download/{job_id}` in `engine/main.py` match `TimetableEngineService` in Flutter.
- **Critical Dependency Gap**: `engine/solver.py:23` imports `from room_policy import room_key`. `engine/room_policy.py` exists as an untracked working-tree file. If this file is not committed before merging to `main`, the Render build will fail with `ModuleNotFoundError`.
- **Dependencies**: `engine/requirements.txt` already specifies required packages (`fastapi`, `uvicorn`, `ortools`, `openpyxl`, `python-multipart`). No additional packages are needed.

### C. Team Device Configuration Readiness
- **Localhost / 10.0.2.2 Trap**: `dart_defines.json` contains `"TIMETABLE_BASE_URL": "http://10.0.2.2:8000"`. If the APK is built using `--dart-define-from-file=dart_defines.json`, physical devices will attempt to connect to the emulator loopback address and fail. Physical device builds must explicitly define `TIMETABLE_BASE_URL=https://universe-timetable-engine.onrender.com` or omit the flag so it falls back to the default `AppConstants` value.
- **Cleartext Restrictions**: `android:networkSecurityConfig` permits cleartext HTTP only to `10.0.2.2`, `localhost`, and `127.0.0.1`. The production Render URL uses HTTPS (`https://...`), satisfying Android network security.
- **Embedded Credentials**: No privileged credentials (`service_role` or database secrets) are present in the Flutter client. `AppConstants.supabaseAnonKey` is the public client key governed by Supabase Row Level Security.
- **Android Signing**: `android/app/build.gradle.kts` automatically configures the release build type to use the debug signing key (`signingConfig = signingConfigs.getByName("debug")`), ensuring team APK builds are installable on test devices without manual keystore configuration.

### D. Generation Lifecycle
- **Navigation away from screen**:
  - *Inside `AdminRoutineScreen`*: Switching between Manage, Generate, and Upload tabs preserves state because `AdminRoutineScreen` uses `IndexedStack`.
  - *Leaving `AdminRoutineScreen`*: Navigating to Dashboard, Users, or Profile unmounts the screen and disposes the controller. On the client, active polling stops and the local `job_id` reference is lost. On the backend, the CP-SAT thread continues solving.
- **Screen restoration**: Returning to the screen initializes a new `TimetableGenController` in `GenPhase.idle`. Active job recovery from server memory is not implemented.
- **Minimizing the app**: Putting the app in the background does not interrupt the backend solver. If Android keeps the app process alive, polling continues; if Android suspends network sockets, transient polling errors occur.
- **Network Resilience (Improved)**: The polling loop in `TimetableGenController` previously failed immediately upon any single network exception. It now tolerates up to 5 consecutive transient network errors (~10 seconds) before aborting, preventing transient mobile/Render drops from killing an active solve.
- **Completion Notifications**: No push or local notification is sent upon solver completion. Notifications are only dispatched if an administrator explicitly taps **Publish to App**.

---

## 3. Changes Made in This Continuation

1. **`lib/features/admin/screens/admin_routine_screen.dart`**:
   - Replaced `bool _readInitialTab` with `String? _lastTabQuery`.
   - Now reacts dynamically to URI query parameters (`?tab=generate`, `?tab=upload`, `?tab=manage`), allowing seamless navigation from Dashboard quick action cards.

2. **`lib/features/admin/controllers/timetable_gen_controller.dart`**:
   - Added transient poll error resilience: tolerates up to 5 consecutive network errors (~10 seconds) during CP-SAT status polling.
   - Made `_pollInterval` configurable via constructor (defaulting to 2 seconds) to support deterministic, fast unit testing.

3. **`test/showcase_controller_test.dart`**:
   - Added unit tests for polling recovery (`recovers from transient network glitches during polling`) and threshold enforcement (`aborts when network failure exceeds retry threshold`).

---

## 4. Verification Executed

| Suite / Check | Result | Details |
|---|---|---|
| **Flutter Test Suite** | **115 passed** (0 failed) | Ran complete Flutter test suite in 8 seconds. |
| **Flutter Static Analysis** | **0 issues** | `flutter analyze lib test` ran clean in 5.5 seconds. |
| **Python Domain Tests** | **24 passed** (0 failed) | `pytest engine/tests/test_domain.py engine/tests/test_legacy_mapping.py` passed in 0.27s. |
| **Tab Query Handling** | Verified | Verified query parameter reaction for `generate`, `upload`, and `manage`. |
| **Transient Poll Retry** | Verified | Tested 2 transient network failures recovering to `GenPhase.done` and 5 failures cleanly surfacing error. |

---

## 5. Curated File List for Merge

Because working-tree modifications and untracked files are not yet committed to `fix/google-oauth`, the user must stage and commit the following files before merging into `main`:

### A. Engine Runtime & Tests (Required for Render)
- `engine/domain.py`
- `engine/legacy_mapping.py`
- `engine/room_policy.py` *(CRITICAL: imported by `solver.py`)*
- `engine/ingest.py`
- `engine/render.py`
- `engine/solver.py`
- `engine/README.md`
- `engine/tests/` (all tests in directory)

### B. Flutter Application Runtime & Tests (Required for APK Build)
- `lib/core/models/academic_model.dart`
- `lib/core/models/profile_model.dart`
- `lib/core/models/routine_model.dart`
- `lib/core/models/timetable_config_model.dart`
- `lib/core/router/app_router.dart`
- `lib/core/utils/clock_time.dart`
- `lib/core/utils/room_identity.dart`
- `lib/features/admin/controllers/routine_upload_controller.dart`
- `lib/features/admin/controllers/timetable_gen_controller.dart`
- `lib/features/admin/screens/admin_routine_screen.dart`
- `lib/features/admin/screens/generate_timetable_screen.dart`
- `lib/features/admin/screens/timetable_grid_screen.dart`
- `lib/features/admin/screens/upload_routine_screen.dart`
- `lib/features/admin/services/academic_config_service.dart`
- `lib/features/admin/services/admin_service.dart`
- `lib/features/admin/services/generation_profile.dart`
- `lib/features/admin/services/routine_workbook_parser.dart`
- `lib/features/admin/services/timetable_config_service.dart`
- `lib/features/admin/services/timetable_engine_service.dart`
- `lib/features/rooms/controllers/rooms_controller.dart`
- `lib/features/rooms/screens/room_detail_screen.dart`
- `lib/features/routine/services/routine_service.dart`
- `test/` (all test files and `test/fixtures/`)
- `.gitignore`

### C. Backend Edge Function Fixes (Ready for function deployment)
- `supabase/functions/invite-admin/index.ts`
- `supabase/functions/send-push/`

### D. Files to Exclude from Commit
- `.task1-local/` (private showcase runs, logs, test artifacts)
- `dart_defines.json` (contains local emulator URL)
- User presentation/diagram deletions (`docs/*.pptx`, `tool/*_diagram.py`) unless intentionally curated by the user.

---

## 6. Build Preparation & Instructions

I will not build the APK or trigger deployments. When you are ready, follow these exact manual steps:

### Step 1: Stage and commit curated files on `fix/google-oauth`
```bash
git add engine/ lib/ test/ supabase/functions/ .gitignore
git commit -m "feat(timetable): integrate updated generation engine and admin application workflow"
```

### Step 2: Merge into `main` and push
```bash
git checkout main
git merge fix/google-oauth
git push origin main
```

### Step 3: Verify Render Deployment
1. Log into your Render dashboard.
2. Select `universe-timetable-engine`.
3. Confirm that the deployment triggered by your push to `main` completes successfully (`Live`).
4. (Optional) Check root endpoint:
   ```bash
   curl https://universe-timetable-engine.onrender.com/
   # Expected: {"service":"universe-timetable-engine","version":"2.0.0","ok":true}
   ```

### Step 4: Build Team Android APK
Run from repository root:
```bash
flutter build apk --release --dart-define=TIMETABLE_BASE_URL=https://universe-timetable-engine.onrender.com
```
*Note: Do NOT pass `--dart-define-from-file=dart_defines.json` unless you have edited `dart_defines.json` to point `TIMETABLE_BASE_URL` to Render.*

The generated APK will be located at:
`build/app/outputs/flutter-apk/app-release.apk`

### Step 5: Team Testing Guidance
- When testing on physical devices, the initial run may take ~50–60s if the Render free-tier instance is asleep.
- Use **Save private draft** to inspect and preserve complete multi-faculty assignments.
- Test with different distribution workbooks (.xlsx) and JSON run profiles as needed.

