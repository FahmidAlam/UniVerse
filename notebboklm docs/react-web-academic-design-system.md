---
name: react-web-academic-design-system
description: Governs OKLCH color architecture, X-Grade Carbon Obsidian Dark + Crisp Daylight Light + X-Azure tokens, anchor-first typography, spacing geometry, and anti-slop rules for the standalone UniVerse React Web app (apps/web/). Use before theming, styling, or designing any React web screen or component.
---

# UniVerse React Web — Design System, Theme Craft & Anti-Slop Governance

## 1. Identity & Theme Governance
- **Separated Client Identities:** Flutter Mobile (`lib/`, Android and iOS Student/Teacher) retains **Obsidian Orbit** (`#0B0C0E` + `#FF7A00`). Standalone React Web (`apps/web/`, Admin Operations Console + Public `/`) uses **UniVerse Academic Ledger** (Theme v3: **X-Grade Carbon Obsidian Dark + Crisp Daylight Light + X-Azure**, interchangeable `Light` / `Dark` / `System` with pre-paint `public/theme-init.js`).
- **Central Token Authority:** All colors, surfaces, borders, and semantic tokens live in `apps/web/src/styles/tokens.css`. Never invent ad-hoc palettes, purple/cyan gradients, or raw unlinked hex values in components, and never revive the retired Spatial Orbit prototype.
- **Domain Grounding:** Derive density, terminology, and affordances from Leading University CSE routine operations and Routine Committee policies (`R1`–`R16`, `D1`–`D6`, `CD1`) rather than generic SaaS templates.

---

## 2. Perceptual Color Architecture (`tokens.css` OKLCH -> Opaque sRGB Verified)
1. **4-Layer Near-Achromatic Surface Spine (Full Light + Dark Parity):**
   - `--bg-canvas`, `--bg-surface`, `--bg-elevated`, `--bg-raised` across **Crisp Daylight Light** (`C <= 0.004`) and **X-Grade Carbon Obsidian Dark** (`C <= 0.006`).
   - Subtle `1px` structural hairlines (`--border-subtle`, `--border-default`), selective `1px` top specular edge (`--highlight`) on elevated drawers/modals, and restrained dual-layer shadows without neon glow or heavy blur.
2. **Opaque sRGB WCAG AA Contrast Floor:**
   - Stepped neutral ink (`--ink-hero`, `--ink-primary`, `--ink-secondary`, `--ink-muted`) verified over actual opaque composited sRGB foreground/background pairs (`tests/unit/tokensContrast.test.ts`): `>= 4.5:1` for text (`>= 7:1` AAA target for primary copy) and `>= 3:1` for non-text UI controls, borders, and focus rings, plus `@media (prefers-contrast: more)` support.
3. **10-Step X-Azure Brand Scale & Signaling Restraint:**
   - `--brand-50`..`--brand-950` (`H = 246°–248°`): `--brand-600` for Light primary CTAs/accents, `--brand-500` for Dark primary CTAs (`#FFFFFF` ink `>= 4.5:1`), and `--brand-300` for Dark links/focus rings.
   - **Single Primary Fill Rule:** At most 1 primary CTA per view carries solid `--action-primary` fill; active tabs and segmented controls use raised monochrome surfaces.
   - **"Checkbox Off = Gray" Rule:** Baseline/untouched states stay neutral slate with dot-pill status badges. Semantic color activates **only** for exceptions, overrides, or the 4 schedule categories (**Theory**, **Lab**, **Joint `B+C`**, **Hard Block / R7 Conflict / Cancellation**).
   - **Color Mixing Safety:** Always use `color-mix(in oklab, ...)` — never `in oklch` on low-chroma neutrals (avoids Chromium neutral hue interpolation artifacts).
   - **Charts (`--chart-1..4`):** Perceptually uniform OKLCH scales; Recharts bars use explicit axes, flat tops, and sibling-bar hover dimming.

---

## 3. Anchor-First Typography & Visual Rhyming
- **Locked Academic Ledger Font Stack:**
  - **Editorial / Display Headlines (`/`, Auth):** **`Source Serif 4`** (`600`, `700`; `text-wrap: balance`, scholarly authority).
  - **UI, Forms & Dense Tables (`/admin/*`):** **`IBM Plex Sans`** (`400`, `500`, `600`).
  - **Codes, Time Slots, Numerals & Hashes:** **`IBM Plex Mono`** (`400`, `500`, `tabular-nums`) for course codes (`CSE-3101`), slots (`08:50–10:05`), capacities, and SHA-256 hashes.
  - Do **NOT** introduce bare `Inter`, `Geist`, `Space Grotesk`, or `JetBrains Mono` in `apps/web/`.
- **Workspace Scale & Micro-Typography:**
  - Cap `/admin/*` page headings at `<= 24px` (`-0.02em` tracking, `1.15–1.2` leading).
  - Enforce `font-variant-numeric: tabular-nums` on all grids, counts, slot times, and timers; reserve bold width on tabs to prevent horizontal shift; use middle truncation for `.xlsx` filenames/hashes.

---

## 4. Layout Geometry, Operational Tables, Print & Iconography
1. **4px (`0.25rem`) Grid & Concentric Radii:** Inner gap `<` outer container padding; `36px` compact admin bar controls, `40px` primary auth/form controls; concentric radii (`12px` outer / `8px` inner / `6px` cell). Horizontal button padding = `2x–3x` vertical padding.
2. **Dissolved Lists ("Walmart Receipt"):** Never nest 4-sided bordered cards inside bordered cards; use one container with `1px` structural dividers and aligned left-label / right-numeric edges.
3. **Dense Operational Table & Inspector Grammar:**
   - **Invisible UI:** Reveal secondary row actions and one-click copy triggers on row hover or `focus-within`.
   - **Inactive-Row Dimming:** Attenuate inactive rooms/faculty or archived versions while keeping WCAG AA contrast.
   - **Override Provenance:** Mark manual overrides/corrections with corner-triangle indicators + Radix Tooltips.
   - **Upfront Filter Counts:** Show live counts (`Showing 14 of 23`, `Inactive (3)`) and contextual bulk toolbars only when `>= 1` row is selected.
4. **Custom 2D Timetable, Dynamic Break & Landscape A4 Print:**
   - Use custom CSS Grid scheduling matrices (`AcademicTimetableMatrix`, `CommitteeDaySheetView`) with dynamic midday break positioning (`breakAfterSlot` / `friday_no_p4` Jummah lock) and dedicated `@media print` Landscape A4 single-sheet pagination — never a Gregorian calendar library.
5. **Icons:** Use **`@phosphor-icons/react`** (`Regular` weight); no Lucide defaults or decorative sparkles.

---

## 5. Mandatory Anti-Slop Gate
Verify **ZERO** violations before completing any `apps/web/` UI change:
- Zero filler badges (`Active`, `Verified`, `Default Baseline`, `Standard 3x/Wk`).
- Zero `SECTION 01 · ALL CAPS` eyebrows, trailing title periods, emojis in headings, 3D tilt (`rotateX/rotateY`), fluted glass, or orbital rings.
- Zero Lorem Ipsum, fake testimonials, or unbacked AI claims.
- Zero automated WCAG AA opaque-sRGB contrast failures (`npm --prefix apps/web test`).
