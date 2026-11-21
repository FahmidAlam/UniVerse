# UniVerse — Standalone React Web Architecture & Design Blueprint

> **Document Role:** Authoritative Strategic Reference (Approved Product, Architectural & Visual Direction)
> **Scope:** Separation of Flutter Mobile (`lib/`, `android/`, iOS-compatible) and Standalone React Web (`apps/web/`)
> **Design System:** **UniVerse Academic Ledger** (Light-First; Dark Mode Deferred)
> **Important Notice:** This document preserves the owner's approved strategic direction. It does **not** claim that every proposed technology, UI screen, or backend contract is currently implemented or deployed. See [`WEB_SOURCE_VERIFICATION_REPORT.md`](WEB_SOURCE_VERIFICATION_REPORT.md) for verified repository facts and [`WEB_IMPLEMENTATION_ROADMAP.md`](WEB_IMPLEMENTATION_ROADMAP.md) for phased execution.

---

## 1. Executive Summary

UniVerse is an academic routine and university management platform serving Leading University, Sylhet (initially focused on the Department of Computer Science and Engineering, with multi-department expansion planned for later phases).

To eliminate the UX friction, heavy bundle overhead, and visual compromises of targeting desktop browser administration and mobile student/faculty workflows from a single Flutter codebase, the owner has approved an architectural separation:

1. **Flutter Mobile (`lib/`):** Retained for Android with continuous iOS compatibility preservation (active new iOS feature expansion is deferred; iOS compatibility preservation and verification are **not** deferred). Serves **Students** and **Teachers** for daily campus life—live/next class tracking, weekly and daily routine consultation, date-scoped class cancellations, room vacancy lookup, faculty directory lookup, course resources, notifications, and profile management—preserving its dark-orange **Obsidian Orbit** identity (`AppColors`, `AppTheme.dark`).
2. **Standalone React Web (`apps/web/`):** Replaces the Flutter Web experience using React 19, TypeScript, Vite, and Tailwind CSS v4. Primarily serves **Administrators** (Routine Committee members and departmental staff) for routine generation, academic configuration, scheduling, and operational management, alongside a **public institutional landing page** (`/`).
3. **Shared Backend:** Preserves the existing **Supabase** (PostgreSQL, GoTrue PKCE auth, Row Level Security, Storage, Edge Functions) and **Python FastAPI + Google OR-Tools CP-SAT** scheduling microservice (`engine/`) without unnecessary backend rewrites or duplicated domain logic.
4. **Approved Web Visual Identity — UniVerse Academic Ledger:** Replaces both Flutter's dark-orange **Obsidian Orbit** theme and the earlier dark-cyan/3D **Spatial Orbit Engine** web prototype (`apps/web/` Phase 0/1) with a calm, daylight-first scholarly institutional design system combining **Precision Ledger**, **Campus Atelier**, and **Archival Registrar**.

---

## 2. Current Documented Architecture (Baseline Context)

As documented across the repository and inspected in source (`CLAUDE.md`, `AGENTS.md`, `PROJECT_STRUCTURE.md`, `apps/web/`, `engine/`, `supabase/`), the current system comprises four pillars:

| Layer | Current Repository Location | Role in Platform |
|---|---|---|
| **Mobile & Legacy Web Client** | `lib/`, `android/`, `web/`, `test/` | Unified Flutter 3.x client (`ChangeNotifier`/`SafeChangeNotifier`, `GoRouter`, `supabase_flutter`) currently hosting Student, Teacher, and Admin screens under the **Obsidian Orbit** dark-orange theme. |
| **Standalone Web Prototype** | `apps/web/` | Early Phase 0/1 React 19 + TypeScript + Vite foundation built under the superseded **Spatial Orbit Engine** theme (`LandingPage`, auth flow, `/admin/dashboard`, and 13 stubbed admin routes). |
| **Database, Auth, Storage & Edge Functions** | `supabase/migrations/`, `supabase/functions/`, `supabase/reconciliation/` | PostgreSQL with RLS, GoTrue PKCE auth, `whitelists` role gate, Storage buckets (`timetables`, `resources`, `avatars`), Realtime (`cancellations`), and Deno Edge Functions (`invite-admin`, `send-push`). |
| **Timetable Constraint Engine** | `engine/` (`main.py`, `solver.py`, `ingest.py`, `distribution.py`, `render.py`) | Python FastAPI HTTP service (configured for Render via `render.yaml`) running Google OR-Tools CP-SAT over Course Distribution `.xlsx` workbooks and returning JSON schedules + formatted `.xlsx` downloads. |

---

## 3. Approved Flutter Mobile + React Web Separation

### 3.1 Platform Audience & Responsibility Split

| User Role | Primary Platform | Core Workflows | Visual Identity |
|---|---|---|---|
| **Students** | **Flutter Mobile** (`lib/`) | Daily student dashboard (live/next class hero cards), weekly matrix & swipeable day agenda, live room vacancy lookup, faculty directory lookup, semester resources, class cancellation alerts, profile. | **Obsidian Orbit** (`#0B0C0E` + `#FF7A00`, unchanged) |
| **Teachers / Faculty** | **Flutter Mobile** (`lib/`) | Teaching dashboard (`teacher_code` matching), faculty routine, date-scoped class cancellation & restoration (`ManageClassesScreen` with 2-step notification recovery), room/faculty lookup, resources, profile. | **Obsidian Orbit** (unchanged) |
| **Administrators & Routine Committee** | **React Web** (`apps/web/`) | Public institutional portal, admin sign-in & invite onboarding, Track 1 Operational Routine Console (live routine CRUD, 2D matrix, CP-SAT generation, `.xlsx` upload & guarded atomic publish), Track 2 Committee Scheduling Workbench (CD1 Course Distribution & R1–R16 policy governance), room/faculty/eligibility/settings config, broadcasts, user whitelisting, academic resources. | **UniVerse Academic Ledger** (Light-first; dark mode deferred) |
| **Public Visitors (Deans, Faculty, Students)** | **React Web** (`apps/web/` `/`) | Scholarly overview of Leading University CSE routine operations, client-side illustrative schedule preview, and clear directional signposting to the Flutter Mobile app for Students/Teachers vs. Admin Sign-In for Committee staff. | **UniVerse Academic Ledger** (Archival Registrar) |

