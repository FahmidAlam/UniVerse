# CLAUDE.md — UniVerse Project Context
> Load this at the start of every session. Dense reference only — no fluff.

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
| Advisor | Kazi Md. Jahid Hasan |
| Defense deadline | 30 days from Day 1 (started May 2026) |
| Flutter package name | `universe` |
| Android applicationId | `com.example.universe_v1` |

**Three actor types:** Student · Teacher · Admin  
**Critical differentiator (advisor-required):** Automatic department timetable generator using OR-Tools CP-SAT

---

## TEAM ROLES

| Member | ID | Role |
|---|---|---|
| Fahmid Alam | 0182320012101309 | Project Lead · Backend · AI pipeline · Architecture · Admin screens |
| Swadheen Islam Robi | 0182320012101278 | UI/UX · Frontend · Feature modules · Student core screens |
| Shahriar Rashid Ratul | 0182320012101276 | QA · Testing · Notifications · Data seeding · Polish |

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
- **Gemini API** — `text-embedding-004` (768-dim vectors) + `gemini-2.0-flash` (generation)
- **Google OAuth** — via Supabase Auth, PKCE flow
- **FastAPI (Python)** — timetable engine, deployed on Railway/Render free tier
- **OR-Tools CP-SAT** — constraint solver for timetable generation

### Auth deep link scheme
```
com.example.universe_v1://login-callback/
com.example.universe_v1://reset-callback/
```

---

## DESIGN SYSTEM

> All tokens are in `lib/core/theme/`. **Never hardcode hex values or raw numbers in widgets.**

### Color tokens (`app_colors.dart`) — KEY VALUES
```dart
bgPrimary   = #0F0F10   // screen background
bgCard      = #1A1A1C   // card surfaces
bgElevated  = #222325   // inputs, chips
primary     = #FF7A00   // orange — CTA, active nav, live badge
primarySoft = #2A1A0A   // orange badge backgrounds
primaryMuted= #3D2000   // selected chip backgrounds
textPrimary = #FFFFFF
textSecondary = #B0B3B8
textMuted   = #6E7278
border      = #2A2C30
navBg       = #111113
success     = #22C55E / successSoft = #0D2E1A
info        = #3B82F6 / infoSoft    = #0D1F3C
warning     = #F59E0B / warningSoft = #2D1E00
error       = #EF4444 / errorSoft   = #2D0D0D
```

### Text styles (`app_text_styles.dart`)
`h1` 24/700 · `h2` 18/600 · `h3` 16/600 · `h4` 14/600  
`body` 14/400 · `bodyMedium` 14/500 · `bodySm` 13/400  
`badge` 10/700 uppercase · `chip` 12/500 · `label` 12/500  
`button` 15/600 · `link` 13/500 orange · `danger` 14/500 red  
`countdown` 30/700 orange · `statNumber` 22/700 orange  

### Spacing (`app_spacing.dart`)
`xs=4 sm=8 md=12 lg=16 xl=20 xxl=24 x3l=32 x4l=40 x5l=48`  
`screenH=20 screenV=16` · `buttonHeight=52` · `inputHeight=52`  
`radiusSm=8 radiusMd=12 radiusLg=16 radiusXl=20 radiusFull=100`  
`borderAccent=3` (notification left border)

### Theme entry point
`AppTheme.dark` — wire in `MaterialApp.router(theme: AppTheme.dark)`  
`AppTheme.setSystemUI()` — call once in `main()` before `runApp()`  
Font: **Inter** via `GoogleFonts.interTextTheme()` — set in app_theme.dart, inherited everywhere  
Icons: **phosphor_flutter** — always use `PhosphorIconsRegular.*`

---

## ARCHITECTURE RULES

### Layer structure (feature-first)
```
lib/
  main.dart
  core/
    theme/         ← app_colors, app_text_styles, app_spacing, app_theme
    router/        ← app_router, route_names
    constants/     ← app_constants
    utils/         ← date_utils, extensions, validators  [TO BUILD]
  shared/
    widgets/       ← reusable u_* widgets + domain cards  [TO BUILD]
  features/
    auth/          ← screens, controllers, services, widgets
    dashboard/     [TO BUILD]
    routine/       [TO BUILD]
    ai_assistant/  [TO BUILD]
    resources/     [TO BUILD]
    notifications/ [TO BUILD]
    profile/       [TO BUILD]
    teacher/       [TO BUILD]
    admin/         [TO BUILD]
```

