# 04 — End-to-End Data Flows, CI/CD & Wave 2 Impact Matrix

**Freshness Date:** 2026-11-24  
**Primary Sources:** `.github/workflows/validate.yml`, `.github/workflows/supabase_keep_alive.yml`, `render.yaml`, `apps/web/public/_headers`, `apps/web/public/_redirects`, `apps/web/public/theme-init.js`, `docs/deployment/CLOUDFLARE_PAGES_AND_CUTOVER_RUNBOOK.md`, `docs/deployment/PHASE_4A1_AND_5B_SQL_PROMOTION_RUNBOOK.md`, `apps/web/src/features/**`, `lib/features/**`.

---

## 1. End-to-End Cross-System Data Flows

`[VERIFIED: Repo Source]` (`apps/web/src/services/supabase.ts`, `apps/web/src/features/**`, `lib/features/**`, `supabase/**`, `engine/**`)

### Flow 1: Auth, Whitelist Provisioning & Admin Invite Flow

```mermaid
sequenceDiagram
    autonumber
    participant Admin as Existing Admin<br/>(React Web /admin/users)
    participant InviteFn as Edge Function: invite-admin<br/>(callback_policy.js + handler.js)
    participant GoTrue as Supabase GoTrue Auth<br/>(PKCE + Invite)
    participant DB as Supabase Postgres<br/>(whitelists + profiles + guard_profile_role)
    participant Invitee as Invited Admin / Mobile User

    Admin->>InviteFn: POST /functions/v1/invite-admin<br/>Bearer JWT + {email, name, redirect_to: "${origin}/"}
    InviteFn->>GoTrue: callerClient.auth.getUser() (401 if invalid)
    InviteFn->>DB: Service-Role SELECT role FROM profiles (403 if != 'admin')
    InviteFn->>InviteFn: resolveInvitationCallback(redirect_to, AUTH_WEB_CALLBACK_URLS)<br/>(400 BEFORE any write if unapproved)
    InviteFn->>DB: Service-Role UPSERT public.whitelists (role='admin')
    InviteFn->>GoTrue: admin.inviteUserByEmail(email, { redirectTo })
    GoTrue-->>Invitee: Invite Email -> "${origin}/#access_token=...&type=invite"
    Invitee->>Invitee: extractAndScrubInviteHash() (history.replaceState)<br/>Reject if URL has ?query
    Invitee->>GoTrue: GET /auth/v1/user (verify id, invited_at, email_confirmed_at)<br/>POST /auth/v1/token?grant_type=refresh_token (expires_at > now+60)
    Invitee->>Invitee: setSession() -> 10m passwordRecovery -> /reset-password
    Invitee->>GoTrue: updateUser({ password }) -> signOut() -> signInWithPassword / Google PKCE
    Invitee->>DB: SELECT profiles(id=uid) -> missing -> SELECT whitelists(email, role='admin')
    Invitee->>DB: INSERT profiles(role='admin') -> guard_profile_role() trigger verifies whitelist
    Note over Invitee,DB: Duplicate concurrent insert (23505 / 409) auto-recovers via re-SELECT.<br/>Non-admin roles route to /access-required on Web or Student/Teacher Hub on Mobile.
```

### Flow 2: Live Student/Teacher Routine Read, Lookup & Realtime Cancellation Flow

> **Critical Realtime Publication Fact `[VERIFIED: Repo Source]`:** `supabase_realtime` publishes **ONLY `public.cancellations`** (`puballtables = false` on both Production and Staging). Neither `public.routines` nor `public.notifications` is in `supabase_realtime`! Note that `TeacherLocationService.streamAllRoutines()`, `RoomStatusService.streamAllRoutines()`, and `NotificationService.subscribeToInserts()` in Flutter attach Realtime listeners to `routines`/`notifications` that receive **zero live change deltas** after initial fetch — React Web intentionally avoids false Realtime subscriptions and uses TanStack Query invalidation + explicit Refresh.

