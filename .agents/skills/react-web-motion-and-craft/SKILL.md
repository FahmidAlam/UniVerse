---
name: react-web-motion-and-craft
description: Governs marketable web onboarding & interactive product showcases, motion physics, timing budgets, progressive disclosure, invisible UI for dense admin dashboards, and error recovery in apps/web/. Load before building onboarding flows, interactive controls, modals, drawers, tables, or async workflows.
---

# UniVerse React Web — Marketable Onboarding, Motion Physics & Dashboard Craft

## 1. Clearing the Commodity Ceiling (Beyond "Design Theater")
Premium products win on **connective tissue and unglamorous states**:
1. **All 5 States Required on Every Async Surface:** `loading` (layout-matched skeleton, zero layout shift), `first-use empty` (actionable setup nudge), `zero-filter-match empty` (one-click clear filters), `recoverable error` (*Service Recovery Paradox*: clear diagnosis + 1-click retry/undo preserving form input), and `locked / staged capability` (truthful backend gate).
2. **Optimistic Updates (< 400ms Doherty Threshold):** Apply reversible admin edits immediately and roll back cleanly with an error toast + subtle horizontal shake if Supabase rejects the write.
3. **Explicit Control States:** Every interactive control supports `default`, `hover`, `focus-visible`, `active`, `disabled`, and `loading`.

---

## 2. Marketable Web Entry & Interactive Onboarding Architecture
UniVerse's web front door (`/`, `/onboarding`, `/login`) must feel like a **flagship, marketable academic SaaS product**—not a bare login box and not a generic feature list.

### Core Storytelling Principles (Grounded in Onboarding & Web Craft Research)
1. **Sell the Outcome, Show the Product in Action:** Lead with UniVerse's genuine differentiator—its **Automated University Routine Generation Engine** (ingesting Course Distribution workbooks, faculty off-days, room/lab pools, and committee rules via Google OR-Tools CP-SAT to assemble an organized timetable that powers daily campus life).
2. **User-Controlled Illustrative Timetable Preview (Public `/`):**
   - Make the centerpiece of the public institutional entry (`/`) an **interactive, user-controlled CSS Grid timetable preview**—not auto-playing marketing slides and not a 3D spinning stage.
   - Let visitors (deans, committee members, faculty, or students) **click real-feeling illustrative constraint toggles** (e.g., *Friday Jummah Hard Block*, *Faculty Off-Day*, *6-Slot vs. 7-Slot Grid*, *Section / Faculty / Room Lens*) and watch timetable slots reorganize calmly via shared-element `Motion` `layoutId` transitions.
   - **No Auto-Cycling Loop & No 3D Stage:** The preview responds strictly to explicit user controls (zero involuntary `4.5s` background timers, zero 3D tilt, zero fluted bezels, zero rotating orbital rings).
   - **Truthfulness Guardrail:** Clearly label the pre-auth preview as an *Illustrative Institutional Preview* powered by client-side Leading University CSE fixtures—never invoke the live backend unauthenticated, never claim unimplemented AI assistants, and never promise guaranteed conflict-free output.
3. **High-Conviction Auth & Mobile Guidance:**
   - Frame the Admin Sign-In / Access panel cleanly around operational institutional value and provide a clear **Flutter Mobile companion path** for Students and Teachers, keeping React Web v1 focused cleanly on Administrators.
4. **Post-Auth Activation Without Pop-up Fatigue:**
   - Never ambush newly signed-in admins with multi-step modal tours. Replace onboarding pop-ups with a persistent, dismissible **Routine Readiness Checklist** on `/admin/dashboard` whose completion signals are **100% derived from real Supabase & FastAPI state** (zero hardcoded fixture metadata, SHA hashes, or fake readiness badges).

---

## 3. Motion Physics & Timing Budgets (`Motion` + CSS)
Use the single **`motion`** package (`motion/react`) plus clean CSS transitions—never duplicate `framer-motion` alongside `motion`. Motion acts strictly as a **communication layer** explaining origin, state continuity, and confirmation.

| Interaction | Timing | Easing / Physics | Mandatory Rule |
| :--- | :--- | :--- | :--- |
| **Entrances (Panels, Drawers, Stage Reveals)** | `180–240ms` | `ease-out` (`cubic-bezier(0.16, 1, 0.3, 1)`) | Crisp settle. **Zero bounce on everyday admin UI.** |
| **Exits (Dismissals)** | **20% shorter** (`140–180ms`) | `ease-in` / fast `ease-out` | Never delay dismissal. |
| **Popovers & Dropdowns** | `150–220ms` | `ease-out`, `scale(0.95 -> 1)` | **Origin-aware:** enter from trigger, exit to trigger. |
| **Shared-Element Moves & Interactive Grid** | `220–300ms` | `ease-in-out` or critically damped spring | Reuse identical `layoutId` (`motion/react`) for sliding view switches, active nav indicators, and user-toggled public preview cells. |
| **Press Feedback** | `100–140ms` | `scale(0.97)` on pointer down | Direct tactile response; **don't tween while held/dragged**. |
| **List Row Stagger** | `30ms` per row (cap at `6` rows) | `ease-out` | Never stagger 50 dense rows. |
| **Error Feedback** | `260ms` | Horizontal **shake (`±4px`)** | Pair with inline text and focus move. |
| **Success Confirmation** | `300ms` | Subtle confirmation pulse + icon crossfade | Confirms publish/save cleanly. |

