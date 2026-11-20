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
1. **Sell the Outcome, Show the Product in Action (Timo / Front Pattern):** Lead with UniVerse's genuine differentiator—its **Automated University Routine Generation Engine** (ingesting Course Distribution workbooks, faculty off-days, room/lab pools, and committee rules via Google OR-Tools CP-SAT to assemble an organized timetable that powers daily campus life).
2. **"The Star of the Show" — Interactive Try-Before-Signup Sandbox (Alma Pattern):**
   - Make the centerpiece of the web onboarding/entry an **interactive, manipulable Routine Engine Stage**—not static icons or dead slides.
   - Let visitors (deans, committee members, stakeholders, or admins) **click/toggle real-feeling illustrative constraints** (e.g., *Toggle Friday Jummah Block*, *Mark Faculty Off-Day*, *Switch 6-Slot vs. 7-Slot Grid*, *Switch Student / Teacher / Admin Lens*) and watch the timetable grid dynamically re-arrange with crisp shared-element `layoutId` motion!
   - **Truthfulness Guardrail:** Clearly frame the pre-auth sandbox as an *Interactive Engine Preview* using realistic Leading University CSE sample data—never invoke the live backend unauthenticated, never promise unimplemented AI assistants, and never claim guaranteed 100% conflict-free output.
3. **High-Conviction Auth & Role Clarity (Superhuman / Endel Pattern):**
   - Turn the Sign-In / Admin Access panel into a crisp, high-trust entry point showing concrete institutional value (Routine Lifecycle Engine + Leading University CSE provenance + direct pointer to the **UniVerse Android App** for Students and Teachers, keeping Web v1 cleanly focused on Administrators).
4. **Post-Auth Activation Without Pop-up Fatigue (Mural Pattern):**
   - Never ambush newly signed-in admins with 6-step modal tours. Replace onboarding pop-ups with a persistent, dismissible **4-Stage Routine Readiness Checklist** on the Admin Dashboard (`01 Room Pools -> 02 Faculty & Off-Days -> 03 Course Eligibility & Time Grid -> 04 Active Routine & Engine`) that tracks real database state.

---

## 3. Motion Physics & Timing Budgets
Motion is a **communication layer** explaining origin, state continuity, and confirmation.

| Interaction | Timing | Easing / Physics | Mandatory Rule |
| :--- | :--- | :--- | :--- |
| **Entrances (Panels, Drawers, Stage Reveals)** | `180–240ms` | `ease-out` (`cubic-bezier(0.16, 1, 0.3, 1)`) | Crisp settle. **Zero bounce on everyday admin UI.** |
| **Exits (Dismissals)** | **20% shorter** (`140–180ms`) | `ease-in` / fast `ease-out` | Never delay dismissal. |
| **Popovers & Dropdowns** | `150–220ms` | `ease-out`, `scale(0.95 -> 1)` | **Origin-aware:** enter from trigger, exit to trigger. |
| **Shared-Element Moves & Interactive Grid** | `220–300ms` | `ease-in-out` or critically damped spring | Reuse identical `layoutId` (Framer Motion) for sliding tabs, active nav indicators, and sandbox timetable cells reorganizing. |
| **Press Feedback** | `100–140ms` | `scale(0.97)` on pointer down | Direct tactile response; **don't tween while held/dragged** (velocity spring on release, rubber-band past bounds). |
| **List Row Stagger** | `30ms` per row (cap at `6` rows) | `ease-out` | Never stagger 50 dense rows. |
| **Error Feedback** | `260ms` | Horizontal **shake (`±4px`)** | Pair with inline text and focus move. |
| **Success Confirmation** | `300ms` | Subtle **pulse** + blurred icon crossfade (`blur(2px) -> 0`) | Confirms publish/save cleanly. |

### Performance & Accessibility Mandates
- **GPU Properties Only:** Animate `transform` and `opacity` (never `left`/`top`/`width`). Use CSS Grid `0fr -> 1fr` or Framer layout transitions for smooth `height: auto`.
- **Interruptible & Overlapping:** Mid-flight clicks reverse cleanly; overlap old and new states to avoid blank flashes.
- **Tooltip Skip Delay:** Configure Radix `TooltipProvider` with `delayDuration={400}` and `skipDelayDuration={0}` so rapid toolbar scanning feels instant.
- **Reduced Motion:** Wrap app root in `<MotionConfig reducedMotion="user">`; under reduced motion, render assembled rest states immediately.

---

## 4. 2026 Admin Dashboard & Dense Table Ergonomics
1. **Actionable Insights Over Endless Charts (2026 Dashboard Standard):** Ditch decorative KPI wallpaper. Lead the Admin Dashboard with **proactive readiness & anomaly cues** (e.g., empty config table warnings, R7 off-day violations, active routine version freshness, live Render engine status) so the dashboard *thinks with* the administrator.
2. **Let Data Drive the Form:** Schedules belong in an interactive **2D Timetable Matrix** (Section / Faculty / Room lenses) or timeline—not flat logs.
3. **Connected Filtering & Live Match Counts:** Keep filters visible above tables/grids with live tabular counts (`Showing 14 of 23 offerings`).
4. **Progressive Disclosure & "Invisible UI":**
   - Reveal secondary row actions (Copy Code, Edit, Delete) on row hover / `focus-within`.
   - Use **Popovers** for display preferences, **Docked Inspectors (`>= 1100px`)** for row provenance/editing, **Modals** for high-stakes confirmations (Publish Routine), and **Comboboxes** (`cmdk` / Radix) whenever selecting from `> 10` courses, rooms, or faculty acronyms.
   - Respect keyboard fluency (`/` focuses search, `Esc` closes drawers/modals, arrow keys traverse comboboxes and tabs) and Fitts's Law (`>= 36px` desktop / `>= 44px` compact hit targets).