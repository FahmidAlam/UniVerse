# CLAUDE.md — UniVerse Project Context
> Load this at the start of every session. Dense reference only — no fluff.
> Last updated: June 2026 (post-auth implementation + hybrid search design)

---

## APP IDENTITY

| Field | Value |
|---|---|
| Name | **UniVerse — A Campus Companion** |
| Platform | Android (Flutter) |
| University | Leading University, Sylhet, Bangladesh |
| Department | CSE |
| Course | CSE-3240 (Project I) |
| Team name | Sherlocked |
| Advisor | Jaminur Rahman |
| Defense deadline | 30 days from Day 1 (started May 2026) |
| Flutter package name | `universe_v1` |
| Android applicationId | `com.example.universe_v1` |

**Three actor types:** Student · Teacher · Admin
**Critical differentiator (advisor-required):** Automatic department timetable generator using OR-Tools CP-SAT

---

## TEAM ROLES — FEATURE-BASED OWNERSHIP

> Each member owns complete vertical slices: screen + controller + service + tests.
> Never touch another member's feature branch. Shared infrastructure = Fahmid only.

### Fahmid Alam — ID: 0182320012101309
**Owns: Architecture, Shared Infrastructure, AI Pipeline, Timetable Engine, Admin**
- `lib/core/` — all theme, router, constants, utils (sole owner)
- `lib/shared/widgets/` — all reusable u_* widgets (sole owner)
- `lib/features/auth/` — complete auth system (done)
- `lib/features/ai_assistant/` — RAG pipeline, chat UI, Gemini integration
- `lib/features/admin/` — all 5 admin screens + controller + service
- `engine/` — FastAPI + OR-Tools timetable backend (Python, separate repo)
- `main.dart`, `pubspec.yaml`, `AndroidManifest.xml` (sole owner)
- **Branch:** `feature/app-foundation`, `feature/auth`, `feature/admin-screens`, `feature/timetable-engine`

### Swadheen Islam Robi — ID: 0182320012101278
**Owns: Student-Facing Features, Teacher Screens**
- `lib/features/dashboard/` — student dashboard, live class card, countdown
- `lib/features/routine/screens/student_routine_screen.dart` — student routine view
- `lib/features/routine/screens/teacher_routine_screen.dart` — teacher routine view
- `lib/features/routine/` — routine controller + service (shared with teacher)
- `lib/features/resources/` — resource hub, filter, PDF viewer, Drive links
- `lib/features/teacher/` — manage classes screen, cancel sheet, notice sheet
- **Branch:** `feature/student-core`, `feature/teacher-screens`
- **Uses mock data** until Fahmid's timetable engine merges to develop

### Shahriar Rashid Ratul — ID: 0182320012101276
**Owns: Notifications, Profile, QA, Data Seeding**
- `lib/features/notifications/` — feed UI, filter chips, Realtime subscription, badge count
- `lib/features/profile/` — profile screen, stats, settings tiles, sign out
- Demo data seed scripts (20 teachers, full routine, 15+ resources, 10 notifications)
- End-to-end testing, device testing, APK build verification
- `README.md`, screenshots for defense
- **Branch:** `feature/notifications-profile`

### Conflict-free shared file rule
If ANY file outside your feature folder needs changing → open a PR to develop and tag Fahmid.
Never directly edit: `app_router.dart`, `route_names.dart`, `app_constants.dart`, `pubspec.yaml`.

---

## TECH STACK

### Flutter (Dart)
```
flutter SDK: >=3.3.0 <4.0.0
supabase_flutter: ^2.5.6
google_sign_in: ^6.2.1
go_router: ^14.2.7
google_fonts: ^6.2.1
phosphor_flutter: ^2.1.0
hive_flutter: ^1.1.0
flutter_local_notifications: ^17.2.2
file_picker: ^8.1.2
flutter_pdfview: ^1.3.2
cached_network_image: ^3.3.1
http: ^1.2.1
shared_preferences: ^2.3.2
```

