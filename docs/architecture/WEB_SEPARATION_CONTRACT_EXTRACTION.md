# UniVerse Web/Mobile Separation — Technical Contract Extraction (Admin-Only React Web v1)

> **Scope & Provenance:** Strictly read-only ground-truth extraction from the `universe_v1` repository working tree (`feature/admin-web-extension`). All secret values, JWTs, API keys, and OAuth client tokens are redacted. Absent files, endpoints, or configs are explicitly marked `NOT FOUND IN REPO`.

---

## Section 1: Python FastAPI Engine API, Auth & CORS Contract

**Inspected files:** [`engine/main.py`](../../engine/main.py), [`engine/solver.py`](../../engine/solver.py), [`engine/ingest.py`](../../engine/ingest.py), [`engine/render.py`](../../engine/render.py), [`engine/distribution.py`](../../engine/distribution.py), [`engine/config.json`](../../engine/config.json), [`engine/requirements.txt`](../../engine/requirements.txt), [`render.yaml`](../../render.yaml), [`engine/Procfile`](../../engine/Procfile).

### 1.1 CORS Configuration (`engine/main.py:18-23`)

| Property | Configured Value | Source / Notes |
|---|---|---|
| Middleware | `fastapi.middleware.cors.CORSMiddleware` | `engine/main.py:9,18` |
| `allow_origins` | `["*"]` (hardcoded wildcard) | Not read from environment variables |
| `allow_origin_regex` | `NOT FOUND IN REPO` (Starlette default `None`) | Not passed in `add_middleware` |
| `allow_credentials` | `NOT FOUND IN REPO` (Starlette default `False`) | Not passed in `add_middleware` |
| `allow_methods` | `["*"]` | Hardcoded |
| `allow_headers` | `["*"]` | Hardcoded |

### 1.2 Authentication & Authorization

- **Engine endpoints are completely unauthenticated.** `engine/main.py` contains zero Supabase JWT verification, zero API key / bearer header checks, and zero `Depends(...)` security guards. Any HTTP caller that reaches the Render service URL can submit jobs, poll status, fetch results, and download rendered `.xlsx` files.

### 1.3 Complete Endpoint Inventory (`engine/main.py`)

> Note: Exact paths use the `/api/timetable/*` prefix for job operations. **`GET /health` is `NOT FOUND IN REPO`** (the root endpoint `GET /` serves as the health check).

| Method & Path | Handler | Request Content-Type & Inputs | Success Response | Error Codes & Bodies |
|---|---|---|---|---|
| `GET /` | `health()` | None | `200 OK` JSON: `{"service": "universe-timetable-engine", "version": "2.0.0", "ok": true}` | — |
| `GET /health` | `NOT FOUND IN REPO` | — | — | `404 Not Found` (FastAPI default) |
| `POST /api/timetable/generate` | `generate()` | `multipart/form-data` (see fields below) | `200 OK` JSON: `{"job_id": "<12-hex-chars>"}` (`uuid.uuid4().hex[:12]`) | `400`: `"Upload a .xlsx distribution file."`, `"config is not valid JSON."`, `"source_contract is not valid JSON."`, `"source_contract must be a JSON object."` |
| `GET /api/timetable/status/{job_id}` | `status()` | Path param `job_id: str` | `200 OK` JSON (schema below) | `404`: `{"detail": "Unknown job_id."}` |
| `GET /api/timetable/result/{job_id}` | `result()` | Path param `job_id: str` | `200 OK` JSON (schema below) | `404`: `{"detail": "Unknown job_id."}`; `409`: `{"detail": "Job not finished (state=<state>)."}` |
| `GET /api/timetable/download/{job_id}` | `download()` | Path param `job_id: str` | `200 OK` binary `.xlsx` (`application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`), `Content-Disposition: attachment; filename="CSE_Routine_<label>.xlsx"` | `404`: `{"detail": "Unknown job_id."}`; `409`: `{"detail": "No workbook for this job yet."}` |

#### Request Contract: `POST /api/timetable/generate` (`multipart/form-data`)

| Form Field | Python Type | Required | Validation / Behavior |
|---|---|---|---|
| `file` | `UploadFile` | Yes | `file.filename` must end with `.xlsx` or `.xls` (case-insensitive). Parsed via `openpyxl` (`distribution.DistributionDraft.create` requires a sheet named `'Course Distribution'`). |
| `config` | `str \| None` | No | JSON string overriding `engine/config.json`. Parsed by `json.loads` and normalized by `solver.load_config(override=...)`. If omitted, loads `engine/config.json`. |
| `source_contract` | `str \| None` | No | JSON object string representing a persisted Course Distribution revision bundle (`source_id`, `revision_id`, `revision_number`, `revision_version`, `status: "accepted"`, `source_sha256`, `corrections[]`). Verified via `distribution.normalize_persisted_revision()`. |
| `time_limit_s` | `float` | No (default `60.0`) | CP-SAT solve budget in seconds (`TimetableGenController` passes `180.0`). |

#### Job State Machine & Background Execution

- **Job Storage:** Process-local in-memory dictionary `JOBS: dict[str, dict] = {}` (`engine/main.py:25`), updated by a daemon `threading.Thread` (`engine/main.py:136-138`). No Redis, database persistence, TTL/eviction, or multi-worker synchronization exists. Render free-tier sleep/restart wipes `JOBS`, turning active `job_id`s into `404`.
- **State Transitions & Progress Milestones (`engine/main.py:47-101, 135`):**
  1. `queued` (`progress: 0.0`)
  2. `ingesting` (`progress: 0.08`)
  3. `solving` (`progress: 0.2` up to `0.95`, computed as `round(0.2 + float(value) * 0.75, 2)`)
  4. `rendering` (`progress: 0.97`)
  5. `done` (`progress: 1.0`) or `failed` (`progress: 1.0`, sets `error: str(e)`)

#### Response JSON Schemas (`status`, `result`, `report`, `validation`)

```typescript
// GET /api/timetable/status/{job_id}
export interface EngineStatusResponse {
  job_id: string;
  state: 'queued' | 'ingesting' | 'solving' | 'rendering' | 'done' | 'failed';
  progress: number; // 0.0 .. 1.0
  // Present only when state === 'done':
  stats?: EngineStats;
  validation?: EngineValidation;
  source_contract?: EngineSourceContract;
  // Present only when state === 'failed':
  error?: string;
}

// GET /api/timetable/result/{job_id}
export interface EngineResultResponse {
  job_id: string;
  rows: EngineRoutineRow[];         // Non-service CSE rows (rendered on grid)
  service_rows: EngineRoutineRow[]; // GED / non-CSE service rows (occupy teacher/room time)
  stats: EngineStats;
  validation: EngineValidation;
  source_contract: EngineSourceContract;
  report: {
    source_contract: EngineSourceContract;
    cohorts: string[]; // Ordered newest numeric batch desc, then section asc
    meta: {
      rows: number;
      offerings: number;
      shared_offerings: number;
      sessions: number;
      render_sessions: number;
      service_sessions: number;
      excluded: number;
      cohorts: number;
      teachers: number;
      pending_faculty_offerings: number;
      weeks_in_term: number;
      fixed_sessions_per_week: number | null;
      sessions_per_week_histogram: Record<string, number>;
    };
    excluded: Array<{
      row: number;
      code: string | null;
      batch: string | null;
      section: string | null;
      reason: 'no_course_code' | 'no_batch' | 'no_teacher';
      detail: string;
    }>;
    warnings: string[];
    offerings: Array<Record<string, unknown>>; // dataclasses.asdict(ingest.Offering)
  };
  has_workbook: boolean;
}

export interface EngineRoutineRow {
  id: string;                 // Synthetic e.g. "gen-0"
  day: string;                // e.g. "Sunday"
  period: number;             // 1-based period idx
  time_start: string;         // "HH:MM" from pmeta[p]["start"]
  time_end: string;           // "HH:MM" from pmeta[p]["end"]
  subject: string;            // Course title
  subject_code: string;       // e.g. "CSE-3101"
  teacher_name: string | null;
  teacher_code: string | null;
  room: string;               // Room name or "TBA"
  batch: string;
  section: string;
  semester: number;
  is_active: boolean;
  // Engine metadata (not persisted by RoutineEntry.toMap() to `routines`):
  oid: number;
  teachers: string[];         // All assigned/co-teaching acronyms
  teacher_state: 'assigned' | 'pending';
  is_service: boolean;
  is_lab: boolean;
}

export interface EngineStats {
  status: string;             // OR-Tools status name (e.g. "OPTIMAL", "FEASIBLE")
  solve_ms: number;
  meetings: number;           // len(rows)
  service_meetings: number;   // len(service_rows)
  offerings: number;
  cohorts: number;
  teachers: number;
  objective: number;
  lab_theory_pairs: number;
  lab_theory_adjacent: number;
}

export interface EngineValidation {
  required_offerings: number;
  scheduled_offerings: number;
  missing_courses: number;
  under_scheduled: number;
  over_scheduled: number;
  unexpected_courses: number;
  teacher_clashes: number;
  cohort_clashes: number;
  room_clashes: number;
  dayoff_violations: number;
  blocked_period_violations: number;
  lab_room_violations: number;
  unplaced_rooms: number;
  invalid_time_slots: number;
  invalid_days: number;
  same_day_sessions: number;
  ineligible_assignments: number;
  teacher_assignment_mismatches: number;
  unknown_rooms: number;
  room_capacity_violations: number;
  unresolved_teachers: number;
  pending_faculty_assignments: number;
  same_day_rule: 'enforced' | 'off';
  lab_theory_pairs: number;
  lab_theory_adjacent: number;
  lab_theory_violations: number;
  // Each array in details is capped at DETAIL_LIMIT = 50:
  details: Record<string, Array<Record<string, unknown>>>;
  source_contract: EngineSourceContract;
  ok: boolean;
}

export interface EngineSourceContract {
  source_sha256: string;
  revision: number;
  invalidated_artifacts: string[];
  // Additional keys present when generated via persisted Course Distribution revision:
  source_id?: string;
  revision_id?: string;
  revision_number?: number;
  revision_version?: number;
}
```

