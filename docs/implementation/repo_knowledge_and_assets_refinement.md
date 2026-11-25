# UniVerse — Knowledge-Base, `.agents/` Skill Ecosystem & Visual Assets Refinement Report

> **Date:** 2026-11-24
> **Scope:** Autonomous staff-engineering refinement of `.agents/skills/`, root governance (`AGENTS.md`, `CLAUDE.md`, `PROJECT_STRUCTURE.md`), active `docs/`, `docs/screenshots/`, Playwright E2E artifact routing, and workspace hygiene ahead of GitHub push, Cloudflare Pages Environment A, and Wave 2 (`Phase 4A-2` / `Phase 3B`).

---

## 1. `.agents/` Skill Ecosystem & Governance Refinement (Objective A)

All 17 files under `.agents/skills/` were audited line by line alongside `AGENTS.md` and `CLAUDE.md`:

1. **Retired `flutter-web-responsive-ui` Out of Active Auto-Discovery:**
   - Moved `.agents/skills/flutter-web-responsive-ui/` via `git mv` to `docs/archive/agent_skills_history/flutter-web-responsive-ui/`. Because coding agents auto-load every `.agents/skills/*/SKILL.md` frontmatter description into their system prompt, leaving an active skill advertising *"desktop web as the primary target"* for Flutter risked misrouting web tasks away from `apps/web/`.
2. **Eliminated Internal Contradictions & Stale Backend/Theme Claims:**
   - **`react-web-academic-design-system/SKILL.md`:** Removed the contradictory §2.1 *"Light-First; Dark Mode Deferred — Never ship a dark theme toggle or parallel dark palette in v1"* and legacy `--bg-dark`/`--bg-light` warm sepia references. Consolidated cleanly around Theme v3 (**X-Grade Carbon Obsidian Dark + Crisp Daylight Light + X-Azure**, `--bg-canvas`..`--bg-raised`, `--brand-50`..`--brand-950`, `public/theme-init.js`, and `@media print` Landscape A4).
   - **`react-admin-backend-contracts/SKILL.md`:** Replaced stale *"No iOS work"*, *"allow_origins=['\*'] and zero JWT"*, and *"Gates A–D locked until 20261106130000 promoted"* notes with current truth: continuous iOS compatibility, Phase 5A `engine/auth.py` (`ENGINE_AUTH_MODE=optional|enforced` + `ALLOWED_ORIGINS`), Staging (`oqwvxplteqtlrhktsplj`, 37 tables + Phase 5B RLS hardened, 4-table PostgREST Gate A/B probe with zero `401`/`500`), and Wave 2 Gate C/D + Phase 3B boundaries.
   - **`react-web-motion-and-craft/SKILL.md`:** Updated public `/` Archival Registrar guidance for full Light + Dark parity, dynamic midday break, in-browser Course Distribution Studio, and Official Committee Day Sheet printing.
   - **`ui-backend-policy-correlation/SKILL.md`:** Expanded from Flutter-only wording to govern 1:1 model/backend/committee correlation across **both** React Web (`apps/web/`) and Flutter Mobile (`lib/`).
   - **`universe-implementation/` (`SKILL.md` + 5 `references/*.md`):** Rewrote `references/web-platform.md` (formerly prohibiting React and iOS!) to govern standalone React Web, Cloudflare Pages Environment A/B, and the frozen Flutter fallback (`RoutineWorkbookParser` preserved until Cutover + Phase 3B). Updated `admin-distribution-ui.md`, `scheduling-cp-sat.md`, `backend-data-integrity.md`, and `testing-reliability.md` for Wave 2 (`Phase 4A-2` R1–R16 CP-SAT + durable jobs + archiving `publish_routine()`, `Phase 3B` parse endpoint, and 5-job CI).
   - **Flutter Mobile & QA Skills (`universe-visual-design-system`, `flutter-interaction-motion`, `accessibility-performance`, `universe-ux-principles`, `visual-ui-qa`):** Sharpened frontmatter descriptions to explicitly scope Obsidian Orbit (`#0B0C0E` + `#FF7A00`) to **Flutter Mobile (`lib/`, Android & iOS)**, removed provisional Phase 2 comment mandates and duplicate 25-line R1–R16 copy-paste blocks, and aligned `visual-ui-qa` for dual-client verification.
   - **`AGENTS.md` & `CLAUDE.md`:** Replaced stale *"Active Phase: Phase 2a on branch feature/admin-web-extension"* headers with the true pre-push / Wave 2 checkpoint and 10-skill routing table.

---

## 2. Active Documentation Consolidation (Objective B)

Verified code/CI dependencies first (`engine/tests/test_legacy_mapping.py` depends on `docs/timetable-audit-2026-10-20/task2-backfill-status.json` — preserved in place!), then moved **27 additional duplicate/historical files** into `docs/archive/` via `git mv`:

