# UniVerse — Phase 5 Hardening, CI/CD, UI Quick Fixes & Phase 4A-1 Readiness Report

**Date:** 2026-11-22  
**Scope:** Stage 0 (5 surgical UI quick fixes), Stage 1 (Cloudflare Pages config + unified CI/CD + cutover runbook), Stage 2 (Phase 5A dual-client FastAPI JWT & CORS hardening), Stage 3 (Phase 5B RLS & Storage SQL packet), Stage 4 (Phase 4A-1 promotion runbook + cross-platform verification).  
**Boundary Compliance:** Zero mutations to Production Supabase (`yxqyrjyzxitrgkhgauli`) or Staging Supabase (`oqwvxplteqtlrhktsplj`), zero edits to `apps/web/.env.local`, zero changes to `engine/solver.py` or `engine/render.py`, zero Supabase CLI usage, and zero secrets committed.

---

## 1. Files Created & Modified

### Stage 0 — 5 Surgical UI Quick Fixes (`apps/web/`)
- [`apps/web/src/features/routine/components/AcademicTimetableMatrix.tsx`](../../apps/web/src/features/routine/components/AcademicTimetableMatrix.tsx): Driven footer midday-break legend dynamically from `resolveMiddayBreak(configuredPeriods)` (matching `resolveBreakBeforePeriodIdx(configuredPeriods)`), replacing the hardcoded `(Col G)` label.
- [`apps/web/src/features/routine/components/CommitteeDaySheetView.tsx`](../../apps/web/src/features/routine/components/CommitteeDaySheetView.tsx) & [`apps/web/src/styles/app.css`](../../apps/web/src/styles/app.css): Stacked `middayBreak.start` and `middayBreak.end` on two tight monospace lines inside `.committee-break-col` (`52px` screen / `44pt` print width) so A4 Landscape print never truncates the break end time.
- [`apps/web/src/styles/tokens.css`](../../apps/web/src/styles/tokens.css): Shifted `--chart-2` to cohesive cool slate-periwinkle (`oklch(0.540 0.085 236)` Light / `oklch(0.700 0.100 238)` Dark) harmonizing with `--chart-1`.
- [`apps/web/src/features/admin/AdminShell.tsx`](../../apps/web/src/features/admin/AdminShell.tsx) & [`apps/web/src/features/admin/pages/AdminDashboardPage.tsx`](../../apps/web/src/features/admin/pages/AdminDashboardPage.tsx): Added `"admin.dashboard": "Dashboard"` mobile compact title and changed readiness checklist descriptions to `line-clamp-2 ... sm:truncate`.
- [`apps/web/src/features/onboarding/components/AcademicLedgerPreview.tsx`](../../apps/web/src/features/onboarding/components/AcademicLedgerPreview.tsx): Aligned `6-Slot` / `7-Slot` active toggle pill to the raised monochrome surface (`bg-[var(--bg-raised)]` + `--border-strong`), reserving solid X-Azure strictly for primary CTAs.

### Stage 1 — Cloudflare Pages Config & Unified CI/CD
- [`apps/web/public/theme-init.js`](../../apps/web/public/theme-init.js) & [`apps/web/index.html`](../../apps/web/index.html): Extracted pre-paint theme initialization into an external `/theme-init.js` script so CSP requires zero `'unsafe-inline'` for scripts.
- [`apps/web/public/_redirects`](../../apps/web/public/_redirects): SPA fallback `/* /index.html 200`.
- [`apps/web/public/_headers`](../../apps/web/public/_headers): Security headers (`X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`, `Referrer-Policy`, `Permissions-Policy`, `Strict-Transport-Security`, `Content-Security-Policy`) and cache rules (`/assets/*` `immutable`, `/index.html` `no-cache`).
- [`.github/workflows/validate.yml`](../../.github/workflows/validate.yml): Added `engine-api-auth-tests` (Python job), `edge-invite-admin-tests` (Deno job), `web-validate` (Node 22 typecheck, Vitest, placeholder-env build), and `flutter-validate` (Flutter 3.47.0 `pub get`, `analyze`, `test`).
- [`docs/deployment/CLOUDFLARE_PAGES_AND_CUTOVER_RUNBOOK.md`](../deployment/CLOUDFLARE_PAGES_AND_CUTOVER_RUNBOOK.md): Environment A (Continuous Committee Review → Staging `oqwvxplteqtlrhktsplj`) and Environment B (Gated Production Cutover → `yxqyrjyzxitrgkhgauli`) checklists.

### Stage 2 — Phase 5A FastAPI Dual-Client Auth & CORS Hardening
- [`lib/features/admin/services/timetable_engine_service.dart`](../../lib/features/admin/services/timetable_engine_service.dart) & [`test/timetable_engine_auth_header_test.dart`](../../test/timetable_engine_auth_header_test.dart): Attached `Authorization: Bearer <access_token>` (via `Supabase.instance.client.auth.currentSession?.accessToken` or injectable `EngineAccessTokenProvider`) to `generate`, `pollStatus`, `fetchResult`, and `downloadWorkbook`, while keeping `EngineConnectivityService.check()` (`GET /`) unauthenticated.
- [`apps/web/src/features/routine/services/timetableEngineService.ts`](../../apps/web/src/features/routine/services/timetableEngineService.ts) & [`apps/web/tests/unit/timetableEnginePolling.test.ts`](../../apps/web/tests/unit/timetableEnginePolling.test.ts): Attached `Authorization: Bearer <session.access_token>` when configured and added fast-fail `"auth"` error handling on `401`/`403`.
- [`engine/auth.py`](../../engine/auth.py), [`engine/main.py`](../../engine/main.py), [`engine/requirements.txt`](../../engine/requirements.txt), [`render.yaml`](../../render.yaml), & [`engine/tests/test_api_auth_and_cors.py`](../../engine/tests/test_api_auth_and_cors.py): Added env-driven `ALLOWED_ORIGINS` CORS and gradual-to-strict `ENGINE_AUTH_MODE` (`optional` default / `enforced` production) Supabase JWT + `public.profiles.role == 'admin'` verification with 60s in-memory TTL cache and fail-closed `503` if `enforced` without Supabase credentials.