#### Baseline `engine/config.json` Schema

- Top-level keys:
  - `days`: 7-day list (`["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]`)
  - `periods`: 7 slot objects (`idx: 1..7`, `label`, `start` `"HH:MM"`, `end` `"HH:MM"`, `col` `["D","E","F","H","I","J","K"]` — column `G` is break)
  - `friday_no_p4`: `true`
  - `rooms`: 30 room objects (`name`, `building`, `is_lab`, `is_gallery`), plus `lab_rooms` (8 names) and `galleries` (3 names)
  - `teachers`: dictionary keyed by teacher acronym (`full_name`, `dept`, `designation`, `off_days[]`). *(Note: `solver._normalize_config` accepts `teachers` as either a dict or a list of `{acronym, full_name, dept, off_days}` objects sent by the client.)*
  - `settings`: `{semester_label: "Summer 2025", periods, working_days, weeks_in_term: 14, blocked_periods: {"Friday": [4]}, online_periods: [7], allow_online_periods: false, excluded_periods: [], semester_map: {}, friday_no_p4: true, service_scope: "resource_only", weights: {different_days: 8, compactness: 3, spread: 2, late_slot: 1}, fixed_sessions_per_week: 2}`

### 1.4 Deployment Config (`render.yaml` & `engine/Procfile`)

| Item | `render.yaml` | `engine/Procfile` |
|---|---|---|
| Service Name | `universe-timetable-engine` (`type: web`, `runtime: python`) | — |
| Root Directory | `engine` | Run from `engine/` |
| Plan & Cold-Start | `plan: free` (512 MB RAM; Render free web services spin down after inactivity, causing cold-start latency and clearing in-memory `JOBS`) | — |
| Build Command | `pip install -r requirements.txt` (`fastapi>=0.110`, `uvicorn[standard]>=0.29`, `ortools>=9.10`, `openpyxl>=3.1`, `python-multipart>=0.0.9`) | — |
| Start Command | `uvicorn main:app --host 0.0.0.0 --port $PORT` | `web: uvicorn main:app --host 0.0.0.0 --port $PORT` |
| Health Check Path | `/` | — |
| Expected Env Vars | `PYTHON_VERSION=3.12.7`, `SOLVER_WORKERS="2"` (read by `engine/solver.py:27`, defaults to `"8"` if unset), `PORT` (Render-injected) | `PORT`, optional `SOLVER_WORKERS` |

---

## Section 2: Current Web Hosting, Bootstrap & Environment Configuration

**Inspected files:** [`web/index.html`](../../web/index.html), [`web/manifest.json`](../../web/manifest.json), [`dart_defines.json`](../../dart_defines.json), [`dart_defines.example.json`](../../dart_defines.example.json), [`lib/core/constants/app_constants.dart`](../../lib/core/constants/app_constants.dart), [`lib/main.dart`](../../lib/main.dart), [`lib/features/auth/services/auth_callback_policy.dart`](../../lib/features/auth/services/auth_callback_policy.dart), [`lib/core/platform/auth_callback_cleanup_web.dart`](../../lib/core/platform/auth_callback_cleanup_web.dart), [`.github/workflows/validate.yml`](../../.github/workflows/validate.yml), [`.github/workflows/supabase_keep_alive.yml`](../../.github/workflows/supabase_keep_alive.yml), [`pubspec.yaml`](../../pubspec.yaml).

### 2.1 Current Web Hosting Setup

- **Flutter Web is local-only / unhosted in repo.** Hosting manifests (`firebase.json`, `wrangler.toml`, `vercel.json`, `netlify.toml`, `.env`, `.env.example`, and any web build/deploy CI workflow) are **`NOT FOUND IN REPO`**.
- **`.github/workflows/`** contains only:
  - [`validate.yml`](../../.github/workflows/validate.yml): runs Python domain pytest checks (`engine/tests/`), Python tool unit tests (`tool/tests/`), Deno tests for `supabase/functions/send-push/`, and local Supabase DB rebuild (`python tool/task1_local_checks.py --task2`). No Flutter/web build or deploy job exists.
  - [`supabase_keep_alive.yml`](../../.github/workflows/supabase_keep_alive.yml): cron (`0 0 */3 * *`) that `GET`s `https://yxqyrjyzxitrgkhgauli.supabase.co/rest/v1/` with hardcoded `SUPABASE_ANON_KEY=<REDACTED>`.
- **`web/index.html` & `web/manifest.json`:**
  - `web/index.html` uses `<base href="$FLUTTER_BASE_HREF">`, `<body style="background-color: #0B0C0E;">`, and `<script src="flutter_bootstrap.js" async></script>`.
  - `web/manifest.json` retains stock Flutter template metadata (`name: "universe_v1"`, `theme_color: "#0175C2"`, `background_color: "#0175C2"`).

### 2.2 Environment Variable Contract (`dart_defines.json`, `app_constants.dart`, `auth_callback_policy.dart`)

| Key Name | Defined in `dart_defines.json`? | Defined in `dart_defines.example.json`? | `AppConstants` / Dart Default | Web vs. Android Resolution |
|---|---|---|---|---|
| `SUPABASE_URL` | Yes (`https://yxqyrjyzxitrgkhgauli.supabase.co`) | Yes (`https://YOUR_PROJECT.supabase.co`) | `https://yxqyrjyzxitrgkhgauli.supabase.co` | Identical (`String.fromEnvironment`, no `kIsWeb` branch) |
| `SUPABASE_ANON_KEY` | Yes (`<REDACTED>`) | Yes (`YOUR_SUPABASE_ANON_KEY`) | `<REDACTED>` | Identical (`String.fromEnvironment`, no `kIsWeb` branch) |
| `GEMINI_API_KEY` | Yes (`<REDACTED>`) | Yes (`YOUR_GEMINI_API_KEY`) | `YOUR_GEMINI_API_KEY` | Identical (`String.fromEnvironment`, no `kIsWeb` branch) |
| `TIMETABLE_BASE_URL` | Yes (`http://10.0.2.2:8000`) | Yes (`http://10.0.2.2:8000`) | `https://universe-timetable-engine.onrender.com` | **No `kIsWeb` branch.** Warning: passing `dart_defines.json` verbatim to a web build points web to Android emulator loopback `10.0.2.2:8000` instead of localhost or Render. |
| `GOOGLE_WEB_CLIENT_ID` | `NOT FOUND` | `NOT FOUND` | `<REDACTED>.apps.googleusercontent.com` | Used only on non-web Android (`GoogleSignIn(serverClientId:)` in `auth_service.dart:38-42`). Web uses Supabase OAuth redirect. |
| `AUTH_WEB_CALLBACK_URLS` | `NOT FOUND` | `NOT FOUND` | `""` (empty string) | Web-only (`AuthCallbackPolicy.current` in `auth_callback_policy.dart:20`). Comma-separated exact URL allowlist; also expected in Supabase Edge Function env for `invite-admin`. |
| `ENABLE_SCHEDULING_PREVIEW_ROUTE` | `NOT FOUND` | `NOT FOUND` | `false` (`bool.fromEnvironment`) | Used in `app_router.dart:53`; combined with `kDebugMode`. |

### 2.3 Web Callback & Routing Mode

- **Routing Mode:** **Hash routing (`/#/`)**. Neither `usePathUrlStrategy()` nor `flutter_web_plugins` is configured (`NOT FOUND IN REPO`).
- **Exact Web Callback URLs:**
  - Dedicated **`/auth-callback` route is `NOT FOUND IN REPO`**.
  - On web (`kIsWeb == true`), `AuthCallbackPolicy._browserCallback()` (`auth_callback_policy.dart:32-50`) takes `Uri.base`, strips query (`?`) and fragment (`#`), strips trailing `[?#]+`, verifies scheme is `https` or loopback `http` (`localhost`, `127.0.0.1`, `::1`), verifies `uri.userInfo.isEmpty && uri.host.isNotEmpty`, and asserts exact membership in `AUTH_WEB_CALLBACK_URLS`.
  - If `AUTH_WEB_CALLBACK_URLS` is unconfigured or does not contain the current browser URL, `_browserCallback()` throws `StateError`, failing Google sign-in, email signup/resend, password reset, and admin invitations on web.
  - On Android (`!kIsWeb`), `AuthCallbackPolicy` uses hardcoded deep links:
    - `loginCallback`: `'com.example.universe://login-callback/'`
    - `recoveryCallback` / `invitationCallback`: `'com.example.universe://reset-callback/'`

