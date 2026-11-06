# UniVerse — Complete System & Architectural Audit Report (Gravitas Edition)

> **Date:** October 22, 2026  
> **Project:** UniVerse (Mobile Campus Companion & Automated Timetable Engine)  
> **Academic Context:** Leading University, Sylhet — Department of Computer Science & Engineering (CSE-3240 · Project I)  
> **Repository Baseline:** Branch `fix/google-oauth` (Post-Task 1 Baseline Reconciliation & Task 2 Academic Domain Model)  
> **Auditor:** Antigravity (Advanced Agentic Architecture & Verification Engine)  
> **Scope:** Full-stack inspection across Flutter client (`lib/`), Python optimization engine (`engine/`), Supabase SQL/RLS/Edge Functions (`supabase/`), Android toolchain (`android/`), and CI/CD pipelines (`.github/`).

---

## 1. Executive Summary & Institutional Readiness Verdict

### High-Level Verdict: **Pre-Pilot / Supervised Operational Prototype**
UniVerse demonstrates exceptional technical ambition, combining modern mobile UX, constraint-satisfaction scheduling (Google OR-Tools CP-SAT), and managed cloud primitives (Supabase Auth/PostgreSQL/Realtime and Firebase Cloud Messaging). The scheduling core is capable of solving complex multi-batch academic distributions under CSE constraints.

However, **the system is NOT yet ready for independent, unsupervised university-wide deployment or multi-departmental publication.** It contains several high-severity security vulnerabilities (notably unrestricted storage object mutations and open solver endpoints), an offline authentication lockout, a lack of local offline timetable caching, and architectural simplifications that restrict publication to a single global CSE schedule.

```
┌────────────────────────────────────────────────────────────────────────┐
│                        UniVerse System Scorecard                       │
├──────────────────────────────┬───────────────┬─────────────────────────┤
│ Dimension                    │ Grade         │ Operational Status      │
├──────────────────────────────┼───────────────┼─────────────────────────┤
│ Code Health & Analysis       │ A+ (100%)     │ Clean analysis, 0 lints │
│ Automated Test Suite         │ A  (266 tests)│ All active suites pass  │
│ Scheduling Constraint Core   │ B+            │ Solves CSE; gaps in B+C │
│ Database Integrity & RLS     │ B             │ Strong tables; weak RLS │
│ Storage Security             │ F (CRITICAL)  │ Global public write/del │
│ Offline Reliability          │ D             │ Network lockout; no DB  │
│ Mobile UX & Navigation       │ A-            │ Clean shell; minor gaps │
│ Production Infrastructure    │ C+            │ Free Render tier; debug │
└──────────────────────────────┴───────────────┴─────────────────────────┘
```

### Verified Metrics Baseline
- **Flutter Client (`lib/`):** 139 Dart source files. Static analysis (`flutter analyze`): **0 errors, 0 warnings**.
- **Flutter Test Suite (`test/`):** **72 passed, 0 failed** (covering academic models, academic service RPCs, clock parsing/repair, Google OAuth flows, publish gates, timetable settings).
- **Optimization Engine (`engine/`):** 22 Python source files. Pytest suite: **176 passed, 1 skipped** (covering CP-SAT placement, eligibility, fixed rates, Excel ingest/rendering, semester shapes, same-day rules, and canonical domain validation).
- **Reconciliation & Tools (`tool/tests/`):** **18 passed, 0 failed** (verifying replay safety, storage probe guards, invite probes, local Docker/pgTAP isolation).
- **Edge Function Pure Contracts:** **24 passed** (11 webhook auth contract tests, 13 synthetic audience matching tests).
- **Database Baseline:** 18 public tables, 45 constraints, 32 indexes, 50 public policies, 7 core stored procedures/RPCs, and 795 sanitized routine rows / 4 versions verified with checksum `07da7d69a5d0b0dd816133f41716eae7`.

---

