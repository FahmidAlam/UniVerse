---
name: flutter-interaction-motion
description: Design and implement purposeful Flutter Mobile (lib/, Android & iOS) interaction states, transitions, AppMotion tokens, gestures, and reduced-motion safeguards for UniVerse.
---

# UniVerse Flutter Mobile Interaction & Motion Specification

> **Platform Scope:** Governs **Flutter Mobile (`lib/`, Android & iOS)** under Obsidian Orbit (`AppMotion`, `UAnimatedSwap`, `UPressableScale`, `USegmentedControl`). For React Web (`apps/web/`), load `react-web-motion-and-craft`.

## 1. Core Principles & Design Intent

- **Purposeful Communication:** Motion in UniVerse must strictly serve to explain state changes, preserve spatial context during page transitions, or provide instantaneous tactile feedback. It must never be purely theatrical.
- **Accessibility & Utility First:** Content readability, keyboard navigation, and operational execution speed always take precedence over animation. Every screen and workflow must remain 100% functional with motion disabled.
- **Obsidian Orbit Aesthetic Integration:** Interaction states must align with the cool dark surface range (`#0B0C0E` to `#1F2229`) and primary brand accent (`#FF7A00`), using subtle top-lit surface highlights instead of heavy glow or intrusive bounce effects.

## 2. Standard Motion Tokens, Durations & Curves

Coding agents and developers MUST use standardized Flutter duration and curve tokens rather than inline magic numbers:

| Motion Category | Duration Token | Curve Token (`Curves`) | Primary Use Cases |
| :--- | :--- | :--- | :--- |
| **Micro / State** | `kDurationFast` (150ms) | `Curves.easeOutCubic` | Button hover, focus ring outline, toggle switches, icon state changes. |
| **Panel / Sheet** | `kDurationMedium` (220ms) | `Curves.easeInOutCubic` | Modal bottom sheet entrance/exit, sidebar collapse, dropdown popovers. |
| **Page / Route** | `kDurationPage` (280ms) | `Curves.fastOutSlowIn` | Tab switching, screen transitions, view layout shifts. |
| **Stage 01 Storyboard** | `kDurationBeat1` (450ms)<br>`kDurationBeat2` (650ms)<br>`kDurationBeat3` (700ms) | `Curves.easeOutQuad` | Multi-beat Pre-Auth Onboarding Convergence Animation (Inputs -> Core -> Matrix). |

- **Exit Speed Rule:** Exits must be 15–20% faster than entrances (e.g., 180ms dismiss vs 220ms slide-in) to enhance perceived system responsiveness.
- **No Gratuitous Elasticity:** Never use `Curves.bounceIn`, `Curves.elasticOut`, or spring simulations for standard academic timetable operations.

## 3. Interactive Component State Matrix

Every interactive component (Buttons, Class Cards, Room Tiles, Form Fields) MUST implement an explicit state matrix:

1. **Idle / Default State:** Base surface layer (`#14161C`) with standard border contrast (`#2A2E39`).
2. **Hover State (Web/Desktop):** Elevated surface fill (`#1F2229`) with top-lit border highlight.
3. **Focus State (Keyboard):** Prominent 2px `#FF7A00` outline with a 2px offset ring; high-contrast focus indicator.
4. **Pressed State (Active Tap):** Scaled down slightly (`Transform.scale(scale: 0.98)` over 100ms) or darker fill (`#0B0C0E`).
5. **Disabled State:** Opacity reduced to `0.38`, hit testing disabled (`IgnorePointer`), cursor set to `SystemMouseCursors.forbidden`.
6. **Async Loading State:** Button dimensions locked (prevent layout shift), text replaced by an inline 18px `CircularProgressIndicator(strokeWidth: 2, color: #FF7A00)` or skeletal shimmer. Action disabled to prevent double submission.
7. **Clash / Warning State:** Surface fill set to dark amber/red tint (`#2C1215`), accompanied by `Icons.warning_amber_rounded` and non-color semantic text.

## 4. Onboarding Convergence Animation & Motion Safeguards

- **3-Beat Pre-Auth Storyboard Execution:**
  - **Beat 1 (0–450ms):** Course Distribution, Faculty, and Room input pills slide inward along staggered orbital paths (`Curves.easeOutCubic`).
  - **Beat 2 (400–1050ms):** Connector line pulse converges into the central UniVerse Orbit Engine Core with a 180° rotation.
  - **Beat 3 (950–1650ms):** Structured 4x3 timetable grid populates class blocks with a 50ms row stagger.
- **Truthful Motion Rule:** Never animate synthetic progress numbers or fake solver metrics before verified backend execution.
- **Reduced Motion Guard (Mandatory):**
  ```dart
  final reduceMotion = MediaQuery.of(context).disableAnimations;
  if (reduceMotion) {
    // Instantly display final static timetable matrix state
    return StaticTimetableMatrixView();
  }
  ```

## 5. Mobile Gestures & Touch Feedback

- **Touch Target Dimensions:** Minimum 48x48 dp touch target on Mobile (`Compact <768px`) and 40x40 dp on Web (`Medium` / `Expanded`).
- **Modal Sheet Gestures:** Drag-to-dismiss modal sheets on mobile must monitor drag velocity (`velocity.pixelsPerSecond.dy > 300`) or drag threshold (>50% container height) to trigger predictable dismissal.
- **Swipe Actions:** Class cancellation and schedule adjustment sheets must provide clear haptic feedback (`HapticFeedback.lightImpact()`) upon threshold crossing.