---

## Section 3: Admin-Only Auth, Whitelist & Invitation Contract

**Inspected files:** [`lib/main.dart`](../../lib/main.dart), [`lib/features/auth/controllers/auth_controller.dart`](../../lib/features/auth/controllers/auth_controller.dart), [`lib/features/auth/services/auth_service.dart`](../../lib/features/auth/services/auth_service.dart), [`lib/features/auth/services/auth_callback_policy.dart`](../../lib/features/auth/services/auth_callback_policy.dart), [`lib/features/auth/services/invitation_callback_bridge.dart`](../../lib/features/auth/services/invitation_callback_bridge.dart), [`lib/features/auth/services/invitation_callback_coordinator.dart`](../../lib/features/auth/services/invitation_callback_coordinator.dart), [`lib/core/platform/auth_callback_cleanup_web.dart`](../../lib/core/platform/auth_callback_cleanup_web.dart), [`lib/core/router/app_router.dart`](../../lib/core/router/app_router.dart), [`lib/features/auth/screens/reset_password_screen.dart`](../../lib/features/auth/screens/reset_password_screen.dart), [`lib/features/auth/screens/not_whitelisted_screen.dart`](../../lib/features/auth/screens/not_whitelisted_screen.dart), [`lib/features/auth/screens/auth_error_screen.dart`](../../lib/features/auth/screens/auth_error_screen.dart), [`supabase/functions/invite-admin/index.ts`](../../supabase/functions/invite-admin/index.ts), [`supabase/functions/invite-admin/handler.js`](../../supabase/functions/invite-admin/handler.js), [`supabase/functions/invite-admin/callback_policy.js`](../../supabase/functions/invite-admin/callback_policy.js), [`supabase/migrations/016_teacher_whitelist_gate.sql`](../../supabase/migrations/016_teacher_whitelist_gate.sql).

### 3.1 Admin Sign-In & Session Lifecycle

`Supabase.initialize` configures `FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce)` (`lib/main.dart:35-41`).

1. **Google OAuth (Web PKCE):**
   - `AuthService.signInWithGoogle()` (`auth_service.dart:49-57`) calls `_supabase.auth.signInWithOAuth(OAuthProvider.google, redirectTo: AuthCallbackPolicy.current.loginCallback, authScreenLaunchMode: LaunchMode.externalApplication)` and returns `false` (browser redirects away).
   - After redirect back with PKCE `?code=...`, Supabase SDK exchanges the code and emits `AuthChangeEvent.signedIn` on `onAuthStateChange`.
   - `main.dart:86-92` invokes `authController.handleOAuthCallback()` -> `_resolvePostLogin()` -> `AuthService.handlePostLogin()`.
2. **Email/Password Login:**
   - `AuthService.signInWithEmail()` (`auth_service.dart:116-142`) calls `signInWithPassword(email: email.trim().toLowerCase(), password: password)`.
   - Checks `response.user!.emailConfirmedAt != null`. If null, calls `signOut()` and returns `AuthResult.needsVerification()` (`AuthStatus.awaitingVerification` -> `/verify-email`).
   - Otherwise calls `handlePostLogin()`.
3. **Startup Session Hydration (`AuthController.initialize()`, `auth_controller.dart:233-287`):**
   - Waits `initializationDelay` (`1800ms`), checks `_authService.currentUser`. If email provider & `emailConfirmedAt == null`, routes to `awaitingVerification`.
   - Calls `fetchProfile(user.id)` first; if null, falls back to `handlePostLogin()`.
4. **`profiles` vs. `whitelists` Check Order (`AuthService.handlePostLogin()`, `auth_service.dart:206-263`):**
   - **Step 1 (`profiles` first):** Queries `public.profiles` where `id = user.id` (`maybeSingle()`). If a row exists, **returns immediately** with `{role, profile}` — `whitelists` is **not** re-checked for existing users.
   - **Step 2 (`whitelists` fallback):** If no `profiles` row exists, queries `public.whitelists` where `email = email.toLowerCase()` (`maybeSingle()`).
   - **Step 3 (not whitelisted):** If `whitelistRow == null`, returns `AuthResult(success: true, profile: null)` (no role/profile). `AuthController` sets `AuthStatus.registering` -> `/role-selection` (where student self-registration is permitted, and teacher self-registration is blocked by DB trigger unless whitelisted).
   - **Step 4 (whitelisted first-time login):** If `whitelistRow != null`, copies `role`, `name` (fallback `userMetadata['full_name']`), `batch`, `section`, `semester`, `teacher_code`, `designation`, `department`, `avatar_url`, `courses: []` and `INSERT`s into `public.profiles`. Postgres RLS (`profiles_insert_own`) and trigger `profiles_guard_role` enforce that `whitelists.role == new.role` for `teacher`/`admin`.

> **React Admin-Only Web Implication:** Because `handlePostLogin()` allows non-whitelisted users to enter `AuthStatus.registering` (and allows `student` / `teacher` profiles to authenticate in the shared Flutter client), an **Admin-Only React Web** app must explicitly check `profile?.role === 'admin'` (or sign out / show unauthorized state if missing `admin` profile or `admin` whitelist row).

### 3.2 Error & Guard Contracts

| Failure / Guard Condition | Backend / Trigger Mechanism | Client Detection & Status / Route |
|---|---|---|
| Non-whitelisted user tries to insert/update `profiles.role` to `'teacher'` or `'admin'` | Trigger `profiles_guard_role` (`public.guard_profile_role()`, migration `016`) checks: (1) `auth.uid() is null` or `public.is_admin()`, (2) `UPDATE` with unchanged role, (3) `INSERT` upsert where `(id, role)` already matches `profiles`, (4) `new.role = 'student'`, (5) `EXISTS (SELECT 1 FROM whitelists w WHERE lower(w.email) = lower(auth.jwt() ->> 'email') AND w.role = new.role)`. Otherwise raises SQLSTATE `42501`, `HINT = 'not_whitelisted'`, message `'The <role> role needs to be added by the department admin.'`. | `AuthService.isNotWhitelistedError(e)` checks `e.hint == 'not_whitelisted'` (`auth_service.dart:306-307`), returning `AuthResult.failure('not_whitelisted')`. `AuthController` sets `AuthStatus.notWhitelisted` -> `/not-whitelisted` (`NotWhitelistedScreen`). |
| Profile lookup / DB / invitation callback error | Postgrest error (not `not_whitelisted`), unexpected exception, or failed invitation verification | `AuthStatus.profileError` -> `/auth-error` (`AuthErrorScreen` with Retry / Sign out). |
| Email not verified | `user.emailConfirmedAt == null` on email sign-in / signup / init | `AuthStatus.awaitingVerification` -> `/verify-email` (`AuthService` signs out local session on `signInWithEmail`). |
| Non-admin authenticated user on `/admin/*` | Client `AppRouter._isWrongRolePage` (`app_router.dart:412-420`) | Flutter redirects `student` -> `/student/dashboard`, `teacher` -> `/teacher/dashboard`. (In an Admin-Only React Web app, reject non-admin sessions.) |
| `AuthService._friendlyAuthError` mappings (`auth_service.dart:364-386`) | Raw `AuthException.message` substring match (case-insensitive) | `'invalid login credentials'` / `'invalid email or password'` -> `'Incorrect email or password. Please try again.'`; `'email not confirmed'` -> `'Please verify your email before signing in.'`; `'user already registered'` -> `'An account with this email already exists. Try signing in.'`; `'password should be at least'` -> `'Password must be at least 6 characters.'`; `'rate limit'` -> `'Too many attempts. Please wait a few minutes and try again.'`; `'network'` / `'connection'` -> `'No internet connection. Please check your network.'`. |

### 3.3 Password Recovery & Invite-Admin Bridge

#### A. Password Recovery (PKCE Flow)

1. `AuthService.sendPasswordResetEmail(email)` (`auth_service.dart:144-156`) calls `resetPasswordForEmail(email.trim().toLowerCase(), redirectTo: AuthCallbackPolicy.current.recoveryCallback)`.
2. User clicks link -> Supabase exchanges PKCE code -> emits `AuthChangeEvent.passwordRecovery` (`main.dart:85` -> `AuthController.handleAuthEvent`).
3. `AuthController` increments `_stateEpoch`, starts a 10-minute `recoveryTimeout` timer (auto-signs out on expiry), and sets `AuthStatus.passwordRecovery`.
4. `AppRouter.redirectFor` forces navigation to `/reset-password` (`ResetPasswordScreen`), where `updateRecoveryPassword(password)` calls `_supabase.auth.updateUser(UserAttributes(password: newPassword))`, then user taps `"Sign in now"` (`signOut()` -> `/login/email`).

