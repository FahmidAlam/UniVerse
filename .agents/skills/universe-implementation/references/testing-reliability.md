# Role 5 — Testing & Full-Stack Verification

## Scope

- **5-Job CI Matrix (`.github/workflows/validate.yml`):**
  1. `academic-domain`: `pytest engine/tests/test_domain.py engine/tests/test_normalized_domain.py engine/tests/test_legacy_mapping.py engine/tests/test_api_auth_and_cors.py -q` (note: `test_legacy_mapping.py` depends on `docs/timetable-audit-2026-10-20/task2-backfill-status.json`).
  2. `tools-and-functions`: `python -m unittest discover -s tool/tests -v` + Deno tests for `send-push` and `invite-admin`.
  3. `local-database`: GitHub-hosted ephemeral check (`python tool/task1_local_checks.py --task2`).
  4. `web-validate`: `npm --prefix apps/web ci`, `run typecheck`, `test` (Vitest), and `run build` (`dist/_redirects`, `dist/_headers`, `dist/theme-init.js`).
  5. `flutter-validate`: Flutter `3.47.0` `pub get`, `flutter analyze`, and `flutter test --exclude-tags visual_capture`.
- **Browser & Visual Regression:**
  - React Web E2E: `npm --prefix apps/web run test:e2e` (Playwright writes runtime captures to gitignored `apps/web/test-results/e2e-screenshots/`, keeping `docs/screenshots/web_theme_v3_x_obsidian_and_print/` clean unless `UPDATE_WEB_GALLERY=1`).
  - Flutter opt-in goldens: `test/phase35_visual_capture_test.dart` (`docs/screenshots/phase_3/`) and `test/phase5_visual_capture_test.dart` (`docs/screenshots/phase_7/regression/`), tagged `visual_capture`.

## Guardrails

- Distinguish clearly between static analysis, unit/widget tests, mocked Playwright E2E, and live Staging/Production database verification.
- Never use Supabase CLI locally; provide read-only SQL verification queries for **Supabase Dashboard → SQL Editor** when verifying hosted database state.
- Wave 2 CP-SAT solver additions (`Phase 4A-2`) must cover all mandatory scheduling fixture classes (feasible baseline, infeasible collision, time-limit incumbent, `B+C` joint/split teachers, external faculty collision, ECL/Physics windows, low-credit theory blocks, break-crossing, batch weekend spread, permanent attendance days, adjunct course bands, 6/7-slot grids, merged-row anomalies).