### Hard folder rules
- Screens only in `features/<feature>/screens/`
- Reusable widgets only in `shared/widgets/` or `features/<feature>/widgets/`
- All Supabase calls only in `features/<feature>/services/`
- Controllers only call services, never call Supabase directly
- Screens only call controllers, never call services directly

### State management
- `ChangeNotifier` + `ListenableBuilder` — **no Riverpod, no Bloc, no Provider**
- `setState` allowed for local UI state (toggle, form, animation)
- Supabase Realtime streams for live notifications

### Navigation
- **GoRouter ^14** — single `AppRouter` instance, passed to `MaterialApp.router`
- All route paths as constants in `RouteNames`
- `redirect` logic in `AppRouter` — screens never guard themselves
- `authController` is the `refreshListenable` — changing status triggers redirect

---

## SUPABASE SCHEMA

### Tables (all created)
| Table | Purpose |
|---|---|
| `whitelists` | Admin pre-registers emails before users can join |
| `profiles` | Extended user data linked to `auth.users` |
| `routines` | Weekly class schedule entries |
| `cancellations` | Teacher class cancellations |
| `notifications` | All notification types |
| `resources` | Academic resources (PDFs, Drive links) |
| `assignments` | Teacher-created assignments |
| `submissions` | Student file submissions with `is_late` trigger |
| `documents` | RAG vector store (content + embedding VECTOR(768)) |
| `generated_timetable` | Output of OR-Tools timetable engine |

### Key schema details
- `submissions.is_late` — set by PostgreSQL trigger `calculate_is_late`, NOT in Dart code
- `documents.embedding` — `VECTOR(768)`, requires `pgvector` extension
- `match_documents(query_embedding, match_count)` — Postgres RPC for cosine similarity search
- HNSW index on `documents.embedding` for fast vector search

### RLS pattern (applied to all tables)
```sql
ALTER TABLE t ENABLE ROW LEVEL SECURITY;
CREATE POLICY "read_all" ON t FOR SELECT USING (true);
CREATE POLICY "admin_write" ON t FOR INSERT
  WITH CHECK (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));
```

### Storage buckets
`avatars` (public) · `resources` (public) · `assignments` (public)  
Open storage policy for MVP — tighten before production.

### Auth methods supported
1. **Google OAuth** — PKCE flow via `supabase.auth.signInWithOAuth(OAuthProvider.google)`
2. **Email + Password** — `signUp()` + `signInWithPassword()` + email verification

### Whitelist gate
Every sign-in (both OAuth and email) checks `whitelists` table by email.  
If email not found → sign out user → redirect to `not_whitelisted` screen.  
Profile created from whitelist data on first login only.

---

## AUTH FLOW (COMPLETE)

```
Splash → check session
  ├─ session exists + verified  → load profile → role dashboard
  ├─ session exists + unverified → VerifyEmailScreen
  └─ no session → check SharedPrefs
        ├─ onboarding not seen → OnboardingScreen
        └─ onboarding seen → LoginScreen

LoginScreen
  ├─ Continue with Google → OAuth → whitelist check → dashboard
  ├─ Email/password form → whitelist check → dashboard / verify screen
  └─ Create account → RoleSelectionScreen
        ├─ Student → StudentRegisterScreen → Google OAuth → profile upsert
        ├─ Teacher → FacultyRegisterScreen → Google OAuth → profile upsert
        └─ Admin   → info sheet (admin accounts created by dept head)

Email signup path:
  EmailSignupScreen → signUp() → VerifyEmailScreen (polls + resend)
  → user clicks link → session refresh → handlePostLogin() → dashboard

Password reset path:
  ForgotPasswordScreen → resetPasswordForEmail() → email sent
  → user clicks link (deep link) → ResetPasswordScreen → updateUser()
```

### AuthStatus enum
`initial · loading · authenticated · unauthenticated · notWhitelisted · awaitingVerification · error`

---

## SCREEN INVENTORY