```mermaid
flowchart LR
    subgraph TeacherMobile ["Flutter Mobile (Teacher)"]
        TCancel["ManageClassesController<br/>cancelClassWithOutcome()"]
    end

    subgraph SupabaseDB ["Supabase Postgres + Realtime"]
        RoutinesTbl[("public.routines<br/>(is_active = true,<br/>includes is_service = true)")]
        CancelTbl[("public.cancellations<br/>UNIQUE (routine_id, class_date)")]
        NotifTbl[("public.notifications<br/>type = 'class_cancel'")]
        RealtimePub[["supabase_realtime<br/>(cancellations ONLY)"]]
    end

    subgraph StudentMobile ["Flutter Mobile (Student / Campus Lookup)"]
        RoutSvc["RoutineService (_fetchActive paged 250)<br/>matchesStudent: section.split('+')<br/>matchesTeacher: teacherCodes"]
        Lookup["TeacherLocationService & RoomStatusService<br/>Derive live occupancy ONLY from public.routines"]
        CancelBadge["Date-Scoped Cancellation Key<br/>'${routine_id}|YYYY-MM-DD'"]
    end

    TCancel -->|"Step 1: INSERT"| CancelTbl
    TCancel -->|"Step 2: INSERT (partial-fail safe)"| NotifTbl
    CancelTbl --> RealtimePub --> CancelBadge
    RoutinesTbl -->|"SELECT (RLS: authenticated true)"| RoutSvc
    RoutinesTbl -->|"SELECT (zero profiles/timetable_* reads!)"| Lookup
    CancelTbl -->|"SELECT class_date >= today"| CancelBadge
```

### Flow 3: Track 1 Routine Generation, 20-Counter Validation & 3-Step Guarded Publication

```mermaid
sequenceDiagram
    autonumber
    participant Web as React Web Admin<br/>(/admin/routine?tab=generate)
    participant Supa as Supabase Postgres + Storage<br/>(Config Tables, timetables bucket, publish_routine)
    participant Engine as Render FastAPI Engine<br/>(main.py + auth.py + solver.py + render.py)
    participant Mobile as Flutter Mobile<br/>(RoutineEntry.fromMap)

    Web->>Supa: Parallel SELECT timetable_rooms, timetable_faculty,<br/>timetable_course_eligibility, timetable_settings (id=1)
    Web->>Web: assembleEngineConfigFromRecords() (HH:MM clocks, zero non-DB keys)<br/>+ Studio OOXML .xlsx builder OR external .xlsx file
    Web->>Engine: POST /api/timetable/generate (Bearer JWT, file, config, time_limit_s=180)
    Engine-->>Web: 200 { job_id }
    loop Every 2s (max 240 polls; +4s backoff on 429; fast-fail on 404/401/403)
        Web->>Engine: GET /api/timetable/status/{job_id}
    end
    Web->>Engine: GET /api/timetable/result/{job_id}
    Engine-->>Web: rows + service_rows + stats + 20-counter validation + report
    Web->>Web: Pre-Publish Guards:<br/>1) blockingValidationErrorFor (all 20 counters == 0 & ok == true)<br/>2) findCoTeacherBlockers (teachers.length <= 1)<br/>3) assessBaselineConfigForPublish (activeRooms>0, activeFaculty>0, hasSettings)
    Web->>Engine: GET /api/timetable/download/{job_id} (.xlsx Blob)
    Web->>Supa: Step 1: Storage upload -> timetables/CSE_Routine_<label>_<ts>.xlsx
    Web->>Supa: Step 2: RPC publish_routine(p_rows: rows + service_rows with HH:MM:SS)<br/>(Atomic tx: routine_versions + DELETE routines WHERE true + bulk INSERT)
    Web->>Supa: Step 3 (Best-effort + retryable): INSERT timetable_runs (status='published')<br/>+ optional INSERT notifications (type='university')
    Mobile->>Supa: SELECT routines WHERE is_active = true -> RoutineEntry.fromMap()
```

### Flow 4: Track 2 Course Distribution Revision, Audited Correction (`40001`) & Gates A–D

