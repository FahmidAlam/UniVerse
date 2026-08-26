# CLAUDE.md — UniVerse Project Context
> Load this at the start of every session. Dense reference only — no fluff.
> Last updated: August 2026 — **feature-complete + polished; defense-ready.**
> The app is BUILT and runs end-to-end (auth · routine · **student/teacher dashboards** ·
> resources hub w/ **admin upload + semester folders** · notifications w/ **live push** ·
> profile · admin · **teacher Manage Classes (cancel/notice)** · **automatic timetable
> generator deployed live** · **Find Teacher + Room Availability — real-time campus explore
> w/ per-room & per-teacher weekly detail** · **admin Upload Routine (workbook → publish)**
> · **side drawer on all dashboards**).
> AI assistant is **DESCOPED** (future scope — see that section).
> ⚙️ `polish/defense-prep` branch merged to `main` (commit f886b2c). All features are on
> `main`. The agent never pushes — Fahmid merges + rebuilds the APK.

---

## ⚠️ READ FIRST — GUARDRAILS FOR AI AGENTS & TEAMMATES

This is a working, demo-ready app with a **live backend**. We are polishing, not
re-architecting. Before changing anything, respect these — breaking them breaks the
whole system or the defense build.

**Never change without doing the matching change everywhere:**
- **Engine row shape ↔ `routines` columns.** The Python engine emits rows shaped
  exactly like the `routines` table; the app publishes them with a direct insert.
  Changing one side silently breaks publish. (See TIMETABLE ENGINE.)
- **Config tables (`timetable_rooms` / `timetable_faculty` / `timetable_settings`).**
  Edited by admin screens, read by `TimetableConfigService.buildEngineConfig()`, and
  consumed by the engine's `_normalize_config()`. Rename a column → update all three.
- **DB schema / RLS / Storage buckets.** Only the `services/` layer touches Supabase.
  Any SQL change needs the matching Dart service + an `app_constants` table constant.
- **`TIMETABLE_BASE_URL` default** in `app_constants.dart` — the shipped APK depends on
  it pointing at the live engine. Don't change it without rebuilding the APK.
- **Week days = Sun–Sat (7 days).** `AppConstants.weekDays`/`weekDaysShort` are the single
  source of truth and MUST match the engine `config.json` "days" order. The university
  teaches all 7 days (Friday has no period 4). Every controller maps `DateTime.weekday`→day
  via these — never reintroduce a Sun–Thu (5-day) assumption.
- **`cancellations` table (migration 007) is LIVE.** Teacher Manage Classes writes one
  dated row (`routine_id`+`class_date`) per cancelled occurrence AND a `class_cancel`
  notification. Insert shape ↔ `TeacherService.cancelClass`. (Legacy DBs had a
  `cancel_date NOT NULL` column; 007 relaxes it; migration 009 drops the legacy column.)
- **Notifications ⇒ push (automatic).** Any INSERT into `notifications` fires the deployed
  `send-push` Edge Function (DB webhook) → OS push to the audience. Creating a notification
  row = in-app alert + push; don't add a second push path.
- **`FindTeacherService` + `RoomStatusService` read only `routines` + `cancellations`.**
  They derive live/next state from the current time vs the weekly schedule. No extra tables.
- **Clock text ⇒ always through `ClockTime` (`core/utils/clock_time.dart`).** Period
  boundaries arrive hand-typed ("13:10", "1:50", "1:50 PM"). A bare `1:50` written
  straight to Postgres lands as **01:50 — 1:50 AM**, which put afternoon classes in the
  middle of the night. Both producers of `routines` rows (the workbook uploader AND
  `buildEngineConfig()`) normalize with it. **Two different output shapes — do not mix
  them up:** Postgres gets `HH:MM:SS`; the **engine gets `HH:MM` only**, because
  `render.py::_fmt_clock` unpacks with `h, m = hhmm.split(":")` and a third field aborts
  the job with "too many values to unpack (expected 2)". Covered by `test/clock_time_test.dart`.
- **Never commit a merge with conflict markers.** It has happened (commit `893d96f`
  shipped `>>>>>>> origin/main` inside four `.dart` files and broke every build). After
  any merge: `grep -rn "^<<<<<<< \|^>>>>>>> " lib/ engine/` must return nothing, then
  `flutter analyze`. Resolve additively — taking "theirs" blindly once would have deleted
  `fetchSubjectTitleMap()` (Upload Routine) and `_registerPushToken()` (push).

**Never touch / never commit:**
- Supabase URL + anon key live as defaults in `app_constants.dart` (anon key is safe to
  ship). The **service-role key lives only in the `invite-admin` Edge Function** — never
  in the app, never in git.
- **Raw distribution workbooks** (`engine/routine generation files/`) — real teacher PII
  (phone/email); gitignored. Never commit them or the explainer PDF.
- `dart_defines.json` (gitignored). `google-services.json` / `firebase_options.dart` are
  committed (Android client config, not secret).
- **Don't downgrade Gradle below 8.14** — the dev machine runs JDK 24, which needs it.
  ⚠️ **Gradle 8.14 / AGP 8.9.1 top out at Java 24.** If the machine's JDK is upgraded
  (e.g. to Temurin 25), Gradle can't parse the version and reports the bare version
  string as the whole error — `* What went wrong: 25.0.4` — with no other clue. Fix by
  pointing Flutter back at JDK 24, **not** by editing Gradle:
  `flutter config --jdk-dir "C:\Program Files\Java\jdk-24"` (verify with `flutter doctor -v`).

