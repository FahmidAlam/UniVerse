# UniVerse React Web v1: Round 2 "Bold Rethink" Architectural Directions

**Status:** Round 2 Architectural Selection Gate (Pre-Scaffold / Pre-Figma)  
**Target Surface:** Standalone React Web Application (`apps/web/`, Public Marketable Web Entry + Administrator Operations Console)  
**Mobile Boundary:** Flutter Android (`lib/`, `android/`) remains untouched for Students and Teachers under Obsidian Orbit (`#0B0C0E` + `#FF7A00`).  
**Interactive Companion:** Open [`docs/architecture/design_directions_bold_preview.html`](design_directions_bold_preview.html) in Chrome to test all **6 states** (`Concept A / B / C` × `Light / Dark`) live.

---

## 1. Why Round 2 Exists (Breaking the Polite SaaS Mold)

Round 1 established clean OKLCH math and anti-slop typography, but all three candidates shared one safe wireframe: a 58/42 split box, soft rounded cards, and cobalt/green SaaS buttons. Round 2 breaks that ceiling by building **three genuinely different product architectures**, each varying:
- **Public `/` layout topology** (no 58/42 split box)
- **Corner & border geometry** (`0px–2px` hardware monolith vs. `12px/6px` precision bezel vs. `0px` `2px`-ruled press monograph)
- **Interactive Star-of-the-Show mechanics** (floating hardware command dock vs. GPU 3D-perspective convergence plane with Flatten-to-2D vs. inline editorial constraint ledger)
- **Auth staging** (native `<dialog>` right-edge slide-over sheet keeping the public stage uncluttered)
- **Paired Light + Dark OKLCH systems** (`L >= 0.165` lifted dark surfaces, zero `#000000`, zero `#FF7A00`, zero purple gradients, `color-mix(in oklab, ...)` only)

All three concepts preserve UniVerse's truthful boundaries: curated client-side Leading University CSE fixtures on `/` (never invoking `POST /api/timetable/generate` unauthenticated), explicit **UniVerse Android App** guidance for Students and Teachers, and fail-closed production guards (`0` seeded rooms/faculty in production today, single-teacher `publish_routine` constraint, R1–R16 / D1–D6 / CD1 fidelity).

---

## 2. Structural Comparison Matrix

| Dimension | Concept A: **Kinetic Transit Monolith** | Concept B: **Spatial Orbit Engine** | Concept C: **Avant-Garde Academic Press** |
| :--- | :--- | :--- | :--- |
| **Visual Reference Axis** | Swiss Departure Board × Teenage Engineering Hardware | 3D Perspective Hardware × Precision Instrument | MIT Press / Pentagram Monograph × Interactive Ledger |
| **Corner Geometry** | Razor-sharp `0px–2px` micro-radius + exposed coordinate rulers | Concentric `12px` outer / `6px` inner + top-lit bevel + outer fluted bezel | `0px` sharp publication grid, decisive `2px` ink rules + `1px` hairlines |
| **Public `/` Structure** | Full-bleed masthead + full-width departure board + **floating bottom hardware command dock** + right `<dialog>` sign-in | Centered instrument header + **interactive 3D-perspective convergence plane** (inputs → Orbit core → angled 3D matrix) + **"Flatten to 2D"** switch | Asymmetric monumental manifesto + **tabular proof colophon** + full-width **inline editorial constraint ledger** |
| **Primary CTA Ink** | High-contrast **Monochrome Ink** (Chalk ↔ Graphite; zero blue) | **Restrained Spectral Cyan-Emerald** (`H = 186° / 182°`) | High-contrast **Editorial Ink** (Charcoal ↔ Parchment) |
| **Signature Accent** | Surgical **International Signal Vermilion** (`H = 29°`, live pulse/conflicts only) | **Spectral Cyan-Emerald** beams & Orbit ring (`H = 182°`) | **Academic Oxblood / Carmine** rubrication (`H = 18° / 22°`) |
| **Typography** | **Bricolage Grotesque 800** (`56–70px`) + **IBM Plex Sans** + **IBM Plex Mono** | **Space Grotesk 600–700** (`44–56px`) + **IBM Plex Sans** + **JetBrains Mono** | **Fraunces 600–700** (`60–78px`) + **DM Sans** + **IBM Plex Mono** |
| **Light Polarity** | Warm Chalk (`H = 85°`) | Ceramic Daylight (`H = 228°`) | Warm Archival Ivory (`H = 84°`) |
| **Dark Polarity** | Graphite Carbon (`H = 240°`, `L >= 0.165`) | Deep Space Slate (`H = 230°`, `L >= 0.168`) | Deep Forest-Charcoal (`H = 165°`, `L >= 0.168`) |

---

## 3. Concept A: Kinetic Transit Monolith