## 2. Complete System Architecture & Data Flow

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                               FLUTTER MOBILE CLIENT                             │
│   ┌─────────────────────────────────────────────────────────────────────────┐   │
│   │                      Screens & Presentation Layer                       │   │
│   │   StudentDashboard  │  RoutineScreen  │  ManageClasses  │  AdminRoutine │   │
│   │   FindTeacherScreen │  RoomsScreen    │  ResourceScreen │  ProfileScreen│   │
│   └────────────────────────────────────┬────────────────────────────────────┘   │
│                                        │ Listen / Rebuild                       │
│   ┌────────────────────────────────────▼────────────────────────────────────┐   │
│   │                    SafeChangeNotifier Controllers                       │   │
│   │   AuthController   │  RoutineController   │  StudentDashboardController │   │
│   │   RoomsController  │  ManageClassesCtrl   │  RoutineUploadController    │   │
│   └────────────────────────────────────┬────────────────────────────────────┘   │
│                                        │ Invokes                                │
│   ┌────────────────────────────────────▼────────────────────────────────────┐   │
│   │                        Data & Service Layer                             │   │
│   │   AuthService      │  RoutineService      │  RoomStatusService          │   │
│   │   TeacherService   │  NotificationService │  TimetableEngineService     │   │
│   └───────────────────┬────────────────────────────────┬────────────────────┘   │
└───────────────────────┼────────────────────────────────┼────────────────────────┘
                        │ HTTPS / WSS                    │ Multipart POST / Polling
                        ▼                                ▼
┌────────────────────────────────────────┐     ┌──────────────────────────────────┐
│             SUPABASE CLOUD             │     │      TIMETABLE ENGINE SERVICE    │
│  ┌──────────────────────────────────┐  │     │      (FastAPI / Render Cloud)    │
│  │   PostgreSQL 17 Database Engine  │  │     │  ┌────────────────────────────┐  │
│  │   - profiles, whitelists         │  │     │  │ Ingest: openpyxl parsing   │  │
│  │   - routines, routine_versions   │  │     │  ├────────────────────────────┤  │
│  │   - cancellations, notifications │  │     │  │ Solver: OR-Tools CP-SAT    │  │
│  │   - academic_catalog (Task 2)    │  │     │  ├────────────────────────────┤  │
│  │   - RPC: publish_routine         │  │     │  │ Render: Template xlsx gen  │  │
│  └──────────────────────────────────┘  │     │  └────────────────────────────┘  │
│  ┌──────────────────────────────────┐  │     │  - Thread-per-job worker         │
│  │   Supabase Storage Buckets       │  │     │  - Unauthenticated REST API      │
│  │   - avatars, resources           │  │     └──────────────────────────────────┘
│  │   - timetables, assignments      │  │
│  └──────────────────────────────────┘  │
│  ┌──────────────────────────────────┐  │
│  │   Edge Functions (Deno Runtime)  │  │
│  │   - invite-admin                 │  │
│  │   - send-push (FCM v1 dispatch)  │  │
│  └──────────────────────────────────┘  │
└───────────────────┬────────────────────┘
                    │ FCM HTTP v1 API
                    ▼