#### B. `invite-admin` Edge Function (`supabase/functions/invite-admin/`)

- **Invoke from client (`AdminService.inviteAdmin`, `admin_service.dart:98-112`):**
  - `POST <SUPABASE_URL>/functions/v1/invite-admin` with `Authorization: Bearer <caller_jwt>`, JSON body:
    ```json
    {
      "email": "newadmin@university.edu",
      "name": "Admin Name",
      "redirect_to": "https://admin.example.com/"
    }
    ```
- **Server Execution (`handler.js` + `callback_policy.js`):**
  1. Verifies `Authorization` header via `callerClient.auth.getUser()` (`401` if missing/invalid).
  2. Queries `profiles.role` for `caller.id` using `SUPABASE_SERVICE_ROLE_KEY`; requires `callerProfile.role === 'admin'` (`403`: `"Only admins can invite admins."`).
  3. Validates `email` (`400`: `"A valid email is required."`).
  4. Validates `body.redirect_to` via `resolveInvitationCallback(body.redirect_to, Deno.env.get('AUTH_WEB_CALLBACK_URLS') ?? '')` (`400`: `"Invitation callback is not approved."`):
     - `undefined`/`null` or `'com.example.universe://reset-callback/'` -> `'com.example.universe://reset-callback/'`
     - Otherwise must be valid `https:` (or `http:` only on `localhost`, `127.0.0.1`, `[::1]`), no username/password/search/hash/`?`/`#`/`*`, `url.href === requested`, and **exact match** in comma-separated `AUTH_WEB_CALLBACK_URLS`.
  5. Upserts `public.whitelists`: `{ email, role: 'admin', name }` (`onConflict: 'email'`).
  6. Calls `admin.auth.admin.inviteUserByEmail(rawEmail, { data: { full_name: name ?? '' }, redirectTo })`.
  7. Returns `200` `{"success": true}` (or `400` / `500` `{"error": "..."}`).

#### C. Why the PKCE / Implicit Invite Callback Gap Occurs & How the Bridge Resolves It

- **Exact Cause:** The Flutter client initializes Supabase with `AuthFlowType.pkce`, which expects authorization `?code=...` callbacks backed by a client-generated `code_verifier`. However, `inviteUserByEmail()` is initiated server-side by the `invite-admin` Edge Function with no client `code_verifier`, so Supabase Auth delivers **implicit** tokens in the URL hash fragment:
  - `#access_token=<jwt>&refresh_token=<token>&expires_in=<sec>&token_type=bearer&type=invite` (with **no** query string `?`).
  - Standard PKCE `GoTrueClient` does not establish a password-setup (`passwordRecovery`) session from an implicit `#...type=invite` fragment.
- **Exact Flutter Bridge Mechanics (`main.dart`, `auth_callback_cleanup_web.dart`, `invitation_callback_coordinator.dart`, `invitation_callback_bridge.dart`):**
  1. On web startup, `clearInvitationLocation(Uri.base)` (`auth_callback_cleanup_web.dart:6-14`) checks `Uri.splitQueryString(uri.fragment)['type'] == 'invite'` and scrubs credentials from the browser bar via `window.history.replaceState(null, '', uri.replace(query: '', fragment: '').toString())`.
  2. `InvitationCallbackCoordinator.handle(uri)` ignores non-invite URIs (`type != 'invite'`), deduplicates by `uri.hashCode`, tracks `_operationEpoch`, and runs `onStart` -> `consume` -> `onVerified` / `onFailure`.
  3. `InvitationCallbackBridge.consume(uri)` validates:
     - `parameters['type'] == 'invite'`
     - `uri` without query/fragment equals `AuthCallbackPolicy.current.invitationCallback`
     - `!uri.hasQuery`
     - `access_token` non-empty, `refresh_token` non-empty, `token_type == 'bearer'`, `int.tryParse(expires_in) > 0`
  4. Spawns a disposable `GoTrueClient(url: '${SUPABASE_URL}/auth/v1', headers: {'apikey': SUPABASE_ANON_KEY}, autoRefreshToken: false, flowType: AuthFlowType.implicit)` and calls `verifier.getSessionFromUrl(uri, storeSession: false)` (calls `/auth/v1/user` to verify token). Checks `verified.redirectType == 'invite'`, `user.invitedAt != null`, `user.emailConfirmedAt != null`.
  5. Exchanges refresh token directly via `POST ${SUPABASE_URL}/auth/v1/token?grant_type=refresh_token` with `{"refresh_token": ...}` (`apikey` header), validating `session.user.id == user.id` and `session.expiresAt > now + 60`.
  6. Adopts the session synchronously via `_auth.recoverSession(jsonEncode(session.toJson()))`, then `completeInvitationCallback` triggers `AuthController.handleAuthEvent(AuthChangeEvent.passwordRecovery, userId)`, locking the router to `/reset-password`.
- **`/auth-callback` and `/reset-password` Summary:**
  - `/auth-callback`: **`NOT FOUND IN REPO`** (callbacks land on the root/approved URL in `AUTH_WEB_CALLBACK_URLS`, then `GoRouter` redirects by `AuthStatus`).
  - `/reset-password`: **`RouteNames.resetPassword`** (`ResetPasswordScreen`), reachable only when `AuthStatus == AuthStatus.passwordRecovery`.

### 3.4 Admin Route Guard Rules (`lib/core/router/app_router.dart`)

- **Redirect Precedence (`AppRouter.redirectFor`, `app_router.dart:304-420`):**
  1. If `location == '/preview/scheduling'` and (`kDebugMode` or compile-time `ENABLE_SCHEDULING_PREVIEW_ROUTE == true`): **bypass auth** (`return null`).
  2. `AuthStatus.passwordRecovery` -> lock to `/reset-password`.
  3. `AuthStatus.profileError` -> lock to `/auth-error`.
  4. `location == '/reset-password'` when `authenticated` -> role dashboard; when any other settled status -> `/role-selection` (if `registering`) else `/login`.
  5. `initial` / `loading` -> lock to `/` (`splash`).
  6. `notWhitelisted` -> lock to `/not-whitelisted`.
  7. `awaitingVerification` -> lock to `/verify-email`.
  8. `registering` -> lock to `registrationPages` (`/role-selection`, `/register/student`, `/register/faculty`, `/signup/email`, `/verify-email`), else `/role-selection`.
  9. `unauthenticated` / `error` -> allow `authPages`, else `/login`.
  10. `authenticated`:
      - If `location == '/preview/scheduling'` and `role != 'admin'`: redirect to `_dashboardForRole(role)`.
      - If `authPages.contains(location)` or `_isWrongRolePage(location, role)`: redirect to `_dashboardForRole(role)` (`admin` -> `/admin/dashboard`, `teacher` -> `/teacher/dashboard`, default -> `/student/dashboard`).
      - `_isWrongRolePage`: rejects `/admin*` for `student` and `teacher`; rejects `/student*` and `/teacher*` for `admin`.
- **Active `/admin/*` & `/preview/*` Routes in `AppRouter` (`app_router.dart:127-269`):**
  - Inside authenticated `ShellRoute` (`AppShell` -> `AdminDesktopShell` on desktop widths):
    - `/admin/dashboard`, `/admin/routine`, `/admin/scheduling`, `/admin/broadcast`, `/admin/broadcast/history`, `/admin/registration`, `/admin/users`, `/admin/resources`, `/admin/resources/library`, `/admin/timetable/courses`, `/admin/timetable/batches`, `/admin/timetable/rooms`, `/admin/timetable/faculty`, `/admin/timetable/course-eligibility`, `/admin/timetable/settings`, `/admin/timetable/grid`.
    - Shared shell routes accessible to admin: `/rooms`, `/rooms/detail`, `/find-teacher`, `/find-teacher/detail`, `/notifications`, `/profile`.
  - Outside `ShellRoute`: `/preview/scheduling` (`RouteNames.schedulingWorkspacePreview`), launching `SchedulingWorkspaceScreen(initialPreviewMode: true, initialTabIndex: ..., initialSelectedRow: ...)` with query params `tab` (`configuration|readiness|generate|review`, else `0`) and `row` (`int`).

---

## Section 4: Admin Client-Side Business Logic & Service Contracts

**Inspected files:** [`routine_workbook_parser.dart`](../../lib/features/admin/services/routine_workbook_parser.dart), [`timetable_engine_service.dart`](../../lib/features/admin/services/timetable_engine_service.dart), [`timetable_config_service.dart`](../../lib/features/admin/services/timetable_config_service.dart), [`academic_config_service.dart`](../../lib/features/admin/services/academic_config_service.dart), [`admin_service.dart`](../../lib/features/admin/services/admin_service.dart), [`generation_profile.dart`](../../lib/features/admin/services/generation_profile.dart), [`engine_connectivity_service.dart`](../../lib/features/admin/services/engine_connectivity_service.dart), [`routine_upload_controller.dart`](../../lib/features/admin/controllers/routine_upload_controller.dart), [`timetable_gen_controller.dart`](../../lib/features/admin/controllers/timetable_gen_controller.dart), [`scheduling_workspace_controller.dart`](../../lib/features/admin/scheduling/controllers/scheduling_workspace_controller.dart), [`notification_service.dart`](../../lib/features/notifications/services/notification_service.dart), [`resource_service.dart`](../../lib/features/resources/services/resource_service.dart), [`routine_service.dart`](../../lib/features/routine/services/routine_service.dart), [`clock_time.dart`](../../lib/core/utils/clock_time.dart), [`room_identity.dart`](../../lib/core/utils/room_identity.dart), [`routine_model.dart`](../../lib/core/models/routine_model.dart), [`timetable_config_model.dart`](../../lib/core/models/timetable_config_model.dart), [`admin_catalog_models.dart`](../../lib/core/models/admin_catalog_models.dart), [`academic_model.dart`](../../lib/core/models/academic_model.dart).