```mermaid
flowchart TD
    Probe["probeLiveSchedulingCapabilities()<br/>Parallel RLS-protected SELECT .limit(1) on 4 Track 2 tables<br/>(NO GET /rest/v1/ OpenAPI root; NO nil-UUID RPC calls)"]
    Probe -->|"Tables missing (Prod pre-4A-1)"| AllLocked["Gates A, B, C, D = LOCKED<br/>(Zero 500s, zero fixture leakage)"]
    Probe -->|"37-table Track 2 live (Staging)"| GateAB["Gate A & Gate B = UNLOCKED"]
    GateAB --> ReadRPC["Gate A: read_course_distribution_revision(target_revision)<br/>Checks status='accepted' + can_scope('read_catalog')<br/>Returns base64 immutable bytes + SHA-256 + corrections[]"]
    GateAB --> AppendRPC["Gate B: append_course_distribution_correction(8 params)<br/>Checks can_scope('edit_draft') + expected_revision_version<br/>SQLSTATE 40001 on stale version -> increments revision_version<br/>Trigger marks course_distribution_artifacts = 'stale'"]
    GateAB --> GateCD["Gate C (PolicySnapshot & Validation Artifact)<br/>& Gate D (Durable Solve & Archiving publish_routine)<br/>UNCONDITIONALLY FAIL-CLOSED until Wave 2 Phase 4A-2"]
```

> **Note on Resolved Staging Discrepancy (`Test 3` in `2026-11-23` Report vs. Current Working Tree) `[VERIFIED: Repo Source]`:** On 2026-11-23, `web_phase_5_staging_verification_and_ci_fix.md` §3 recorded `Gate A` and `Gate B` showing `Locked` on Staging because `probeRpcPathsViaOpenApi` called `GET /rest/v1/`, which returned `401` on publishable keys. Current uncommitted `apps/web/src/features/scheduling/services/schedulingCapabilities.ts:111-199` in the working tree **has already eliminated `GET /rest/v1/`**, probing the 4 atomic Track 2 tables (`course_distribution_revisions`, `sources`, `corrections`, `artifacts`) via standard RLS-protected PostgREST `SELECT .limit(1)` queries so Gates A & B unlock cleanly on Staging with zero `401`/`500` errors.

### Flow 5: Resource Storage Upload & Campus Broadcast Flow

```mermaid
sequenceDiagram
    autonumber
    participant Staff as Admin (React Web /admin/resources)<br/>or Teacher (Flutter Mobile)
    participant Storage as Supabase Storage<br/>(Bucket: resources)
    participant DB as Supabase Postgres<br/>(public.resources / notifications)
    participant Student as Student (Flutter Mobile)

    Staff->>Storage: Upload file to "${semester}/${epochMs}_${sanitizedFilename}"<br/>(Phase 5B RLS: my_role() IN ('teacher','admin'))
    Storage-->>Staff: Public URL (/storage/v1/object/public/resources/...)
    Staff->>DB: INSERT INTO public.resources<br/>(title, category IN ['PYQ','Notes','Slides','Assignments'], semester 1..8, subject_code, file_url/drive_link, uploaded_by)
    Student->>DB: SELECT FROM public.resources WHERE semester = X
    Student->>Storage: HTTPS GET public file_url (or external https:// drive_link)
    Note over Staff,Storage: On Delete (React Web deleteResourceWithCleanup):<br/>1) DELETE FROM public.resources -> 2) storage.from('resources').remove([path])<br/>Surfaces non-blocking storageWarning if Step 2 fails.
```

---

## 2. Complete CI/CD & Deployment Infrastructure Map

### 2.1 GitHub Actions Workflows (`.github/workflows/`)

`[VERIFIED: Repo Source]` (`.github/workflows/validate.yml`, `.github/workflows/supabase_keep_alive.yml`)

#### A. `.github/workflows/validate.yml` — 5 Parallel Verification Jobs
Triggers: `pull_request`, `push` to `branches: [main]`, `workflow_dispatch`. Uses **zero repository secrets or hosted credentials** (`permissions: contents: read`).