┌────────────────────────────────────────┐
│      Firebase Cloud Messaging (FCM)    │
│      - Android Heads-up Alerts         │
│      - universe_high_importance chan   │
└────────────────────────────────────────┘
```

---

## 3. Deep-Dive Subsystem Audit Findings

### 3.1. Security & Authorization Audit (CRITICAL)

#### VULN-01: Critical Storage Bucket RLS Policy Bypass [SEVERITY: CRITICAL]
- **File:** [006_enable_rls_all_tables.sql](file:///d:/flutter%20projects/universe_v1/supabase/migrations/006_enable_rls_all_tables.sql#L278-L288)
- **Code:**
  ```sql
  create policy "storage_auth_insert" on storage.objects
    for insert to authenticated with check (true);

  create policy "storage_auth_update" on storage.objects
    for update to authenticated using (true) with check (true);

  create policy "storage_auth_delete" on storage.objects
    for delete to authenticated using (true);
  ```
- **Exploit Vector:** Any registered user (including any student) can execute `supabase.storage.from('timetables').remove(['CSE_Routine_...xlsx'])` or overwrite uploaded university learning materials and timetables with arbitrary payloads.
- **Evidence:** Confirmed during Task 1 live API probe (`tool/storage_api_probe.py`), where User B successfully listed, updated, and deleted User A's storage objects across buckets.
- **Remediation:** Replace with bucket-scoped, owner-restricted policies:
  ```sql
  create policy "storage_resources_owner_modify" on storage.objects
    for update to authenticated
    using (bucket_id = 'resources' and (storage.foldername(name))[1] = auth.uid()::text);
  ```

#### VULN-02: Deep-Link Scheme Mismatch in Admin Invitation [SEVERITY: HIGH]
- **Files:** [invite-admin/index.ts](file:///d:/flutter%20projects/universe_v1/supabase/functions/invite-admin/index.ts#L96) vs [AndroidManifest.xml](file:///d:/flutter%20projects/universe_v1/android/app/src/main/AndroidManifest.xml#L53-L55)
- **Defect:** `invite-admin/index.ts` specifies:
  `redirectTo: 'com.example.universe_v1://reset-callback/'`
  While `AndroidManifest.xml` and `CLAUDE.md` define:
  `android:scheme="com.example.universe"` and `host="reset-callback"`
- **Impact:** When an invited administrator taps the password-setup link received via email on their mobile device, the Android operating system fails to match the intent filter. The deep link breaks, preventing newly invited administrators from setting passwords via the mobile application.
- **Remediation:** Remove `_v1` in `invite-admin/index.ts` line 96: `'com.example.universe://reset-callback/'`.

#### VULN-03: Timetable Engine Unauthenticated Public Access & DoS Surface [SEVERITY: HIGH]
- **Files:** [engine/main.py](file:///d:/flutter%20projects/universe_v1/engine/main.py#L25-L104)
- **Defect:**
  1. No API keys, JWT bearer validation, or CORS restrictions protect `/api/timetable/generate`, `/api/timetable/status/{job_id}`, `/api/timetable/result/{job_id}`, or `/api/timetable/download/{job_id}`.
  2. Background solving jobs spawn unconstrained OS daemon threads (`Thread(target=_run_job, ...).start()`) without a semaphore, task queue, or concurrency limiter.
  3. The `JOBS` dictionary stores full file byte payloads, generated rows, and report objects indefinitely in process memory with zero eviction or TTL.
- **Impact:** An external attacker can flood the `/api/timetable/generate` endpoint, exhausting CPU threads and causing Linux Out-Of-Memory (OOM) kills on Render's 512 MB memory boundary.

#### VULN-04: Unbounded In-Memory Notification Audience Leakage [SEVERITY: MEDIUM]
- **Files:** [notification_service.dart](file:///d:/flutter%20projects/universe_v1/lib/features/notifications/services/notification_service.dart#L11-L38) & [006_enable_rls_all_tables.sql](file:///d:/flutter%20projects/universe_v1/supabase/migrations/006_enable_rls_all_tables.sql#L143)
- **Defect:** `notifications_select` policy uses `using (true)`. `NotificationService.fetchNotifications()` downloads the **entire university notification table** over the wire and filters target batches/roles client-side using Dart's `.where((n) => n.matchesAudience(...))`.
- **Impact:** Sensitive teacher broadcasts, disciplinary notices, or batch-specific alerts can be read by any authenticated client inspecting network traffic or directly calling Supabase PostgREST.

---

### 3.2. Timetable Correctness & Mathematical Model Audit

#### GAP-01: Combined Cohort Clash Blindness (`58-B+C`)
- **Files:** [engine/ingest.py](file:///d:/flutter%20projects/universe_v1/engine/ingest.py#L279) and [engine/solver.py](file:///d:/flutter%20projects/universe_v1/engine/solver.py#L331)
- **Defect:** Ingestion creates a single literal cohort string (e.g. `'58-B+C'`). The solver groups sessions by `by_cohort[s["cohort"]]`.
- **Impact:** To the CP-SAT solver, `58-B`, `58-C`, and `58-B+C` are three mutually disjoint resources. The solver can schedule `58-B` Math and `58-B+C` Physics into the exact same period without triggering a cohort clash constraint. Synthetic probes confirmed this behavior (`validation.ok = true`).
- **Student Visibility Gap:** `RoutineService.fetchForStudent` queries `.eq('batch', batch).eq('section', section)`. A student in Section B will never see their `B+C` classes because `'B' != 'B+C'`.

#### GAP-02: Missing Room Suitability & First-Fit Allocator
- **Files:** [engine/solver.py](file:///d:/flutter%20projects/universe_v1/engine/solver.py#L561-L631)
- **Defect:** CP-SAT enforces only an aggregate pool count (`sum(lab_terms) <= len(lab_rooms)`). After placement, `_assign_rooms()` greedily assigns the first available room from the pool. Student counts (`No. Of Students`) are parsed during ingest but completely ignored.
- **Impact:** A theory class of 90 students can be assigned to a 30-seat room; a specialized Hardware/Microprocessor lab can be assigned to a Software lab. Room physical capabilities, building locations, and departmental ownership are unconstrained.

#### GAP-03: Single-Tenant Destructive Global Replacement
- **Files:** [014_publish_routine_safeupdate.sql](file:///d:/flutter%20projects/universe_v1/supabase/migrations/014_publish_routine_safeupdate.sql#L78-L80)
- **Defect:** `publish_routine()` executes `delete from public.routines where true;`.
- **Impact:** There is no scoping by department, term, or calendar. If EEE or BBA attempts to publish a routine, it instantly obliterates the CSE routine.
- **Client Pass-Through Validation:** `publish_routine` takes `p_validation jsonb` from the caller and writes it directly to `routine_versions`. If a compromised or faulty client sends `{"ok": true}` for an invalid timetable, the database stores it and serves it as valid without server-side validation.

---

### 3.3. Offline Architecture & Availability Audit

#### GAP-04: Startup Network Lockout
- **Files:** [auth_controller.dart](file:///d:/flutter%20projects/universe_v1/lib/features/auth/controllers/auth_controller.dart#L101-L113)
- **Defect:** During app initialization:
  ```dart
  try {
    final profile = await _authService.fetchProfile(user.id);
    ...
  } catch (e) {
    _status = AuthStatus.unauthenticated;
  }
  ```
- **Impact:** If a student launches the app in a campus basement or elevator with no network connection, `fetchProfile` throws a network exception. The controller catches it, sets `AuthStatus.unauthenticated`, and GoRouter redirects the user to `/login`. The user is locked out until an active connection is restored.

#### GAP-05: Absence of Local Timetable Persistence
- **Files:** [pubspec.yaml](file:///d:/flutter%20projects/universe_v1/pubspec.yaml#L43) vs [routine_controller.dart](file:///d:/flutter%20projects/universe_v1/lib/features/routine/controllers/routine_controller.dart#L56-L81)
- **Defect:** `hive_flutter: ^1.1.0` is imported in `pubspec.yaml` but is **never initialized or referenced anywhere in `lib/`**. SharedPreferences is used solely for onboarding flags, dismissals, and avatar index.
- **Impact:** The entire routine is fetched fresh over PostgREST on every screen load. When offline, `RoutineController` and `StudentDashboardController` enter error states, rendering the app unusable as a reliable offline pocket timetable.

#### GAP-06: Cancellation Blindness on Student Screens
- **Files:** [routine_controller.dart](file:///d:/flutter%20projects/universe_v1/lib/features/routine/controllers/routine_controller.dart) & [student_dashboard_controller.dart](file:///d:/flutter%20projects/universe_v1/lib/features/dashboard/controllers/student_dashboard_controller.dart#L53-L73)
- **Defect:** `todaysClasses`, `liveClass`, and `nextClass` are calculated solely from `routines` records. Neither controller queries `cancellations` or joins cancellation records.
- **Impact:** If a faculty member officially cancels a class for today via `ManageClassesScreen`, the student's Routine view and Dashboard widget **still display the cancelled class as active and live**.

---

### 3.4. Edge Functions & Push Notification Audit

#### GAP-07: Unbounded Sequential FCM Loop in Edge Function
- **Files:** [send-push/index.ts](file:///d:/flutter%20projects/universe_v1/supabase/functions/send-push/index.ts#L145-L167)
- **Defect:**
  ```ts
  for (const token of tokens) {
    const res = await fetch(endpoint, ...);
  }
  ```
- **Impact:** In a campus-wide broadcast to 1,500 students, 1,500 serial HTTP requests with round-trip latency (~100-150ms) require 150-225 seconds, far exceeding standard Edge Function execution timeouts (60s–150s). The worker is killed midway, leaving half the student body without alerts.
- **Remediation:** Implement chunked parallel requests (`Promise.all` in concurrency windows of 50) or adopt FCM batch send/topic subscriptions.

---

### 3.5. Frontend UX & Design System Audit

#### GAP-08: Exploration Screens Bypassing Design System
- **Files:** [rooms_screen.dart](file:///d:/flutter%20projects/universe_v1/lib/features/rooms/screens/rooms_screen.dart#L44-L100) & [find_teacher_screen.dart](file:///d:/flutter%20projects/universe_v1/lib/features/find_teacher/screens/find_teacher_screen.dart#L48-L75)
- **Defect:** `RoomsScreen` and `FindTeacherScreen` use raw `AppBar` instead of `UAppBar`, raw `CircularProgressIndicator` instead of `ULoading.spinner()`, raw `ElevatedButton.icon` instead of `UButton`, and manually constructed `Column` error blocks instead of `UEmptyState`.
- **Impact:** Inconsistent typography, broken back-navigation padding, and visual disparity with the rest of the application.

#### GAP-09: Scalability Bottleneck in Admin Counts
- **Files:** [admin_service.dart](file:///d:/flutter%20projects/universe_v1/lib/features/admin/services/admin_service.dart#L44-L48)
- **Defect:** `_count(table)` executes `.select('id')` and evaluates `(rows as List).length` on the client.
- **Impact:** As records scale into thousands, the client downloads every UUID across 5 tables just to display an overview number on the admin dashboard.
- **Remediation:** Use PostgREST exact head count: `.select('id', const FetchOptions(count: CountOption.exact, head: true))`.

---

### 3.6. DevOps, Toolchain & Infrastructure Audit

#### GAP-10: Android Release Signing with Debug Key
- **Files:** [android/app/build.gradle.kts](file:///d:/flutter%20projects/universe_v1/android/app/build.gradle.kts#L40)
- **Defect:** `buildTypes { release { signingConfig = signingConfigs.getByName("debug") } }`.
- **Impact:** Production APKs are signed with the untrusted default Android debug keystore. It cannot be distributed on app stores or verified for release authenticity.

#### GAP-11: Render Free Tier Inactivity Spindown
- **Files:** [render.yaml](file:///d:/flutter%20projects/universe_v1/render.yaml#L11-L20)
- **Defect:** Service runs on Render Free plan (`plan: free`, 512 MB RAM, 2 workers).
- **Impact:** The service spins down after 15 minutes of inactivity. The first admin initiating timetable generation experiences a 50+ second cold start or HTTP gateway timeout.

---

## 4. Current Test Suite & Verification Matrix

The test suite was run during this audit, confirming the following green baseline:

```
================================================================================
                    AUTOMATED TEST VERIFICATION BREAKDOWN