| # | Screen | Route | Status |
|---|---|---|---|
| 1 | Splash | `/` | ✅ Built |
| 2 | Onboarding (3 slides) | `/onboarding` | ✅ Built |
| 3 | Login (Google + email) | `/login` | ✅ Built |
| 4 | Email Sign In | `/login/email` | ✅ Built |
| 5 | Email Sign Up | `/signup/email` | ✅ Built |
| 6 | Verify Email | `/verify-email` | ✅ Built |
| 7 | Forgot Password | `/forgot-password` | ⚠️ Route wired, screen file missing |
| 8 | Role Selection | `/role-selection` | ✅ Built |
| 9 | Student Register | `/register/student` | ✅ Built |
| 10 | Faculty Register | `/register/faculty` | ✅ Built |
| 11 | Not Whitelisted | `/not-whitelisted` | ✅ Built |
| 12 | Student Dashboard | `/student/dashboard` | 🔲 Placeholder |
| 13 | AI Chat Assistant | `/student/ai-assistant` | 🔲 Placeholder |
| 14 | Student Routine | `/student/routine` | 🔲 Placeholder |
| 15 | Resource Hub | `/student/resources` | 🔲 Placeholder |
| 16 | Notifications | `/notifications` | 🔲 Placeholder |
| 17 | Profile | `/profile` | 🔲 Placeholder |
| 18 | Teacher Dashboard | `/teacher/dashboard` | 🔲 Placeholder |
| 19 | Teacher Routine | `/teacher/routine` | 🔲 Placeholder |
| 20 | Manage Classes & Notice | `/teacher/manage-classes` | 🔲 Placeholder |
| 21 | Admin Dashboard | `/admin/dashboard` | 🔲 Placeholder |
| 22 | Routine Management | `/admin/routine` | 🔲 Placeholder |
| 23 | Campus Broadcast | `/admin/broadcast` | 🔲 Placeholder |
| 24 | Admin Registration | `/admin/registration` | 🔲 Placeholder |
| 25 | Manage Users | `/admin/users` | 🔲 Placeholder |

---

## FILES ALREADY CREATED

### Core
| Path | Purpose |
|---|---|
| `lib/main.dart` | App entry — Supabase init, AppTheme, GoRouter, auth stream |
| `lib/core/theme/app_colors.dart` | All color tokens |
| `lib/core/theme/app_text_styles.dart` | All text styles |
| `lib/core/theme/app_spacing.dart` | All spacing/radius/dimension tokens |
| `lib/core/theme/app_theme.dart` | Full ThemeData wiring all tokens |
| `lib/core/router/route_names.dart` | All route path constants |
| `lib/core/router/app_router.dart` | GoRouter with full role-based redirect logic |
| `lib/core/constants/app_constants.dart` | Supabase URLs, table names, slots, semesters |

### Auth feature
| Path | Purpose |
|---|---|
| `lib/features/auth/services/auth_service.dart` | All Supabase auth ops — Google OAuth + email/password |
| `lib/features/auth/controllers/auth_controller.dart` | ChangeNotifier state manager for all auth flows |
| `lib/features/auth/screens/splash_screen.dart` | Animated logo, session check, routing |
| `lib/features/auth/screens/onboarding_screen.dart` | 3-slide PageView, SharedPrefs flag |
| `lib/features/auth/screens/login_screen.dart` | Google + email/password login, animated form |
| `lib/features/auth/screens/email_login_screen.dart` | Dedicated email sign-in screen |
| `lib/features/auth/screens/email_signup_screen.dart` | Email sign-up with password strength bar |
| `lib/features/auth/screens/verify_email_screen.dart` | Email verification — polling + resend + cooldown |
| `lib/features/auth/screens/role_selection_screen.dart` | Student/Teacher/Admin role cards |
| `lib/features/auth/screens/student_register_screen.dart` | Student registration form + Google OAuth |
| `lib/features/auth/screens/faculty_register_screen.dart` | Faculty registration form + Google OAuth |
| `lib/features/auth/screens/not_whitelisted_screen.dart` | Email not in whitelist — contact admin |
| `lib/features/auth/screens/placeholder_screen.dart` | Temporary screen for unbuilt routes |
| `lib/features/auth/widgets/onboard_slide.dart` | Single onboarding slide widget |
| `lib/features/auth/widgets/google_sign_in_button.dart` | White Google OAuth button |

### Config
| Path | Purpose |
|---|---|
| `pubspec.yaml` | All dependencies pinned |

---

## WHAT STILL NEEDS BUILDING

### Immediate (to complete auth)
- [ ] `lib/features/auth/screens/forgot_password_screen.dart` — email field + send reset
- [ ] `lib/features/auth/screens/reset_password_screen.dart` — new password form (deep link entry)

### Next up (shared widgets — build in this order)
1. `u_button.dart` · `u_text_field.dart` · `u_card.dart` · `u_divider.dart`
2. `u_badge.dart` · `u_chip.dart` · `u_avatar.dart` · `u_app_bar.dart`
3. `u_bottom_nav.dart` · `u_section_header.dart` · `u_empty_state.dart` · `u_loading.dart`
4. `class_card.dart` · `live_class_card.dart` · `notification_tile.dart`
5. `resource_card.dart` · `chat_bubble.dart` · `day_selector.dart`
6. `role_card.dart` · `stat_card.dart` · `info_row.dart` · `settings_tile.dart` · `quick_action_card.dart`

