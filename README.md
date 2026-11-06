<div align="center">
<img src="assets/icon/app_icon.png" width="96" alt="UniVerse app icon" />

# UniVerse — A Campus Companion

A Flutter campus application for students, teachers, and administrators, with a Python OR-Tools CP-SAT timetable generator.
</div>

**Authoritative Roadmap & Active Checkpoint:** [`docs/implementation/UniVerse_Implementation_Master_Plan_v1_1.md`](docs/implementation/UniVerse_Implementation_Master_Plan_v1_1.md)
**Engineering Rules:** [`AGENTS.md`](AGENTS.md) (Codex / Antigravity) & [`CLAUDE.md`](CLAUDE.md) (Claude)

## Current Implementation Status

- **Phase 1 — Browser Admin Foundation:** Implemented and remediated on `feature/admin-web-extension` (`AdminDesktopShell`, responsive admin screens, web XLSX/JSON downloads, browser auth callback routing). See [`docs/implementation/20-browser-admin-foundation.md`](docs/implementation/20-browser-admin-foundation.md) and [`docs/implementation/21-browser-admin-independent-review.md`](docs/implementation/21-browser-admin-independent-review.md).
- **Phase 2a — Course Distribution Data Contract (Active):** Immutable source workbook storage and SHA-256 identity, formula/cached-value provenance (`J` and `L`), optimistic concurrency revisions, derived-artifact invalidation, and capability-checked correction RPCs in [`engine/distribution.py`](engine/distribution.py) (implemented & Python-verified) and [`supabase/migrations/20261106130000_course_distribution_contract.sql`](supabase/migrations/20261106130000_course_distribution_contract.sql) (implemented & SQL-reviewed; pending database execution/verification).
- **Upcoming Phases:** Editable Course Distribution & configuration workspace (**Phase 2b**, gated on explicit user UI/UX approval), shared server-authoritative validation & safe publication (**Phase 3**), committee scheduling requirements `R1`–`R16` in CP-SAT (**Phase 4**), complete committee workbench (**Phase 5**), and multi-department expansion (**Phase 6**).

## Implemented Application Capabilities

- Student and teacher dashboards and weekly routines, selected by batch/section or teacher code.
- Academic resources organized by semester and category, with uploaded files and links.
- Notification feed, read receipts, and local dismissal preferences.
- Teacher cancellation of dated class occurrences, notices, and cancellation undo.
- Admin user/whitelist management, broadcasts, resources, rooms, faculty, course eligibility, and scheduling settings.
- Browser-compatible admin shell (`AdminDesktopShell` on desktop/tablet web, `AppShell` on mobile) and routine hub with manual management, distribution generation, and rendered-workbook upload.
- Room and teacher status lookup derived from scheduled classes.
- Firebase Cloud Messaging client integration and local notification display.

## Timetable Engine Overview

```text
Distribution .xlsx (immutable source + accepted revision) + configuration
  → distribution.py / ingest.py: validate formula/cached provenance, group offerings & sessions
  → solver.py: CP-SAT day/period placement + concrete room assignment
  → validation: reconcile normalized requirements and scheduling checks
  → render.py: generate a workbook using the CSE template
  → Flutter: report, grid, download, and publication
```

See [`engine/README.md`](engine/README.md) for the current engine API, normalization pipeline, and constraint details, and [`docs/timetable-audit-2026-10-20/18-committee-decisions-and-policy-baseline-2026-11-04.md`](docs/timetable-audit-2026-10-20/18-committee-decisions-and-policy-baseline-2026-11-04.md) + [`16-committee-traceability-2026-11-04.md`](docs/timetable-audit-2026-10-20/16-committee-traceability-2026-11-04.md) for the approved committee scheduling baseline.

## Stack and Layout

| Layer | Implementation |
|---|---|
| App | Flutter/Dart (`>=3.0.0 <4.0.0`) |
| State & Routing | `ChangeNotifier`, `ListenableBuilder`, `SafeChangeNotifier`; `GoRouter` |
| Backend | Supabase Auth, PostgreSQL/RLS, Storage, and selected Realtime streams |
| Sign-In | Native Google ID-token exchange off-web; browser OAuth on web; email/password |
| Permissions | Student/teacher/admin (`016` whitelist gate) + scoped department capabilities (`academic_private.can_scope`) |
| Messaging | Firebase Core/Cloud Messaging and `flutter_local_notifications` |
| Scheduling | FastAPI, OR-Tools CP-SAT, `openpyxl` |
| UI | Inter typography, dark theme tokens, Material icon shim exposing Phosphor names |

See [`PROJECT_STRUCTURE.md`](PROJECT_STRUCTURE.md) for the full repository layout.

## Local Setup

### Flutter App (Android & Web)

From repository root in PowerShell:

```powershell
flutter pub get
Copy-Item dart_defines.example.json dart_defines.json
flutter run --dart-define-from-file=dart_defines.json
flutter build web --release --dart-define-from-file=dart_defines.json
flutter build apk --release --dart-define-from-file=dart_defines.json
```

Fill `dart_defines.json` (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `TIMETABLE_BASE_URL`, `GOOGLE_WEB_CLIENT_ID`). Never place privileged server credentials in Dart defines. Native auth callbacks use `com.example.universe://login-callback/` and `com.example.universe://reset-callback/`. (iOS is currently out of scope.)

### Python Timetable Engine

```powershell
Set-Location engine
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements-dev.txt
.\.venv\Scripts\python.exe -m uvicorn main:app --reload --port 8000
```

For Android emulator development, use `TIMETABLE_BASE_URL=http://10.0.2.2:8000`.

### Supabase Backend

See [`docs/backend-setup.md`](docs/backend-setup.md) for schema baseline, migrations, and verification rules. **Note:** Do not install or use Supabase CLI; database inspection and verification use the connected Supabase plugin or SQL queries executed in **Supabase Dashboard → SQL Editor**.

## Verification

From repository root:
```powershell
flutter analyze
flutter test
```

From `engine/`:
```powershell
.\.venv\Scripts\python.exe -m pytest tests -q
```

Private workbooks in `engine/routine generation files/` contain personal data and remain gitignored. `engine/tools/seed_config.py` rewrites config and seed files — do not run it for inspection.

## Team

Team Sherlocked, CSE-3240 (Project I), Leading University:
- **Fahmid Alam:** Architecture, shared infrastructure, auth, admin, timetable engine, build/deploy
- **Swadheen Islam Robi:** Routine, resources, dashboards, teacher features, room/teacher lookup
- **Shahriar Rashid Ratul:** Notifications, profile, push, QA, seeding, and docs
