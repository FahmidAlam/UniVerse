---
name: react-web-academic-design-system
description: Governs theme discovery (Mobbin/Figma), OKLCH color architecture, anchor-first typography, visual rhyming, spacing geometry, and anti-slop rules for the standalone UniVerse React Web app (apps/web/). Use before theming, styling, or designing any React web screen or component.
---

# UniVerse React Web — Design System, Theme Craft & Anti-Slop Governance

## 1. Anti-Slop Theme Governance & Approved Design System Discipline
- **NEVER invent or hardcode a generic AI palette** (e.g., default purple gradients, generic corporate navy/amber, or unlinked raw hex codes outside `tokens.css`).
- **Separate Mobile & Web Identities:** Flutter Mobile (`lib/`, Android and iOS compatibility) retains Obsidian Orbit (`#0B0C0E` + `#FF7A00`). React Web (`apps/web/`) uses the owner-approved **UniVerse Academic Ledger** visual system (interchangeable Light + Dark / System; combining Precision Ledger, Campus Atelier, and Archival Registrar), stored centrally in `apps/web/src/styles/tokens.css`.
- **Approved v1 Direction Locked:** Do **not** reopen multi-direction discovery for React Web v1 screens or revive Spatial Orbit Engine. Reserve Mobbin/Figma multi-direction exploration strictly for future net-new product initiatives when explicitly requested by the owner.
- **Domain Grounding:** Every React Web surface must derive its visual density, terminology, and affordances from Leading University CSE routine operations and committee policies rather than generic SaaS templates.

---

## 2. Perceptual Color Architecture (OKLCH Math + 4 Depth Properties)
Once the owner approves a visual direction from Mobbin/Figma, translate it into **Tailwind v4 / CSS custom properties in OKLCH (`oklch(L C H)`)**—never raw unlinked hex values.

### Neutral Surface & Text Spine (Define Before Brand Accent)
1. **3 Perceptual Light Surfaces (Light-First; Dark Mode Deferred):** `--bg-dark` (recessed warm ledger canvas/sidebar), `--bg` (primary warm paper surface), `--bg-light` (crisp elevated sheet/card surface). Never ship a dark theme toggle or parallel dark palette in v1.
2. **Actual Opaque sRGB WCAG AA Verification:** Compute contrast ratios over **actual opaque composited sRGB foreground/background hex pairs** (not OKLCH `L` heuristics alone) via automated verification: primary text (`>= 7:1` AAA target, `>= 4.5:1` hard floor), secondary labels (`>= 4.5:1`), muted metadata/inactive-row text (`>= 4.5:1` for small text; `>= 3:1` strictly for non-text UI controls, borders, and focus rings) + `@media (prefers-contrast: more)` support.
3. **Calm Paper Depth Properties (Prevent Flatness Without Glare or 3D Clutter):**
   - **Subtle Surface Elevation:** Soft luminance step from warm ledger paper (`--bg-dark` / `--bg`) to elevated sheets (`--bg-light`).
   - **Calibrated Structural Hairlines:** Crisp `1px` ledger borders matching paper tone without noisy dark boxes.
   - **1px Specular Top Edge (`--highlight`):** Subtle top light highlight on elevated drawers/cards/actions.
   - **Soft Daylight Shadows:** Low-opacity dual-layer shadows (`short + ambient`) — zero neon glow or heavy drop-shadows.
4. **Controlled Chroma & Signaling Discipline:**
   - Keep UI chroma restrained (`C <= 0.14` in OKLCH for accents; neutral ink/paper spine keeps `C <= 0.015`).
   - **"Checkbox Off = Gray" Rule:** Default/baseline states stay neutral ledger slate. Semantic color activates **only** for exceptions, overrides, or schedule class categories (Theory, Lab, Joint `B+C`, Conflict/R7 Violation/Cancellation).
   - **Data Visualization Scales:** Sequential scales for load/utilization density; diverging scales for overload/underload balance. Recharts charts must render explicit axes, flat bar tops (never rounded candy bars), and **sibling-bar hover dimming** (dimming non-hovered sibling bars cleanly).
   - **Color Mixing Safety:** Always use `color-mix(in oklab, ...)` — never `in oklch` with low-chroma neutrals (avoids Chromium neutral hue bug 565837690).

---

