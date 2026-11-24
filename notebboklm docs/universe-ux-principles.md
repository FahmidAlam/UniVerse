---
name: universe-ux-principles
description: Apply product-level UX reasoning to UniVerse journeys, forms, navigation, information hierarchy, unglamorous states, and academic task clarity across Flutter Mobile (lib/) and React Web (apps/web/).
---

# UniVerse UX Principles & User Journey Specification

## 1. Product Target & Separated Platform UX

- **Operational Trust & Task Completion:** UniVerse optimizes for low-friction execution of real university workflows — student/faculty routine consultation, class updates, room/faculty lookup, and committee timetable generation. Avoid visual novelty or fabricated telemetry.
- **Separated Client Identities:**
  - **Flutter Mobile (`lib/`, Android & iOS Student/Teacher):** Uses **Obsidian Orbit** (`#0B0C0E`–`#1F2229` dark surfaces, `#FF7A00` accent; pair with `universe-visual-design-system`). Legacy Flutter Web (`web/`, `lib/features/admin/`) is frozen.
  - **Standalone React Web (`apps/web/`, Admin Console & Public `/`):** Uses **UniVerse Academic Ledger** (X-Grade Carbon Obsidian Dark + Crisp Daylight Light + X-Azure; pair with `react-web-academic-design-system` + `ui-backend-policy-correlation`).

## 2. Core User Experience Principles

- **Clarity Over Cleverness:** Use explicit, familiar academic terminology (`Weekly Matrix`, `Routine Operations`, `Class Tools`, `Campus Lookup`). Avoid cryptic, icon-only buttons for critical academic actions.
- **Task-Driven Information Hierarchy:** Structure screens around what users need to decide or execute next—not around database table schemas or raw API models.
- **Content-Aware Adaptive Layouts (Decision D-04):**
  - **Compact Mobile (`<768px` Usable Width):** Single-column vertical stream, 5-item thumb-friendly bottom bar, minimum 48x48 dp touch targets.
  - **Medium Tablet/Laptop (`768–1099px` Usable Width):** Compact rail (`220px`) + single-column bounded workspace (600–860px canvas).
  - **Expanded Desktop (`>=1100px` Usable Width):** Persistent left sidebar (`250px`) + multi-column workspace (e.g., 58/42 split or master-detail inspector).
- **Progressive Disclosure:** Show critical schedule context and next actions first. Keep advanced filters or administrative overrides in secondary inspect panels or sheets.
- **Truthful Progress & Academic Integrity:**
  - Never animate synthetic solver progress bars or fake initial completion percentages.
  - Academic correctness strictly outranks visual convenience: never hide unresolved room conflicts, silently normalize uncertain source data, or represent simulated previews (`/admin/scheduling`) as live published schedules.

## 3. Role-Aware Journey Patterns

- **Student UX Journey:**
  - Primary Bottom Bar: `Today (/student/dashboard) | Routine (/student/routine) | Campus (/rooms) | Resources (/student/resources) | Alerts (/notifications)`.
  - Priority: Instant clarity on current section/batch timetable, real-time class cancellations/relocations, and 1-tap room/faculty lookup.
- **Teacher UX Journey:**
  - Primary Bottom Bar: `Today (/teacher/dashboard) | Teaching (/teacher/routine) | Campus (/rooms) | Class Tools (/teacher/manage-classes) | Alerts (/notifications)`.
  - Priority: Frictionless access to today's teaching slots, date-scoped class updates via modal bottom sheets (`220ms Curves.easeInOutCubic`), and right-hand class action inspectors on wide viewports.
- **Administrator UX Journey:**
  - Desktop Shell: Command Center (`/admin/dashboard`), Routine Operations (`/admin/routine?tab=manage|generate|upload`), and Scheduling Workbench · Preview (`/admin/scheduling` with explicit `PREVIEW` banner).
  - Priority: Dense data scanning, stable column alignment, explicit revision selection, and verified capability gates (Gates A–D) for backend execution.

## 4. The 6 Mandatory Unglamorous States (Psychology of Premium Apps)

To break past the "commodity ceiling" and deliver a truly premium experience, every screen MUST explicitly handle all 6 unglamorous states:

