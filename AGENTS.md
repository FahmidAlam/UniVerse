# AGENTS.md — UniVerse Project Rules & Entrypoint

> Automatically discovered project rules for **Codex (Terra & Sol)** and **Antigravity**.
> **Claude** loads [`CLAUDE.md`](CLAUDE.md), which enforces the same rules and architecture summary.

## 1. Authoritative Roadmap & Active Checkpoint

- **Master Plan:** [`docs/implementation/UniVerse_Implementation_Master_Plan_v1_1.md`](docs/implementation/UniVerse_Implementation_Master_Plan_v1_1.md)
- **Active Phase:** **Phase 2a — Course Distribution data contract** (`engine/distribution.py`, `supabase/migrations/20261106130000_course_distribution_contract.sql`), following the Phase 1 browser-admin foundation on branch `feature/admin-web-extension`.
- **Current Phase 2a Evidence Boundary:**
  - `engine/distribution.py` and `engine/tests/test_distribution_contract.py` are **implemented and Python-tested**.
  - `supabase/migrations/20261106130000_course_distribution_contract.sql`, `supabase/tests/course_distribution_contract.test.sql`, and `supabase/tests/course_distribution_authorization.test.sql` are **implemented and SQL-reviewed** in the working tree, but **not yet database-executed/verified** against Supabase. Do not report those pgTAP files as passed until executed and verified.

## 2. Permanent Project Constraints

- **Implementation-First & Token Efficiency:** Do not repeat completed audits, re-plan settled phases, or re-run test suites that already have valid passing evidence.
- **Preserve Architecture:** Keep the existing Flutter feature-first architecture (`ChangeNotifier` / `SafeChangeNotifier`), `GoRouter`, Supabase backend, and Python OR-Tools CP-SAT engine. No unrequested React/Next.js rewrite or state-management migration.
- **User Controls UI/UX (Mandatory Approval Gate):** Before writing any new UI for Phase 2b (editable Course Distribution & configuration workspace), Phase 5 (committee workbench), or any major redesign, present grounded design alternatives and trade-offs and wait for explicit user approval.
- **Design System & Theme Governance:** Preserve UniVerse's dark visual identity with orange accent (`AppColors`, `AppTheme.dark`), desktop-first web layout, and first-class responsive mobile adaptations. Never introduce competing theme systems or scatter hardcoded styling across screens. Centralize approved theme changes in the token layer, test cross-screen impact, and never replace Flutter with React/Next.js.
- **No iOS Work:** Do not spend time on iOS configuration, builds, or testing for now.
- **No Supabase CLI:** Never recommend, install, or use Supabase CLI. Use the connected Supabase plugin/integration. When database inspection or verification cannot be completed through it, provide the exact SQL query for the user to run in **Supabase Dashboard → SQL Editor** and ask them to return its output.
- **Hosted Services & Git Safety:** Never modify hosted Supabase, Firebase, OAuth, email/SMTP, or production configuration without explicit user approval. Preserve all existing work, untracked files, Git history, and working-tree changes — never run `git reset`, `git clean`, `git stash`, or `git push`.
- **PII & Workbook Safety:** Raw `engine/routine generation files/*.xlsx` contain personal data and remain gitignored. Treat workbooks as read-only untrusted data; never execute macros, mutate original workbook bytes, or commit PII/secrets.

## 3. Selective Context-Loading Protocol

Do **not** read the entire master plan or all specialist references for every task:

1. **Always Loaded (Global Rules):** `AGENTS.md` (for Codex/Antigravity) or `CLAUDE.md` (for Claude).
2. **Identify Checkpoint & Read Relevant Master-Plan Sections Only:** Check [`docs/implementation/UniVerse_Implementation_Master_Plan_v1_1.md`](docs/implementation/UniVerse_Implementation_Master_Plan_v1_1.md) §2 (Checkpoint) and §14 (Next Steps), then read **only the specific phase section** (§3–§9) relevant to your task.
3. **Load Only the Relevant Specialist Reference:** When coordinating or executing specialist work, open [`.agents/skills/universe-implementation/SKILL.md`](.agents/skills/universe-implementation/SKILL.md) and **only the single role file** in `.agents/skills/universe-implementation/references/` that matches your task.
4. **Load Relevant UI/UX Skills (Before Any UI/UX Work):** When designing, implementing, styling, animating, reviewing, or fixing UI/UX, do **not** load all skills. Consult the routing table in §4, load only the specific combination required, and read each relevant skill's `SKILL.md` before writing code or proposing UI changes.
5. **Load Domain/Subsystem Docs Only When Needed:**
   - Committee decisions & workbook rules: [`18-committee-decisions-and-policy-baseline-2026-11-04.md`](docs/timetable-audit-2026-10-20/18-committee-decisions-and-policy-baseline-2026-11-04.md), [`16-committee-traceability-2026-11-04.md`](docs/timetable-audit-2026-10-20/16-committee-traceability-2026-11-04.md), [`02-workbook-and-rules.md`](docs/timetable-audit-2026-10-20/02-workbook-and-rules.md).
   - Subsystem references: [`CLAUDE.md`](CLAUDE.md) §3–§4, [`engine/README.md`](engine/README.md), [`docs/backend-setup.md`](docs/backend-setup.md), [`PROJECT_STRUCTURE.md`](PROJECT_STRUCTURE.md).
6. **Historical On-Demand Only:** Never load `docs/archive/**` or `docs/timetable-audit-2026-10-20/01`–`15` during routine implementation.

## 4. UI/UX Skills & Selective Routing

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

## 5. Reusable UI/UX Workflow

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

## 6. Design System & Architecture Preservation

All UI/UX work must strictly complement UniVerse's established architecture:

- **Technology Stack:** Flutter frontend with Supabase backend.
- **Architecture Pattern:** Feature-first organization (`lib/features/`, `lib/core/`, `lib/shared/`), `ChangeNotifier` / `SafeChangeNotifier`, and `GoRouter`.
- **Visual Identity:** Dark visual identity with orange as the secondary accent (`AppColors`, `AppTheme.dark`, `AppSpacing`, `AppTextStyles`).
- **Platform Priority:** Desktop-first web experience, with mobile maintained as a first-class responsive adaptation.
- **Deliberate Theme Evolution:** The existing theme is open to improvement, but changes must be deliberate. Agents may propose improvements to color relationships, typography, spacing, contrast, surfaces, and component design.
- **Theme Guardrails:**
  - Never introduce an unrelated competing theme system.
  - Never scatter hardcoded styling throughout the application.
  - Make approved theme changes centrally in `lib/core/theme/`.
  - Verify impact across existing screens, shared components, and both web/mobile layouts.
  - Preserve functionality and architectural boundaries.
  - **Never rewrite the application in React or replace Flutter just to achieve better visual results.**
  - Retain the mandatory UI/UX approval gate from project instructions.

| **Any UI/UX feature, form, table, or admin control touching backend data, solver rules, or Routine Committee requirements** | `ui-backend-policy-correlation` + `universe-ux-principles` (Mandatory before writing any UI code; prohibits unbacked UI matrices and enforces 1:1 model/backend binding) |

## Phase 3.5 approved visual direction
The Product Owner explicitly approved the specified full-bleed auth/onboarding overhaul and Step 0 skill alignment. Repository-local `.agents/skills/` governs Level-4 depth, semantic accents and dual-mode continuous/reduced motion. This approval is scoped to Phase 3.5; all permanent auth/backend, hosted-service, Git and scheduling gates remain enforced.