### Architectural POV
Inspired by SBB Swiss departure boards and Teenage Engineering's tactile hardware interfaces, **Kinetic Transit Monolith** eliminates soft SaaS cards altogether. Every screen is framed by exposed coordinate axes (`SUN–SAT`, `P1–P7`), `0px–2px` hardware corners, monochrome ink buttons, and a single surgical **International Signal Vermilion** reserved strictly for live solver pulses, active time markers, and hard exceptions (Friday P4 Jummah, R7 off-day clashes, empty production table guards).

### Paired Light & Dark OKLCH Tokens

| Token | Light Mode (Warm Chalk, `H = 85°`) | Dark Mode (Graphite Carbon, `H = 240°`) | Role |
| :--- | :--- | :--- | :--- |
| `--bg-dark` | `oklch(0.912 0.008 85)` | `oklch(0.165 0.006 240)` | Recessed hardware housing / sidebar |
| `--bg` | `oklch(0.954 0.006 85)` | `oklch(0.205 0.006 240)` | Primary departure board & workspace |
| `--bg-light` | `oklch(0.988 0.003 85)` | `oklch(0.254 0.007 240)` | Raised keycaps, active cells, inspector |
| `--text-primary` | `oklch(0.145 0.008 80)` | `oklch(0.945 0.004 85)` | Monumental headlines & primary codes |
| `--text-secondary` | `oklch(0.365 0.008 80)` | `oklch(0.775 0.005 85)` | Body labels & metadata |
| `--text-muted` | `oklch(0.468 0.006 80)` | `oklch(0.675 0.005 85)` | Coordinate rulers & hashes (`>= 5.2:1` AA) |
| `--cta-bg` / `--cta-ink` | `oklch(0.145 0.008 80)` / `oklch(0.985 0.004 85)` | `oklch(0.938 0.006 85)` / `oklch(0.155 0.006 240)` | Solid monochrome primary actions |
| `--signal` | `oklch(0.495 0.192 29)` | `oklch(0.690 0.185 29)` | Surgical International Signal Vermilion |
| `--border` | `oklch(0.15 0.008 80 / 0.16)` | `oklch(0.94 0.005 85 / 0.14)` | Crisp `1px` architectural grid rules |
| `--highlight` | `inset 0 1px 0 oklch(1 0 0 / 0.85)` | `inset 0 1px 0 oklch(1 0 0 / 0.12)` | Machined top-edge bevel |
| **Theory Cell** | `bg: oklch(0.922 0.008 85)` / `ink: oklch(0.20 0.010 80)` | `bg: oklch(0.265 0.010 240)` / `ink: oklch(0.91 0.006 85)` | Calm monochrome transit slate |
| **Lab Cell** | `bg: oklch(0.934 0.024 185)` / `ink: oklch(0.27 0.072 185)` | `bg: oklch(0.268 0.036 185)` / `ink: oklch(0.89 0.062 185)` | Technical mineral teal |
| **Joint `B+C`** | `bg: oklch(0.942 0.032 78)` / `ink: oklch(0.32 0.088 72)` | `bg: oklch(0.285 0.036 80)` / `ink: oklch(0.91 0.062 82)` | Industrial brass-ochre |
| **Hard Block / Conflict** | `bg: oklch(0.938 0.036 29)` / `ink: oklch(0.38 0.165 29)` | `bg: oklch(0.275 0.058 29)` / `ink: oklch(0.90 0.095 29)` | Signal Vermilion + diagonal hatch + lock icon |

### Public `/` & Admin `/admin/*` Choreography
- **Public `/`:** Top editorial masthead (`Bricolage Grotesque 800`, `62px`) spans full width above a full-bleed departure-board schedule with exposed `P1–P7` / `SUN–FRI` coordinate rulers and an active vermilion time marker. Controls live in a **floating bottom hardware command dock** (tactile keycap switches for Friday Jummah, R7 `EBH` off-day, R15 6/7-Slot, and Section/Faculty/Room lens) triggering a crisp View Transitions cascade. Clicking **Admin Sign In** opens a native `<dialog>` right-edge slide-over drawer.
- **Admin `/admin/*`:** Exposed-grid Command Center with `0px` recessed rail, Render engine vermilion/ready LED telemetry, dissolved 4-stage readiness ledger with exact numeric right edges, and razor-sharp 2D matrix + docked inspector.

---

## 4. Concept B: Spatial Orbit Engine

### Architectural POV
**Spatial Orbit Engine** turns UniVerse's literal Orbit mark and CP-SAT pipeline into a tangible precision instrument. The public front door makes the automated solver *visibly spatial*: raw `.xlsx` workbook inputs flow across spectral cyan-emerald conduits through a central Orbit CP-SAT constraint ring directly into an angled 3D-perspective timetable plane. One click on **"Flatten to 2D Workbench"** smoothly collapses the 3D plane into flat inspection mode, bridging marketing spectacle directly into the calm, completely flat 2D `/admin/*` console.