### 3.2 Retirement of Flutter Web as Primary Admin Surface

- Flutter's web runner (`web/`) and web-targeted admin flows (`AdminDesktopShell`, `file_downloader_web.dart`) are superseded by `apps/web/` as the strategic browser experience.
- Flutter Mobile (`lib/`) **must remain intact** for Android and continuous iOS compatibility (custom URL schemes, deep links, auth callbacks, and backend APIs). While active net-new iOS feature expansion is deferred, iOS compatibility preservation and regression verification remain mandatory whenever shared auth, FastAPI, or schema contracts change. No shared Supabase table schema, RPC contract, or Python solver interface may break existing Student or Teacher Flutter mobile functionality.

---

## 4. Frontend / Backend Responsibility Boundaries

The separation obeys strict single-source-of-truth boundaries so business logic is never duplicated across Dart, TypeScript, SQL, and Python:

### 4.1 What Remains in Supabase (PostgreSQL + RLS + Edge Functions)
- **Identity & Role Enforcement:** GoTrue authentication (`flowType: 'pkce'`), `public.profiles`, `public.whitelists`, and the `profiles_guard_role` BEFORE INSERT/UPDATE trigger (`guard_profile_role()`) preventing self-escalation to `teacher` or `admin` without a matching whitelist entry.
- **Routine Persistence & Backend Publication Safeguards:** `public.routines`, `public.routine_versions`, `public.timetable_runs`, and `publish_routine(...)` RPC executing transactional routine replacement. Production-grade publication safeguards require four database-enforced invariants (requiring authorized backend evolution where current SQL falls short, e.g. `F-21`/`F-22`):
  1. **Scope enforcement** (preventing cross-semester/cross-scope accidental overwrites and verifying target admin privileges).
  2. **Concurrency control** (revision/version optimistic locking to block stale overwrites).
  3. **Integrity validation** (rejecting empty, structurally malformed, or clash-invalid payloads server-side rather than trusting client checks alone).
  4. **Recoverability through archived snapshots** (preserving full historical routine row snapshots in addition to summary metadata so rollback operates inside PostgreSQL without manual `.xlsx` re-upload).
- **Configuration & Operations:** `public.timetable_rooms`, `public.timetable_faculty`, `public.timetable_course_eligibility`, `public.timetable_settings` (singleton `id = 1`), `public.notifications`, `public.notification_reads`, `public.cancellations`, `public.resources`.
- **Canonical Catalog & Course Distribution Ledger (Target Backend for Track 2):** `20261022140809_academic_catalog.sql` and `20261106130000_course_distribution_contract.sql` (`course_distribution_sources`, `course_distribution_revisions`, `course_distribution_corrections`, `course_distribution_artifacts`, `append_course_distribution_correction`, `read_course_distribution_revision`).
- **Privileged Server Actions:** `invite-admin` (uses `SUPABASE_SERVICE_ROLE_KEY` to upsert `whitelists` and send GoTrue invitation emails) and `send-push` (uses `SUPABASE_SERVICE_ROLE_KEY` to dispatch FCM HTTP v1 notifications).

### 4.2 What Remains in Python FastAPI (`engine/`)
- **Authoritative Input Ingestion & Normalization:** `engine/distribution.py` (`SourceWorkbook`, `DistributionDraft`, `normalize_persisted_revision`) and `engine/ingest.py` (`Offering`/`Session` grouping, `B+C` joint section preservation, split/co-teacher arrays, formula & cached-value checks on columns `J` and `L`).
- **Constraint Solving & Post-Solve Validation:** `engine/solver.py` (OR-Tools CP-SAT placement, room allocation, 20-point validation dictionary + `ok` verdict) and `engine/room_policy.py` (ECL/EEE vs. CSE room rules, alias resolution). Do **not** redesign the CP-SAT solver algorithm during Web migration.
- **Official `.xlsx` Rendering:** `engine/render.py` (`render_bytes` producing formatted Leading University routine spreadsheets).
- **Rendered `.xlsx` Parse/Validation Ownership (Provisional Preference):** For Track 1 rendered routine `.xlsx` uploads, the provisional architectural preference is an **additive, non-mutating FastAPI parse/validation endpoint** (`engine/main.py`) rather than mandating a parallel TypeScript parser port. Flutter's existing Dart `RoutineWorkbookParser` (`lib/features/admin/services/routine_workbook_parser.dart`) remains unchanged initially, shared test fixtures must establish equivalence between Python and Dart outputs, and introducing this endpoint requires **separate review and owner authorization** before implementation.

### 4.3 What Lives in React Web (`apps/web/`)
- **Presentation, Workflow Orchestration & Pre-Flight Guardrails:**
  - Admin-only route protection (`profile.role === 'admin'`), invite hash scrubbing & adoption bridge, and honest empty/loading/error/locked UX states.
  - Typed Supabase query/mutation layer (`TanStack Query v5`) strictly honoring verified database columns.
  - FastAPI job submission (`POST /api/timetable/generate`), bounded polling (`2s` interval, up to `240` polls, `429` backoff), validation blocker checks (`blockingValidationErrorFor`), co-teacher storage guard (`teachers.length > 1`), and `.xlsx` download handling.
  - Track 1 rendered routine `.xlsx` upload & review UI calling the provisionally preferred additive FastAPI parse/validation endpoint once reviewed and authorized (do **not** duplicate `Course Distribution` solving or maintain an unverified parallel parser unless expressly instructed).
  - Custom 2D CSS Grid timetable visualization across **Section**, **Faculty**, and **Room** lenses paired with Compact List switching.

