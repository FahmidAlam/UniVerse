<div align="center">
<img src="assets/icon/app_icon.png" width="96" alt="UniVerse app icon" />

# UniVerse — A Campus Companion

A Flutter campus application for students, teachers and administrators, with a Python timetable generator.
</div>

UniVerse began as a CSE application for Leading University, Sylhet. University-wide scheduling and reliable offline access are planned extensions, not completed capabilities.

**Immediate priority:** a browser-based admin extension and complete CSE routine generation, extending this application. Preserve the long-term multi-department academic-management direction; other actors on web and offline expansion follow later.

**Current audit (4 November 2026):** [Admin web assessment and roadmap](docs/timetable-audit-2026-10-20/15-admin-web-preimplementation-2026-11-04.md), [all 16 committee requirements](docs/timetable-audit-2026-10-20/16-committee-traceability-2026-11-04.md), and [documentation/PDF inventory](docs/timetable-audit-2026-10-20/17-documentation-inventory-2026-11-04.md). Audit/documentation only; implementation requires a separate instruction. [Earlier checkpoints](docs/timetable-audit-2026-10-20/README.md) retain dated evidence.

## Implemented features

**Committee policy update:** [Confirmed decisions and editable Course Distribution baseline](docs/timetable-audit-2026-10-20/18-committee-decisions-and-policy-baseline-2026-11-04.md) supersede the initial audit's open questions. Independent section weekends, faculty attendance distinct from teaching, distinct-course adjunct workloads, low-credit theory blocks and explicit sessional break permission are approved requirements, not implemented features. The editable distribution page is also future work: retain original files and use one validated versioned correction draft throughout generation and publication.

After separate implementation instruction, start with browser admin compatibility. [Five specialist roles and coordination](docs/timetable-audit-2026-10-20/19-specialist-coordination-workflow-2026-11-04.md) assign platform, UI/distribution, scheduling, backend and independent testing work; the [repository skill](.agents/skills/universe-implementation/SKILL.md) provides portable handoffs. Preparation does not authorize source changes.

- Student/teacher dashboards and weekly routines, selected by batch/section or teacher code.
- Resources organized by semester/category, with uploaded files and links.
- Notification feed, read receipts and local dismiss preferences.
- Teacher cancellation of dated class occurrences, notices and cancellation undo.
- Admin user/whitelist management, broadcasts, resources, rooms, faculty and scheduling settings.
- Admin routine hub with manual management, distribution generation and rendered-workbook upload.
- Room and teacher lookup derived from scheduled classes.
- Firebase messaging client integration and local notification display.

Room/teacher lookup represents scheduled activity, not physical tracking. It currently ignores cancellations and has freshness/lifecycle limitations. Schedule data is not persistently cached for offline use.

The intended push path is notification insert to Supabase webhook, send-push and FCM. Executable recovered Edge Function sources now exist, including a test-only webhook gate. See [backend baseline evidence](docs/backend-setup.md). Their presence does not establish production rollout or end-to-end delivery; no deployment is authorized by these docs.

## Timetable engine

```text
Distribution .xlsx + configuration from Supabase
  → ingest.py: group source rows into offerings and weekly sessions
  → solver.py: CP-SAT day/period placement, greedy concrete-room assignment
  → validation: reconcile normalized requirements and scheduling checks
  → render.py: generate a workbook using the CSE template
  → Flutter: report, grid, download and publication
```

The engine models teacher/cohort slot conflicts, day-offs, blocked periods, room-pool counts, same-day restrictions and inferred theory/lab adjacency. Faculty-course eligibility is validated after solving. Known room capacity and source-backed combined-section collisions are now checked; usable periods must not overlap. Equipment, per-slot faculty/room availability and independent cross-department reservations remain gaps. Pool capacity alone does not guarantee a usable concrete-room allocation.

Weekly counts normally derive from term class totals and teaching weeks. A fixed count can override them; migration 015 sets the existing settings row to two/week. Under-delivery currently produces warnings rather than blocking errors.

The older Summer 2025 audit counted 325 assigned offerings/656 derived meetings. Later pending-preserving ingestion retains **338 offerings and 682 meetings** under the explicit 14-week source-derived policy, or 676 at fixed two/week; see [dated showcase evidence](docs/timetable-audit-2026-10-20/11-advisor-showcase-2026-11-02.md). Fixture results are not current committee-policy approval.

Generated/uploaded routines use `publish_routine` (012, replaced by 014), which atomically replaces **all** current rows. Manual management still changes individual rows directly. Shared backend validation, scoped publication, full historical snapshots and committee approval remain necessary before university-wide use.

## Stack and layout

| Layer | Implementation |
|---|---|
| App | Flutter/Dart; pubspec SDK range `>=3.0.0 <4.0.0` |
| State/routing | ChangeNotifier, ListenableBuilder, SafeChangeNotifier in several features; GoRouter |
| Backend | Supabase Auth, PostgreSQL/RLS, Storage and selected Realtime streams |
| Sign-in | Native Google ID-token exchange off-web; browser OAuth on web; email/password |
| Permissions | Student/teacher/admin; migration 016 gates new teacher/admin roles through whitelists |
| Messaging | Firebase Core/Cloud Messaging and flutter_local_notifications; no Firestore/Firebase Auth |
| Scheduling | FastAPI, OR-Tools CP-SAT, openpyxl |
| Local state | SharedPreferences/temporary files; Hive declared but no timetable cache |
| UI | Inter, dark theme tokens, Material icon shim exposing Phosphor names |

The feature-first convention is screen → controller → service → backend, with a few existing exceptions.

