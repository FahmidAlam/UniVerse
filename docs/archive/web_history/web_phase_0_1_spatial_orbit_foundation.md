# UniVerse React Web v1 — Spatial Orbit Engine Completion Report (Phase 0 + Phase 1 Taste Gate)

> **Historical Notice (Superseded Prototype):** This report documents the early Spatial Orbit Engine prototype in `apps/web/`. That visual system (`Spatial Orbit Engine`, dark mode toggle, 3D tilt/4-layer kinetic loop) has been **superseded by UniVerse Academic Ledger** (light-first, dark mode deferred). Refer to [`docs/architecture/WEB_ARCHITECTURE_DESIGN_BLUEPRINT.md`](../architecture/WEB_ARCHITECTURE_DESIGN_BLUEPRINT.md), [`docs/architecture/WEB_SOURCE_VERIFICATION_REPORT.md`](../architecture/WEB_SOURCE_VERIFICATION_REPORT.md), and [`docs/architecture/WEB_IMPLEMENTATION_ROADMAP.md`](../architecture/WEB_IMPLEMENTATION_ROADMAP.md) as the authoritative architecture and roadmap.
>
> **Date:** 2026-11-21  
> **Status:** Historical prototype verified locally (`tsc --noEmit`, `vite build`, and live headless Chrome CDP inspection at `1440px` & `1024px` across Light & Dark themes)  
> **Scope:** Standalone React Web application (`apps/web/`) implementing the superseded **Spatial Orbit Engine** prototype and initial `AdminShell` + `/admin/dashboard` shell.  
> **Isolation Guarantee:** Zero edits to Flutter (`lib/`, `android/`, `test/`, `web/`), `engine/`, or `supabase/`.

---

## 1. Design Direction Lock & Architecture Summary

Following Round 1 ([`WEB_DESIGN_DIRECTION_CANDIDATES.md`](../architecture/WEB_DESIGN_DIRECTION_CANDIDATES.md)) and Round 2 ([`WEB_BOLD_DIRECTIONS_R2.md`](../architecture/WEB_BOLD_DIRECTIONS_R2.md)), **Concept B: Spatial Orbit Engine** was locked for `apps/web/` with a deliberate split between public marketing/auth surfaces and the daily admin workbench:

| Surface | Theme & Palette | Typography | Motion & Depth Discipline |
|---|---|---|---|
| **Public Entry & Auth** (`/`, `/login`, `/forgot-password`, `/reset-password`, `/access-required`) | **Ceramic Daylight Light** (`H = 228°`) & **Deep Space Slate Dark** (`H = 230°`, `L >= 0.168`), Spectral Cyan-Emerald (`H = 182°–186°`) | `Space Grotesk` (display) + `IBM Plex Sans` (UI/body) + `JetBrains Mono` (codes/metrics) | **Authorized 4-Layer Kinetic Loop**: fluted housing, pointer spring 3D tilt (`±3°`, `Flatten to 2D` toggle), counter-rotating Orbit SVG rings + SVG conduit pulses, and 4.5s auto-cycling constraint demo |
| **Admin Operations Console** (`/admin/*`) | Same OKLCH token system (`tokens.css`), instant 1-frame Light/Dark/System switching | Same typography + tabular monospace numerals | **Strictly Flat 2D**: zero 3D tilt, zero continuous loops, zero fluted noise behind data (`240px` sidebar >= `1100px`, `52px` top bar) |
| **Flutter Android (`lib/`)** | Unchanged (**Obsidian Orbit** `#0B0C0E` + `#FF7A00`) | Unchanged | Completely untouched |

---

## 2. Updated Governance, Rules & Skills

| File | Update Summary | Link |
|---|---|---|
| React Web Design System Skill | Added `## 6. Locked Web Theme: Spatial Orbit Engine (Light + Dark)` with OKLCH values, typography rules, concentric `12px`/`6px` geometry, and `color-mix(in oklab, ...)` requirement | [SKILL.md](../../.agents/skills/react-web-academic-design-system/SKILL.md) |
| React Web Motion & Craft Skill | Added `## 5. Authorized 4-Layer Continuous Kinetic Loop (Public Entry & Auth Routes Only)` prohibiting decorative loops/3D/fluting on `/admin/*` | [SKILL.md](../../.agents/skills/react-web-motion-and-craft/SKILL.md) |
| Project Agent Instructions | Added `apps/web/` skill-routing rows and `React Web v1 Locked Theme (Spatial Orbit Engine)` guardrails | [AGENTS.md](../../AGENTS.md) |
| Claude Project Instructions | Synced the identical React Web skill-routing rows and Spatial Orbit Engine guardrails | [CLAUDE.md](../../CLAUDE.md) |