### 4.1 Client-Side Excel Parsing (`routine_workbook_parser.dart`)

- **Supported Formats (`.xlsx` ZIP XML decoded client-side via `archive` + `xml`):**
  1. **`UniVerse day sheets` (primary):** Matches worksheet names to `Sunday..Saturday` (exact or prefix/contains). Reads from row `_firstDataRow = 3` onward. Detects Batch & Section columns from rows `1..16` headers (defaults to `B` and `C`). Resolves period slots from `timetable_settings.periods` columns, overridden by any time ranges found in header rows `1..16`, or falling back to `D` (`08:50-10:05`), `E` (`10:05-11:20`), `F` (`11:20-12:35`), `H` (`13:10-14:25`), `I` (`14:25-15:40`), `J` (`15:40-16:55`), `K` (`19:00-20:20`). Splits multi-line or `;`-separated cells and matches `<COURSE_CODE> <TEACHER_CODE|PENDING|TBA|TBD|UNASSIGNED|FACULTY-PENDING> <ROOM>` where `COURSE_CODE` matches `^[A-Z]{2,5}[- ]?\d{3,4}[A-Z]?$`.
  2. **`Tabular workbook` (fallback when day sheets yield 0 rows):** Scans rows `1..40` on every sheet for required headers (`day` or sheet-inferred day, `time` or `start`+`end`, `subject`/`code`, `teacher`/`teacher name`, `batch`+`section`, optional `semester`).
- **Validation & Normalization Strictly in Dart Today:**
  - `ClockTime.normalize()` & `ClockTime.repairSequence()` (`clock_time.dart`): converts Excel fractional day serials (`0 <= x < 1`), inherits trailing AM/PM across endpoints (`9-10PM`), shifts bare afternoon hours `1–7` to `13:00–19:00`, and repairs monotonic sequence order across columns.
  - `RoomIdentity.key(label, aliases: ...)` (`room_identity.dart`): normalizes whitespace/case and resolves alias chains (guarding against cycles).
  - `_semesterFor(batch, maxBatch)`: `(maxBatch - n + 1).clamp(1, 8)` when tabular `semester` column is absent.
  - `_validate(rows)`: computes `teacher_clashes`, `cohort_clashes` (splits joint sections on `+`), `room_clashes` (ignores `'TBA'`), `invalid_time_slots`, `pending_faculty_assignments`, `unresolved_faculty_names`, `unavailable_room_assignments`, and sets `ok: true` iff `unavailableAssignments == 0 && invalidTimes == 0 && teacherClashes == 0 && cohortClashes == 0 && roomClashes == 0`.
- **Coupling to `UploadRoutineScreen` & `publish_routine`:**
  - `UploadRoutineScreen` (`upload_routine_screen.dart`) delegates directly to `RoutineUploadController`:
    1. `parse()` fetches `TimetableConfigService.buildEngineConfig()` (for `settings.periods`, `settings.semester_label`, and `teachers` acronyms->names) and `TimetableEngineService.fetchSubjectTitleMap()` (from existing `routines` rows), then runs `RoutineWorkbookParser.parse(...)`.
    2. `publish()` validates via `blockingValidationErrorFor(_result?.validation)`, then executes:
       - Step 1: `TimetableEngineService.uploadWorkbook()` -> uploads `.xlsx` to Supabase Storage bucket **`timetables`** *(note: `upload_routine_screen.dart:268` UI copy misleadingly labels this `routine-workbooks bucket`, while the actual bucket constant is `AppConstants.bucketTimetables = 'timetables'`)*.
       - Step 2: `TimetableEngineService.publishToRoutines(..., source: 'upload')` -> enforces `!rows.any((r) => r.requiresSharedTeacherStorage)`, then calls RPC `publish_routine`.
       - Step 3 (best-effort): `recordRun(..., status: 'published')` into `timetable_runs`, plus `NotificationService().createBroadcast(...)` into `notifications`.

### 4.2 Engine Payload Assembly (`generation_profile.dart`, `timetable_config_service.dart`, `timetable_engine_service.dart`, `timetable_gen_controller.dart`, `engine_connectivity_service.dart`)

#### Engine `config` JSON Payload (`TimetableConfigService.buildEngineConfig()`)

Sent as the `config` string form field on `POST /api/timetable/generate` (unless overridden by a loaded `GenerationProfile`):

```json
{
  "rooms": [
    { "name": "ACL-1", "is_lab": true, "is_gallery": false, "capacity": 45 }
  ],
  "teachers": [
    { "acronym": "EBH", "full_name": "Md. Ebrahim Hossain", "dept": "CSE", "off_days": ["Thursday", "Friday"] }
  ],
  "eligibility": [
    { "acronym": "EBH", "course_code": "CSE-1101", "eligible": true, "priority": 1 }
  ],
  "days": ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"],
  "settings": {
    "semester_label": "Summer 2025",
    "periods": [
      { "idx": 1, "label": "08:50-10:05", "start": "08:50", "end": "10:05", "col": "D" }
    ],
    "weeks_in_term": 14,
    "fixed_sessions_per_week": 2,
    "blocked_periods": { "Friday": [4] },
    "online_periods": [7],
    "allow_online_periods": false,
    "excluded_periods": [],
    "semester_map": {},
    "friday_no_p4": true,
    "service_scope": "resource_only",
    "weights": { "different_days": 8, "compactness": 3, "spread": 2, "late_slot": 1 }
  }
}
```
*Note:* `buildEngineConfig()` normalizes `periods` via `ClockTime.toHm()` (`HH:MM`, because `engine/render.py` splits on `:` into exactly 2 fields). Phase A extended fields (`classification`, `boundCourseCodes`, `declaredWindowMatrix`, `slotMatrix`, `employmentType`, `sustCompactnessMode`, `isSustAdjunctExplicit`, `isExternalGuestExplicit`, `hasExternalBlockExplicit`) are **not** included in `buildEngineConfig()`.

#### Rehearsal `GenerationProfile` & Draft Format (`generation_profile.dart`, `timetable_gen_controller.dart`)

```typescript
// Input profile JSON validated client-side (max 1 MB UTF-8, CRC32 + byte length verified against .xlsx):
export interface GenerationProfileV1 {
  format: 'universe-generation-profile-v1';
  label: string;
  provenance: string;
  source_crc32: number;  // unsigned 32-bit CRC32 of raw .xlsx bytes
  source_bytes: number;  // raw .xlsx byte length
  meeting_count_policy: 'distribution' | 'fixed'; // 'distribution' nulls fixed_sessions_per_week
  config: {
    rooms: Array<{ name: string; is_lab?: boolean; is_gallery?: boolean; capacity?: number }>;
    teachers: Array<Record<string, unknown>> | Record<string, unknown>;
    days: string[];
    room_aliases?: Record<string, string>;
    settings: {
      periods: Array<{ idx: number; col: string; start: string; end: string }>; // 24h HH:MM
      weeks_in_term: number; // >= 1
      fixed_sessions_per_week?: number | null;
      [key: string]: unknown;
    };
  };
}
```
- Loading a `GenerationProfile` forces `isPrivatePreview = true`, blocking `publish()` and `uploadWorkbook()`, and restricts saving to local JSON (`format: 'universe-routine-draft-v1'`, `rows: allRows.map(toDraftMap)`).

#### Persisted Distribution Revision Flow (`TimetableEngineService.generateAcceptedDistributionRevision`)

1. Calls RPC `read_course_distribution_revision(target_revision: revisionId)`.
2. Base64-decodes `source_bytes_base64` into `Uint8List`.
3. Extracts `source_contract` (`source_id`, `revision_id`, `revision_number`, `revision_version`, `status`, `source_sha256`, `corrections`) and submits both `file` and `source_contract` to `POST /api/timetable/generate`.

#### Polling, Timeouts & Error Handling (`engine_connectivity_service.dart`, `timetable_engine_service.dart`, `timetable_gen_controller.dart`)

