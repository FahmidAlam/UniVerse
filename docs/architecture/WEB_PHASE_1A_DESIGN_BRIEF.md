# UniVerse React Web v1 — Finalized Phase 1A Academic Ledger Design Brief & Package Approval

> **Phase Scope:** Sub-Phase **1A** (`apps/web/` frontend-only, mocked/local dev mode).
> **Interactive Prototype:** [`academic_ledger_phase1a_preview.html`](academic_ledger_phase1a_preview.html) (standalone HTML/CSS/JS specimen preview — inspect & approve before Phase 1A React implementation).
> **Gated Boundaries:** Sub-Phase **1B** (live staging auth on owner-approved `oqwvxplteqtlrhktsplj`) remains blocked until Supabase Auth Redirect URLs & `AUTH_WEB_CALLBACK_URLS` are confirmed; production `yxqyrjyzxitrgkhgauli` stays **strictly read-only**.
> **Implementation Gate:** Zero edits to `apps/web/src/`, `apps/web/package.json`, `lib/`, `android/`, `ios/`, `engine/`, or `supabase/` until explicit owner sign-off on this specification and the static prototype.

---

## 1. Exact Design Tokens & sRGB WCAG AA Contrast Specification

All CSS custom properties live centrally in `apps/web/src/styles/tokens.css` under a single **light-first theme** (dark mode is explicitly deferred in v1; remove `html[data-theme="dark"]` and `ThemeSwitcher.tsx`). Whenever mixing colors in CSS, use `color-mix(in oklab, ...)` rather than `in oklch` on low-chroma neutrals to avoid Chromium neutral hue drift.

### 1.1 Numerical OKLCH Tokens & sRGB Hex Fallbacks

| Token | Numerical `oklch(L C H)` Value | Resolved sRGB Hex Fallback | sRGB Gamut Safe | Semantic Role |
|---|---|---|---|---|
| `--bg-canvas` | `oklch(0.946 0.008 86)` | `#EFEDE7` | Yes | Warm recessed archival stone/paper backdrop & admin nav rail (`240px`) |
| `--bg-surface` | `oklch(0.974 0.006 86)` | `#F8F6F2` | Yes | Primary page canvas & reading surface |
| `--bg-elevated` | `oklch(0.996 0.002 86)` | `#FEFEFC` | Yes | Crisp elevated cards, ledger sheets, modals, popovers, & inputs |
| `--surface-hover` | `oklch(0.960 0.007 86)` | `#F4F1ED` | Yes | Subtle pointer hover state over neutral table rows & nav links |
| `--surface-active` | `oklch(0.934 0.009 86)` | `#ECE9E3` | Yes | Pressed / selected neutral control & active nav item fill |
| `--ink-primary` | `oklch(0.205 0.012 75)` | `#1A1611` | Yes | Primary headings, primary cell text, values, active nav text |
| `--ink-secondary` | `oklch(0.415 0.012 78)` | `#4F4B45` | Yes | Supporting copy, table labels, form descriptions |
| `--ink-muted` | `oklch(0.510 0.010 80)` | `#696660` | Yes | Quiet metadata, timestamps, captions, & **inactive-row attenuated text** |
| `--action-primary` | `oklch(0.220 0.012 75)` | `#1E1A14` | Yes | **Charcoal Ink** primary CTA fill |
| `--action-primary-hover` | `oklch(0.275 0.014 75)` | `#2C2720` | Yes | Primary button hover fill |
| `--action-primary-active` | `oklch(0.180 0.010 75)` | `#14110D` | Yes | Primary button pressed fill (paired with `scale(0.97)`) |
| `--action-primary-ink` | `oklch(0.988 0.003 86)` | `#FCFBF9` | Yes | Warm paper label ink on Charcoal Ink CTA |
| `--accent-pine` *(Provisional)* | `oklch(0.395 0.076 158)` | `#1A5236` | Yes | **Deep Botanical Pine** — provisional accent pending official Leading University branding confirmation |
| `--accent-pine-hover` *(Provisional)* | `oklch(0.345 0.078 158)` | `#044529` | Yes | Active accent hover state |
| `--accent-pine-soft` *(Provisional)* | `oklch(0.942 0.018 156)` | `#E3F0E7` | Yes | Selected filter pill fill / subtle active indicator wash |
| `--accent-pine-ink` *(Provisional)* | `oklch(0.990 0.003 95)` | `#FCFCF9` | Yes | Light ink inside solid Deep Botanical Pine badges/actions |
| `--border-subtle` | `oklch(0.205 0.012 75 / 0.12)` | `#E3E2E0` *(on `--bg-elevated`)* | Yes | Decorative `1px` ledger grid hairlines & section rules (non-critical boundary) |
| `--border-control` | `oklch(0.575 0.012 80)` | `#7D7871` | Yes | Essential interactive control outlines (inputs, checkboxes, toggle tracks) |
| `--focus-ring` | `oklch(0.395 0.076 158)` | `#1A5236` | Yes | `2px` solid `:focus-visible` ring (`2px` offset) |
| `--sem-theory-bg` | `oklch(0.950 0.018 245)` | `#E5F0FA` | Yes | Theory slot background |
| `--sem-theory-ink` | `oklch(0.335 0.078 248)` | `#0E395D` | Yes | Theory text ink |
| `--sem-theory-bar` | `oklch(0.495 0.095 248)` | `#316695` | Yes | `3px` left accent bar for Theory cells |
| `--sem-lab-bg` | `oklch(0.944 0.022 158)` | `#E1F1E7` | Yes | Lab / Sessional slot background |
| `--sem-lab-ink` | `oklch(0.335 0.062 158)` | `#15402A` | Yes | Lab / Sessional text ink |
| `--sem-lab-bar` | `oklch(0.450 0.088 158)` | `#206442` | Yes | `3px` left accent bar for Lab cells |
| `--sem-joint-bg` | `oklch(0.954 0.028 80)` | `#FAEEDB` | Yes | Joint `B+C` offering background |
| `--sem-joint-ink` | `oklch(0.380 0.085 65)` | `#613700` | Yes | Joint `B+C` text ink |
| `--sem-joint-bar` | `oklch(0.560 0.115 70)` | `#9F6713` | Yes | `3px` left accent bar for Joint cells |
| `--sem-conflict-bg` | `oklch(0.946 0.020 24)` | `#FAE8E7` | Yes | Hard Block / Conflict / Empty Config warning background |
| `--sem-conflict-ink` | `oklch(0.415 0.145 25)` | `#8A1C1F` | Yes | Hard Block / Conflict / Error text ink |
| `--sem-conflict-bar` | `oklch(0.530 0.165 25)` | `#B83837` | Yes | `3px` left accent bar & destructive indicator |

