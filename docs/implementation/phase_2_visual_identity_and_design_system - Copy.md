# Phase 2 Visual Identity & Provisional Obsidian Orbit Design System

Date: 7 November 2026. Scope: Redesign Phase 2 (Provisional Obsidian Orbit Design System, Shared U* Components & State Presenters).
Redesign phase numbering is distinct from the backend implementation roadmap.

---

## 1. Executive Summary & Direction Alignment

Phase 2 establishes the provisional **Obsidian Orbit** design system for UniVerse, unifying visual tokens in `lib/core/theme/` and standardizing shared `U*` widgets in `lib/shared/widgets/`.

Key achievements in this phase:
1. **WCAG AA/AAA Contrast Remediation:** Muted caption text (`textMuted` / `textTertiary`) is boosted from `#6E7278` to `#8A909E` (`6.19:1` against dark canvas, `5.64:1` against card surfaces), resolving low-contrast warnings across dense tables, caption lines, and bottom navigation labels.
2. **Perceptual Surface Depth without Slop:** Replaced flat surfaces with a clean, cool-obsidian 5-tier lightness ramp (`#0B0C0E` ? `#121417` ? `#17191E` ? `#1F2229` ? `#272B33`) accented by selective 1px specular top-edge highlights (`Color(0x12FFFFFF)` ~7% white) rather than heavy drop-shadows or gratuitous glassmorphism.
3. **Primary Action Contrast:** Retained `#FF7A00` as UniVerse's signature brand orange, with active primary buttons pairing `#FF7A00` with high-contrast `#0B0C0E` (`textOnPrimary`) achieving **7.54:1 contrast** (exceeding WCAG AAA).
4. **4px Step Grid & Optical Geometry:** Established strict 4px spacing steps (`4px`, `8px`, `12px`, `16px`, `20px`, `24px`, `32px`), card inner padding (`16px`), section gap (`24px`), matched control heights (`52px` inputs/buttons, `36px` compact filter bar controls), and consistent radii (`8px` chips/inputs, `12px` cards, `16px` modals).
5. **Upgraded State Presenters:** Enhanced `UEmptyState` with four purpose-built constructors: `firstUse` (calm guidance), `noMatches` (with 1-tap `Clear filters`), `error` (human-readable explanation with prominent `Retry`), and `lockedCapability` (truthful preview boundary disclosure).
6. **Full Backward Compatibility:** Maintained 100% getter and constructor compatibility across `AppColors`, `AppSpacing`, `AppTextStyles`, `AppTheme`, and all shared widgets so all existing screens and test suites compile and pass.

---

## 2. Provisional Obsidian Orbit Design Token Specifications

> **Notice:** All exact design token values remain provisional pending representative-screen review across student, teacher, and admin workspaces.

### 2.1 Surface & Depth Ramp

| Semantic Token | Hex / Value | Perceptual Role & Usage | Contrast vs TextPrimary |
|---|---|---|---|
| `bgPrimary` / `background` / `bgDark` | `#0B0C0E` | Base deep canvas / screen background | 17.8 : 1 (AAA) |
| `bgSubtle` / `surfaceSubtle` | `#121417` | Subtle rail, disabled inputs, secondary container | 16.2 : 1 (AAA) |
| `bgCard` / `surface` / `cardBg` | `#17191E` | Standard card surface, calendar grid cells | 14.8 : 1 (AAA) |
| `bgElevated` / `surfaceElevated` / `elevatedCard` | `#1F2229` | Modals, bottom sheets, hover states, chips | 13.0 : 1 (AAA) |
| `surfaceInteractive` | `#272B33` | Interactive pressed / selected item background | 11.2 : 1 (AAA) |

### 2.2 Borders & Top-Lit Highlight

| Semantic Token | Hex / Value | Role & Usage |
|---|---|---|
| `border` / `divider` | `#262932` | Standard 1px divider, card border, input border |
| `borderHighlight` / `topHighlight` | `Color(0x12FFFFFF)` | ~7% white specular top highlight for top-lit cards |
| `borderFocus` / `focusRing` | `#FF7A00` | Accessible focus outline (1.5px–2.0px) |
| `borderError` | `#EF4444` | Form validation error outline (1.5px) |

### 2.3 Typography & Text Contrast Hierarchy