## 3. Anchor-First Typography & Visual Rhyming
- **Locked Academic Ledger Font Stack (Zero Generic Defaults):**
  - Do **NOT** use bare **Inter**, **Geist**, **Instrument Serif**, or legacy **Space Grotesk** / **JetBrains Mono**.
  - **Editorial / Display Headlines (Archival Registrar):** **`Source Serif 4`** (`600`, `700`; `text-wrap: balance`, tight headline tracking on `/`, scholarly authority without marketing hype).
  - **UI, Forms & Dense Tables (Precision Ledger / Campus Atelier):** **`IBM Plex Sans`** (`400`, `500`, `600`).
  - **Codes, Slots, Tabular Numerals & Hashes:** **`IBM Plex Mono`** (`400`, `500`, `tabular-nums`) for course codes (`CSE-3101`), time slots (`08:50–10:05`), section counts, and revision hashes.
- **Visual Rhyming:** Echo subtle archival ledger geometry (`1px` structural hairlines, tabular cell proportion, crisp rectangular corner geometry) consistently across public mastheads, auth panels, dashboards, drawers, and schedule cells so every surface clearly belongs to one institution.
- **Dashboard Scale Cap & Micro-Typography:**
  - Cap in-app `/admin/*` workspace headings at `<= 24px` (`-0.02em` to `-0.03em` tracking, `1.15–1.2` leading); public `/` editorial headings in `Source Serif 4` scale deliberately with `text-wrap: balance` (zero widows).
  - **Tabular Numbers (`font-variant-numeric: tabular-nums`):** Mandatory on all grids, filter counts, slot times, capacities, and solver timers.
  - **Reserved Bold Width:** Prevent horizontal layout shift when tabs/links bold on active state.
  - **Optical Alignment & Smart Truncation:** Align labels by eye (`text-box-trim` / calibrated optical padding), use `line-clamp` for long course titles, **middle truncation** for `.xlsx` filenames/hashes, `text-underline-offset: 3px`, small-caps styling for dense acronyms (`CSE`, `GED`, `SUST`, `ECL`), and curly quotes in editorial copy.

---

## 4. Layout Geometry, Operational Table Ergonomics & Iconography
1. **Strict 4px (`0.25rem`) Grid & Cross-Screen Consistency:** Inner gap must always be smaller than outer container padding (`gap < padding`). Enforce identical cross-screen component dimensions and interaction grammar (`36px` compact admin bar controls, `40px` primary auth/form controls, uniform `12px`/`8px`/`6px` concentric radii where `R_inner = R_outer - padding`).
2. **Optical Button Padding:** Horizontal button padding = `2x–3x` vertical padding.
3. **"Walmart Receipt" Dissolved Lists:** Never nest 4-sided bordered cards inside bordered cards for lists, rules, or settings. Use one surface container with `1px` structural dividers and aligned left-text / right-numeric column edges.
4. **Public vs. Dense Table Surface Discipline:**
   - Public `/` Archival Registrar masthead may use **subtle archival paper grain (`<= 2–3%`)** paired with visual rhyming and a calm custom 2D preview. **Prohibit** fluted/layered glass, 3D perspective stages (`rotateX/rotateY`), and glowing conduits anywhere in `apps/web/`.
   - Authenticated `/admin/*` dense operational tables stay crisp and unadorned for extended administrative sessions.
5. **Dense Operational Table & Inspector Grammar:**
   - **Invisible UI:** Keep secondary row actions (Edit, Inspect, Archive) hidden until row hover or `focus-within`.
   - **Inactive-Row Dimming:** Visibly attenuate disabled rooms, inactive faculty, or archived versions while preserving WCAG AA text contrast.
   - **Hover-Revealed Copy Actions:** Reveal one-click copy triggers on row hover/`focus-within` for course codes, teacher codes, revision IDs, and hashes.
   - **Corner-Triangle Override Indicators + Radix Tooltips:** Mark manual overrides or exceptions with a clean corner-triangle cell indicator backed by a consistent **Radix UI Tooltip** explaining provenance/reason.
   - **Upfront Option-Level Filter Counts:** Show live counts beside filter options (`Theory (18)`, `Inactive (3)`) so admins anticipate result sizes before clicking.
   - **Matrix ↔ Compact List Switching:** Provide instant switching between the custom CSS Grid **2D Timetable Matrix** and compact flat row scanning where appropriate.
   - **Contextual Multi-Select Bulk Actions:** Reveal batch action toolbars strictly when 1+ rows are selected.
