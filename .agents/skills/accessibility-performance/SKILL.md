---
name: accessibility-performance
description: Review and implement accessible, inclusive, and performant UniVerse Flutter Mobile (lib/, Android & iOS) interfaces — WCAG AA contrast, Semantics, focus traversal, reduced motion, and rebuild minimization.
---

# UniVerse Flutter Mobile Accessibility & UI Performance Specification

> **Platform Scope:** Governs **Flutter Mobile (`lib/`, Android & iOS Student/Teacher)** under Obsidian Orbit (`#0B0C0E` + `#FF7A00`). For standalone React Web (`apps/web/`), load `react-web-academic-design-system` + `react-web-motion-and-craft`. Legacy Flutter Web (`web/`, `lib/features/admin/`) is frozen.

## 1. Accessibility Baseline & Obsidian Orbit Contrast Standards

- **Color Contrast Verification (Obsidian Orbit Tokens):**
  - Verify actual contrast ratios using WCAG AA standards (4.5:1 for normal text, 3:1 for large text >= 18pt and non-text UI elements).
  - **Primary Accent (`#FF7A00`):** Must be paired with high-contrast text overlay (e.g., `#0B0C0E` dark text) on filled buttons.
  - **Dark Surfaces (`#0B0C0E` to `#1F2229`):** Body text (`#E6E8EC`) and muted labels (`#949BA6`) must maintain a minimum 4.5:1 contrast against their respective background surface.
  - **Focus Rings & Borders:** Active keyboard focus indicators must use a prominent visual outline (e.g., `#FF7A00` 2px solid ring) with a minimum 3:1 non-text contrast against surrounding surfaces.
- **Multi-Modal Communication (No Color-Alone Indicators):**
  - Status, validation errors, section selection, and routine clashes MUST include textual labels, distinct icons, or tactile patterns alongside color changes.
  - Clash warning tiles in the Timetable Grid must feature `Icons.warning_amber_rounded` + explicit text ("Conflict: Room Double-Booked") rather than just a red surface fill.
- **Semantic Structure & Roles:**
  - Wrap custom controls and cards with `Semantics(button: true, label: ..., hint: ...)` to ensure screen readers announce clear roles and actions.
  - Avoid redundant announcements (e.g., do not write "Button" inside the semantic label when `button: true` is set).
  - Use `Header` semantics and logical heading hierarchies (`Semantics(header: true)`) on screen titles and dashboard section headers.

## 2. Keyboard Navigation, Focus & Overlay Boundaries

- **Focus Trapping & Overlay Restoration:**
  - When opening dismissible overlays (`AppDrawer`, modal bottom sheets, confirmation dialogs, or dropdown menus), keyboard focus MUST be trapped within the overlay scope (`FocusScope`).
  - Pressing `Escape` or tapping the backdrop must dismiss the overlay and cleanly return focus to the triggering element.
- **Logical Tab Order & Short-Cuts:**
  - Wrap multi-column layouts and custom form grids in `FocusTraversalGroup` with `ReadingOrderTraversalPolicy` or `OrderedTraversalPolicy`.
  - Ensure all primary interactive cards (e.g., Class Cards, Room Tiles) are reachable via `Tab` / `Shift+Tab` and activatable via `Enter` or `Space`.
- **Touch Target Padding:**
  - All interactive tap targets must maintain a minimum touch area of **48x48 dp** on mobile (`Compact <768px`) and **40x40 dp** on web/desktop (`Medium` / `Expanded`). Use `InkWell` or `IconButton` with explicit constraints.

## 3. Dense Timetable & Admin Grid Accessibility

- **2D Matrix Focus Traversal:**
  - Dense timetable grids (`Weekly Matrix` and `/admin/scheduling` Workbench) must support predictable directional focus navigation (Arrow Keys or Tab order across days and period slots).
- **Slot Announcement Patterns:**
  - Empty or unscheduled timetable cells must NOT be announced as vague blank elements. Wrap empty slot cells in `Semantics(label: "Monday Period 2, 09:30 AM to 10:45 AM: Unscheduled slot", button: true)`.
  - Scheduled class slots must announce full context: `"Monday Period 1, 08:00 AM: CSE-401 Lecture, Room 302, Prof. MSR"`.