1. **Loading State:** Skeleton shimmers (`#1F2229`) or locked-dimension spinners; zero layout shifts.
2. **First-Use Empty State:** Clear guidance explaining how to setup, enroll, or generate routines.
3. **Filter Zero-Match State (`UEmptyState.noMatches`):** Acknowledges active search/filter terms and provides a 1-tap `Clear filters` button.
4. **Recoverable Error State (`UEmptyState.error`):** Presents human-readable failure context and a prominent `Retry` button (`Icons.refresh`).
5. **Unavailable / Stale Data State:** Displays explicit offline or stale timestamp banners; never presents stale data as live.
6. **Fail-Closed Capability Lock State (`UEmptyState.lockedCapability`):** Displays clear, non-deceptive locked contract indicators when backend capabilities (Gates A–D) are unintegrated.

## 5. Pre-Auth Onboarding & Ethical Motion UX

- **3-Stage Pre-Auth Product Narrative:**
  - `01 — Intelligent Routine Generation`: Explains how course distribution workbooks, faculty allocations, room pools, and rules assemble an organized timetable.
  - `02 — Your University Routine, Made Clear`: Shows how published routines adapt to student batches and teacher slots.
  - `03 — Your Academic Life, Connected`: Highlights real-time cancellation alerts, room/faculty lookup, and course resources.
- **Ethical Motion Safeguards:**
  - Convergence Animation features a lightweight 3-beat storyboard (Inputs -> Core -> Matrix).
  - **Reduced Motion Guard:** `MediaQuery.of(context).disableAnimations` instantly displays the static timetable grid.

## 6. Required Workflow for UX Changes

For any new screen, workflow alteration, or UI review:
1. **Inspect Context:** Map entry point, role, required decisions, system feedback, success state, recovery path, and exit.
2. **Draft Compact UX Brief:** Document user task, proposed hierarchy, responsive behavior, and edge states.
3. **Verify Technical Contracts:** Ensure proposed interactions align with existing GoRouter rules and backend API capability gates.
4. **Implement & Test:** Build within bounded scope and verify all 6 unglamorous states.

## 7. UX Quality Verification Checklist

Before submitting UI work, verify:

1. [x] **Task Execution Efficiency:** Primary task is obvious and completable in minimal taps/clicks.
2. [x] **Obsidian Orbit Aesthetics:** Colors (`#0B0C0E`–`#1F2229`), 1px top-lit specular highlights (`Color(0x12FFFFFF)`), and `#FF7A00` accents match specifications.
3. [x] **Adaptive Layout Integrity:** Evaluates `LayoutBuilder` canvas width; respects `Compact`, `Medium`, and `Expanded` tier rules.
4. [x] **Complete State Matrix:** Loading, empty, filter zero-match, recoverable error, stale data, and capability lock states are styled and tested.
5. [x] **Accessibility & Reduced Motion:** Touch targets meet min dp (48x48 mobile / 40x40 web), keyboard focus rings are visible (`#FF7A00`), and `disableAnimations` instantly bypasses motion.

## Phase 3.5 full-bleed auth composition
AuthResponsiveShell is full-bleed 100vh at >=920px: 58/42 at >=1100px, 50/50 at 920-1099px. Never place an outer Scaffold AppBar across split panes. Back/title/step controls belong atop the right interaction panel; below 920px use a compact top bar above scrollable content. The left pane is an interactive visual instrument with compact telemetry and stage controls; the right owns the editorial H1. Never duplicate the same H1 side by side. Truthful illustrative previews require rich multi-attribute academic cards, not empty gray boxes. Keep footer: Illustrative preview · Published routines depend on departmental approval.

## Cohesive Phase 0-3 implementation standard (Flutter Mobile)
Shared transitions preserve context: key stages/views by actual identity with UAnimatedSwap, use USegmentedControl for custom sliding selectors, and retain all functional state. Password checklist rules must agree with actual validators; do not invent strength requirements. Live elapsed-time progress requires real start/end values. For R1–R16 committee rule correlation on admin/scheduling surfaces, load `ui-backend-policy-correlation`.