| Text Token | Hex / Value | Role | Contrast vs `#0B0C0E` (Canvas) | Contrast vs `#17191E` (Card) | WCAG Level |
|---|---|---|---|---|---|
| `textPrimary` | `#F3F4F6` | Primary headings, table text, body copy | 17.8 : 1 | 14.8 : 1 | AAA |
| `textSecondary` | `#B8BCC6` | Secondary labels, supporting metadata | 10.3 : 1 | 8.6 : 1 | AAA |
| `textMuted` / `textTertiary` | `#8A909E` | Captions, timestamps, inactive nav | 6.2 : 1 | 5.6 : 1 | AA (>= 4.5:1) |
| `textDisabled` | `#525866` | Disabled button/input labels | 3.3 : 1 | 2.8 : 1 | Disabled UI |
| `textOnPrimary` | `#0B0C0E` | High-contrast label/icon on `#FF7A00` | 7.5 : 1 (vs `#FF7A00`) | — | AAA (>= 7.0:1) |

### 2.4 Semantic Status & Container Fills

| Semantic Status | Foreground Token | Container Token | Container Border | Meaning / Usage |
|---|---|---|---|---|
| **Success** | `success`: `#10B981` | `successSoft`: `#062E22` | `Color(0x6610B981)` | Routine published, class upcoming, verified |
| **Info / Analytic** | `info`: `#38BDF8` | `infoSoft`: `#0F2342` | `Color(0x6638BDF8)` | Teaching slot, next class, design preview |
| **Warning** | `warning`: `#F59E0B` | `warningSoft`: `#302007` | `Color(0x66F59E0B)` | Source warnings, pending gates, preflight blocked |
| **Error / Cancelled**| `error`: `#EF4444` | `errorSoft`: `#331014` | `Color(0x66EF4444)` | Class cancelled, validation failure, network error |
| **Done / Past** | `done`: `#8A909E` | `doneSoft`: `#1F2229` | `#262932` | Completed class, archived routine |

---

## 3. Typography & 4px Spacing / Radius Scale

### 3.1 Typography Scale
- **Display Headings (Hero / Onboarding):**
  - `displayLarge`: `32px`, `FontWeight.w700`, `letterSpacing: -0.8px` (-2.5%), `height: 1.15`.
  - `displayMedium`: `28px`, `FontWeight.w700`, `letterSpacing: -0.6px` (-2%), `height: 1.15`.
  - `onboardTitle`: `28px`, `FontWeight.w700`, `letterSpacing: -0.6px`, `height: 1.15`.
- **Operational Headings (Dense Workspaces Cap):**
  - `h1`: `24px`, `FontWeight.w700`, `letterSpacing: -0.4px`, `height: 1.25` (capped to prevent workspace crowding).
  - `h2`: `18px`, `FontWeight.w600`, `letterSpacing: -0.3px`, `height: 1.3`.
  - `h3`: `16px`, `FontWeight.w600`, `letterSpacing: -0.2px`, `height: 1.35`.
  - `h4`: `14px`, `FontWeight.w600`, `height: 1.4`.
- **Numeric & Tabular Data (Monospaced alignment):**
  - `numeric`: `14px`, `FontWeight.w600`, `fontFeatures: [FontFeature.tabularFigures()]`, `color: textPrimary`.
  - `timeCode`: `13px`, `FontWeight.w600`, `fontFeatures: [FontFeature.tabularFigures()]`, `color: textPrimary`.
  - `roomCode`: `14px`, `FontWeight.w700`, `fontFeatures: [FontFeature.tabularFigures()]`, `letterSpacing: 0.5px`.
  - `statNumber`: `22px`, `FontWeight.w700`, `fontFeatures: [FontFeature.tabularFigures()]`, `letterSpacing: -0.4px`.
  - `countdown`: `30px`, `FontWeight.w700`, `fontFeatures: [FontFeature.tabularFigures()]`, `letterSpacing: -1.0px`.

### 3.2 Spacing & Geometry Scale
- **Step Scale:** `xs: 4px`, `sm: 8px`, `md: 12px`, `lg: 16px`, `xl: 20px`, `xxl: 24px`, `xxxl: 32px`.
- **Hierarchy Gaps:** `gapIntraGroup (8px) < cardPadding (16px) < gapSection (24px)`.
- **Control Heights:**
  - `controlHeightDefault`: `48px` (standard button/input default).
  - `controlHeightPrimary`: `52px` (auth form fields, primary action buttons).
  - `controlHeightCompact`: `36px` (filter bar inputs, compact action buttons).
  - `chipHeight`: `36px` (ensures touch target compliance >= 36px).