| Operation | Timeout / Interval | Retry / Error Behavior |
|---|---|---|
| Engine Health Check (`GET /`) | `5s` | Expects HTTP `200` and `body['ok'] == true && body['service'] == 'universe-timetable-engine'`. |
| `POST /api/timetable/generate` | `90s` (`_http.send` + `Response.fromStream`) | Throws on non-`200` or missing `job_id`. Client passes `time_limit_s = 180` (`TimetableGenController._solveTimeLimitS`). |
| `GET /api/timetable/status/{job_id}` | `90s` per request; `_pollInterval = 2s`; `_maxPolls = 240` (~8 min) | If error contains `'429'`: waits extra `4s` and does **not** increment failure counter. Non-`429` poll errors tolerate up to `4` consecutive failures; rethrows on 5th (`~10s`). |
| `GET /api/timetable/result/{job_id}` | `90s` | Throws on non-`200`. |
| `GET /api/timetable/download/{job_id}` | `90s` | Throws on non-`200`. |

#### Publication Validation & Co-Teacher Storage Gate

- **`blockingValidationErrorFor(validation)` (`timetable_gen_controller.dart:493-556`):** Blocks publishing if `validation == null`, `validation['ok'] is! bool`, `validation['ok'] == false`, or any of these 20 counters `> 0`:
  `missing_courses`, `under_scheduled`, `over_scheduled`, `unexpected_courses`, `teacher_clashes`, `cohort_clashes`, `room_clashes`, `same_day_sessions`, `ineligible_assignments`, `dayoff_violations`, `blocked_period_violations`, `lab_room_violations`, `unplaced_rooms`, `lab_theory_violations`, `invalid_time_slots`, `invalid_days`, `teacher_assignment_mismatches`, `unknown_rooms`, `room_capacity_violations`, `unresolved_teachers`.
- **Co-Teacher Publication Check (`routine_model.dart:82-90`, `timetable_gen_controller.dart:361-363`, `timetable_engine_service.dart:306-309`):**
  - `RoutineEntry.fromMap` reads `coTeacherCodes` from `map['teachers'] ?? map['teacher_codes']`.
  - `RoutineEntry.teacherCodes` merges `[teacherCode, ...coTeacherCodes]` (unique, non-empty).
  - `RoutineEntry.requiresSharedTeacherStorage` evaluates `teacherCodes.any((c) => c != teacherCode)`.
  - Both `TimetableGenController.blockingValidationError` and `TimetableEngineService.publishToRoutines()` throw/refuse publication if **any** row (including `service_rows`) has `requiresSharedTeacherStorage == true`, because `public.routines` and `publish_routine` store only a single `teacher_code` scalar column and cannot persist co-teachers.

### 4.3 Catalog & Config Persistence Matrix (`timetable_config_service.dart` vs `academic_config_service.dart`)

| Feature / Entity | Service & Methods | Persistence Backing Today | Exact Gaps / Caveats Observed in Code |
|---|---|---|---|
| **Courses Catalog (`CatalogCourse`)** | `TimetableConfigService`: `fetchCatalogCourses`, `createCatalogCourse`, `updateCatalogCourse`, `deleteCatalogCourse` | **In-Memory Seeded Only** (`_inMemoryCourses`, 17 hardcoded items) | Zero Supabase reads or writes. All edits reset on reload/restart. |
| **Batches & Offerings (`CohortBatch`, `BatchCourseOffering`)** | `TimetableConfigService`: `fetchBatches`, `createBatch`, `updateBatch`, `deleteBatch` | **In-Memory Seeded Only** (`_inMemoryBatches`: `batch-58`, `batch-59`, `batch-60`) | Zero Supabase reads or writes. `BatchCourseOffering` & R1/R2 weekend fields live only in Dart memory. |
| **Native Catalog Distribution Bridge** | `TimetableConfigService`: `synthesizeDistributionFromCatalog`, `importCatalogFromDistributionRows`, `exportCatalogToWorkbookSummary` | **In-Memory Only** | Reads/writes `_inMemoryCourses` and `_inMemoryBatches`. Also in `GenerateTimetableScreen` (lines 308-349): `"Synthesize & Generate Routine"` only shows a SnackBar and calls `_controller.generate()` which immediately returns when `_fileBytes == null`; `"Export .xlsx Summary"` only displays a summary count SnackBar (no `.xlsx` bytes produced). |
| **Rooms (`TimetableRoom`)** | `TimetableConfigService`: `fetchRooms`, `createRoom`, `updateRoom`, `deleteRoom` | **Hybrid (Live Supabase `timetable_rooms` + In-Memory Seeded Fallback + Silent Schema Mismatch)** | 1) `fetchRooms` merges DB rows into static `_inMemoryRooms` (seeded with 8 dummy rooms `Room 301..Gallery 1`) without removing seeded rooms absent from DB.<br>2) `TimetableRoom.toMap()` emits Phase A columns **`classification`, `building_and_floor`, `in_active_semester_pool`, `bound_course_codes`, `declared_window_matrix`**, which **do not exist** in `public.timetable_rooms` (`20261021214512_reconstructed_baseline.sql:212-221` + `20261022140809:97`). DB inserts/updates with those keys fail and are silently swallowed by `try { ... } catch (_) {}`.<br>3) `ManageRoomsScreen` also keeps `_labAvailability` and `_physicsBoundCourses` strictly in widget memory (`manage_rooms_screen.dart:49-51`). |
| **Faculty (`TimetableFaculty`)** | `TimetableConfigService`: `fetchFaculty`, `createFaculty`, `updateFaculty`, `deleteFaculty` | **Hybrid (Live Supabase `timetable_faculty` + In-Memory Seeded Fallback + Silent Schema Mismatch)** | 1) `fetchFaculty` merges DB rows into static `_inMemoryFaculty` (8 seeded records) without clearing missing seeded entries.<br>2) `TimetableFaculty.toMap()` emits Phase A columns **`employment_type`, `is_sust_adjunct`, `sust_compactness_mode`, `is_external_guest`, `has_external_block`, `slot_matrix`**, which **do not exist** in `public.timetable_faculty` (`20261021214512:199-208` + `20261022140809:95`). Full profile saves silently fail against Supabase and remain in memory only; only `TimetableFacultyController.save()` (updating just `full_name` and `off_days`) writes cleanly.<br>3) `ManageFacultyScreen` keeps `_slotMatrixState` and `_sustBreakPreference` in widget memory (`manage_faculty_screen.dart:48-50`). |
| **Course Eligibility (`TimetableCourseEligibility`)** | `TimetableConfigService`: `fetchEligibility`, `saveEligibilityFor`, `fetchCourseCatalog` | **Live Supabase (`timetable_course_eligibility`)** | `saveEligibilityFor` deletes by `acronym` and inserts rows where `is_eligible == true`. Note: `ManageCourseEligibilityScreen` UI mixes `_controller.catalog` with `SchedulingPreviewFixtures.records` and local `_courseQualifications` map (`manage_course_eligibility_screen.dart:76,93,121`). |
| **Timetable Settings (`TimetableSettings`)** | `TimetableConfigService`: `fetchSettings`, `saveSettings` | **Live Supabase (`timetable_settings`, `id = 1`)** | Upserts singleton row `id = 1`. Falls back to `const TimetableSettings()` on error/offline. |
| **Canonical Academic Schema v1** | `AcademicConfigService` (`academic_config_service.dart`) | **Live Supabase (`20261022140809_academic_catalog.sql`)** | Implements `academic_catalog()`, `save_academic_alias()`, `review_academic_alias()`, `replace_academic_alias_members()`, and upserts on `departments`, `academic_calendars`, `academic_years`, `programs`, `academic_terms`, `cohorts`, `student_groups`, `cohort_terms`, `scheduling_scopes`, plus `updateFaculty`/`updateRoom`. **Not yet wired to any admin screen or `TimetableConfigService` legacy CRUD.** |
| **Course Distribution Contract (Phase 2a)** | `SupabaseSchedulingWorkspaceGateway` (`scheduling_workspace_controller.dart`) + `TimetableEngineService.fetchAcceptedDistributionRevision` | **Schema Implemented in SQL (`20261106130000_course_distribution_contract.sql`); Client Gateway Locked & Mismatched** | `SchedulingWorkspaceController` defaults to `WorkspaceCapabilityState.allLocked` (all 4 Gates A–D `false`). Moreover, `SupabaseSchedulingWorkspaceGateway` has two direct contract mismatches against SQL:<br>1) `fetchAvailableScopesAndRevisions` selects `version, scope_id` from `course_distribution_revisions`, whereas SQL columns are `revision_version` (on `course_distribution_revisions`) and `scheduling_scope_id` (on `course_distribution_sources`).<br>2) `appendCellCorrection` calls `append_course_distribution_correction` with 6 `p_*` params expecting a JSON map, whereas SQL (`20261106130000:125-175`) defines 8 params (`target_revision`, `expected_revision_version`, `target_row`, `target_column`, `prior_formula`, `prior_cached_value`, `next_effective_value`, `reason`) returning `uuid`. *(By contrast, `TimetableEngineService.fetchAcceptedDistributionRevision` matches `read_course_distribution_revision(target_revision)`.)* |

### 4.4 Supabase Tables, RPCs, Edge Functions & Storage Buckets Touched by Admin

#### A. PostgreSQL Tables (`public` schema)