---

## 5. Approved Visual Design Direction — UniVerse Academic Ledger

The owner has approved **UniVerse Academic Ledger** as the unified design system for `apps/web/`, explicitly replacing both Flutter's dark-orange **Obsidian Orbit** theme and the earlier dark-cyan/3D **Spatial Orbit Engine** prototype.

### 5.1 Three Complementary Pillars

| Pillar | Primary Surface | Core Visual Traits |
|---|---|---|
| **Precision Ledger** | Admin tables, readiness checklists, timetable matrices, eligibility grids | Swiss-inspired grid discipline, crisp `1px` structural hairlines, tabular numeric alignment, high information density, Invisible UI in dense tables, calm neutral baseline where color signals only anomalies/categories. |
| **Campus Atelier** | Forms, configuration drawers, inspector panels, dashboard workspace | Warm daylight paper surfaces, generous optical breathing room, comfortable long-session contrast without harsh pure-white glare, tactile `1px` top specular borders and restrained elevation. |
| **Archival Registrar** | Public institutional landing page (`/`) and authentication entry | Scholarly editorial typography (`Source Serif 4`), subtle public masthead paper grain (`<= 2–3%`) and visual rhyming across ledger borders/cells, user-controlled illustrative landing timetable preview, clean multi-column grid without marketing hype or SaaS tropes. |

### 5.2 Explicit Theme & Visual Prohibitions
- **Light-First Only (Dark Mode Deferred):** All surfaces in React Web v1 ship in a calibrated daylight palette. Dark mode is explicitly deferred; do **not** implement dark-mode switches or maintain dual light/dark theme tokens in v1.
- **No Obsidian Orbit Carryover:** Zero `#0B0C0E` obsidian canvas, zero `#FF7A00` neon orange primary accents.
- **No Spatial Orbit Engine Carryover:** Zero `Space Grotesk` display headings, zero spectral cyan-emerald (`H = 182°–186°`) glowing beams/conduits, zero counter-rotating SVG orbital rings, zero perspective 3D CSS tilts (`rotateX/rotateY`), and zero fluted vertical ribbing.
- **Anti-Slop Restraint:** Zero decorative KPI wallpaper, zero purple gradients, zero ungrounded AI assistant claims, zero glowing orbs, zero filler status badges (`Active`, `Verified`), zero generic 3-icon SaaS feature grids.

---

## 6. Typography, Color, Spacing & Accessibility Principles

### 6.1 Typography System (Anchor-First Pairing)

| Role | Font Family | Weights & Features | Usage Rules |
|---|---|---|---|
| **Editorial Headline Anchor** | `Source Serif 4` | `600`, `700`; optical sizing; `text-wrap: balance` | Public institutional landing page titles, auth masthead headings, major section editorial headers. Never paired with decorative gimmicks. |
| **UI & Dense Data** | `IBM Plex Sans` | `400`, `500`, `600` | Navigation, form labels, inspector prose, dense tabular descriptions, control labels. Admin `h1` capped at `<= 24px` (`-0.02em` tracking). |
| **Tabular & Academic Code** | `IBM Plex Mono` | `400`, `500`; `font-variant-numeric: tabular-nums` | Course codes (`CSE-3101`), time slots (`08:50–10:05`), teacher acronyms (`EBH`), room identifiers (`ACL-1`), SHA-256 hashes, batch/section labels, row counts, solver timers. |

### 6.2 Color Architecture (OKLCH Light-First Spine + Opaque sRGB Contrast Verification)

All design tokens live centrally in `apps/web/src/styles/tokens.css` using perceptual `oklch(L C H)` values and safe `color-mix(in oklab, ...)` blending (never `color-mix(in oklch, ...)` on low-chroma neutrals, avoiding Chromium neutral hue drift). Contrast compliance **must be verified over actual opaque composited sRGB foreground/background hex pairs** (not OKLCH lightness differences alone):

1. **Surface Hierarchy (Warm Archival Paper / Daylight Ledger):**
   - `--bg-canvas`: Recessed archival stone/paper workspace backdrop.
   - `--bg-surface`: Primary ledger card/table container surface.
   - `--bg-elevated`: Crisp elevated interactive surface (modals, popovers, active row highlights, sticky headers).
   - `--border-subtle` / `--border-strong`: Calibrated low-chroma ink alpha hairlines (`1px` structural grid discipline).
2. **Primary Action & Text Ink:**
   - **Charcoal Ink** (`--ink-primary`, `--action-primary`): Deep charcoal ink used for high-contrast primary typography and primary CTA buttons (authoritative registrar ink rather than bright neon buttons).
   - Stepped text hierarchy: `--ink-primary` (headings/values), `--ink-secondary` (labels/body), `--ink-muted` (metadata and dimmed inactive rows, each verified `>= 4.5:1` AA contrast against actual opaque composited sRGB surface hexes).
3. **Provisional Institutional Accent — Deep Botanical Pine:**
   - `--accent-pine`: Deep Botanical Pine used sparingly for active navigation indicators, focused input outlines, selected tab markers, and key institutional highlights.
   - **Provisional Status:** Pending verification against official Leading University institutional branding guidelines. Token isolation in `tokens.css` allows one-line brand calibration without refactoring components.
4. **Academic Schedule & Data Visualization Semantics ("Checkbox Off = Gray" Rule):**
   - Verified baseline rows and unflagged states remain calm neutral ink/paper.
   - Semantic tint + hairline border + 3px left accent bar activate **only** for meaningful domain distinctions:
     - **Theory Session** (muted slate-blue ledger ink/tint).
     - **Lab / Sessional** (botanical sage/pine tint).
     - **Joint / Co-Taught (`B+C`)** (warm archival ochre/amber tint).
     - **Hard Block / Conflict / R7 Violation / Jummah Block** (restrained vermilion/crimson alert tint + accessible text).
   - **Charts (Recharts v3):** Explicit visible X/Y axes, flat unrounded bar tops, tabular tick labels, and **sibling-bar hover dimming** (hovered datum stays full-opacity while sibling bars attenuate calmly).