### 1.2 Four Light-Mode Depth Properties

1. **Blended Hairline Borders:** `--border-subtle: oklch(0.205 0.012 75 / 0.12)` for decorative `1px` ledger rules; `--border-control: oklch(0.575 0.012 80)` (`#7D7871`) on essential form inputs, checkboxes, and switches (`>= 3:1`).
2. **Crisp Top-Edge Specular Highlight:** `--highlight-top: inset 0 1px 0 oklch(1 0 0 / 0.85)` (`#FFFFFF` at 85%) on elevated cards, popovers, modals, and drawers.
3. **Subtle Hover Sheen:** `--surface-sheen: linear-gradient(180deg, oklch(1 0.001 86), oklch(0.985 0.004 86))` gently lifting interactive cards and action strips on hover without harsh gradients.
4. **Dual-Layer Soft Alpha Shadows:** `--shadow-sheet: 0 1px 2px oklch(0.205 0.012 75 / 0.06), 0 6px 18px oklch(0.205 0.012 75 / 0.05)` and `--shadow-popover: 0 2px 6px oklch(0.205 0.012 75 / 0.08), 0 14px 32px oklch(0.205 0.012 75 / 0.10)`.

### 1.3 Verified sRGB WCAG 2.1 AA Contrast Matrix

All pairs below were programmatically converted via `OKLCH -> OKLab -> Linear sRGB -> sRGB (8-bit)` and checked via WCAG 2.1 relative luminance against actual opaque sRGB foreground/background hex values (never relying on OKLCH `L` heuristics or percentage opacity guesses):