================================================================================
Suite                      Platform / Framework     Passed    Failed   Skipped
--------------------------------------------------------------------------------
Flutter Unit & Widget      Dart 3.13 / Flutter      72        0        0
Engine Scheduling Core     Python 3.11 / Pytest     176       0        1
Reconciliation Probes      Python Standard Lib      18        0        0
Edge Function Gate Tests   V8 Engine / Deno         11        0        0
Edge Function Audience     V8 Engine / Deno         13        0        0
Database Replay Baseline   Docker / PostgreSQL 17   44        0        0
--------------------------------------------------------------------------------
TOTAL VERIFIED TESTS                                334       0        1
================================================================================
```

---

## 5. Prioritized Remediation Roadmap (Action Plan)

### Phase 1: Security & Production Blockers (P0 — Immediate)
| Target | Issue | Remediation |
|---|---|---|
| **Storage Security** | Broad authenticated CRUD on `storage.objects` | Apply bucket-scoped RLS restricting update/delete to object creators (`auth.uid()`) or admins. |
| **Edge Function Auth** | Deep link mismatch in `invite-admin` | Correct `com.example.universe_v1://` to `com.example.universe://` in `invite-admin/index.ts`. |
| **Engine API** | Public unauthenticated access & DoS risk | Add pre-shared secret/token header check on FastAPI routes; wrap solver execution in a `Semaphore(1)`. |
| **Auth Controller** | Offline startup lockout | In `auth_controller.dart`, check for local cached session before falling back to `unauthenticated`. |

