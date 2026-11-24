# UniVerse React Web v1 — Sub-Phase 1A Implementation Report (UniVerse Academic Ledger)

> **Milestone Scope:** Sub-Phase 1A — **UniVerse Academic Ledger** visual system replacement, public specimen refactor, authentication & invite hardening, centralized Capability Registry, backend-derived Command Center, and automated Vitest + Playwright verification inside `apps/web/`.
> **Gated Boundaries Preserved:** Zero edits to Flutter mobile (`lib/`, `android/`, `ios/`, `test/`), Python engine (`engine/`), or database migrations (`supabase/`). Sub-Phase 1B (live hosted staging auth verification against `oqwvxplteqtlrhktsplj`) and production `yxqyrjyzxitrgkhgauli` remain untouched.

---

## 1. Documentation Sync Updates (Scope A)

- Updated [`docs/architecture/WEB_PHASE_1A_DESIGN_BRIEF.md`](../architecture/WEB_PHASE_1A_DESIGN_BRIEF.md) §8 to retain `@radix-ui/react-switch` (`^1.2.5`) for accessible rule switches, add `sonner`, `clsx`, `tailwind-merge`, and `class-variance-authority`, and retire `framer-motion`.
- Updated [`docs/architecture/WEB_IMPLEMENTATION_ROADMAP.md`](../architecture/WEB_IMPLEMENTATION_ROADMAP.md) §6.3 and [`docs/architecture/web-separation/WEB_IMPLEMENTATION_ROADMAP.md`](../architecture/web-separation/WEB_IMPLEMENTATION_ROADMAP.md) §6.3 from `"Android companion guidance"` to `"Android & iOS mobile companion guidance"`.

---

## 2. Package Delta (`apps/web/package.json`)

- **Removed:** `framer-motion`
- **Retained:** `@radix-ui/react-switch` (`^1.2.5`), `@radix-ui/react-dialog` (`^1.1.14`), `@radix-ui/react-dropdown-menu` (`^1.1.15`), `@radix-ui/react-tooltip` (`^1.2.7`), `@phosphor-icons/react` (`^2.1.7`), `@supabase/supabase-js` (`^2.50.0`), `@tanstack/react-query` (`^5.80.7`), `react` (`^19.1.0`), `react-dom` (`^19.1.0`), `react-router-dom` (`^7.6.2`)
- **Installed (`dependencies`):**
  - `motion` (`^14.14.0`) — sole animation runtime via `motion/react` (`<MotionConfig reducedMotion="user">`)
  - `react-hook-form` (`^7.92.0`), `zod` (`^4.6.7`), `@hookform/resolvers` (`^7.0.8`)
  - `zustand` (`^5.1.0`) — interactive specimen rule/lens/view store
  - `sonner` (`^2.0.8`) — recovery/validation toast feedback
  - `clsx` (`^2.1.1`), `tailwind-merge` (`^3.7.1`), `class-variance-authority` (`^0.7.1`)
- **Installed (`devDependencies`):** `vitest` (`^4.1.12`), `@testing-library/react` (`^16.3.3`), `jsdom` (`^31.0.1`), `@playwright/test` (`^1.65.1`)
- **Scripts added to [`apps/web/package.json`](../../apps/web/package.json):** `"test": "vitest run"`, `"test:watch": "vitest"`, `"test:e2e": "playwright test"`.

---

## 3. Retired Spatial Orbit Layer & Academic Ledger Design System

- **Deleted superseded files:**
  - `apps/web/src/shared/theme/ThemeProvider.tsx`
  - `apps/web/src/shared/components/ThemeSwitcher.tsx`
  - `apps/web/src/shared/components/OrbitMark.tsx`
  - `apps/web/src/features/onboarding/components/SpatialOrbitStage.tsx`
  - `apps/web/src/features/auth/components/AndroidCompanionStrip.tsx`
- **Implemented light-first foundation:**
  - [`apps/web/index.html`](../../apps/web/index.html): Loads `Source Serif 4` (`600`), `IBM Plex Sans` (`400`, `500`, `600`), and `IBM Plex Mono` (`400`, `500`), enforces `<meta name="color-scheme" content="light" />`, removes dark-mode FOUC script, and adds the Academic Ledger geometric SVG favicon.
  - [`apps/web/src/styles/tokens.css`](../../apps/web/src/styles/tokens.css): Single light-first OKLCH token sheet (`--bg-canvas`, `--bg-surface`, `--bg-elevated`, `--surface-hover`, `--surface-active`, `--ink-{primary,secondary,muted}`, `--action-primary*`, provisional `--accent-pine*`, `--border-{subtle,strong,control}`, `--focus-ring`, `--sem-{theory,lab,joint,conflict}-{bg,ink,bar,border}`, `--highlight-top`, `--surface-sheen`, `--shadow-{sheet,popover}`, typography, radii, and motion budgets), plus `@media (prefers-contrast: more)`, `@media (prefers-reduced-motion: reduce)`, and `@media (forced-colors: active)`.
  - [`apps/web/src/styles/app.css`](../../apps/web/src/styles/app.css): Places `.ledger-paper-grain`, `.ledger-sheet`, `.ledger-card`, `.ledger-popover`, `.btn-primary`, `.btn-secondary`, `.slot-*`, `.slot-override-corner`, `.row-reveal-action`, and `.reserved-bold` inside `@layer components` so responsive Tailwind utility overrides (`min-[1100px]:hidden`, etc.) apply reliably.
  - [`apps/web/src/lib/utils.ts`](../../apps/web/src/lib/utils.ts) & [`apps/web/src/components/ui/`](../../apps/web/src/components/ui/Button.tsx): Reusable `cn` helper plus `Button`, `Badge`, `Switch`, `Tooltip`, `Dialog`, and `DropdownMenu` primitives backed by Radix UI and `@phosphor-icons/react`.
  - [`apps/web/src/shared/components/LedgerMark.tsx`](../../apps/web/src/shared/components/LedgerMark.tsx): Clean static architectural grid emblem.