### 6.3 Spacing, Geometry, Craft & Density
- **4px Optical Grid & Cross-Screen Consistency:** Base unit `4px` (`0.25rem`); container padding strictly exceeds internal item gaps (`gap < padding`). Maintain consistent cross-screen component dimensions and interaction grammar (`36px` dense admin toolbar controls, `40px` primary auth/form inputs and buttons, `>= 44px` compact touch targets, unified `340px–380px` inspector drawers, consistent `/` search & `Esc` modal/drawer dismissal).
- **Subtle Public Masthead Paper Grain & Visual Rhyming:** Apply optional ultra-subtle paper texture (`<= 2–3%` opacity) strictly to the public Archival Registrar masthead (`/`) while echoing clean `1px` ledger hairlines, tabular cell geometry, and corner proportions consistently across public, auth, and admin screens (keep `/admin/*` dense tables visually quiet and grain-free).
- **"Walmart Receipt" Edge Alignment:** Dissolve nested 4-sided card-inside-card boxes in checklists and inspectors into single top-level ledger containers divided by `1px` hairlines with aligned left labels and right-aligned tabular figures.
- **Middle Filename Truncation:** Preserve trailing `.xlsx` extensions and SHA suffix characters when truncating long Course Distribution filenames.

### 6.4 Accessibility & Restrained Motion
- **Automated Opaque sRGB WCAG AA Contrast Verification:** All text/surface (`>= 4.5:1` normal text) and UI control (`>= 3:1` large text, borders, icons, focus rings) pairings must pass automated WCAG AA verification computed over **actual opaque composited sRGB foreground/background hex pairs** in unit/CI checks.
- **Consistent Radix Tooltips:** Wrap root in Radix `TooltipProvider` (`delayDuration={400}`, `skipDelayDuration={0}`) so tooltips for corner-triangle overrides, truncated labels, and toolbar icons appear reliably via mouse and keyboard focus.
- **High-Contrast & Forced Colors:** Support `@media (prefers-contrast: more)` and `@media (forced-colors: active)`.
- **Keyboard Fluency:** `/` focuses the active workspace filter input; `Esc` closes modals/drawers; `focus-visible` outlines remain clearly visible on every interactive element.
- **Motion Discipline (`Motion` + CSS):**
  - Entrances `180–220ms` `cubic-bezier(0.16, 1, 0.3, 1)`, exits 20% faster (`140–170ms`), active press `100–120ms`.
  - GPU-composited `transform` and `opacity` only; shared-element transitions (`layoutId`) limited to functional state continuity (such as switching timetable lenses or active tabs), never continuous idle loops.
  - Strict `<MotionConfig reducedMotion="user">` and `@media (prefers-reduced-motion: reduce)` compliance, immediately suppressing animations and rendering rest states.

---

## 7. Preferred Technology Stack and Justification

> **Verification Requirement:** The stack below reflects the owner's **approved strategic technology direction**, NOT an instruction to install packages now. Exact package versions, React 19 peer dependency compatibility, and migration implications must be verified before installation (see §14).

| Category | Preferred Technology | Architectural Justification | Verification / Compatibility Note |
|---|---|---|---|
| **Frontend Core** | **React 19 + TypeScript** | Strong typing for complex academic contracts, wide ecosystem, clean separation from Flutter Mobile. | Currently installed in `apps/web/`: `react@^19.1.0`, `typescript@^5.8.3`. |
| **Build Tool** | **Vite** | Instant HMR, fast ES-module bundling, straightforward static output for Cloudflare Pages. | Currently installed: `vite@^6.3.5`. |
| **Styling** | **Tailwind CSS v4 + OKLCH** | Zero-runtime CSS utilities paired with native `@theme` and CSS custom properties in `oklch(...)`. | Currently installed: `tailwindcss@^4.1.8`, `@tailwindcss/vite@^4.1.8`. |
| **UI Primitives** | **shadcn/ui + Radix UI** | Accessible headless primitives (dialogs, popovers, dropdowns, tabs, tooltips) styled cleanly with Academic Ledger tokens without black-box theme lock-in. | Radix packages partially installed (`dialog`, `dropdown-menu`, `switch`, `tooltip`); shadcn/ui component layer not yet scaffolded. |
| **Searchable Inputs** | **cmdk** | Fast keyboard-first comboboxes for `> 10` courses, room pools, and faculty acronyms. | Not yet installed; Phase 0 verified `cmdk@1.1.1` supports React 18/19 (`react: ^18 \|\| ^19`). |
| **Animation** | **Motion** | Declarative layout transitions, reduced-motion awareness, and crisp modal/drawer choreography. | Legacy `framer-motion@^12.16.0` is currently installed; Phase 0 verified `motion@14.14.0` (`react: ^18 \|\| ^19`)—migrate `framer-motion` -> `motion` (`motion/react`) in Phase 1A to avoid duplicate libraries. |
| **Server State** | **TanStack Query v5** | Authoritative caching, focus-refetching (critical where Supabase Realtime is absent), optimistic rollback, and explicit loading/error states. | Currently installed: `@tanstack/react-query@^5.80.7`. |
| **Tables & Virtualization** | **TanStack Table v9 + TanStack Virtual** | High-density Course Distribution grids (`CD1` 12-column table), sorting, filtering, and virtualized row rendering for large semester catalogs. | Phase 0 `npm view` verified `@tanstack/react-table@9.3.1` (`latest`, `peerDependencies: {"react": ">=18"}`, stable line `8.21.3` also available) and `@tanstack/react-virtual@3.14.26` (React 19 supported); see [`WEB_PHASE_0_COMPATIBILITY_AND_AUDIT_ADDENDUM.md`](WEB_PHASE_0_COMPATIBILITY_AND_AUDIT_ADDENDUM.md). |
| **Charts** | **Recharts v3** | Declarative SVG charts for room utilization and departmental teaching load breakdowns. | Phase 0 verified `recharts@3.11.0` supports React 19 **with required matching `react-is@19.x` peer dependency**. |
| **Forms & Validation** | **React Hook Form + Zod** | Schema-driven validation matching PostgreSQL constraints (e.g., R7 off-day counts, `ClockTime` `HH:MM`, whitelist emails) with minimal re-renders. | Verified compatible (`react-hook-form@7.92.0`, `zod@4.6.7`, `@hookform/resolvers@7.0.8` supporting Zod v3/v4). |
| **Client State** | **Zustand** | Lightweight cross-pane state (active semester scope selection, lens filters, draft edit overlays) without heavy boilerplate. | Verified `zustand@5.1.0` supports React 18/19. |
| **Routing** | **React Router v7** | Declarative nested layouts (`PublicLayout`, `AdminShell`), route guards, and query-param synchronized tabs/inspectors. | Currently installed: `react-router-dom@^7.6.2` (`7.18.6` latest). |
| **Icons** | **Phosphor Icons** (`@phosphor-icons/react`) | Crisp geometric stroke weights matching `IBM Plex Sans` and visual consistency with Flutter Mobile's Phosphor icon family. | Currently installed: `@phosphor-icons/react@^2.1.7`. |
| **Testing** | **Vitest + Playwright** | Fast unit/component/opaque-sRGB WCAG contrast testing (`Vitest`) + real browser E2E, responsive viewport, and reduced-motion verification (`Playwright`). | Phase 0 verified `vitest@4.1.12` (`V4`) matches installed `vite@6.4.6` directly (`vitest@5.1.1` requires `vite@^6.4.0`), `@playwright/test@1.65.1`. |
| **Hosting (Provisional)** | **Cloudflare Pages** | Zero-cost/low-latency global CDN for static Vite SPA builds with preview deployments. | **Provisional decision**; requires SPA fallback (`_redirects`) and Supabase Auth callback allowlist registration. |