| Table Name | Admin Columns Read / Written | Operations Used by Admin | Source Service(s) |
|---|---|---|---|
| `profiles` | `id`, `email`, `role`, `name`, `avatar_url`, `batch`, `section`, `semester`, `student_id`, `teacher_code`, `designation`, `department`, `courses`, `created_at` (+ canonical UUIDs `department_id`, `program_id`, `cohort_id`, `student_group_id`, `faculty_id`) | `SELECT` (count, list, own profile), `INSERT`/`UPSERT` (post-login), `UPDATE` (`role`) | `AdminService`, `AuthService` |
| `whitelists` | `email`, `role`, `name`, `teacher_code`, `batch`, `section`, `semester`, `department`, `designation` | `SELECT`, `UPSERT` (`onConflict: 'email'`), `DELETE` | `AdminService`, `AuthService`, `invite-admin` Edge Function |
| `routines` | `id`, `day`, `time_start`, `time_end`, `subject`, `subject_code`, `teacher_name`, `teacher_code`, `room`, `batch`, `section`, `semester`, `is_active`, `is_service`, `routine_version_id` (+ canonical UUIDs) | `SELECT`, `INSERT`, `UPDATE`, `DELETE`, full atomic replace via `publish_routine` RPC | `RoutineService`, `AdminService`, `TimetableEngineService`, `TimetableConfigService` |
| `routine_versions` | `id`, `semester_label`, `source`, `is_active`, `row_count`, `stats`, `validation`, `notes`, `published_at`, `published_by`, `created_at` | `SELECT` (`is_active = true`), `INSERT`/`UPDATE` inside `publish_routine` RPC | `TimetableEngineService`, `012_routine_versions.sql` |
| `timetable_runs` | `id`, `semester_label`, `file_path`, `stats`, `validation`, `row_count`, `status`, `created_by`, `created_at` | `INSERT` (`recordRun`) | `TimetableEngineService` |
| `timetable_rooms` | DB columns: `id`, `name`, `building`, `is_lab`, `is_gallery`, `capacity`, `is_active`, `dept`, `campus`, `features` *(Dart `toMap()` also emits non-DB Phase A fields)* | `SELECT`, `INSERT`, `UPDATE`, `DELETE` | `TimetableConfigService`, `AdminService`, `AcademicConfigService` |
| `timetable_faculty` | DB columns: `id`, `acronym`, `full_name`, `dept`, `designation`, `off_days`, `is_active`, `courses`, `home_department_id` *(Dart `toMap()` also emits non-DB Phase A fields)* | `SELECT`, `INSERT`, `UPDATE`, `DELETE` | `TimetableConfigService`, `AcademicConfigService` |
| `timetable_course_eligibility` | `id`, `acronym`, `course_code`, `is_eligible`, `priority`, `created_at`, `updated_at` | `SELECT`, `DELETE` (by `acronym`), `INSERT` | `TimetableConfigService`, `AdminService` |
| `timetable_settings` | `id` (`1`), `semester_label`, `periods`, `working_days`, `weeks_in_term`, `fixed_sessions_per_week`, `blocked_periods`, `online_periods`, `allow_online_periods`, `excluded_periods`, `semester_map`, `friday_no_p4`, `service_scope`, `weights` | `SELECT` (`eq('id', 1)`), `UPSERT` | `TimetableConfigService` |
| `notifications` | `id`, `type`, `title`, `body`, `sent_by`, `target_role`, `target_batch`, `target_section`, `created_at` | `SELECT`, `INSERT`, `DELETE` | `NotificationService`, `AdminService` |
| `resources` | `id`, `title`, `category`, `semester`, `subject_code`, `file_url`, `drive_link`, `uploaded_by`, `created_at` | `SELECT`, `INSERT`, `DELETE` | `ResourceService` |
| `course_distribution_sources`, `course_distribution_revisions`, `course_distribution_corrections`, `course_distribution_artifacts` | `id`, `scheduling_scope_id`, `source_hash`, `source_bytes`, `sheet_name`, `source_id`, `parent_revision_id`, `revision_number`, `revision_version`, `status`, `correction_reason`, `source_row`, `source_column`, `original_formula`, `original_cached_value`, `effective_value` | `SELECT` (availability probe in `SchedulingWorkspaceController`), RPC read/append (`20261106130000`) | `SchedulingWorkspaceController`, `TimetableEngineService` |
| `departments`, `academic_calendars`, `academic_years`, `programs`, `academic_terms`, `cohorts`, `student_groups`, `cohort_terms`, `scheduling_scopes`, `group_aliases`, `group_alias_members` | Canonical schema v1 columns (`20261022140809_academic_catalog.sql`) | `UPSERT` + RPCs (implemented in `AcademicConfigService`, not yet wired to admin UI) | `AcademicConfigService` |
| `timetable_courses` *(baseline table)* | `id`, `code`, `title`, `batch`, `section`, `dept`, `is_lab`, `file_teacher`, `assigned_teacher`, `updated_at` | **Not touched by any Dart admin service** (`ManageCoursesScreen` uses in-memory `_inMemoryCourses`) | `20261021214512_reconstructed_baseline.sql` |

#### B. PostgreSQL RPC Functions

| RPC Name | SQL Parameter Signature | Call Sites & Notes |
|---|---|---|
| `publish_routine` | `(p_rows jsonb, p_semester_label text default null, p_source text default 'engine', p_stats jsonb default '{}'::jsonb, p_validation jsonb default '{}'::jsonb, p_notes text default null) -> jsonb` (`{version_id, row_count}`) | `TimetableEngineService.publishToRoutines()`. Admin-only (`public.is_admin()`). Atomically deactivates prior `routine_versions`, runs `delete from public.routines where true`, inserts `p_rows`, activates new version. |
| `read_course_distribution_revision` | `(target_revision uuid) -> jsonb` | `TimetableEngineService.fetchAcceptedDistributionRevision()`. Returns `{source_id, revision_id, revision_number, revision_version, status, source_sha256, source_bytes_base64, sheet_name, corrections}`. Requires scoped `read_catalog`. |
| `append_course_distribution_correction` | `(target_revision uuid, expected_revision_version integer, target_row integer, target_column text, prior_formula jsonb, prior_cached_value jsonb, next_effective_value jsonb, reason text) -> uuid` | `SupabaseSchedulingWorkspaceGateway.appendCellCorrection()` (locked behind Gate B; currently passes mismatched `p_*` param names). Requires scoped `edit_draft`. Raises `40001` on version conflict. |
| `academic_catalog` | `() -> jsonb` | `AcademicConfigService.fetchCatalog()`. |
| `save_academic_alias` | `(p_id uuid, p_cohort_id uuid, p_label text, p_group_ids uuid[]) -> void` | `AcademicConfigService.saveAlias()`. |
| `review_academic_alias` | `(p_alias_id uuid) -> void` | `AcademicConfigService.reviewAlias()`. |
| `replace_academic_alias_members` | `(p_alias_id uuid, p_group_ids uuid[]) -> void` | `AcademicConfigService.replaceAliasMembers()`. |
| `apply_academic_mapping` | `(p_mapping_id uuid) -> jsonb` | Defined in `20261022140809`; no Dart client caller found. |

#### C. Supabase Edge Functions

| Function Slug | Invoked From | Purpose & Auth |
|---|---|---|
| `invite-admin` | `AdminService.inviteAdmin` | Caller JWT verified + `profiles.role === 'admin'`; upserts `whitelists` (`role='admin'`) and calls `inviteUserByEmail`. |

#### D. Supabase Storage Buckets (`lib/core/constants/app_constants.dart:121-124`)

| Bucket Constant & Name | Admin Upload Path Convention | Content-Type & Access Method |
|---|---|---|
| `bucketTimetables` (`'timetables'`) | `CSE_Routine_<safe_semester_label>_<epoch_ms>.xlsx` (`TimetableEngineService.uploadWorkbook`) | `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`, `upsert: true`. |
| `bucketResources` (`'resources'`) | `<semester>/<epoch_ms>_<sanitized_filename>` (`ResourceService.uploadFile`) | Mapped by extension (`.pdf`, `.png`, `.jpg`, `.jpeg`, `.doc`, `.docx`, `.ppt`, `.pptx`, `.xls`, `.xlsx`, `.zip`, fallback `application/octet-stream`). Uses `getPublicUrl(path)`. |
| `bucketAvatars` (`'avatars'`) | Shared profile avatars (not uploaded via admin-only controllers) | Public read per RLS `storage_public_read`. |

---

## Section 5: Complete Current Admin Screen & Route Inventory

**Inspected files:** [`lib/core/router/route_names.dart`](../../lib/core/router/route_names.dart), [`lib/core/router/app_router.dart`](../../lib/core/router/app_router.dart), [`lib/core/router/app_shell.dart`](../../lib/core/router/app_shell.dart), [`lib/features/admin/widgets/admin_desktop_shell.dart`](../../lib/features/admin/widgets/admin_desktop_shell.dart), [`lib/features/admin/screens/admin_routine_screen.dart`](../../lib/features/admin/screens/admin_routine_screen.dart), [`lib/features/admin/screens/scheduling_workspace_screen.dart`](../../lib/features/admin/screens/scheduling_workspace_screen.dart), [`lib/features/admin/widgets/admin_route_tabs.dart`](../../lib/features/admin/widgets/admin_route_tabs.dart), and all `lib/features/admin/screens/*.dart`.