---

## 3. Complete `apps/web/` File Inventory (34 Files)

### Tooling, Environment & Entry (`apps/web/`)
- [`package.json`](../../apps/web/package.json) & `package-lock.json` — React `^19.1.0`, React Router `^7.6.2`, Framer Motion `^12.16.0`, TanStack Query `^5.80.7`, Supabase JS `^2.50.0`, Radix UI primitives (`dialog`, `dropdown-menu`, `switch`, `tooltip`), `@phosphor-icons/react`, Tailwind CSS v4 (`@tailwindcss/vite`).
- [`vite.config.ts`](../../apps/web/vite.config.ts) — ESM `fileURLToPath` `@/` path alias, React + Tailwind Vite plugins, `"target": "esnext"`.
- [`tsconfig.json`](../../apps/web/tsconfig.json), [`tsconfig.app.json`](../../apps/web/tsconfig.app.json), [`tsconfig.node.json`](../../apps/web/tsconfig.node.json), `src/vite-env.d.ts` — Strict TypeScript with `@types/node` enabled for Vite config compilation and Vite client types.
- [`index.html`](../../apps/web/index.html) — Google Fonts (`Space Grotesk`, `IBM Plex Sans`, `JetBrains Mono`), SVG Orbit favicon, and blocking pre-paint `universe-web-theme` script preventing FOUC.
- [`.env.example`](../../apps/web/.env.example) & [`.gitignore`](../../apps/web/.gitignore) — Documents `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, `VITE_TIMETABLE_BASE_URL`, and `VITE_ENABLE_SCHEDULING_PREVIEW_ROUTE`.

### Design System & Core UI (`apps/web/src/styles/`, `src/shared/`)
- [`src/styles/tokens.css`](../../apps/web/src/styles/tokens.css) — Light/Dark OKLCH neutrals, 4 depth properties (`--surface-grad`, `--border`, `--highlight`, `--shadow-elevated`/`--shadow-sm`), schedule semantics (`--sem-theory-*`, `--sem-lab-*`, `--sem-joint-*`, `--sem-alert-*`, `--sem-neutral-*`), `.theme-switching`, `prefers-contrast: more`, and `forced-colors: active`.
- [`src/styles/app.css`](../../apps/web/src/styles/app.css) — Typography rules, `.orbit-stage-fluted`, `.orbit-spin-cw`, `.orbit-spin-ccw`, `.orbit-conduit-pulse`, `.hatch-blocked` diagonal Friday Jummah pattern, `.surface-card`, `.btn-primary`, and `.btn-secondary`.
- [`src/shared/theme/ThemeProvider.tsx`](../../apps/web/src/shared/theme/ThemeProvider.tsx) & [`src/shared/components/ThemeSwitcher.tsx`](../../apps/web/src/shared/components/ThemeSwitcher.tsx) — Three-way Light / Dark / System switcher persisted to `universe-web-theme`.
- [`src/shared/components/OrbitMark.tsx`](../../apps/web/src/shared/components/OrbitMark.tsx) & [`src/shared/components/EngineHealthBadge.tsx`](../../apps/web/src/shared/components/EngineHealthBadge.tsx) — Orbital mark and live FastAPI health indicator badge.

### Backend Clients & Auth Infrastructure (`apps/web/src/services/`, `src/features/auth/`)
- [`src/services/supabase.ts`](../../apps/web/src/services/supabase.ts) — PKCE Supabase browser client (`flowType: "pkce"`, `detectSessionInUrl: true`, `persistSession: true`) plus `extractAndScrubInviteHash()` and `adoptInviteSession()` to verify and exchange server-side `invite-admin` implicit hash tokens via GoTrue `/auth/v1/user` and `/auth/v1/token?grant_type=refresh_token`.
- [`src/services/engineHealth.ts`](../../apps/web/src/services/engineHealth.ts) — Authenticated/dashboard FastAPI `GET /` 5-second health check against `VITE_TIMETABLE_BASE_URL`.
- [`src/features/auth/AuthProvider.tsx`](../../apps/web/src/features/auth/AuthProvider.tsx) — Admin session context enforcing `public.whitelists` allowlist + `admin` role checks *(corrected from earlier `approved_users` misnomer)*, `passwordRecovery` (10-minute recovery window), `accessDenied`, `engineMood` signaling (`idle`, `solving`, `verifying`, `error`, `success`), and local `dev-preview-admin` fallback strictly gated behind `import.meta.env.DEV && !isSupabaseConfigured`.
- [`src/features/auth/PublicAuthLayout.tsx`](../../apps/web/src/features/auth/PublicAuthLayout.tsx) — Persistent morphing wrapper holding `SpatialOrbitStage` mounted across `/` (`landing`) and split auth routes (`auth-split`).
- [`src/features/auth/components/AndroidCompanionStrip.tsx`](../../apps/web/src/features/auth/components/AndroidCompanionStrip.tsx) — Explicit boundary notice routing Students & Teachers to the UniVerse Android App.
- Auth Pages:
  - [`src/features/auth/pages/LandingPage.tsx`](../../apps/web/src/features/auth/pages/LandingPage.tsx) (`/`)
  - [`src/features/auth/pages/LoginPage.tsx`](../../apps/web/src/features/auth/pages/LoginPage.tsx) (`/login`, with PKCE email/Google sign-in + local **Preview Admin Shell** button in unconfigured dev mode)
  - [`src/features/auth/pages/ForgotPasswordPage.tsx`](../../apps/web/src/features/auth/pages/ForgotPasswordPage.tsx) (`/forgot-password`)
  - [`src/features/auth/pages/ResetPasswordPage.tsx`](../../apps/web/src/features/auth/pages/ResetPasswordPage.tsx) (`/reset-password`)
  - [`src/features/auth/pages/AccessRequiredPage.tsx`](../../apps/web/src/features/auth/pages/AccessRequiredPage.tsx) (`/access-required`)

### Kinetic Onboarding Engine (`apps/web/src/features/onboarding/`)
- [`src/features/onboarding/data/routineFixtures.ts`](../../apps/web/src/features/onboarding/data/routineFixtures.ts) — Client-only Leading University CSE showcase data (`CSE-3101`, `CSE-3102 Lab`, `CSE-3202`, `Batch 58 B+C`, `MSR`, `EBH`, `RAB-302`, `ACL-1`, `Friday P4 Jummah`, `R7 Off-Day`, `R15 7-Slot`) with zero unauthenticated network calls.
- [`src/features/onboarding/components/SpatialOrbitStage.tsx`](../../apps/web/src/features/onboarding/components/SpatialOrbitStage.tsx) — 4-layer GPU-composited Orbit stage with `AUTO_SCENARIOS` 4.5s loop, Framer Motion `layoutId` cell transitions, manual constraint pause + `Resume Loop`, `Flatten to 2D` toggle, and live `matchMedia("(prefers-reduced-motion: reduce)")` enforcement.

### Admin Operations Console (`apps/web/src/features/admin/`, `src/App.tsx`, `src/main.tsx`)
- [`src/features/admin/AdminShell.tsx`](../../apps/web/src/features/admin/AdminShell.tsx) — Flat 2D shell (`240px` desktop sidebar / Radix drawer below `1100px`, `52px` top bar, grouped navigation with `PREVIEW` / `STAGED` honesty badges).
- [`src/features/admin/services/adminDashboardService.ts`](../../apps/web/src/features/admin/services/adminDashboardService.ts) — Live Supabase exact-count queries (`profiles`, `routines`, `notifications`, `timetable_rooms`, `timetable_faculty`, `timetable_course_eligibility`, active `routine_versions`) plus illustrative `getDevPreviewCounts()`.
- [`src/features/admin/pages/AdminDashboardPage.tsx`](../../apps/web/src/features/admin/pages/AdminDashboardPage.tsx) — Routine Command Center featuring 4-stage readiness checklist, proactive empty-config pre-publish guard banner, persisted vs. staged backend inventory, loading/error/refresh controls.
- [`src/features/admin/pages/AdminRouteStubPage.tsx`](../../apps/web/src/features/admin/pages/AdminRouteStubPage.tsx) — Typed route stubs for Phase 2–4 routes documenting exact target contracts.
- [`src/App.tsx`](../../apps/web/src/App.tsx) & [`src/main.tsx`](../../src/main.tsx) — Router guards (`PublicRouteGuard`, `AdminRouteGuard`), `QueryClientProvider`, `MotionConfig`, and Radix `Tooltip.Provider`.

---

## 4. Implemented Route Matrix & Persistence Honesty

| Route | Implementation Status | Backend / Persistence Boundary |
|---|---|---|
| `/` | Live UI | 100% client fixtures (`routineFixtures.ts`), zero unauthenticated backend calls |
| `/login`, `/forgot-password`, `/reset-password`, `/access-required` | Live Auth UI & Logic | Supabase PKCE + `public.whitelists` *(not `approved_users`)* / `profiles.role = 'admin'` gate + `invite-admin` hash adoption |
| `/admin/dashboard` | Live Dashboard + Dev Preview | Reads `profiles`, `routines`, `notifications`, `timetable_rooms`, `timetable_faculty`, `timetable_course_eligibility`, `routine_versions` (or dev preview when unconfigured) |
| `/admin/routine`, `/admin/timetable/grid` | Phase 2 Stub | `POST /api/timetable/generate`, `GET /api/timetable/{status,result,download}/{job_id}`, `publish_routine`, `public.routines` |
| `/admin/timetable/rooms`, `/faculty`, `/course-eligibility`, `/settings`, `/broadcast`, `/users`, `/resources`, `/profile` | Phase 3 Stubs | Live Supabase baseline tables, `invite-admin`, storage buckets (`timetables`, `resources`) |
| `/admin/scheduling` | Fail-Closed Stub (`PREVIEW · LOCKED`) | Locked behind schema migrations `20261022140809` & `20261106130000` |
| `/admin/timetable/courses`, `/admin/timetable/batches` | Honest Staged Stubs (`STAGED · NO DB TABLE`) | Refuses fake save persistence until canonical DB tables exist |

---

## 5. Verification Record (Post-Final-Edit)

1. **Static Checks & Production Bundle (`apps/web/`):**
   - `npx tsc --noEmit` — **Passed (`0` errors)**.
   - `npm run build` (`tsc -b && vite build`) — **Passed (`5160 modules transformed`, `✓ built in 9.37s`)**.
2. **Headless Chrome CDP Runtime & Screenshot Audit (`http://127.0.0.1:5173`):**
   - **Typography Loaded:** `IBM Plex Sans`, `JetBrains Mono`, `Space Grotesk`.
   - **Console / Page Errors:** `[]` (`0` errors).
   - **Kinetic Orbit Loop (`/`):** Active CSS keyframes `["conduitFlow", "orbitSpinCw", "orbitSpinCcw"]`; `autoCycleChanged: true`; manual toggle pause reveals `Resume Loop` (`manualPausedHasResume: true`); `Flatten to 2D` resets `[data-testid="orbit-timetable-plane"]` transform to `none`.
   - **Morph Without Unmount (`/` → `/login` → `/forgot-password`):** Exact DOM node identity preserved (`sameStageInstance: true`), `data-layout-mode` transitions `landing` → `auth-split`, invalid form submit surfaces `[data-testid="login-error-alert"]` and `data-engine-mood="error"`.
   - **Flat 2D Admin Console (`/admin/dashboard`):** `hasFlat2DShell: true`, `hasOrbitStage: false`, Light & Dark theme switch verified (`oklch(0.168 0.018 230)` dark body), zero horizontal overflow at both `1440px` and `1024px`.
   - **Reduced Motion (`prefers-reduced-motion: reduce`):** `[data-3d-active="false"]` and `transform: none` verified dynamically via CDP media emulation.
   - **Issues Found & Fixed During Visual QA:** Added live `matchMedia("(prefers-reduced-motion: reduce)")` change listener in `SpatialOrbitStage.tsx`, and fixed compact scenario caption wrapping on `/login` split layout.
3. **Working Tree Hygiene (`git status --short`):**
   - Only `apps/web/`, `docs/`, `.agents/skills/react-web-*`, `AGENTS.md`, and `CLAUDE.md` modified/added; Flutter & Python/Supabase files remain untouched.

---

## 6. Local Preview & Next Phase Readiness

```bash
cd apps/web
npm run dev
```

Open **http://localhost:5173** to preview Light/Dark **Spatial Orbit Engine** onboarding, `/login` split auth (click **Preview Admin Shell** when no `.env.local` is configured), and the flat 2D `/admin/dashboard`.

**Ready Next Phase (Upon Product Owner Approval):** Phase 2 — Operational Routine Console (`/admin/routine` 4-tab Manage/Grid/Generate/Upload workbench + full-width `/admin/timetable/grid` matrix + FastAPI solver polling).