**Don't re-add the AI assistant** without first running the `documents` table migration
(it's intentionally descoped — see AI ASSISTANT section).

**Deployment is automatic:** push to `main` → Render rebuilds the engine. Don't deploy
manually. The engine is stateless (in-memory jobs) — no DB on the engine side.

---

## APP IDENTITY

| Field | Value |
|---|---|
| Name | **UniVerse — A Campus Companion** |
| Platform | Android (Flutter) |
| University | Leading University, Sylhet, Bangladesh |
| Department | CSE · Course CSE-3240 (Project I) · Team **Sherlocked** |
| Advisor | Jaminur Rahman |
| Flutter package | `universe` · applicationId `com.example.universe` |
| Actors | Student · Teacher · Admin |
| **Differentiator (advisor-required)** | **Automatic department timetable generator (OR-Tools CP-SAT) — DONE & deployed** |

---

## CURRENT STATUS (what's real)

| Area | State |
|---|---|
| Auth (Google OAuth + email/password, whitelist gate for admin) | ✅ complete |
| Role-aware tab navigation (AppShell + bottom nav) | ✅ complete |
| Student / Teacher routine views (from `routines`) | ✅ built |
| **Student + Teacher dashboards** (greeting · live/next-class hero w/ countdown · stats · today's list) | ✅ built (`features/dashboard/`, `features/teacher/`) |
| **Teacher Manage Classes** — cancel occurrence (+student alert/push) · post notice/room-change · undo | ✅ built (`cancellations` + migration 007) |
| Resources hub — **semester folders** (all semesters), opens files; **admin upload** (any file / Drive link) | ✅ built |
| Notifications (Realtime feed + **per-user local multi-select dismiss**) · Profile | ✅ built |
| Admin: dashboard, **Routine hub (Manage + Generate)**, broadcast, registration, users, **Manage Resources** | ✅ built |
| **Push notifications (FCM)** — `send-push` Edge Function **deployed & live** (DB webhook on `notifications` INSERT) | ✅ working (`device_tokens`) |
| **Auto-notify**: resource upload → students · routine publish → everyone | ✅ built |
| **Timetable engine (Excel→CP-SAT→workbook) + admin config + publish** | ✅ built, deployed, verified live |
| **Find Teacher** — real-time teacher locator (current room · remaining time · next class) | ✅ built (`features/find_teacher/`) |
| **Room Availability** — real-time room occupancy (current class · next class · status) | ✅ built (`features/rooms/`) |
| **Room / Teacher detail** — "More details" → full day-by-day weekly schedule | ✅ built (`weekly_schedule_view.dart`) |
| **Explore FAB** — floating "Explore Campus" button on all three dashboards | ✅ built (`shared/widgets/explore_fab_menu.dart`) |
| **App drawer** — hamburger (top-right) on all three dashboards; role-aware links + Sign Out | ✅ built (`shared/widgets/app_drawer.dart`) |
| **Admin Upload Routine** — parse a rendered workbook in-app → publish to `routines` | ✅ built (`routine_workbook_parser.dart`) |
| App icon (orbit mark via `flutter_launcher_icons`) | ✅ wired |
| AI assistant (RAG/Gemini) | ⛔ **descoped → future scope** |

---

## TEAM ROLES — FEATURE-BASED OWNERSHIP

> Each member owns vertical slices: screen + controller + service. Shared
> infrastructure (`core/`, `shared/widgets/`, `main.dart`, `pubspec.yaml`,
> `AndroidManifest.xml`, `engine/`) = **Fahmid only**.

- **Fahmid Alam** (0182320012101309) — Architecture, shared infra, auth, **admin +
  timetable engine** (`lib/features/admin/`, `engine/`), `lib/core/`,
  `lib/shared/widgets/`, build/deploy.
- **Swadheen Islam Robi** (0182320012101278) — student/teacher features:
  `lib/features/routine/`, `lib/features/resources/`, dashboards, teacher screens,
  **`lib/features/find_teacher/`**, **`lib/features/rooms/`**.
- **Shahriar Rashid Ratul** (0182320012101276) — `lib/features/notifications/`,
  `lib/features/profile/`, push, QA, seeding, README/screenshots.

**Conflict-free rule:** changes outside your feature folder → PR + tag Fahmid. Never
directly edit `app_router.dart`, `route_names.dart`, `app_constants.dart`,
`pubspec.yaml`, `app_shell.dart`.

---

## TECH STACK (current, see `pubspec.yaml`)

```
Dart SDK: >=3.0.0 <4.0.0   (toolchain in use: Flutter 3.44.9 / Dart 3.12.2)
supabase_flutter: ^2.12.4      go_router: ^17.2.3
google_sign_in: ^6.2.1         google_fonts: ^8.1.0
phosphor_flutter: REMOVED — see note below
archive: ^4.0.9                xml: ^6.6.1        (Upload Routine .xlsx parsing)
hive_flutter: ^1.1.0
flutter_local_notifications: ^17.2.2
firebase_core: ^4.10.0         firebase_messaging: ^16.3.0
file_picker: ^8.1.2            flutter_pdfview: ^1.3.2
cached_network_image: ^3.3.1   http: ^1.6.0
shared_preferences: ^2.5.5     path_provider: ^2.1.4   open_filex: ^4.5.0
url_launcher: ^6.3.2           flutter_launcher_icons: ^0.14.4 (dev)
```

> ⚠️ **Icons: `phosphor_flutter` is NOT installed.** It is commented out in
> `pubspec.yaml` and replaced by a Material-Icons shim,
> `lib/shared/widgets/utils/phosphor_compat.dart` (re-exported from
> `lib/shared/utils/phosphor_compat.dart`, which every screen imports). It exposes
> `PhosphorIcons` / `PhosphorIconsRegular` with the same member names, so existing
> `PhosphorIconsRegular.*` code compiles unchanged — but the app actually renders
> **Material** icons, not Phosphor. This was a workaround for the package breaking on the
> newer Flutter, not a design decision. **Adding a new icon means adding a member to the
> shim.** To restore real Phosphor: un-comment the dep at a Dart-3.12-compatible version,
> repoint the two `phosphor_compat.dart` files at the package, delete the shim.

### Backend / services
- **Supabase** (project ref `yxqyrjyzxitrgkhgauli`) — Postgres + Auth + Storage + Realtime.
- **Firebase** — Cloud Messaging only (Android). Configured via `firebase_options.dart`
  + `android/app/google-services.json`.
- **Timetable engine** — FastAPI + OR-Tools CP-SAT (Python), **deployed on Render free**:
  `https://universe-timetable-engine.onrender.com`.
- **Google OAuth** — via Supabase Auth, PKCE flow.
- (Gemini — only for the descoped AI assistant; not used in the build.)

### Build environment
- Gradle wrapper **8.14** (required for the dev machine's **JDK 24**). AGP **8.9.1**,
  Kotlin **2.1.0**, `com.google.gms.google-services` **4.4.2**.
- Release APK uses **debug signing** (sideloadable for the demo) — no keystore set up.
- Build: `flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk`.
- **App icon:** `flutter_launcher_icons` (config block in `pubspec.yaml`). Source PNGs in
  `assets/icon/` are generated from the splash orbit mark by `python tool/generate_app_icon.py`.
  Regenerate the Android mipmaps: `dart run flutter_launcher_icons`.

### Auth deep links
```
com.example.universe://login-callback/   ← Google OAuth + email verify
com.example.universe://reset-callback/   ← password reset
```

---

## DESIGN SYSTEM

> All tokens in `lib/core/theme/`. **Never hardcode hex or raw numbers in widgets.**

### Colors (`app_colors.dart`)
```
bgPrimary #0F0F10 · bgCard #1A1A1C · bgElevated #222325 · bgSubtle #1C1C1E
primary #FF7A00 · primaryDark #E66A00 · primarySoft #2A1A0A · primaryMuted #3D2000
textPrimary #FFFFFF · textSecondary #B0B3B8 · textMuted #6E7278 · textDisabled #4A4D52
border #2A2C30 · borderFocus #FF7A00 · borderError #EF4444 · navBg #111113
success #22C55E/successSoft #0D2E1A · info #3B82F6/infoSoft #0D1F3C
warning #F59E0B/warningSoft #2D1E00 · error #EF4444/errorSoft #2D0D0D · done #6E7278
roleStudent / roleTeacher / roleAdmin accent colors also exist.
```

### Text styles (`app_text_styles.dart`)
`h1` 24/700 · `h2` 18/600 · `h3` 16/600 · `h4` 14/600 · `body` 14/400 ·
`bodyMedium` 14/500 · `bodySm` 13/400 · `bodySmMedium` 13/500 · `chip` 12/500 ·
`label` 12/500 · `labelCaps` 11/600 caps · `caption` 11/400 · `captionMedium` 11/500 ·
`badge` 10/700 · `button` 15/600 · `link` 13/500 · `danger` 14/500 · `input` ·
`placeholder` · `countdown` · `statNumber` · `onboardTitle`. `.copyWith()` for overrides.

### Spacing (`app_spacing.dart`)
`xs4 sm8 md12 lg16 xl20 xxl24 x3l32 x4l40 x5l48` · gaps `xsGap smGap smHGap cardGap
mdGap lgGap sectionGap` · radius objects `radiusSm/Md/Lg/Xl/Xxl/Full` + doubles
`radiusSmD..radiusXlD` · `buttonHeight52 inputHeight52 chipHeight34 appBarHeight56` ·
icons `iconSm16 iconMd20 iconLg24 iconXl32` · borders `borderThin0.5 ..Thick2`.

### Theme
`AppTheme.dark` → `MaterialApp.router(theme:)`. `AppTheme.setSystemUI()` in `main()`.
Font **Inter** via `GoogleFonts.interTextTheme()` (global — never set fontFamily).
Icons: always `PhosphorIconsRegular.*`, imported from
`package:universe/shared/utils/phosphor_compat.dart` — **not** from `phosphor_flutter`,
which is no longer a dependency (see the icon note in TECH STACK).

---

## ARCHITECTURE

### Folder structure (current — all built)
```
lib/
  main.dart                       Firebase+Push init, Supabase init, router, deep links
  firebase_options.dart           generated (Android only)
  core/
    theme/  router/  constants/  models/  utils/  services/push_service.dart
  shared/widgets/                 u_* primitives + composite cards + explore_fab_menu.dart
  features/
    auth/  routine/  resources/  notifications/  profile/  admin/
    dashboard/     (student Home)
    teacher/       (teacher Home + Manage Classes)
    find_teacher/  (real-time teacher locator — secondary screen)
    rooms/         (real-time room availability — secondary screen)
```

### Layer rules (enforced)
- Screen → controller → service → Supabase. Screens/controllers **never** touch Supabase.
- Each feature: `screens/ controllers/ services/`. Shared widgets only from `shared/widgets/`.
- State: **`ChangeNotifier` + `ListenableBuilder`** only (no Riverpod/Bloc/Provider).
  `setState` for local UI only.

### Navigation (GoRouter ^17 + ShellRoute)
- Single `AppRouter` in `main.dart`; `authController` is `refreshListenable`.
- **`AppShell`** (`core/router/app_shell.dart`) owns ONE Scaffold + bottom nav for all
  top-level tabs; tab screens render content only.
- **`AppBottomNav`** (`shared/widgets/app_bottom_nav.dart`) — single source of truth for
  each role's tabs (`destinationsFor(role)`). Notification badge wired to a shared
  `NotificationController`.
- **Secondary screens** (Resources, Admin Registration, Manage Rooms/Faculty, Timetable
  Settings, Timetable Grid, **Manage Resources**, **Resource Library**, **Broadcast
  History**, **Find Teacher**, **Room Availability**) are **pushed** (back button), NOT tabs.
- **`ExploreFabMenu`** (`shared/widgets/explore_fab_menu.dart`) — FAB shown on all three
  dashboards; opens a bottom sheet with two options: **Rooms** (`/rooms`) and
  **Find Teacher** (`/find-teacher`).
- **Admin "Routine" tab = `AdminRoutineScreen` hub** — a segmented control hosting
  **Manage** (`RoutineManagementScreen`) + **Generate** (`GenerateTimetableScreen`), both
  rendered with `embedded: true` (no inner app bar). `?tab=generate` opens it on the
  generator. There is NO standalone `generateTimetable` route anymore.
- All paths are `RouteNames.*` constants. Redirect logic lives only in `AppRouter.redirect()`.
- Tab sets: **Student** Home·Routine·Alerts·Profile · **Teacher** Home·Routine·Classes·
  Alerts·Profile · **Admin** Dashboard·Broadcast·Routine·Users·Profile.
- **`AppDrawer`** (`shared/widgets/app_drawer.dart`) — right-side `endDrawer` opened by
  `UDrawerButton` (hamburger) in the top-right of all three dashboards, replacing the old
  profile-avatar action. Every role opens with **Profile · Find Teacher · Room
  Availability**, then role-specific links, then Sign Out (same confirm dialog as Profile).
  `_destinationsFor(role)` is the single source of truth, mirroring `AppBottomNav`.
  The drawer lives on each **screen's** Scaffold while the Explore FAB lives on the
  **shell's**, so they can't see each other in the tree — a shared `drawerOpenNotifier`
  (exported from `app_drawer.dart`, driven by `Scaffold.onEndDrawerChanged`) lets
  `AppShell` scale the FAB away while the drawer is open.
- **Routes added (f886b2c):** `RouteNames.rooms = '/rooms'` · `RouteNames.findTeacher = '/find-teacher'` · `RouteNames.teacherDirectory = '/teacher-directory'` (defined, not yet wired to a screen).
- **Routes added (Aug 2026):** `RouteNames.roomDetail = '/rooms/detail'` (`extra` = room
  name `String`) · `RouteNames.teacherDetail = '/find-teacher/detail'` (`extra` =
  `TeacherDetailArgs(code, name)`). Both secondary/pushed.

---

## AUTH SYSTEM (complete)

- **Google OAuth** (PKCE) + **Email/Password** (signup → email verify → signin).
- **Whitelist gate = ADMIN ONLY.** Students/teachers sign up freely; admins must be in
  `whitelists`. Enforced in `auth_service.handlePostLogin()`; non-whitelisted admin →
  signed out → `NotWhitelistedScreen`.
- `AuthStatus`: `initial · loading · authenticated · unauthenticated · registering ·
  notWhitelisted · awaitingVerification · error`.
- Email path stores pending student/faculty data on the controller, consumed after
  verification by `EmailSignupScreen` → `completeRegistration()`.
- Admin provisioning via the **`invite-admin` Edge Function** (holds service-role key).

---

## PUSH NOTIFICATIONS (Firebase FCM — built)

- `main.dart` inits Firebase + `PushService.instance.init()` (mobile only; web is skipped
  because there's no web Firebase config).
- On sign-in, `PushService.registerToken(userId)` saves the device's FCM token to
  **`device_tokens`**. On sign-out, `AuthService.signOut()` cleans the token up *before*
  the session drops (deleting after would run as anon and leave a stale row).
- Tapping a push → opens the notifications feed.
- Local-notification channel id `pushChannelId = 'universe_high_importance'` **must match**
  AndroidManifest's `default_notification_channel_id`.
- Permissions in `AndroidManifest.xml`: `INTERNET`, `POST_NOTIFICATIONS`. The `<queries>`
  block also allows `https` VIEW intents (so `url_launcher` can open resource links).
- **OS delivery = `supabase/functions/send-push` Edge Function — DEPLOYED & live.** A
  Supabase **DB Webhook on `notifications` INSERT** invokes it → resolves the row's audience
  (role/batch/section) → looks up `device_tokens` → sends via **FCM HTTP v1** (service-account
  JWT minted in-function; secret `FCM_SERVICE_ACCOUNT`). The local `index.ts` is commented
  out — it's only a copy of the deployed function.
- **Net effect:** inserting a `notifications` row = in-app Realtime alert **+** OS push.
  Used by admin broadcast, teacher cancel/notice, resource upload, and routine publish.

---

## SUPABASE SCHEMA (live)

| Table | Key detail |
|---|---|
| `whitelists` | admin gate; `role` ∈ student/teacher/admin |
| `profiles` | extends `auth.users`; created on first login |
| `routines` | weekly schedule; filtered by batch+section (student) or teacher_code (teacher). `teacher_name`/`teacher_code` are TEXT (migration 003); `teacher_id` nullable. **Engine publishes here.** Also read by `FindTeacherService` and `RoomStatusService`. |
| `cancellations` | **LIVE (migration 007)** — one dated row per cancelled occurrence: `routine_id, class_date, reason, batch, section, subject, day, time_start, cancelled_by` (+ unique `(routine_id, class_date)`). RLS: read-all; insert/delete by `cancelled_by = auth.uid()` & teacher/admin. Written by `TeacherService`; teacher view badges CANCELLED (student grid not yet wired — alert only). `cancel_date` legacy column dropped by migration 009. |
| `notifications` | typed (CHECK constraint); `notification_reads` tracks per-user read state |
| `resources` | files (any type) in the `resources` bucket + Drive links. Admin uploads via Manage Resources; everyone browses by **semester folder** (all semesters) + category. `uploaded_by` set from session (RLS). |
| `assignments` / `submissions` | `submissions.is_late` set by DB trigger — **never compute in Dart** |
| `documents` | RAG vector store (`VECTOR(768)`) — **unused (AI descoped)** |
| `generated_timetable` | **dropped (migration 009)** — was legacy pre-existing; superseded by `routines` |
| `device_tokens` | FCM tokens per device/user (push) |
| **`timetable_rooms`** | engine room pool: `name, building, is_lab, is_gallery, is_active`. RLS added migration 008. |
| **`timetable_faculty`** | teacher directory: `acronym, full_name, dept, designation, off_days text[], is_active` (off_days TRUE-semantics = unavailable). RLS added migration 008. |
| **`timetable_settings`** | single row (id=1): `semester_label, periods jsonb, friday_no_p4, service_scope, weights jsonb`. RLS added migration 008. |
| **`timetable_runs`** | generation history: `semester_label, file_path, stats jsonb, validation jsonb, status, row_count, created_by`. RLS added migration 008. |

**RLS pattern (all tables):** `read_all` (SELECT using true) + `admin_write` (INSERT/…
with check: caller is admin in `profiles`).

**Storage buckets:** `avatars` · `resources` · `assignments` · **`timetables`** (generated
workbooks). All public for the MVP.

**Seeds:** `supabase/seed/` — `seed_timetable_config.sql` (rooms/faculty/settings, generated
from the real workbooks), plus demo accounts/routine/resources/notifications/whitelist.
**Migrations:** `supabase/migrations/` — 001 notification_reads · 002 drop profiles photo_url ·
003 routines teacher text · 004 device_tokens · 005 register_device_token · 006 enable RLS
on all tables (+ `my_role()`/`is_admin()` helpers) · **007 cancellations schema** (canonical
columns + RLS + Realtime + legacy `cancel_date` relax; idempotent) · **008 RLS on
timetable_* config tables** (timetable_rooms/faculty/settings/runs — authenticated read-all +
admin write) · **009 drop unused objects** (drops legacy `cancellations.cancel_date` column
and `generated_timetable` table).
**Edge Functions:** `supabase/functions/` — `invite-admin` (service-role; admin provisioning)
· `send-push` (FCM v1; triggered by the `notifications` INSERT webhook).

---

## TIMETABLE ENGINE (the differentiator — DONE & DEPLOYED)

**Live:** `https://universe-timetable-engine.onrender.com` · Render free tier, deployed
from `main` via root `render.yaml` (Blueprint). Env: `PYTHON_VERSION=3.12.7`,
`SOLVER_WORKERS=2`. Free tier **sleeps after ~15 min** → first request ~50 s cold start
(the app's poll ceiling absorbs it; pre-warm before a demo).

### Pipeline (Excel in → workbook out)
```
Admin picks Main Distribution .xlsx  +  app loads DB config
   → POST multipart {file, config(JSON), time_limit_s}
   → ingest.py   parse "Course Distribution" sheet (header-text binding, even-digit
                 lab rule, exclude blank-teacher project rows + blank-batch ACM rows,
                 detect service/non-CSE offerings, validate invariants)
   → solver.py   PHASE 1 CP-SAT: assign (day, period). HARD: each session once;
                 no teacher/cohort/room double-book; teacher day-offs; Friday no-P4;
                 room-count ≤ pool. SOFT: a course's 2 sessions on different days;
                 cohort compactness; avoid last period. PHASE 2 greedy room assign
                 (labs→lab rooms, theory→theory/galleries). Self-validates (§9).
                 Service/non-CSE = resource-only (hold teacher+room time, not rendered).
   → render.py   clone templates/CSE_Routine_TEMPLATE.xlsx, write ONE canonical 55-row
                 cohort map to all 7 day-sheets (fixes the legacy row-shift bug),
                 cells "CODE TEACHER ROOM", Friday P4 left empty.
   → app polls status → shows report + validation + grid → Download .xlsx / Publish.
```

### HTTP contract (`engine/main.py`)
- `POST /api/timetable/generate` — multipart: `file` (.xlsx), `config` (JSON string),
  `time_limit_s` (default 60) → `{job_id}`. Runs on a background thread (in-memory job dict).
- `GET /api/timetable/status/{job_id}` → `{state, progress, [stats, validation, error]}`
  state: queued→ingesting→solving→rendering→done|failed.
- `GET /api/timetable/result/{job_id}` → `{rows, stats, validation, report}`.
- `GET /api/timetable/download/{job_id}` → the rendered `.xlsx`.

### Engine files (`engine/`)
`main.py` (API) · `solver.py` (CP-SAT + greedy + validation; `SOLVER_WORKERS` env) ·
`ingest.py` (xlsx parser) · `render.py` (workbook writer) · `config.json` (engine
fallback config) · `templates/CSE_Routine_TEMPLATE.xlsx` (PII-stripped) ·
`tools/seed_config.py` (regenerates `config.json` + the seed SQL from the raw workbooks) ·
`requirements.txt` · `Procfile` · `runtime.txt` / `.python-version` (3.12.7).
Gitignored: `.venv/`, `__pycache__/`, `routine generation files/` (PII), output `.xlsx`.

### Config flow (DB-backed)
Admin edits **Manage Rooms / Manage Faculty / Timetable Settings** →
`TimetableConfigService` (CRUD on `timetable_*`) → `buildEngineConfig()` assembles
`{rooms[], teachers[], settings{periods,friday_no_p4,service_scope,weights,semester_label}}`
→ sent in the generate request. The engine's `_normalize_config()` accepts this shape
(and falls back to `config.json`). **Keep these three in sync.**

### Flutter side (`lib/features/admin/`)
- Services: `timetable_engine_service.dart` (HTTP + upload-to-bucket + publish + record
  run), `timetable_config_service.dart`.
- Controllers: `timetable_gen_controller.dart`, `timetable_rooms/faculty/settings_controller.dart`.
- Screens: `generate_timetable_screen.dart` (pick→report→validation→grid→download→publish),
  `manage_rooms/faculty_screen.dart`, `timetable_settings_screen.dart`,
  `timetable_grid_screen.dart`.
- Local run override: `--dart-define=TIMETABLE_BASE_URL=http://10.0.2.2:8000` (emulator).
  `android/app/src/main/res/xml/network_security_config.xml` permits cleartext to
  10.0.2.2/localhost only (prod is HTTPS).
- Real data sanity (Summer 2025): 358 offerings → 654 CSE + 32 service sessions, 55 cohorts,
  76 teachers, solves clash-free (`validation.ok = true`).

---

## FIND TEACHER & ROOM AVAILABILITY (campus explore — built, on `main`)

Both features are **real-time** (Supabase Realtime streaming) and are reached from the
**`ExploreFabMenu`** FAB present on all three dashboards (student, teacher, admin).

### Find Teacher (`lib/features/find_teacher/`)
- **Service** (`find_teacher_service.dart`): streams `routines` + `cancellations` →
  derives each teacher's current status from live time vs the weekly schedule.
- **Controller** (`find_teacher_controller.dart`): search filter by name or teacher code;
  exposes list of `TeacherStatus` objects (status: `inClass` / `free` / `noClassToday`).
- **Screen** (`find_teacher_screen.dart`) + **Widget** (`teacher_status_card.dart`):
  search bar → list of teacher cards showing current room + remaining time + next class.
- **Route**: `RouteNames.findTeacher = '/find-teacher'` (secondary, pushed).

### Room Availability (`lib/features/rooms/`)
- **Service** (`room_status_service.dart`): streams `routines` → derives each room's
  occupancy (OCCUPIED / AVAILABLE) from the timetable + cancellations.
- **Controller** (`room_status_controller.dart`): sortable by room name; exposes list of
  `RoomStatus` objects with current class info and next scheduled class.
- **Screen** (`rooms_screen.dart`) + **Widget** (`room_status_card.dart`):
  room list with occupancy chips, current teacher/subject/batch, countdown to free.
- **Route**: `RouteNames.rooms = '/rooms'` (secondary, pushed).

### Detail screens (weekly schedule)
- Each room card and teacher card ends in a **"More details"** link → a screen showing the
  full **day-by-day** schedule, built on the shared
  `shared/widgets/weekly_schedule_view.dart` (day strip on top + that day's class list).
- `WeeklyScheduleView` takes the entries + a `rowBuilder`, so Rooms can emphasise the
  teacher while Find Teacher emphasises the room / course code from one implementation.
- Opens on **today**; if today is empty it falls back to the first day that has classes.
- **Cancellations are not applied here** (deliberate) — plain weekly timetable only.

### ⚠️ Known gaps in these two features (not yet fixed)
- Both controllers extend plain `ChangeNotifier`, not `SafeChangeNotifier` like every
  other screen-scoped controller, **and** their `streamAllRoutines().listen(...)`
  subscription is never cancelled → a Realtime event after the screen is popped notifies
  a disposed notifier.
- `subscribeToRealTimeUpdates()` assigns the streamed rows and then immediately re-fetches
  over the network, discarding the payload it was just handed.
- The list screens ignore `cancellations`, so a cancelled class still shows the teacher as
  "In Class" and the room as occupied.
- Both duplicate a local `['Sunday', …]` list instead of using `AppConstants.weekDays`.

### Explore FAB (`lib/shared/widgets/explore_fab_menu.dart`)
- `FloatingActionButton` wired into all three dashboard scaffolds.
- Tapping opens a bottom sheet with two tiles: **Rooms** and **Find Teacher**.
- No new tables — reads only existing `routines` and `cancellations`.

---

## AI ASSISTANT — ⛔ DESCOPED (future scope)

Not in the defense build. **Removed from UI:** the student "AI" bottom-nav tab and the
`/student/ai-assistant` route. **Kept for restore:** `RouteNames.aiAssistant` constant,
`shared/widgets/chat_bubble.dart`, the `documents` table.

**To restore later:** re-add the nav destination in `app_bottom_nav.dart` + the GoRoute in
`app_router.dart`, build `lib/features/ai_assistant/` (service+controller+chat screen),
then run the `documents` hybrid-search migration (add `namespace` + `content_tsv` columns,
GIN index, rewrite `match_documents()` RPC) — and update every `documents` INSERT in the
same sitting. Gemini: `text-embedding-004` (768-dim) + `gemini-2.0-flash`. Do NOT run that
migration before the service is being written.

---

## SCREEN INVENTORY (all built unless noted)

Auth (12): splash, onboarding, login, email login/signup, verify email, forgot/reset
password, role selection, student/faculty register, not-whitelisted. ·
Student (`features/dashboard/`): **dashboard (built)**, routine, resources (semester
folders), ~~AI assistant (descoped)~~. · Shared: notifications (multi-select dismiss),
profile. · Teacher (`features/teacher/`): **dashboard (built)**, routine, **Manage Classes
(built — cancel/notice/undo)**. · Admin: dashboard, **Routine hub (Manage + Generate)**,
campus broadcast (+ **Broadcast History**), admin registration, manage users, **Manage
Resources (+ Resource Library)**, manage rooms, manage faculty, timetable settings,
timetable grid, **Upload Routine** (3rd segment of the Routine hub). · **Campus Explore
(all roles via FAB or drawer):** **Find Teacher** (real-time teacher locator), **Room
Availability** (real-time occupancy), **Room Detail** + **Teacher Detail** (full weekly
schedule, reached via the "More details" link on each card).

---

## NEW FEATURE MAP (all merged to `main`)

- **Dashboards** — `features/dashboard/` (student) + `features/teacher/` (teacher). Each:
  greeting app bar → hero (`LiveClassCard` if live, else `NextClassCard` countdown, else
  `MessageHeroCard` "done") → stat strip → today's list → quick actions → recent-alerts
  preview. Controllers aggregate `RoutineService.fetchFor{Student,Teacher}` + the shared
  `NotificationController`. New widgets: `next_class_card`, `message_hero_card`,
  `scrollable_empty`.
- **Manage Classes** — `features/teacher/` (`manage_classes_screen/_controller`,
  `teacher_service.dart`). Day selector → tap class → action sheet: **Cancel** (reason →
  `cancellations` row + `class_cancel` alert), **Post update** (room_change/notice/
  test_reminder via `createBroadcast`), **Undo** (delete row). A cancellation targets the
  next occurrence date of that weekday; teacher card badges CANCELLED.
- **Resources** — admin **Manage Resources** (`resource_admin_controller`) uploads via
  `ResourceService.uploadFile`+`createResource` (+ student alert), with a separate
  **Resource Library** page (semester folders + delete). Student `ResourceController` loads
  ALL resources → `resources_screen` shows **semester folders** → category list → opens
  links (`url_launcher`, clipboard fallback). RLS lets students read every semester.
- **Auto-notify** — resource upload → students; `timetable_gen_controller.publish()` inserts
  a "routine published" notification (everyone) after `publishToRoutines` (best-effort).
  `NotificationService.createBroadcast` now defaults `sent_by` to the current user.
- **Notifications dismiss** — `NotificationController` keeps a per-user dismissed-id set in
  `SharedPreferences` (`dismissed_notifs_<uid>`), filtered out of feed/badge/previews;
  multi-select UI (long-press / select icon → checkboxes → trash). **DB rows untouched.**
- **Admin Routine hub** — `admin_routine_screen.dart`: segmented Manage/Generate (both
  rendered `embedded`); the old standalone Generate route is gone.
- **Split pages** — `broadcast_history_screen`, `resource_library_screen`, reached via an
  app-bar icon from the compose/upload pages (keeps those pages clean forms).
- **7-day week** — `AppConstants.weekDays` = Sun–Sat; all controller weekday maps updated;
  `timetable_grid`/`manage_faculty` now use the constant (were duplicated 7-day lists).
- **Find Teacher + Room Availability** — `features/find_teacher/` + `features/rooms/`
  (Robi, merged via PR #5 `room_teacher_find`). Real-time campus explore via FAB.
- **Package rename** — Flutter package `universe_v1` → `universe`; applicationId
  `com.example.universe_v1` → `com.example.universe`. All imports updated project-wide.
  Auth deep link scheme updated accordingly.
- **`ULocalAvatar` widget** — `shared/widgets/u_local_avatar.dart`; user profile avatars.

### August 2026 session (branch `room_teacher_find`)

- **About credits** — `AppConstants.supervisorName/supervisorRole/developers/teamName/course`
  feed the Profile → About dialog: supervisor **Md. Jamaner Rahaman, Assistant Professor,
  Leading University**, then the 3-member team with student IDs.
- **AM/PM clock fix** (`core/utils/clock_time.dart` + `test/clock_time_test.dart`) —
  see the guardrail above. `normalize()` reads a bare hour of **1–7 as PM** (campus teaches
  ~08:00–21:00); `repairSequence()` pushes any slot that starts *before* the one preceding
  it forward 12h, because a teaching day only moves forward. Replaced the old naive
  `_dbTime()` string-concat in `routine_workbook_parser.dart` and now also normalizes
  `buildEngineConfig()`. `engine/render.py::_fmt_clock` was hardened to accept `HH:MM` and
  `HH:MM:SS` alike (**render-only label formatter — no CP-SAT/solver change**).
  ⚠️ This fixes the WRITE path only; routines already published with wrong times must be
  re-uploaded / re-generated.
- **Admin Upload Routine** — `upload_routine_screen.dart` + `routine_upload_controller.dart`
  + `routine_workbook_parser.dart` (pure-Dart .xlsx reader via `archive` + `xml`). Parses a
  **rendered** UniVerse routine workbook → `routines` rows → publishes through the same
  `TimetableEngineService.publishToRoutines` path as generated output, records a
  `timetable_runs` row and posts a "routine published" broadcast. It is a **second producer
  of `routines` rows** alongside the engine — keep both in sync with the row shape.
- **App drawer + FAB coordination** — see NAVIGATION.
- **Room / Teacher detail** — `rooms/screens/room_detail_screen.dart` +
  `find_teacher/screens/teacher_detail_screen.dart`, both built on the shared
  `shared/widgets/weekly_schedule_view.dart` (day strip + per-day list). Opens on **today**,
  falling back to the first day that has classes so an empty day never reads as "no schedule
  at all". Each screen **fetches its own rows** (survives deep link / back-stack restore
  from `extra` alone). **Cancellations are NOT applied here** — deliberate: these show the
  plain weekly timetable.
- **Push: data-only messages** (`core/services/push_service.dart`) — FCM *notification*
  messages are drawn by Android; **data-only messages are drawn by nobody**. Both handlers
  used to drop them (`_showForeground` bailed on `notification == null`; the background
  handler only `debugPrint`ed), so such a push could never reach the notification bar.
  Both now fall back to `data['title']`/`data['body']` via `_contentOf()` + `_displayLocal()`;
  the background isolate initializes its own plugin + channel and returns early when a
  `notification` block is present (which Android already drew) to avoid double alerts.
  `registerToken` now logs its outcome — an empty `device_tokens` used to fail silently.
  ⚠️ **Unverified server-side links:** whether the DB Webhook on `notifications` INSERT is
  actually configured, and whether `FCM_SERVICE_ACCOUNT` is set. `send-push` IS deployed
  (a bare POST returns `"No record"`, not 404). Check Edge Functions → send-push → Logs.

---

## GITHUB / BUILD

- `main` = integration + release branch (engine deploys from it). Feature branches merge
  to `main`. **All features — polish work + find_teacher + rooms — are merged to `main`.**
  The agent never pushes; Fahmid merges + rebuilds the APK.
- Commit format: `feat|fix|chore|refactor(module): description`.
- After a merge conflict, resolve by **keeping both features** (the conflicts so far were
  additive: push-notifications ↔ timetable).
- Deploy: push `main` → Render auto-rebuilds the engine (same URL, no downtime).
- APK: `flutter build apk --release` (URL baked into `app_constants` default).

---

## HARD CONSTRAINTS — NEVER VIOLATE

- No hardcoded hex → `AppColors.*` · no raw spacing → `AppSpacing.*` · no raw
  `TextStyle()` → `AppTextStyles.*` (+ `.copyWith`).
- All clock text through `ClockTime` — `HH:MM:SS` to Postgres, `HH:MM` to the engine.
- No conflict markers in a commit. Grep + `flutter analyze` before every merge commit.
- No `MaterialPageRoute` → `context.go/push` with `RouteNames.*`. No hardcoded route strings.
- No Supabase in screens/controllers → services only. `is_late` is a DB trigger.
- `ChangeNotifier` only (no Riverpod/Bloc/Provider). Icons `PhosphorIconsRegular.*` **via
  `shared/utils/phosphor_compat.dart`**. Font Inter (global). One theme: `AppTheme.dark`.
  App name "UniVerse".
- `DropdownButtonFormField`: use `initialValue:` (not deprecated `value:`).
- Shared infra (`app_router`, `route_names`, `app_constants`, `pubspec.yaml`, `main.dart`,
  `app_shell.dart`) → Fahmid only.
- Engine row shape ↔ `routines` columns and the `timetable_*` config tables ↔
  `buildEngineConfig()` ↔ engine `_normalize_config()` must move together.
- Don't downgrade Gradle < 8.14. Don't commit secrets / PII workbooks / `dart_defines.json`.

---

## IMPORT CONVENTION
```dart
// Always package imports — never relative.
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/router/route_names.dart';
```

## QUICK REFERENCE
- **Add screen:** file in `features/<f>/screens/` → `RouteNames` const → `GoRoute` in
  `app_router` (tab → inside `ShellRoute`; secondary → top-level).
- **Add table:** SQL + RLS (read_all + admin_write) → `app_constants` table const → service method.
- **Add widget:** `shared/widgets/`, import only theme tokens, config via constructor.
- **Change engine behavior:** edit `engine/*.py`, test locally
  (`uvicorn main:app --port 8000` + `--dart-define=TIMETABLE_BASE_URL=http://10.0.2.2:8000`),
  then push `main` to auto-deploy.
- **Regenerate engine config/seed from workbooks:** `python engine/tools/seed_config.py`.
- **Run tests:** `flutter test` (currently `test/clock_time_test.dart` — the AM/PM rules).
- **Build won't start / cryptic Gradle version error:** see the JDK note in GUARDRAILS.
- **Routine times look wrong (AM instead of PM):** the write path is fixed, but existing
  rows are not — re-upload or re-generate. `timetable_settings.periods` is the source;
  it is NOT editable from the Timetable Settings screen (passed through as
  `// unchanged (advanced)`), so it can only be corrected via SQL today.