- **Border Radii:**
  - `radiusSm`: `8px` (inner chips, tags, text input fields).
  - `radiusMd`: `12px` (standard cards, buttons, dialog boxes).
  - `radiusLg`: `16px` (hero cards, bottom sheets, full-width modals).
  - `radiusFull`: `100px` (pills, badges, circular avatars).

---

## 4. Shared `U*` Component Upgrades

### 4.1 `UButton` (`lib/shared/widgets/u_button.dart`)
- **Visual Treatment:** Solid `#FF7A00` primary surface with subtle top specular highlight (`Color(0x33FFFFFF)`), crisp `#0B0C0E` foreground text/icon (`7.54:1` contrast), optical horizontal padding `>= 2x` vertical padding (`24px` horizontal for `52px` buttons).
- **States:** Explicit hover (`primaryHover: #FF8F26`), pressed (`primaryPressed: #E66A00`), focus ring (`borderFocus: #FF7A00`, 2px), disabled (`surfaceElevated` with `textDisabled`), and loading (`CircularProgressIndicator` with matching content color).
- **Reduced Motion:** Respects `MediaQueryData(disableAnimations: true)` with instant state changes (`Duration.zero`).

### 4.2 `UCard` (`lib/shared/widgets/u_card.dart`)
- **Top-Lit Highlight:** Optional `isTopLit: true` overlays a 1px specular top highlight (`AppColors.borderHighlight`) inside a safe `ClipRRect(borderRadius: radius)` Stack, preventing Flutter's non-uniform border assertion while creating perceptual depth.
- **Elevation Variant:** Optional `elevated: true` automatically defaults the background to `AppColors.surfaceElevated` (`#1F2229`).

### 4.3 `UTextField` (`lib/shared/widgets/u_text_field.dart`)
- **Focus & Validation:** Focused border uses `borderFocus` (`#FF7A00`, 1.5px); error states use `borderError` (`#EF4444`, 1.5px); disabled states use `surfaceSubtle` background with `textDisabled`.
- **Typography & Alignment:** Hint text uses `textMuted` (`#8A909E`), label uses `textSecondary` (`#B8BCC6`), and input text uses `textPrimary` (`#F3F4F6`).

### 4.4 `UChip` & `UBadge` (`lib/shared/widgets/u_chip.dart`, `lib/shared/widgets/u_badge.dart`)
- **`UChip`:** Matched `36px` height meeting touch target criteria. Active chips use `primarySoft` (`#302007`) container with `#FF7A00` border and `FontWeight.w600` text; inactive chips use `surfaceElevated` with `textMuted` (`> 4.5:1` contrast).
- **`UBadge`:** Dimmed semantic container fills with bright foreground text. Live badge pulse animation pauses and pins to `1.0` when `MediaQuery.disableAnimations` is active.

### 4.5 `UBottomNav` & `AppBottomNav` (`lib/shared/widgets/u_bottom_nav.dart`, `lib/shared/widgets/app_bottom_nav.dart`)
- **Dual Visual Cues:** Active items feature both:
  1. An icon enclosed in an animated pill container (`AppColors.primarySoft` / `Color(0x26FF7A00)`).
  2. Label in `AppColors.navActive` (`#FF7A00`) with bold `FontWeight.w700`.
- **Inactive Items:** Rendered in `AppColors.navInactive` (`#8A909E`), comfortably exceeding 3:1 WCAG UI contrast on `#121417`.
- **Separation & Clearance:** 1px `#262932` top border cleanly divides the navigation bar from scrolling content; `SafeArea(top: false, bottom: true)` guarantees clearance above mobile gesture bars.

### 4.6 `UEmptyState` (`lib/shared/widgets/u_empty_state.dart`)
Enhanced with 4 dedicated factory constructors:
- `UEmptyState.firstUse()`: Calm instructional guidance for new semesters or unpublished routines.
- `UEmptyState.noMatches(query: ...)`: Explains search query / filter misses and renders a 1-tap `Clear filters` button.
- `UEmptyState.error(...)`: Explains connection/data failures in human terms and renders a prominent `Retry` button.
- `UEmptyState.lockedCapability(...)`: Truthfully communicates unintegrated server capabilities with a prominent preview badge and scope description.

