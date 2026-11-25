# UniVerse — Polish Phase Handoff
> Give this file to a new Claude Code session to continue the defense-polish work
> with zero ramp-up. The repo's **`CLAUDE.md`** (auto-loaded) has full project
> context + hard guardrails — read it first. This doc covers ONLY the polish task:
> what was decided, the working process, and per-item implementation notes.
> Context: feature-complete app, **~2 days to defense**, polishing for the demo.

---

## 0. TL;DR for the new session
1. The app is DONE and runs end-to-end. The timetable engine is **deployed & live**.
   We are polishing UI/UX only — **do not touch backend / DB / engine / deployment.**
2. **FIRST ACTION when the user says "go": create a branch** —
   `git checkout -b polish/defense-prep` off `main`. Never work polish on `main`.
3. **The agent must NOT run git push / commit-to-remote.** The user does all
   pushing/merging manually. You may create the branch and (optionally) make local
   commits if asked, but never push.
4. Implement in the order in §3. Run `flutter analyze` after each chunk; keep it clean.
5. Follow every rule in `CLAUDE.md` → "⚠️ READ FIRST — GUARDRAILS" (design tokens,
   layering, ChangeNotifier, RouteNames, phosphor icons, no Supabase in screens, etc.).

---

## 1. Verified current state (facts, don't re-derive)
- **Engine live:** `https://universe-timetable-engine.onrender.com` (Render free, deploys
  from `main` via root `render.yaml`). Verified end-to-end: health, upload+generate
  (0 clashes, `validation.ok=true`), download `.xlsx`. Free tier sleeps ~15 min →
  ~50 s cold start.
- **APK built:** `build/app/outputs/flutter-apk/app-release.apk` (debug-signed release,
  ~73 MB), engine URL baked into `app_constants.timetableBaseUrl` default.
- **Branches:** `feature/timetable-engine` was merged into `main` (conflicts resolved by
  keeping BOTH features). Push-notifications/Firebase already on `main`.
- **AI assistant DESCOPED:** student "AI" bottom-nav tab + `/student/ai-assistant` route
  removed. Kept for future restore: `RouteNames.aiAssistant`, `shared/widgets/chat_bubble.dart`,
  `documents` table. (See CLAUDE.md → AI ASSISTANT.)
- **Build env:** Gradle wrapper **8.14** (dev machine has JDK 24 — do NOT downgrade).
- `flutter analyze` is currently **clean** across the project.

