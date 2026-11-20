# CLAUDE.md — UniVerse Engineering Context

**Authoritative Roadmap & Active Checkpoint:** [`docs/implementation/UniVerse_Implementation_Master_Plan_v1_1.md`](docs/implementation/UniVerse_Implementation_Master_Plan_v1_1.md)
**Active Work:** **Phase 2a — Accepted Course Distribution data contract** (`engine/distribution.py` + `engine/tests/test_distribution_contract.py` implemented & Python-verified; `supabase/migrations/20261106130000_course_distribution_contract.sql` + `supabase/tests/course_distribution_*.test.sql` implemented & SQL-reviewed, pending database execution/verification).

## 1. Permanent Project Constraints (Non-Negotiable)

- **Implementation-First & Token Efficiency:** Do not repeat completed audits, re-plan settled phases, or re-run test suites that already have valid passing evidence. Load only the files required for your current task.
- **Preserve Architecture:** Keep the existing Flutter feature-first architecture (`ChangeNotifier` / `SafeChangeNotifier`), `GoRouter`, Supabase backend, and Python OR-Tools CP-SAT engine. No unrequested React/Next.js rewrite or state-management migration.
- **User Controls UI/UX (Mandatory Approval Gate):** Before writing any new UI for Phase 2b (editable Course Distribution & configuration workspace), Phase 5 (committee workbench), or any major redesign, present grounded design alternatives and trade-offs and wait for explicit user approval.
- **Design System & Theme Governance:** Preserve UniVerse's dark visual identity with orange accent (`AppColors`, `AppTheme.dark`), desktop-first web layout, and first-class responsive mobile adaptations. Never introduce competing theme systems or scatter hardcoded styling across screens. Centralize approved theme changes in the token layer, test cross-screen impact, and never replace Flutter with React/Next.js.
- **No iOS Work:** Do not spend time on iOS configuration, builds, or testing for now.
- **No Supabase CLI:** Never recommend, install, or use Supabase CLI. Use the connected Supabase plugin/integration. When database inspection or verification cannot be completed through it, give the user the exact SQL query to run in **Supabase Dashboard → SQL Editor** and ask them to return its output.
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
  - Subsystem references when editing that subsystem: [`engine/README.md`](engine/README.md), [`docs/backend-setup.md`](docs/backend-setup.md), [`PROJECT_STRUCTURE.md`](PROJECT_STRUCTURE.md), or Phase 1 records [`20-browser-admin-foundation.md`](docs/implementation/20-browser-admin-foundation.md) / [`21-browser-admin-independent-review.md`](docs/implementation/21-browser-admin-independent-review.md).
- **Step 4 — Task-Scoped UI/UX Skills (Before Any UI/UX Work):**
  - Six specialized UI/UX skills exist in `.agents/skills/`. Do **not** load all six. Consult the routing table in §5, load only the specific combination required, and read each relevant skill's `SKILL.md` before writing code or proposing UI changes.
- **Step 5 — Historical / On-Demand Only:**
  - `docs/archive/**` and historical audit checkpoints `docs/timetable-audit-2026-10-20/01`–`15`. Do not load during routine implementation.

## 3. Architecture & Core Technical Contracts

- **Flutter Layering:** `screen` → `ChangeNotifier` controller → feature service → Supabase / engine API.
  - Core modules: `lib/core/` (`constants`, `models`, `platform`, `router`, `theme`, `utils`, `services`), `lib/shared/`, `lib/features/` (`auth`, `admin`, `routine`, `resources`, `notifications`, `profile`, `dashboard`, `teacher`, `find_teacher`, `rooms`).
  - Navigation: `AppRouter` (`GoRouter`) with `AuthController` redirect refresh. Web/desktop admin uses `AdminDesktopShell`; mobile uses `AppShell`. Secondary routes use `context.push` + `RouteNames` (never `MaterialPageRoute` or hardcoded strings).
  - Auth callbacks: native `com.example.universe://login-callback/` and `com.example.universe://reset-callback/`; web `/auth-callback` and `/reset-password` (`AuthCallbackLocation`).
- **Course Distribution & Timetable Pipeline:**
  - **Phase 2a Source Contract:** `engine/distribution.py` (`SourceWorkbook`, `DistributionDraft`, `CellCorrection`, `CorrectionRevision`, `normalize`) and `supabase/migrations/20261106130000_course_distribution_contract.sql` (`course_distribution_sources`, `course_distribution_revisions`, `course_distribution_corrections`, `course_distribution_artifacts`, `append_course_distribution_correction`).
  - Original `.xlsx` bytes and SHA-256 hash are immutable. Columns `J` and `L` retain both formula text and cached value (missing cached value on an uncorrected formula fails validation). Corrections require revision concurrency match (`expected_revision`), author, and reason, and automatically mark derived artifacts `stale`.
  - **Ingestion & Solver:** `engine/ingest.py` binds headers on row 5 of `Course Distribution`, preserves `B+C` joint sections and split/co-teacher arrays, and feeds `engine/solver.py` (CP-SAT) → validation in `engine/solver.py` → `engine/render.py`.
  - **Clock & Publication:** Clock normalization uses `ClockTime` (`HH:MM:SS` in DB, `HH:MM` in engine). `publish_routine()` atomically replaces global active routine rows (refusing empty payloads); manual CRUD via `RoutineAdminController` still writes directly until Phase 3 unifies server-authoritative validation across generation, upload, manual edits, and publication.