6. **Icon Consistency:** Use **`@phosphor-icons/react`** (`Regular` weight matching UI typography and mobile's Phosphor family). Do **NOT** use generic Lucide defaults or decorative sparkle icons.
7. **Masked Scroll Edges & `100dvh`:** Use CSS `mask-image` edge fades on scrollable timetable strips and dynamic viewport units (`min-h-dvh`).

---

## 5. Mandatory Anti-Slop & Anti-Vibe-Coded Gate
Verify **ZERO** violations before approving any screen:
- [ ] Zero filler badges (`Active`, `Verified`, `Default Baseline`, `Standard 3x/Wk`).
- [ ] Zero `SECTION 01 · ALL CAPS` eyebrows, zero periods in titles, zero code breadcrumbs, zero emojis in headings, zero em-dash spam.
- [ ] Zero vibe-coded clichés: no 3-icon feature cards in a row, no bento-grid filler, no glowing orbs, no dot-grid wallpaper, no purple gradients, no permanent color stripe on every stacked card, no gradient circle-letter avatars.
- [ ] Real `<title>` (`UniVerse — Academic Routine Platform`) and custom SVG favicon (never `"Vite + React"`).
- [ ] Zero Lorem Ipsum, fake testimonials, or unimplemented AI claims.
- [ ] Zero automated WCAG AA opaque-sRGB contrast failures.

---

## 6. Approved Web Theme: UniVerse Academic Ledger (Interchangeable Light + Dark / System)
Approved by Product Owner in `docs/architecture/WEB_ARCHITECTURE_DESIGN_BLUEPRINT.md`. Stored centrally in `apps/web/src/styles/tokens.css`.

### Three Complementary Design Pillars
1. **Precision Ledger:** Swiss-inspired grid discipline, crisp `1px` hairlines, high density, tabular numerals, administrative ergonomics.
2. **Campus Atelier:** Warm daylight paper tones, comfortable long-session contrast without stark glare, generous breathing room.
3. **Archival Registrar:** Scholarly `Source Serif 4` editorial credibility for `/` and auth entry.

### Explicit Visual Prohibitions (No Carryover)
- **Interchangeable Light + Dark (Light / Dark / System):** Full-parity Crisp Daylight Light and X-Grade Carbon Obsidian Dark modes under UniVerse Academic Ledger — strictly separate from Flutter's Obsidian Orbit (`#0B0C0E` + `#FF7A00`) and the retired cyan/3D Spatial Orbit prototype.
- **No Obsidian Orbit Carryover:** Completely separate from Flutter's `#0B0C0E` + `#FF7A00` mobile theme.
- **No Spatial Orbit Carryover:** Zero `Space Grotesk`, zero `JetBrains Mono`, zero cyan-emerald `H = 182°–186°` beams/conduits, zero counter-rotating SVG rings, zero 3D tilt, and zero fluted ribbing.

### Color Token Architecture (OKLCH -> Opaque Composited sRGB Verified)
- **Surfaces:** 4-layer near-achromatic Carbon-Obsidian (Dark, `C <= 0.006`) and Crisp Daylight (Light, `C <= 0.004`) palette (`--bg-canvas`, `--bg-surface`, `--bg-elevated`, `--bg-raised`).
- **Typography Ink Spine:** Stepped neutral ink `--ink-hero`, `--ink-primary`, `--ink-secondary`, `--ink-muted` — every pair must pass automated opaque sRGB WCAG AA checks (`>= 4.5:1` text, `>= 3:1` non-text controls) across all 4 surface tiers.
- **Primary Action & Brand Scale:** 10-step **X-Azure Blue** (`--brand-50`..`--brand-950`, `H = 246°–248°`); `--brand-600` for Light primary CTAs/accents, `--brand-500` for Dark primary CTAs (`#FFFFFF` ink `>= 4.5:1`), and `--brand-300` for Dark accents/links/focus rings. Only 1 primary CTA per screen carries solid `--action-primary` fill; active tabs/segmented controls use raised monochrome surfaces.
- **Charts & Semantics:** Perceptually uniform OKLCH charts (`--chart-1..4`) and 4 calm schedule categories (**Theory**, **Lab**, **Joint `B+C`**, **Hard Block / R7 Conflict**), all verified against opaque surfaces.