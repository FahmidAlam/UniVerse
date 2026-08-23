# -*- coding: utf-8 -*-
"""
Generates one defense-prep PDF per topic into docs/defense/.
Run from project root:  python tool/make_defense_docs.py

Each build_* function owns one topic's content and saves its own PDF,
so teammates can study features independently. Grounded in the real code.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from defense_pdf_kit import Doc  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "docs", "defense")
os.makedirs(OUT, exist_ok=True)

META = [
    "Leading University, Sylhet - Dept. of CSE",
    "Course CSE-3240 (Project I) - Team Sherlocked",
    "Flutter (Dart) - Supabase - Firebase FCM - OR-Tools CP-SAT",
]


def _p(name):
    return os.path.join(OUT, name)


# ============================================================
# 0. START HERE - OVERVIEW
# ============================================================
def build_index():
    d = Doc("Start Here - Defense Overview",
            "Read this first. The whole app on two pages, then one PDF per "
            "feature.")
    d.cover(META + ["", "Team Sherlocked - Advisor: Jaminur Rahman",
                    "App: UniVerse - A Campus Companion (Android, Flutter)"])

    d.h1("1. The 30-second pitch")
    d.p("UniVerse is a role-aware campus companion for students, teachers and admins at "
        "Leading University. It unifies routines, resources, class cancellations and "
        "notifications in one app - and its differentiator is an **automatic, clash-free "
        "department timetable generator** powered by an OR-Tools CP-SAT constraint solver.")

    d.h1("2. The one architecture rule (every feature follows it)")
    d.p("Every feature is a vertical slice with the SAME four layers. If you remember one "
        "thing for the defense, remember this chain:")
    d.code("Screen  ->  Controller  ->  Service  ->  Supabase / Engine\n"
           " (UI)      (state, logic)   (data calls)   (backend)")
    d.kv([
        ("Screen", "Pure UI. Reads the controller, renders widgets. NEVER touches Supabase."),
        ("Controller", "A ChangeNotifier holding state + logic. Calls services, then notifyListeners()."),
        ("Service", "The ONLY layer that talks to Supabase / HTTP. Returns typed models."),
        ("Model", "Typed view of a DB row (e.g. RoutineEntry, Profile). Pure Dart."),
    ], c1="layer", c2="responsibility", w1=34)
    d.p("State management is plain **ChangeNotifier + ListenableBuilder** - no Riverpod/"
        "Bloc. The UI rebuilds when a controller calls notifyListeners().")

    d.h1("3. Tech stack")
    d.kv([
        ("Frontend", "Flutter (Dart 3.9), GoRouter, google_fonts (Inter), phosphor icons."),
        ("Backend", "Supabase - Postgres + Auth + Storage + Realtime, secured with Row Level Security (RLS)."),
        ("Push", "Firebase Cloud Messaging (FCM) via a send-push Edge Function."),
        ("Engine", "FastAPI + Google OR-Tools CP-SAT (Python), deployed on Render."),
        ("Auth", "Google OAuth (PKCE) + email/password; admin whitelist gate."),
    ], c1="area", c2="what we use", w1=34)

    d.h1("4. Who owns what (so you answer your own slice)")
    d.kv([
        ("Fahmid Alam", "Architecture, shared infra, auth, admin + timetable engine, theming, routing."),
        ("Swadheen Islam (Robi)", "Routine, resources, dashboards, teacher screens, Find Teacher, Rooms."),
        ("Shahriar Rashid (Ratul)", "Notifications, push, profile, QA, seeding."),
    ], c1="member", c2="owns", w1=46)

    d.h1("5. The document set (study your slice, skim the rest)")
    d.kv([
        ("01 Routing", "One GoRouter + a redirect guard; tabs vs pushed screens."),
        ("02 Theming", "Design tokens (colors/text/spacing) wired via AppTheme."),
        ("03 Authentication", "OAuth + email, the AuthStatus machine, the whitelist gate."),
        ("04 Routine", "One table, two read paths; the time/status helpers."),
        ("05 Student Dashboard", "Live/next/done hero derived from the routine."),
        ("06 Teacher Features", "Cancel/notice/undo + the cancellations table."),
        ("07 Resources", "Semester folders, admin upload to Storage."),
        ("08 Notifications & Push", "One insert -> Realtime feed + FCM push."),
        ("09 Profile", "Read/update own row; the textbook layering example."),
        ("10 Admin & Engine", "The differentiator: CP-SAT timetable pipeline."),
        ("11 Find Teacher", "Schedule-derived real-time teacher locator."),
        ("12 Room Availability", "Schedule-derived real-time room occupancy."),
    ], c1="PDF", c2="covers", w1=44)
    d.tip("Each feature PDF ends with a 'Likely defense questions' table - rehearse those "
          "out loud. The answers are written the way you'd say them to the examiner.")

    d.save(_p("00_START_HERE.pdf"))
    print("  + 00_START_HERE.pdf")


# ============================================================
# 1. ROUTING & NAVIGATION
# ============================================================
def build_routing():
    d = Doc("Routing & Navigation",
            "How the app decides which screen to show, and how every "
            "screen is reached.")
    d.cover(META + ["", "Owner: Fahmid (shared infrastructure)",
                    "Key files: main.dart, core/router/*, shared/widgets/app_bottom_nav.dart"])

    d.h1("1. The big picture (say this first)")
    d.p("UniVerse has **one** router for the whole app - a single GoRouter built in "
        "**app_router.dart**. There is no `Navigator.push(MaterialPageRoute(...))` "
        "anywhere. Every screen is reached through a **named route constant** "
        "(RouteNames.*), and a central **redirect** function decides, on every "
        "navigation, whether the user is allowed to be there.")
    d.bullet("**route_names.dart** - every path string as a constant (no hardcoded '/login').")
    d.bullet("**app_router.dart** - the GoRouter: the route table + the auth redirect guard.")
    d.bullet("**app_shell.dart** - one Scaffold + bottom nav wrapped around all tab screens.")
    d.bullet("**app_bottom_nav.dart** - the single source of truth for each role's tabs.")
    d.tip("We use declarative routing - the URL is the single source of truth for what is "
          "on screen, and one guard protects every route instead of scattered checks.")

    d.h1("2. Startup flow (main.dart)")
    d.flow([
        "**ensureInitialized()** + `AppTheme.setSystemUI()` - lock portrait, set status bar.",
        "On mobile: **Firebase.initializeApp()** then **PushService.init()** (skipped on web - there is no web Firebase config).",
        "**Supabase.initialize()** with `AuthFlowType.pkce` - PKCE is the secure OAuth flow for mobile.",
        "Create **AuthController** (the app's auth brain) and **AppRouter** (wraps GoRouter).",
        "Subscribe to `authStateChanges`: on signed-in resolve the session + save the FCM token; on passwordRecovery jump to the reset screen.",
        "**runApp(UniVerseApp)** -> `MaterialApp.router(theme: AppTheme.dark, routerConfig: router.router)`.",
    ])
    d.p("Important detail for the viva: the auth listener only resolves a session when no "
        "controller-driven flow is already doing it (email sign-in / OTP verify do it "
        "themselves). Double-resolving would race the router into the wrong redirect.")

    d.h1("3. The redirect guard (the heart of routing)")
    d.p("`refreshListenable: authController` means **every time auth state changes, the "
        "router re-runs `redirect()`**. The guard reads `authController.status` and the "
        "target location, and returns either `null` (allow) or a path to bounce to.")
    d.kv([
        ("initial / loading", "Force to Splash until auth resolves."),
        ("notWhitelisted", "Force to the Not-Whitelisted screen (rejected admin)."),
        ("awaitingVerification", "Force to Verify-Email screen."),
        ("registering", "Session exists but no profile yet (first Google login / OTP verified). Allow the auth/register pages; otherwise send to Role Selection."),
        ("unauthenticated / error", "Allow auth pages; otherwise force to Login."),
        ("authenticated", "If on an auth page -> send to the role's dashboard. If on the WRONG role's section (e.g. student on /admin) -> bounce to own dashboard."),
    ], c1="auth status", c2="what the guard does", w1=42)
    d.p("`_dashboardForRole()` maps role -> landing route (student/teacher/admin "
        "dashboard). `_isWrongRolePage()` enforces role isolation by URL prefix "
        "(/student, /teacher, /admin). This is why a student can never deep-link into "
        "an admin screen.")
    d.tip("The redirect is the ONLY place navigation rules live - screens never check "
          "'is the user allowed here', they just exist; the guard decides.")

    d.h1("4. Route table: tabs vs secondary screens")
    d.p("The route list has two kinds of routes, and knowing the difference is a likely "
        "question:")
    d.h2("a) Tab screens - inside the ShellRoute")
    d.p("A **ShellRoute** wraps a group of routes in one persistent **AppShell** "
        "(one Scaffold + one bottom nav). The child route only renders its content; "
        "the shell draws the nav bar around it. Tab screens: student dashboard/routine/"
        "resources/alerts/profile, teacher dashboard/routine/manage, admin dashboard/"
        "broadcast/routine/users.")
    d.h2("b) Secondary screens - top-level routes (pushed)")
    d.p("Screens reached by a back button - NOT tabs - sit outside the shell so they have "
        "no bottom nav: Rooms, Find Teacher, Admin Registration, Manage Resources, "
        "Resource Library, Broadcast History, Manage Rooms/Faculty, Timetable Settings, "
        "Timetable Grid.")
    d.code("// passing data to a pushed route via `extra`:\n"
           "context.push(RouteNames.timetableGrid, extra: rows);\n"
           "// received:\n"
           "TimetableGridScreen(rows: (s.extra as List<RoutineEntry>?) ?? const [])")

    d.h1("5. AppShell - the persistent frame")
    d.p("**app_shell.dart** owns the only Scaffold for tab screens. It:")
    d.bullet("Derives the active tab from the current router location (`GoRouterState.of(context).matchedLocation`) - screens don't track their own selection.")
    d.bullet("Hosts the app-scoped **NotificationController**: starts ONE Realtime subscription for the whole session so the unread badge is live on every tab.")
    d.bullet("Shows the **ExploreFabMenu** floating button only on the three dashboards (`/student|teacher|admin/dashboard`).")
    d.bullet("Re-fetches notifications if the signed-in user changes, so one account's alerts never leak into another's badge.")

    d.h1("6. AppBottomNav - role-aware tabs")
    d.p("`destinationsFor(role)` is the **single source of truth** for tabs. A switch on "
        "role returns the list of `AppNavDest(icon, label, route)`:")
    d.kv([
        ("Student", "Home - Routine - Resources - Alerts - Profile"),
        ("Teacher", "Home - Routine - Manage - Alerts - Profile"),
        ("Admin", "Dashboard - Broadcast - Routine - Users - Profile"),
    ], c1="role", c2="tabs", w1=30)
    d.p("The active index is computed by matching the current route; the Alerts tab shows "
        "the unread badge. Tapping calls `context.go(route)` (replaces, doesn't stack). "
        "Because tabs are derived from role + location, shared screens (Profile, Alerts) "
        "always show the correct tab set for whoever is logged in.")

    d.h1("7. Likely defense questions")
    d.kv([
        ("Why GoRouter not Navigator?", "Declarative + URL-driven; one central guard; deep links and role redirects are trivial. Navigator.push everywhere would scatter the auth checks."),
        ("How is a student blocked from /admin?", "redirect() -> _isWrongRolePage() checks the URL prefix against the role and bounces to the user's own dashboard."),
        ("Why a ShellRoute?", "So the bottom nav persists across tab switches (one Scaffold) instead of every screen rebuilding its own nav bar."),
        ("How do tabs stay in sync?", "Active tab is derived from the router location, not stored - impossible to get out of sync."),
        ("Where are route strings?", "All in route_names.dart - no screen hardcodes a path."),
    ], c1="question", c2="answer", w1=52)

    d.save(_p("01_Routing_and_Navigation.pdf"))
    print("  + 01_Routing_and_Navigation.pdf")


# ============================================================
# 2. THEMING & DESIGN SYSTEM
# ============================================================
def build_theming():
    d = Doc("Theming & Design System",
            "How one set of tokens controls every color, font and spacing "
            "in the app.")
    d.cover(META + ["", "Owner: Fahmid (shared infrastructure)",
                    "Key files: core/theme/app_colors.dart, app_text_styles.dart, "
                    "app_spacing.dart, app_theme.dart"])

    d.h1("1. The idea (say this first)")
    d.p("UniVerse uses a **centralized design system**. Nothing is hardcoded in screens - "
        "every color, text style and spacing value is a **named token** in four files "
        "under `core/theme/`. Change one token and the whole app updates. This is a hard "
        "project rule: no raw hex, no raw `TextStyle()`, no magic numbers in widgets.")
    d.kv([
        ("app_colors.dart", "Every color as a named constant (AppColors.primary, bgCard...)."),
        ("app_text_styles.dart", "Every TextStyle (h1, body, badge, countdown...)."),
        ("app_spacing.dart", "Spacing, radii, icon sizes, component heights."),
        ("app_theme.dart", "Wires all tokens into Flutter's ThemeData (one line in main)."),
    ], c1="file", c2="responsibility", w1=46)
    d.tip("If the advisor says 'make the orange blue', I change ONE line - "
          "AppColors.primary - and all 60+ screens update. No find-and-replace across files.")

    d.h1("2. Colors (app_colors.dart)")
    d.p("`abstract class AppColors` holds only `static const Color` values, grouped by "
        "purpose so the palette reads like a system, not a random list:")
    d.bullet("**Background layers** - bgPrimary (screen) < bgCard (cards) < bgElevated (inputs/chips). A depth stack.")
    d.bullet("**Brand** - primary `#FF7A00` (the one personality color), plus primaryDark / primarySoft / primaryMuted for states.")
    d.bullet("**Text hierarchy** - exactly four shades: textPrimary, textSecondary, textMuted, textDisabled. Never any other grey.")
    d.bullet("**Semantic/status** - success/info/warning/error/done, each with a FULL color (text/icon) and a SOFT color (badge background).")
    d.bullet("**Notification type colors** - the 3px left border that tells you the alert type at a glance (cancel=red, room=blue, exam=orange...).")
    d.bullet("**Role colors** - student=green, teacher=blue, admin=orange.")
    d.code("Container(color: AppColors.bgCard)\n"
           "Text('LIVE', style: TextStyle(color: AppColors.success))\n"
           "// opacity helper, no magic numbers:\n"
           "AppColors.withOpacity(AppColors.primary, 0.15)")

    d.h1("3. Text styles (app_text_styles.dart)")
    d.p("`abstract class AppTextStyles` defines every `TextStyle` as a named token on a "
        "clear scale. Widgets use these instead of writing `TextStyle(fontSize: ...)`.")
    d.kv([
        ("h1 / h2 / h3 / h4", "Heading scale - one h1 per screen, h2 for sections."),
        ("body / bodyMedium / bodySm", "Reading text + metadata."),
        ("chip / label / labelCaps / badge", "Small purposeful text (pills, form labels, status badges)."),
        ("countdown / statNumber", "Big display numbers (live-class timer, dashboard stats)."),
        ("button / link / danger", "Interactive text."),
    ], c1="token group", c2="use", w1=52)
    d.p("You override with `.copyWith()` instead of making a new style: "
        "`AppTextStyles.bodySm.copyWith(color: AppColors.error)`. Note: the font family "
        "is NOT set here - it is applied globally in app_theme via GoogleFonts, so every "
        "style inherits **Inter** automatically.")

    d.h1("4. Spacing (app_spacing.dart)")
    d.p("All paddings, gaps, corner radii, icon sizes and component heights are tokens on "
        "a consistent scale (xs4, sm8, md12, lg16, xl20, xxl24...). Radius objects "
        "(radiusSm..radiusXxl) + their double values, plus fixed component sizes like "
        "buttonHeight, inputHeight, appBarHeight, icon sizes. This keeps every screen on "
        "the same rhythm.")

    d.h1("5. app_theme.dart - wiring it into Flutter")
    d.p("This is the single entry point that maps all tokens into Flutter's **ThemeData**, "
        "so built-in widgets look correct with zero extra styling. Used in main.dart as "
        "`theme: AppTheme.dark`.")
    d.h2("What AppTheme.dark configures")
    d.bullet("**ColorScheme.dark** - maps semantic roles (primary, surface, error...) to our tokens, so `colorScheme.primary` is our orange.")
    d.bullet("**textTheme: GoogleFonts.interTextTheme(...)** - sets Inter globally and maps Flutter's named styles (headlineLarge, bodyMedium...) to AppTextStyles.")
    d.bullet("**Component themes** - AppBar, BottomNavigationBar/NavigationBar, ElevatedButton (orange), inputs (orange focus border, red error border), chips, progress, checkbox, switch, snackbar, bottom sheet, list tile, popup menu, FAB.")
    d.p("`AppTheme.setSystemUI()` (called in main) makes the status bar transparent with "
        "light icons and locks portrait orientation.")
    d.h2("Theme vs custom widgets")
    d.p("ThemeData styles **built-in** Flutter widgets as a baseline. Our custom `U*` "
        "widgets (UButton, UTextField, UCard) read AppColors/AppTextStyles **directly** "
        "for precise control. Both pull from the same tokens, so they always match.")

    d.h1("6. Likely defense questions")
    d.kv([
        ("Why tokens, not inline styles?", "One source of truth -> consistent UI + one-line global changes. No hunting hex across files."),
        ("How is the font set everywhere?", "GoogleFonts.interTextTheme() in app_theme - every style inherits Inter; we never set fontFamily per widget."),
        ("Light mode later?", "Add AppColors light variant + AppTheme.light following the same structure, toggle in main. Structure already supports it."),
        ("Why abstract classes?", "They are pure namespaces of static consts - you never instantiate AppColors(), you read AppColors.primary."),
        ("Icons?", "phosphor_flutter, always PhosphorIconsRegular.* - one icon family for consistency."),
    ], c1="question", c2="answer", w1=52)

    d.save(_p("02_Theming_and_Design_System.pdf"))
    print("  + 02_Theming_and_Design_System.pdf")


# ============================================================
# 3. AUTH
# ============================================================
def build_auth():
    d = Doc("Authentication & Onboarding",
            "Sign-in, sign-up, the admin whitelist gate, and how the app "
            "knows who you are.")
    d.cover(META + ["", "Owner: Fahmid (auth + shared infra)",
                    "Key files: features/auth/controllers/auth_controller.dart, "
                    "services/auth_service.dart"])

    d.h1("1. What auth does (say this first)")
    d.p("UniVerse supports **two sign-in methods** - Google OAuth and email/password - "
        "and three roles (student, teacher, admin). The golden rule: **students and "
        "teachers sign up freely; only admins are gated by a whitelist.** Auth is split "
        "into three layers:")
    d.kv([
        ("auth_service.dart", "Raw Supabase calls (signIn, signUp, OTP verify, reset). The only file that touches Supabase auth."),
        ("auth_controller.dart", "A ChangeNotifier holding the auth state machine (AuthStatus) + the loaded profile. Screens listen to it."),
        ("auth screens", "12 screens: splash, onboarding, login, email login/signup, verify, forgot/reset, role selection, student/faculty register, not-whitelisted."),
    ], c1="layer", c2="job", w1=42)

    d.h1("2. The AuthStatus state machine")
    d.p("The controller exposes a single `AuthStatus` enum that the **router watches** "
        "(`refreshListenable`). Every screen change is a reaction to this status:")
    d.kv([
        ("initial", "App just launched, checking for an existing session."),
        ("loading", "An async auth call is in progress."),
        ("authenticated", "Signed in AND a profile row is loaded -> goes to dashboard."),
        ("unauthenticated", "Not signed in -> login."),
        ("registering", "Session exists but no profile yet (first Google login / verified email before profile built) -> register screens finish it."),
        ("notWhitelisted", "Admin account not in the whitelist -> rejected screen."),
        ("awaitingVerification", "Signed up, email not confirmed yet -> verify screen."),
        ("error", "Something failed -> message shown."),
    ], c1="status", c2="meaning", w1=44)
    d.tip("Auth is a state machine. The controller never navigates - it only changes "
          "status, and the router's redirect reacts. One brain, one source of truth.")

    d.h1("3. Google OAuth flow (2 steps)")
    d.flow([
        "User taps 'Continue with Google'. `signInWithGoogle()` calls Supabase `signInWithOAuth` with PKCE and the deep-link `com.example.universe://login-callback/`.",
        "Google opens in an external browser; the user picks an account.",
        "The browser redirects back to the app via the deep link. Supabase fires `onAuthStateChange(signedIn)` (caught in main.dart).",
        "main.dart calls `handleOAuthCallback()` -> `handlePostLogin()` resolves the profile / whitelist and sets the final status.",
    ])
    d.p("PKCE (Proof Key for Code Exchange) is the secure OAuth variant for mobile apps - "
        "no client secret is shipped in the app.")

    d.h1("4. The whitelist gate (admin only) - handlePostLogin()")
    d.p("This shared method runs after ANY successful login (Google or email). Its logic "
        "is the most important thing to explain:")
    d.flow([
        "**Profile exists?** Query `profiles` by user id. If a row exists -> returning user, log them straight in (no whitelist check at all).",
        "**First login** -> look up the email in the `whitelists` table.",
        "**Not whitelisted?** Return success but `profile = null` -> status becomes `registering`. The student/faculty register screen creates the profile. (We do NOT auto-create a student row - that would mislabel faculty.)",
        "**Whitelisted?** This is a pre-provisioned admin -> build the profile row directly from the whitelist entry and insert it.",
    ])
    d.p("So: a non-whitelisted user who tries to register **as admin** has no profile and "
        "no whitelist row -> they never become admin. Students/teachers simply complete "
        "their own registration. Admins are seeded into `whitelists` by the department.")

    d.h1("5. Email / password flow")
    d.bullet("**Sign up** -> `signUp()`; Supabase sends a confirmation email. No session yet -> status `awaitingVerification`.")
    d.bullet("**Verify** -> the user types the 6-digit OTP from the email into VerifyEmailScreen; `verifyEmailOtp()` confirms the email AND opens a session. (OTP is used instead of a link because email clients sometimes pre-fetch and burn the link.)")
    d.bullet("**Pending data** -> before sign-up, the register screen stores the user's name/ID/batch via `storePendingStudentData()`. After verification, `_completeFromPendingData()` builds the real profile automatically, so the user lands fully authenticated.")
    d.bullet("**Sign in** -> `signInWithPassword()`; if email isn't verified yet, sign out and route to verify.")
    d.bullet("**Forgot password** -> `resetPasswordForEmail()` with deep link `reset-callback`; tapping it fires `passwordRecovery` -> reset screen.")

    d.h1("6. Robustness details (good for follow-ups)")
    d.bullet("**De-duped resolution** - `handleOAuthCallback()` shares one in-flight future (`_postLoginInFlight`), so the deep-link listener, the OTP verify, and the poll timer can't resolve the session twice and race the router.")
    d.bullet("**Friendly errors** - `_friendlyAuthError()` translates Supabase's technical messages ('invalid login credentials') into human text ('Incorrect email or password').")
    d.bullet("**Sign-out token cleanup** - the FCM device token is deleted BEFORE `auth.signOut()`; after sign-out the request would run as anon and RLS would silently keep a stale row.")

    d.h1("7. Likely defense questions")
    d.kv([
        ("Who needs the whitelist?", "Only admins. Students/teachers self-register; the whitelist is the admin gate."),
        ("Why PKCE?", "Secure OAuth for mobile - no client secret in the app."),
        ("Why OTP not the email link?", "Email clients can pre-fetch links and consume the token; a typed 6-digit code is immune."),
        ("Where is the role stored?", "In the profiles row; the controller exposes it as `role`, and the router redirects on it."),
        ("Is the anon key a secret?", "No - the Supabase anon key is safe to ship; RLS enforces access. The service-role key lives only in an Edge Function."),
    ], c1="question", c2="answer", w1=48)

    d.save(_p("03_Authentication.pdf"))
    print("  + 03_Authentication.pdf")


# ============================================================
# 4. ROUTINE
# ============================================================
def build_routine():
    d = Doc("Routine (Timetable Viewer)",
            "How students and teachers see their weekly class schedule from "
            "one shared table.")
    d.cover(META + ["", "Owner: Robi (student/teacher features)",
                    "Key files: features/routine/*, core/models/routine_model.dart"])

    d.h1("1. What it does")
    d.p("The Routine screen shows a weekly class schedule with a day selector. The same "
        "screen + controller serves BOTH students and teachers - it is **role-aware**. "
        "Students see their cohort's classes; teachers see the classes they teach. Both "
        "read from one `routines` table.")
    d.kv([
        ("routine_service.dart", "The only Supabase layer. Two read paths over `routines`."),
        ("routine_controller.dart", "Role-aware state: loads the right rows, tracks selected day, exposes that day's entries."),
        ("routine_model.dart (RoutineEntry)", "Typed row + all the time/status helpers. Pure Dart, no Supabase."),
    ], c1="file", c2="job", w1=52)

    d.h1("2. Two read paths, one table")
    d.code("// student: filter by cohort\n"
           "fetchForStudent(batch, section)  ->  WHERE batch=.. AND section=.. AND is_active\n\n"
           "// teacher: filter by their code\n"
           "fetchForTeacher(teacherCode)     ->  WHERE teacher_code=.. AND is_active")
    d.p("Why no semester filter for students? A batch+section cohort is only ever in one "
        "semester at a time, so batch+section already uniquely identifies their routine. "
        "Filtering by semester too would only create mismatches if a profile's semester "
        "drifted out of sync with the seeded data.")

    d.h1("3. The controller's day logic")
    d.p("`load()` checks the logged-in profile: if teacher, fetch by teacher code; else "
        "fetch by batch+section. It defaults the selected day to today.")
    d.bullet("**7-day week** - the university teaches Sun-Sat. `DateTime.weekday` (Mon=1..Sun=7) is mapped to short day names via a constant table, so today is highlighted correctly.")
    d.bullet("**entriesForSelectedDay** - filters the loaded entries to the selected day's full name (e.g. 'Sunday').")
    d.bullet("**countForDay** - powers the little count badges on each day chip.")
    d.bullet("**setDay()** - changes the selected day and `notifyListeners()`; the screen rebuilds via ListenableBuilder.")

    d.h1("4. RoutineEntry - the model that does the time math")
    d.p("Each row carries day, start/end time (as 'HH:MM' text), subject, teacher "
        "(name + code as TEXT), room, batch, section, semester. The smart part is the "
        "helper methods:")
    d.kv([
        ("startOn(date) / endOn(date)", "Builds a real DateTime for this slot on a given calendar day - so we can compare against `now`."),
        ("timeLabel / startLabel", "Pretty 12-hour strings like '9:30 AM - 10:50 AM'."),
        ("teacherDisplay", "Name if present, else code, else 'TBA'."),
        ("statusOn(date, isToday)", "Returns live / next / done / upcoming for today's classes (delegates to AppDateUtils.getClassStatus)."),
    ], c1="method", c2="what it returns", w1=52)
    d.p("`getClassStatus(start,end)`: now after end -> **done**; now after start -> "
        "**live**; starts within 30 min -> **next**; otherwise **upcoming**. This same "
        "logic powers the dashboards, Find Teacher and Rooms.")

    d.h1("5. Likely defense questions")
    d.kv([
        ("How does one screen serve both roles?", "The controller reads the profile's role and picks fetchForTeacher vs fetchForStudent; the UI is identical."),
        ("Where does the data come from?", "The `routines` table - the same rows the timetable engine publishes."),
        ("Why store time as text?", "It matches the engine output and DB column; the model parses it into DateTime on demand for comparisons."),
        ("How is 'today' computed for 7 days?", "DateTime.weekday mapped through AppConstants.weekDays (Sun-Sat), the single source of truth shared with the engine."),
    ], c1="question", c2="answer", w1=52)

    d.save(_p("04_Routine.pdf"))
    print("  + 04_Routine.pdf")


# ============================================================
# 5. STUDENT DASHBOARD
# ============================================================
def build_dashboard():
    d = Doc("Student Dashboard (Home)",
            "The live home screen: greeting, the class happening now, a "
            "countdown to the next one, and today's list.")
    d.cover(META + ["", "Owner: Robi (student/teacher features)",
                    "Key files: features/dashboard/*"])

    d.h1("1. What it does")
    d.p("The student Home is a **read-only aggregation** of the routine - no new backend. "
        "It greets the student, shows a hero card for the class happening right now (or a "
        "countdown to the next class, or a 'done for today' message), a small stat strip, "
        "today's class list, quick actions, and a preview of recent alerts.")
    d.p("`StudentDashboardController` loads the cohort's routine once "
        "(`RoutineService.fetchForStudent`) and derives everything else in memory.")

    d.h1("2. The three hero states (the key UX)")
    d.flow([
        "**Live class?** `liveClass` scans today's classes for one whose status is `live` (now between start and end). If found -> show the LiveClassCard.",
        "**Otherwise, next class?** `nextClass` returns the first class today that hasn't started yet -> show NextClassCard with a countdown.",
        "**Otherwise** -> show MessageHeroCard ('You're done for today').",
    ], title="How the hero decides what to show")
    d.p("This mirrors how a student actually thinks: 'what's on now? what's next? am I "
        "done?' - which makes the home screen instantly useful.")

    d.h1("3. The derived values")
    d.kv([
        ("todaysClasses", "Today's entries (by weekday), sorted by start time."),
        ("liveClass", "The class running right now, if any."),
        ("nextClass", "The first not-yet-started class today."),
        ("remainingToday", "Count of classes today that haven't finished (live + upcoming)."),
        ("weeklyCount / todayCount", "Totals for the stat strip."),
    ], c1="getter", c2="meaning", w1=42)
    d.p("All of these are computed from the single loaded list against `DateTime.now()`. "
        "No extra queries, so the screen is fast and works offline once loaded.")

    d.h1("4. How it stays in sync")
    d.p("The controller extends `SafeChangeNotifier` (a ChangeNotifier that won't call "
        "`notifyListeners()` after dispose). The screen wraps content in a "
        "`ListenableBuilder` listening to both the dashboard controller and the shared "
        "NotificationController, so the recent-alerts preview updates live.")

    d.h1("5. Likely defense questions")
    d.kv([
        ("Does the dashboard hit a new table?", "No - it reuses RoutineService. It is pure derivation, zero new backend."),
        ("How is 'live' decided?", "RoutineEntry.statusOn(now) -> getClassStatus compares now against the slot's start/end."),
        ("Why ChangeNotifier?", "Built into Flutter, minimal boilerplate, perfect for our scale - the controller just calls notifyListeners() and the UI rebuilds."),
        ("What if there are no classes today?", "The hero gracefully shows the 'done for today' message card."),
    ], c1="question", c2="answer", w1=50)

    d.save(_p("05_Student_Dashboard.pdf"))
    print("  + 05_Student_Dashboard.pdf")


# ============================================================
# 6. TEACHER (dashboard + manage classes)
# ============================================================
def build_teacher():
    d = Doc("Teacher Features",
            "The teacher Home dashboard and Manage Classes - cancel a class, "
            "post a notice, and undo, with live student alerts.")
    d.cover(META + ["", "Owner: Robi (student/teacher features)",
                    "Key files: features/teacher/* (+ cancellations table, migration 007)"])

    d.h1("1. Two teacher screens")
    d.bullet("**Teacher Dashboard** - same idea as the student home, but built from `fetchForTeacher`: greeting, live/next class hero, today's classes, stats.")
    d.bullet("**Manage Classes** - the teacher's action centre: pick a day, tap a class, then Cancel it / Post an update / Undo. This is where teachers WRITE to the backend.")

    d.h1("2. Cancelling a class - the full flow")
    d.p("A cancellation targets ONE specific occurrence (a single date), not the whole "
        "weekly slot. `occurrenceDate(day)` computes the next calendar date (>= today) "
        "whose weekday matches the class's day.")
    d.flow([
        "Teacher taps a class -> chooses 'Cancel' -> types a reason.",
        "`TeacherService.cancelClass()` INSERTs a row into **cancellations** (routine_id + class_date + reason + cohort info + cancelled_by).",
        "In the SAME call it fires a broadcast: `createBroadcast(classCancel, target = that batch+section)`.",
        "Inserting that notification row triggers BOTH the in-app Realtime alert AND the OS push (via the send-push Edge Function).",
        "The teacher's own card badges the class as CANCELLED (the key is added to a local cancelled set).",
    ])
    d.p("So one tap = a durable cancellation record + an instant alert to exactly the "
        "affected students. The student grid badge isn't wired yet - students get the "
        "alert - but the data model supports it.")

    d.h1("3. Post a notice / Undo")
    d.bullet("**Post update** - `postNotice()` sends a room-change / notice / test-reminder broadcast to the class's cohort (no cancellation row, just a notification).")
    d.bullet("**Undo** - `undoCancel()` deletes the cancellation row (scoped to `cancelled_by = me` by RLS). The already-sent alert stays in students' history - you can't recall a sent message, and that's honest behaviour.")

    d.h1("4. The cancellations table (migration 007)")
    d.p("One dated row per cancelled occurrence: `routine_id, class_date, reason, batch, "
        "section, subject, day, time_start, cancelled_by`, with a UNIQUE constraint on "
        "`(routine_id, class_date)` so the same class can't be cancelled twice for the "
        "same date.")
    d.kv([
        ("Read", "Everyone (so teacher view + future student view can badge CANCELLED)."),
        ("Insert / Delete", "Only the teacher/admin who owns it (cancelled_by = auth.uid())."),
        ("Realtime", "Enabled, so changes can stream to clients."),
    ], c1="RLS rule", c2="who", w1=34)

    d.h1("5. Likely defense questions")
    d.kv([
        ("Does cancelling delete the routine row?", "No - the weekly routine is permanent. A cancellation is a separate dated exception row."),
        ("How do students find out instantly?", "The same insert that records the cancellation also inserts a notification -> Realtime + push fan out to the cohort."),
        ("Can a teacher cancel another's class?", "No - RLS ties insert/delete to cancelled_by = auth.uid() plus the teacher/admin role."),
        ("Why target batch+section?", "createBroadcast sets target_batch/target_section so only the affected cohort is alerted, not the whole campus."),
    ], c1="question", c2="answer", w1=50)

    d.save(_p("06_Teacher_Features.pdf"))
    print("  + 06_Teacher_Features.pdf")


# ============================================================
# 7. RESOURCES
# ============================================================
def build_resources():
    d = Doc("Resources Hub",
            "Semester folders of study materials - admin uploads files or "
            "Drive links, students browse and open them.")
    d.cover(META + ["", "Owner: Robi (student) + Fahmid (admin upload)",
                    "Key files: features/resources/*, features/admin/.../manage_resources_screen.dart"])

    d.h1("1. What it does")
    d.p("The Resources Hub is the department's shared file drawer. **Admins upload** any "
        "file (PDF/DOC/PPT/image/zip) or paste a Google Drive link, tagged to a semester "
        "and category. **Students browse** by semester folder -> category -> and tap to "
        "open. Files live in Supabase Storage; links open in the browser.")
    d.kv([
        ("resource_service.dart", "The only Supabase layer: fetch by semester, upload to the `resources` bucket, insert/delete rows."),
        ("resource_controller.dart", "Student-side state: loads resources, filters by semester + category."),
        ("resource_admin_controller.dart", "Admin-side: pick a file, upload, create the row, alert students."),
    ], c1="file", c2="job", w1=50)

    d.h1("2. Why resources filter by SEMESTER (not batch+section)")
    d.p("This is a deliberate contrast with routines. A 'Data Structures' note is useful "
        "to every student in that semester regardless of section, so resources key on "
        "**semester**. Routines key on batch+section because a schedule is cohort-specific. "
        "Good detail to mention - it shows you chose the data model per use-case.")

    d.h1("3. Upload flow (admin)")
    d.flow([
        "Admin picks a file (file_picker, with bytes) or enters a Drive URL + sets semester + category.",
        "`uploadFile(bytes, name, semester)` sanitises the filename, builds a path `<semester>/<timestamp>_<name>`, uploads to the public `resources` bucket, returns the public URL.",
        "`createResource()` inserts the row, stamping `uploaded_by` from the session (required by the RLS insert policy).",
        "A best-effort broadcast alerts students that new material was added.",
    ])
    d.p("Content-type is inferred from the extension so the browser opens the file "
        "correctly instead of downloading a blob.")

    d.h1("4. Browse flow (student)")
    d.bullet("`ResourceController` loads resources; the screen shows **semester folders** (all semesters - RLS lets students read every semester).")
    d.bullet("Tapping a folder lists items; a category chip row filters client-side for instant response (no re-query).")
    d.bullet("Tapping an item opens the URL via `url_launcher`, with a clipboard fallback if no browser can handle it.")

    d.h1("5. Likely defense questions")
    d.kv([
        ("Where are the files stored?", "Supabase Storage, the public `resources` bucket; the DB row stores the URL + metadata."),
        ("Why public bucket?", "MVP simplicity; access is read-only browse. Could be tightened with signed URLs later."),
        ("How are uploads restricted to staff?", "RLS insert policy requires uploaded_by = the caller and an admin/teacher role."),
        ("Do students get notified?", "Yes - upload fires a best-effort notification to students (in-app + push)."),
    ], c1="question", c2="answer", w1=48)

    d.save(_p("07_Resources.pdf"))
    print("  + 07_Resources.pdf")


# ============================================================
# 8. NOTIFICATIONS + PUSH
# ============================================================
def build_notifications():
    d = Doc("Notifications & Push",
            "One insert, two deliveries: a live in-app feed (Supabase Realtime) "
            "plus an OS push (Firebase FCM).")
    d.cover(META + ["", "Owner: Ratul (notifications, push, profile)",
                    "Key files: features/notifications/*, core/services/push_service.dart, "
                    "supabase/functions/send-push"])

    d.h1("1. The big idea (say this first)")
    d.p("In UniVerse, **inserting one row into the `notifications` table does everything**: "
        "it appears live in the in-app feed (Supabase Realtime) AND fires an OS push "
        "notification (Firebase FCM) to the right audience. There is exactly one path - "
        "no feature sends push directly.")
    d.flow([
        "A source inserts a `notifications` row (admin broadcast, teacher cancel/notice, resource upload, routine publish).",
        "**In-app:** every signed-in device has a Realtime subscription on the table -> the new row streams in and the feed + unread badge update instantly.",
        "**Push:** a Supabase DB Webhook on INSERT invokes the `send-push` Edge Function -> it resolves the row's audience, looks up `device_tokens`, and sends via FCM HTTP v1.",
    ])

    d.h1("2. Audience targeting")
    d.p("A notification row has `target_role`, `target_batch`, `target_section`. NULLs mean "
        "'everyone'. The client's `matchesAudience()` filters the feed to what applies to "
        "this user, and the Edge Function uses the same fields to pick which device tokens "
        "to push to. Examples:")
    d.kv([
        ("target_role=null", "Broadcast to the whole campus (e.g. 'routine published')."),
        ("role=student, batch+section set", "Only that cohort (a teacher cancelling their class)."),
        ("role=student", "All students (a new resource uploaded)."),
    ], c1="targets", c2="audience", w1=52)

    d.h1("3. In-app feed details (notification_controller)")
    d.bullet("**Read-state** - a separate `notification_reads` table tracks per-user read marks; the service merges it so each user has their own read/unread state on shared broadcast rows.")
    d.bullet("**Unread badge** - `unreadCount` drives the Alerts tab badge in the bottom nav. The controller is app-scoped (one subscription for the whole session).")
    d.bullet("**Optimistic mark-read** - tapping marks read in the UI immediately, then writes to the DB, rolling back if it fails.")
    d.bullet("**Per-user dismiss** - users can multi-select and hide alerts; dismissed ids are stored locally in SharedPreferences (`dismissed_notifs_<uid>`). The shared DB rows are never deleted - dismissal is local only.")

    d.h1("4. Push details (push_service.dart)")
    d.p("`PushService` is the only layer touching firebase_messaging + "
        "flutter_local_notifications. Why it exists: Realtime can update an OPEN app, but "
        "it can't wake a backgrounded or killed app - FCM can.")
    d.kv([
        ("init()", "Sets up a high-importance Android channel, asks permission, registers handlers."),
        ("registerToken(userId)", "On sign-in, saves the device's FCM token to `device_tokens` (via a SECURITY DEFINER RPC that clears any stale row first)."),
        ("foreground messages", "Android doesn't auto-show pushes while the app is open, so we draw a local heads-up banner ourselves."),
        ("onNotificationTap", "Tapping a push routes to the notifications feed."),
        ("unregisterToken()", "On sign-out, deletes the token BEFORE the session drops (else RLS blocks it)."),
    ], c1="member", c2="role", w1=44)
    d.p("The channel id `universe_high_importance` MUST match AndroidManifest's "
        "`default_notification_channel_id` or background pushes are silent.")

    d.h1("5. The send-push Edge Function (deployed)")
    d.p("A Deno/TypeScript function on Supabase, triggered by the DB Webhook on "
        "`notifications` INSERT. It resolves the audience -> queries `device_tokens` -> "
        "sends via **FCM HTTP v1**, minting a service-account JWT in-function (secret "
        "`FCM_SERVICE_ACCOUNT`). The FCM service key lives ONLY here, never in the app.")

    d.h1("6. Likely defense questions")
    d.kv([
        ("Realtime vs FCM - why both?", "Realtime updates an open app instantly; FCM delivers to backgrounded/killed apps. Together = always delivered."),
        ("How does a DB insert send a push?", "A Supabase DB Webhook on INSERT invokes the send-push Edge Function automatically."),
        ("Where is the FCM secret?", "Only inside the Edge Function (FCM_SERVICE_ACCOUNT secret) - never shipped in the APK."),
        ("Do dismissed alerts delete data?", "No - dismissal is per-user and local (SharedPreferences). Shared broadcast rows are untouched."),
    ], c1="question", c2="answer", w1=50)

    d.save(_p("08_Notifications_and_Push.pdf"))
    print("  + 08_Notifications_and_Push.pdf")


# ============================================================
# 9. PROFILE
# ============================================================
def build_profile():
    d = Doc("Profile",
            "Viewing and editing the user's own account details.")
    d.cover(META + ["", "Owner: Ratul (notifications, profile)",
                    "Key files: features/profile/*"])

    d.h1("1. What it does")
    d.p("The Profile screen shows the logged-in user's details (name, role badge, "
        "academic/teaching info, avatar) and lets them edit allowed fields and sign out. "
        "It is a thin, focused feature - the textbook example of our layering.")
    d.kv([
        ("profile_service.dart", "The only Supabase layer: fetchProfile(id) and updateProfile(id, changes). Returns the typed Profile model."),
        ("profile_controller.dart", "Holds the Profile, loading/saving state; calls the service and notifies the screen."),
        ("profile_screen.dart", "Pure UI: reads the controller, renders sections, triggers edit + sign-out."),
    ], c1="file", c2="job", w1=44)

    d.h1("2. The Profile model")
    d.p("`Profile.fromMap()` turns a `profiles` row into a typed object with helpers like "
        "`isTeacher`, `isStudent`, plus role-specific fields (batch/section/student_id for "
        "students; teacher_code/department/designation for teachers). The whole app reads "
        "the current user through this model - the AuthController exposes the raw map and "
        "features wrap it in `Profile.fromMap()`.")

    d.h1("3. Update flow")
    d.flow([
        "User edits a field and saves.",
        "`updateProfile(userId, changes)` runs an UPDATE on `profiles` WHERE id = the user, returning the fresh row.",
        "RLS ensures a user can only update their OWN row.",
        "The returned row is re-wrapped as a Profile and the screen rebuilds.",
    ])

    d.h1("4. Likely defense questions")
    d.kv([
        ("Can a user edit someone else's profile?", "No - RLS scopes updates to id = auth.uid(); the query also filters by the user's id."),
        ("Where does the role come from?", "The profiles.role column, set at registration (or from the whitelist for admins)."),
        ("Is this the same profile auth uses?", "Yes - one profiles row per user, created at first login, read everywhere via Profile.fromMap()."),
    ], c1="question", c2="answer", w1=50)

    d.save(_p("09_Profile.pdf"))
    print("  + 09_Profile.pdf")


# ============================================================
# 10. ADMIN + TIMETABLE ENGINE
# ============================================================
def build_admin_engine():
    d = Doc("Admin & Timetable Engine",
            "The admin control centre and the project's differentiator: an "
            "automatic, clash-free timetable generator (OR-Tools CP-SAT).")
    d.cover(META + ["", "Owner: Fahmid (admin + engine)",
                    "Key files: features/admin/*, engine/*.py"])

    d.h1("1. The admin side")
    d.p("Admins get a dashboard plus management hubs. Each is a screen -> controller -> "
        "service slice over Supabase with admin-only RLS.")
    d.kv([
        ("Routine hub", "Segmented control: Manage (CRUD on routines) + Generate (the engine)."),
        ("Campus Broadcast", "Compose a notification to a chosen audience (+ Broadcast History)."),
        ("Manage Users", "View/manage profiles; admin provisioning via the invite-admin Edge Function."),
        ("Manage Resources", "Upload files / links (+ Resource Library to delete)."),
        ("Timetable config", "Manage Rooms, Manage Faculty, Timetable Settings - the engine's inputs."),
    ], c1="screen", c2="purpose", w1=42)

    d.h1("2. The differentiator - why it matters")
    d.p("Building a clash-free routine for ~55 cohorts, ~76 teachers and limited rooms is "
        "normally days of manual work. UniVerse does it in seconds with a constraint "
        "solver, guarantees no teacher/room/cohort double-booking, and publishes to every "
        "student and teacher with one tap. This is the advisor-required feature and the "
        "centrepiece of the defense.")

    d.h1("3. The pipeline (Excel in -> workbook out)")
    d.flow([
        "Admin picks the Main Distribution .xlsx; the app loads engine config from the DB.",
        "**ingest.py** parses the 'Course Distribution' sheet: binds columns by header text, applies the even-digit lab rule, excludes blank-teacher/blank-batch rows, detects service/non-CSE offerings, validates invariants.",
        "**solver.py Phase 1 (CP-SAT):** assign each session a (day, period). HARD constraints: each session once; no teacher/cohort/room double-book; teacher day-offs; Friday no period-4; rooms <= pool. SOFT: spread a course's 2 sessions across different days, cohort compactness, avoid the last period.",
        "**solver.py Phase 2 (greedy room assign):** labs -> lab rooms, theory -> theory/galleries. Then it self-validates.",
        "**render.py** clones the Excel template and writes one canonical 55-row cohort map to all 7 day-sheets, cells as 'CODE TEACHER ROOM'.",
        "App polls status -> shows report + validation + grid -> Download .xlsx or Publish.",
    ])
    d.p("CP-SAT (Constraint Programming - SATisfiability) from Google OR-Tools explores the "
        "assignment space far faster than brute force and returns a provably clash-free "
        "solution (or reports infeasibility).")

    d.h1("4. The HTTP contract (FastAPI engine)")
    d.kv([
        ("POST /generate", "multipart {file, config(JSON), time_limit_s} -> {job_id}. Runs on a background thread."),
        ("GET /status/{id}", "{state, progress, [stats, validation, error]}. state: queued->ingesting->solving->rendering->done|failed."),
        ("GET /result/{id}", "{rows, stats, validation, report}."),
        ("GET /download/{id}", "the rendered .xlsx."),
    ], c1="endpoint", c2="contract", w1=42)
    d.p("The engine is **stateless** - jobs live in an in-memory dict, no DB on the engine "
        "side. Deployed on Render free tier; it sleeps after ~15 min so the first request "
        "is a ~50s cold start (pre-warm before a demo).")

    d.h1("5. Config flow (DB-backed) - keep three in sync")
    d.p("Admin edits Manage Rooms / Faculty / Settings -> `TimetableConfigService` CRUDs "
        "the `timetable_*` tables -> `buildEngineConfig()` assembles "
        "{rooms[], teachers[], settings{periods, friday_no_p4, service_scope, weights, "
        "semester_label}} -> sent with the generate request -> the engine's "
        "`_normalize_config()` consumes it. **If you rename a column, all three must "
        "move together** - a key project guardrail.")

    d.h1("6. Generate + publish (timetable_gen_controller)")
    d.flow([
        "`generate()` builds config, uploads the file, then polls every 2s (up to ~4 min) until the job is done.",
        "On done it fetches the result (rows + stats + validation + report) for the preview grid.",
        "`downloadAndOpen()` fetches the .xlsx, opens it, and archives it to the `timetables` bucket.",
        "`publish()` writes rows into `routines` (idempotent: clears each generated batch first), records the run in `timetable_runs`, then fires a campus-wide 'routine published' notification (in-app + push).",
    ])
    d.p("Critical guardrail: the engine emits rows shaped EXACTLY like the `routines` "
        "columns (RoutineEntry.toMap()), so publishing is a direct insert. Change one "
        "side and publish silently breaks.")

    d.h1("7. Likely defense questions")
    d.kv([
        ("Why CP-SAT / OR-Tools?", "Timetabling is a constraint-satisfaction problem; CP-SAT finds a provably clash-free schedule far faster than brute force."),
        ("Hard vs soft constraints?", "Hard = must hold (no double-booking, day-offs); soft = preferences the solver optimises (spread sessions, compactness)."),
        ("What proves it's clash-free?", "The solver self-validates (validation.ok) and the HARD constraints make double-booking impossible by construction."),
        ("Where does it run?", "A separate FastAPI service on Render; the app talks to it over HTTPS and polls the job."),
        ("Real numbers?", "Summer 2025: 358 offerings -> 654 CSE + 32 service sessions, 55 cohorts, 76 teachers, solved clash-free."),
    ], c1="question", c2="answer", w1=46)

    d.save(_p("10_Admin_and_Timetable_Engine.pdf"))
    print("  + 10_Admin_and_Timetable_Engine.pdf")


# ============================================================
# 11. FIND TEACHER
# ============================================================
def build_find_teacher():
    d = Doc("Find Teacher",
            "Real-time teacher locator: which room a teacher is in now, time "
            "left, and their next class.")
    d.cover(META + ["", "Owner: Robi (campus explore)",
                    "Key files: features/find_teacher/*"])

    d.h1("1. What it does")
    d.p("Find Teacher answers 'where is this teacher right now?'. You search by name or "
        "code and get a card showing their status (In Class / Free / No Class Today), the "
        "current room + minutes remaining, and their next class. It is reached from the "
        "**Explore** FAB on every dashboard. No new tables - it derives everything from "
        "the live `routines` schedule vs the current time.")

    d.h1("2. How status is derived")
    d.flow([
        "`fetchAllRoutines()` loads all active routine rows.",
        "Build a unique teacher list from the rows (code -> name).",
        "For each teacher, take today's classes sorted by time.",
        "If `now` is between a class's start and end -> **In Class** (show room, cohort, minutes left = end - now).",
        "Else if a later class exists today -> **Free** now, show the next class.",
        "Else -> **No Class Today** (or Free, last class ended).",
    ])
    d.p("`_buildTeacherInfo()` packages this into a `TeacherInfo` object the card renders. "
        "Search filters the in-memory list by name or code - instant, no re-query.")

    d.h1("3. Real-time")
    d.p("`streamAllRoutines()` is a Supabase Realtime stream on the `routines` table; when "
        "the schedule changes the controller rebuilds the teacher list, so locations stay "
        "current without a manual refresh.")

    d.h1("4. Likely defense questions")
    d.kv([
        ("Is there GPS / live tracking?", "No - it's schedule-derived: where the timetable says they should be, compared to the clock. Privacy-friendly and needs no hardware."),
        ("Any new backend?", "None - it reads the same `routines` table the routine viewer uses."),
        ("How is it real-time?", "A Supabase Realtime subscription on routines; changes re-derive the list."),
        ("What about cancellations?", "The feature set reads routines (+ cancellations in the design) to reflect live state; a cancelled class shouldn't show as 'in class'."),
    ], c1="question", c2="answer", w1=50)

    d.save(_p("11_Find_Teacher.pdf"))
    print("  + 11_Find_Teacher.pdf")


# ============================================================
# 12. ROOMS
# ============================================================
def build_rooms():
    d = Doc("Room Availability",
            "Real-time room occupancy: which rooms are busy, who's in them, "
            "and when each frees up.")
    d.cover(META + ["", "Owner: Robi (campus explore)",
                    "Key files: features/rooms/*"])

    d.h1("1. What it does")
    d.p("Room Availability shows every room with an OCCUPIED / AVAILABLE chip, the current "
        "class (teacher, subject, cohort) with minutes remaining, and the next scheduled "
        "class. Like Find Teacher, it's reached from the Explore FAB and derives state "
        "from the live `routines` table - no new tables.")

    d.h1("2. How occupancy is derived (rooms_controller)")
    d.flow([
        "`fetchAllRoutines()` loads all active routine rows.",
        "Group rows by room.",
        "For each room, take today's classes sorted by time.",
        "If `now` is inside a class window -> **OCCUPIED**: show teacher, subject, cohort, and minutes remaining (end - now).",
        "Else -> **AVAILABLE**: show the next class today (or 'No more classes').",
        "Sort rooms by name for a stable list.",
    ])
    d.p("This is the exact mirror of Find Teacher - same data, grouped by room instead of "
        "by teacher. Both reuse RoutineEntry's startOn/endOn time helpers.")

    d.h1("3. Real-time")
    d.p("`streamAllRoutines()` (Supabase Realtime) feeds the controller; when the schedule "
        "changes, occupancy recomputes automatically.")

    d.h1("4. Likely defense questions")
    d.kv([
        ("How do you know a room is free?", "If no class in the timetable covers the current time for that room, it's available; we also show when the next class starts."),
        ("Sensors / IoT?", "None - it's schedule-based occupancy from the published routine."),
        ("Shared logic with Find Teacher?", "Yes - same routines data and time helpers; one groups by teacher, the other by room."),
        ("Does it cover all rooms?", "Every room that appears in the routine; the room pool itself is managed in Manage Rooms for the engine."),
    ], c1="question", c2="answer", w1=50)

    d.save(_p("12_Room_Availability.pdf"))
    print("  + 12_Room_Availability.pdf")


BUILDERS = [
    build_index,
    build_routing,
    build_theming,
    build_auth,
    build_routine,
    build_dashboard,
    build_teacher,
    build_resources,
    build_notifications,
    build_profile,
    build_admin_engine,
    build_find_teacher,
    build_rooms,
]


def main():
    print("Generating defense PDFs ->", OUT)
    for b in BUILDERS:
        b()
    print("Done.")


if __name__ == "__main__":
    main()