---

## 5. Inline Code Comments & Traceability

Every modified token group and shared component boundary is tagged with `// PHASE 2:` comments:

| File | Tag Type | Primary Locations / Lines | Purpose |
|---|---|---|---|
| `lib/core/theme/app_colors.dart` | `// PHASE 2:` & `// PHASE 2 (PROVISIONAL):` | Lines 3, 6, 29, 43, 56, 69 | Surface depth ramp, orange accent states, WCAG contrast fixes, semantic status containers |
| `lib/core/theme/app_text_styles.dart` | `// PHASE 2:` & `// PHASE 2 (PROVISIONAL):` | Lines 4, 6, 23, 166 | Display scale, operational 24px cap, tabular numeric styles |
| `lib/core/theme/app_spacing.dart` | `// PHASE 2:` & `// PHASE 2 (PROVISIONAL):` | Lines 3, 5, 17, 60, 74 | 4px grid steps, layout constants, 36px chip height, radii |
| `lib/core/theme/app_theme.dart` | `// PHASE 2:` & `// PHASE 2 (PROVISIONAL):` | Lines 9, 11, 187 | Dark theme alignment, 44x44 TextButton hit target |
| `lib/shared/widgets/u_button.dart` | `// PHASE 2:` & `// PHASE 2 (PROVISIONAL):` | Lines 6, 9, 66, 153 | High-contrast button surface, top highlight, reduced motion |
| `lib/shared/widgets/u_card.dart` | `// PHASE 2:` & `// PHASE 2 (PROVISIONAL):` | Lines 5, 14, 16, 70 | Top-lit specular highlight, elevated background variant |
| `lib/shared/widgets/u_text_field.dart` | `// PHASE 2:` | Line 6 | Focus outline, error styling, disabled states |
| `lib/shared/widgets/u_chip.dart` | `// PHASE 2:` | Line 6 | 36px touch height, dimmed semantic container fill |
| `lib/shared/widgets/u_badge.dart` | `// PHASE 2:` | Line 7 | Dimmed semantic status fills, reduced motion support |
| `lib/shared/widgets/u_bottom_nav.dart` | `// PHASE 2:` & `// PHASE 2 (PROVISIONAL):` | Lines 13, 66, 106 | Dual visual cues (icon pill + w700 text), 1px border |
| `lib/shared/widgets/app_bottom_nav.dart` | `// PHASE 2:` | Line 148 | SafeArea bottom clearance protection |
| `lib/shared/widgets/u_empty_state.dart` | `// PHASE 2:` & `// PHASE 2 (PROVISIONAL):` | Lines 8, 27, 46, 84, 116 | Four state presenter variants (first-use, no-matches, error, locked) |
| `lib/shared/widgets/u_loading.dart` | `// PHASE 2:` | Line 5 | Skeleton shimmer and spinner aligned to Obsidian Orbit tokens |

---

## 6. Verification Results

All tests and static analysis executed locally on Windows (Dart / Flutter):

### 6.1 Static Analysis
Command:
```powershell
flutter analyze --no-pub
```
Output:
```text
Analyzing universe_v1...
No issues found! (ran in 4.9s)
```
Status: **Clean (0 errors, 0 warnings, 0 lints).**