**No Overlapping Dependencies Policy:** Do not introduce redundant state managers, icon libraries (e.g., Lucide alongside Phosphor), CSS-in-JS libraries, duplicate animation libraries (`motion` vs `framer-motion`—use `motion` alone once migrated), or third-party Gregorian calendar suites.

---

## 8. Public Website UX Requirements

The public surface (`/`, `/login`, `/forgot-password`, `/reset-password`, `/access-required`) serves as UniVerse's institutional front door:

1. **Scholarly Institutional Presence & User-Controlled Timetable Preview (Archival Registrar):**
   - Present Leading University CSE routine lifecycle clearly using `Source Serif 4` editorial headlines, warm archival paper surfaces, Charcoal Ink typography, Deep Botanical Pine accents, subtle masthead paper grain (`<= 2–3%`), and consistent visual rhyming across ledger borders.
   - Replace the existing 3D kinetic `SpatialOrbitStage` with a crisp **user-controlled illustrative landing-page timetable preview** (flat 2D CSS Grid; **no involuntary 4.5s auto-cycling loop**) where visitors explicitly click sample constraint toggles (`Friday P4 Jummah Block`, `R7 Faculty Off-Day`, `6-Slot vs. 7-Slot`, `Section / Faculty / Room` lens) to watch slots reorganize smoothly.
2. **Public Sandbox Security Boundary:**
   - Public preview interactions on `/` **must operate 100% on curated client-side fixtures**.
   - Never invoke `POST /api/timetable/generate`, query private Supabase tables (`profiles`, `whitelists`, `routines`), or imply live database reads while unauthenticated.
3. **Clear Role Routing & Mobile Guidance:**
   - Clearly inform **Students and Faculty** that daily routines, live room availability, teacher location, and cancellation alerts live in the **UniVerse Mobile App** (Flutter), while keeping the web portal focused on **Routine Committee Administrators**.
4. **High-Trust Admin Authentication Entry:**
   - Support institutional Google OAuth (PKCE), email/password sign-in, password reset (`/forgot-password`, `/reset-password` with 10-minute recovery window), and server-issued `invite-admin` link completion with immediate URL hash token scrubbing.
   - Non-admin accounts (`student`, `teacher`) and non-whitelisted accounts must land on a helpful `/access-required` screen explaining the boundary and offering sign-out/account switching.

---

## 9. Administrative Workspace UX Requirements

Inside `/admin/*`, the design shifts to **Precision Ledger** + **Campus Atelier** for sustained operational clarity:

1. **Shell & Navigation Hierarchy:**
   - Persistent `240px` left sidebar at `>= 1100px`; collapsible drawer on tablet/mobile (`< 1100px`).
   - Compact `52px` top bar displaying current page title, **live Python Engine health badge** (`GET /`), primary operational shortcut (`Generate Routine`), and administrator profile menu.
   - Honest navigation grouping separating **Track 1 (Operational Routine Console)**, **Configuration**, **Communication & Users**, and **Track 2 (Committee Scheduling Workbench)** with clear capability badges (`STAGED`, `LOCKED`).
2. **Backend-Derived Command Center (`/admin/dashboard`):**
   - Replace decorative KPI cards with a **4-Stage Routine Readiness Checklist** (`01 Room & Lab Pools`, `02 Faculty & Off-Days`, `03 Course Eligibility & Time Grid`, `04 Active Routine & Publication`), proactive **Empty Production Config Pre-Publish Guard**, active routine version freshness, and explicit Refresh controls (honoring the absence of Supabase Realtime on `routines`/`notifications`).
   - **Strict Truthfulness Mandate:** Dashboard readiness indicators, counts, and active routine metadata **must remain 100% backend-derived** from Supabase and FastAPI responses—zero hardcoded illustrative filenames, SHAs, or synthetic completion states in live views.