### ⚠️ Possibly-uncommitted working-tree changes
The CLAUDE.md rewrite + the AI-descope edits (`lib/shared/widgets/app_bottom_nav.dart`,
`lib/core/router/app_router.dart`) may still be **uncommitted** on `main`. They will
follow you onto the new branch when you `git checkout -b` (that's fine). Recommended:
user commits them first, then branches. Suggested command (USER runs):
```bash
git add CLAUDE.md lib/shared/widgets/app_bottom_nav.dart lib/core/router/app_router.dart
git commit -m "docs(claude): refresh + guardrails; chore(nav): descope AI assistant"
git push origin main
```

---

## 2. Decisions already made (do NOT re-ask)
- **Dashboards:** Build **robust, fully-finished, defense-grade** Student + Teacher
  dashboards and a complete Manage Classes screen — they must look and feel like polished,
  production features, NOT stubs. **Robi (the normal owner) is unavailable**, so these must
  be self-sufficient and complete on their own. Reuse existing services/widgets (no new
  backend tables; you may add read methods to existing services). The lead (Fahmid)
  approved building these. When merged, give Robi a heads-up to avoid collisions.
- **Scope:** **Everything — P0 + P1 + P2** (full list in §3). Dashboards (P0) get the most
  effort and polish.
- **Workflow:** plan → branch on "go" → implement in order → user reviews & merges & rebuilds APK.

---

## 3. The polish plan (implement in this order)

### P0 — demo-blockers: build 3 FULL, robust screens (highest effort)
Currently these route to `PlaceholderScreen` ("under construction") in
`lib/core/router/app_router.dart` (inside the `ShellRoute`). Replace each builder with a
**complete, polished, defense-grade screen** — they must read as finished products.
**Benchmark for quality/structure: the existing `admin_dashboard_screen.dart` and
`routine_screen.dart`** — match their polish (sectioned layout, real data, loading + empty
+ error + pull-to-refresh, design tokens, phosphor icons). Every new screen follows
screen → controller → service. Reuse widgets; do NOT touch Supabase outside services.

**Tab-screen pattern (check `app_shell.dart` first):** each tab screen returns its OWN
`Scaffold` with a `UAppBar(showBackButton:false)`; `AppShell` supplies the bottom nav.
Mirror `routine_screen.dart`. Add NO new routes — just swap the builders for these three
existing route names inside the `ShellRoute`.

**Reusable building blocks (already in `lib/shared/widgets/`):** `live_class_card`
(hero w/ countdown), `class_card` (status: live/next/done/upcoming), `stat_card`,
`quick_action_card`, `u_section_header` (title + "See all"), `notification_tile`,
`u_card`, `u_empty_state`, `u_loading`, `u_avatar`, `day_selector`, `info_row`.
Status/time helpers: `RoutineEntry.statusOn(...)` + `AppDateUtils` (and check
`core/utils/extensions.dart` / `date_utils.dart` for a time-of-day greeting helper).

1. **Student Dashboard** — `RouteNames.studentDashboard` (student Home; HIGH effort)
   - New feature: `lib/features/dashboard/` (`screens/student_dashboard_screen.dart` +
     `controllers/student_dashboard_controller.dart`). Controller aggregates from
     `RoutineService.fetchForStudent(batch, section)` (+ the shared `NotificationController`
     unread count if easy). Get `batch`/`section`/name/avatar from `Profile`
     (`auth_controller.profile` → `Profile.fromMap`; read `profile_model.dart` for fields).
   - Layout (top→bottom):
     1. **Greeting header** — time-aware ("Good morning, {firstName}"), `UAvatar`→Profile,
        subtitle "Batch {batch} · Section {section}" + today's date.
     2. **Hero** — `LiveClassCard` for the current LIVE class, else the NEXT upcoming class
        today with live countdown; if none left today → a friendly "You're done for today"
        card (not an empty void).
     3. **Quick stats strip** (`stat_card` ×3–4) — Classes Today · Next Class (time) ·
        Unread Alerts · (optional) This Week's count. Real values, graceful 0/— fallbacks.
     4. **"Today" section** (`u_section_header` "Today" + See all → Routine) — list of
        `class_card` for today's classes with live/next/done/upcoming status. `UEmptyState`
        if none.
     5. **Quick actions** (`quick_action_card` 2×2) — My Routine · Resources · Alerts · Profile.
     6. (Optional but nice) **Recent alerts** preview — header + 2–3 `notification_tile` +
        See all → Notifications.
   - Wrap in `RefreshIndicator` (color `AppColors.primary`); `ULoading.spinner()` while
     loading; handle the error path with a retry.
2. **Teacher Dashboard** — `RouteNames.teacherDashboard` (teacher Home; HIGH effort)
   - `lib/features/teacher/screens/teacher_dashboard_screen.dart` +
     `controllers/teacher_dashboard_controller.dart`. Data:
     `RoutineService.fetchForTeacher(teacherCode)` (teacherCode from `Profile`).
   - Same structure as the student dashboard, teacher-framed:
     greeting → **next class I teach** hero → stats (Classes Today · Weekly Classes ·
     Sections Taught · Unread Alerts) → **"Today's Teaching"** list (`class_card`) →
     quick actions (My Routine · Manage Classes · Alerts · Profile) → optional recent.
   - Loading/empty/error/refresh — full parity with the student one.
3. **Manage Classes** — `RouteNames.manageClasses` (teacher Classes tab; FULL feature)
   - `lib/features/teacher/screens/manage_classes_screen.dart` + controller, and a
     **`teacher_service.dart`** (or extend `RoutineService`) for the writes. First READ:
     the `cancellations` table columns, `NotificationService` create method signature, and
     the `notifications.type` CHECK / `NotifType` enum (`core/constants/app_enums.dart`).
   - Layout: a `DaySelector` (or grouped-by-day list) over the teacher's full weekly
     classes; each `class_card` shows subject/code/time/room/section and a **"Cancelled"**
     badge when a cancellation exists for that occurrence.
   - **Per-class actions** (bottom sheet):
     - **Cancel class** → insert a `cancellations` row (class identity + date + reason) AND
       post a `class_cancel` notification targeting that batch+section (so students get the
       Realtime alert). Show a confirm + success snackbar.
     - **Post notice / room change** → create a notification (`room_change` /
       `test_reminder` / `university` per `NotifType`) targeting the cohort, with a short
       composer (title + body).
     - **Undo cancel** → delete the `cancellations` row (if feasible) and refresh.
   - Sections: "Today" first, then the rest of the week; a small "Recent notices/cancellations"
     summary is a nice touch. Full loading/empty/error/refresh states.

> Make these three look **complete** — proper section headers, spacing, icons, colors,
> real data, and friendly (not blank) empty states. They are the parts a fresh installer
> sees first, and Robi won't be polishing them. Run `flutter analyze` after each.

### P1 — visible polish
4. **Profile** (`lib/features/profile/screens/profile_screen.dart` ~line 86): some settings
   tiles fire a `"… — coming soon"` snackbar. **Hide/remove** the non-functional tiles so
   nothing looks half-built (keep Sign Out + real info rows).
5. **Generate Timetable UX** (`lib/features/admin/screens/generate_timetable_screen.dart`):
   during the solve the progress bar parks at ~0.57 (engine reports coarse progress).
   Add a clearer "Solving… this can take up to ~60s" state and a one-line **cold-start
   hint** ("first run may take ~50s while the server wakes") so it never looks frozen.
6. **Empty-data states sweep**: confirm friendly empty messages for no-routine /
   no-notifications / no-resources / teacher with no classes. Fill any gaps with `UEmptyState`.

### P2 — finishing touches
7. **`debugLogDiagnostics: true` → `false`** in `lib/core/router/app_router.dart` (release noise).
8. **App icon**: likely the default Flutter icon (no `flutter_launcher_icons` in
   `pubspec.yaml`). If the user provides a logo PNG, wire `flutter_launcher_icons`
   (dev_dependency + config + run). **Needs an asset from the user — ask for it.**
9. **Refresh + error consistency**: ensure list screens have pull-to-refresh
   (`RefreshIndicator`, color `AppColors.primary`) and consistent error toasts.

---

## 4. Working process (strict)
```
# Step 0 — ALWAYS first, on user's "go":
git checkout -b polish/defense-prep        # off main

# Implement P0 → P1 → P2 in order. After each screen/chunk:
flutter analyze                            # must stay clean

# When done, the USER (not the agent) reviews + merges + rebuilds:
#   git checkout main && git merge polish/defense-prep && git push origin main
#   flutter build apk --release
```
- Agent: **no `git push`, no remote ops.** Local branch + edits only.
- Verify a screen compiles/looks right before moving on. Don't batch everything blind.
- If a change would touch the engine/DB/config tables/deployment → STOP, it's out of scope.

---

## 5. Build / run / verify commands
- Analyze: `flutter analyze`
- Release APK: `flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk`
- Run against **local** engine (emulator): start engine
  (`cd engine && uvicorn main:app --host 0.0.0.0 --port 8000`, or its venv python), then
  `flutter run --dart-define=TIMETABLE_BASE_URL=http://10.0.2.2:8000`
- Run against **live** engine: plain `flutter run` (default URL is the Render one).

---

## 6. Key references in the repo (read these, don't guess)
- `CLAUDE.md` — full project context + guardrails (top section).
- Models: `lib/core/models/profile_model.dart`, `routine_model.dart`.
- Services to reuse: `lib/features/routine/services/routine_service.dart`
  (`fetchForStudent`, `fetchForTeacher`), `lib/features/notifications/services/notification_service.dart`.
- Widgets to reuse: `lib/shared/widgets/` — `live_class_card`, `class_card`,
  `quick_action_card`, `stat_card`, `u_empty_state`, `u_loading`, `u_app_bar`, `u_card`,
  `day_selector`, `settings_tile`.
- Nav: `lib/core/router/app_shell.dart`, `app_router.dart`, `shared/widgets/app_bottom_nav.dart`.
- Admin dashboard is a good reference pattern for the new dashboards:
  `lib/features/admin/screens/admin_dashboard_screen.dart` (+ its controller).

---

## 7. Guardrails recap (full list in CLAUDE.md)
- Design tokens only (`AppColors/AppTextStyles/AppSpacing`); phosphor icons; Inter font global.
- Screen→controller→service; `ChangeNotifier`+`ListenableBuilder`; `RouteNames.*`.
- Don't change: engine, DB schema/RLS, `timetable_*` config tables, Supabase/Firebase wiring,
  `render.yaml`, deployment, `TIMETABLE_BASE_URL` default, Gradle version.
- Don't commit secrets / PII workbooks (`engine/routine generation files/`) / `dart_defines.json`.
- Don't re-add AI assistant (descoped).
- Agent never pushes; user handles all git remote ops + final APK rebuild.

---

## 8. Quick facts
| Thing | Value |
|---|---|
| Engine URL | `https://universe-timetable-engine.onrender.com` |
| Supabase project ref | `yxqyrjyzxitrgkhgauli` |
| Release/integration branch | `main` |
| Polish branch (to create) | `polish/defense-prep` |
| APK path | `build/app/outputs/flutter-apk/app-release.apk` |
| Engine env (Render) | `PYTHON_VERSION=3.12.7`, `SOLVER_WORKERS=2` |
| Gradle wrapper | 8.14 (JDK 24 — don't downgrade) |

*(You can delete this file after the polish phase; it's a handoff aid, not project docs.)*