```text
lib/main.dart
lib/core/                   constants, models, router, theme, utilities, push
lib/shared/                 widgets and utilities
lib/features/               auth, admin, routine, resources, notifications,
                            profile, dashboard, teacher, find_teacher, rooms
engine/                     API, ingestion, solver, renderer, tests, templates
supabase/migrations/        historical incremental SQL + local additive catalog
supabase/reconciliation/    reconstructed baseline and verification artifacts
supabase/functions/         recovered executable source; rollout unverified
supabase/seed/              sample/historical data; not production setup
```

[Defense diagrams](docs/archive/diagrams/README.md) contain historical schema/behavior claims; use the current audit for architecture.

## Local setup

Use an Android-capable Flutter installation and configured Android SDK/JDK. The audit's SDK cache reported Flutter **3.47.0 / Dart 3.13.0**; this is a tested local environment, not the minimum supported version. `pubspec.lock` records resolved dependencies.

Android files use Gradle **8.14**, AGP **8.11.1**, Kotlin **2.2.20**. Keep the established wrapper unless deliberately coordinating toolchain changes. Release currently uses debug signing and a development package identity; production release setup is incomplete.

From repository root in PowerShell:

```powershell
flutter pub get
Copy-Item dart_defines.example.json dart_defines.json
flutter run --dart-define-from-file=dart_defines.json
flutter build apk --release --dart-define-from-file=dart_defines.json
```

Fill the copied example before running. AppConstants supports `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `TIMETABLE_BASE_URL` and `GOOGLE_WEB_CLIENT_ID`. Select a test environment deliberately; code defaults point to a project/service. Never put privileged server credentials in Dart defines.

APK output: `build/app/outputs/flutter-apk/app-release.apk`. Building release does not establish production signing readiness.

Firebase setup is Android-focused. Native Google sign-in depends on the web client ID, package identity and registered signing certificate. Coordinate package/signing changes with Firebase/OAuth and these links:

```text
com.example.universe://login-callback/
com.example.universe://reset-callback/
```

Other platform folders exist but are not evidence of tested support.

## Backend setup limitations

The historical 15 migrations (001-009 and 011-016, no 010) alter an existing schema and do not bootstrap a complete backend. A reconstructed baseline, local config, isolated verifier and additive catalog migration now exist; see [backend setup](docs/backend-setup.md). Automatic replay of the historical chain is disabled. Local artifacts do not prove hosted catalog deployment.

Before backend rollout, review existing reconciliation/local verification evidence and reconcile current deployment drift, grants/RLS, Storage, Realtime and migration history. Recovered function sources and a limited backup exist; full production recovery remains unverified. Do not run demo seeds or destructive migrations against production. [Migration proposal](docs/timetable-audit-2026-10-20/05-database-migration.md)

`supabase/diagnostics.sql` offers read-only introspection. Review its output for sensitive configuration before sharing.

## Running the engine

Deployment files request Python **3.12.7**. Audit tests used the existing Python **3.11.4** environment; validate the deployment interpreter separately.

```powershell
Set-Location engine
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements-dev.txt
.\.venv\Scripts\python.exe -m uvicorn main:app --reload --port 8000
```

For Android emulator development, use `TIMETABLE_BASE_URL=http://10.0.2.2:8000`. Android cleartext exceptions cover local development hosts.

| Method/path | Current contract |
|---|---|
| `GET /` | Health JSON |
| `POST /api/timetable/generate` | Multipart required file, optional config JSON string and time_limit_s (default 60) → job ID |
| `GET /api/timetable/status/{job_id}` | queued/ingesting/solving/rendering/done/failed, progress and metadata/error |
| `GET /api/timetable/result/{job_id}` | rows, service_rows, stats, validation, report, has_workbook |
| `GET /api/timetable/download/{job_id}` | Rendered .xlsx |

Jobs are currently in memory without authenticated ownership/resource bounds. `.xls` passes filename checks but the reader requires `.xlsx`. See [engine guide](engine/README.md) for current constraints and limits.

`render.yaml`, Procfile and runtime files describe hosting. Actual account linkage, deploy branch, uptime and automatic rebuild behavior were not verified.

## Verification

From repository root:

```powershell
flutter analyze
flutter test
```

From engine:

```powershell
.\.venv\Scripts\python.exe -m pytest tests -q
```

Optional private-workbook full solve, from engine:

```powershell
$env:UNIVERSE_SOLVE = '1'
$env:SOLVER_WORKERS = '2'
.\.venv\Scripts\python.exe -m pytest tests/test_real_distribution.py -q
Remove-Item Env:UNIVERSE_SOLVE
Remove-Item Env:SOLVER_WORKERS
```

On 4 November 2026: **115 Flutter tests passed; 210 engine tests passed and 1 optional full solve skipped**. October analysis/results remain dated evidence; no browser build or live DB/push/device certification was performed here. [Acceptance strategy](docs/timetable-audit-2026-10-20/06-testing-and-acceptance.md)

Private workbooks in `engine/routine generation files/` contain personal data and must remain gitignored. Use sanitized CI fixtures. `engine/tools/seed_config.py` rewrites config and seed files; it is not an inspection command.

## Team and conventions

Team Sherlocked, CSE-3240 (Project I), Leading University.

| Member | Ownership |
|---|---|
| Fahmid Alam | Architecture, shared infrastructure, auth, admin, timetable engine, build/deploy |
| Swadheen Islam Robi | Routine, resources, dashboards, teacher features, room/teacher lookup |
| Shahriar Rashid Ratul | Notifications, profile, push, QA, seeding and docs |

Use theme tokens, package imports and existing navigation/service patterns. [CLAUDE.md](CLAUDE.md) records engineering guardrails. AI assistance remains outside current scope.

Academic project; no redistribution license is specified.
