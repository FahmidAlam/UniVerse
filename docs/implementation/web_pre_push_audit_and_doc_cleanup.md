# UniVerse — Pre-Push Whole-Project Audit, Hygiene Fixes & Doc Cleanup Report

> **Date:** 2026-11-24
> **Scope:** Pre-push security/CI/code audit, Staging `401` OpenAPI probe fix, legacy Flutter/Web doc archiving (`docs/archive/`), and active governance/architecture synchronization.
> **Target:** GitHub push (5-job CI in `.github/workflows/validate.yml`) → Cloudflare Pages **Environment A (Continuous Committee Review → Staging `oqwvxplteqtlrhktsplj`)**.

---

## 1. Whole-Project Pre-Push Audit & Surgical Fixes

### 1.1 Secrets, PII & `.gitignore` Hygiene
- **Tracked Secret Scan (`git ls-files` & `git grep`):**
  - `apps/web/.env.local`, `dart_defines.json`, `.env`, `workbook/`, `new genarated routine/`, and `engine/routine generation files/` are **strictly gitignored and NOT tracked** (`git ls-files` returned only `apps/web/.env.example`).
  - Zero `sb_secret_`, `service_role`, or real private keys exist in tracked source files (only the PEM header stripping regex in `supabase/functions/send-push/index.ts:60` and the synthetic test fixture `"sb_secret_private"` in `tool/tests/test_storage_api_probe.py:33`).
  - `.github/workflows/supabase_keep_alive.yml` uses a hardcoded `SUPABASE_ANON_KEY` (`role: anon`, public publishable JWT for `yxqyrjyzxitrgkhgauli`) — not a secret/service_role key. Left intact so the scheduled keep-alive workflow is not broken; can optionally be migrated to GitHub Secrets in a future maintenance pass.

### 1.2 Staging Test 3 Fix — `401` on `GET /rest/v1/` OpenAPI Probe
- **Root Cause:** `probeRpcPathsViaOpenApi()` in `apps/web/src/features/scheduling/services/schedulingCapabilities.ts` called `GET /rest/v1/` with `Accept: application/openapi+json`, which returned `401 Unauthorized` on Staging (`oqwvxplteqtlrhktsplj`) and left Gates A & B locked when `course_distribution_revisions` had `0` rows.
- **Fix Applied:**
  - Removed `probeRpcPathsViaOpenApi()` and replaced it with a parallel 4-table RLS-protected PostgREST read against the atomic Track 2 schema from migration `20261106130000_course_distribution_contract.sql`: `course_distribution_revisions`, `course_distribution_sources`, `course_distribution_corrections`, and `course_distribution_artifacts`.
  - When a real revision row exists, `read_course_distribution_revision` is verified with that real ID (never a nil UUID).
  - **Result:** Zero HTTP `401` and zero HTTP `500` console errors in Live Mode; Gates A & B evaluate truthfully against the 37-table schema; **Gates C & D remain unconditionally locked** in Live Mode.
  - Updated `apps/web/tests/unit/schedulingContract.test.ts` and `apps/web/tests/unit/consolidatedFixesAndCohesion.test.tsx` to enforce this contract.

### 1.3 CI Workflow, CSP Headers, CORS & Stale Reference Audit
- **`.github/workflows/validate.yml`:** All 5 jobs (`academic-domain`, `tools-and-functions`, `local-database`, `web-validate`, `flutter-validate`) verified. Confirmed `flutter-version: '3.47.0'` matches the installed stable Flutter `3.47.0` / Dart `3.13.0` toolchain.
- **`apps/web/public/_headers`:** CSP verified against Google Fonts (`fonts.googleapis.com`, `fonts.gstatic.com`), Supabase (`https://*.supabase.co`, `wss://*.supabase.co`), Render engine (`https://universe-timetable-engine.onrender.com`), same-origin `/theme-init.js`, and `data:`/`blob:` assets.
- **`engine/auth.py` & `render.yaml`:** `ENGINE_AUTH_MODE=optional` default confirmed; `get_allowed_origins()` already strips whitespace and trailing slashes (`origin.strip().rstrip("/")`).
- **Stale Theme Comment Cleanup:** Updated the single remaining `Deep Botanical Pine` comment in `apps/web/src/shared/components/LedgerMark.tsx` to `X-Azure Blue`.

---

## 2. Legacy Documents Archived (`docs/archive/` via `git mv`)

Verified zero references from `.github/`, `test/`, `tool/`, `engine/`, `lib/`, or `apps/web/` before moving **32 files** via `git mv` (preserving full Git history) and adding `docs/archive/README.md`:

- **`docs/archive/flutter_ui_history/` (18 files):**
  - `ADMIN_CRASH_PERFORMANCE_AND_UI_FIX_REPORT.md`
  - `GLOBAL_FLUTTER_DART_SKILLS_REPORT.md`
  - `PHASE_2B_UI_UX_IMPLEMENTATION_REPORT.md`
  - `PHASE_6_COMMITTEE_RULES_AND_SUPPORTING_MODULES_REPORT.md`
  - `PHASE_7_FINAL_UI_UX_CLOSURE_REPORT.md`
  - `PHASE_A_ADMIN_CATALOG_CRUD_REPORT.md`
  - `PHASE_B_AND_7DAY_ALIGNMENT_REPORT.md`
  - `PHASE_C_AND_UNSLOP_COMPLETION_REPORT.md`
  - `UI_UX_SKILLS_INTEGRATION_REPORT.md`
  - `UNIVERSE_CURRENT_ARCHITECTURE_AND_UI_UX_DOSSIER.md`
  - `phase_0_redesign_baseline_and_decisions.md`
  - `phase_0_3_continuation_completion_report.md`
  - `phase_1_information_architecture_and_navigation.md`
  - `phase_2_visual_identity_and_design_system.md`
  - `phase_3_first_impression_onboarding_and_auth.md`
  - `phase_4_core_student_and_teacher_experiences.md`
  - `phase_5_administrative_scheduling_experience.md`
  - `22-phase-2b-scheduling-workspace-design-proposal.md`