| # | Job ID | Runner / Toolchain | Exact Checks Executed |
| :--- | :--- | :--- | :--- |
| 1 | `academic-domain` | `ubuntu-latest`, Python `3.12` (`timeout: 10m`) | Installs `engine/requirements.txt` + `pytest` + `httpx`; runs `pytest` on `test_domain.py`, `test_normalized_domain.py`, `test_legacy_mapping.py`, and Phase 5A `test_api_auth_and_cors.py`. *(Note: full 230-test CP-SAT solver suite is run locally before push, not all files in this fast job.)* |
| 2 | `tools-and-functions` | `ubuntu-latest`, Python `3.12` + Deno `v2.5.6` (`timeout: 10m`) | Runs `python -m unittest discover -s tool/tests -v`, `deno test supabase/functions/send-push/{webhook_auth_test.js,audience_test.js}`, and `deno test supabase/functions/invite-admin/{callback_policy_test.js,handler_test.js}`. |
| 3 | `local-database` | `ubuntu-latest`, Python `3.12` + isolated `supabase/setup-cli@v1` (`2.121.0`) (`timeout: 30m`) | Runs `python tool/task1_local_checks.py --task2` against an ephemeral local Docker stack (two fresh public-schema resets + 44 pgTAP baseline assertions + 795-row sanitized restore + `20261022140809` Task 2 catalog checks). *(CI-only ephemeral container; developers never use Supabase CLI).* |
| 4 | `web-validate` | `ubuntu-latest`, Node `22` (`timeout: 15m`) | `npm --prefix apps/web ci` → `npm run typecheck` → `npm test` (17 Vitest suites / 157 tests including 83 WCAG AA contrast pairs) → `npm run build` with placeholder non-secret env vars (`VITE_ENABLE_SCHEDULING_PREVIEW_ROUTE="false"`). |
| 5 | `flutter-validate` | `ubuntu-latest`, Flutter `3.47.0` stable (`timeout: 20m`) | `flutter pub get` → `flutter analyze` → `flutter test --exclude-tags visual_capture` (384 passing unit/widget tests). |

#### B. `.github/workflows/supabase_keep_alive.yml` — Scheduled Free-Tier Ping (With Newly Identified Drift)
- **Schedule:** Cron `'0 0 */3 * *'` (every 3 days at 00:00 UTC) + `workflow_dispatch`.
- **Action:** Runs `curl -s -X GET "${SUPABASE_URL}/rest/v1/"` with `apikey` and `Authorization: Bearer <REDACTED_PROD_ANON_JWT>` against Production `https://yxqyrjyzxitrgkhgauli.supabase.co`.
- **Newly Discovered Findings `[VERIFIED: Repo Source]`:**
  1. **Hardcoded Legacy Anon JWT:** Line 20 hardcodes the Production `anon` JWT directly in YAML rather than reading `${{ secrets.SUPABASE_ANON_KEY }}`.
  2. **OpenAPI Root `401` Behavior & Silent Failure:** `curl -s` without `-f` always exits `0` even on `401`/`5xx` (and newer Supabase PostgREST configs return `401` on `GET /rest/v1/` with anon keys, though an inbound HTTP request to Kong still registers project activity).
  3. **Staging Not Pinged:** Secondary Staging (`oqwvxplteqtlrhktsplj`) is **not** included in `supabase_keep_alive.yml` and can pause after 7 days of inactivity during quiet review periods unless added or manually resumed.

### 2.2 Render FastAPI Deployment & Shared-Service Constraint

`[VERIFIED: Repo Source]` (`render.yaml`, `docs/deployment/CLOUDFLARE_PAGES_AND_CUTOVER_RUNBOOK.md:48-60`)

- **Service Blueprint (`render.yaml`):** Web service `universe-timetable-engine`, `runtime: python` (`PYTHON_VERSION=3.12.7`), `rootDir: engine`, `plan: free` (`512 MB` RAM), `buildCommand: pip install -r requirements.txt`, `startCommand: uvicorn main:app --host 0.0.0.0 --port $PORT`, `healthCheckPath: /`, `SOLVER_WORKERS="2"`.
- **Shared Render Service Constraint:** Because a single Render instance (`https://universe-timetable-engine.onrender.com`) currently serves **both** Environment A Staging (`oqwvxplteqtlrhktsplj`) and Production Flutter (`yxqyrjyzxitrgkhgauli`), **`ENGINE_AUTH_MODE` MUST remain `optional`** (while setting strict `ALLOWED_ORIGINS` for browser CORS) until either a second staging Render service is provisioned or Environment B cuts over to Production (`SUPABASE_URL=https://yxqyrjyzxitrgkhgauli.supabase.co` + `ENGINE_AUTH_MODE=enforced`).