### 6.2 Focused Phase 2 Test Suite
Command:
```powershell
flutter test test/phase_2_design_system_and_components_test.dart
```
Output:
```text
00:00 +0: (setUpAll)
00:00 +0: Phase 2: Obsidian Orbit Color Tokens & WCAG Contrast textPrimary against background exceeds WCAG AAA (7.0:1)
00:00 +1: Phase 2: Obsidian Orbit Color Tokens & WCAG Contrast textSecondary against background exceeds WCAG AA (4.5:1)
00:00 +2: Phase 2: Obsidian Orbit Color Tokens & WCAG Contrast textMuted against background and surface exceeds WCAG AA (4.5:1)
00:00 +3: Phase 2: Obsidian Orbit Color Tokens & WCAG Contrast textOnPrimary against primary (#FF7A00) exceeds WCAG AAA (7.0:1)
00:00 +4: Phase 2: Obsidian Orbit Color Tokens & WCAG Contrast ThemeData.dark incorporates Obsidian Orbit ColorScheme tokens
00:00 +5: Phase 2: Obsidian Orbit Color Tokens & WCAG Contrast AppSpacing and AppTextStyles follow strict Obsidian Orbit scale
00:00 +6: Phase 2: UButton Component States renders primary button with label, icon, and handles tap
00:00 +7: Phase 2: UButton Component States renders loading state without label text and does not tap
00:00 +8: Phase 2: UButton Component States renders disabled state with no tap interaction
00:00 +9: Phase 2: UButton Component States respects MediaQueryData(disableAnimations: true)
00:00 +10: Phase 2: UCard Component & Top-Lit Highlight renders standard card and handles tap
00:00 +11: Phase 2: UCard Component & Top-Lit Highlight renders elevated card with surfaceElevated background
00:00 +12: Phase 2: UCard Component & Top-Lit Highlight renders isTopLit with specular top-edge highlight
00:01 +13: Phase 2: UTextField Component renders label, hint, and handles input text
00:01 +14: Phase 2: UTextField Component renders disabled state correctly
00:01 +15: Phase 2: UChip & UBadge Components UChip has >= 36px touch height and triggers tap
00:01 +16: Phase 2: UChip & UBadge Components UBadge renders all statuses and respects disableAnimations
00:01 +17: Phase 2: UBottomNav Dual Visual Cues renders active pill container and w700 text style
00:01 +18: Phase 2: UEmptyState Presenter Variants UEmptyState.firstUse renders calm guidance
00:01 +19: Phase 2: UEmptyState Presenter Variants UEmptyState.noMatches acknowledges query and triggers clear action
00:01 +20: Phase 2: UEmptyState Presenter Variants UEmptyState.error displays error copy and triggers retry
00:01 +21: Phase 2: UEmptyState Presenter Variants UEmptyState.lockedCapability communicates preview boundary
00:01 +22: Phase 2: ULoading Presenter ULoading.spinner renders with primary color
00:01 +23: Phase 2: ULoading Presenter ULoading.skeleton respects disableAnimations
00:01 +24: (tearDownAll)
00:01 +24: All tests passed!
```
Status: **24 of 24 tests passed.**

### 6.3 Comprehensive Regression Test Suite (Phases 0, 1 & 2)
Command:
```powershell
flutter test test/phase_2_design_system_and_components_test.dart test/phase_1_navigation_and_shell_test.dart test/scheduling_workspace_route_test.dart test/scheduling_workspace_comprehensive_test.dart test/auth_recovery_remediation_test.dart test/auth_callback_policy_test.dart
```
Output:
```text
00:10 +90: All tests passed!
```
Status: **90 of 90 tests passed across all 6 suites without regression.**

### 6.4 Git Diff Whitespace Check
Command:
```powershell
git diff --check
```
Output:
```text
Exit code: 0
```
Status: **Zero trailing whitespace or whitespace errors.**

---

## 7. Phase 0–3 Cohesive Continuation Upgrades (8 November 2026)

As part of the Phase 0–3 continuation pass, the Obsidian Orbit design system and shared component library were extended with centralized motion primitives, tactile interaction choreography, and Level-4 dark-mode surface depth:

### 7.1 Centralized Motion System (`lib/core/theme/app_motion.dart`)
- **Duration Tokens:** `micro` (`140ms`), `fast` (`220ms`), `medium` (`340ms`), `slow` (`520ms`).
- **Curve Tokens:** `snappy` (`Cubic(0.22, 1.0, 0.36, 1.0)`), `magnetic` (`Cubic(0.16, 1.0, 0.30, 1.0)`), `fluid` (`Curves.easeInOutCubic`).
- **Reduced-Motion Governance:** `AppMotion.reduced(context)` and `AppMotion.duration(context, normal)` respect `MediaQuery.maybeDisableAnimationsOf(context)` and return `Duration.zero` when reduced motion is enabled.