- **`docs/archive/web_history/` (14 files):**
  - `WEB_BOLD_DIRECTIONS_R2.md`
  - `WEB_DESIGN_DIRECTION_CANDIDATES.md`
  - `WEB_PHASE_1A_DESIGN_BRIEF.md`
  - `WEB_PHASE_2_DESIGN_BRIEF.md`
  - `web_phase_0_1_spatial_orbit_foundation.md`
  - `web_phase_1a_academic_ledger_foundation.md`
  - `web_phase_2a_core_config.md`
  - `web_phase_2b_directory_comms_and_polish.md`
  - `web_phase_3_operational_routine_console.md`
  - `web_phase_4_committee_scheduling_workbench.md`
  - `web_consolidated_staging_verification.md`
  - `web_admin_ux_cohesion_and_staging_fixes.md`
  - `web_dark_theme_and_distribution_studio.md`
  - `web_theme_v2_dynamic_break_and_fluid_layout.md`
  *(Note: `docs/implementation/web_phase_1b_staging_auth_verification.md` was not present in the repository.)*

---

## 3. Active Governance & Architecture Docs Synchronized

Updated and link-verified (**11 active docs checked, 0 broken internal links**):
- `AGENTS.md` & `CLAUDE.md`: Added **Archive Exclusion Rule** and **Flutter Web Freeze Policy**, retired `flutter-web-responsive-ui` from the active Skill-Routing Table, and synchronized the Theme v3 + Phase 5 status.
- `PROJECT_STRUCTURE.md`: Rewrote `apps/web/` to reflect the production React Web v1 tree, removed archived root reports, and indexed `docs/deployment/`, `docs/archive/`, `engine/auth.py`, and Phase 5B migration.
- `README.md`, `docs/architecture/WEB_ARCHITECTURE_DESIGN_BLUEPRINT.md`, `docs/architecture/WEB_IMPLEMENTATION_ROADMAP.md`, and `docs/architecture/WEB_SOURCE_VERIFICATION_REPORT.md`: Synchronized current milestone status and fixed all 11 broken/archived relative links.

---

## 4. Full-Stack Pre-Push Verification Results

| Layer | Command | Result |
|---|---|---|
| **React Web TypeScript** | `npm --prefix apps/web run typecheck` | **0 errors** |
| **React Web Unit Tests** | `npm --prefix apps/web test` | **17/17 files, 157/157 tests passed** |
| **React Web Production Build** | `npm --prefix apps/web run build` | **0 errors** (`dist/_redirects` 19B, `dist/_headers` 719B, `dist/theme-init.js` 403B verified) |
| **React Web Playwright E2E** | `npm --prefix apps/web run test:e2e` | **12/12 passed** |
| **Python Engine** | `.\engine\.venv\Scripts\python.exe -m pytest engine/tests -q` | **230 passed, 1 skipped** |
| **Flutter Static Analysis** | `flutter analyze` | **0 issues** |
| **Flutter Mobile Tests** | `flutter test --exclude-tags visual_capture` | **384 passed** |
| **Active Markdown Links** | Python relative-link audit across 11 active docs | **0 broken links** |

---

## 5. Curated NotebookLM Source List (For Clean Wave 2 Research)

### Upload / Keep in NotebookLM (Active Sources of Truth)
1. `AGENTS.md`
2. `CLAUDE.md`
3. `PROJECT_STRUCTURE.md`
4. `README.md`
5. `DATABASE_AND_ROUTINE_SYSTEM_ARCHITECTURE.md`
6. `docs/architecture/WEB_ARCHITECTURE_DESIGN_BLUEPRINT.md`
7. `docs/architecture/WEB_IMPLEMENTATION_ROADMAP.md`
8. `docs/architecture/WEB_SOURCE_VERIFICATION_REPORT.md`
9. `docs/architecture/WEB_SEPARATION_CONTRACT_EXTRACTION.md`
10. `docs/deployment/CLOUDFLARE_PAGES_AND_CUTOVER_RUNBOOK.md`
11. `docs/deployment/PHASE_4A1_AND_5B_SQL_PROMOTION_RUNBOOK.md`
12. `docs/implementation/UniVerse_Implementation_Master_Plan_v1_1.md`
13. `docs/implementation/web_theme_v3_x_obsidian_and_print_fix.md`
14. `docs/implementation/web_phase_5_hardening_cicd_and_4a1_readiness.md`
15. `docs/implementation/web_phase_5_staging_verification_and_ci_fix.md`
16. `docs/implementation/web_pre_push_audit_and_doc_cleanup.md`
17. `docs/timetable-audit-2026-10-20/18-committee-decisions-and-policy-baseline-2026-11-04.md`
18. `docs/timetable-audit-2026-10-20/16-committee-traceability-2026-11-04.md`

### Remove from NotebookLM (Archived / Superseded)
- Remove any previously uploaded files now located in `docs/archive/flutter_ui_history/` (18 files, including `UNIVERSE_CURRENT_ARCHITECTURE_AND_UI_UX_DOSSIER.md` and Flutter UI Phase 0–7/A–C reports) and `docs/archive/web_history/` (14 files, including `web_phase_0_1_spatial_orbit_foundation.md`, `WEB_BOLD_DIRECTIONS_R2.md`, and Theme v1/v2 intermediate logs).
