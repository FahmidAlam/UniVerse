# UniVerse React Web v1: Visual Direction & Marketable Onboarding Candidates

**Status:** Discovery & Owner Selection Gate (Pre-Figma / Pre-Scaffold)  
**Target Surface:** Standalone React Web Application (`apps/web/`, Administrator Console + Public Marketable Web Entry)  
**Mobile Boundary:** Flutter Android (`lib/`, `android/`) remains untouched for Students & Teachers under Obsidian Orbit (`#0B0C0E` + `#FF7A00`).  
**Research Provenance:** Authored under Option 3 (without Mobbin MCP, which required a paid upgrade, and without external screenshots), grounded directly in UniVerse's repository design contracts (`.agents/skills/react-web-academic-design-system`, `react-web-motion-and-craft`, `react-admin-backend-contracts`, `ui-backend-policy-correlation`), Leading University CSE's live engine schema (`engine/config.json`, `engine/solver.py`), and Routine Committee policy baseline (`R1–R16`, `D1–D6`, `CD1`).  
**Interactive Companion:** Open [`docs/architecture/design_directions_preview.html`](design_directions_preview.html) in Chrome to compare all 3 directions live across interactive specimens.

---

## 1. Strategic Framing & Hard Guardrails

UniVerse Web serves two distinct jobs without mixing their visual noise profiles:

1. **Public Marketable Web Entry (`/`, `/onboarding`, `/login`):** Demonstrates UniVerse's real differentiator to university leadership, committee members, and departmental admins. Visitors manipulate an **illustrative, 100% client-side Routine Engine Preview** (powered by realistic Leading University CSE sample fixtures) to see how Google OR-Tools CP-SAT turns Course Distribution workbooks, R1–R16 committee rules, faculty off-days, and room/lab pools into an organized weekly timetable. It must never call `POST /api/timetable/generate` unauthenticated, never claim unimplemented AI assistants, and must clearly direct Students and Teachers to the **UniVerse Android App**.
2. **Administrator Operations Console (`/admin/*`):** A high-density, low-fatigue workbench for timetable configuration, solver execution, provenance inspection, and routine publication. Post-auth activation replaces modal tours with a persistent **4-Stage Routine Readiness Checklist** and proactive anomaly alerts (empty production config tables, R7 off-day violations, Render cold-start health).

### Non-Negotiable Anti-Slop Exclusions (Enforced Across All 3 Directions)
- **Zero mobile theme reuse:** No `#0B0C0E` pitch black and no `#FF7A00` neon orange anywhere in `apps/web/`.
- **Zero generic AI clichés:** No purple gradients, no corporate navy/amber, no glowing ambient orbs, no dot-grid wallpaper, no 3-icon feature cards in a row, no bento-grid filler, no glassmorphism over dense data tables, no gradient circle-letter avatars, and no permanent 3px color stripes on every list row.
- **Zero default typography:** No bare `Inter`, `Geist`, or `Instrument Serif`.
- **Zero chrome pollution:** No Lucide icons (use `@phosphor-icons/web` / `@phosphor-icons/react`), no decorative sparkle icons, no filler badges (`Active`, `Verified`, `Default Baseline`), no `SECTION 01 · ALL CAPS` eyebrows, no trailing periods in headings, no emojis in titles, and no Lorem Ipsum.

