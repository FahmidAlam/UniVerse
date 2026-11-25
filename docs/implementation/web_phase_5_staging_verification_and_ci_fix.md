# UniVerse — Pre-CI Fixes, Staging Phase 5B Hardening & Final Live Staging E2E Re-Verification Report

**Date:** 2026-11-23  
**Target Environment:** Staging Supabase **`oqwvxplteqtlrhktsplj`** + Live Render FastAPI (`https://universe-timetable-engine.onrender.com`) + Local Vite Dev Server (`http://localhost:5173`)  
**Production Safety Confirmation:** Production Supabase **`yxqyrjyzxitrgkhgauli`** was **NEVER** queried, connected to `apps/web/.env.local`, or modified. Zero edits were made to `apps/web/.env.local`, `engine/solver.py`, or `engine/render.py`. Zero Supabase CLI was used.

---

## 1. Part A — Pre-Push Fixes (Docs + Flutter CI Green Check)

### 1.1 Redirect URL Contract & Shared Render Warning
- **Code Inspection:** Confirmed [`AuthProvider.tsx`](../../apps/web/src/features/auth/AuthProvider.tsx#L416-L439) (`signInWithGoogle`, `sendPasswordReset`) and [`usersService.ts`](../../apps/web/src/features/admin/services/usersService.ts#L80-L91) (`buildInviteAdminPayload`) all send `${window.location.origin}/` (root with trailing slash).
- **Runbook Updated:** [`docs/deployment/CLOUDFLARE_PAGES_AND_CUTOVER_RUNBOOK.md`](../deployment/CLOUDFLARE_PAGES_AND_CUTOVER_RUNBOOK.md):
  - Updated **§2.2** and **§3.2** so mandatory Redirect URLs and `AUTH_WEB_CALLBACK_URLS` list exact trailing-slash root URLs (`https://<review-domain>.pages.dev/`, `http://localhost:5173/`, `https://<prod-domain>/`), keeping `/login` and `/reset-password` as optional secondary entries.
  - Added the **Shared Render Service Warning** in **§2.3**: while a single shared Render service (`universe-timetable-engine`) serves both Staging Review (`oqwvxplteqtlrhktsplj`) and Production Flutter (`yxqyrjyzxitrgkhgauli`), Render must stay in `ENGINE_AUTH_MODE=optional` (with strict `ALLOWED_ORIGINS` active) until either a dedicated staging Render service is created or Environment B cuts over to Production with `ENGINE_AUTH_MODE=enforced`.

### 1.2 Flutter CI (`flutter-validate`) Resolution
- [`test/admin_web_foundation_test.dart`](../../test/admin_web_foundation_test.dart#L277-L331): Updated two stale expectations to match current production behavior without weakening production code:
  1. `TimetableGridScreen(rows: [])` intentionally falls back to `SchedulingPreviewFixtures.candidateRoutineRows` when Supabase is unavailable (verified alongside `test/admin_crash_performance_and_layout_fix_test.dart`); updated expectation to assert the operational lenses (`Section`, `Faculty`, `Room`).
  2. `AdminScheduleSlot` normalizes `'Lab-1'` via `RoomIdentity.key` to `'LAB-1'` and renders `'LAB-1 ↗'` when the normalized key differs from `entry.room`; updated expectation from `'LAB-1'` to `'LAB-1 ↗'`.
- [`test/phase5_visual_capture_test.dart`](../../test/phase5_visual_capture_test.dart#L211-L682) & [`test/phase35_visual_capture_test.dart`](../../test/phase35_visual_capture_test.dart#L183): Gated `phase5_visual_capture_test.dart` behind `const enabled = bool.fromEnvironment('PHASE5_CAPTURE')` (`skip: !enabled`) and tagged both opt-in visual capture suites with `tags: ['visual_capture']`.
- [`.github/workflows/validate.yml`](../../.github/workflows/validate.yml#L91-L92): Updated `flutter-validate` to run `flutter test --exclude-tags visual_capture`.

| Check | Command | Result |
|---|---|---|
| Flutter Static Analysis | `flutter analyze` | **Passed** (`No issues found!`) |
| Flutter CI Test Suite | `flutter test --exclude-tags visual_capture` | **Passed** (`384 passed, 0 failed`) |

---

## 2. Part B — Staging (`oqwvxplteqtlrhktsplj`) Phase 5B Hardening & Verification

1. **Pre-Flight Snapshot (`oqwvxplteqtlrhktsplj` via `supabase_mcp`):**
   - `table_count`: `37`
   - `profiles`: `1`, `whitelists`: `2`, `routines`: `2`, `timetable_rooms`: `3`, `timetable_faculty`: `2`, `timetable_settings`: `1`, `timetable_course_eligibility`: `2`.
2. **Migration Execution (`20261122160000_phase_5b_rls_and_storage_hardening.sql`):**
   - `supabase_mcp` auto-cancelled mutating DDL/DML confirmations, so the owner executed [`supabase/migrations/20261122160000_phase_5b_rls_and_storage_hardening.sql`](../../supabase/migrations/20261122160000_phase_5b_rls_and_storage_hardening.sql) directly in **Staging (`oqwvxplteqtlrhktsplj`) → Supabase Dashboard → SQL Editor** (succeeded).
3. **Verification Script Fix & Execution (`phase_5b_rls_hardening_verification.sql`):**
   - Initial run hit `ERROR: 42703: column "full_name" of relation "profiles" does not exist`. Fixed [`supabase/tests/phase_5b_rls_hardening_verification.sql`](../../supabase/tests/phase_5b_rls_hardening_verification.sql#L29) (`full_name` → `name`), and the owner re-ran it cleanly in Staging SQL Editor (`ROLLBACK`-safe).
4. **Post-Promotion Read-Only SQL Verification (`oqwvxplteqtlrhktsplj` via `supabase_mcp`):**
   - **`pg_proc` (`search_path` & `SECURITY DEFINER`):** `guard_profile_role`, `is_admin`, `my_role`, and `register_device_token` all returned `prosecdef = true` and `proconfig = ["search_path=\"\""]`.
   - **`pg_policies` (`storage.objects`):** **Zero** `storage_auth_*` wildcard policies remain. Active policies are strictly bucket-scoped (`storage_timetables_*_admin`, `storage_resources_*_staff`, `storage_avatars_*_own`, `storage_assignments_*_scoped`, `storage_public_read`).

---

## 3. Part C — Final Live Staging E2E Re-Verification Scorecard (`oqwvxplteqtlrhktsplj`)

| Suite | Scope | Verdict | Key Observed Evidence |
|---|---|---|---|
| **Test 1** | First-Login `409 Conflict` Fix (`test-demo@user.com`) | **PASS** | Staging `public.profiles` was cleared to `0` rows for `test-demo@user.com` (`whitelists = 1`). When the browser opened `http://localhost:5173/login`, `AuthProvider` auto-provisioned `public.profiles` (`created_at: 2026-11-22T21:59:34Z`, `name: "Staging Test Admin"`, `role: "admin"`); subsequent sign-out + clean sign-in landed on `/admin/dashboard` on **attempt #1** (`POST /auth/v1/token` → `200`, `GET /rest/v1/profiles` → `200`), **zero `409`** errors. |
| **Test 2** | In-App Distribution Studio → Live Render CP-SAT → 3-Step Guarded Publication + Flutter Parity | **PASS** | Created 2-offering non-PII sheet (`CSE-1101` `58-A` `TFA`, `CSE-1102` `58-B` `TFB`). `POST /api/timetable/generate` → `200` (`job_id: d7823233df73`), polled `200` to `done` (`00:23`), `GET /api/timetable/result/d7823233df73` → `200` with **zero `EngineResultSchema` error**. KPI cards rendered (`OR-Tools OPTIMAL`, `146 ms`, `CSE Meetings: 4`, `Validation: Passed (20/20)`), 20-counter ledger expanded cleanly (`0` failing), **Inspect in 2D Grid** rendered 4 slots, and `GET /api/timetable/download/d7823233df73` returned `200` (`322,593` bytes). **3-Step Guarded Publication** succeeded under Phase 5B RLS: (1) Storage `timetables` upload → `200`, (2) `POST /rest/v1/rpc/publish_routine` → `200`, (3) `POST /rest/v1/timetable_runs` → `201`. Verified via `supabase_mcp`: `routine_versions` (`is_active: true`, `row_count: 4`), `timetable_runs` (`status: "published"`), and `routines` (`4` active rows with `HH:MM:SS` times, `batch`, `section`, `teacher_code`, `room`, `is_active`, `is_service`) matching Flutter `RoutineEntry.fromMap`. |
| **Test 3** | Zero-500 `/admin/scheduling` Live Capability Probe | **PARTIAL / DEFECT** | **Zero HTTP `500`** errors (`course_distribution_sources` → `200`, `course_distribution_revisions` → `200`), zero fixture leakage, `Gate C: Locked`, `Gate D: Locked`. **Discrepancy:** `GET /rest/v1/` (OpenAPI probe in `probeRpcPathsViaOpenApi`) returned `401`, causing `Gate A` and `Gate B` to display **`Locked`** instead of **`Verified`**. |
| **Test 4** | Post-Phase-5B Admin Regression + Theme/Print Spot-Check | **PASS** *(with settings/print notes)* | `/admin/timetable/rooms` (`200`, 3 rooms), `/admin/timetable/faculty` Dark Mode off-day pills (`TFA`, `TFB`, legible contrast, `200`), `/admin/resources` Storage upload (`200`) + DB insert (`201`) + DB delete (`204`) + Storage delete (`200`) succeeded under Phase 5B RLS, `/admin/broadcast` (`200`, `Sent History (1)`). On `/admin/timetable/grid` **Committee Sheet** mode, the `BREAK` column rendered unclipped (`12:45` / `13:10` stacked after `P3`, matching `timetable_settings` `id=1`'s current `After P3` config); `@media print` CSS rules (`A4 landscape`, `.no-print` hidden, `overflow: visible`, `44pt` break col) were verified in DOM/CSS (sandboxed browser does not support `page.emulateMedia()`). |
| **Test 5** | Local Web Typecheck, Unit Tests & Working Tree | **PASS** | `npm --prefix apps/web run typecheck` (`0` errors); `npm --prefix apps/web test` (`17/17` files, `157/157` tests passed); `git status --short` clean of unintended edits or secrets. |

---

## 4. Next Owner Checklist (GitHub Push & Environment A Launch)

1. **Optional Follow-Up (Test 3 Discrepancy):** Decide whether to address `GET /rest/v1/` returning `401` in `probeRpcPathsViaOpenApi()` (`schedulingCapabilities.ts`) before or after Environment A preview (Track 2 UI remains gated behind `VITE_ENABLE_SCHEDULING_PREVIEW_ROUTE=false` in Environment A).
2. **Commit & Push (`feature/admin-web-extension`):** Review `git status --short`, commit the Part A/B fixes and verification docs, and push to GitHub so `.github/workflows/validate.yml` runs all 5 CI jobs (`academic-domain`, `tools-and-functions`, `local-database`, `web-validate`, `flutter-validate`).
3. **Launch Cloudflare Pages Environment A (Continuous Committee Review → Staging `oqwvxplteqtlrhktsplj`):**
   - Create Cloudflare Pages project (`Root: apps/web`, `Build: npm run build`, `Output: dist`, `NODE_VERSION=22`).
   - Set `VITE_SUPABASE_URL=https://oqwvxplteqtlrhktsplj.supabase.co`, `VITE_SUPABASE_ANON_KEY=<REDACTED>`, `VITE_TIMETABLE_BASE_URL=https://universe-timetable-engine.onrender.com`, `VITE_ENABLE_SCHEDULING_PREVIEW_ROUTE=false`.
   - In Staging Supabase (`oqwvxplteqtlrhktsplj`) → **Authentication → URL Configuration → Redirect URLs**, register `https://<review-domain>.pages.dev/` and `http://localhost:5173/`.
   - On Render (`universe-timetable-engine`), add `https://<review-domain>.pages.dev` to `ALLOWED_ORIGINS` and keep `ENGINE_AUTH_MODE=optional` until dedicated staging Render or Production cutover.