---

## 4. Public Landing `/`, Interactive 2D Specimen & Auth Hardening

- **Public entry ([`PublicAuthLayout.tsx`](../../apps/web/src/features/auth/PublicAuthLayout.tsx), [`LandingPage.tsx`](../../apps/web/src/features/auth/pages/LandingPage.tsx), [`MobileCompanionStrip.tsx`](../../apps/web/src/features/auth/components/MobileCompanionStrip.tsx)):**
  - Single-row sticky header (`56px` mobile / `60px` desktop) with no stacked duplicate CTAs.
  - Replaced `SpatialOrbitStage` 3D tilt/fluted chrome/auto-looping engine with [`AcademicLedgerPreview.tsx`](../../apps/web/src/features/onboarding/components/AcademicLedgerPreview.tsx) backed by [`routineFixtures.ts`](../../apps/web/src/features/onboarding/data/routineFixtures.ts) and [`specimenStore.ts`](../../apps/web/src/features/onboarding/store/specimenStore.ts).
  - Permanent disclosure strip (`"Illustrative sample schedule — interactive preview only, not a live CP-SAT solver run."`), user-controlled Friday P4 Jummah Lock switch, R7 Off-Day switch, R15 `6-Slot` / `7-Slot + P7` toggle, `Section / Faculty / Room` lens switcher, `Matrix / List` view switcher, corner-triangle override markers with Radix tooltips, `whitespace-nowrap` on room/block codes, and zero unauthenticated remote requests.
  - Auth pages reorder on `< 1024px` (`order-1 lg:order-2`) so sign-in renders above the fold on `390×844`.
- **Auth & Invite Hardening ([`supabase.ts`](../../apps/web/src/services/supabase.ts), [`AuthProvider.tsx`](../../apps/web/src/features/auth/AuthProvider.tsx)):**
  - Fixed stale `status` closure inside `onAuthStateChange` using `statusRef` and `updateStatus`, and guarded `bootstrap()` `getSession()` hydration against overwriting an active `passwordRecovery` window.
  - Hardened `extractAndScrubInviteHash()` + `adoptInviteSession()`: rejects non-empty `window.location.search`, requires verified `email_confirmed_at` alongside `id` and `invited_at`, and requires `expires_at > now + 60`.
  - Refactored [`LoginPage.tsx`](../../apps/web/src/features/auth/pages/LoginPage.tsx), [`ForgotPasswordPage.tsx`](../../apps/web/src/features/auth/pages/ForgotPasswordPage.tsx), [`ResetPasswordPage.tsx`](../../apps/web/src/features/auth/pages/ResetPasswordPage.tsx), and [`AccessRequiredPage.tsx`](../../apps/web/src/features/auth/pages/AccessRequiredPage.tsx) with `react-hook-form` + `zod` + `sonner`, password show/hide toggles, `"Continue with Google"` button, live 4-item inline password checklist on `/reset-password`, and removed exposed `public.*` table identifiers, PKCE jargon, and UI dev-simulator cards (preserving `?preview=admin` / `sessionStorage` dev-preview access strictly for `import.meta.env.DEV && !isSupabaseConfigured`).

---

## 5. Capability Registry, Admin Shell & Backend-Derived Command Center

- **Centralized Registry ([`capabilityRegistry.ts`](../../apps/web/src/core/capabilities/capabilityRegistry.ts)):** Single source of truth driving all 14 admin sidebar routes, page titles, [`AdminRouteStubPage.tsx`](../../apps/web/src/features/admin/pages/AdminRouteStubPage.tsx), and `SUBFEATURE_CAPABILITIES`:
  - `live-persisted`: Dashboard (`implementedInPhase1A: true`), Routine Operations, Room Pools, Faculty, Course Eligibility, Timetable Settings, Campus Broadcast, User Whitelist, Academic Resources (plus `solver.co-teacher-guard`).
  - `read-only`: Routine Matrix (`/admin/timetable/grid`), My Profile (`/admin/profile`).
  - `staged-no-db`: Courses (`/admin/timetable/courses`), Batches & Sections (`/admin/timetable/batches`).
  - `fail-closed-gate`: 5-Stage Scheduling Workbench (`/admin/scheduling`, `Locked · Gates A–D`) and Track 1 `.xlsx` Workbook Upload sub-feature.