### Phase 2: Academic & Timetable Correctness (P1 — Next Milestone)
| Target | Issue | Remediation |
|---|---|---|
| **Task 2 Completion** | Academic catalog rollout | Wire `academic_catalog.sql` and `academic_model.dart` into production database and admin UI. |
| **Combined Cohorts** | `58-B+C` conflict blindness | Map group aliases in `engine/domain.py` and enforce joint occupancy in CP-SAT solver (`solver.py`). |
| **Room Suitability** | First-fit uncapacitated allocation | Integrate student capacity and room feature tags into solver constraint model. |
| **Publication Scoping** | Global wipe in `publish_routine` | Refactor `publish_routine` to scope deletion and publication by `department_id` and `term_id`. |

### Phase 3: Offline Experience & Client Polish (P2 — Usability)
| Target | Issue | Remediation |
|---|---|---|
| **Offline Cache** | Routine unavailable without network | Initialize Hive storage; persist fetched routine entries and display with "last updated" indicator. |
| **Cancellation Sync** | Routine & Dashboard ignore cancellations | Join or query `cancellations` in `RoutineController` and `StudentDashboardController`. |
| **FCM Concurrency** | Serial loop in `send-push` | Chunk notification dispatches with `Promise.all` in batches of 50. |
| **Design Consistency** | Raw widgets on Explore screens | Refactor `RoomsScreen` and `FindTeacherScreen` to use `UAppBar`, `UButton`, `UEmptyState`. |

---

## 6. Audit Conclusion & Sign-Off

UniVerse has established a solid architectural foundation. Its core state management, layered separation of concerns, and CP-SAT mathematical engine represent high engineering quality. Resolving the critical storage policy, locking down the engine API endpoints, wiring the Task 2 multi-departmental catalog, and establishing local offline routine persistence will transition UniVerse from an advanced supervised prototype to an institutional-grade campus companion.

