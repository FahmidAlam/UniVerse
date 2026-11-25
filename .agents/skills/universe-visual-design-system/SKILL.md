---
name: universe-visual-design-system
description: Design and refine UniVerse Flutter Mobile's (lib/, Android & iOS) Obsidian Orbit visual language, spacing, typography, dark/orange color tokens, and shared U* widgets. Do NOT load for React Web (apps/web/).
---

# UniVerse Flutter Mobile Visual Design System (Obsidian Orbit)

> **Platform Scope:** Exclusively governs **Flutter Mobile (`lib/`, Android & iOS Student/Teacher)** using centralized Obsidian Orbit tokens (`lib/core/theme/`). Never apply `#0B0C0E` + `#FF7A00` tokens to standalone React Web (`apps/web/`), which uses `react-web-academic-design-system`. Legacy Flutter Web (`web/`, `lib/features/admin/`) is frozen.

## 1. Objective & Obsidian Orbit Design Identity

- **Product Target:** Create a recognizable, calm, high-contrast, professional academic operations system. UniVerse's visual identity is anchored in the **Obsidian Orbit** dark-mode visual system, combining a perceptual dark surface ramp with a signature primary accent.
- **Surface Lightness Ramp:**
  - Base Background (`background` / `bgDark`): `#0B0C0E`
  - Navigation Rail / Sidebar / Subtle Surface (`bgSubtle`): `#121417`
  - Standard Card Surface (`cardBg`): `#17191E`
  - Elevated Modal / Sheet / Hover Surface (`elevatedCard`): `#1F2229`
  - Interactive Hover / Selected Surface (`surfaceInteractive`): `#272B33`
- **Selective Top-Lit Specular Highlight:**
  - Standard Border: 1px solid `#262932`
  - Top-Edge Specular Highlight (`borderHighlight`): `Color(0x12FFFFFF)` (subtle ~7% white top border to establish dark-mode tactile depth without heavy drop shadows or glassmorphic blur).
- **Brand & Semantic Color Palette:**
  - Signature Accent (`primary`): `#FF7A00` (Hover: `#FF8F26`, Pressed: `#E66A00`, Focus Ring: `#FF7A00` 2px solid).
  - Primary Text (`textPrimary`): `#F3F4F6` (crisp off-white to prevent halation on `#0B0C0E`).
  - Secondary Text (`textSecondary`): `#B8BCC6`.
  - Muted / Caption Text (`textMuted`): `#8A909E` (boosted from `#6E7278` to guarantee >= 4.5:1 text contrast for WCAG AA compliance).
  - Status Indicators (Bright foreground + dimmed dark container fill):
    - Success: `#10B981` + Container `#062E22`
    - Warning: `#F59E0B` + Container `#302007`
    - Error: `#EF4444` + Container `#331014`
    - Info / Analytical Accent: `#38BDF8` + Container `#0F2342`

## 2. Theme Governance & Safety Protocols

- **Centralization Rule:** All design tokens MUST be defined in `lib/core/theme/` (`app_colors.dart`, `app_text_styles.dart`, `app_spacing.dart`, `app_theme.dart`). Never inline raw hex values, magic font sizes, or ad-hoc padding constants in screen files.
- **Backward Compatibility:** Preserving public getters in `AppColors` and existing component parameters is mandatory. New semantic tokens must map cleanly alongside existing theme getters so all screens compile with zero warnings or broken references.
- **No Forking or Parallel Palettes:** Do not create conflicting local themes or inline custom color definitions for single screens. Fix visual hierarchy by refining central semantic tokens or updating shared `U*` widgets.

## 3. Typography, Layout Geometry & 4px Grid

- **Strict 4px Spatial Grid:**
  - Base spacing scale: `xs: 4`, `sm: 8`, `md: 12`, `lg: 16`, `xl: 20`, `xxl: 24`, `xxxl: 32`.
  - Spatial Hierarchy: Intra-element gap (8px) < Card inner padding (16px) < Section gap (24px).
- **Control Heights & Touch Targets:**
  - Standard Control Height: **48dp** (default buttons, form inputs).
  - Primary Onboarding / Auth Inputs: **52dp**.
  - Compact Filter Bar Controls: **36dp–40dp** (with matched row heights and minimum 40x40 dp touch target on web/desktop, 48x48 dp on mobile).