### Shared Engineering & Craft Standards (Applied Uniformly)
- **OKLCH Perceptual Math:** Three linked neutral surfaces (`--bg-dark` recessed < `--bg` primary < `--bg-light` elevated) defined before brand hues; UI chroma capped at `C <= 0.16`; `color-mix(in oklab, ...)` only (avoiding Chromium's low-chroma `in oklch` pink-shift bug); full `@media (prefers-contrast: more)` and `@media (forced-colors: active)` support.
- **4 Depth Properties:** (1) Subtle vertical surface luminance shift revealed on hover, (2) calibrated alpha border, (3) overhead `--highlight` top inset edge, and (4) dual-layer alpha shadows (short tight shadow + longer soft shadow).
- **"Checkbox Off = Gray" Signaling:** Baseline settings and clean rows stay neutral slate. Semantic color fires exclusively for exceptions, overrides, and schedule categories (Theory, Lab, Joint `B+C`, Conflict / R7 Violation / Friday P4 Jummah Hard Block), always paired with Phosphor icons or explicit labels so color never stands alone.
- **Strict 4px Grid & Concentric Geometry:** `inner gap < outer padding`; matching horizontal control heights (`36px` compact admin bars, `40px` standard controls); optical button padding (`2x–3x` horizontal vs. vertical); concentric corners (`R_inner = R_outer - padding`); "Walmart Receipt" dissolved lists (`1px` alpha hairlines inside a single container, never bordered cards nested inside bordered cards).
- **Motion Physics:** Entrances `180–240ms cubic-bezier(0.16, 1, 0.3, 1)`, exits `140–180ms` (20% faster), origin-aware popovers (`scale(0.95 -> 1)`), tactile press (`scale(0.97)`), `±4px` horizontal error shake, `30ms` row stagger capped at 6 rows, `transform`/`opacity` + View Transitions / Framer `layoutId` only, and immediate rest-state rendering under `prefers-reduced-motion: reduce`.

---

## 2. Side-by-Side Comparison ("Music Producer" Matrix)

Each direction represents a genuinely different institutional mood, surface polarity, anchor foundry, background craft, and Star-of-the-Show staging.

| Dimension | Direction 1: **Sylhet Folio** | Direction 2: **Meridian Grid** | Direction 3: **Observatory Slate** |
| :--- | :--- | :--- | :--- |
| **Core Metaphor** | Archival University Register & Editorial Monograph | Swiss Railway Timetable & Architectural Blueprint | Astronomical Ephemeris & Nocturnal Operations Desk |
| **Polarity & Surface Hue** | Warm Archival Paper Light (`H = 82°`) | Cool Mineral Alabaster Light (`H = 245°`) | Deep Mineral-Teal Slate Dark (`H = 218°`, lifted `L >= 0.172`) |
| **Brand Primary Accent** | Botanical Tea-Leaf Pine (`oklch(0.44 0.105 154)`) | Swiss Technical Cobalt (`oklch(0.46 0.155 256)`) | Luminous Celadon Verdigris (`oklch(0.76 0.128 172)`) |
| **Headline Anchor Font** | **Fraunces** (Optical-size soft editorial serif) | **Bricolage Grotesque** (Optical architectural neo-grotesque) | **Newsreader** (Refined editorial ephemeris serif) |
| **UI & Body Font** | **Plus Jakarta Sans** | **IBM Plex Sans** | **DM Sans** |
| **Monospace Font** | **IBM Plex Mono** | **IBM Plex Mono** | **JetBrains Mono** |
| **Hero Depth Texture** *(Onboarding only)* | Fine cotton-paper speckled grain (`<= 2.2%`) + folio margin rules | Hairline drafting blueprint coordinates (`3.5%` opacity, masked) | Subtle orbital contour arcs + restrained fluted glass stage bezel |
| **Visual Rhyming Motif** | Orbital groove toggles + curved folio corner brackets | Concentric `12px/6px` precision rails + equatorial axis ticks | Concentric orbital track rings + satellite status nodes |
| **Best Fit For** | Institutional prestige, dean/committee trust, warm long-form reading | Maximum tabular density, clinical spreadsheet-grade scan speed | Low-glare late-evening scheduling runs, distinctive instrument authority |

---

## 3. Direction 1: Sylhet Folio

### Concept & Brand POV
**Sylhet Folio** honors Leading University's Sylhet hillside heritage and the solemn precision of an academic course register. Instead of cold SaaS whiteness or harsh dark neon, it pairs warm archival cotton-rag surfaces (`H = 82°`) with deep botanical pine ink (`H = 154°`). To a university dean, routine committee chair, or external visitor, it reads immediately as an enduring academic instrument built specifically for higher education rather than a generic project-management clone.

### OKLCH Neutral, Depth & Semantic Token Architecture

| Token | OKLCH Value | Role & Contrast Notes |
| :--- | :--- | :--- |
| `--bg-dark` | `oklch(0.932 0.012 82)` | Recessed warm parchment canvas & left sidebar rail |
| `--bg` | `oklch(0.966 0.009 82)` | Primary folio workspace, dissolved list body, matrix well |
| `--bg-light` | `oklch(0.992 0.005 82)` | Elevated interactive sheets, active cells, docked inspector |
| `--text-primary` | `oklch(0.215 0.014 75)` | Headings & primary cell codes (~89% ink, `~14.2:1` on `--bg`) |
| `--text-secondary` | `oklch(0.415 0.014 75)` | Course titles, form labels (~66% emphasis, `~7.4:1` on `--bg`) |
| `--text-muted` | `oklch(0.508 0.012 75)` | Slot timestamps, provenance notes (~52% emphasis, `~5.1:1` AA) |
| `--accent` | `oklch(0.440 0.105 154)` | Botanical Pine primary CTA, active tab, focus ring (`~8.1:1` on `--bg-light`) |
| `--accent-hover` | `oklch(0.382 0.112 154)` | Pressed/hover primary state |
| `--accent-ink` | `oklch(0.985 0.004 85)` | Text on `--accent` surfaces (`~8.6:1`) |
| `--surface-grad` | `linear-gradient(180deg, oklch(0.996 0.004 82), oklch(0.981 0.008 82))` | Depth Prop 1: Subtle warm paper sheen revealed on hover |
| `--border` | `oklch(0.220 0.014 75 / 0.11)` | Depth Prop 2: Softly blended ink hairline |
| `--highlight` | `inset 0 1px 0 oklch(1 0 0 / 0.88)` | Depth Prop 3: Overhead studio top bevel |
| `--shadow-elevated` | `0 1px 2px oklch(0.22 0.02 75 / 0.06), 0 10px 24px -8px oklch(0.22 0.02 75 / 0.09)` | Depth Prop 4: Dual-layer paper lift |

#### Schedule Semantics & Data Visualization Scales ("Checkbox Off = Gray")
- **Theory (`CSE-3101`, `RAB-302`):** Surface `oklch(0.944 0.022 238)`, Border `oklch(0.50 0.085 238 / 0.30)`, Ink `oklch(0.33 0.088 238)`.
- **Lab (`CSE-3102`, `ACL-1`):** Surface `oklch(0.938 0.028 154)`, Border `oklch(0.44 0.098 154 / 0.32)`, Ink `oklch(0.31 0.095 154)`.
- **Joint Section (`Batch 58 B+C`):** Surface `oklch(0.948 0.036 68)`, Border `oklch(0.56 0.115 62 / 0.36)`, Ink `oklch(0.38 0.098 58)`.
- **Conflict / R7 Violation / Friday P4 Jummah Block:** Surface `oklch(0.942 0.032 22)`, Border `oklch(0.54 0.145 22 / 0.38)`, Ink `oklch(0.39 0.148 22)` + subtle diagonal 45-degree hatch + Phosphor `ph-lock-simple` / `ph-warning` icon.
- **Load Density (Sequential 4-Step):** `oklch(0.94 0.015 154)` → `oklch(0.84 0.045 154)` → `oklch(0.66 0.085 154)` → `oklch(0.44 0.105 154)`.
- **Faculty Balance (Diverging):** Underload `oklch(0.52 0.095 235)` ↔ Balanced `oklch(0.86 0.010 82)` ↔ Overload `oklch(0.52 0.140 24)`.
- **Contrast & Forced Colors:** `@media (prefers-contrast: more)` deepens `--border` alpha to `0.28` and ink to `L = 0.15`; `@media (forced-colors: active)` replaces elevation shadows with `1px solid CanvasText` and `Highlight` focus outlines.

### Anchor-First Typography Pairing
- **Headline Anchor (`Fraunces`, weights 500–600, optical size `opsz`):** Distinctive editorial softness and ink-trap character give the public landing headline and institutional banners unmistakable scholarly weight without looking cliché. In-app dashboard headings are strictly capped at `22px` (`-0.025em` tracking, `1.18` line height).
- **UI & Body (`Plus Jakarta Sans`, weights 400–600):** Wide apertures and geometric clarity create crisp structural contrast against Fraunces and keep dense tables effortlessly readable at `13px–14px`.
- **Monospace (`IBM Plex Mono`, weights 400–500):** Dedicated strictly to course codes (`CSE-3101`), time slots (`08:50–10:05`), capacities, and revision hashes, paired with `font-variant-numeric: tabular-nums`.
- **Micro-Typography & Icons:** Small-caps `font-variant-caps: all-small-caps` on dense acronyms (`CSE`, `GED`, `SUST`, `ECL`), `text-underline-offset: 3px`, `text-wrap: balance` on headings, middle DOM truncation on `.xlsx` filenames/hashes, and `@phosphor-icons/web` Regular (`1.5px` stroke).

### Star of the Show, Visual Rhyming & Marketable Onboarding
- **Hero Stage ("The Living Folio"):** Full-bleed asymmetric composition (`58/42` on desktop `>= 1100px`) over a `2%` speckled cotton-paper grain backdrop. Left column presents the editorial value statement and the **Interactive Routine Engine Preview** framed as a stitched academic folio plate. Visitors toggle real committee constraints (**Friday P4 Jummah Block**, **R15: 6-Slot vs. 7-Slot Grid**, **R7: EBH Thu–Fri Off-Day**, **Lens: Section / Faculty / Room**) and watch `CSE-3101`, `CSE-3102 Lab`, and `Batch 58 B+C` smoothly glide into valid slots via `document.startViewTransition()`.
- **Visual Rhyming:** UniVerse's Orbit mark (central sphere + horizontal orbital ellipse + right-arc satellite) rhymes across the pine orbital switch tracks (satellite dot glides along an elliptical groove), active tab indicators, and curved folio stage corners (`16px` outer / `10px` inner with `6px` padding).
- **High-Conviction Auth & Role Clarity:** Right panel (`42%`) houses the Admin Sign-In sheet with explicit Leading University CSE provenance, an inline truthful notice (*"Interactive preview uses curated sample fixtures; live solving requires admin authorization"*), and a calm companion strip pointing Students and Teachers to the **UniVerse Android App**.
- **Post-Auth Activation:** Zero pop-up tours. Lands on the Admin Command Center featuring a dissolved "Walmart Receipt" **4-Stage Routine Readiness Checklist** (`01 Room Pools` -> `02 Faculty & Off-Days` -> `03 Course Eligibility & Time Grid` -> `04 Active Routine & Engine`) and proactive empty-config / R7 anomaly banners.

### Manual Figma Handoff Blueprint (Starter View Seat)
Create Variable Collection `UniVerse / Sylhet Folio` with groups `surface/*`, `ink/*`, `brand/*`, `semantic/*`, `radius/*` (`outer-16`, `inner-10`, `control-8`), and `type/*` (`Fraunces`, `Plus Jakarta Sans`, `IBM Plex Mono`). Author 3 frames at `1440×900` (plus `1024×768` responsive variants):
1. `01 Public Marketable Onboarding & Sandbox`: 58/42 split; left Living Folio interactive matrix + 4 constraint switches; right Admin Sign-In card + Android companion note.
2. `02 Admin Command Center`: `244px` warm recessed sidebar (`--bg-dark`), `56px` single-row header with Render engine status pill, proactive empty-config alert banner, and dissolved 4-stage readiness list.
3. `03 2D Operational Timetable Matrix + Docked Inspector`: Connected `36px` filter bar with live tabular match count, 6/7-slot matrix with semantic cells, and `360px` docked right-hand provenance inspector.

---

## 4. Direction 2: Meridian Grid

### Concept & Brand POV
**Meridian Grid** treats university scheduling as a precision Swiss transit system. Inspired by the iconic clarity of Swiss railway departure boards and architectural drafting tables, it uses cool mineral alabaster (`H = 245°`), crisp hairline rules, and authoritative Swiss Technical Cobalt (`H = 256°`). Every pixel earns its keep: administrators scanning 60+ sections and 30 classrooms get zero visual haze, razor-sharp column alignment, and instant anomaly recognition.

### OKLCH Neutral, Depth & Semantic Token Architecture

| Token | OKLCH Value | Role & Contrast Notes |
| :--- | :--- | :--- |
| `--bg-dark` | `oklch(0.946 0.008 245)` | Cool recessed navigation rail & outer structural canvas |
| `--bg` | `oklch(0.976 0.005 245)` | Crisp alabaster primary workspace surface |
| `--bg-light` | `oklch(0.996 0.002 245)` | Elevated interactive surface, cells, inspectors, menus |
| `--text-primary` | `oklch(0.195 0.018 252)` | Cool graphite primary ink (~90% ink, `~15.4:1` on `--bg`) |
| `--text-secondary` | `oklch(0.410 0.018 250)` | Secondary metadata & labels (~65% emphasis, `~7.8:1`) |
| `--text-muted` | `oklch(0.502 0.016 248)` | Quiet slot numbers & hashes (~50% emphasis, `~5.4:1` AA) |
| `--accent` | `oklch(0.460 0.155 256)` | Swiss Technical Cobalt primary action & active indicator (`~7.5:1`) |
| `--accent-hover` | `oklch(0.402 0.160 256)` | Hover/pressed cobalt |
| `--accent-ink` | `oklch(0.992 0.002 245)` | Text on `--accent` surfaces (`~7.6:1`) |
| `--surface-grad` | `linear-gradient(180deg, oklch(1 0.001 245), oklch(0.985 0.005 245))` | Depth Prop 1: Clean satin sheen on hover |
| `--border` | `oklch(0.200 0.020 252 / 0.105)` | Depth Prop 2: Calibrated Swiss hairline rule |
| `--highlight` | `inset 0 1px 0 oklch(1 0 0 / 0.94)` | Depth Prop 3: Crisp overhead light edge |
| `--shadow-elevated` | `0 1px 1.5px oklch(0.18 0.025 252 / 0.05), 0 8px 20px -6px oklch(0.18 0.025 252 / 0.08)` | Depth Prop 4: Tight architectural elevation |

#### Schedule Semantics & Data Visualization Scales ("Checkbox Off = Gray")
- **Theory (`CSE-3101`, `RAB-302`):** Surface `oklch(0.948 0.025 254)`, Border `oklch(0.48 0.135 256 / 0.28)`, Ink `oklch(0.34 0.135 256)`.
- **Lab (`CSE-3102`, `ACL-1`):** Surface `oklch(0.942 0.028 198)`, Border `oklch(0.47 0.095 198 / 0.32)`, Ink `oklch(0.31 0.092 198)`.
- **Joint Section (`Batch 58 B+C`):** Surface `oklch(0.952 0.032 82)`, Border `oklch(0.55 0.110 78 / 0.35)`, Ink `oklch(0.37 0.095 72)` (precision brass-bronze, zero purple).
- **Conflict / R7 Violation / Friday P4 Jummah Block:** Surface `oklch(0.946 0.034 26)`, Border `oklch(0.55 0.155 26 / 0.40)`, Ink `oklch(0.40 0.155 26)` + diagonal rule + Phosphor warning/lock glyph.
- **Load Density (Sequential 4-Step):** `oklch(0.94 0.018 256)` → `oklch(0.83 0.055 256)` → `oklch(0.65 0.105 256)` → `oklch(0.46 0.155 256)`.
- **Faculty Balance (Diverging):** Underload `oklch(0.52 0.100 198)` ↔ Balanced `oklch(0.88 0.006 245)` ↔ Overload `oklch(0.53 0.150 26)`.
- **Contrast & Forced Colors:** `@media (prefers-contrast: more)` raises border opacity to `0.26` and deepens `--text-muted` to `L = 0.38`; `@media (forced-colors: active)` switches cell rules and focus rings to `CanvasText` / `Highlight`.

### Anchor-First Typography Pairing
- **Headline Anchor (`Bricolage Grotesque`, weights 600–700):** An expressive modern neo-grotesque with subtle optical ink-traps and lively architectural curves that instantly distinguishes UniVerse from generic Inter/Geist dashboards while feeling unmistakably technical and Swiss. Dashboard headings stay `<= 22px` (`-0.025em` tracking, `1.16` leading).
- **UI & Body (`IBM Plex Sans`, weights 400–600):** Engineered specifically for dense operational tables, forms, and long-horizon screen readability, providing crisp geometric contrast against Bricolage Grotesque.
- **Monospace (`IBM Plex Mono`, weights 400–500):** Forms a true Super Family spine with IBM Plex Sans for all `CSE-3101` codes, `08:50–10:05` slots, room capacities, and SHA-256 hashes.
- **Micro-Typography & Icons:** `tabular-nums` everywhere, reserved bold width on segmented lens tabs (`display: inline-grid` ghost text trick so bolding active tabs causes zero horizontal jitter), small-caps acronyms (`CSE`, `GED`, `SUST`, `ECL`), and `@phosphor-icons/web` Regular (`1.5px` stroke).

### Star of the Show, Visual Rhyming & Marketable Onboarding
- **Hero Stage ("The Timetable Instrument Console"):** Set over a subtly masked drafting blueprint grid (`3.5%` opacity hairlines + coordinate ticks `P1–P7` on hero only; admin tables remain razor-clean). Above the live interactive timetable sits a flush `36px` instrument rail with live CP-SAT constraint readouts (`0 clashes · 6/6 rules`) and instant toggles for Friday Jummah, R15 6/7-Slot, R7 EBH Off-Day, and Section/Faculty/Room lens.
- **Visual Rhyming:** Tight concentric corners (`12px` outer / `6px` inner with `6px` padding), equatorial crosshair ticks borrowed from the Orbit mark's horizontal axis on empty grid cells, and a cobalt orbital pulse ring on the live Render engine health indicator.
- **High-Conviction Auth & Role Clarity:** Clean architectural sign-in sheet with explicit Leading University CSE Administrator badge, direct Android App companion link for Students and Teachers, and truthful client-side preview framing.
- **Post-Auth Activation:** Single-row `52px` top bar, compact `240px` left rail, proactive anomaly callout at the top of the workspace, and a dissolved 4-stage readiness ledger with aligned left labels and right-justified tabular completion fractions (`0 / 30 rooms`, `0 / 56 faculty`).

### Manual Figma Handoff Blueprint (Starter View Seat)
Create Variable Collection `UniVerse / Meridian Grid` (`surface/*`, `ink/*`, `brand/*`, `semantic/*`, `radius/outer-12`, `radius/inner-6`, `type/Bricolage-IBM`). Author the same 3 flagship frames (`1440×900` + `1024×768`):
1. `01 Public Marketable Onboarding & Sandbox`: Blueprint-masked hero with flush instrument bar, interactive matrix, and right-docked Admin Access column.
2. `02 Admin Command Center`: `240px` cool slate rail, `52px` top bar with engine health, dissolved 4-stage readiness table, and compact anomaly banner.
3. `03 2D Operational Timetable Matrix + Docked Inspector`: Connected `36px` filter toolbar, high-density Swiss grid with subtle cell coordinates, and `360px` docked provenance inspector.

---

## 5. Direction 3: Observatory Slate

### Concept & Brand POV
**Observatory Slate** delivers a refined nocturnal command desk built for focused, glare-free timetable operations, while breaking completely away from Flutter Android's `#0B0C0E` pitch black and `#FF7A00` neon orange. Grounded in lifted deep mineral blue-green slate (`H = 218°`, `L = 0.172–0.258`), soft alabaster ink (zero harsh `#FFFFFF`), and luminous celadon-verdigris accents (`H = 172°`), it evokes an astronomical ephemeris and orbital tracking station: serene, authoritative, and unmistakable.

### OKLCH Neutral, Depth & Semantic Token Architecture

| Token | OKLCH Value | Role & Contrast Notes |
| :--- | :--- | :--- |
| `--bg-dark` | `oklch(0.172 0.018 218)` | Recessed mineral slate canvas & navigation sidebar |
| `--bg` | `oklch(0.212 0.018 218)` | Primary workspace panel, dissolved lists, timetable well |
| `--bg-light` | `oklch(0.258 0.019 218)` | Elevated interactive layer (cards, cells, docked inspector) |
| `--text-primary` | `oklch(0.935 0.008 205)` | Soft alabaster ink (~88% luminance, `~12.4:1` on `--bg`, zero halation) |
| `--text-secondary` | `oklch(0.768 0.014 212)` | Secondary body & titles (~68% emphasis, `~7.6:1` on `--bg`) |
| `--text-muted` | `oklch(0.662 0.016 214)` | Muted metadata & timestamps (~54% emphasis, `~5.2:1` AA) |
| `--accent` | `oklch(0.760 0.128 172)` | Luminous Celadon-Verdigris primary action & active orbit node (`C = 0.128`) |
| `--accent-hover` | `oklch(0.812 0.132 172)` | Hover/focus lift |
| `--accent-ink` | `oklch(0.165 0.024 185)` | Deep pine-slate ink on `--accent` buttons (`~10.2:1` contrast) |
| `--surface-grad` | `linear-gradient(180deg, oklch(0.272 0.019 218), oklch(0.244 0.018 218))` | Depth Prop 1: Subtle top-lit slate sheen revealed on hover |
| `--border` | `oklch(0.920 0.012 205 / 0.115)` | Depth Prop 2: Crisp calibrated dark-surface alpha border |
| `--highlight` | `inset 0 1px 0 oklch(0.960 0.010 200 / 0.14)` | Depth Prop 3: Subtle overhead metallic bevel highlight |
| `--shadow-elevated` | `0 1px 2px oklch(0.08 0.015 218 / 0.46), 0 14px 30px -10px oklch(0.06 0.015 218 / 0.54)` | Depth Prop 4: Deep realistic dual-layer dark elevation |

#### Schedule Semantics & Data Visualization Scales ("Checkbox Off = Gray")
- **Theory (`CSE-3101`, `RAB-302`):** Surface `oklch(0.274 0.036 232)`, Border `oklch(0.70 0.105 232 / 0.34)`, Ink `oklch(0.87 0.062 230)`.
- **Lab (`CSE-3102`, `ACL-1`):** Surface `oklch(0.274 0.044 170)`, Border `oklch(0.74 0.118 170 / 0.38)`, Ink `oklch(0.89 0.072 168)`.
- **Joint Section (`Batch 58 B+C`):** Surface `oklch(0.292 0.040 84)`, Border `oklch(0.78 0.108 82 / 0.38)`, Ink `oklch(0.91 0.068 84)` (warm sand-gold, zero orange/purple).
- **Conflict / R7 Violation / Friday P4 Jummah Block:** Surface `oklch(0.276 0.052 20)`, Border `oklch(0.71 0.142 20 / 0.44)`, Ink `oklch(0.89 0.082 20)` + diagonal rule + Phosphor lock/warning icon.
- **Load Density (Sequential 4-Step):** `oklch(0.26 0.025 172)` → `oklch(0.38 0.065 172)` → `oklch(0.56 0.100 172)` → `oklch(0.76 0.128 172)`.
- **Faculty Balance (Diverging):** Underload `oklch(0.72 0.100 232)` ↔ Balanced `oklch(0.34 0.018 218)` ↔ Overload `oklch(0.70 0.140 20)`.
- **Contrast & Forced Colors:** `@media (prefers-contrast: more)` raises border alpha to `0.28` and lifts `--text-muted` to `L = 0.78`; `@media (forced-colors: active)` strips gradient textures and enforces explicit `CanvasText` borders.

### Anchor-First Typography Pairing
- **Headline Anchor (`Newsreader`, optical size `opsz`, weights 500–600 + subtle italic emphasis):** Pairs crisp editorial intelligence with the nocturnal slate canvas, making UniVerse feel like a prestigious research observatory rather than a gamer or crypto dark dashboard. Dashboard headings stay `<= 22px` (`-0.02em` tracking, `1.18` leading).
- **UI & Body (`DM Sans`, weights 400–600):** Clean, spacious low-contrast sans engineered for high legibility on dark surfaces without letter-bleeding.
- **Monospace (`JetBrains Mono`, weights 400–500):** Crisp tall x-height makes `CSE-3101`, `08:50–10:05`, room codes, and SHA-256 checksums pop with effortless clarity on slate surfaces.
- **Micro-Typography & Icons:** `tabular-nums`, reserved bold width on navigation & tabs, small-caps acronyms (`CSE`, `GED`, `SUST`, `ECL`), middle truncation on filenames/hashes, and `@phosphor-icons/web` Regular (`1.5px` stroke).

### Star of the Show, Visual Rhyming & Marketable Onboarding
- **Hero Stage ("The Ephemeris Orbit Stage"):** Framed by restrained fluted-glass vertical ribbing strictly along the outer hero bezel (never behind data cells) and faint `5%` orbital contour arcs. Inside sits a dark mineral timetable matrix where toggling Friday Jummah, R15 6/7-Slot, or R7 EBH Off-Day illuminates affected slots and smoothly glides classes into their newly solved coordinates.
- **Visual Rhyming:** Concentric elliptical pill rings (`16px` outer / `10px` inner with `6px` padding), luminous verdigris satellite dots marking active sidebar routes and active rules, and subtle orbital ring telemetry in the solver header.
- **High-Conviction Auth & Role Clarity:** Recessed slate Admin Sign-In sheet with overhead top-bevel highlight, Leading University CSE provenance, truthful preview disclaimer, and clear Android companion block for Students & Teachers.
- **Post-Auth Activation:** Deep slate Command Center with single-row header, Render engine status pulse, dissolved 4-stage readiness checklist, and proactive empty-config / R7 violation strip.

### Manual Figma Handoff Blueprint (Starter View Seat)
Create Variable Collection `UniVerse / Observatory Slate` (`surface/*`, `ink/*`, `brand/*`, `semantic/*`, `radius/outer-16`, `radius/inner-10`, `type/Newsreader-DM-JetBrains`). Author the 3 flagship frames (`1440×900` + `1024×768`):
1. `01 Public Marketable Onboarding & Sandbox`: Fluted bezel hero with orbital contour backdrop, live constraint sandbox, and high-trust Admin Sign-In panel.
2. `02 Admin Command Center`: `244px` deep slate sidebar, `54px` header with verdigris engine readout, proactive anomaly strip, and dissolved 4-stage readiness list.
3. `03 2D Operational Timetable Matrix + Docked Inspector`: Connected `36px` filter bar, glare-free slate matrix with clear semantic tokens, and `360px` docked provenance inspector.

---

## 6. Interactive Visual Lookbook & Decision Protocol

Open [`docs/architecture/design_directions_preview.html`](design_directions_preview.html) in Chrome to test all 3 directions live with an instant, zero-flash top switcher (`Sylhet Folio | Meridian Grid | Observatory Slate`). Each direction renders 3 complete interactive specimens:
1. **Specimen 1:** Marketable Public Entry, live Interactive Routine Engine Sandbox (working Friday Jummah, R15 6/7-Slot, R7 EBH Off-Day, and Section/Faculty/Room lens controls), and Admin Sign-In panel with Android companion note.
2. **Specimen 2:** Admin Command Center shell with persistent sidebar, live Render engine status pill, proactive empty-config / R7 anomaly banner, dissolved 4-Stage Readiness Checklist, and hover/focus-revealed ("invisible UI") row actions.
3. **Specimen 3:** 2D Operational Timetable Matrix with connected filter bar, live tabular match counts, clickable cells driving a docked right-hand provenance inspector (`Checkbox Off = Gray`), middle-truncated workbook filenames/hashes, and a live Service Recovery error-state preview toggle.

### Recommended Next Step After Owner Selection
Once you pick a winning direction (or a blend, such as **Direction 1 typography + Direction 2 cool alabaster palette**):
1. Lock the chosen tokens in `apps/web/src/styles/tokens.css` (and mirror into the manual Figma Variable Collection).
2. Scaffold `apps/web/` (React + TypeScript + Vite + Tailwind v4 + TanStack Query + Radix UI + Framer Motion + `@phosphor-icons/react`) against `react-admin-backend-contracts`.