| Foreground Token (Hex) | Background Token (Hex) | Calculated Ratio | WCAG Requirement | Verdict |
|---|---|---|---|---|
| `--ink-primary` (`#1A1611`) | `--bg-canvas` (`#EFEDE7`) | **15.37 : 1** | Normal text (`>= 4.5:1`) | **PASS** |
| `--ink-primary` (`#1A1611`) | `--bg-surface` (`#F8F6F2`) | **16.67 : 1** | Normal text (`>= 4.5:1`) | **PASS** |
| `--ink-primary` (`#1A1611`) | `--bg-elevated` (`#FEFEFC`) | **17.82 : 1** | Normal text (`>= 4.5:1`) | **PASS** |
| `--ink-secondary` (`#4F4B45`) | `--bg-canvas` (`#EFEDE7`) | **7.40 : 1** | Normal text (`>= 4.5:1`) | **PASS** |
| `--ink-secondary` (`#4F4B45`) | `--bg-surface` (`#F8F6F2`) | **8.02 : 1** | Normal text (`>= 4.5:1`) | **PASS** |
| `--ink-secondary` (`#4F4B45`) | `--bg-elevated` (`#FEFEFC`) | **8.58 : 1** | Normal text (`>= 4.5:1`) | **PASS** |
| `--ink-muted` (`#696660`) | `--bg-canvas` (`#EFEDE7`) | **4.89 : 1** | Quiet text / inactive row (`>= 4.5:1`) | **PASS** |
| `--ink-muted` (`#696660`) | `--bg-surface` (`#F8F6F2`) | **5.30 : 1** | Quiet text / inactive row (`>= 4.5:1`) | **PASS** |
| `--ink-muted` (`#696660`) | `--bg-elevated` (`#FEFEFC`) | **5.67 : 1** | Quiet text / inactive row (`>= 4.5:1`) | **PASS** |
| `--action-primary-ink` (`#FCFBF9`) | `--action-primary` (`#1E1A14`) | **16.74 : 1** | Button text (`>= 4.5:1`) | **PASS** |
| `--action-primary-ink` (`#FCFBF9`) | `--action-primary-hover` (`#2C2720`) | **14.32 : 1** | Hover CTA text (`>= 4.5:1`) | **PASS** |
| `--action-primary` (`#1E1A14`) | `--bg-elevated` (`#FEFEFC`) | **17.14 : 1** | UI component boundary (`>= 3.0:1`) | **PASS** |
| `--accent-pine` (`#1A5236`) | `--bg-canvas` (`#EFEDE7`) | **7.79 : 1** | Accent text/link (`>= 4.5:1`) | **PASS** |
| `--accent-pine` (`#1A5236`) | `--bg-surface` (`#F8F6F2`) | **8.44 : 1** | Accent text/link (`>= 4.5:1`) | **PASS** |
| `--accent-pine` (`#1A5236`) | `--bg-elevated` (`#FEFEFC`) | **9.03 : 1** | Accent text/link (`>= 4.5:1`) | **PASS** |
| `--accent-pine` (`#1A5236`) | `--accent-pine-soft` (`#E3F0E7`) | **7.76 : 1** | Active pill/badge text (`>= 4.5:1`) | **PASS** |
| `--accent-pine-ink` (`#FCFCF9`) | `--accent-pine` (`#1A5236`) | **8.87 : 1** | Solid accent pill text (`>= 4.5:1`) | **PASS** |
| `--focus-ring` (`#1A5236`) | `--bg-elevated` (`#FEFEFC`) / `--bg-canvas` (`#EFEDE7`) | **9.03 : 1** / **7.79 : 1** | Focus indicator (`>= 3.0:1`) | **PASS** |
| `--border-control` (`#7D7871`) | `--bg-elevated` (`#FEFEFC`) / `--bg-surface` (`#F8F6F2`) | **4.34 : 1** / **4.06 : 1** | Essential input/control outline (`>= 3.0:1`) | **PASS** |
| `--sem-theory-ink` (`#0E395D`) | `--sem-theory-bg` (`#E5F0FA`) | **10.32 : 1** | Semantic text (`>= 4.5:1`) | **PASS** |
| `--sem-theory-bar` (`#316695`) | `--bg-elevated` (`#FEFEFC`) | **6.00 : 1** | Non-text bar indicator (`>= 3.0:1`) | **PASS** |
| `--sem-lab-ink` (`#15402A`) | `--sem-lab-bg` (`#E1F1E7`) | **9.97 : 1** | Semantic text (`>= 4.5:1`) | **PASS** |
| `--sem-lab-bar` (`#206442`) | `--bg-elevated` (`#FEFEFC`) | **7.02 : 1** | Non-text bar indicator (`>= 3.0:1`) | **PASS** |
| `--sem-joint-ink` (`#613700`) | `--sem-joint-bg` (`#FAEEDB`) | **8.91 : 1** | Semantic text (`>= 4.5:1`) | **PASS** |
| `--sem-joint-bar` (`#9F6713`) | `--bg-elevated` (`#FEFEFC`) | **4.70 : 1** | Non-text bar indicator (`>= 3.0:1`) | **PASS** |
| `--sem-conflict-ink` (`#8A1C1F`) | `--sem-conflict-bg` (`#FAE8E7`) | **7.84 : 1** | Semantic text (`>= 4.5:1`) | **PASS** |
| `--sem-conflict-bar` (`#B83837`) | `--bg-elevated` (`#FEFEFC`) | **5.68 : 1** | Non-text bar indicator (`>= 3.0:1`) | **PASS** |