- **Duplicates & Drafts Archived (`docs/archive/flutter_ui_history/` & `docs/archive/web_history/`):**
  - `docs/architecture/web-separation/` (`WEB_ARCHITECTURE_DESIGN_BLUEPRINT.md`, `WEB_SOURCE_VERIFICATION_REPORT.md` — older duplicates of `docs/architecture/*.md`).
  - `docs/architecture/*.html` (`academic_ledger_phase1a_preview.html`, `design_directions_bold_preview.html`, `design_directions_preview.html` -> `docs/archive/web_history/html_prototypes/`).
  - `docs/implementation/* - Copy.md` (3 accidental Windows Explorer duplicate files) + duplicate `docs/implementation/UI_UX_SKILLS_INTEGRATION_REPORT.md`.
  - Legacy Flutter Web / Phase 2a handoff logs: `20-browser-admin-foundation.md`, `21-browser-admin-independent-review.md`, `22-phase-2a-contract-resumption.md`, and root `SEVEN_DAY_WEEK_AND_FRIDAY_JUMMAH_REMEDIATION_REPORT.md`.
- **Historical Audit Checkpoints Archived (`docs/archive/timetable_audit_history/`):**
  - Moved dated checkpoints `01` and `03`–`15` (14 files) out of `docs/timetable-audit-2026-10-20/`, leaving **only** the living committee & workbook specifications (`02-workbook-and-rules.md`, `16-committee-traceability-2026-11-04.md`, `18-committee-decisions-and-policy-baseline-2026-11-04.md`, updated `README.md`, and CI-required `task2-backfill-status.json`).

---

## 3. Visual Evidence & Playwright E2E Decoupling (Objective C)

1. **Fixed Root Cause of Dirty Screenshot Tree (`apps/web/tests/e2e/*.spec.ts`):**
   - Previously, all 7 Playwright specs wrote screenshots unconditionally into tracked `docs/screenshots/web_*` folders on every `test:e2e` run, modifying ~45 tracked PNGs per test run.
   - Updated all 7 E2E specs to write transient test captures to gitignored `apps/web/test-results/e2e-screenshots/<suite>` (with `UPDATE_WEB_GALLERY=1` opt-in on `phase_dark_and_distribution.spec.ts` when intentionally updating the canonical v3 gallery). Confirmed via a full `npm --prefix apps/web run test:e2e` run that **zero archived folders are recreated** and tracked galleries remain untouched.
2. **Archived 13 Superseded Screenshot & Failure Directories (`docs/archive/screenshots/` via `git mv`):**
   - Web history: `web_phase_1a`, `web_phase_2a`, `web_phase_2b`, `web_phase_3`, `web_phase_4`, `web_ux_cohesion`, `web_dark_and_distribution`, `web_theme_v2_and_fluid_layout`, `phase1a-screenshots`.
   - Flutter history & stale golden failure diffs: `flutter_phase_2b`, `flutter_phase_5`, `flutter_updatd` (`docs/updatd`), and `flutter_golden_failures` (`test/failures`, 64 stale diff PNGs).
3. **Retained Clean Active Galleries (`docs/screenshots/README.md`):**
   - `docs/screenshots/web_theme_v3_x_obsidian_and_print/` (8 current React Web v3 Dark + Light + Print + Distribution Studio + Mobile 390px captures).
   - `docs/screenshots/phase_3/` & `docs/screenshots/phase_7/` (active Flutter Mobile Obsidian Orbit golden baselines referenced by `test/phase35_visual_capture_test.dart` and `test/phase5_visual_capture_test.dart`).

---

## 4. Workspace Hygiene & Ambiguous Items Left for Owner Decision (Objective D)

### Cleaned Automatically (Unambiguous Non-Functional Clutter)
- Deleted 8 untracked gitignored build logs in repo root (`phase35-analyze-output.log`, `phase35-build-output.log`, `phase35-capture-output.log`, `phase35-motion-output.log`, `phase35-test-output.log`, `phase3_analyze.log`, `phase3_regressions.log`, `phase3_tests.log`) and root `test-results/`.
- Added `test/failures/`, `test-results/`, and `playwright-report/` to `.gitignore` and `apps/web/.gitignore`.

### Intentionally Preserved for Owner Decision (Not Deleted)
| Path | Git Status | Classification & Recommendation |
|---|---|---|
| `project_structure.txt` | **Untracked** | Workspace tree dump generated locally at `2026-11-24 04:51`. Delete or add to `.gitignore` before `git add .` if you do not want it committed. |
| `UniVerse_Project_Report.docx`, `SEARCH_SYSTEM.pdf`, `UniVerse_Concepts_Answers.pdf`, `generate_report.py`, `docs/Routine Generation System.pdf` | **Tracked** | Academic course/committee deliverables and report generator (`CSE-3240`). Keep tracked or move academic defense deliverables into a dedicated `docs/academic_submission/` folder if desired. |
| `engine/_expanded.xlsx` | **Tracked** | Existing tracked synthetic/test workbook in `engine/`. Left untouched per workbook safety rules; verify whether still needed during Wave 2 solver cleanup. |
| `.github/java-upgrade/`, `.github/modernize/` | **Untracked** (self-gitignored) | Created by VS Code / GitHub Copilot Java Upgrade extension (contains `.gitignore` ignoring `*`). Safe to leave or delete locally; `git add` ignores them. |
| `workbook/`, `new genarated routine/` | **Gitignored** | Local owner routine workbooks; strictly gitignored and untouched. |
| `tool/*.py` (diagram/PDF/rehearsal scripts) | **Tracked** | Note that `tool/task1_local_checks.py`, `tool/task1_invite_checks.py`, `tool/storage_api_probe.py`, and `tool/build_replay_rehearsal.py` are **actively tested in CI (`tools-and-functions` & `local-database` jobs)**. One-off diagram/PDF scripts (`make_defense_*.py`, `make_locallens_pptx.py`) were left intact to avoid breaking owner tooling. |

