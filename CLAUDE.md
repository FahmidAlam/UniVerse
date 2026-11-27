# CLAUDE.md — UniVerse Engineering Context

**Authoritative Roadmaps:** [`docs/architecture/WEB_IMPLEMENTATION_ROADMAP.md`](docs/architecture/WEB_IMPLEMENTATION_ROADMAP.md) & [`docs/implementation/UniVerse_Implementation_Master_Plan_v1_1.md`](docs/implementation/UniVerse_Implementation_Master_Plan_v1_1.md)

**Active Checkpoint (2026-11-28):**
- **Completed & Implemented (Stage 5C · Wave 2B / Phase 4A-2 · Gate D Ready):** Standalone React Web (`apps/web/`, Theme v3 `X-Grade Carbon Obsidian` Dark / `Crisp Daylight` Light / `X-Azure`) on **Environment B (Production):** `https://universe-admin-exi.pages.dev` → Production Supabase (`yxqyrjyzxitrgkhgauli`) and **Environment A (Staging):** `https://universe-bfi.pages.dev` → Staging Supabase (`oqwvxplteqtlrhktsplj`); Render FastAPI (`https://universe-timetable-engine.onrender.com`, `Engine v2.0.0`) with `ENGINE_AUTH_MODE=enforced`, strict `ALLOWED_ORIGINS`, Render 512 MB memory tuning (`SOLVER_WORKERS=1`, `SOLVER_NUM_WORKERS=1`, `SOLVER_MAX_MEMORY_MB=320`, `SOLVER_LINEARIZATION_LEVEL=0`, `MAX_CONCURRENT_SOLVES=1`), startup orphan-job sweep (`mark_orphaned_jobs_on_startup`), 2027 `sb_secret_...`/`sb_publishable_...` key compatibility (`engine/auth.py`), OOXML/rate-limit guards (`engine/security_guards.py`), Phase 3B parser (`engine/parse_rendered.py`), **dynamic 3-tier Course Room-Pool Classification** (`engine/ingest.py`, `engine/room_policy.py`), **Stage 5C Hybrid Faculty Off-Day Resolution (`R7`/`R6`/`R5`)**, and **durable Postgres `public.solver_jobs` + `timetables` Storage persistence (`engine/job_store.py`)**; React Web preflight modals (`CourseRoomPoolReviewModal.tsx`, `ImportMissingFacultyModal.tsx`, `workbookCourseScanner.ts`, `workbookFacultyScanner.ts`), resilient `58s` polling backoff + reconnect, Stage 4/5 Gate D unlock, Archive v2b 1-click `restore_routine_version()` rollback, joint-section (`B+C`) push fan-out & co-teacher `teacher_codes text[]` parity, Flutter Mobile 2027 `sb_publishable_...` key readiness, and pruned frozen Flutter Web (`web/`, `lib/features/admin/`).
- **Promotion Sequence (Owner-Executed in Supabase Dashboard → SQL Editor):** Apply `supabase/migrations/20261127180000_stage_5c_gate_d_durable_jobs_and_archiving_publish.sql` on Staging (`oqwvxplteqtlrhktsplj`) → verify with `supabase/tests/stage_5c_gate_d_rls_verification.sql` → promote to Production (`yxqyrjyzxitrgkhgauli`) + deploy Render/Cloudflare.

## 1. Permanent Project Constraints (Non-Negotiable)