*Vitest Gate:* Include `@media (prefers-contrast: more)` and `@media (forced-colors: active)` overrides and assert every pair above automatically in Vitest (`>= 4.5:1` / `>= 3.0:1`).

---

## 2. Typography Scale

**Font Stacks:**
- **Editorial Serif:** `--font-serif: "Source Serif 4", Georgia, "Times New Roman", serif;`
- **UI & Tables:** `--font-sans: "IBM Plex Sans", -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;`
- **Academic Monospace:** `--font-mono: "IBM Plex Mono", ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;`
- **Icons:** `@phosphor-icons/react` (`Regular` weight only; never Lucide or decorative sparkles).

| Role | Font Family | Size | Weight | Line Height | Tracking / Features |
|---|---|---|---|---|---|
| **Public Editorial Headline (`h1` on `/`)** | `Source Serif 4` | `clamp(2rem, 3.6vw, 2.75rem)` (`44px` max desktop) | `600` | `1.10` | `-0.025em`; `text-wrap: balance` |
| **Public Body Copy** | `IBM Plex Sans` | `16px` (`1rem`) | `400` | `1.60` | `0em`; measure `<= 62ch` |
| **Admin Page Title (`h1` on `/admin/*`)** | `IBM Plex Sans` | `22px` (`1.375rem`, capped `<= 24px`) | `600` | `1.22` | `-0.02em` |
| **Section Headings (`h2`)** | `IBM Plex Sans` (`Source Serif 4` on public sections) | `16px` (`1rem` admin) / `20px` (public) | `600` | `1.25` | `-0.015em` |
| **Table Headers (`th`)** | `IBM Plex Sans` | `11.5px` | `600` | `1.30` | `+0.04em` uppercase archival ledger rule |
| **Table Rows (`td`)** | `IBM Plex Sans` | `13.5px` | `400` / `500` | `1.45` | `0em`; generous `12px–14px` vertical padding |
| **Course Codes & Identifiers** | `IBM Plex Mono` | `12.5px` | `500` | `1.35` | `font-variant-numeric: tabular-nums` |
| **Time Slots & Clocks** | `IBM Plex Mono` | `11.5px` | `500` | `1.30` | `font-variant-numeric: tabular-nums` (`08:50–10:05`) |
| **Quiet Metadata & Filter Counts** | `IBM Plex Sans` / `Mono` (counts) | `12px` | `400` / `500` | `1.40` | `tabular-nums` for counts & timestamps |
| **Buttons & Form Controls** | `IBM Plex Sans` | `13.5px` (desktop `36px` toolbar / `40px` primary) | `500`–`600` | `1.0` | `>= 2x` horizontal-to-vertical optical padding |

---

## 3. Public Landing Page `/` Specification