### Backend / Services
- **Supabase** — PostgreSQL + pgvector + Auth + Storage + Realtime
- **Gemini API** — `text-embedding-004` (768-dim) + `gemini-2.0-flash` (generation)
- **Google OAuth** — via Supabase Auth, PKCE flow
- **FastAPI (Python)** — timetable engine, deployed on Railway/Render free tier
- **OR-Tools CP-SAT** — constraint solver for timetable generation

### Auth deep link schemes
```
com.example.universe_v1://login-callback/   <- Google OAuth + email verify
com.example.universe_v1://reset-callback/  <- password reset
```

---

## DESIGN SYSTEM

> All tokens in `lib/core/theme/`. **Never hardcode hex values or raw numbers in widgets.**

### Color tokens (`app_colors.dart`)
```dart
bgPrimary    = #0F0F10   // screen background
bgCard       = #1A1A1C   // card surfaces
bgElevated   = #222325   // inputs, chips
bgSubtle     = #1C1C1E   // pressed states, skeletons
primary      = #FF7A00   // orange - CTA, active nav, live badge
primaryDark  = #E66A00   // pressed state
primarySoft  = #2A1A0A   // orange badge backgrounds
primaryMuted = #3D2000   // selected chip backgrounds
textPrimary  = #FFFFFF
textSecondary= #B0B3B8
textMuted    = #6E7278
textDisabled = #4A4D52
border       = #2A2C30
borderFocus  = #FF7A00
borderError  = #EF4444
navBg        = #111113
success=#22C55E / successSoft=#0D2E1A
info   =#3B82F6 / infoSoft   =#0D1F3C
warning=#F59E0B / warningSoft=#2D1E00
error  =#EF4444 / errorSoft  =#2D0D0D
done   =#6E7278 / doneSoft   =#1A1C1F
```

### Text styles (`app_text_styles.dart`)
`h1` 24/700 · `h2` 18/600 · `h3` 16/600 · `h4` 14/600
`body` 14/400 · `bodyMedium` 14/500 · `bodySm` 13/400 (color: textSecondary)
`badge` 10/700 uppercase ls:0.8 · `chip` 12/500 · `label` 12/500 ls:0.3
`button` 15/600 · `link` 13/500 orange · `danger` 14/500 red
`countdown` 30/700 orange ls:-1.5 · `statNumber` 22/700 orange
`onboardTitle` 22/700 · `input` 14/400 · `placeholder` 14/400 muted

### Spacing (`app_spacing.dart`)
`xs=4 sm=8 md=12 lg=16 xl=20 xxl=24 x3l=32 x4l=40 x5l=48`
`screenH=20 screenV=16` · `buttonHeight=52` · `inputHeight=52` · `chipHeight=34`
`radiusSm=8 radiusMd=12 radiusLg=16 radiusXl=20 radiusFull=100`
`borderThin=0.5 borderNormal=1.0 borderThick=2.0 borderAccent=3.0`

### Theme
`AppTheme.dark` -> wire in `MaterialApp.router(theme: AppTheme.dark)`
`AppTheme.setSystemUI()` -> call once in `main()` before `runApp()`
Font: **Inter** via `GoogleFonts.interTextTheme()` — inherited everywhere, never specify fontFamily in widgets
Icons: **phosphor_flutter** -> always `PhosphorIconsRegular.*`

---

## ARCHITECTURE RULES

### Folder structure
```
lib/
  main.dart                   <- Fahmid only
  core/
    theme/                    <- 4 files, all done, Fahmid only
    router/                   <- app_router + route_names, Fahmid only
    constants/                <- app_constants, Fahmid only
    utils/                    <- date_utils, validators, extensions [TO BUILD]
  shared/
    widgets/                  <- all u_* widgets [TO BUILD - Fahmid]
  features/
    auth/                     <- DONE - Fahmid
    dashboard/                <- Robi
    routine/                  <- Robi
    ai_assistant/             <- Fahmid
    resources/                <- Robi
    notifications/            <- Ratul
    profile/                  <- Ratul
    teacher/                  <- Robi
    admin/                    <- Fahmid
```

### Layer rules (enforced — no exceptions)
- Screens -> call controllers only, never Supabase directly
- Controllers -> call services only, never Supabase directly
- Services -> only layer that touches Supabase
- Shared widgets -> import from `shared/widgets/` never from feature folders
- Each feature folder: `screens/` + `controllers/` + `services/` + `widgets/`

