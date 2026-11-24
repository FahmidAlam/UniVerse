<div align="center">
<img src="assets/icon/app_icon.png" width="96" alt="UniVerse app icon" />

# UniVerse — A Campus Companion

A Flutter campus application for students, teachers, and administrators, with a Python OR-Tools CP-SAT timetable generator.
</div>

**Authoritative Roadmap & Active Checkpoint:** [`docs/implementation/UniVerse_Implementation_Master_Plan_v1_1.md`](docs/implementation/UniVerse_Implementation_Master_Plan_v1_1.md)
**Engineering Rules:** [`AGENTS.md`](AGENTS.md) (Codex / Antigravity) & [`CLAUDE.md`](CLAUDE.md) (Claude)

## Current Implementation Status

- **Standalone React Web (`apps/web/`, UniVerse Academic Ledger):** Phases 0–4B, Theme v3 (**X-Grade Carbon Obsidian Dark + Crisp Daylight Light + X-Azure**), dynamic midday break, in-browser Course Distribution Studio, Official Committee Day Sheet + Landscape A4 print, and Phase 5A/5B/5C-Prep & Staging Phase 5B RLS/storage hardening are **implemented and verified**. See [`docs/architecture/WEB_ARCHITECTURE_DESIGN_BLUEPRINT.md`](docs/architecture/WEB_ARCHITECTURE_DESIGN_BLUEPRINT.md), [`docs/architecture/WEB_IMPLEMENTATION_ROADMAP.md`](docs/architecture/WEB_IMPLEMENTATION_ROADMAP.md), and [`docs/implementation/web_phase_5_staging_verification_and_ci_fix.md`](docs/implementation/web_phase_5_staging_verification_and_ci_fix.md).
- **Flutter Mobile (`lib/`, Obsidian Orbit):** Active Android & iOS-compatible Student and Teacher mobile client. Legacy Flutter Web (`web/` and desktop admin flows under `lib/features/admin/`) is **frozen** as a read-only rollback fallback until Production Cutover + Phase 3B complete.
- **Immediate Next Milestone:** GitHub Push (5-job CI in `.github/workflows/validate.yml`) + Cloudflare Pages **Environment A** (Continuous Committee Review → Staging `oqwvxplteqtlrhktsplj`) → Gated Production Cutover (**Environment B** + Phase 4A-1) → **Wave 2** (`Phase 4A-2`: R1–R16 CP-SAT Solver, Gate C/D Backend, Phase 3B Parse Endpoint, and Post-Cutover Flutter Web Pruning).

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