- **Desktop Composition & Proportions (`1440px`):** Max container `1280px` centered with `32px` gutter (`1024px`: tight `24px` gutter; `390px`: single column `16px` padding). Hero splits **`minmax(0, 0.92fr)` editorial prose (left)** beside **`minmax(0, 1.38fr)` interactive 2D academic timetable specimen (right)**, collapsing smoothly into a clean vertical stack at `< 1024px`.
- **Masthead & Navigation:** Full-width `60px` top strip (`1px` subtle bottom ledger rule), university provenance mark + geometric Orbit/Grid hairline emblem, minimal links (`Specimen`, `Mobile Apps`, `Admin Sign In` Charcoal Ink CTA). Subtle archival SVG paper-grain texture (`<= 1.8%` visual opacity) sits **exclusively** behind the public masthead/hero header, reinforced via **visual rhyming** (coordinate index ticks `01`, `02`, ruled divider hairlines, `1px` cell intersections echoing across page cards).
- **Editorial Headline & Copy:** `Source Serif 4` headline highlighting Leading University CSE academic routine generation & constraint resolution without unimplemented AI marketing claims.
- **Flat User-Controlled Illustrative 2D Timetable Specimen:**
  - Strictly static local fixture data in `apps/web/src/features/onboarding/data/routineFixtures.ts` (**zero unauthenticated Supabase or FastAPI calls**, zero fake solver progress percentages, zero automatic 4.5s background cycling timers, zero 3D perspective tilts or fluted glass).
  - Permanent disclosure strip anchored inside the grid chrome: **"Illustrative sample schedule — interactive preview only, not a live CP-SAT solver run."**
  - Interactive user constraint controls (`36px` bar, wrapping cleanly at `< 768px`):
    - **Jummah Block (`Fri P4`) toggle:** Locks/unlocks Friday Period 4 Jummah prayer hard block across all batches.
    - **R7 Faculty Off-Day (`EBH Thu–Fri`) toggle:** Moves EBH sections cleanly to valid `Sun–Wed` windows or surfaces a live conflict notice.
    - **R15 Grid (`6-Slot` vs `7-Slot + Online P7`) toggle:** Adds/removes the evening P7 column (`19:00–20:20 Online`).
    - **Lens Switcher (`Section` / `Faculty` / `Room`)** & **View Switch (`Matrix` ↔ `Compact List`)**, with an interactive corner-triangle override indicator (`58-B+C` joint lab override) displaying an explanation tooltip on hover/focus.
- **`MobileCompanionStrip` (Below Hero):** Dedicated light-paper ledger band explaining clearly that **Students & Teachers use the UniVerse Flutter Mobile app on Android and iOS** for daily live routines, date-scoped cancellation alerts, teacher lookup, and live room availability, keeping browser workflows focused on Administrators.

---

## 4. Authentication `/login` & `/reset-password` Specification

- **Desktop Split Layout (`>= 1024px`):** `54%` left institutional Archival Registrar context panel (`--bg-canvas` with `<= 1.8%` subtle grain, coordinate ticks, Leading University CSE provenance, and explicit **Android & iOS** mobile-app guidance strip for non-admins) paired with a **`46%` bounded elevated sheet** (`--bg-elevated`, `max-width: 440px` form container, crisp `1px` hairline + dual-layer soft shadow). Below `1024px`, context stacks concisely above or compactly below the bounded card so login inputs stay above the fold at `390×844`.
- **Sign-In Presentation (`/login`):**
  - **Primary OAuth:** Institutional Google Sign-In secondary outlined button (`40px` height, `--border-control` outline) triggering Supabase PKCE flow.
  - **Email & Password Form:** Validated via `react-hook-form` + `zod`; `40px` inputs, clear inline validation feedback (`260ms` horizontal `±4px` shake on error paired with inline focus move), Charcoal Ink `Sign In to Operations Console` submit CTA (`40px`), and `/forgot-password` recovery link.
- **Error & Recovery States:** Friendly error banner (`Service Recovery Paradox`) preserves typed email input, diagnoses credential/network/unwhitelisted issues honestly without exposing auth internals, and offers a 1-click retry/reset link. `/access-required` cleanly instructs signed-in Students/Teachers to use **Android/iOS mobile** and offers one-click account switching.
- **Live Password Requirement Checklist (`/reset-password`):** Enforces the 10-minute recovery window (matching existing `AuthProvider` contract—zero auth contract changes) and updates a 4-item inline checklist live while typing (`>= 8 characters`, `Uppercase letter`, `Number`, `Matches confirm password`).
- **`AuthProvider` & `adoptInviteSession` Phase 1A Hardening:** Refactor `AuthProvider` `onAuthStateChange` to track `statusRef` and align `adoptInviteSession()` (`!window.location.search`, `email_confirmed_at`, `expires_at > now + 60`) with Flutter's `InvitationCallbackBridge`.