### State management
- `ChangeNotifier` + `ListenableBuilder` — **no Riverpod, no Bloc, no Provider**
- `setState` for local UI state only (toggle, animation, form field)
- Supabase Realtime streams for live notifications (Ratul's feature)

### Navigation
- **GoRouter ^14** — single `AppRouter` instance in `main.dart`
- All paths as constants in `RouteNames` — never hardcode strings
- Redirect logic lives only in `AppRouter.redirect()` — screens never guard themselves
- `authController` is the `refreshListenable`

---

## AUTH SYSTEM (COMPLETE)

### Two methods supported
1. **Google OAuth** — PKCE, `signInWithOAuth(OAuthProvider.google)`
2. **Email + Password** — `signUp()` + email verification + `signInWithPassword()`

### Whitelist gate — ADMIN ONLY
- Students and teachers sign up/login freely — no whitelist check
- Only admin accounts require pre-registration in `whitelists` table
- `handlePostLogin()` in `auth_service.dart` enforces this
- Non-whitelisted admin -> signed out -> `NotWhitelistedScreen`

### AuthStatus enum
```dart
initial · loading · authenticated · unauthenticated ·
registering · notWhitelisted · awaitingVerification · error
```

### Pending registration data (email path)
- Register screen calls `storePendingStudentData()` / `storePendingFacultyData()` on controller
- Then navigates to `EmailSignupScreen`
- After email verified, `EmailSignupScreen` reads `pendingStudentData` / `pendingFacultyData`
- Calls `completeStudentRegistration()` / `completeFacultyRegistration()` to create profile
- `clearPendingData()` called automatically on success or sign out

### Full auth flow
```
Splash -> initialize()
  |- session + verified     -> load profile -> role dashboard
  |- session + unverified   -> VerifyEmailScreen
  +- no session             -> onboarding check -> Login or Onboarding

Login
  |- Google OAuth           -> whitelist check (admin only) -> dashboard
  |- Email/password         -> dashboard / VerifyEmailScreen
  +- Create account         -> RoleSelection -> Student/FacultyRegister

Email registration path:
  RegisterScreen -> storePendingData() -> EmailSignupScreen
  -> signUp() -> VerifyEmailScreen (polls + resend + 60s cooldown)
  -> verified -> handlePostLogin() -> completeRegistration() -> dashboard

Password reset path:
  ForgotPasswordScreen -> sendPasswordResetEmail()
  -> deep link fires AuthChangeEvent.passwordRecovery
  -> main.dart routes to ResetPasswordScreen -> updatePassword() -> login
```

---

## SUPABASE SCHEMA

### Current tables (live in production)

| Table | Key detail |
|---|---|
| `whitelists` | Admin-only gate. `role` constrained to student/teacher/admin |
| `profiles` | Extends `auth.users`, created on first login |
| `routines` | Weekly schedule. Filtered by batch+section for students |
| `cancellations` | Teacher cancellations, triggers Realtime push |
| `notifications` | All types. `type` constrained by CHECK constraint |
| `resources` | PDFs + Drive links, filtered by semester + category |
| `assignments` | Teacher-created, targets batch+section |
| `submissions` | `is_late` set by PostgreSQL trigger, never in Dart |
| `documents` | RAG vector store — `embedding VECTOR(768)`, `category TEXT` |
| `generated_timetable` | OR-Tools output, stored after generation |

### `documents` table — current state vs planned state

**Current columns (live):**
```sql
id        UUID  PRIMARY KEY
content   TEXT  NOT NULL
embedding VECTOR(768)        -- pgvector, HNSW indexed
category  TEXT  NOT NULL     -- e.g. 'routine', 'resource', 'policy'
```

**Planned additions — DO NOT RUN until ai_assistant_service.dart is being built:**
```sql
-- 1. namespace column for scoped retrieval
ALTER TABLE documents ADD COLUMN namespace TEXT NOT NULL DEFAULT 'admin_global';
-- Values: 'student_{uuid}' | 'course_{code}' | 'admin_global'

-- 2. Full-text search column (auto-generated, Dart never touches it)
ALTER TABLE documents ADD COLUMN content_tsv TSVECTOR
  GENERATED ALWAYS AS (to_tsvector('english', content)) STORED;

CREATE INDEX idx_documents_tsv ON documents USING GIN(content_tsv);
```

**Why deferred:** Adding `namespace` requires updating every Dart INSERT call simultaneously.
Do the migration and write `ai_assistant_service.dart` in the same sitting to avoid broken state.

### Namespace routing (when implemented)

| Who is querying | Namespace value to pass |
|---|---|
| Student querying their own uploaded notes | `student_{userId}` |
| Student asking about a course | `course_{courseCode}` |
| Anyone querying university-wide info | `admin_global` |
| Admin querying everything | `null` (no filter applied) |

### Critical schema notes
- `submissions.is_late` -> PostgreSQL trigger `calculate_is_late` — **never compute in Dart**
- `documents.embedding` -> `VECTOR(768)`, requires `pgvector` extension (enabled)
- HNSW index on `documents.embedding` for fast cosine search
- `match_documents(query_embedding, match_count)` -> current Postgres RPC for RAG queries
- `category` != `namespace` — category describes content type, namespace scopes access

### RLS pattern (all tables)
```sql
ALTER TABLE t ENABLE ROW LEVEL SECURITY;
CREATE POLICY "read_all" ON t FOR SELECT USING (true);
CREATE POLICY "admin_write" ON t FOR INSERT
  WITH CHECK (EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
  ));
```

### Storage buckets
`avatars` (public) · `resources` (public) · `assignments` (public)
Open storage policy for MVP — tighten before production.

---

## FILES ALREADY CREATED

### Core (Fahmid — all done)
| Path | Status |
|---|---|
| `lib/core/theme/app_colors.dart` | Done |
| `lib/core/theme/app_text_styles.dart` | Done |
| `lib/core/theme/app_spacing.dart` | Done |
| `lib/core/theme/app_theme.dart` | Done |
| `lib/core/router/route_names.dart` | Done |
| `lib/core/router/app_router.dart` | Done |
| `lib/core/constants/app_constants.dart` | Done |
| `lib/main.dart` | Done |
| `pubspec.yaml` | Done |
| `android/app/src/main/AndroidManifest.xml` | Done |

### Auth feature (Fahmid — all done)
| Path | Status |
|---|---|
| `lib/features/auth/services/auth_service.dart` | Done |
| `lib/features/auth/controllers/auth_controller.dart` | Done |
| `lib/features/auth/screens/splash_screen.dart` | Done |
| `lib/features/auth/screens/onboarding_screen.dart` | Done |
| `lib/features/auth/screens/login_screen.dart` | Done |
| `lib/features/auth/screens/email_login_screen.dart` | Done |
| `lib/features/auth/screens/email_signup_screen.dart` | Done |
| `lib/features/auth/screens/verify_email_screen.dart` | Done |
| `lib/features/auth/screens/forgot_password_screen.dart` | Done |
| `lib/features/auth/screens/reset_password_screen.dart` | Done |
| `lib/features/auth/screens/role_selection_screen.dart` | Done |
| `lib/features/auth/screens/student_register_screen.dart` | Done |
| `lib/features/auth/screens/faculty_register_screen.dart` | Done |
| `lib/features/auth/screens/not_whitelisted_screen.dart` | Done |
| `lib/features/auth/screens/placeholder_screen.dart` | Done |
| `lib/features/auth/widgets/onboard_slide.dart` | Done |
| `lib/features/auth/widgets/google_sign_in_button.dart` | Done |

---

## SCREEN INVENTORY

| # | Screen | Route | Owner | Status |
|---|---|---|---|---|
| 1 | Splash | `/` | Fahmid | Built |
| 2 | Onboarding | `/onboarding` | Fahmid | Built |
| 3 | Login | `/login` | Fahmid | Built |
| 4 | Email Sign In | `/login/email` | Fahmid | Built |
| 5 | Email Sign Up | `/signup/email` | Fahmid | Built |
| 6 | Verify Email | `/verify-email` | Fahmid | Built |
| 7 | Forgot Password | `/forgot-password` | Fahmid | Built |
| 8 | Reset Password | `/reset-password` | Fahmid | Built |
| 9 | Role Selection | `/role-selection` | Fahmid | Built |
| 10 | Student Register | `/register/student` | Fahmid | Built |
| 11 | Faculty Register | `/register/faculty` | Fahmid | Built |
| 12 | Not Whitelisted | `/not-whitelisted` | Fahmid | Built |
| 13 | Student Dashboard | `/student/dashboard` | Robi | Placeholder |
| 14 | AI Chat Assistant | `/student/ai-assistant` | Fahmid | Placeholder |
| 15 | Student Routine | `/student/routine` | Robi | Placeholder |
| 16 | Resource Hub | `/student/resources` | Robi | Placeholder |
| 17 | Notifications | `/notifications` | Ratul | Placeholder |
| 18 | Profile | `/profile` | Ratul | Placeholder |
| 19 | Teacher Dashboard | `/teacher/dashboard` | Robi | Placeholder |
| 20 | Teacher Routine | `/teacher/routine` | Robi | Placeholder |
| 21 | Manage Classes | `/teacher/manage-classes` | Robi | Placeholder |
| 22 | Admin Dashboard | `/admin/dashboard` | Fahmid | Placeholder |
| 23 | Routine Management | `/admin/routine` | Fahmid | Placeholder |
| 24 | Campus Broadcast | `/admin/broadcast` | Fahmid | Placeholder |
| 25 | Admin Registration | `/admin/registration` | Fahmid | Placeholder |
| 26 | Manage Users | `/admin/users` | Fahmid | Placeholder |

---

## WHAT NEEDS BUILDING NEXT

### Fahmid — immediate
- [ ] `lib/core/utils/date_utils.dart` — countdown logic, time slot helpers
- [ ] `lib/core/utils/validators.dart` — form validation functions
- [ ] `lib/core/utils/extensions.dart` — String, DateTime extensions
- [ ] All 23 shared widgets in `lib/shared/widgets/` (build in order below)

### Shared widgets build order (Fahmid)
Robi needs widgets 1-4 + 13 + 14 first to unblock dashboard.
Ratul needs widgets 1-4 + 15 first to unblock notifications.
Build in this sequence — do not skip ahead.

```
1.  u_button.dart          primary / secondary / danger variants       <- Robi + Ratul unblock
2.  u_text_field.dart      label, error state, prefix/suffix           <- Robi + Ratul unblock
3.  u_card.dart            base dark card surface                      <- Robi + Ratul unblock
4.  u_divider.dart         subtle separator                            <- Robi + Ratul unblock
5.  u_badge.dart           ClassStatus enum: live/next/done/cancelled/upcoming
6.  u_chip.dart            active/inactive filter pill
7.  u_avatar.dart          initials fallback + network image
8.  u_app_bar.dart         consistent top bar
9.  u_bottom_nav.dart      5-tab with unread badge support
10. u_section_header.dart  title + optional "See all"
11. u_empty_state.dart     icon + message + optional action
12. u_loading.dart         skeleton + spinner
13. class_card.dart        all status states                           <- Robi unblock
14. live_class_card.dart   hero card with countdown timer             <- Robi unblock
15. notification_tile.dart 3px colored left border                    <- Ratul unblock
16. resource_card.dart     PDF / Drive variants
17. chat_bubble.dart       user (right) and AI (left) variants
18. day_selector.dart      scrollable day pills
19. role_card.dart         Student / Teacher / Admin
20. stat_card.dart         number + label
21. info_row.dart          label : value pair
22. settings_tile.dart     chevron row
23. quick_action_card.dart dashboard 2x2 grid item
```

### Robi — unblocked after widgets 1-4 + 13 + 14 land on develop
- [ ] Student dashboard (mock data first)
- [ ] Student routine screen
- [ ] Resource hub
- [ ] Teacher routine screen
- [ ] Manage classes screen

### Ratul — unblocked after widgets 1-4 + 15 land on develop
- [ ] Notification feed + Realtime subscription
- [ ] Profile screen
- [ ] Demo data seeding scripts

---

## TIMETABLE ENGINE (FastAPI — Fahmid)

- Language: Python · Framework: FastAPI · Solver: `ortools` CP-SAT
- Deployed: Railway or Render free tier
- Start command: `uvicorn engine:app --host 0.0.0.0 --port $PORT`
- Endpoints: `POST /api/timetable/generate` · `GET /api/timetable/status/{job_id}` · `GET /api/timetable/download/{job_id}` · `GET /api/timetable/result/{job_id}`
- Real data: 343 offerings · 686 slots · 76 teachers · 68 sections · 27 rooms · 5 days · 5 slots/day
- Teacher day-offs: `EBH` Thu · `RLP` Thu · `STA` Sun · `JIM` Sun
- Phase 1: CP-SAT assigns (day, slot) — hard: teacher/section/day-conflict · soft: spread daily load
- Phase 2: Greedy room assignment — sessionals -> labs first (ACL-1/2/NL/GL/ECL/ChL/PhL), theory -> any of 20 theory rooms
- Flutter polls `status` endpoint every 3s during solve (30-120s expected)

---

## RAG AI PIPELINE (Gemini — Fahmid)

### Current implementation (live design)
- Embed: `POST .../models/text-embedding-004:embedContent` -> 768-dim vector
- Generate: Gemini Flash, constrained prompt: "Answer ONLY using this context: [chunks]. Question: [q]"
- Ingestion: DB rows -> natural language sentences -> embed -> bulk insert `documents`
- Query: embed question -> `match_documents()` RPC (top 3) -> Gemini Flash -> chat UI
- No relevant chunks -> return "I don't have information about that yet."
- RPC call: `supabase.rpc('match_documents', params: {'query_embedding': vector, 'match_count': 3})`

### Planned: hybrid search (implement with ai_assistant_service.dart — same sitting as DB migration)

Why hybrid: Pure vector search misses exact terms — course codes, teacher initials, room numbers.
Hybrid merges vector similarity (semantic) + PostgreSQL full-text search (keyword).

**Updated RPC signature (run only after namespace + content_tsv columns are added):**
```sql
CREATE OR REPLACE FUNCTION match_documents(
  query_embedding VECTOR(768),
  query_text      TEXT,
  match_count     INT     DEFAULT 3,
  p_namespace     TEXT    DEFAULT NULL
)
RETURNS TABLE (id UUID, content TEXT, namespace TEXT, score FLOAT)
LANGUAGE sql AS $$
  WITH vector_results AS (
    SELECT id, content, namespace,
           1 - (embedding <=> query_embedding) AS vector_score,
           0::FLOAT AS text_score
    FROM documents
    WHERE (p_namespace IS NULL OR namespace = p_namespace)
  ),
  text_results AS (
    SELECT id, content, namespace,
           0::FLOAT AS vector_score,
           ts_rank(content_tsv, plainto_tsquery('english', query_text)) AS text_score
    FROM documents
    WHERE (p_namespace IS NULL OR namespace = p_namespace)
      AND content_tsv @@ plainto_tsquery('english', query_text)
  ),
  combined AS (
    SELECT id, content, namespace,
           COALESCE(v.vector_score, 0) * 0.7 +
           COALESCE(t.text_score,  0) * 0.3 AS score
    FROM vector_results v
    FULL OUTER JOIN text_results t USING (id, content, namespace)
  )
  SELECT id, content, namespace, score
  FROM combined
  ORDER BY score DESC
  LIMIT match_count;
$$;
```

**Dart call (planned — do not write until migration is done):**
```dart
final results = await supabase.rpc('match_documents', params: {
  'query_embedding': embedding,
  'query_text':      question,
  'match_count':     3,
  'p_namespace':     namespace,   // e.g. 'course_CSE301' or 'admin_global'
});
```

Weights: vector 0.7 + text 0.3 — tunable.
For exact campus terms (room numbers, teacher codes) consider 0.6 / 0.4.

---

## GITHUB BRANCH STRATEGY

```
main (protected — tagged releases only: v1.0.0-defense)
develop (integration — all PRs target here, always runnable)
  |
  |-- feature/app-foundation        Fahmid  Days 1-6   MERGED
  |-- feature/auth                  Fahmid  Days 2-7   MERGED
  |-- feature/shared-widgets        Fahmid  Days 6-8   NEXT
  |-- feature/student-core          Robi    Days 7-14  blocked on shared-widgets
  |-- feature/notifications-profile Ratul   Days 7-14  blocked on shared-widgets
  |-- feature/teacher-screens       Robi    Week 3     pending
  |-- feature/admin-screens         Fahmid  Week 3     pending
  +-- feature/timetable-engine      Fahmid  Day 28     stretch goal (Python repo)
```

**Branch protection on main:** require PR + 1 approval · no force push
**Commit format:** `feat|fix|chore|refactor(module): description`
**Examples:** `feat(routine): add live countdown timer` · `fix(ai): handle empty pgvector result`

---

## HARD CONSTRAINTS — NEVER VIOLATE

- **No hardcoded hex colors** -> always `AppColors.*`
- **No raw spacing numbers** -> always `AppSpacing.*`
- **No raw `TextStyle()`** -> always `AppTextStyles.*` with `.copyWith()` for overrides
- **No `MaterialPageRoute`** -> always `context.go()` with `RouteNames.*`
- **No Supabase calls in screens** -> controller -> service only
- **No Supabase calls in controllers** -> service layer only
- **`is_late` is a DB trigger** -> never compute in Dart
- **No Riverpod, Bloc, or Provider** -> `ChangeNotifier` only
- **No hardcoded route strings** -> `RouteNames.*` only
- **All icons from phosphor_flutter** -> `PhosphorIconsRegular.*`
- **Font is Inter, set globally** -> never set `fontFamily` in individual widgets
- **App name is UniVerse** -> never "EduPilot" or any other variant
- **One ThemeData only** -> `AppTheme.dark` — no light theme
- **`setPendingRole()` does not exist** -> removed; role assigned by service or registration completion
- **`value` on DropdownButtonFormField is deprecated** (after Flutter v3.33.0-1.0.pre) -> use `initialValue:` instead
- **Shared infrastructure files** -> only Fahmid edits `app_router`, `route_names`, `app_constants`, `pubspec.yaml`, `main.dart`
- **`documents.category` != namespace** -> category = content type label, namespace = access scope (column to be added later)
- **Never run documents migration** without simultaneously updating `ai_assistant_service.dart`

---

## IMPORT CONVENTION

```dart
// Always package imports — never relative imports
import 'package:universe_v1/core/theme/app_colors.dart';
import 'package:universe_v1/core/theme/app_text_styles.dart';
import 'package:universe_v1/core/theme/app_spacing.dart';
import 'package:universe_v1/core/constants/app_constants.dart';
import 'package:universe_v1/core/router/route_names.dart';
```

---

## QUICK REFERENCE

### Add a new screen
1. Create file in `features/<feature>/screens/`
2. Add constant in `route_names.dart` (Fahmid)
3. Add `GoRoute` in `app_router.dart` (Fahmid)
4. Add to `authPages` list if it's an auth screen

### Add a new Supabase table
1. Run SQL in Supabase SQL editor
2. Add table name constant in `app_constants.dart`
3. Create service method in `features/<feature>/services/`
4. Add RLS policies (read_all + admin_write pattern above)

### Add a new shared widget
1. Create in `lib/shared/widgets/`
2. Import `AppColors`, `AppTextStyles`, `AppSpacing` — nothing else from core
3. Accept all configuration via constructor params — no hardcoded values

### Documents table migration checklist (do ALL steps in one sitting)
- [ ] Add `namespace TEXT NOT NULL DEFAULT 'admin_global'`
- [ ] Add `content_tsv TSVECTOR GENERATED ALWAYS AS (...) STORED`
- [ ] Create GIN index on `content_tsv`
- [ ] Replace `match_documents()` RPC with hybrid version above
- [ ] Update all Dart INSERT calls to pass `namespace`
- [ ] Update `ai_assistant_service.dart` RPC call to pass `query_text` + `p_namespace`
- [ ] Test: exact term query (e.g. "JIM", "ACL-1") returns correct chunks