### 7.2 Shared Kinetic & Tactile Primitives
- **`UAnimatedSwap` (`lib/shared/widgets/u_animated_swap.dart`):** Keyed content crossfade with directional slide (`Offset(0, .035)` vertical / `Offset(.04, 0)` horizontal) and subtle scale (`.985` to `1.0`), bypassing `AnimatedSwitcher` immediately under reduced motion.
- **`UPressableScale` (`lib/shared/widgets/u_pressable_scale.dart`):** Pointer-down/up/cancel and mouse-hover tracking that animates scale to `0.975` on press and `1.012` on hover without intercepting child tap callbacks.
- **`USegmentedControl<T>` (`lib/shared/widgets/u_segmented_control.dart`):** Accessible generic segmented selector with an `AnimatedPositionedDirectional` sliding thumb (`AppColors.cardIdleGradient`, `AppColors.dualElevationShadow`, `1px` `AppColors.specular` top highlight), keyboard focus support, semantic `selected` state merging, and `48px` mobile / `40px` compact desktop heights.

### 7.3 Surface Depth & Shared Widget Refinements
- **`AppColors` (`lib/core/theme/app_colors.dart`):** Added centralized Level-4 depth helpers (`cardIdleGradient`, `cardHoverGradient`, `dualElevationShadow`, `specularHover`, `instrumentTop`, `instrumentBottom`, `authCardTop`, `authCardBottom`).
- **`AppSpacing` & `AppTheme` (`lib/core/theme/app_spacing.dart`, `lib/core/theme/app_theme.dart`):** Added `cardBorderRadius` (`12.0`), `modalBorderRadius` (`16.0`), and `badgeBorderRadius` (`999.0`), wired them into `CardThemeData`, `DialogThemeData`, and `BottomSheetThemeData`, and normalized button `minimumSize` in `ElevatedButtonThemeData`, `FilledButtonThemeData`, and `OutlinedButtonThemeData` to `Size(64, AppSpacing.buttonHeight)` so buttons placed inside unconstrained `Wrap` or `Row` containers (such as `AdminDesktopShell`'s header actions) size intrinsically without throwing `BoxConstraints forces an infinite width`.
- **`UButton`, `UCard`, `UTextField`, `UChip`, `UBadge`, `UBottomNav`:**
  - `UButton` and `UChip` integrate `UPressableScale` and `UAnimatedSwap` for label/loading transitions.
  - `UCard` uses `cardIdleGradient` / `cardHoverGradient`, `dualElevationShadow`, and hover-responsive `specular` / `specularHover` top highlight.
  - `UTextField` tracks focus state to animate an subtle orange outer focus glow (`AppColors.primary.withValues(alpha: 0.16)`, `blurRadius: 12`).
  - `UBottomNav` uses `UPressableScale` and `AppMotion` tokens while preserving `SafeArea` bottom clearance.
- **Avatar & Desktop Shell Actions (`u_avatar.dart`, `u_local_avatar.dart`, `desktop_shell_scope.dart`, `role_desktop_shell.dart`, `admin_desktop_shell.dart`):**
  - Replaced low-contrast `rgba` avatar borders with `AppColors.border` (`1.5px`) and semantic role/deterministic palettes.
  - `ProfileAccountAction` provides an accessible account menu on desktop (`View Profile`, `Sign Out`) and direct `/profile` navigation on compact mobile headers.
- **Domain Cards (`live_class_card.dart`, `next_class_card.dart`, `class_card.dart`, `role_card.dart`, `quick_action_card.dart`, `resource_card.dart`, `day_selector.dart`, `room_status_card.dart`, `teacher_location_card.dart`):**
  - `LiveClassCard` computes real progress strictly from `startTime` and `endTime` (`0.0` to `1.0`), omitting the progress bar when `startTime == null` or `!endTime.isAfter(startTime)`, and stopping its periodic timer and pulse animation when reduced motion is enabled or the class ends.
  - All domain cards adopt `UCard(isTopLit: true)`, `UPressableScale`, and `AppMotion` durations.

### 7.4 Updated Verification Evidence
- `flutter analyze --no-pub`: **0 issues**.
- `flutter test test/shared_motion_test.dart test/domain_card_motion_test.dart test/phase_2_design_system_and_components_test.dart`: **32 tests passed** (`4` in `shared_motion_test.dart`, `3` in `domain_card_motion_test.dart`, `25` in `phase_2_design_system_and_components_test.dart` including `UTextField` focus glow verification).
- Full 11-suite cross-phase regression gate: **135 tests passed, 0 failures**.