---

## 5. Admin Shell & Dashboard Specification

- **Shell Architecture (`AdminShell.tsx`):**
  - **Desktop (`>= 1100px`):** Fixed `240px` left navigation rail (`--bg-canvas`, `1px` right subtle border) + fluid main column with `52px` sticky top bar (`--bg-surface`).
  - **Compact / Mobile (`< 1100px`):** Top bar exposes a `44px` menu button opening the Radix `Dialog` slide-over drawer.
  - **Top Bar Contents (`52px`):** Current page title (`<= 24px` in workspace body or compact header crumb), `EngineHealthBadge` polling `GET /`, `Generate Routine` shortcut, and **one single interactive Account Popover** (admin name, email, role badge, `/admin/profile` link, `Sign Out`; remove `ThemeSwitcher`).
- **Navigation Hierarchy & Capability Honesty:**
  - Group 1 (`Operations`): Dashboard, Routine Operations, Routine Matrix, Scheduling Workbench (`PREVIEW / LOCKED` behind Track 2 Gates A–D).
  - Group 2 (`Configuration`): Room Pools, Faculty, Course Eligibility, Timetable Settings (`live-persisted`); Courses, Batches & Sections (`STAGED`).
  - Group 3 (`Directory & Alerts`): Campus Broadcast, User Whitelist, Academic Resources, My Profile.
- **Backend-Derived Command Center (`/admin/dashboard`):**
  - **Remove Phase 0 Hardcoded Placeholder:** Strip `CSE_Course_Distribution_Spring_2026_Final_v4.xlsx` and `9f4c8a...e21b` completely from `AdminDashboardPage.tsx` Stage 03.
  - **Manual Refresh & Timestamp:** Header action row shows `Last checked HH:MM:SS` (`tabular-nums`) plus a `36px` `Refresh` button.
  - **Empty Eligibility Warning:** Because production `yxqyrjyzxitrgkhgauli` currently has `0` rows in `timetable_course_eligibility` (`F-20` verified), show an explicit high-contrast semantic alert banner (`0 configured eligibility records`) with a direct link to `/admin/timetable/course-eligibility`.
  - **4-Stage Routine Readiness Checklist:** `01 Room Pools`, `02 Faculty & Off-Days`, `03 Course Eligibility & Time Grid`, `04 Active Routine & Engine Publication` using dissolved `1px`-divided ledger rows (never nested cards).
  - **5 Async States + Consistent Overlay Grammar:** Mandatory support for `loading` (layout-matched skeleton), `empty` (actionable CTA), `filter-empty` (one-click clear filters), `error` (`Service Recovery Paradox` retry preserving form state + recovery toast), and `locked`/`staged` banners — sharing unified confirmation modals (`Esc` dismissible), popovers, and recovery toasts across all admin screens.
  - **Static Preview Notice:** Both this brief's prototype and `AdminDashboardPage` dev-preview fallback must display an explicit banner stating `"Illustrative preview — disconnected from live Supabase & FastAPI backends."`

---

## 6. Video-Based Interaction Principles & Flutter Remediation Guardrails