- **Implementation-First & Token Efficiency:** Do not repeat completed audits, re-plan settled phases, or re-run test suites that already have valid passing evidence. Load only the files required for your current task.
- **Preserve Architecture:** Keep the existing Flutter feature-first architecture (`ChangeNotifier` / `SafeChangeNotifier`) and `GoRouter` for Android and iOS mobile (`lib/`), while delivering the standalone browser experience as a React 19 + TypeScript + Vite application (`apps/web/`). Both clients share the existing Supabase and Python FastAPI OR-Tools CP-SAT backend without duplicating business logic.
- **User Controls UI/UX (Mandatory Approval Gate):** Before writing any new UI for Phase 2b (editable Course Distribution & configuration workspace), Phase 5 (committee workbench), or any major redesign, present grounded design alternatives and trade-offs and wait for explicit user approval.
- **Design System & Theme Governance:** Keep Flutter mobile (`lib/`) on UniVerse's dark Obsidian Orbit visual identity (`AppColors`, `AppTheme.dark`) with full Android and iOS compatibility. Standalone React Web (`apps/web/`) uses its own completely separate interchangeable Light + Dark (Light / Dark / System) design system (**UniVerse Academic Ledger** — strictly separate from Flutter's Obsidian Orbit `#0B0C0E` + `#FF7A00` and the retired cyan/3D Spatial Orbit prototype). Never introduce competing theme systems within either client or back-port mobile styling onto React Web.
- **Archive Exclusion Rule:** Do **NOT** scan or load files under `docs/archive/` unless explicitly instructed by the user.
- **Flutter Web Pruned Policy:** Legacy Flutter Web (`web/`) and Flutter desktop admin screens (`lib/features/admin/`) have been **PRUNED** post-cutover (Stage 5C). Never implement web or admin features in Flutter; all web/admin work belongs exclusively in `apps/web/`. Signed-in admins on mobile route to `AdminWebNoticeScreen`. Flutter mobile Android & iOS Student/Teacher code remains active and protected.
- **iOS Scope (Compatibility vs. Feature Expansion):** Active iOS feature expansion and net-new iOS-only features are deferred; **continuous iOS compatibility preservation is mandatory**. Never remove or break iOS deep links, URL schemes, auth callback compatibility, or shared FastAPI/Supabase contracts.
- **No Supabase CLI:** Never recommend, install, or use Supabase CLI. Use the connected Supabase plugin/integration. When database inspection or verification cannot be completed through it, give the user the exact read-only SQL query to run in **Supabase Dashboard → SQL Editor** and ask them to return its output.
- **Supabase Environment Governance:** Production Supabase (`yxqyrjyzxitrgkhgauli`) is **live on Environment B** (37 tables + Phase 5B RLS/Storage hardening) and strictly protected against any unauthorized agent mutations. Secondary Supabase project `oqwvxplteqtlrhktsplj` is the **owner-approved isolated staging project** (37 tables + Phase 5B RLS/Storage hardening, zero outbound `send_push_on_notification` webhook). Because shared Render (`universe-timetable-engine.onrender.com`) now enforces **Production** Supabase JWTs (`ENGINE_AUTH_MODE=enforced`), local Staging end-to-end engine testing must run local `uvicorn` pointed at Staging Supabase. Any production database modification requires separate explicit owner authorization.
- **Hosted Services & Git Safety:** Never modify hosted Supabase, Firebase, OAuth, email/SMTP, or production configuration without explicit user approval. Never run `git reset`, `git clean`, `git stash`, or `git push`, and never discard uncommitted or untracked user work. Keep the user involved in manual dashboard actions.
- **PII & Workbook Safety:** Raw `engine/routine generation files/*.xlsx` contain personal data and remain gitignored. Treat workbooks as read-only untrusted data; never execute macros, mutate original workbook bytes, or commit PII/secrets.

## 2. Selective Context-Loading Protocol

Do **not** read the entire master plan or all specialist references before every task:

- **Step 1 — Always-Loaded Global Rules:**
  - `CLAUDE.md` (auto-loaded by Claude) and [`AGENTS.md`](AGENTS.md) (auto-loaded by Codex & Antigravity).
- **Step 2 — Checkpoint & Relevant Master-Plan Section Only:**
  - Read [`docs/implementation/UniVerse_Implementation_Master_Plan_v1_1.md`](docs/implementation/UniVerse_Implementation_Master_Plan_v1_1.md) **§2 (Current Status & Execution Checkpoint)** and **only the specific phase section** (§3–§9) relevant to the current task.