### Paired Light & Dark OKLCH Tokens

| Token | Light Mode (Ceramic Daylight, `H = 228°`) | Dark Mode (Deep Space Slate, `H = 230°`) | Role |
| :--- | :--- | :--- | :--- |
| `--bg-dark` | `oklch(0.928 0.009 228)` | `oklch(0.168 0.018 230)` | Matte ceramic chamber / sidebar |
| `--bg` | `oklch(0.966 0.005 228)` | `oklch(0.208 0.018 230)` | Primary instrument workspace |
| `--bg-light` | `oklch(0.996 0.002 228)` | `oklch(0.258 0.020 230)` | Elevated optical layer & inspector |
| `--text-primary` | `oklch(0.185 0.018 232)` | `oklch(0.938 0.008 220)` | Sculptural headings & primary codes |
| `--text-secondary` | `oklch(0.390 0.016 232)` | `oklch(0.778 0.012 225)` | Labels & course titles |
| `--text-muted` | `oklch(0.482 0.014 232)` | `oklch(0.682 0.014 225)` | Telemetry metadata (`>= 5.3:1` AA) |
| `--accent` / `--accent-ink` | `oklch(0.435 0.112 186)` / `oklch(0.990 0.003 190)` | `oklch(0.762 0.124 182)` / `oklch(0.158 0.024 195)` | Spectral Cyan-Emerald Orbit & beams |
| `--border` | `oklch(0.20 0.018 232 / 0.11)` | `oklch(0.92 0.010 220 / 0.12)` | Calibrated optical hairline |
| `--highlight` | `inset 0 1px 0 oklch(1 0 0 / 0.94)` | `inset 0 1px 0 oklch(0.96 0.012 200 / 0.15)` | Overhead top-lit bevel |
| **Theory Cell** | `bg: oklch(0.944 0.024 238)` / `ink: oklch(0.31 0.095 238)` | `bg: oklch(0.275 0.038 234)` / `ink: oklch(0.89 0.062 232)` | Optical cobalt-slate |
| **Lab Cell** | `bg: oklch(0.938 0.028 182)` / `ink: oklch(0.28 0.092 182)` | `bg: oklch(0.274 0.044 180)` / `ink: oklch(0.90 0.072 178)` | Spectral emerald-cyan |
| **Joint `B+C`** | `bg: oklch(0.948 0.032 82)` / `ink: oklch(0.34 0.092 76)` | `bg: oklch(0.292 0.040 84)` / `ink: oklch(0.91 0.068 84)` | Warm instrument gold |
| **Hard Block / Conflict** | `bg: oklch(0.944 0.034 22)` / `ink: oklch(0.38 0.148 22)` | `bg: oklch(0.278 0.054 22)` / `ink: oklch(0.90 0.085 22)` | Signal coral-crimson + hatch |

### Public `/` & Admin `/admin/*` Choreography
- **Public `/`:** Centered `Space Grotesk` display header with explicit **"3D Engine View | Flatten to 2D Workbench"** switch. Below sits a restrained fluted-bezel stage housing 3 GPU-composited zones: (1) floating `.xlsx` distribution input cards (`Course_Dist_Sp26.xlsx`, `R7 Off-Days`, `Lab Pools`), (2) an interactive **Orbit CP-SAT Constraint Core** with spectral SVG conduits and rule toggles, and (3) a CSS 3D-tilted (`perspective(1200px) rotateX(10deg) rotateY(-5deg)`) live weekly timetable plane that flattens smoothly to 2D on click (and defaults flat automatically under `prefers-reduced-motion: reduce`).
- **Admin `/admin/*`:** Zero 3D tilt and zero fluted texture behind data. Calm flat 2D spatial console with concentric `12px/6px` framing, live Orbit telemetry bar, dissolved 4-stage readiness panel, and 2D Matrix + docked inspector.

---

## 5. Concept C: Avant-Garde Academic Press

### Architectural POV
Modeled after MIT Press monographs and Pentagram's editorial design systems, **Avant-Garde Academic Press** rejects modern "box-in-a-box" SaaS tropes in favor of typographic authority. Monumental `Fraunces` headlines, decisive `2px` ink horizontal dividers, `1px` column hairlines, monochrome ink buttons, and a single scholarly **Academic Oxblood / Carmine** rubrication accent make UniVerse feel like an authoritative university institution rather than a generic startup template.

### Paired Light & Dark OKLCH Tokens

