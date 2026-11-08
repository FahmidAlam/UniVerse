---
name: visual-ui-qa
description: Conduct evidence-based visual and usability reviews of UniVerse Flutter screens using screenshots, live browser inspection, responsive viewport checks, interaction walkthroughs, and regression comparisons.
---

# UniVerse Visual & Usability Quality Assurance Specification

## 1. Objective & Evidence-Based QA Philosophy

- **Product Target:** Maintain high visual polish, operational trust, accessibility, and zero-regression standards across all UniVerse Flutter views (Student, Teacher, Admin, Pre-Auth).
- **Evidence-First Protocol:** Reviews MUST be grounded in actual rendered UI evidence—live browser inspection, automated widget/golden tests, and verified screenshots across responsive viewports. Never invent praise or claim visual compliance without inspecting real artifacts.
- **Obsidian Orbit Aesthetic Grounding:**
  - Base Background: `#0B0C0E`
  - Rail / Subtle Surface: `#121417`
  - Standard Card Surface: `#17191E`
  - Elevated Modal / Sheet Surface: `#1F2229`
  - Top-Lit Specular Highlight: 1px `#262932` border with selective `Color(0x12FFFFFF)` top-edge specular highlight.
  - Signature Accent: `#FF7A00` for primary call-to-actions, active tab indicators, and keyboard focus rings (`2px solid`).

## 2. Responsive Viewport & Layout Tier Inspection

QA verification MUST evaluate **content-aware canvas width (`LayoutBuilder`)** after deducting navigation sidebars/rails rather than global viewport size alone:

- **Compact Mobile Tier (`<768px` Usable Width):**
  - Verify 5-item thumb-friendly bottom bar (`Today | Routine | Campus | Resources | Alerts` for students; `Today | Teaching | Campus | Class Tools | Alerts` for teachers).
  - Verify `AppDrawer` and `ExploreFabMenu` function correctly on mobile shells.
  - Touch targets MUST meet minimum **48x48 dp** bounds.
- **Medium Tablet/Laptop Tier (`768–1099px` Usable Width):**
  - Verify compact rail navigation (`220px`) + single-column bounded workspace (600–860px canvas).
  - Interactive targets MUST meet minimum **40x40 dp** bounds.
- **Expanded Desktop Tier (`>=1100px` Usable Width):**
  - Verify persistent left sidebar (`250px`) + multi-column workspace (including 58/42 pre-auth web auth split screen).
- **Timetable Matrix Threshold (>=860px Canvas Width):**
  - Verify `RoutineScreen` defaults to the **Weekly Matrix** ONLY when usable content canvas width is >=860px, correctly defaulting or offering **Day List** on narrower canvas widths.

## 3. QA Dimension Inspection Protocols

### A. Visual & Aesthetic Quality (Anti-Slop Audit)
- **Contrast Check:** Verify primary (`#F3F4F6`), secondary (`#B8BCC6`), and muted (`#8A909E`) text meet >= 4.5:1 WCAG AA contrast against dark surfaces (`#0B0C0E`–`#1F2229`).
- **Anti-Slop Checks (Zero "Vibe Code" Tells):**
  - NO gratuitous glassmorphism, background blurs, or heavy neon glow shadows.
  - NO casual emojis as interface icons (must use unified vector icons).
  - NO nested card containers (cards inside cards inside cards).
  - NO mechanical all-caps titles or trailing periods on headers.
- **Spatial Alignment:** Enforce strict 4px grid spacing, consistent control heights (48dp standard, 52dp auth, 36–40dp filter bar), and 2x–3x horizontal optical button padding.

### B. Usability & Unglamorous State Audit
Verify that every screen handles all 6 unglamorous states without crashing or visual degradation:
1. **Loading State:** Verified skeleton shimmers (`#1F2229`) or locked spinners; zero layout shift.
2. **First-Use Empty State:** Calm guidance explaining how to enroll or import data.
3. **Filter Zero-Match State (`UEmptyState.noMatches`):** Acknowledges active search query/filters and presents a 1-tap `Clear filters` button.
4. **Recoverable Error State (`UEmptyState.error`):** Clear human-readable error details + prominent `Retry` button (`Icons.refresh`).
5. **Stale / Offline State:** Explicit offline/stale timestamp banners; never presents stale data as live.
6. **Fail-Closed Capability Lock State (`UEmptyState.lockedCapability`):** Displays clear fail-closed status badges for unintegrated backend contracts (Gates A–D).

### C. Interaction & Accessibility Audit
- **Keyboard Navigation:** Full `Tab` / `Shift+Tab` traversal, visible `#FF7A00` focus rings, and `Escape` key backdrop dismissal for modal overlays.
- **Screen Reader Semantics:** Verify custom widgets use `Semantics(button: true, label: ..., hint: ...)` and empty timetable matrix slots announce full date/time context.
- **Reduced Motion Guard:** Verify `MediaQuery.of(context).disableAnimations` instantly bypasses the 3-beat Pre-Auth Convergence Animation and micro-interactions.

## 4. Defect Severity Classification

Defects identified during QA MUST be categorized using strict severity tiers:

- **Critical:** Prevents task completion, misrepresents academic data/solver status (e.g., displaying simulated schedule as published), or breaks security/auth boundaries.
- **High:** Major workflow friction, broken responsive layouts (e.g., text overflow, clipped actions), or failing keyboard focus trapping.
- **Medium:** Repeated visual inconsistencies, unhandled empty/error states, or minor spatial alignment flaws.
- **Low:** Minor cosmetic polish issues with zero impact on task completion or data clarity.

## 5. Mandatory QA Report Structure

Every visual QA review output MUST include:
1. **Scope & Environment:** Evaluated route, viewport width(s), browser/device, role, and test fixtures used.
2. **Positive Evidence:** Strong architectural or visual elements worth preserving.
3. **Severity-Ranked Findings:** Location, observed defect, user impact, and recommended technical fix.
4. **Verified Code / Test Executions:** Results of `flutter analyze --no-pub`, `flutter test`, and visual regression checks.
5. **Acceptance Sign-Off:** Confirmation of WCAG AA compliance, responsive tier adaptation, and state presenter verification.

## Phase 3.5 mandatory rejection checks
Reject plain Icons.arrow_downward/Icons.south between text boxes, any outer full-width AppBar cutting across an auth split, duplicate H1 titles on both halves, and empty wireframe showcase cards. Inspect real captures and reactive registration lenses at desktop, medium and mobile. Verify continuous runtime motion and zero reduced-motion transient callbacks separately.

## Cohesive Phase 0-3 implementation standard
Inspect both UAnimatedSwap motion and its immediate reduced-motion replacement; test generic USegmentedControl values, keyboard focus, selection/disabled semantics and UPressableScale pointer cancellation. Open regenerated desktop/mobile captures and record screens and viewports inspected. Capture generation alone is not visual approval. Account chrome uses shared avatars; dual shadows/top highlights remain selective.