### Performance & Accessibility Mandates
- **GPU Properties Only:** Animate `transform` and `opacity` (never `left`/`top`/`width`). Use CSS Grid `0fr -> 1fr` or `Motion` layout transitions for smooth `height: auto`.
- **Interruptible & Overlapping:** Mid-flight clicks reverse cleanly; overlap old and new states to avoid blank flashes.
- **Tooltip Skip Delay:** Configure Radix `TooltipProvider` with `delayDuration={400}` and `skipDelayDuration={0}` so rapid toolbar scanning feels instant.
- **Reduced Motion:** Wrap app root in `<MotionConfig reducedMotion="user">`; under `@media (prefers-reduced-motion: reduce)`, render assembled rest states immediately with zero synthetic `0.01ms` hacks.

---

## 4. Academic Ledger Admin Dashboard & Dense Table Ergonomics
1. **Truthful Operational Insights Over Wallpaper Charts:** Ditch decorative KPI wallpaper. Lead `/admin/dashboard` with **live backend-derived readiness & anomaly cues** (empty config tables, active routine freshness, FastAPI health) without hardcoded `.xlsx` filenames/SHAs.
2. **Custom 2D CSS Grid Timetable + Compact List:** Schedules live in a custom **CSS Grid 2D Timetable Matrix** (Section / Faculty / Room lenses) with instant **Matrix ↔ Compact List** switching—never forced into a conventional Gregorian calendar library.
3. **Connected Filtering & Upfront Filter Counts:** Show filters above tables/grids with live match totals (`Showing 14 of 23 offerings`) and upfront option-level counts (`Inactive (3)`) so counts are visible before toggling.
4. **Progressive Disclosure & "Invisible UI":**
   - Keep secondary row actions and **hover-revealed copy triggers** hidden until row hover or `focus-within`.
   - Apply **inactive-row dimming** cleanly while preserving AA text contrast.
   - Surface manual overrides via clean **corner-triangle indicators** backed by consistent **Radix UI Tooltips**.
   - Show **contextual multi-select bulk actions** only when 1+ rows are selected.
   - Apply uniform cross-screen control dimensions (`36px` compact admin bars, `40px` primary forms), **Popovers** for display preferences, **Docked Inspectors (`>= 1100px`)** for detail/editing, **Modals** for high-stakes confirmations, and **Comboboxes** (`cmdk` / Radix) when choosing from `> 10` items.
   - **Recharts Hover Discipline:** Explicit axes, flat bar tops, and **sibling-bar hover dimming**.
   - Respect keyboard fluency (`/` focuses search, `Esc` closes drawers/modals, arrow keys traverse comboboxes/tabs) and Fitts's Law (`>= 36px` desktop / `>= 44px` touch).

---

## 5. Archival Craft & Restrained Motion Boundaries (UniVerse Academic Ledger)
Strict boundary rules replacing the superseded Spatial Orbit 4-layer kinetic loop:

1. **Public Institutional Entry (`/` & Auth Routes):**
   - Light-first **Archival Registrar** daylight paper canvas; subtle archival paper grain (`<= 2–3%`) may texture the outer public masthead only, with consistent visual rhyming across `1px` rules and containers.
   - The illustrative timetable preview responds exclusively to explicit user clicks/toggles (`Motion` `layoutId` / CSS transitions).
   - **Prohibited Everywhere:** Zero 3D CSS perspective stages (`rotateX/rotateY`), zero pointer-reactive 3D card tilt, zero fluted vertical ribbing, zero counter-rotating orbital SVG rings, zero flowing neon conduits, and zero automatic background cycling timers.
2. **Authenticated Admin Console (`/admin/*`):**
   - 100% flat 2D **Precision Ledger** and **Campus Atelier** workspace with zero decorative background textures behind data tables.
   - Motion is strictly functional (panel/drawer slide, optimistic rollback shake, filter/view switch, validation focus), never ambient or celebratory wallpaper.
3. **Honest Async & Solver Progress:** Never animate fabricated percentage bars or fake CP-SAT solver countdowns; reflect actual job submission/polling state (`queued`/`running`/actual elapsed timer).