3. **Dense Operational Table & Inspector Grammar:**
   - **Invisible UI in Dense Tables:** Keep secondary row actions unobtrusive/hidden until row hover or `focus-within`.
   - **Inactive-Row Dimming:** Visibly attenuate inactive rooms, disabled faculty, and historical versions without violating AA contrast.
   - **Hover-Revealed Copy Actions:** Reveal one-click copy triggers on hover/`focus-within` for course codes, teacher acronyms, revision IDs, and hashes.
   - **Corner-Triangle Override Indicators + Radix Tooltips:** Flag manual overrides and eligibility exceptions with subtle corner-triangle markers wired to consistent **Radix UI Tooltips** explaining provenance.
   - **Upfront Option-Level Filter Counts:** Display result counts directly beside filter pills/options (`Theory (18)`, `Inactive (3)`) prior to interaction.
   - **Matrix ↔ Compact List Switching:** Let admins toggle seamlessly between the custom CSS Grid **2D Timetable Matrix** and compact flat list scanning.
   - **Contextual Multi-Select Bulk Actions:** Reveal batch selection toolbars only when rows are actively checked.
   - **Recharts Discipline & Cross-Screen Consistency:** Use explicit X/Y axes, flat bar tops, and sibling-bar hover dimming on load/room charts, alongside identical cross-screen control heights (`36px`/`40px`), docked inspector dimensions (`340px–380px` at `>= 1100px`; Radix drawer/sheet below), and keyboard shortcuts (`/` filter focus, `Esc` dismiss).
4. **5-State Async Honesty Across Every Screen:**
   - Every async screen must implement: (a) layout-matched **loading** skeleton, (b) actionable **first-use empty** state, (c) one-click reset **zero-filter-match** state, (d) **recoverable error** banner (*Service Recovery Paradox*—preserving user input and offering 1-click retry), and (e) truthful **locked/staged** gate when backend schema support is absent.

---

## 10. Custom Academic Timetable Design Concept

The central scheduling interface **must be custom-built using CSS Grid and React** rather than adopting an off-the-shelf Gregorian calendar library (such as FullCalendar or react-big-calendar).

### Why Conventional Calendar Libraries Fail Academic Routine Requirements
1. **Recurring Abstract Week × Period Slots (Not Calendar Dates):** UniVerse routines bind to institutional days (`Sunday`–`Saturday`) and discrete period indices (`P1`–`P6` or `P1`–`P7`, e.g., `08:50–10:05` through `19:00–20:20` online reserve), with a midday break column (`G`) and dynamic summer/winter clock definitions from `timetable_settings.periods`.
2. **Multi-Lens Matrix Pivoting:** Administrators inspect the exact same routine dataset across three structural lenses:
   - **Section Lens:** Rows = Batch + Section (e.g., `58-A`, `58-B`, `58-B+C` joint), Columns = Periods `P1..P7` grouped or filtered by Day.
   - **Faculty Lens:** Rows = Teacher Acronym (`EBH`, `MSR`), visualizing R7 off-days, R4/R5 availability blocks, and R9 compactness gaps.
   - **Room Lens:** Rows = Physical Rooms (`ACL-1..4`, `RAB-302`, `ECL-1`), visualizing lab vs. theory parity and capacity utilization.
3. **Domain Semantics & Joint Offerings:** Joint sections (`58-B+C`) and multi-hour sessional labs require custom span/badge rendering, R10/R11 lab restrictions, Friday P4 Jummah hard-block hatching, and conflict overlays that conventional date-event calendars distort or obscure.

### Target CSS Grid Architecture
- Sticky period header (`tabular-nums` clocks) + sticky row header (`Batch-Section` / `Faculty` / `Room`) with instant **Matrix ↔ Compact List** switching.
- Connected filter bar directly above the grid (`Day`, `Batch`, `Department`, `Category`, `Search` bound to `/`) displaying **upfront option-level counts** and live tabular match counters (`Showing 42 of 186 slots`).
- Keyboard-accessible cells with **corner-triangle override indicators** + consistent **Radix UI Tooltips** opening a docked provenance inspector showing full course title, credit, teacher(s), room capacity, `is_service` status, and quick edit/validation actions.

---

## 11. Capability-Driven UI Architecture

To ensure the React Web frontend **never** repeats Flutter's silent-catch persistence issues or fabricates database writes, UI availability must be governed by a centralized **Capability Registry**:

```text
Backend Truth (Verified Tables / RPCs / Solver Endpoints)
        │
        ▼
Centralized Capability Model (Frontend Read-Only Resolver)
        ├── "live-persisted"   -> Full CRUD / RPC mutations enabled
        ├── "read-only"        -> Inspection enabled; writes disabled with explanation
        ├── "staged-no-db"     -> Honest staged banner; zero fake DB saves
        └── "fail-closed-gate" -> Locked behind specific Gate A–D prerequisites
```

### Mandatory Architectural Principles
1. **Zero Simulated Persistence:** Features whose underlying PostgreSQL tables or columns do not exist in the target environment (`CatalogCourse`, `CohortBatch`, Phase A extended `TimetableRoom`/`TimetableFaculty` columns, or unpromoted Track 2 Course Distribution contracts) must never display mock success toasts or swallow `PostgrestException` column errors.
2. **UI Gating Is Not Authorization:** The frontend capability model shapes UI affordances and prevents broken requests, while **actual security and authorization remain enforced exclusively by Supabase RLS, PostgreSQL triggers (`guard_profile_role`), `SECURITY DEFINER` RPC capability checks, Edge Function JWT verification, and FastAPI authentication**.

---

## 12. Track 1 (Operational Routine Console) vs. Track 2 (Committee Scheduling Workbench)

