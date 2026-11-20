---
name: react-web-academic-design-system
description: Governs theme discovery (Mobbin/Figma), OKLCH color architecture, anchor-first typography, visual rhyming, spacing geometry, and anti-slop rules for the standalone UniVerse React Web app (apps/web/). Use before theming, styling, or designing any React web screen or component.
---

# UniVerse React Web — Design System, Theme Craft & Anti-Slop Governance

## 1. Anti-Slop Theme Governance (Mobbin + Figma + "Music Producer" Rule)
- **NEVER invent or hardcode a generic AI palette** (e.g., default purple gradients, generic corporate navy/amber, or random hex codes).
- **Separate Mobile & Web Identities:** Flutter Android (`lib/`) retains Obsidian Orbit (`#0B0C0E` + `#FF7A00`). React Web (`apps/web/`) derives its own distinctive, approved visual system—free of the dark-black/neon-orange association—stored centrally in `apps/web/src/styles/tokens.css`.
- **Mandatory Multi-Direction Exploration ("Music Producer" Method):** Before locking the web theme or redesigning a flagship surface (Onboarding, Dashboard, Timetable Matrix):
  1. Query real-world SaaS, editorial, and operational references via the **Mobbin** plugin and/or inspect approved frames via the **Figma** plugin.
  2. Propose **3 genuinely distinct visual directions** (varying mood, anchor typography, surface treatment, and Star-of-the-Show concept)—never minor tweaks of a first draft.
  3. Adapt the owner-selected reference smoothly to UniVerse's domain (academic routine lifecycle, Leading University CSE) rather than copying blindly.

---

## 2. Perceptual Color Architecture (OKLCH Math + 4 Depth Properties)
Once the owner approves a visual direction from Mobbin/Figma, translate it into **Tailwind v4 / CSS custom properties in OKLCH (`oklch(L C H)`)**—never raw unlinked hex values.

### Neutral Surface & Text Spine (Define Before Brand Accent)
1. **3 Perceptual Neutral Surfaces:** `--bg-dark` (recessed canvas/sidebar), `--bg` (primary surface), `--bg-light` (elevated/interactive surface). Lighter always reads as closer to the user in **both** light and dark themes.
2. **Explicit Opacity & Contrast Hierarchy:** Never put all text at 100% opacity. Use stepped emphasis: primary headings (`100%` / `~87%` perceptual ink—never harsh pure `#FFFFFF` on `#000000`), secondary labels (`60%–70%` emphasis), muted metadata (`45%–55%`, strictly verified for WCAG AA `>= 4.5:1` body and `>= 3:1` UI controls + `@media (prefers-contrast: more)` support).
3. **The 4 Depth Properties (Prevent Flatness Without Clutter):**
   - **Subtle Surface Gradient:** Slight vertical luminance shift across `--bg` and `--bg-light`, revealing full sheen on hover.
   - **Calibrated Alpha Border:** Crisp alpha border in dark surfaces; softly blended border matching surface lightness in light surfaces.
   - **Overhead Top Highlight (`--highlight`):** Subtle top-edge highlight simulating overhead lighting on elevated panels/CTAs.
   - **Dual-Layer Alpha Shadows:** Combine one short, darker shadow with one longer, softer shadow for realistic elevation.
4. **Controlled Chroma & Signaling Discipline:**
   - Keep UI chroma restrained (`C <= 0.15–0.20` in OKLCH) to prevent chromostereopsis and harsh glare.
   - **"Checkbox Off = Gray" Rule:** Default/baseline states stay neutral slate. Semantic color activates **only** for exceptions, overrides, or schedule class categories (Theory, Lab, Joint `B+C`, Conflict/R7 Violation/Cancellation).
   - **Data Visualization Scales:** Sequential scales for load/utilization density; diverging scales for overload/underload balance.
   - **Instant Theme Switch:** If dark/light switching is offered, disable root color transitions for 1 frame so surfaces snap cleanly.

---