### 2.3 Cloudflare Pages Static Architecture (`apps/web/public/`)

`[VERIFIED: Repo Source]` (`apps/web/public/_redirects`, `apps/web/public/_headers`, `apps/web/public/theme-init.js`, `docs/deployment/CLOUDFLARE_PAGES_AND_CUTOVER_RUNBOOK.md`)

- **Build Contract:** Root `apps/web`, command `npm run build`, output `dist`, `NODE_VERSION=22`.
- **SPA Routing (`_redirects`):** `/* /index.html 200`.
- **Zero-Inline-Script Theme Init (`theme-init.js`):** External pre-paint IIFE reading `localStorage.getItem("universe-web-theme")` + `prefers-color-scheme: dark` and stamping `document.documentElement.dataset.theme = "dark" | "light"` before first paint so `script-src 'self'` needs **zero `'unsafe-inline'`**.
- **Security Headers & CSP (`_headers`):**
  - `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`, `Permissions-Policy: camera=(), microphone=(), geolocation=()`, `Strict-Transport-Security: max-age=31536000; includeSubDomains`.
  - `Content-Security-Policy`: `default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com; img-src 'self' data: blob: https:; connect-src 'self' https://*.supabase.co wss://*.supabase.co https://universe-timetable-engine.onrender.com; frame-ancestors 'none'; base-uri 'self'; form-action 'self'`. *(Note: if a separate Staging Render hostname is ever created, add its origin to `connect-src` in `_headers`!)*
  - Caching: `/assets/*` → `public, max-age=31536000, immutable`; `/index.html` → `no-cache`.

### 2.4 Environment Variable Matrix Across Hosts (Names & Sources Only — Zero Secrets)

