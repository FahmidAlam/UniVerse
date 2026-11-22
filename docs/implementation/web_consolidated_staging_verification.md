# UniVerse React Web v1 — Consolidated Live Staging End-to-End Verification Report

**Date:** 2026-11-22  
**Target Environment:** Staging Supabase **`oqwvxplteqtlrhktsplj`** (`ap-south-1`, Postgres 17, `ACTIVE_HEALTHY`) + Live Render FastAPI Engine (`https://universe-timetable-engine.onrender.com`) + Local Vite Dev Server (`http://localhost:5173`)  
**Production Safety:** Production Supabase **`yxqyrjyzxitrgkhgauli`** was **NEVER** queried, connected to `.env.local`, or modified.  
**Verification-Only Compliance:** Zero edits made to `apps/web/src/`, `apps/web/package.json`, `lib/`, `android/`, `ios/`, `test/`, `engine/`, or `supabase/`.

---

## 1. Executive Pass / Fail Scorecard (Suites 1–5)

| Suite | Scope | Verdict | Key Evidence / Notes |
|---|---|---|---|
| **Pre-Flight** | `.env.local` + `oqwvxplteqtlrhktsplj` baseline + dev server | **PASS** | `.env.local` gitignored (`apps/web/.gitignore:6`), points strictly to `oqwvxplteqtlrhktsplj` & Render; `VITE_ENABLE_SCHEDULING_PREVIEW_ROUTE=false`. Staging baseline confirmed `ACTIVE_HEALTHY` (`1` profile, `2` whitelists, `0` rows across all timetable/comms/distribution tables). |
| **Suite 1** | Public Landing, Auth & Dashboard Reload (Sub-Phase 1B) | **PARTIAL PASS** *(1st-login `409` skipped by owner choice)* | `/` returned HTTP `200`, `0` Supabase/Render calls, `0` console errors, no horizontal overflow at `1440×900`. `/admin/dashboard` unauthenticated redirected cleanly to `/login`. Owner signed in as existing `test-demo@user.com` rather than creating `stage-admin-test@example.com`, so **fresh 1st-login `409` provisioning was not exercised**. Reload on `/admin/dashboard` persisted session cleanly (`200`), `0` dev-preview banner, `EngineHealthBadge` showed `Engine v2.0.0 · 300 ms` (`GET /` -> `200`). |
| **Suite 2** | Phase 2 Live CRUD (8 Live Screens + 2 Staged) | **PASS** *(expected `404` on un-deployed `invite-admin`)* | All 8 live screens persisted & reloaded cleanly against `oqwvxplteqtlrhktsplj` (`200`/`201`/`204`), zero Phase A column errors, zero `avatars` Storage calls, and both staged catalog routes remained fail-closed (`staged-no-db`). |
| **Suite 3** | Phase 3 Live Track 1 (`routines` CRUD, 2D Matrix, Live FastAPI + Publish) | **FAIL (Blocked at 3.3 Result Schema)** | **3.1** (`routines` CRUD + Teacher/Room/Cohort clash detection + `HH:MM:SS` DB persistence), **3.2** (2D Matrix across Section/Faculty/Room lenses, Matrix↔List, Friday P4 lock, `360px` inspector), and **3.4** (`?tab=upload` `Gated · Phase 3B`) **PASSED**. **3.3** submitted `POST /api/timetable/generate` (`200`, `963 ms`, job `0e3e83be2545`), polled 9× `200 OK` over `00:22`, and fetched `GET /api/timetable/result/0e3e83be2545` (`200 OK`), where **`EngineResultSchema` failed** (`Invalid input: expected object, received undefined` due to missing `source_contract`), **blocking Candidate Preview, UI `.xlsx` download, and the 3-Step Guarded Publication Pipeline**. |
| **Suite 4** | Phase 4B Live Track 2 Capability Probe (`/admin/scheduling`) | **PASS WITH DEFECT** | Live Mode showed `Gate A: Verified`, `Gate B: Verified`, `Gate C: Locked`, `Gate D: Locked`, zero fixture leakage, and zero unhandled JS console errors; Design Preview Stages 1–5 fired `0` remote requests. **Defect:** `probeLiveSchedulingCapabilities()`'s nil-UUID probes triggered two HTTP `500` responses from PostgREST (`P0002`). |
| **Suite 5** | Flutter Android/iOS Deserialization Parity & Staging Hygiene | **PASS** *(with Publish-path caveat)* | React-authored staging rows in `public.routines` (manual CRUD), `public.notifications`, and `public.resources` match Flutter `fromMap` & `matchesAudience` contracts 100%. Temporary `.xlsx` cleaned up; `git status --short` shows zero modified code files. |