- **Step 3 — Task-Scoped Specialist & Subsystem Docs (When Relevant):**
  - Specialist skill [`SKILL.md`](.agents/skills/universe-implementation/SKILL.md) + **only the single matching role file** in `.agents/skills/universe-implementation/references/`.
  - Committee policy & workbook rules when touching Phase 2a/2b/4:
    - [`18-committee-decisions-and-policy-baseline-2026-11-04.md`](docs/timetable-audit-2026-10-20/18-committee-decisions-and-policy-baseline-2026-11-04.md) (decisions D1–D6, CD1 workbook columns `A`–`L`).
    - [`16-committee-traceability-2026-11-04.md`](docs/timetable-audit-2026-10-20/16-committee-traceability-2026-11-04.md) (detailed R1–R16 traceability matrix).
    - [`02-workbook-and-rules.md`](docs/timetable-audit-2026-10-20/02-workbook-and-rules.md) (workbook structure, formulas, anomalies).
  - Subsystem references when editing that subsystem: [`engine/README.md`](engine/README.md), [`docs/backend-setup.md`](docs/backend-setup.md), [`PROJECT_STRUCTURE.md`](PROJECT_STRUCTURE.md), [`docs/architecture/WEB_ARCHITECTURE_DESIGN_BLUEPRINT.md`](docs/architecture/WEB_ARCHITECTURE_DESIGN_BLUEPRINT.md), and [`docs/deployment/CLOUDFLARE_PAGES_AND_CUTOVER_RUNBOOK.md`](docs/deployment/CLOUDFLARE_PAGES_AND_CUTOVER_RUNBOOK.md).
- **Step 4 — Task-Scoped Skills (Before Any Work):**
  - Thirteen active skills live in `.agents/skills/`. Do **not** load all of them. Consult the **Skill-Routing Table** in §5, load only the matching row, and read each relevant skill's `SKILL.md` before writing code or proposing UI changes.
- **Step 5 — Historical / On-Demand Only:**
  - `docs/archive/**` and historical audit checkpoints `docs/timetable-audit-2026-10-20/01`–`15`. Do not load during routine implementation.

## 3. Architecture & Core Technical Contracts

- **Flutter Layering:** `screen` → `ChangeNotifier` controller → feature service → Supabase / engine API.
  - Core modules: `lib/core/` (`constants`, `models`, `platform`, `router`, `theme`, `utils`, `services`), `lib/shared/`, `lib/features/` (`auth`, `routine`, `resources`, `notifications`, `profile`, `dashboard`, `teacher`, `find_teacher`, `rooms`).
  - Navigation: `AppRouter` (`GoRouter`) with `AuthController` redirect refresh (`AdminWebNoticeScreen` for mobile admins; `AppShell` / `RoleDesktopShell` for mobile/tablet students & teachers). Secondary routes use `context.push` + `RouteNames` (never `MaterialPageRoute` or hardcoded strings).
  - Auth callbacks: Flutter native uses `com.example.universe://login-callback/` and `com.example.universe://reset-callback/` (`AuthCallbackPolicy`); Flutter web uses origin allowlist `AUTH_WEB_CALLBACK_URLS` against `Uri.base`; React Web (`apps/web/`) handles PKCE + `extractAndScrubInviteHash()` / `adoptInviteSession()` (`services/supabase.ts`) across `/`, `/login`, `/forgot-password`, `/reset-password`, and `/access-required` (no `/auth-callback` or `AuthCallbackLocation` symbol exists).
- **Course Distribution & Timetable Pipeline:**
  - **Phase 2a Source Contract:** `engine/distribution.py` (`SourceWorkbook`, `DistributionDraft`, `CellCorrection`, `CorrectionRevision`, `normalize`) and `supabase/migrations/20261106130000_course_distribution_contract.sql` (`course_distribution_sources`, `course_distribution_revisions`, `course_distribution_corrections`, `course_distribution_artifacts`, `append_course_distribution_correction`).
  - Original `.xlsx` bytes and SHA-256 hash are immutable. Columns `J` and `L` retain both formula text and cached value (missing cached value on an uncorrected formula fails validation). Corrections require revision concurrency match (`expected_revision`), author, and reason, and automatically mark derived artifacts `stale`.
  - **Ingestion & Solver:** `engine/ingest.py` binds headers on row 5 of `Course Distribution`, preserves `B+C` joint sections and split/co-teacher arrays, and feeds `engine/solver.py` (CP-SAT) → validation in `engine/solver.py` → `engine/render.py`.
  - **Clock & Publication:** Clock normalization uses `ClockTime` (`HH:MM:SS` in DB, `HH:MM` in engine). `publish_routine()` archives prior active rows non-destructively (`is_active = false` + `routine_versions.snapshot_rows`), persists `teacher_codes text[]`, and pairs with `restore_routine_version()` for 1-click PostgreSQL rollback (`20261127180000`).
