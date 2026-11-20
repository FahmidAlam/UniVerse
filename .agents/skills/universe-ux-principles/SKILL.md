---
name: universe-ux-principles
description: Apply product-level UX reasoning to UniVerse screens and workflows. Use when designing, reviewing, simplifying, or changing user journeys, forms, navigation, information hierarchy, defaults, feedback, or decision points.
---

# UniVerse UX Principles & User Journey Specification

## 1. Product Target & UX Philosophy

- **Operational Trust & Task Completion:** UniVerse optimizes for successful, low-friction execution of real university tasks—routine consultation, class updates, room lookup, faculty schedule checks, and administrative timetable generation. Avoid visual novelty, deceptive engagement patterns, or e-commerce conversion tricks.
- **Obsidian Orbit Design System Alignment:** All user journeys MUST strictly adhere to the **Obsidian Orbit** design identity:
  - Base Background: `#0B0C0E`
  - Subtle / Rail Surface: `#121417`
  - Standard Card Surface: `#17191E`
  - Elevated Modal / Sheet Surface: `#1F2229`
  - Selective Top-Lit Borders: 1px `#262932` with a subtle top-edge specular highlight (`Color(0x12FFFFFF)`) to establish dark-mode tactile depth.
  - Signature Accent: `#FF7A00` for primary actions, focus rings, and active role cues.

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

## Cohesive Phase 0-3 implementation standard
Shared transitions preserve context: key stages/views by actual identity with UAnimatedSwap, use USegmentedControl for custom sliding selectors, and retain all functional state. Password checklist rules must agree with actual validators; do not invent strength requirements. Live elapsed-time progress requires real start/end values.


## R1–R16 Committee Scheduling Rules & Supporting Modules UI/UX Standard (Phase 5/6 Alignment)

When designing or implementing administrative configuration screens (`ManageRoomsScreen`, `ManageFacultyScreen`, `ManageCourseEligibilityScreen`, `TimetableSettingsScreen`), the `SchedulingWorkspaceScreen` panes (`SchedulingConfigurationPane`, `SchedulingReadinessPane`, `DistributionRecordInspector`), or supporting campus modules (`RoomsScreen`, `FindTeacherScreen`, `ResourcesScreen`, `NotificationsScreen`, `CampusBroadcastScreen`), enforce these mandatory rules:

### 1. Complete UI Configurability of All 16 Committee Rules (R16 Mandate)
Never hardcode scheduling assumptions invisibly. Expose structured, human-readable controls for all 16 rules across Live Admin Configuration (`/admin/timetable/*`) and the Scheduling Workbench (`/admin/scheduling`):
- **R1 & R2 (Section Calendar & Batch Parity):** 2 consecutive weekend days off per section (R1); equal weekly days off across sections of the same batch with max ±1 day variance (R2).
- **R3 (Section Compactness):** Zero 2-slot consecutive gaps for any section; 1-slot gap + scheduled break permitted.
- **R4 & R5 (Cross-Department Faculty Windows):** CSE faculty external-department teaching slot blocker (R4); External/Guest faculty (GED, EEE, Physics, English) strict available day/slot window matrix (R5).
- **R6 & R7 (Faculty Category & Off-Day Bounds):** Explicit `Permanent` vs. `Adjunct` category badge. Adjunct workload band: 2 courses -> 2 days, 3 courses -> 3–4 days, >=4 courses -> 4–5 days (R6). Permanent faculty: 4–5 working days, strictly 2–3 weekly days off (R7).
- **R8 & R9 (Faculty Slot Preferences & SUST Adjunct Compactness):** Priority day/time slot preference matrix (R8); SUST Adjunct mode enforcing compact single-half-day scheduling (all before break OR all after break) and max daily gap <= 2 consecutive slots (R9).
- **R10, R11 & R14 (Dynamic Room Pools & Shared Lab Windows):** Semester active-pool toggle for general theory classrooms (R14); explicit shared-lab availability matrices for the two EEE-owned `ECL` labs (R10) and exclusive `Physics Lab` course-code binding + conflict window blocking (R11).
- **R12 & R13 (Sessional & 1–2 Credit Theory Distribution):** Sessionals: 1 or 1.5 credits -> 2 classes/week; 2 credits -> 3 classes/week with preferred 2-slot consecutive same-lab placement (R12). 1–2 credit CSE theory courses -> completed in 1 day across 2 consecutive slots in the same classroom (R13).
- **R15 (Flexible 6-Slot vs. 7-Slot Daily Grid):** First-class `USegmentedControl<int>` switching between 6-slot and 7-slot daily period configurations with live period-header preview.

### 2. Visual & Structural Execution Laws (Video Research Synthesis)
- **"Walmart Receipt" Dissolved Cards:** Group R1–R16 settings and CRUD lists inside top-lit `UCard(isTopLit: true)` containers separated by 1px `AppColors.border` horizontal lines. Never nest 4-sided cards inside cards.
- **"Checkbox Off = Gray" Signaling:** Standard committee baseline rules (R1–R15 in default state) use calm slate-gray badges (`DEFAULT BASELINE`). Reserve `AppColors.warning` (Amber) for overridden rules/soft preferences, `AppColors.error` (Crimson) for hard R4/R5/R7/R10/R11 availability conflicts, and `AppColors.primary` (Orange) / `AppColors.info` (Cyan) for active selection.
- **Show, Don't Tell (Interactive Slot Mini-Grids):** Represent R4/R5/R8 faculty time windows and R10/R11 ECL/Physics lab availability using interactive compact `Day × Slot` pill grids (6 or 7 slots per R15) rather than raw text strings.
- **Usable-Width Master-Detail Architecture:** Evaluate all layouts via `LayoutBuilder` post-sidebar usable width:
  - `>= 900px` usable width: 55/45 or 60/40 Master-Detail split (`UMasterDetailWorkspace`) with docked right-hand inspector and URL query parameter sync (`?room=`, `?teacher=`, `?faculty=`, `?rule=`).
  - `< 900px` usable width: Single-axis list/grid with `showUAdaptiveModal` (centered top-lit modal `>= 768px`, single-handle bottom sheet `< 768px`).