| Host / Service | Variable Name | Environment A (Staging Review) | Environment B (Production Cutover) | Secret? |
| :--- | :--- | :--- | :--- | :--- |
| **Cloudflare Pages** (`apps/web`) | `NODE_VERSION` | `22` | `22` | No |
| **Cloudflare Pages** | `VITE_SUPABASE_URL` | `https://oqwvxplteqtlrhktsplj.supabase.co` | `https://yxqyrjyzxitrgkhgauli.supabase.co` | No |
| **Cloudflare Pages** | `VITE_SUPABASE_ANON_KEY` | `<REDACTED>` *(Staging publishable/anon key)* | `<REDACTED>` *(Prod publishable/anon key)* | Publishable |
| **Cloudflare Pages** | `VITE_TIMETABLE_BASE_URL` | `https://universe-timetable-engine.onrender.com` | `https://universe-timetable-engine.onrender.com` | No |
| **Cloudflare Pages** | `VITE_ENABLE_SCHEDULING_PREVIEW_ROUTE` | `false` | `false` | No |
| **Render** (`engine/`) | `PYTHON_VERSION` / `SOLVER_WORKERS` | `3.12.7` / `"2"` | `3.12.7` / `"2"` | No |
| **Render** (`engine/`) | `ENGINE_AUTH_MODE` | `optional` *(shared Render)* | `enforced` | No |
| **Render** (`engine/`) | `ALLOWED_ORIGINS` | `https://<review>.pages.dev,http://localhost:5173,http://127.0.0.1:5173` | `https://<prod-domain>,https://<review>.pages.dev` | No |
| **Render** (`engine/`) | `SUPABASE_URL` | `https://oqwvxplteqtlrhktsplj.supabase.co` | `https://yxqyrjyzxitrgkhgauli.supabase.co` | No |
| **Render** (`engine/`) | `SUPABASE_ANON_KEY` | `<REDACTED>` | `<REDACTED>` | Publishable |
| **Render** (`engine/`) | `SUPABASE_SERVICE_ROLE_KEY` | `<REDACTED>` | `<REDACTED>` | **SECRET** |
| **Supabase Edge** (`invite-admin`) | `AUTH_WEB_CALLBACK_URLS` | `https://<review>.pages.dev/,http://localhost:5173/` | `https://<prod-domain>/` | Config |
| **Supabase Edge** (`send-push`) | `PUSH_WEBHOOK_SECRET` | *(Not deployed on Staging)* | `<REDACTED>` *(matches DB webhook `x-webhook-secret`)* | **SECRET** |
| **Supabase Edge** (`send-push`) | `FCM_SERVICE_ACCOUNT` | *(Not deployed on Staging)* | `<REDACTED>` *(Firebase SA JSON)* | **SECRET** |
| **Flutter Mobile** (`--dart-define`) | `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `TIMETABLE_BASE_URL`, `GOOGLE_WEB_CLIENT_ID`, `GEMINI_API_KEY` | Defaults in `AppConstants` point to Prod (`yxqyrjyzxitrgkhgauli`) + Render | Override via `--dart-define` for non-default builds (`GEMINI_API_KEY` for AI RAG) | Mixed |

---

## 3. Wave 2 Backend Change Impact Matrix

`[VERIFIED: Repo Source]` (`docs/deployment/PHASE_4A1_AND_5B_SQL_PROMOTION_RUNBOOK.md`, `AGENTS.md`, `apps/web/src/features/scheduling/`, `lib/core/models/routine_model.dart`, `engine/solver.py`)

Use this matrix before modifying any SQL migration, FastAPI endpoint, or client contract in Wave 2 so **zero mobile regressions** or unbacked UI states are introduced:

| Planned Wave 2 Change | Supabase SQL / RLS / Edge Changes | FastAPI Engine (`engine/`) Changes | Flutter Mobile (`lib/` Android & iOS) Impact | React Web (`apps/web/`) Updates |
| :--- | :--- | :--- | :--- | :--- |
| **1. Phase 4A-1 Prod SQL Promotion** (`20261022140809` + `20261106130000`) | Run Steps A & B of `PHASE_4A1_AND_5B_SQL_PROMOTION_RUNBOOK.md` on `yxqyrjyzxitrgkhgauli`: adds 19 tables (`18 -> 37`), `academic_private`, nullable FK cols on `profiles`/`routines`/`timetable_rooms`/`timetable_faculty`, and Gates A–B RPCs. | None (`distribution.py` already supports `source_contract`). | **Zero Breaking Impact:** All 12 new columns on `profiles`, `routines`, `timetable_rooms`, `timetable_faculty` are nullable/defaulted; `RoutineEntry.fromMap` already parses optional `scheduling_scope_id`, `cohort_id`, `student_group_id`, `faculty_id`, `room_id`. | `probeLiveSchedulingCapabilities()` automatically unlocks **Gate A** and **Gate B** on Production once `VITE_ENABLE_SCHEDULING_PREVIEW_ROUTE` / Track 2 live workflow is enabled. |
| **2. Phase 5B Prod RLS & Storage Hardening** (`20261122160000`) | Run Step C + rollback-safe `phase_5b_rls_hardening_verification.sql` on `yxqyrjyzxitrgkhgauli`: sets `search_path = ''`, restricts `profiles_select` to own/admin, restricts `timetable_*` `SELECT` to `is_admin()`, revokes `anon`, replaces wildcard `storage_auth_*` with bucket-scoped policies. | `engine/auth.py` uses `SUPABASE_SERVICE_ROLE_KEY` (or caller's own token for `id=eq.<uid>`), which passes `profiles_select` (`id = auth.uid()`). | **Verified Safe (`F-13`, `F-29`, `F-30`):** Student/Teacher screens read only own `profiles` row and `public.routines` (never `timetable_*` or `avatars` bucket). `send-push` uses `service_role` and bypasses RLS. | Already verified E2E on Staging (`2026-11-23` Tests 1–4). |
| **3. Gate C — Policy Snapshot, Extended Catalogs & Server Validation Artifact** (`Phase 4A-2`) | Add migration + RPCs for `CatalogCourse`, `CohortBatch`/section weekend overrides, `PolicySnapshot` (`R1`–`R16` typed settings + faculty/room slot windows + `employment_type` + `is_sust_adjunct`), and persisted `validation_report` rows in `course_distribution_artifacts`. Enforce `SET search_path = ''` and `academic_private.can_scope(..., 'manage_policy')`. | Wire `engine/domain.py` (`PolicySnapshot`, `ValidationReport`, `NormalizedInput`) into `main.py` / `solver.py`; expose standalone preflight/validation endpoint or RPC integration. | **Zero Mobile Impact:** Students and Teachers never read `PolicySnapshot` or catalog config tables. | Unlock **Gate C** in `schedulingCapabilities.ts`; replace read-only `staged-no-db` banners on `/admin/timetable/courses`, `/admin/timetable/batches`, and `PolicyStudioStage.tsx` with live TanStack Query mutations. |
| **4. R1–R16 + D1–D6 CP-SAT Solver Extensions** (`Phase 4A-2`) | Consumes Gate C schema (`employment_type`, `is_sust_adjunct`, faculty `external_busy_slots` / `available_slots` / `preferred_slots`, room `declared_windows`, explicit Physics lab codes, `allow_sessional_across_break`). | Extend `ingest.py` & `solver.py`: implement R1/R2 section weekends & batch spread `<=1`, R3 section gap `<2`, R4/R5 slot domains, R6/R7 permanent vs adjunct distinct-course bands, R8/R9 preferences & SUST rules, R10/R11 room-window & Physics pins, R12/R13 credit-based blocks & coupled room assignment, drop `solver.py:136` digit filter (R14), and emit structured `D6` outcomes (`OPTIMAL`, `FEASIBLE`, `INFEASIBLE`, `TIME_LIMIT_EXHAUSTED`, `UNKNOWN`, `INPUT_ERROR`). | **Zero Mobile Impact** as long as output rows preserve `day`, `time_start` (`HH:MM:SS`), `time_end`, `subject`, `subject_code`, `room`, `batch`, `section` (`+` for joint), `semester`, `is_active`, `is_service`. | Update `EngineResultSchema` / `ValidationGate` and `RevisionSolveStage` / `GenerateRoutineTab` conflict inspector to render structured `D6` hard violations vs. soft preference misses. |
| **5. Gate D — Durable Solver Jobs, Co-Teacher Storage & Archiving `publish_routine()`** (`Phase 4A-2`) | 1) Add durable `solver_jobs` table.<br/>2) Add `teacher_codes text[] NOT NULL DEFAULT '{}'` to `public.routines`.<br/>3) Upgrade `publish_routine()` to archive prior `routines` snapshot on `routine_versions`, scope deletes by `scheduling_scope_id`, verify fresh `validation_report` server-side, and write `teacher_codes`. | Replace volatile in-memory `JOBS: dict` in `engine/main.py` with Supabase-persisted job state + Storage `.xlsx` persistence so Render restarts never `404`. | **Mobile Compatibility Check:** `RoutineEntry.fromMap` (`routine_model.dart:114`) **already** reads `map['teacher_codes']` into `coTeacherCodes` and `matchesTeacher` checks `teacherCodes`! Verify `TeacherLocationService.fetchUniqueTeachers()` (`teacher_location_service.dart:20-37`) is updated to also index `teacher_codes` so co-teachers appear in Find Teacher directory. *(Also expand `B+C` joint-section matching in `send-push/audience.js` & `NotificationItem.matchesAudience`.)* | Unlock **Gate D** in `schedulingCapabilities.ts`; remove `findCoTeacherBlockers` pre-publish throw once `routines.teacher_codes` is live; wire version diff & one-click rollback in `ManagePublishedTab` / `ReviewDiffPublishStage`. |
| **6. Phase 3B — Server-Side Rendered `.xlsx` Parse Endpoint** | None (reuses existing `publish_routine` + `timetables` bucket). | Add `POST /api/timetable/parse-rendered` (`Depends(auth.require_admin_caller)`) in `engine/main.py` + new parser module achieving fixture-verified equivalence with `RoutineWorkbookParser` (`7` day sheets + tabular sheets + `ClockTime` sequence repair + 20-counter `_validate`). | Unblocks post-cutover retirement/pruning of frozen Flutter Web (`web/`, `lib/features/admin/`). Mobile Student/Teacher app unaffected. | Replace `UploadRoutineGatedTab.tsx` (`/admin/routine?tab=upload`) with live drag-and-drop upload → FastAPI parse preview → 20-counter validation → 3-step `publishRoutinePipeline`. |