- **Supabase Security & Schema:**
  - Historical chain `001`–`016` (no `010`), `20261022140809_academic_catalog.sql`, `20261106130000_course_distribution_contract.sql`, `20261122160000_phase_5b_rls_and_storage_hardening.sql`, `20261127120000_stage_5a_gate_c_catalogs_and_policy.sql`, and `20261127180000_stage_5c_gate_d_durable_jobs_and_archiving_publish.sql`.
  - Every table or RPC change requires matching Dart/TS contracts, least-privilege grants/RLS, `set search_path = ''` on `SECURITY DEFINER` functions, and negative authorization tests. Never weaken RLS to bypass permission errors.
- **UI Conventions:**
  - Use `package:universe/...` imports, `AppColors`, `AppTextStyles`, `AppSpacing`, `AppTheme.dark`, global Inter typography, `shared/utils/phosphor_compat.dart` icon shim, and `DropdownButtonFormField.initialValue`.

## 4. Verification Commands (Run Targeted Checks Only)

From repository root:
```powershell
flutter analyze
flutter test <target_test_file.dart>
flutter build web --release --dart-define-from-file=dart_defines.json
```

From `engine/`:
```powershell
.\.venv\Scripts\python.exe -m pytest tests/test_distribution_contract.py -q
.\.venv\Scripts\python.exe -m uvicorn main:app --reload --port 8000
```

*Note:* `seed_config.py` mutates config/seed files from workbooks — never run it as an inspection command. For Supabase database checks, use the connected Supabase plugin or provide exact SQL for **Supabase Dashboard → SQL Editor**.

## 5. UI/UX & Engineering Skills (`.agents/skills/`)

Thirteen active repository-local skills live in `.agents/skills/` (the retired `flutter-web-responsive-ui` skill is archived under `docs/archive/agent_skills_history/`). Read only the specific `SKILL.md` combination matching your task:

1. [`system-security-and-hardening`](.agents/skills/system-security-and-hardening/SKILL.md) — Zero-trust Auth/PKCE/invite-bridge, Edge Functions, Postgres `SET search_path = ''` + RLS, Storage bounds, untrusted `.xlsx` safety, FastAPI `429`/CORS, CSP `_headers`, and CI secret hygiene.
2. [`backend-evolution-and-resilience`](.agents/skills/backend-evolution-and-resilience/SKILL.md) — Expand–contract SQL migrations, `supabase/reconciliation/` rollbacks, 4-layer serialization contracts, durable Postgres solver jobs, direct Storage downloads, and pure `engine/` domain boundaries.
3. [`fullstack-verification-and-ci`](.agents/skills/fullstack-verification-and-ci/SKILL.md) — Targeted Vitest/Playwright/pytest/Deno/SQL/Flutter verification matrix, Dart↔Python fixture parity, and 5-job CI / pre-commit leak checks.
4. [`react-web-academic-design-system`](.agents/skills/react-web-academic-design-system/SKILL.md) — React Web (`apps/web/`) Theme v3 OKLCH tokens (`X-Grade Carbon Obsidian` Dark + `Crisp Daylight` Light + `X-Azure`), typography, dense tables, Landscape A4 print, and anti-slop gate.
5. [`react-web-motion-and-craft`](.agents/skills/react-web-motion-and-craft/SKILL.md) — React Web (`apps/web/`) public specimen, `motion/react` physics, Course Distribution Studio, progressive disclosure, and async states.
6. [`react-admin-backend-contracts`](.agents/skills/react-admin-backend-contracts/SKILL.md) — React Web (`apps/web/`) PKCE + invite bridge, FastAPI JWT/CORS, Supabase persistence truth, and 4-table Gate A–D boundaries.
7. [`ui-backend-policy-correlation`](.agents/skills/ui-backend-policy-correlation/SKILL.md) — Strict 1:1 correlation between UI controls (`apps/web/` & `lib/`), backend contracts, and Routine Committee rules (`R1`–`R16`, `D1`–`D6`, `CD1`).
8. [`universe-implementation`](.agents/skills/universe-implementation/SKILL.md) — Multi-layer coordinator with 5 role references (`web-platform`, `admin-distribution-ui`, `scheduling-cp-sat`, `backend-data-integrity`, `testing-reliability`).
9. [`universe-ux-principles`](.agents/skills/universe-ux-principles/SKILL.md) — Product-level UX reasoning, journeys, hierarchy, and the 6 unglamorous states across Mobile and Web.
10. [`universe-visual-design-system`](.agents/skills/universe-visual-design-system/SKILL.md) — Flutter Mobile (`lib/`) dark Obsidian Orbit tokens (`AppColors`, `AppTheme.dark`) and shared `U*` widgets.
11. [`flutter-interaction-motion`](.agents/skills/flutter-interaction-motion/SKILL.md) — Flutter Mobile (`lib/`) `AppMotion` timing, tactile press feedback, and reduced-motion safeguards.
12. [`accessibility-performance`](.agents/skills/accessibility-performance/SKILL.md) — Flutter Mobile (`lib/`) WCAG AA contrast, `Semantics`, keyboard traversal, and rebuild minimization.
13. [`visual-ui-qa`](.agents/skills/visual-ui-qa/SKILL.md) — Dual-client evidence-based visual QA (Playwright/DevTools for `apps/web/`, widget/golden checks for `lib/`).

