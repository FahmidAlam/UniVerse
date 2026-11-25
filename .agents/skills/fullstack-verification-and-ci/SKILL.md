---
name: fullstack-verification-and-ci
description: Cross-stack testing, fixture equivalence, SQL negative RLS verification, pre-commit secret/drift checks, and 5-job GitHub Actions CI discipline across apps/web/, engine/, supabase/, and lib/. Mandatory before declaring any multi-layer feature, migration, FastAPI endpoint, or CI change complete. Do NOT use for visual screenshot layout critiques alone (use visual-ui-qa).
---

# UniVerse Full-Stack Verification & CI Reliability

Verify every layer with deterministic, proportional evidence before concluding work or preparing a commit.

## 1. Targeted Verification Matrix (Run What Matches Touched Layers)

1. **React Web (`apps/web/`):**
   - `npm --prefix apps/web run typecheck` (zero TypeScript errors)
   - `npm --prefix apps/web test` (Vitest unit/contract/contrast suites)
   - `npm --prefix apps/web run build` (clean Vite production bundle)
   - `npm --prefix apps/web run test:e2e` (Playwright smoke & responsive checks when routes, auth, or layouts change)
2. **Python Engine (`engine/`):**
   - `pytest engine/tests` (covers `distribution.py`, `ingest.py`, `room_policy.py`, `solver.py`, `render.py`, `auth.py`, and Phase 3B parser parity)
3. **Supabase SQL & Edge Functions (`supabase/`):**
   - Run `python tool/task1_local_checks.py` and `python tool/task1_local_checks.py --task2` (plus `python -m unittest discover -s tool/tests -v`) for local schema/catalog invariants.
   - Run `deno test` on `supabase/functions/invite-admin/` and `supabase/functions/send-push/` when Edge Functions change.
   - Execute `supabase/tests/phase_5b_rls_hardening_verification.sql` (wrapped in `BEGIN ... ROLLBACK`) in Staging/Production SQL Editor after any RLS/Storage migration.
4. **Flutter Mobile (`lib/`, `test/`):**
   - `flutter analyze` (zero warnings/errors)
   - `flutter test --exclude-tags visual_capture` (ensures zero regression to Android/iOS Student & Teacher flows)

## 2. Cross-Client Fixture & Contract Parity

- Any change to `ClockTime`, joint-section (`B+C`) parsing, room aliases, 20-counter validation keys, or Phase 3B rendered-workbook parsing must pass shared test fixtures matching Dart (`RoutineWorkbookParser` / `RoutineEntry`) and Python (`engine/ingest.py` / `render.py`).
- Live capability probes (`schedulingCapabilities.ts`) must be tested against both Staging (`Gate A/B unlocked, Gate C/D locked`) and Production (`Gates A–D locked` pre-4A-1) states without triggering `401` or `500` console errors.

## 3. Pre-Commit Hygiene & CI Discipline

1. **5-Job GitHub Actions Parity (`.github/workflows/validate.yml`):**
   - Keep `academic-domain`, `tools-and-functions`, `local-database`, `web-validate`, and `flutter-validate` green on every PR.
2. **Secret & Artifact Leak Check:**
   - Run `git status --short` and `git diff --check` before handoff.
   - Confirm `apps/web/.env.local`, `dart_defines.json`, `project_structure*.txt`, and raw `.xlsx` workbooks (`engine/routine generation files/*.xlsx`) are untracked/gitignored and zero secrets appear in YAML or source files.