- **Admin Shell ([`AdminShell.tsx`](../../apps/web/src/features/admin/AdminShell.tsx), [`EngineHealthBadge.tsx`](../../apps/web/src/shared/components/EngineHealthBadge.tsx)):** `264px` fixed desktop rail (`>= 1100px`) with `18px` Regular Phosphor icons on all navigation entries, Radix `Dialog` mobile drawer (`< 1100px`), `52px` top bar with live `EngineHealthBadge`, `Generate Routine` shortcut, and one single Account Popover.
- **Backend-Derived Dashboard ([`AdminDashboardPage.tsx`](../../apps/web/src/features/admin/pages/AdminDashboardPage.tsx)):**
  - Completely removed hardcoded `CSE_Course_Distribution_Spring_2026_Final_v4.xlsx` and SHA `9f4c8a...e21b`.
  - Stage `01–04` counts derive directly from live `AdminDashboardCounts`; displays explicit `0 configured eligibility records` warning banner, `Last checked HH:MM:SS` + `Refresh` button, upfront filter counts (`All`, `Needs Setup`, `Ready`) with filter-empty `Clear Filter` reset, hover/focus-revealed row actions on desktop, loading skeleton, error retry recovery, Track 2 Gates A–D governance table, and the required dev-preview notice (`"Illustrative preview — disconnected from live Supabase & FastAPI backends."`).

---

## 6. Verification & Visual QA Results

All checks ran cleanly after the final edit inside `apps/web/`:

| Verification Check | Command | Observed Result |
|---|---|---|
| TypeScript check | `npm --prefix apps/web run typecheck` | **Passed** (`0` errors) |
| Production build | `npm --prefix apps/web run build` | **Passed** (`tsc -b && vite build`, 5,301 modules transformed) |
| Vitest unit suite | `npm --prefix apps/web test` | **Passed — 48 / 48 tests across 4 files** (`tokensContrast.test.ts`: 30, `capabilityRegistry.test.ts`: 5, `authHardening.test.tsx`: 9, `adminDashboard.test.tsx`: 4) |
| Playwright E2E & visual QA | `npm --prefix apps/web run test:e2e` | **Passed — 4 / 4 scenarios** (`1440×900`, `1024×768`, `390×844`, `prefers-reduced-motion: reduce`; zero horizontal overflow, zero page/console errors, zero unauthenticated Supabase/Render traffic on `/`) |
| Git boundary check | `git status --short` | **Verified** zero changes under `lib/`, `android/`, `ios/`, `test/`, `engine/`, or `supabase/`. |

### Screenshots Reviewed (`docs/screenshots/web_phase_1a/`)

- [`01_landing_1440x900.png`](../screenshots/web_phase_1a/01_landing_1440x900.png), [`02_landing_1024x768.png`](../screenshots/web_phase_1a/02_landing_1024x768.png), [`03_landing_390x844.png`](../screenshots/web_phase_1a/03_landing_390x844.png), [`04_landing_list_390x844.png`](../screenshots/web_phase_1a/04_landing_list_390x844.png)
- [`05_login_1440x900.png`](../screenshots/web_phase_1a/05_login_1440x900.png), [`06_login_390x844.png`](../screenshots/web_phase_1a/06_login_390x844.png), [`07_reset_password_1440x900.png`](../screenshots/web_phase_1a/07_reset_password_1440x900.png)
- [`08_admin_dashboard_1440x900.png`](../screenshots/web_phase_1a/08_admin_dashboard_1440x900.png), [`09_admin_dashboard_1024x768.png`](../screenshots/web_phase_1a/09_admin_dashboard_1024x768.png), [`10_admin_dashboard_390x844.png`](../screenshots/web_phase_1a/10_admin_dashboard_390x844.png), [`11_admin_scheduling_locked_1440x900.png`](../screenshots/web_phase_1a/11_admin_scheduling_locked_1440x900.png)

Visual defects caught and resolved during screenshot inspection:
1. Wrapped `.btn-primary` / `.btn-secondary` / surface classes inside `@layer components` in `app.css` so Tailwind `min-[1100px]:hidden` cleanly hides the mobile navigation toggle on desktop viewports (`1440×900`).
2. Balanced landing hero split (`lg:grid-cols-[minmax(0,0.82fr)_minmax(0,1.48fr)]`) and specimen column sizing so all 6 daily periods (`P1–P6`) remain unclipped side by side at `1024×768`.
3. Widened desktop left rail to `264px` so active bold labels alongside `READ-ONLY`, `LOCKED`, and `STAGED` badges render without ellipsis truncation.
4. Scoped `.row-reveal-action` transition strictly to `@media (min-width: 640px) and (hover: hover)` so mobile action buttons render immediately at full contrast.

---

## 7. Next Gated Phase

Sub-Phase 1A implementation and local mocked verification are complete. Next step awaits explicit owner sign-off for **Sub-Phase 1B** (hosted non-production staging auth smoke verification against approved isolated staging project `oqwvxplteqtlrhktsplj`) and subsequent Phase 2 admin CRUD routes.
