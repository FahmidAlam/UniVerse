---
name: react-web-motion-and-craft
description: Governs marketable web onboarding & interactive product showcases, motion physics, timing budgets, progressive disclosure, invisible UI for dense admin dashboards, and error recovery in apps/web/. Load before building onboarding flows, interactive controls, modals, drawers, tables, or async workflows.
---

# UniVerse React Web — Onboarding, Motion Physics & Operational Craft

## 1. Complete Async & Interactive State Coverage
1. **All 5 States Required on Every Async Surface:** `loading` (layout-matched skeleton, zero layout shift), `first-use empty` (actionable setup guidance), `zero-filter-match empty` (1-click clear filters), `recoverable error` (*Service Recovery Paradox*: clear diagnosis + 1-click retry preserving user input), and `locked / staged capability` (truthful backend gate).
2. **Optimistic Updates (< 400ms):** Apply reversible admin edits promptly and roll back cleanly with an error toast + subtle horizontal shake if Supabase rejects the write.
3. **Explicit Control States:** Support `default`, `hover`, `focus-visible`, `active`, `disabled`, and `loading` on every interactive element.

---

## 2. Public Institutional Entry (`/`) & Post-Auth Activation
1. **User-Controlled Illustrative Timetable Preview (`AcademicLedgerPreview`):**
   - Center `/` around an interactive, user-controlled 2D CSS Grid timetable specimen demonstrating Leading University CSE constraints (e.g., *Friday Jummah Hard Block*, *Faculty Off-Day*, *6-Slot vs. 7-Slot Grid*, *Section / Faculty / Room Lens*) across both **Crisp Daylight Light** and **X-Grade Carbon Obsidian Dark** modes.
   - **Zero Auto-Play & Zero 3D:** Respond strictly to explicit user clicks (`motion/react` `layoutId` / CSS transitions) — zero background cycling timers, 3D tilt (`rotateX/rotateY`), fluted bezels, or orbital rings.
   - **Truthfulness Guardrail:** Label pre-auth data as an *Illustrative Institutional Preview* powered by client-side fixtures; never call live backend endpoints unauthenticated.
2. **Role Signposting & Readiness Checklist:**
   - Guide Students and Teachers clearly toward the **Flutter Mobile** companion app while keeping authenticated web focused on Administrators.
   - On `/admin/dashboard`, surface a live **Routine Readiness Checklist** derived 100% from real Supabase & FastAPI state (zero hardcoded fixture hashes or fake completion badges).

---

## 3. Motion Physics & Timing Budgets (`motion/react` + CSS)
Use the single **`motion`** package (`motion/react`) plus CSS transitions — never install `framer-motion` alongside `motion`.

| Interaction | Timing | Easing / Physics | Mandatory Rule |
| :--- | :--- | :--- | :--- |
| **Entrances (Panels, Drawers)** | `180–240ms` | `cubic-bezier(0.16, 1, 0.3, 1)` | Crisp settle; **zero bounce on admin UI.** |
| **Exits (Dismissals)** | `140–180ms` | `ease-in` / fast `ease-out` | **~20% shorter** than entrances. |
| **Popovers & Dropdowns** | `150–220ms` | `ease-out`, `scale(0.95 -> 1)` | Origin-aware from trigger. |
| **Shared-Element Switches** | `220–300ms` | `ease-in-out` / damped spring | Reuse `layoutId` for view switches & active pills. |
| **Press Feedback** | `100–140ms` | `scale(0.97)` on pointer down | Do not continuously tween while held. |
| **List Row Stagger** | `30ms` / row (max `6`) | `ease-out` | Never stagger dense operational tables. |
| **Validation Error** | `260ms` | Horizontal shake (`±4px`) | Pair with inline error message & focus move. |

- **GPU & Reduced Motion:** Animate `transform` and `opacity` only. Wrap app root in `<MotionConfig reducedMotion="user">`; under `@media (prefers-reduced-motion: reduce)` and `@media print`, render static assembled states immediately.
- **Radix Tooltips:** Use `delayDuration={400}` and `skipDelayDuration={0}`.

---

## 4. Dense Admin Console, Distribution Studio & Print Craft
1. **Custom 2D Scheduling Matrices & Print:**
   - Render schedules in `AcademicTimetableMatrix` (Section / Faculty / Room lenses + Compact List toggle, dynamic midday break slot, 7-day `Sun–Sat` week with Friday Jummah lock) and `CommitteeDaySheetView` (Official Leading University day sheet with single-sheet Landscape A4 `@media print` formatting).
2. **In-Browser Course Distribution Studio:**
   - Enable structured offering composition and workbook generation (`distributionXlsxBuilder`) directly in the browser without fabricating server persistence when Track 2 gates are locked.
3. **Progressive Disclosure & Keyboard Fluency:**
   - Hide secondary row actions and copy buttons until hover/`focus-within`; dim inactive rows cleanly; show corner-triangle override indicators with Radix Tooltips; reveal bulk bars only when `>= 1` row is selected.
   - Use Docked Inspectors (`>= 1100px`), Modals for destructive/publish confirmations, and `cmdk` Comboboxes when selecting from `> 10` items.
   - Support `/` to focus search, `Esc` to dismiss overlays, arrow-key traversal, and `>= 36px` desktop / `>= 44px` mobile touch targets.
   - **Honest Solver Telemetry:** Reflect real FastAPI job states (`queued`, `ingesting`, `solving`, `rendering`, `done`, `failed`) and real elapsed time — never fake progress percentages.