### Stage 3 — Phase 5B RLS & Storage Hardening SQL Packet (No Supabase CLI)
- [`supabase/migrations/20261122160000_phase_5b_rls_and_storage_hardening.sql`](../../supabase/migrations/20261122160000_phase_5b_rls_and_storage_hardening.sql): Standardized `my_role`, `is_admin`, `guard_profile_role`, and `register_device_token` (`SET search_path = ''`), tightened `profiles_select` and `timetable_*` `SELECT` policies, revoked `anon` on `timetable_*` config tables, replaced wildcard `storage_auth_*` policies with bucket-scoped rules (`timetables`, `resources`, `avatars`, `assignments`), and conditionally tightened Track 2 `course_distribution_*_read` policies.
- [`supabase/reconciliation/rollback_phase_5b_rls_and_storage.sql`](../../supabase/reconciliation/rollback_phase_5b_rls_and_storage.sql): Reversible restore script.
- [`supabase/tests/phase_5b_rls_hardening_verification.sql`](../../supabase/tests/phase_5b_rls_hardening_verification.sql): `ROLLBACK`-safe SQL Editor negative/positive verification script.

### Stage 4 — Phase 4A-1 Promotion Runbook
- [`docs/deployment/PHASE_4A1_AND_5B_SQL_PROMOTION_RUNBOOK.md`](../deployment/PHASE_4A1_AND_5B_SQL_PROMOTION_RUNBOOK.md): Ordered SQL Editor promotion steps for Staging then gated Production, plus explicit Wave 2 (Phase 4A-2) scope boundaries.

---

## 2. Local Cross-Platform Verification Results

| Stack | Command | Observed Result |
|---|---|---|
| **React Web** | `npm --prefix apps/web run typecheck` | **Passed** (`0` errors) |
| **React Web** | `npm --prefix apps/web test` | **Passed** (`17` test files, `157/157` tests, including `83` WCAG AA contrast checks) |
| **React Web** | `npm --prefix apps/web run build` | **Passed** (`5879` modules; `_headers`, `_redirects`, `theme-init.js` verified in `apps/web/dist/`) |
| **React Web** | `npm --prefix apps/web run test:e2e` | **Passed** (`12/12` Playwright specs in `4.4m`) |
| **Python Engine** | `engine\.venv\Scripts\python.exe -m pytest engine/tests/test_api_auth_and_cors.py -v` | **Passed** (`6/6` auth & CORS tests) |
| **Python Engine** | `engine\.venv\Scripts\python.exe -m pytest engine/tests -q` | **Passed** (`230 passed, 1 skipped` — `solver.py`/`render.py` untouched) |
| **Flutter Mobile** | `flutter analyze` | **Passed** (`No issues found!`) |
| **Flutter Mobile** | `flutter test test/timetable_engine_auth_header_test.dart` | **Passed** (`2/2` Bearer header tests) |
| **Flutter Mobile** | `flutter test` | `382 passed, 1 skipped` (`phase35_visual_capture_test.dart`), `3` pre-existing unrelated failures (`test/admin_web_foundation_test.dart` x2, `test/phase5_visual_capture_test.dart` x1) |
| **iOS Static Check** | Inspected `ios/Runner/Info.plist` & `lib/features/auth/services/auth_callback_policy.dart` | Verified `io.supabase.universe` and `com.example.universe` URL schemes + `FlutterDeepLinkingEnabled = false` intact. Native macOS/Xcode runtime execution not available on Windows host. |
| **Deno Edge** | `where.exe deno` | Deno not installed locally; `invite-admin` & `send-push` tests are configured in `.github/workflows/validate.yml` (`edge-invite-admin-tests`) for CI execution. |

---

## 3. Manual Owner Actions Required (Hosted Dashboards)

1. **Staging SQL Execution (`oqwvxplteqtlrhktsplj`):** Run `20261122160000_phase_5b_rls_and_storage_hardening.sql` and `phase_5b_rls_hardening_verification.sql` in Supabase Dashboard → SQL Editor.
2. **Environment A (Cloudflare Pages Review Site):** Create Cloudflare Pages project (`apps/web`, `npm run build`, `dist`, `NODE_VERSION=22`), set Staging Supabase + Render env vars, register exact Redirect URLs in `oqwvxplteqtlrhktsplj`, and set `ALLOWED_ORIGINS` on Render.
3. **Render FastAPI (`universe-timetable-engine`):** Redeploy with `ENGINE_AUTH_MODE=optional` first, verify Flutter + React Web on Staging, then set `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, and switch `ENGINE_AUTH_MODE=enforced`.
4. **Production Cutover (GATED):** Only after Staging + Review URL + enforced FastAPI pass, execute Steps A–D of `PHASE_4A1_AND_5B_SQL_PROMOTION_RUNBOOK.md` on `yxqyrjyzxitrgkhgauli` and deploy Environment B.