- **Optical Padding & Corner Radii:**
  - Button Padding: Horizontal padding MUST be 2x–3x vertical padding (e.g., 16px horizontal / 8px vertical for compact; 24px horizontal / 12px vertical for standard).
  - Radii Scale: **8px** (inner tags, chips, input fields), **12px** (standard cards, popovers), **16px** (hero panels, modal bottom sheets).
- **Typography & Tracking Discipline:**
  - Display / Onboarding Headings (28px–36px): Tighten letter-spacing by **-2% to -3%** (-0.6px to -0.9px), line height **1.15**.
  - Dashboard & Operational Page Titles: Cap cleanly at **22px–24px** (`fontWeight: w700`, -0.4px tracking) so dense workspaces are not overwhelmed.
  - Body Text: 14px–16px (`lineHeight: 1.4–1.5`).
  - Tabular & Numeric Data: Monospace or aligned numeric font features for time slots, room numbers, and capacity counts.

## 4. Shared Component Discipline (`lib/shared/widgets/`)

- **`UButton` Alignment:** Unified flat Obsidian Orbit surface (`#FF7A00` solid fill for primary), top-lit border highlights for secondary, optical horizontal padding >= 2x vertical padding, explicit hover/focus/pressed/disabled/loading states, and support for `MediaQuery.disableAnimations`.
- **`UCard` Alignment:** Surface `#17191E`, 1px border `#262932`, optional top-lit specular highlight `borderHighlight` (`Color(0x12FFFFFF)`).
- **`UTextField` Alignment:** Dark input fill (`#121417`), crisp border (`#262932`), explicit focus ring (`#FF7A00` 1.5px–2px), clear error state (`#EF4444`), disabled state opacity `0.38`.
- **`UChip` & `UBadge` Alignment:** Dimmed status container fills with bright foreground text/icons; minimum 36px touch height for interactive filter chips.
- **State Presenters (`UEmptyState`, `ULoading`, Error & Capability Lock Presenters):**
  - **First-Use Empty State:** Calm guidance.
  - **Filter Zero-Match State (`UEmptyState.noMatches`):** Shows active query and 1-tap `Clear filters` button.
  - **Recoverable Error State (`UEmptyState.error`):** Human-readable details + actionable `Retry` button (`Icons.refresh`).
  - **Truthful Capability Lock State (`UEmptyState.lockedCapability`):** Explicit fail-closed status badges for unintegrated backend contracts (Gates A–D).

## 5. Anti-Slop Discipline & Aesthetic Restraint

To eliminate telltale "vibe code" flaws and maintain professional quality, coding agents MUST strictly enforce these anti-slop rules:

- **Banned Visual Gimmicks:**
  - NO gratuitous glassmorphism, heavy background blurs, neon glow dropshadows, or rainbow gradients.
  - NO casual emojis as interface icons (use clean `Lucide` / `Icons` vector icons).
  - NO all-caps mechanical titles or mechanical punctuation (e.g., trailing periods on headers).
  - NO nested container-in-container cards (cards inside cards inside cards).
- **Restraint Rules:**
  - Accent color (`#FF7A00`) is kept scarce—reserved for primary call-to-action buttons, active navigation indicators, and keyboard focus outlines.
  - Rely on subtle surface lightness differences (`#0B0C0E` to `#1F2229`) and whitespace grouping before adding extra borders or containers.
  - Never communicate status by color alone—always pair color badges with explicit text and distinct icons (`Icons.warning_amber_rounded`).

## 6. Responsive & Role-Aware Integration

- **Layout Tiers (`LayoutBuilder` Evaluation):**
  - **Compact (`<768px` Usable Width):** 5-item thumb-friendly bottom nav bar (`Today | Routine | Campus | Resources | Alerts` for students; `Today | Teaching | Campus | Class Tools | Alerts` for teachers).
  - **Medium (`768–1099px` Usable Width):** Compact rail (`220px`) + single-column bounded workspace.
  - **Expanded (`>=1100px` Usable Width):** Persistent left sidebar (`250px`) + multi-column workspace (including 58/42 web auth split screen).

## 7. Visual System Quality Verification Checklist

Before marking any visual design task complete, verify:

1. [x] **WCAG AA Contrast Compliance:** Text pairs (`textPrimary`, `textSecondary`, `textMuted`) against `#0B0C0E`–`#1F2229` surfaces meet >= 4.5:1 ratio (>= 3:1 for non-text icons/borders).
2. [x] **Obsidian Orbit Token Centralization:** All visual styles map to `AppColors`, `AppTextStyles`, `AppSpacing`, and `AppTheme` with `// PHASE 2 (PROVISIONAL):` comments.
3. [x] **4px Spatial Grid & Control Heights:** Padding and margins adhere strictly to 4px multiples; control heights match 48dp (standard), 52dp (auth), and 36–40dp (filter bar).
4. [x] **Shared Widget Consistency:** `UButton`, `UCard`, `UTextField`, `UChip`, and `UBadge` use flat Obsidian Orbit tokens with top-lit specular highlights.
5. [x] **State Presenters Verified:** Loading shimmers, first-use empty, filter zero-match, recoverable error, and capability lock states are verified visually and functionally.
6. [x] **Zero "Vibe Code" Tells:** No glassmorphism, heavy neon glows, clashing emojis, or nested container clutter.

## Phase 3.5 approved Level-4 art direction
Repository-local skills are authoritative for UniVerse. The Product Owner approved this auth/onboarding design; implement it without reopening approval. Preserve every auth, RLS/RPC, no-CLI, Gates A-D and single-writer safeguard.
Require perceptual depth #0B0C0E -> #121417 -> #17191E -> #1F2229, crisp 1px #262932 borders and selective rgba(255,255,255,0.08-0.14) top-edge highlights. Require subtle top-down #1C1F26 -> #15171C surfaces and radial #FF7A00 spotlights at 6-10% alpha behind hero instruments. Semantic preview accents: Orange #FF7A00 theory, Cyan #38BDF8 analytical/faculty, Emerald #10B981 labs/rooms, Amber #F59E0B date updates. These intentional gradients, particle glows, compact telemetry capitals and layered academic mockups override generic restraint rules above. Random rainbow gradients and heavy BackdropFilter blur remain prohibited. Centralize tokens.

## Cohesive Phase 0-3 implementation standard
Use centralized AppColors.cardIdleGradient/cardHoverGradient, dualElevationShadow and specular/specularHover on meaningful elevated surfaces. Passive cards stay passive. UAvatar/ULocalAvatar and ProfileAccountAction own account chrome; preserve the dark/orange identity.

## Anti-Slop, Concentric Radius & Institutional Precision Standard (Phase A & B)
1. **Delete Filler Badges & Unselected Row Stripes ("Checkbox Off = Gray"):**
   - Normal/default states must NOT display filler badges (`Standard 3x/Wk`, `Active`, `Verified`, `Default Baseline`). Normal metrics (credits, capacities, meetings) render as clean right-aligned tabular numerals (`AppTextStyles.numeric`).
   - Reserve semantic badges ONLY for active exceptions/rules: `R13 · 1-Day Block` (Cyan), `R12 · Lab Block` (Emerald), `B+C Joint` (Cyan), `Retake` (Amber), `External Guest [R5]` / `SUST [R9]` (Amber), `R7 Violation` / `R2 Variance > 1d` (Crimson), `Jummah Block` (Amber/Crimson).
   - In master lists, display the `3px` left accent bar ONLY on the currently selected row. Unselected rows remain clean with `1px` dissolved horizontal dividers.
2. **Drop Redundant Labels & Eyebrow Clutter:**
   - Eliminate permanent `Saved in Catalog Store · Staged for Phase D` text banners from inspector headers. Show an optimistic toast/pill upon save, and show the `[Discard] [Save Changes]` bar only when `isDirty == true`.
   - Avoid excessive ALL-CAPS subtitles; use crisp sentence-case headings (`20–24px` max, `-2%` tracking) and group related fields using `AppSpacing` (`4px` grid) rather than extra nested bordered boxes.
3. **Concentric Corner Radii (Inner Radius = Outer – Padding):**
   - Outer `UCard` radius = `12px`; inner toolbars/segmented controls (`4px` padding) = `8px`; matrix cells = `6px`.
   - Lock column and table widths so toggling filters or R15 slot count (`6` vs `7` slots) causes zero layout shift.
4. **7-Day Institutional Week & Jummah Hard Block:**
   - All matrices, day strips, and timetable views span all 7 days (`Sun..Sat`).
   - Friday Period 4 is permanently locked with `JUMMAH` badge and tooltip (`friday_no_p4` hard constraint).