## 6. Flutter Implementation Discipline & Performance Rules

- **Repaint Boundary Isolation:** Always wrap animated subtrees (`AnimatedSwitcher`, `AnimationController`, `Shimmer`) in a `RepaintBoundary` widget to avoid repainting the parent dashboard or timetable canvas.
- **AnimationController Lifecycle Rules:**
  - Initialize controllers with `vsync: this` using `SingleTickerProviderStateMixin`.
  - ALWAYS call `controller.dispose()` inside the `StatefulWidget` `dispose()` method to prevent memory leaks.
  - Store static `Tween` objects as `final` members outside `build()` methods to prevent object allocations during frames.
- **Layout Shift Prevention:** Never animate layout height/width of parent containers during list loading. Use fixed-height containers or `Sliver` layouts.

## 7. Concrete Operational Verification Solutions

Based on UniVerse's Flutter architecture and UI/UX design video standards, Section 7 requirements are explicitly defined as follows:

1. **Operational Communication:**
   - **Spatial Hierarchy:** Sliding drawers (`220ms Curves.easeInOutCubic`) communicate context preservation during class/room detail drill-down.
   - **Async Execution:** Inline progress rings (`#FF7A00`) signal engine solver processing or backend authentication verification without blocking layout stability.
   - **Clash Awareness:** Visual surface transitions (`#2C1215` fill + `Icons.warning_amber_rounded`) signal room/faculty double-booking conflicts.
   - **Pre-Auth Engine Story:** Stage 01 3-beat Convergence Animation visually communicates how raw course workbooks, rooms, and faculty inputs merge into an organized routine.

2. **Zero-Motion Readability & Utility Guarantee:**
   - When `MediaQuery.of(context).disableAnimations` is `true`, all components immediately jump to rest states (0ms duration).
   - Pre-Auth Onboarding instantly displays the static 4x3 timetable grid without playing entrance frames.
   - Typography, contrast ratios, and touch targets maintain 100% WCAG AA accessibility standards regardless of animation state.

3. **Layout Stability & Repaint Performance Protection:**
   - **Repaint Boundaries:** Every dynamic component (`AnimatedSwitcher`, loading shimmer, onboarding core) is enclosed in a `RepaintBoundary` to isolate repaints from parent canvases.
   - **Fixed Spatial Containers:** Control buttons, tab bars, and timetable slot cards maintain locked dimensions to eliminate layout shifts (`0px` height/width recalculation).
   - **Controller Lifecycle Discipline:** All `AnimationController` instances are bound to `SingleTickerProviderStateMixin` and disposed cleanly in `dispose()` to prevent memory leaks and GPU drops.

4. **Keyboard Focus & Assistive Technology Integration:**
   - **Visual Focus Rings:** All interactive state changes are paired with a prominent 2px `#FF7A00` focus ring outline for keyboard users (`FocusNode` + `FocusTraversalGroup`).
   - **Screen Reader Announcements:** Asynchronous state changes (e.g., class cancellations, filter updates) trigger explicit `SemanticsService.announce()` messages.
   - **Overlay Focus Trapping:** Modal sheets, popovers, and drawers restrict focus to their scope (`FocusScope`) and cleanly restore focus to the trigger element upon pressing `Escape`.

## Phase 3.5 dual-mode kinetic storytelling
Normal runtime (MediaQuery.disableAnimations == false): hero showcases, splash orbit and verification radar MUST use continuous CustomPainter/ticker ambient orbital rings, Bezier energy pulses, staggered entrance and hover/focus elevation. Isolate repaints and dispose controllers; never delay initialization or fabricate backend progress.
Reduced motion/test mode (disableAnimations == true): immediately controller.stop() on every repeating controller and pin a rich fully assembled rest state, with transientCallbackCount == 0. Also respect accessibleNavigation and TickerMode. No flashing.

## Cohesive Phase 0-3 implementation standard
AppMotion in lib/core/theme/app_motion.dart supersedes the baseline duration table above: micro 140ms, fast 220ms, medium 340ms, slow 520ms; snappy, magnetic and fluid curves. Use UAnimatedSwap for keyed route-adjacent content, UPressableScale for pointer feedback, and USegmentedControl for custom sliding selection. AppMotion.reduced also respects accessibleNavigation and TickerMode; remove outgoing animated content immediately in reduced mode.

## Precision Motion & Everyday UI Transitions (Phase A & B)
1. **Everyday Transitions (No Elastic Bounce):**
   - In `u_adaptive_overlay.dart`, dropdown popovers, dialogs, and modal sheets: replace `Curves.easeOutBack` with **`Curves.easeOutCubic`**. Everyday operational software must feel crisp, decisive, and stable—zero rubber-band or cartoon bounce on standard administrative interfaces.
2. **Asymmetric Durations (Fast Exits):**
   - Entrances: `180–220ms` (`Curves.easeOutCubic`), starting with scale `0.95` and opacity `0.0`.
   - Exits: **15–20% shorter** (`140–160ms`) (`Curves.easeInCubic`) so dismissal feels instantaneous.
3. **Micro-Scale Press Feedback:**
   - Tap/click interactions use `0.97` press scaling (`UPressableScale`) without continuous tweening while held down.
   - Trigger a subtle confirmation pulse/toast upon saving records.