- **Sticky Headers & Scrolling Reachability:**
  - Timetable headers (Days of Week and Time Slot headers) must remain visible and sticky during scrolling while preserving semantic connection to grid columns/rows.

## 4. Motion & Animation Accessibility

- **Reduced Motion Guard:**
  - Always check `MediaQuery.of(context).disableAnimations` or `MediaQuery.of(context).accessibleNavigation`.
  - When reduced motion is requested, instantly bypass the **Stage 01 Pre-Auth Convergence Animation** and micro-interactions, displaying the final static multi-column layout without delay or transition.
- **Non-Flashing Feedback:**
  - Avoid rapid blinking or pulsing UI elements (>= 3Hz) for live indicators. Connectivity and engine status indicators must use steady color + text badge updates.

## 5. Flutter Performance & Web Rendering Principles

- **Repaint Isolation & Narrow Scope State:**
  - Wrap heavy or frequently updated subtrees (`WeeklyMatrixGrid`, `ConvergenceAnimationWidget`, live countdown timers, administrative table rows) in `RepaintBoundary` widgets to prevent full-screen canvas repaints.
  - Keep state listeners scoped locally (using `ValueNotifier`, `Selector`, or narrow `Consumer` widgets) to rebuild only the targeted cell or badge.
- **Lazy Building & Const Discipline:**
  - Enforce `ListView.builder`, `GridView.builder`, or `SliverList` for lists exceeding 8 items. Never instantiate long child lists eagerly inside `SingleChildScrollView`.
  - Enforce `const` constructors on all static subtrees to optimize element tree caching.
- **Debounced High-Frequency Work:**
  - Debounce search input (`Find Teacher`, `Room Lookup`, `Scheduling Workbench Filters`) by **300ms** to eliminate unnecessary intermediate filtering or database queries without creating UI latency.
- **Asset & Font Optimization:**
  - Ensure all network images feature memory caching (`memCacheWidth` / `memCacheHeight`), and vector icons use unified `IconData` or optimized SVG paths.

## 6. System Status & Error Recovery Verification

- **Real Engine & Network State Visualizers:**
  - Stale connectivity or offline solver statuses must be explicitly checked. Do NOT display a green/live status badge without an active health check or ping confirmation.
- **Preserved Error Details & Actionable Recovery:**
  - Form validation and network failures must present human-readable error messages alongside actionable retry buttons (`ElevatedButton` with `Icons.refresh`).

## 7. Mandatory Validation Evidence Requirements

Before marking any UI task complete, developers and AI coding agents MUST execute and document validation across five distinct levels:

1. **Static Analysis & Analyzer Checks:**
   - Execute `flutter analyze` — 0 warnings or errors allowed on touched files.
2. **Widget & Semantic Unit Tests:**
   - Execute targeted semantic tests checking `tester.getSemantics(...)` labels, hints, and focus traversal.
3. **Browser & Keyboard Traversal Verification:**
   - Verify full keyboard-only navigation (`Tab`, `Shift+Tab`, `Enter`, `Space`, `Esc`) on Web builds.
4. **Assisted Technology & Screen Reader Checks:**
   - Test accessibility using VoiceOver (macOS/iOS), TalkBack (Android), or NVDA/ChromeVox.
5. **Performance & Profiling Evidence:**
   - Verify 60fps rendering in Flutter DevTools Performance Overlay (zero red jank bars during scrolling or tab transitions).

## Phase 3.5 dual-mode kinetic storytelling
Normal runtime (MediaQuery.disableAnimations == false): hero showcases, splash orbit and verification radar MUST use continuous CustomPainter/ticker ambient orbital rings, Bezier energy pulses, staggered entrance and hover/focus elevation. Isolate repaints and dispose controllers; never delay initialization or fabricate backend progress.
Reduced motion/test mode (disableAnimations == true): immediately controller.stop() on every repeating controller and pin a rich fully assembled rest state, with transientCallbackCount == 0. Also respect accessibleNavigation and TickerMode. No flashing.

## Cohesive Phase 0-3 implementation standard
Use AppMotion for new animation timing and reduced-motion policy. USegmentedControl uses native focusable buttons with selected/disabled semantics; UPressableScale must not consume gestures. Repeating indicators stop under reduced motion. Live class progress uses a disposed low-frequency timer, never frame-by-frame full-screen rebuilds. Record actual keyboard, screen-reader and profiling evidence separately from widget tests.