UniVerse separates routine operations into two explicit tracks matching verified vs. staged backend readiness:

| Dimension | Track 1 — Operational Routine Console | Track 2 — Committee Scheduling Workbench |
|---|---|---|
| **Primary Routes** | `/admin/routine` (`Manage`, `Grid`, `Generate`, `Upload`), `/admin/timetable/grid` | `/admin/scheduling` |
| **Backend Backing** | **Production-Backed Today** (`routines`, `routine_versions`, `timetable_runs`, `timetable_rooms`, `timetable_faculty`, `timetable_settings`, `timetable_course_eligibility`, `publish_routine()`, `timetables` bucket, FastAPI `/api/timetable/*`). | **Fail-Closed Behind Gates A–D** until `20261022140809_academic_catalog.sql`, `20261106130000_course_distribution_contract.sql`, policy persistence, and server validation contracts are promoted & verified. |
| **Input Model** | Uploaded `.xlsx` Course Distribution file + live baseline config tables (or rendered routine `.xlsx` upload for direct review/publish). | Immutable stored `course_distribution_sources` (`bytes` + `sha256`), audited cell overlays (`A`–`L`, formulas + cached values on `J`/`L`), and versioned R1–R16 policy snapshots. |
| **Core Workflows** | 1. Visualize active routine across Section, Faculty, Room lenses (plus Compact List toggle).<br>2. Direct manual routine CRUD (with explicit audit warning).<br>3. Submit `.xlsx` + config to FastAPI CP-SAT, poll `2s/240`, inspect 20 validation counters, download `.xlsx` or private JSON draft (`JOBS` remains volatile in-memory in Track 1).<br>4. Rendered `.xlsx` upload/review stays gated until the **provisional additive FastAPI parse/validation endpoint** receives separate review & authorization.<br>5. Atomic publish via `publish_routine()` with empty-config & co-teacher guards (upheld with scope enforcement, concurrency control, integrity validation, and snapshot recoverability roadmap). | **5-Stage Fail-Closed Progression:**<br>• **Gate A — Distribution Revision Read:** Read accepted revision bundle via `read_course_distribution_revision(target_revision)`.<br>• **Gate B — Audited Corrections:** Append row/column corrections via 8-param `append_course_distribution_correction(...)` with `40001` optimistic concurrency & automatic `stale` artifact invalidation.<br>• **Gate C — Policy Persistence & Authoritative Validation:** Persist R1–R16 rules & generate server-side `validation_report` artifacts.<br>• **Gate D — Durable Job Storage & Recoverable Atomic Publication:** Move solver execution from volatile `JOBS` to **durable job storage**, bind solves to `source_contract`, enforce scope/concurrency/integrity guarantees, and publish atomically with archived snapshot rollback. |
| **Failure Mode** | Blocks publication on validation failures (`ok !== true`), empty baseline config, or multi-teacher rows (`teachers.length > 1`). | Strictly refuses mock/simulated database saves; unavailable gates stay visibly locked with diagnostic details. |

---

## 13. Security and Cross-Platform Compatibility Principles

1. **Admin-Only Web Authentication Gate:**
   - Web sessions require both a valid Supabase GoTrue session **and** `public.profiles.role === 'admin'` (or first-time provisioning from `public.whitelists` where `role = 'admin'`).
   - Non-admin authenticated sessions (`student`, `teacher`) must never render `/admin/*` UI or store admin capabilities client-side.
2. **PKCE & Invite-Admin Callback Integrity:**
   - Standard logins and password resets use `flowType: 'pkce'`.
   - Server-initiated `invite-admin` flows emit implicit `#access_token=...&type=invite` fragments; the web entrypoint must scrub credentials from browser history before router settlement, verify user identity and invitation state against GoTrue, adopt the session cleanly, enforce a bounded 10-minute password recovery window, and complete admin profile provisioning on first sign-in.
3. **Flutter Mobile Read-Contract Preservation:**
   - Flutter Mobile relies on `public.routines` (`is_active = true`, `HH:MM:SS` times, `batch`, `section`, `teacher_code`, `room`, `is_service`), `public.cancellations` (including Realtime), `public.notifications` (`check_notif_type` enum), `public.notification_reads`, `public.resources`, `public.device_tokens`, and self-scoped `public.profiles`.
   - Any future RLS tightening on `profiles` (self + admin only) or `timetable_*` config tables (admin/scoped catalog only) must preserve non-admin mobile reads on `routines`, `cancellations`, `notifications`, `resources`, and own `profiles` row.
4. **FastAPI Coordinated Hardening Sequence (Backend Phase 5A):**
   - Currently `engine/main.py` lacks authentication and restricts nothing via CORS (`allow_origins=["*"]`). Hardening FastAPI follows an explicit 5-step compatibility sequence without redesigning the CP-SAT solver: (1) inspect existing Flutter request headers, (2) update Flutter (`TimetableEngineService`) + React Web for dual-client JWT compatibility, (3) introduce environment-driven CORS allowlists and gradual JWT verification, (4) verify Flutter Android, iOS compatibility, and React Web against dual-client mode, and (5) enforce production JWT verification only after compatibility is proven. Durable job storage belongs strictly to **Track 2 Gate D**, not minimal Track 1 security hardening.
5. **Database Environment Governance & CLI Ban:**
   - Production Supabase (`yxqyrjyzxitrgkhgauli`) remains **read-only** during initial React Web development; secondary project `oqwvxplteqtlrhktsplj` passed Phase 0 read-only SQL verification (`37` tables, `0` rows, zero outbound `send-push` webhooks) and is **owner-approved as the non-production staging project** (quarantine lifted). Never use Supabase CLI.