### Skill-Routing Table (Sync in `AGENTS.md` §4 & `CLAUDE.md` §5)

| Work Type | Required Skills to Load (Load Only Matching Row) |
| :--- | :--- |
| **Auth, RLS, Storage, Edge Functions, FastAPI JWT/CORS/rate-limits, `.xlsx` security, CSP, or CI secrets** | `system-security-and-hardening` (Mandatory before editing security boundaries) |
| **SQL migrations, RPCs, FastAPI endpoints (Phase 3B / Gate C–D / R1–R16), durable jobs, or cross-client contracts** | `backend-evolution-and-resilience` + `universe-implementation` (load single matching role reference) |
| **Any UI control, form, table, or admin view touching backend data or Committee Rules (`R1`–`R16`, `D1`–`D6`, `CD1`)** | `ui-backend-policy-correlation` + `universe-ux-principles` (+ `react-admin-backend-contracts` for `apps/web/`) |
| **React Web (`apps/web/`) design, layout, OKLCH tokens, typography, motion, or print** | `react-web-academic-design-system` + `react-web-motion-and-craft` |
| **React Web (`apps/web/`) Auth, Supabase queries/RPCs, FastAPI client, or capability gates** | `react-admin-backend-contracts` |
| **Flutter Mobile (`lib/`) UI, tokens, motion, or accessibility** | `universe-visual-design-system` + `flutter-interaction-motion` + `accessibility-performance` |
| **Full-stack testing, fixture parity, SQL negative RLS checks, or CI pipelines** | `fullstack-verification-and-ci` |
| **Visual/DOM screenshot & responsive QA (`apps/web/` or `lib/`)** | `visual-ui-qa` + active client design skill |

> **Context Efficiency Rule:** Do **not** load all skills for every task. Load only the specific row matching the active work type.

## 6. Reusable UI/UX Workflow & Design System Governance

For all UI/UX-related work, agents must follow this 11-step process:

1. **Identify Scope:** Identify the screen, component, or user workflow involved.
2. **Inspect Existing Baseline:** Inspect the existing implementation, theme, shared components, and relevant design decisions.
3. **Load Relevant Skills:** Load the relevant UI/UX skills per the routing table above.
4. **Understand Core Problem:** Understand the actual user problem before proposing a visual solution.
5. **Analyze Improvement Opportunities:** Identify opportunities to improve usability, hierarchy, consistency, responsiveness, and interaction quality.
6. **Formulate Alternatives:** For material redesigns, prepare a concise design proposal with relevant alternatives and trade-offs.
7. **Obtain User Approval:** Obtain explicit user approval before implementing material changes to screens, themes, navigation, or workflows (Mandatory Approval Gate).
8. **Architectural Implementation:** Implement within the existing architecture.
9. **Verification:** Run relevant tests and inspect actual rendered output.
10. **Visual & Responsive Testing:** Use screenshots and responsive browser testing where appropriate.
11. **Comprehensive Reporting:** Report changed files, verification evidence, and remaining issues.