---

## 5. Full-Stack Verification Evidence

| Check | Command | Exact Result |
|---|---|---|
| **React Web Typecheck** | `npm --prefix apps/web run typecheck` | **0 errors** |
| **React Web Unit Suite** | `npm --prefix apps/web test` | **17/17 files, 157/157 tests passed** |
| **React Web Prod Build** | `npm --prefix apps/web run build` | **0 errors** (`dist/index.html`, CSS, JS, `_headers`, `_redirects`, `theme-init.js`) |
| **React Web Playwright E2E** | `npm --prefix apps/web run test:e2e` | **12/12 passed** (zero archived screenshot folders recreated) |
| **Python CP-SAT Engine** | `.\engine\.venv\Scripts\python.exe -m pytest engine/tests -q` | **230 passed, 1 skipped** |
| **Flutter Static Analysis** | `flutter analyze` | **0 issues** |
| **Flutter Mobile Suite** | `flutter test --exclude-tags visual_capture` | **384 passed** |
| **Active Link & Skill Audit** | Python audit across all active `docs/`, root `.md`, and `.agents/skills/` | **0 broken internal links, 10/10 skills verified** |

---

## 6. Final Curated NotebookLM Sync List

### Keep / Upload to NotebookLM (19 High-Signal Active Files)
1. `AGENTS.md`
2. `CLAUDE.md`
3. `PROJECT_STRUCTURE.md`
4. `README.md`
5. `DATABASE_AND_ROUTINE_SYSTEM_ARCHITECTURE.md`
6. `docs/backend-setup.md`
7. `docs/Routine Generation System.pdf`
8. `docs/architecture/WEB_ARCHITECTURE_DESIGN_BLUEPRINT.md`
9. `docs/architecture/WEB_IMPLEMENTATION_ROADMAP.md`
10. `docs/architecture/WEB_SOURCE_VERIFICATION_REPORT.md`
11. `docs/architecture/WEB_SEPARATION_CONTRACT_EXTRACTION.md`
12. `docs/deployment/CLOUDFLARE_PAGES_AND_CUTOVER_RUNBOOK.md`
13. `docs/deployment/PHASE_4A1_AND_5B_SQL_PROMOTION_RUNBOOK.md`
14. `docs/implementation/UniVerse_Implementation_Master_Plan_v1_1.md`
15. `docs/implementation/web_theme_v3_x_obsidian_and_print_fix.md`
16. `docs/implementation/web_phase_5_hardening_cicd_and_4a1_readiness.md`
17. `docs/implementation/web_phase_5_staging_verification_and_ci_fix.md`
18. `docs/timetable-audit-2026-10-20/18-committee-decisions-and-policy-baseline-2026-11-04.md`
19. `docs/timetable-audit-2026-10-20/16-committee-traceability-2026-11-04.md`
*(Optional: `docs/timetable-audit-2026-10-20/02-workbook-and-rules.md` for deep Excel cell/formula edge cases, and `docs/implementation/repo_knowledge_and_assets_refinement.md`.)*

### Remove from NotebookLM (All Archived / Duplicate Sources)
- Delete anything previously uploaded from:
  - Root legacy reports (`UNIVERSE_CURRENT_ARCHITECTURE_AND_UI_UX_DOSSIER.md`, `PHASE_*_REPORT.md`, `SEVEN_DAY_WEEK_*`, `GLOBAL_FLUTTER_DART_SKILLS_REPORT.md`, `UI_UX_SKILLS_INTEGRATION_REPORT.md`, `ADMIN_CRASH_*`).
  - `docs/implementation/` legacy logs (`20-browser-admin-foundation.md`, `21-browser-admin-independent-review.md`, `22-*`, `phase_0`..`phase_5`, `web_phase_0`..`web_phase_4`, `web_dark_theme_*`, `web_theme_v2_*`, `web_consolidated_*`, `web_admin_ux_*`).
  - `docs/architecture/` superseded drafts (`WEB_BOLD_DIRECTIONS_R2.md`, `WEB_DESIGN_DIRECTION_CANDIDATES.md`, `WEB_PHASE_1A_DESIGN_BRIEF.md`, `WEB_PHASE_2_DESIGN_BRIEF.md`, `web-separation/*`).
  - `docs/timetable-audit-2026-10-20/` dated checkpoints `01` and `03`–`15`.