| Token | Light Mode (Archival Ivory, `H = 84°`) | Dark Mode (Forest-Charcoal, `H = 165°`) | Role |
| :--- | :--- | :--- | :--- |
| `--bg-dark` | `oklch(0.918 0.013 84)` | `oklch(0.168 0.016 165)` | Recessed press margin / sidebar |
| `--bg` | `oklch(0.960 0.009 84)` | `oklch(0.206 0.016 165)` | Primary archival monograph sheet |
| `--bg-light` | `oklch(0.990 0.004 84)` | `oklch(0.252 0.018 165)` | Highlighted ledger cell / drawer |
| `--text-primary` | `oklch(0.175 0.015 70)` | `oklch(0.935 0.008 88)` | Monumental editorial ink |
| `--text-secondary` | `oklch(0.382 0.014 72)` | `oklch(0.775 0.012 95)` | Monograph body & column notes |
| `--text-muted` | `oklch(0.472 0.012 72)` | `oklch(0.680 0.014 115)` | Index numbers & metadata (`>= 5.3:1` AA) |
| `--cta-bg` / `--cta-ink` | `oklch(0.175 0.015 70)` / `oklch(0.985 0.005 84)` | `oklch(0.930 0.010 88)` / `oklch(0.168 0.016 165)` | Monochrome editorial press buttons |
| `--accent` | `oklch(0.415 0.148 18)` | `oklch(0.715 0.138 22)` | Academic Oxblood / Carmine rubrication |
| `--rule-heavy` | `2px solid oklch(0.175 0.015 70)` | `2px solid oklch(0.935 0.008 88 / 0.85)` | Decisive monograph horizontal rules |
| `--border` | `oklch(0.18 0.014 70 / 0.16)` | `oklch(0.93 0.008 88 / 0.14)` | Crisp `1px` hairline column dividers |
| **Theory Cell** | `bg: oklch(0.940 0.020 236)` / `ink: oklch(0.30 0.082 236)` | `bg: oklch(0.270 0.032 230)` / `ink: oklch(0.89 0.056 228)` | Archival slate-blue wash |
| **Lab Cell** | `bg: oklch(0.936 0.026 154)` / `ink: oklch(0.28 0.088 154)` | `bg: oklch(0.272 0.042 158)` / `ink: oklch(0.90 0.068 156)` | Botanical pine wash |
| **Joint `B+C`** | `bg: oklch(0.946 0.034 68)` / `ink: oklch(0.34 0.095 60)` | `bg: oklch(0.288 0.038 78)` / `ink: oklch(0.91 0.065 80)` | Warm parchment-ochre wash |
| **Hard Block / Conflict** | `bg: oklch(0.938 0.036 18)` / `ink: oklch(0.37 0.148 18)` | `bg: oklch(0.278 0.056 20)` / `ink: oklch(0.90 0.088 20)` | Oxblood rubrication + diagonal rule |

### Public `/` & Admin `/admin/*` Choreography
- **Public `/`:** Editorial press masthead (`2px` ink rules) above an asymmetric 8/4 front page: massive `Fraunces` manifesto (`68px`) on the left paired with a `1px`-ruled live **Tabular Proof Strip** (`796 active slots · 16 committee rules · 7-day grid · 30 rooms`) on the right. Directly underneath, a full-width **Interactive Constraint Ledger** puts crisp typographic rule toggles in a 3-column margin beside the live 9-column timetable register.
- **Admin `/admin/*`:** Hairline-divided academic register with zero bubbly cards, `2px` header rules, dissolved 4-stage readiness ledger, and high-legibility 2D operational matrix + docked provenance column.

---

## 6. Verification Checklist (All 6 States)

Verified in Google Chrome via Chrome DevTools Protocol across `Concept A / B / C` × `Light / Dark` at `1440px` and `1024px`:
1. All declared Google Fonts (`Bricolage Grotesque`, `Space Grotesk`, `Fraunces`, `IBM Plex Sans`, `DM Sans`, `IBM Plex Mono`, `JetBrains Mono`) and `Phosphor` icons load with `0` failures and `0` console errors.
2. Zero document-level horizontal overflow at `1440px` and `1024px` across all 6 states.
3. WCAG AA (`>= 4.5:1`) contrast verified on computed sRGB values across primary, secondary, muted, CTA, and semantic schedule tokens in both Light and Dark modes.
4. Interactive constraint switches (`Friday P4 Jummah`, `R7 EBH Off-Day`, `R15 6/7-Slot`, `Lens`), Concept B's `3D / Flatten to 2D` switch, native `<dialog>` Admin Sign-In slide-over, clickable 2D matrix cells + docked inspector, D5 override, zero-match filter reset, and Service Recovery timeout/retry all verified live.
5. `prefers-reduced-motion: reduce` natively flattens Concept B's 3D stage and disables spatial animations without using jarring `0.01ms` hacks.