---

## 2. Severity-Ranked Bugs & Edge Cases Discovered

### CRITICAL — #1: Live FastAPI `/api/timetable/result/{job_id}` Missing `source_contract` Breaks `EngineResultSchema`
- **Area:** Suite 3.3 — [`apps/web/src/features/routine/services/timetableEngineService.ts`](apps/web/src/features/routine/services/timetableEngineService.ts#L95-L123) vs. live Render `https://universe-timetable-engine.onrender.com/api/timetable/result/{job_id}`
- **Observed Symptom:** After `POST /api/timetable/generate` (`200 OK`, job `0e3e83be2545`) and 9 status polls (`200 OK` over `22s`), `GET /api/timetable/result/0e3e83be2545` returned **`200 OK`**, but the UI aborted with:
  > **Timetable generation interrupted**  
  > `Generated timetable response schema mismatch: Invalid input: expected object, received undefined`
- **Exact Payload Evidence:** Direct inspection of `GET https://universe-timetable-engine.onrender.com/api/timetable/result/0e3e83be2545` returned top-level keys:
  `['job_id', 'rows', 'service_rows', 'stats', 'validation', 'report', 'has_workbook']`  
  with `stats.status = 'OPTIMAL'`, `solve_ms = 120`, `meetings = 4`, `validation.ok = True`, and `has_workbook = True`.
- **Root Cause:** `EngineResultSchema` (`timetableEngineService.ts:105-111`) declares `source_contract` as a **required** object (`z.object({ source_sha256: z.string(), revision: z.number(), ... }).passthrough()`), whereas the live Render `engine/server.py` deployment does not include `source_contract` in `/api/timetable/result/{job_id}` (Track 1 uploads omit a `course_distribution_revisions` contract).
- **Impact:** Completely blocks Candidate Preview, 20-counter Validation Ledger rendering, UI `.xlsx` Download, and the 3-Step Guarded Publication Pipeline against the live Render engine.
- **Recommended Fix:** Make `source_contract` `.optional()` in `EngineResultSchema` (and handle `result.source_contract ?? null` gracefully for Track 1 ad-hoc `.xlsx` runs while keeping it strict when Track 2 revision contracts are active).

### MEDIUM — #2: `probeLiveSchedulingCapabilities()` Nil-UUID RPC Probes Emit Two HTTP `500`s on `/admin/scheduling`
- **Area:** Suite 4 — [`apps/web/src/features/scheduling/services/schedulingCapabilities.ts`](apps/web/src/features/scheduling/services/schedulingCapabilities.ts#L143-L168)
- **Observed Symptom:** Loading `/admin/scheduling` in Live Backend mode fired:
  - `POST .../rest/v1/rpc/read_course_distribution_revision` -> **HTTP `500`**
  - `POST .../rest/v1/rpc/append_course_distribution_correction` -> **HTTP `500`**
  Even though `Gate A` and `Gate B` still evaluated to `Verified` (because `isMissingFunctionOrSchemaError()` only treats `PGRST202`/`42883`/`42P01`/`42703` as missing) and no JS console error was thrown, Chrome DevTools Network logs two red `500` errors on every `/admin/scheduling` visit.
- **Root Cause:** Both Postgres functions (`public.read_course_distribution_revision` and `public.append_course_distribution_correction`) raise custom PL/pgSQL `ERRCODE 'P0002'` (`Unknown course distribution revision`) when probed with `nilUuid = "00000000-0000-0000-0000-000000000000"`, which PostgREST surfaces as HTTP `500` (or `400`/`500` depending on error mapping).
- **Recommended Fix:** Probe RPC availability without triggering `P0002` exceptions (e.g., pass an existing `revision_id` for `read_course_distribution_revision` when present, or verify RPC existence via PostgREST OpenAPI / `HEAD` / lightweight read-only capability check).

### INFO / EXPECTED — #3: `invite-admin` Edge Function Not Deployed on Staging (`OPTIONS` -> `404`)
- **Area:** Suite 2.6 — `/admin/users` (`Invite Administrator` modal)
- **Observed Symptom:** Submitting `Invite Administrator` triggered `OPTIONS https://oqwvxplteqtlrhktsplj.supabase.co/functions/v1/invite-admin` -> **HTTP `404`** (`CORS PreflightInvalidStatus`), and the UI cleanly surfaced `"Failed to send a request to the Edge Function"` without faking success.
- **Status:** Expected on `oqwvxplteqtlrhktsplj` (Edge Function not deployed there); error-handling behavior **PASSED**.

### INFO / AUTOMATION NOTE — #4: Row-Level Whitelist Delete vs. Bulk Delete (`ManageUsersPage.tsx`)
- **Area:** Suite 2.6 — `/admin/users`
- **Observed Symptom:** Clicking the row-level `Delete whitelist` button opened the `ConfirmDialog`, where the automated browser step did not trigger `DELETE`, whereas selecting the checkbox and using bulk **Remove Selected** -> **Remove Entries** fired `DELETE .../rest/v1/whitelists?email=in.(...)` -> `204` cleanly. Code inspection of [`ManageUsersPage.tsx`](apps/web/src/features/admin/pages/ManageUsersPage.tsx#L1199-L1215) confirms both paths share the exact same `ConfirmDialog` (`confirmLabel="Remove Entries"`), so this appears to be an automation modal-click miss rather than a confirmed app bug (worth a quick manual spot-check during the fix pass).

---

## 3. Live Verification of R15 + Online Slot (`idx: 8, Col L`) on Render FastAPI

Despite the client-side `EngineResultSchema` rejection on `source_contract`, direct inspection of the live Render job **`0e3e83be2545`** (submitted with `7-Slot Grid` `P1–P7` `idx: 1..7` cols `D..K` + `allow_online_periods: true`, `online_periods: [8]`, `idx: 8` col `L` `19:00-20:20`, `friday_no_p4: true`) confirms:
1. **`engine/solver.py`:** Accepted the `idx: 8, col: "L"` configuration cleanly and returned `status: "OPTIMAL"` in `120 ms` (`meetings: 4`, `offerings: 2`, `cohorts: 2`, `teachers: 2`, `validation.ok: True`).
2. **`engine/render.py`:** Verified via `GET https://universe-timetable-engine.onrender.com/api/timetable/download/0e3e83be2545` -> **HTTP `200 OK`**, `Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`, `322,621` bytes, valid `PK` zip header.

---

## 4. Detailed Suite Evidence (HTTP Statuses & DB Persistence on `oqwvxplteqtlrhktsplj`)

- **Suite 2.1 Rooms (`/admin/timetable/rooms`):**
  - `POST .../rest/v1/timetable_rooms?select=id,name,building,is_lab,is_gallery,capacity,is_active,dept` -> `201` (3×: `RAB-301`, `ACL-1`, `GAL-1`).
  - `PATCH .../rest/v1/timetable_rooms?id=eq....` -> `200` (`RAB-301` capacity `60 -> 64`, persisted across reload).
  - Bulk Activate/Deactivate `GAL-1` -> `PATCH .../rest/v1/timetable_rooms?id=in.(...)` -> `204` (`2` active, `1` inactive).
- **Suite 2.2 Faculty (`/admin/timetable/faculty`):**
  - `POST .../rest/v1/timetable_faculty?select=id,acronym,full_name,dept,designation,off_days,is_active,courses` -> `201` (`TFA`, `TFB`).
  - R7 Off-Day Advisory verified in-form, in filter chip (`R7 Off-Day Advisory (1)`), and in row badge (`Fri · R7 Advisory (1)`) for `TFB` (`['Friday']`).
  - `PATCH .../rest/v1/timetable_faculty?id=eq....` -> `200` (`TFB` courses `['CSE-1102']`, persisted across reload).
- **Suite 2.3 Course Eligibility (`/admin/timetable/course-eligibility`):**
  - `POST .../rest/v1/timetable_course_eligibility?on_conflict=acronym%2Ccourse_code&select=...` -> `201` (`TFA -> CSE-1101`, `TFB -> CSE-1102`).
  - Duplicate upsert (`TFA -> CSE-1101` priority `2` then `1`) -> `200` (merged cleanly, zero duplicate rows).
- **Suite 2.4 Timetable Settings (`/admin/timetable/settings`):**
  - `POST .../rest/v1/timetable_settings?on_conflict=id` -> `201` (`id = 1`, `semester_label = 'Staging Test 2026'`, `allow_online_periods = true`, `online_periods = [8]`, `periods` `idx 1..8`, `friday_no_p4 = true`). Hydrated all 3 tabs on reload (`200`).
- **Suite 2.5 Dashboard (`/admin/dashboard`):**
  - Refresh showed `3 of 4 stages configured` (`Rooms: 3`, `Faculty: 2`, `Eligibility: 2`, `Active Routine: 0`); Recharts v3 bar chart rendered live SVG bars (`Theory: 1 active`, `Labs: 1 active`, `Galleries: 1 inactive`).
- **Suite 2.6 Users & Whitelist (`/admin/users`):**
  - Self-demotion blocked on `test-demo@user.com`; `stage-teacher@example.com` added (`201`) and removed (`204`); `invite-admin` failed honestly (`404`).
- **Suite 2.7 Campus Broadcast (`/admin/broadcast`):**
  - Created `Staging Interop Test` (`201`) and `Staging Delete Check` (`201`), deleted `Staging Delete Check` (`204`).
- **Suite 2.8 Academic Resources (`/admin/resources`):**
  - Created `Staging External Link` (`201`); uploaded `staging_resource_test.txt` to Storage `resources/1/<epoch>_staging_resource_test.txt` (`200`) + DB insert (`201`), then deleted Storage object (`200`) + DB row (`204`).
- **Suite 2.9 Admin Profile (`/admin/profile`):**
  - `PATCH .../rest/v1/profiles?id=eq.78322eda-17b5-4c4d-99be-e39c130b4312&select=*` -> `200` (`Staging Admin Lead`, `Routine Coordinator`), persisted on reload, `0` requests to `avatars` bucket.
- **Suite 2.10 Staged Catalog Routes:** `/admin/timetable/courses` & `/admin/timetable/batches` -> `Staged · No DB`, `0` writable controls, `0` errors.

---

## 5. Flutter Mobile (Android & iOS) Deserialization Parity Check

Verified live Postgres rows in `oqwvxplteqtlrhktsplj` against Flutter's model deserializers:

| Table | Flutter Model / Method | Verified Live Staging Row Values | Verdict |
|---|---|---|---|
| `public.routines` | `RoutineEntry.fromMap` ([`routine_model.dart`](lib/core/models/routine_model.dart#L97-L124)) | `day: "Sunday"`, `time_start: "08:50:00"`, `time_end: "10:05:00"`, `subject_code: "CSE-1101"`, `teacher_code: "TFA"`, `teacher_name: null`, `room: "RAB-301"`, `batch: "58"`, `section: "B+C"`, `semester: 1`, `is_active: true`, `is_service: false` (plus `Monday 10:05:00–11:20:00`, `is_service: true`, `room: "TBA"`). `matchesStudent` splits `"B+C"` cleanly; `_hm()` parses `HH:MM:SS`. | **PASS** *(manual CRUD rows verified; `publish_routine` RPC rows blocked by Bug #1)* |
| `public.notifications` | `NotificationItem.fromMap` & `matchesAudience` ([`notification_model.dart`](lib/core/models/notification_model.dart#L28-L71)) | `type: "university"`, `sent_by: "78322eda-17b5-4c4d-99be-e39c130b4312"`, `target_role: null`, `target_batch: null`, `target_section: null`, `created_at: "2026-11-21T21:05:29.844771+00:00"`. | **PASS** |
| `public.resources` | `Resource.fromMap` ([`resource_model.dart`](lib/core/models/resource_model.dart#L22-L43)) | `title: "Staging External Link"`, `category: "Notes"`, `semester: 1`, `subject_code: "CSE-1101"`, `drive_link: "https://drive.google.com/file/d/staging-test/view"`, `file_url: null`. | **PASS** |

---

## 6. Current Staging State (`oqwvxplteqtlrhktsplj`) & Workspace Hygiene

- **Preserved Synthetic Staging Seed Rows in `oqwvxplteqtlrhktsplj`:**
  - `public.profiles`: `1` (`test-demo@user.com`, `Staging Admin Lead`, `Routine Coordinator`)
  - `public.whitelists`: `2` (`stage-admin-test@example.com`, `test-demo@user.com`)
  - `public.timetable_rooms`: `3` (`RAB-301` active cap 64, `ACL-1` active cap 40, `GAL-1` inactive cap 120)
  - `public.timetable_faculty`: `2` (`TFA`, `TFB`)
  - `public.timetable_course_eligibility`: `2` (`TFA -> CSE-1101`, `TFB -> CSE-1102`)
  - `public.timetable_settings`: `1` (`id = 1`, `Staging Test 2026`, `P1–P7` + `Online P8 Col L`, Friday P4 locked)
  - `public.routines`: `2` (`CSE-1101` `58 B+C` Sun `08:50:00–10:05:00`, `MAT-1101` `58 A` Mon `10:05:00–11:20:00` `is_service=true`)
  - `public.notifications`: `1` (`Staging Interop Test`)
  - `public.resources`: `1` (`Staging External Link`)
  - `public.routine_versions`, `public.timetable_runs`, `public.course_distribution_*`: `0` rows
- **Local Workspace:** Temporary `synthetic_course_distribution.xlsx` is removed; `git status --short` confirms **zero modified code files**.
