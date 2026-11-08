---
name: flutter-web-responsive-ui
description: Build and review responsive UniVerse Flutter interfaces with desktop web as the primary target and tablet/mobile as deliberate adaptive layouts. Use for screens, navigation, forms, tables, dashboards, and layout defects.
---

# UniVerse Web-First Responsive UI & Layout Specification

## 1. Product Target & Responsive Core Strategy

- **Web-First Adaptation:** Design primarily for desktop browser productivity (`Expanded >=1100px` and `Medium 768–1099px`), then adapt intentionally for mobile (`Compact <768px`). Never stretch a phone layout into a sparse desktop view or crush desktop admin tools onto a mobile screen.
- **Content-Aware Breakpoint Tiers (Decision D-04):** Layout decisions MUST be evaluated against **usable content canvas width (`LayoutBuilder`)** after deducting navigation sidebars/rails, rather than raw global viewport width:
  - **Compact Tier (`<768px` Usable Width):** 5-Item Role-Aware Bottom Navigation Bar (`AppBottomNav`), single-column vertical stack, minimum $48\times 48\text{dp}$ touch targets. `AppDrawer` & `ExploreFabMenu` temporarily retained.
  - **Medium Tier (`768–1099px` Usable Width):** Compact Left Navigation Rail (`220px` width) + single-column bounded workspace ($600–860\text{px}$ content width), minimum $40\times 40\text{dp}$ interactive targets.
  - **Expanded Tier (`>=1100px` Usable Width):** Persistent Left Sidebar (`250px` width) + 2-Column Asymmetric Workspace (e.g., 58/42 split or master-detail pane).
  - **Matrix Canvas Threshold ($\ge 860\text{px}$ Canvas Width):** Timetable displays default to the **Weekly Matrix** view ONLY when usable canvas width is $\ge 860\text{px}$. On narrower canvas widths, automatically default to or offer the **Day List** toggle.

## 2. Visual System Integration (Obsidian Orbit Aesthetics)

All responsive layouts MUST utilize the **Obsidian Orbit** visual hierarchy and dark-mode surface lightness ramp:

- **Surface Depth Hierarchy:**
  - Base Background (`background`): `#0B0C0E`
  - Navigation Sidebar / Rail (`bgSubtle`): `#121417`
  - Standard Card Surface (`cardBg`): `#17191E`
  - Elevated Modal / Popover (`elevatedCard`): `#1F2229`
- **Border & Highlight Discipline:**
  - Standard Border (`#262932`, 1px solid).
  - Top-Lit Specular Highlight (`Color(0x12FFFFFF)`): Selective 1px top-edge border highlight on cards to establish dark-mode tactile depth without heavy dropshadows or glassmorphic blur.
- **Primary Brand Accent:** `#FF7A00` (Hover: `#FF8F26`, Pressed: `#E66A00`) for primary action buttons, active tab indicators, and keyboard focus rings.
- **Text & Contrast Standards:** Primary text `#F3F4F6`, Secondary `#B8BCC6`, Muted `#8A909E` (guaranteeing $\ge 4.5:1$ contrast against dark surfaces for WCAG AA compliance).

## 3. Web Navigation, Role Shells & URL Durability

- **Role-Aware Navigation Matrix:**
  - **Student Shell:** `Today (/student/dashboard) | Routine (/student/routine) | Campus (/rooms) | Resources (/student/resources) | Alerts (/notifications)`
  - **Teacher Shell:** `Today (/teacher/dashboard) | Teaching (/teacher/routine) | Campus (/rooms) | Class Tools (/teacher/manage-classes) | Alerts (/notifications)`
  - **Admin Shell:** Command Center (`/admin/dashboard`), Routine Operations (`/admin/routine`), Scheduling Workbench · Preview (`/admin/scheduling` with explicit `PREVIEW` pill), Engine Baseline (Faculty/Rooms/Eligibility), Campus Ops.
- **URL Semantics & Deep Link Durability:**
  - Preserve direct web entry, browser back/forward navigation, page refreshes, and URL query params (`?room=`, `?code=`, `?tab=`, `?revision=`).
  - Do not create stateful desktop views that lose filter/selection context on page refresh.

## 4. Web-First Onboarding & Auth Split-Screen (`>=1100px`)

- **Art-Directed 58/42 Web Composition:**
  - On `Expanded` web viewports ($\ge 1100\text{px}$), pre-auth onboarding and authentication screens (`LoginScreen`, `RoleSelectionScreen`, `VerifyEmailScreen`) utilize a **58% interactive showcase pane** (left) and **42% bounded interaction card** ($420–460\text{px}$ max width, right).
  - The 58% showcase pane hosts the **3-Stage Pre-Auth Narrative** (`01 — Intelligent Routine Generation`, `02 — Your University Routine, Made Clear`, `03 — Your Academic Life, Connected`) and the 3-beat lightweight **Convergence Animation**.
  - On `Medium` viewports ($768–1099\text{px}$), adapt to a 50/50 compact split or top interactive showcase strip. On `Compact` mobile ($<768\text{px}$), stack into a focused vertical layout.