### Then core utils
- `date_utils.dart` — countdown timer logic, time slot helpers
- `validators.dart` — form validation functions
- `extensions.dart` — String, DateTime convenience extensions

### Then feature screens (30-day roadmap order)
Week 2: Teacher Directory · Resource Hub · Notification feed  
Week 3: RAG ingestion pipeline · AI chat · Teacher cancellation · Supabase Realtime  
Week 4: Polish · Assignment screens · Timetable engine (stretch goal Day 28)

---

## TIMETABLE ENGINE (FastAPI — Fahmid)

- Language: Python · Framework: FastAPI · Solver: `ortools` CP-SAT
- Deployed: Railway or Render free tier
- Endpoints:
  - `POST /api/timetable/generate` — upload Excel, returns `job_id`
  - `GET /api/timetable/status/{job_id}` — poll every 3s during solve
  - `GET /api/timetable/download/{job_id}` — get filled Excel
  - `GET /api/timetable/result/{job_id}` — get JSON for Supabase insert
- Real data: 343 offerings · 686 class slots · 76 teachers · 68 sections · 27 rooms · 5 days · 5 slots/day
- Teacher day-offs: `EBH` Thu · `RLP` Thu · `STA` Sun · `JIM` Sun
- Phase 1: CP-SAT assigns (day, slot) — hard constraints: teacher no-conflict, section no-conflict, different days for same offering's two classes
- Phase 2: Greedy room assignment — sessionals → labs first (ACL-1/2/NL/GL/ECL), theory → any of 20 theory rooms

---

## RAG AI PIPELINE (Gemini — Fahmid)

- Embedding: `POST https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent`
- Generation: Gemini Flash with constrained prompt ("Answer only using this context")
- Ingestion: DB rows → natural language sentences → embed → bulk insert `documents` table
- Query: embed question → `match_documents()` RPC → top 3 chunks → Gemini Flash → chat UI
- No relevant chunks → return `"I don't have information about that yet."`
- Supabase RPC: `supabase.rpc('match_documents', params: {'query_embedding': vector, 'match_count': 3})`

---

## HARD CONSTRAINTS

- **Never hardcode hex colors** — always `AppColors.*`
- **Never hardcode spacing numbers** — always `AppSpacing.*`
- **Never write raw `TextStyle()`** — always `AppTextStyles.*` with `.copyWith()` for overrides
- **Never use `MaterialPageRoute`** — always `context.go()` / `context.push()` with `RouteNames.*`
- **Never call Supabase from a screen** — always via controller → service
- **Never call Supabase from a controller** — only via service layer
- **`is_late` in submissions is a DB trigger** — never compute it in Dart
- **Never use `Provider`, `Riverpod`, or `Bloc`** — only `ChangeNotifier`
- **Never hardcode route strings** — always `RouteNames.*`
- **All icons from `phosphor_flutter`** — `PhosphorIconsRegular.*`
- **Font is Inter** — set globally in `app_theme.dart`, never specify `fontFamily` in widgets
- **App name is always UniVerse** — never "EduPilot" or any other name
- **Only one `ThemeData`** — `AppTheme.dark` — no light theme exists
- **`forgot_password_screen.dart` is missing** — router imports it, build it before running

---

## GITHUB BRANCH STRATEGY

```
main (protected — tagged releases only: v1.0.0-defense)
develop (integration — all PRs merge here)
  feature/app-foundation   (Fahmid, Days 1–6)
  feature/auth             (Fahmid, Days 2–7)
  feature/student-core     (Robi, Days 7–14)
  feature/notifications-profile (Ratul, Days 7–14)
  feature/teacher-screens  (Robi, Week 3)
  feature/admin-screens    (Fahmid, Week 3)
  feature/timetable-engine (Fahmid, separate Python repo)
```

Commit format: `feat|fix|chore|refactor(module): description`

---

## QUICK REFERENCE

### Add a new screen
1. Create file in `features/<feature>/screens/`
2. Add route constant in `route_names.dart`
3. Add `GoRoute` in `app_router.dart`
4. Add to `authPages` list in router if it's an auth screen

### Add a new Supabase table
1. Run SQL in Supabase editor
2. Add table name constant in `app_constants.dart`
3. Create service method in `features/<feature>/services/`
4. Add RLS policies (read_all + admin_write pattern)

### Import convention
```dart
// Always use package imports, never relative
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/router/route_names.dart';
```