| Route Path | Screen / Widget | Shell / Navigation Location | Query Params / `GoRouterState.extra` | Current Data Source Classification | Implementation Notes |
|---|---|---|---|---|---|
| `/admin/dashboard` | `AdminDashboardScreen` | Sidebar: `TIMETABLE ENGINE` → `Dashboard` | None | **Live Supabase** (`AdminService.counts()`) | Reads counts from `profiles`, `routines`, `notifications`, `timetable_rooms`, `timetable_course_eligibility`. |
| `/admin/routine` | `AdminRoutineScreen` (4-tab shell) | Sidebar: `Routine Operations` (`tab=manage` or default) | `tab=manage \| grid \| generate \| upload` (default `manage`) | Depends on active tab (below) | Houses compact banner linking to `/admin/scheduling`. |
| `/admin/routine?tab=manage` | `RoutineManagementScreen` | `AdminRoutineScreen` Tab 1 (`Manage Published`) | `tab=manage` | **Live Supabase** (`routines` table via `RoutineService`) | Full CRUD on live published `routines` rows. |
| `/admin/routine?tab=grid` | `TimetableGridScreen` (`embedded: true`) | `AdminRoutineScreen` Tab 0 (`Operational 2D Grid`) | `tab=grid` | **Live Supabase** with **Preview Fixtures Fallback** | Reads `RoutineAdminController` / `RoutineService.fetchAll()`; falls back to `SchedulingPreviewFixtures.candidateRoutineRows` if empty or error. |
| `/admin/routine?tab=generate` | `GenerateTimetableScreen` (`embedded: true`) | Sidebar sub-item `• Generate Timetable` & Header CTA | `tab=generate` | **Hybrid: In-Memory Seeded + Live FastAPI + Live Supabase** | Mode 0 (`UI Catalog & Batch Offerings`) calls in-memory `synthesizeDistributionFromCatalog()` (broken `.xlsx` handoff). Mode 1 (`.xlsx` upload / `GenerationProfile` / accepted revision) uses **Live FastAPI** + **Live Supabase** (`publish_routine`, `timetables` bucket, `timetable_runs`, `notifications`). |
| `/admin/routine?tab=upload` | `UploadRoutineScreen` (`embedded: true`) | Sidebar sub-item `• Upload Routine` | `tab=upload` | **Live Supabase** (client-side parse + DB/Storage publish) | Parses `.xlsx` in Dart (`RoutineWorkbookParser`), uses `buildEngineConfig()` & `fetchSubjectTitleMap()`, publishes via `timetables` bucket + `publish_routine` + `timetable_runs` + `notifications`. |
| `/admin/timetable/grid` | `TimetableGridScreen` | Sidebar: `Routine Preview` | `extra`: `TimetablePreview` or `List<RoutineEntry>?` | **Live Supabase** (when navigated directly & DB non-empty) or **Caller `extra` / Preview Fixtures Fallback** | Same fallback to `SchedulingPreviewFixtures.candidateRoutineRows` when `extra` is null and `fetchAll()` returns empty/throws. |
| `/admin/scheduling` | `SchedulingWorkspaceScreen` (5 tabs: `Distribution`, `Configuration`, `Readiness`, `Generate`, `Review & publish`) | Sidebar: `Scheduling Workbench · Preview` | None (in-screen `TabController` + mode toggle) | **Live Supabase Probe + Preview Fixtures Only** | Live Backend mode checks `course_distribution_revisions` (`status='accepted'`), then renders fail-closed `_CapabilityUnavailable` gates for all 5 tabs (`WorkspaceCapabilityState.allLocked`). Design Preview toggle loads `SchedulingPreviewFixtures` (or in-memory `synthesizeDistributionFromCatalog()`). |
| `/preview/scheduling` | `SchedulingWorkspaceScreen(initialPreviewMode: true)` | Deep link / dev preview route (outside `ShellRoute`) | `tab=configuration \| readiness \| generate \| review` (default `0`), `row=<int>` | **Preview Fixtures Only** (`SchedulingPreviewFixtures`) | Unauthenticated in debug or when `ENABLE_SCHEDULING_PREVIEW_ROUTE=true`; otherwise requires `authenticated` + `admin`. Zero DB writes. |
| `/admin/timetable/courses` | `ManageCoursesScreen` | Sidebar: `CONFIGURATION` → `Courses` | None | **In-Memory Seeded** (`_inMemoryCourses`) | Phase A Course Catalog CRUD. No Supabase persistence. |
| `/admin/timetable/batches` | `ManageBatchesScreen` | Sidebar: `CONFIGURATION` → `Batches & Sections` | None | **In-Memory Seeded** (`_inMemoryBatches`) | Phase A Cohort Batch, Section, Joint Section & Offering CRUD. No Supabase persistence. |
| `/admin/timetable/faculty` | `ManageFacultyScreen` | Sidebar: `CONFIGURATION` → `Faculty` | None | **Hybrid: Live Supabase + In-Memory Seeded + Widget Memory** | Basic fields (`acronym`, `full_name`, `dept`, `designation`, `off_days`, `is_active`) read/write `timetable_faculty`; extended Phase A fields & `_slotMatrixState` / `_sustBreakPreference` fail silently on DB write and stay in memory. |
| `/admin/timetable/rooms` | `ManageRoomsScreen` | Sidebar: `CONFIGURATION` → `Room Pools` | None | **Hybrid: Live Supabase + In-Memory Seeded + Widget Memory** | Basic fields (`name`, `building`, `is_lab`, `is_gallery`, `capacity`, `is_active`) read/write `timetable_rooms`; extended Phase A fields & `_labAvailability` / `_physicsBoundCourses` fail silently on DB write and stay in memory. |
| `/admin/timetable/course-eligibility` | `ManageCourseEligibilityScreen` | Sidebar: `CONFIGURATION` → `Course Eligibility` | None | **Hybrid: Live Supabase + Preview Fixtures** | `CourseEligibilityController` reads/writes `timetable_course_eligibility` & `routines`; screen also seeds `_getCourseCatalog()` and `_courseQualifications` from `SchedulingPreviewFixtures.records`. |
| `/admin/timetable/settings` | `TimetableSettingsScreen` | Sidebar: `CONFIGURATION` → `Timetable Settings` | None | **Live Supabase** (`timetable_settings` singleton `id=1`) | Persists working days, periods, `weeks_in_term`, `fixed_sessions_per_week`, `blocked_periods`, `online_periods`, `excluded_periods`, `semester_map`, weights. |
| `/admin/broadcast` | `CampusBroadcastScreen` | Sidebar: `COMMUNICATION & USERS` → `Campus Broadcast` | None | **Live Supabase** (`notifications`) | `AdminRouteTabs` links to `/admin/broadcast/history`. |
| `/admin/broadcast/history` | `BroadcastHistoryScreen` | `AdminRouteTabs` sibling under `/admin/broadcast` | None | **Live Supabase** (`notifications`) | Lists and deletes broadcasts. |
| `/admin/users` | `ManageUsersScreen` | Sidebar: `COMMUNICATION & USERS` → `User Whitelist` | None | **Live Supabase** (`profiles`) | Reads/filters all profiles and updates `profiles.role`. `AdminRouteTabs` links to `/admin/registration`. |
| `/admin/registration` | `AdminRegistrationScreen` | `AdminRouteTabs` sibling under `/admin/users` | None | **Live Supabase + Edge Function** | Invokes `invite-admin` Edge Function; adds teachers to `whitelists`; deletes from `whitelists`. |
| `/admin/resources` | `ManageResourcesScreen` | Sidebar: `COMMUNICATION & USERS` → `Academic Resources` | None | **Live Supabase + Storage** (`resources`, `notifications`, `resources` bucket) | Uploads resource files / drive links and optionally notifies students. `AdminRouteTabs` links to `/admin/resources/library`. |
| `/admin/resources/library` | `ResourceLibraryScreen` | `AdminRouteTabs` sibling under `/admin/resources` | None | **Live Supabase** (`resources`) | Filters by semester/category and deletes resource records. |
| `/profile` *(shared route)* | `ProfileScreen` | Sidebar: `COMMUNICATION & USERS` → `Admin Profile` & Header account menu | None | **Live Supabase** (`profiles` + `avatars` bucket) | Shared role screen hosted inside `AdminDesktopShell` when `role == 'admin'`. |
| `/rooms`, `/rooms/detail`, `/find-teacher`, `/find-teacher/detail`, `/notifications` *(shared routes)* | `RoomsScreen`, `RoomDetailScreen`, `FindTeacherScreen`, `TeacherDetailScreen`, `NotificationsScreen` | Reachable inside `ShellRoute` (`campusRoutes()` / push tap), not listed in `AdminDesktopShell` sidebar | `room`, `code`/`name`/`dept`/`desig` | **Live Supabase** (`routines`, `cancellations`, `notifications`, `notification_reads`) | Shared campus/notification routes allowed for `role == 'admin'` in `AppRouter`. |