## 3. Anchor-First Typography & Visual Rhyming
- **Level 2 or Level 3 Font System (Ban Generic AI Defaults):**
  - Do **NOT** default to bare **Inter**, **Geist**, or overused **Instrument Serif**.
  - Choose either a **Super Family** (matched sans + serif + mono) or an **Anchor-First Pairing**: select a distinctive **Headline Anchor Font** (from Figma/Mobbin direction) that establishes UniVerse's institutional personality, then pair a structurally contrasting, high-legibility body/UI font + a crisp monospace strictly for course codes (`CSE-3101`), time slots (`08:50–10:05`), capacities, and revision hashes.
- **Visual Rhyming:** Echo geometric motifs from UniVerse's **Orbit mark** and **Routine Grid** subtly across icon strokes, button accents, masks, and callout frames so every page feels part of one cohesive universe.
- **Dashboard Scale Cap & Micro-Typography:**
  - Cap in-app dashboard headings at `<= 24px` (`-0.02em` to `-0.03em` tracking, `1.15–1.2` leading); public onboarding/hero display typography may scale boldly with `text-wrap: balance` (zero widows).
  - **Tabular Numbers (`font-variant-numeric: tabular-nums`):** Mandatory on all grids, counts, slot times, and solver timers.
  - **Reserved Bold Width:** Prevent horizontal layout shift when tabs/links bold on active state.
  - **Optical Alignment & Smart Truncation:** Align labels by eye (`text-box-trim` / calibrated optical padding), use `line-clamp` for long course titles, **middle truncation** for `.xlsx` filenames/hashes, `text-underline-offset: 3px`, small-caps styling for dense acronyms (`CSE`, `GED`, `SUST`, `ECL`), and curly quotes in editorial copy.

---

## 4. Layout Geometry, Tactile Depth & Iconography
1. **Strict 4px (`0.25rem`) Grid:** Inner gap must always be smaller than outer container padding (`gap < padding`). Horizontal control bars must enforce matching control heights (`36px` compact admin bar, `40px` standard).
2. **Optical Button Padding & Concentric Radius:** Horizontal button padding = `2x–3x` vertical padding. Nested corners must follow `R_inner = R_outer - padding`.
3. **"Walmart Receipt" Dissolved Lists:** Never nest 4-sided bordered cards inside bordered cards for lists, rules, or settings. Use one surface container with `1px` alpha dividers and aligned left-text / right-numeric column edges.
4. **Subtle Real-World Depth:** On marketing/onboarding canvases, subtle noise/grain (`<= 2–3%`), fluted/layered glass accents, or restrained 3D spatial depth may be used **only** if they support (never compete with) the Star of the Show. Inside high-density admin tables, keep backgrounds ultra-clean for zero visual fatigue.
5. **Icon Consistency:** Use **`@phosphor-icons/react`** (matched stroke weight to typography, matching mobile's Phosphor family). Do **NOT** use generic Lucide defaults or decorative sparkle icons.
6. **Masked Scroll Edges & `100dvh`:** Use CSS `mask-image` edge fades on scrollable timetable strips and dynamic viewport units (`min-h-dvh`).

---

## 5. Mandatory Anti-Slop & Anti-Vibe-Coded Gate
Verify **ZERO** violations before approving any screen:
- [ ] Zero filler badges (`Active`, `Verified`, `Default Baseline`, `Standard 3x/Wk`).
- [ ] Zero `SECTION 01 · ALL CAPS` eyebrows, zero periods in titles, zero code breadcrumbs, zero emojis in headings, zero em-dash spam.
- [ ] Zero vibe-coded clichés: no 3-icon feature cards in a row, no bento-grid filler, no glowing orbs, no dot-grid wallpaper, no purple gradients, no permanent color stripe on every stacked card, no gradient circle-letter avatars.
- [ ] Real `<title>` (`UniVerse — Academic Routine Platform`) and custom Orbit SVG favicon (never `"Vite + React"`).
- [ ] Zero Lorem Ipsum, fake testimonials, or unimplemented AI claims.