- **Supabase Security & Schema:**
  - Historical chain `001`–`016` (no `010`), `20261022140809_academic_catalog.sql`, and `20261106130000_course_distribution_contract.sql`.
  - Every table or RPC change requires matching Dart models/services, least-privilege grants/RLS, `set search_path = ''` on `SECURITY DEFINER` functions, and negative authorization tests. Never weaken RLS to bypass permission errors.
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

## 5. UI/UX Skills & Selective Routing

Six specialized UI/UX skills are located in `.agents/skills/`. Agents must read the relevant `SKILL.md` before starting applicable UI/UX work and combine skills when a task spans multiple areas:

1. [`universe-ux-principles`](.agents/skills/universe-ux-principles/SKILL.md) — Product-level UX reasoning, user journeys, task hierarchy, forms, decision points, honest progress/feedback, error prevention, and academic task clarity.
2. [`universe-visual-design-system`](.agents/skills/universe-visual-design-system/SKILL.md) — Visual hierarchy, spacing, typography, dark/orange palette governance, anti-slop restraint, and centralized theme modification protocol.
3. [`flutter-web-responsive-ui`](.agents/skills/flutter-web-responsive-ui/SKILL.md) — Desktop-first web layouts, adaptive breakpoints (1440, 1280, 1024, 768, 390 px), data-heavy admin grids, sidebars, and responsive form patterns.
4. [`flutter-interaction-motion`](.agents/skills/flutter-interaction-motion/SKILL.md) — Interaction states (idle, hover, focus, pressed, disabled, loading, success, error), purposeful animations, micro-interactions, and reduced-motion support.
5. [`accessibility-performance`](.agents/skills/accessibility-performance/SKILL.md) — Color contrast, keyboard focus traversal, semantic labels, screen readers, rebuild minimization, and UI performance.
6. [`visual-ui-qa`](.agents/skills/visual-ui-qa/SKILL.md) — Evidence-based visual QA, screenshot comparison protocol, severity ranking (Critical, High, Medium, Low), and multi-viewport inspection.

### Skill-Routing Table

| Work type | Skills to load |
|---|---|
| UX research, user journey, or workflow redesign | `universe-ux-principles` + `universe-visual-design-system` |
| Visual redesign or new components | `universe-visual-design-system` + `universe-ux-principles` |
| Flutter Web screen implementation | `flutter-web-responsive-ui` + `universe-visual-design-system` |
| Animation or interaction work | `flutter-interaction-motion` + `universe-ux-principles` |
| Accessibility or performance improvements | `accessibility-performance` |
| Final visual inspection or UI review | `visual-ui-qa` + relevant implementation skills |
| Complete UI/UX task | Only the relevant combination of skills |

> **Context Efficiency Rule:** Do **not** load all six skills for every task. Load only the specific combination matching the active work type.

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

- **Technology Stack:** Flutter frontend with Supabase backend.
- **Architecture Pattern:** Feature-first organization (`lib/features/`, `lib/core/`, `lib/shared/`), `ChangeNotifier` / `SafeChangeNotifier`, and `GoRouter`.
- **Visual Identity:** Dark visual identity with orange as the secondary accent (`AppColors`, `AppTheme.dark`, `AppSpacing`, `AppTextStyles`).
- **Platform Priority:** Desktop-first web experience, with mobile maintained as a first-class responsive adaptation.
- **Theme Guardrails:**
  - Never introduce an unrelated competing theme system.
  - Never scatter hardcoded styling throughout the application.
  - Make approved theme changes centrally in `lib/core/theme/`.
  - Verify impact across existing screens, shared components, and both web/mobile layouts.
  - Preserve functionality and architectural boundaries.
  - **Never rewrite the application in React or replace Flutter just to achieve better visual results.**
  - Retain the mandatory UI/UX approval gate from project instructions.

## Phase 0 redesign baseline

Scheduling Workspace fixtures and simulated mutations are Design Preview only. An accepted database revision does not establish operational reader, correction, policy, generation, or publication wiring. `/admin/routine` remains the operational generator/uploader. See [Phase 0 baseline and decisions](docs/implementation/phase_0_redesign_baseline_and_decisions.md).

## Phase 3.5 approved visual direction
The Product Owner explicitly approved the specified full-bleed auth/onboarding overhaul and Step 0 skill alignment. Repository-local `.agents/skills/` governs Level-4 depth, semantic accents and dual-mode continuous/reduced motion. This approval is scoped to Phase 3.5; all permanent auth/backend, hosted-service, Git and scheduling gates remain enforced.


| **Any UI/UX feature, form, table, or admin control touching backend data, solver rules, or Routine Committee requirements** | `ui-backend-policy-correlation` + `universe-ux-principles` (Mandatory before writing any UI code; prohibits unbacked UI matrices and enforces 1:1 model/backend binding) |