6. **No Secret Exposure:**
   - Only `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, and `VITE_TIMETABLE_BASE_URL` belong in browser bundles. `SUPABASE_SERVICE_ROLE_KEY`, SMTP credentials, and FCM service accounts remain strictly server-side (Edge Functions / Render).

---

## 14. Major Architectural Constraints & Decision Classification Matrix

| Classification | Decision / Item | Notes & Governance Impact |
|---|---|---|
| **Approved Decision** | Flutter Mobile (`lib/`, `android/`, iOS-compatible) retained for Students & Teachers under **Obsidian Orbit**. | Zero unrequested mobile rewrites; active iOS feature expansion is deferred while continuous Android & iOS compatibility preservation remains mandatory. |
| **Approved Decision** | Standalone React 19 + TypeScript + Vite web app (`apps/web/`) replaces Flutter Web for Administrators + Public Landing. | Shares Supabase & FastAPI backends without duplicating CP-SAT or ingestion logic. |
| **Approved Decision** | **UniVerse Academic Ledger** visual direction (Precision Ledger + Campus Atelier + Archival Registrar), light-first, dark mode deferred. | Supersedes Spatial Orbit Engine (`apps/web/` Phase 0/1) and forbids Obsidian Orbit carryover. |
| **Approved Decision** | `Source Serif 4` + `IBM Plex Sans` + `IBM Plex Mono`, Charcoal Ink primary action, OKLCH tokens verified via opaque sRGB WCAG AA checks, `prefers-reduced-motion`, user-controlled landing timetable, Phosphor Icons. | Tokenized centrally in `apps/web/src/styles/tokens.css`. |
| **Approved Decision** | Custom CSS Grid + React 2D Academic Timetable Matrix + Compact List toggle (no Gregorian calendar library), backend-derived dashboard readiness. | Supports Section, Faculty, Room lenses + Friday P4 Jummah + `B+C` joint sections. |
| **Approved Decision** | Track 1 (Operational Routine Console) vs. Track 2 (Committee Scheduling Workbench fail-closed behind Gates A–D; durable job storage placed in Gate D). | Centralized frontend capability model; zero simulated DB mutations. |
| **Approved Constraint** | Never recommend or use Supabase CLI; keep prod `yxqyrjyzxitrgkhgauli` read-only initially; use audited/owner-approved staging `oqwvxplteqtlrhktsplj` (`37` tables, `0` rows) for non-prod testing. | Mandatory permanent project rule (`AGENTS.md`, `CLAUDE.md`); Phase 0 SQL verification completed. |
| **Approved (Phase 1A)** | **Deep Botanical Pine** accent color. | Owner-confirmed for Phase 1A React Web (`tokens.css` remains cleanly calibrated if institutional branding updates later). |
| **Provisional Decision** | **Cloudflare Pages** hosting for `apps/web/`. | Subject to owner confirmation, SPA `_redirects` setup, and Auth callback URL registration. |
| **Provisional Preference (Gated)** | Additive, non-mutating **FastAPI parse/validation endpoint** (`engine/main.py`) for Track 1 rendered `.xlsx` uploads. | Replaces earlier TypeScript `RoutineWorkbookParser` assumption; Dart parser stays unchanged initially; shared fixtures must prove equivalence; requires separate review & owner authorization before implementation. |
| **Architectural Recommendation** | Harden `engine/main.py` via 5-step dual-client JWT + env-driven CORS sequence without solver redesign. | Prevents unauthenticated compute abuse after Flutter + React Web compatibility is verified; durable job storage deferred to Track 2 Gate D. |
| **Architectural Recommendation** | Upgrade `publish_routine()` (via separate DB authorization) for full publication safeguards: scope enforcement, concurrency control, integrity validation, archived row snapshots, and co-teacher arrays (`teachers text[]`). | Currently `publish_routine()` permanently wipes `public.routines` rows without row snapshots and blocks co-taught courses. |
| **Architectural Recommendation** | Scope `profiles_select`, `timetable_*`, `course_distribution_*_read` (`scheduling_scope_id IS NULL`), and `storage.objects` write policies (`timetables`, `resources`, `avatars`) once verified against mobile queries & `send-push`. | Closes over-broad `authenticated` permissions without breaking mobile (`send-push` uses `service_role`; Flutter does not upload to `avatars`). |
| **Verified in Phase 0 Addendum** | React 19 compatibility of TanStack Table (`9.3.1` latest vs. `8.21.3` stable), TanStack Virtual (`3.14.26`), Recharts (`3.11.0` requiring `react-is@19`), `motion` vs. `framer-motion` deduplication, `cmdk` (`1.1.1`), Vitest (`4.1.12` vs `5.1.1` on Vite `6.4.6`). | Recorded from live `npm view` metadata in [`WEB_PHASE_0_COMPATIBILITY_AND_AUDIT_ADDENDUM.md`](WEB_PHASE_0_COMPATIBILITY_AND_AUDIT_ADDENDUM.md) (no packages installed yet). |
| **Verified in Phase 0 Addendum** | Live PostgreSQL schema, exact baseline counts, triggers, RLS, RPC signatures, Storage & Realtime across `yxqyrjyzxitrgkhgauli` (`18` tables; `796` routines; `0` eligibility) and `oqwvxplteqtlrhktsplj` (`37` tables; `0` rows). | Recorded from owner-executed read-only SQL Editor output in [`WEB_PHASE_0_COMPATIBILITY_AND_AUDIT_ADDENDUM.md`](WEB_PHASE_0_COMPATIBILITY_AND_AUDIT_ADDENDUM.md) §4. |
| **Requires External Verification** | Supabase Auth Site/Redirect URLs, Google Cloud OAuth web/iOS client config, deployed Edge Function `AUTH_WEB_CALLBACK_URLS`/`PUSH_WEBHOOK_SECRET`, Render runtime telemetry, Cloudflare Pages setup. | Cannot be inspected via SQL Editor or local repo files; checked in Supabase/Render/Cloudflare dashboards prior to Phase 1B / 5C. |