1. **Invisible UI & Hover/Focus-Revealed Actions:** Secondary row actions (Inspect, Copy, Edit) stay visually hidden (`opacity: 0`, keyboard-focusable on `focus-within`) until row hover or keyboard focus.
2. **Hover-Revealed Copy Controls:** One-click copy buttons appear beside course codes, teacher acronyms, and revision IDs on hover/focus with crisp `"Copied"` confirmation.
3. **Corner-Triangle Override Markers + Consistent Radix Tooltips:** Overridden timetable cells or manual exceptions display a top-right corner triangle paired with unified Radix UI Tooltips (`TooltipProvider` `delayDuration={400}`, `skipDelayDuration={0}`).
4. **Inactive-Row Attenuation:** Inactive rooms, retired faculty, and archived versions dim using `--ink-muted` (`#696660`, verified `>= 4.89:1` AA) rather than translucent text that breaks WCAG contrast.
5. **Upfront Option-Level Filter Counts:** Filter pills/options display live tabular counts *before* clicking (`All (6)`, `Active (4)`, `Inactive (2)`).
6. **Matrix ↔ Compact List Switching:** Consistent segmented switch toggles between the 2D CSS Grid timetable and compact linear row scanning.
7. **Contextual Multi-Select Bulk Actions:** Batch action strip slides in cleanly only when 1+ table checkboxes are selected.
8. **Recharts Visualization Contract (Phase 2+):** Charts must render explicit X/Y axes, flat bar tops (never rounded pills), tabular ticks, and **sibling-bar hover dimming** (dimming non-hovered sibling bars smoothly).
9. **Cross-Screen Dimension & Remediation Consistency (incorporating `ADMIN_CRASH_PERFORMANCE_AND_UI_FIX_REPORT.md`):**
   - Uniform `36px` compact admin toolbar controls (`cross-axis` aligned flush with `>= 280px` unclipped `Section | Faculty | Room` lens segmented controls — never squeezed into narrow boxes).
   - Zero duplicate `+ +` button icon+text prefixes (icon buttons use clean verbs: `Add Room`, `Refresh`, `Generate Routine`).
   - Horizontal filter chips wrap naturally (`flex-wrap: wrap`, `gap: 8px`) instead of overflowing/clipping off-screen.
   - Default 2D timetable matrix claims 100% full canvas width (`selected == null`); clicking a slot opens a **closable `360px` right inspector (`[X]` close button)** at `>= 1100px` (modal sheet below `1100px`).

---

## 7. Motion Contract (`Motion` + CSS)

- **Timing Budgets:**
  - Panel/drawer/card **entrances:** `180–220ms` `cubic-bezier(0.16, 1, 0.3, 1)` (`ease-out`).
  - **Exits & dismissals:** ~20% shorter (`140–175ms`) `ease-in` / fast `ease-out`.
  - **Popovers & tooltips:** `150–180ms` origin-aware scale (`0.96 -> 1`).
  - **Press feedback:** `100ms` tactile `transform: scale(0.97)` on pointer `:active` down.
- **Interruptible Transitions:** Mid-flight clicks on constraint pills, Matrix ↔ List switches, or inspector drawers reverse cleanly using `Motion` `layoutId` and GPU-composited `transform`/`opacity` only.
- **Strict Prohibitions:** Zero everyday bounce/spring overshoot on admin controls, **zero autonomous visual loops or background `4.5s` auto-cycling timers**.
- **Reduced Motion Fallback:** App wrapped in `<MotionConfig reducedMotion="user">` alongside `@media (prefers-reduced-motion: reduce)` immediately suppressing transitions, disabling scale presses, and snapping to crisp static rest states (never `0.01ms` synthetic hacks).

---

## 8. Approved Phase 1A npm Package Delta (`apps/web/package.json`)

| Action | Package | Version | Role |
|---|---|---|---|
| **Install (`dependencies`)** | `motion` | `^14.14.0` | Sole animation library (`motion/react`), replacing `framer-motion`. |
| **Install (`dependencies`)** | `react-hook-form`, `zod`, `@hookform/resolvers` | `^7.92.0` / `^4.6.7` / `^7.0.8` | Form validation across `/login`, `/forgot-password`, `/reset-password`. |
| **Install (`dependencies`)** | `zustand` | `^5.1.0` | Lightweight shell/preview filter state. |
| **Install (`dependencies`)** | `sonner`, `clsx`, `tailwind-merge`, `class-variance-authority` | `^2.0.8` / latest | Toast recovery notifications (`sonner`) & CVA/Tailwind class merging (`src/lib/utils.ts`, `src/components/ui/`). |
| **Retain (`dependencies`)** | `@radix-ui/react-switch` | `^1.2.5` | Preserved for accessible Academic Ledger interactive rule switches (Jummah Block, R7 Off-Day). |
| **Install (`devDependencies`)** | `vitest`, `@testing-library/react`, `jsdom`, `@playwright/test` | `^4.1.12` / `^16.3.3` / `^31.0.1` / `^1.65.1` | Unit, opaque-sRGB WCAG contrast, auth/capability tests, & E2E verification. |
| **Remove** | `framer-motion` | *(remove existing)* | Eliminates overlapping motion package in favor of `motion`. |
| **Deferred to Phase 2+ / 4B** | `@tanstack/react-table`, `@tanstack/react-virtual`, `recharts` + `react-is`, `cmdk` | *(Phase 2 / 4B)* | Not needed for Phase 1A static shell & auth routes. |