## 5. Data-Heavy Admin & Grid Guidelines

- **Dense Workspace Layouts (`/admin/scheduling` & `/admin/routine`):**
  - Use sticky header rows and sticky time-slot columns on data grids so academic context is preserved during scrolling.
  - Implement 2D matrix focus traversal (Arrow keys / Tab order across days and period slots).
  - Empty grid slots MUST be semantically announced: `Semantics(label: "Monday Period 2, 09:30 AM to 10:45 AM: Unscheduled slot", button: true)`.
- **Side Panel & Inspector Ergonomics:**
  - On `Expanded` viewports, details and class tools open in a persistent docked right-hand inspector panel ($320–380\text{px}$ width).
  - On `Medium` and `Compact` viewports, inspectors seamlessly degrade to centered modal sheets or slide-over bottom sheets (`Curves.easeInOutCubic`, 220ms).
- **Unglamorous State Presenters (Psychology of Premium Apps):**
  - **First-Use Empty State:** Calm guidance explaining how to import or generate data.
  - **Zero-Match Filter State:** Acknowledges active search query/filters with a 1-tap `Clear filters` button.
  - **Recoverable Error State:** Clear human-readable error details + actionable `Retry` button (`Icons.refresh`).
  - **Truthful Capability Lock State:** Displays fail-closed status badges for unintegrated backend contracts (Gates A–D) rather than showing fake green indicators or synthetic solver numbers.

## 6. Flutter Web Technical Implementation Rules

- **Responsive Constraints (`LayoutBuilder` over Device Checks):**
  - ALWAYS calculate responsive layouts using `LayoutBuilder` child constraints or `BoxConstraints`. Never use raw `Platform.isAndroid` or `MediaQuery.of(context).size.width` alone to dictate workspace layout.
- **Performance & Repaint Isolation:**
  - Enclose heavy grid structures, animated showcase panels, and list items inside `RepaintBoundary` widgets.
  - Avoid `IntrinsicHeight` or `IntrinsicWidth` inside large dynamic lists or timetable grids.
  - Debounce search/filter inputs by **300ms** to avoid layout thrashing during web user typing.
- **Web Browser Safety:**
  - Do not use native desktop/mobile filesystem APIs directly (`dart:io` file operations). Keep file uploads/downloads compatible with web browser blobs and bytes.
  - Ensure all interactive elements feature appropriate hover cursors (`SystemMouseCursors.click`) and visible keyboard focus rings (`#FF7A00`, 2px solid).

## 7. Responsive Acceptance Verification Checklist

Before submitting any updated screen, verify:

1. [x] **Zero Layout Shifts / Overflows:** No horizontal yellow-black overflow bars across 390px, 768px, 1024px, 1280px, and 1440px test viewports.
2. [x] **Usable Canvas Breakpoints:** `LayoutBuilder` canvas width properly deducts sidebar width before selecting matrix vs list views.
3. [x] **URL & Router Integrity:** GoRouter deep links, query parameters, and browser back/forward buttons function correctly.
4. [x] **Obsidian Orbit Styling:** Dark surface tokens (`#0B0C0E`–`#1F2229`) and top-lit 1px specular highlights (`Color(0x12FFFFFF)`) render correctly.
5. [x] **Touch & Keyboard Targets:** Min $48\times 48\text{dp}$ targets on Mobile, min $40\times 40\text{dp}$ targets on Web/Desktop, visible focus rings on keyboard tab navigation.
6. [x] **State Presenters Verified:** First-use empty, filter zero-match, recoverable error, and fail-closed capability lock states handle all edge cases cleanly.

## Phase 3.5 full-bleed auth composition
AuthResponsiveShell is full-bleed 100vh at >=920px: 58/42 at >=1100px, 50/50 at 920-1099px. Never place an outer Scaffold AppBar across split panes. Back/title/step controls belong atop the right interaction panel; below 920px use a compact top bar above scrollable content. The left pane is an interactive visual instrument with compact telemetry and stage controls; the right owns the editorial H1. Never duplicate the same H1 side by side. Truthful illustrative previews require rich multi-attribute academic cards, not empty gray boxes. Keep footer: Illustrative preview · Published routines depend on departmental approval.

## Cohesive Phase 0-3 implementation standard
Use USegmentedControl for custom equal-slot selectors; constrain width within rows and keep labels readable at narrow widths. Shared account pills collapse their text at narrow widths. Showcase perspective belongs only to noncompact compositions. Preserve durable URLs and mobile drawer/FAB behavior.