*Routine fixes exception:* Small defect fixes that preserve an already-approved design can proceed without reopening the design approval process.

### Design System & Architecture Guardrails

All UI/UX work must respect the separated client architecture:

- **Mobile Client (`lib/` — Android & iOS compatibility):** Flutter frontend with Supabase + FastAPI backends, feature-first organization (`lib/features/`, `lib/core/`, `lib/shared/`), `ChangeNotifier` / `SafeChangeNotifier`, `GoRouter`, and dark Obsidian Orbit tokens (`AppColors`, `AppTheme.dark`, `AppSpacing`, `AppTextStyles`). Preserve Android and iOS compatibility continuously; never replace Flutter mobile with React/Next.js, scatter hardcoded styling, or bypass `lib/core/theme/`.
- **Web Client (`apps/web/` — Desktop Admin & Public Entry):** Standalone React 19 + TypeScript + Vite frontend governed by **UniVerse Academic Ledger** (`react-web-academic-design-system` + `react-web-motion-and-craft` + `react-admin-backend-contracts`). Students and teachers signing in on web receive a mobile-app guidance view.
- **Mandatory UI/UX Approval Gate:** Obtain explicit user approval before implementing material screen, theme, navigation, or workflow changes.

## Phase 0 redesign baseline (Flutter Legacy Context)

Scheduling Workspace fixtures and simulated mutations are Design Preview only. An accepted database revision does not establish operational reader, correction, policy, generation, or publication wiring. In legacy Flutter web, `/admin/routine` acted as the operational generator/uploader; new browser administration targets standalone React Web (`apps/web/`). See [Phase 0 baseline and decisions](docs/archive/flutter_ui_history/phase_0_redesign_baseline_and_decisions.md).

## Phase 3.5 approved visual direction (Flutter Mobile Scope)

The Product Owner previously approved the specified full-bleed auth/onboarding overhaul for the Flutter app (`lib/`). All permanent auth/backend, hosted-service, Git, and scheduling gates remain enforced.

## React Web v1 Approved Visual Direction (UniVerse Academic Ledger)

Standalone React Web (`apps/web/`, Administrator Operations Console + Public Institutional Entry `/` + Mobile-App Guidance for student/teacher sessions) uses **UniVerse Academic Ledger**, combining **Precision Ledger** (administrative ergonomics), **Campus Atelier** (comfortable long-session usability), and **Archival Registrar** (institutional public presentation).

- **Interchangeable Light + Dark (Light / Dark / System):** React Web v1 ships full-parity Crisp Daylight Light and X-Grade Carbon Obsidian Dark modes under UniVerse Academic Ledger. Completely separate from Flutter's dark-orange Obsidian Orbit (`#0B0C0E` + `#FF7A00`), and must **not** inherit the superseded dark-cyan Spatial Orbit Engine prototype.
- **Typography:** `Source Serif 4` (editorial headlines), `IBM Plex Sans` (UI and dense operational tables), `IBM Plex Mono` (course codes, time slots, and tabular numerals).
- **Color Tokens:** 4-layer near-achromatic Carbon-Obsidian (Dark, `C <= 0.006`) + Crisp Daylight (Light, `C <= 0.004`) + 10-step **X-Azure Blue** (`H = 246°–248°`, `--brand-50`..`--brand-950`) OKLCH token architecture with neutral dot-pill status badges, raised monochrome active tabs, and perceptually uniform OKLCH charts, verified via automated WCAG AA checks over actual opaque sRGB foreground/background pairs (tokenized centrally in `tokens.css`).
- **Timetable & Craft:** Custom CSS Grid + React scheduling timetable (not a Gregorian calendar library), dynamic midday break, restrained Motion/CSS transitions respecting `prefers-reduced-motion`, user-controlled illustrative public timetable, invisible UI in dense operational tables, and backend-derived dashboard readiness. Flutter mobile (`lib/`) remains on Obsidian Orbit (`#0B0C0E` + `#FF7A00`).
