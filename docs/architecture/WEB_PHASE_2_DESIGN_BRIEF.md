# UniVerse React Web v1 — Phase 2 UI/UX Design Brief & Package Approval Request

> **Phase Scope:** Sub-Phase **2** (`apps/web/` Administrative Dashboard Recharts Upgrade + 8 Live-Persisted Baseline/Operations CRUD Screens + 2 Honest `staged-no-db` Catalog Stubs).
> **Document Gate Status:** **Docs-Only Approval Request** (per `AGENTS.md` §2/§6 & `WEB_IMPLEMENTATION_ROADMAP.md` Phase 2 §5). Zero edits to `apps/web/src/`, `apps/web/package.json`, `lib/`, `android/`, `ios/`, `engine/`, or `supabase/` and zero `npm install` calls until explicit Product Owner sign-off.
> **Authoritative Grounding:** [`WEB_ARCHITECTURE_DESIGN_BLUEPRINT.md`](WEB_ARCHITECTURE_DESIGN_BLUEPRINT.md), [`WEB_SOURCE_VERIFICATION_REPORT.md`](WEB_SOURCE_VERIFICATION_REPORT.md) (`F-01`–`F-31`), [`WEB_IMPLEMENTATION_ROADMAP.md`](WEB_IMPLEMENTATION_ROADMAP.md) (Phase 2), [`WEB_PHASE_0_COMPATIBILITY_AND_AUDIT_ADDENDUM.md`](WEB_PHASE_0_COMPATIBILITY_AND_AUDIT_ADDENDUM.md), and [`WEB_PHASE_1A_DESIGN_BRIEF.md`](WEB_PHASE_1A_DESIGN_BRIEF.md).

---

## 1. Phase 1A Micro-Polish Carry-Over (5 Mandatory Fixes at Start of Phase 2)

These five visual QA and housekeeping refinements from Sub-Phase 1A review will be folded into the opening commit of Phase 2 before building new CRUD routes:

1. **Readiness Primary CTAs Always Visible (`AdminDashboardPage.tsx`) & First-Login `409` Race Guard (`AuthProvider.tsx`):**
   - Remove `.row-reveal-action` from the 4 primary checklist action links (`Configure Rooms`, `Manage Faculty`, `Set Eligibility`, `Open Operations`) in [`apps/web/src/features/admin/pages/AdminDashboardPage.tsx`](../../apps/web/src/features/admin/pages/AdminDashboardPage.tsx) (`line 413`) so they render at full `1.0` opacity and contrast across both desktop and touch viewports.
   - Reserve `.row-reveal-action` (hover/`focus-within` reveal in [`app.css`](../../apps/web/src/styles/app.css)) strictly for secondary row actions (`Edit`, `Copy`, `Delete`, `Inspect`) inside dense Phase 2 data tables.
   - Fold in the **Sub-Phase 1B first-login `409 Conflict` race fix** (`AuthProvider.tsx`): deduplicate concurrent `resolveAdminGate(user)` promises per `user.id` (`inFlightGateRef`) and recover cleanly on PostgreSQL `23505` / HTTP `409` duplicate profile inserts by re-selecting `public.profiles`.

2. **Sidebar Rail Width, Badge Restraint & Profile Reclassification:**
   - Remove visible `READ-ONLY` sidebar badges by dropping `sidebarBadge: "READ-ONLY"` on `admin.routine-grid` in [`capabilityRegistry.ts`](../../apps/web/src/core/capabilities/capabilityRegistry.ts) and rendering sidebar pills in [`AdminShell.tsx`](../../apps/web/src/features/admin/AdminShell.tsx) **only** for `LOCKED` (`fail-closed-gate`) and `STAGED` (`staged-no-db`) entries.
   - Restore the fixed desktop sidebar rail width from `w-[264px]` to `w-[240px]` in `AdminShell.tsx` (adjusting sidebar item padding/text spacing cleanly so `Scheduling Workbench` + `LOCKED` stays unclipped on one line within `240px`).
   - Reclassify `admin.profile` (`/admin/profile`) in `capabilityRegistry.ts` from `"read-only"` to `"live-persisted"` (`implementedInPhase1A` -> Phase 2 live edit over own `public.profiles` row).

3. **Copy, Telemetry & Account Trigger Polish:**
   - Update auth header back-link label in [`PublicAuthLayout.tsx`](../../apps/web/src/features/auth/PublicAuthLayout.tsx) (`line 71`) from `"Back to Specimen"` to `"Back to Home"`.
   - Remove the `"01 —"` coordinate eyebrow prefix rows on `/` ([`LandingPage.tsx`](../../apps/web/src/features/auth/pages/LandingPage.tsx) `lines 31–35`) and `/login` ([`PublicAuthLayout.tsx`](../../apps/web/src/features/auth/PublicAuthLayout.tsx) `lines 90–94`) in compliance with Academic Ledger anti-slop rules.
   - Relabel `"Automated Distribution Workbook Upload"` (`track1.workbook-upload`) in `SUBFEATURE_CAPABILITIES` ([`capabilityRegistry.ts`](../../apps/web/src/core/capabilities/capabilityRegistry.ts)) to `"Rendered Routine Upload"` with a distinct status label `"Gated · Phase 3B"` so it is not conflated with Track 2 `"Gates A–D"`.
   - Update [`EngineHealthBadge.tsx`](../../apps/web/src/shared/components/EngineHealthBadge.tsx) so disconnected local preview (`isDevPreview === true`) displays `"Engine · Preview"` with a neutral/pine preview indicator instead of live Render polling noise.
   - Add a subtle `CaretDown` icon (`@phosphor-icons/react`, `12px`) beside the admin monogram button inside [`AdminShell.tsx`](../../apps/web/src/features/admin/AdminShell.tsx) so the single Account Popover affords interactivity immediately.

4. **Compact Landing Specimen Default & Editorial Serif Weight `700`:**
   - Default [`AcademicLedgerPreview.tsx`](../../apps/web/src/features/onboarding/components/AcademicLedgerPreview.tsx) / [`specimenStore.ts`](../../apps/web/src/features/onboarding/store/specimenStore.ts) cleanly to `"list"` on compact viewports (`window.matchMedia("(max-width: 767px)")` at initialization, never overriding manual user switches) and add a subtle CSS `mask-image: linear-gradient(...)` right-edge fade when `Matrix` scrolls horizontally.
   - Add `Source Serif 4` bold weight `700` alongside `600` (`family=Source+Serif+4:opsz,wght@8..60,600;8..60,700`) in [`apps/web/index.html`](../../apps/web/index.html).

5. **Roadmap Single-Source Deduplication:**
   - Remove the duplicate file `docs/architecture/web-separation/WEB_IMPLEMENTATION_ROADMAP.md` (keeping [`docs/architecture/WEB_IMPLEMENTATION_ROADMAP.md`](WEB_IMPLEMENTATION_ROADMAP.md) as the sole authoritative roadmap document).

---

## 2. Exact Phase 2 Package Delta (`apps/web/package.json` — Pending Owner Approval)

All versions and React 19 peer dependencies below were verified in [`WEB_PHASE_0_COMPATIBILITY_AND_AUDIT_ADDENDUM.md`](WEB_PHASE_0_COMPATIBILITY_AND_AUDIT_ADDENDUM.md) §1.2. **No packages will be installed until owner approval.**

| Action | Package | Version Spec | Role in Phase 2 |
|---|---|---|---|
| **Install (`dependencies`)** | `@tanstack/react-table` | `^9.3.1` | Typed dense operational tables, sorting, multi-select row selection, & column visibility. |
| **Install (`dependencies`)** | `@tanstack/react-virtual` | `^3.14.26` | Virtualized scrolling for larger eligibility, faculty, user directory, and notification tables. |
| **Install (`dependencies`)** | `recharts` | `^3.11.0` | Room capacity/type & live published slot load bar charts on `/admin/dashboard`. |
| **Install (`dependencies`)** | `react-is` | `^19.3.1` | **Mandatory React 19 peer dependency** required by `recharts@^3.11.0`. |
| **Install (`dependencies`)** | `cmdk` | `^1.1.1` | Searchable comboboxes (`Course Eligibility`, faculty courses, room filters) + `Cmd+K` quick route palette inside `AdminShell`. |
| **Deferred to Phase 3 / 4** | `react-resizable-panels` | *(Deferred)* | Phase 2 uses a crisp CSS Grid **55/45 master-detail split**; draggable split panes are deferred to Track 1 / Track 2 Workbench if needed. |
| **Not Adopted** | `react-hotkeys-hook` | *(Not needed)* | `/` search focus and `Esc` dismissal use a small native React `keydown` hook (~25 lines checking `input`/`textarea` targets) alongside Radix `Dialog` dismissal. |
| **Strictly Excluded** | `lucide-react`, `xlsx`, `exceljs` | *(Prohibited)* | Icons stay strictly `@phosphor-icons/react` (`Regular`); Excel parsing stays server-side (`engine/`) pending Phase 3B authorization. |

---

## 3. Shared Phase 2 Operational Patterns

Every Phase 2 screen enforces one uniform Academic Ledger interaction contract (grounding the UI/UX research principles and [`ADMIN_CRASH_PERFORMANCE_AND_UI_FIX_REPORT.md`](../../ADMIN_CRASH_PERFORMANCE_AND_UI_FIX_REPORT.md) guardrails):

1. **55/45 Master-Detail Inspector Geometry:**
   - **Desktop (`>= 1024px` usable workspace column):** Default table spans 100% width until an item or `+ Add ...` CTA opens; when inspecting/editing/creating, the workspace splits smoothly into `minmax(0, 1.22fr)` (~55%) left data table and `minmax(340px, 1fr)` (~45%, capped `<= 460px`) docked right elevated sheet (`--bg-elevated`, `1px` `--border-subtle`) with a crisp `X` close button (`Esc` also dismisses if clean, or triggers dirty-discard confirmation).
   - **Compact / Mobile (`< 1024px`):** Inspector opens cleanly inside a Radix `Dialog` slide-over drawer/sheet (`100dvh` safe padding).

2. **Uniform `36px` Toolbar & Filter Grammar:**
   - Search input (`/` keyboard shortcut to focus), upfront option-level filter pills showing live tabular counts *before* clicking (e.g., `All (30)`, `Active (28)`, `Inactive (2)`, `Labs (6)`), and primary CTA sit flush at uniform `36px` control height with `flex-wrap: wrap; gap: 8px` (zero clipped strips and zero duplicate `+ +` button prefixes—e.g. `Add Room`, `Invite Admin`, `Publish Broadcast`).

3. **Dense Table Ergonomics:**
   - Built with `@tanstack/react-table` + `@tanstack/react-virtual` where row sets exceed compact bounds; all numbers, counts, priority integers, and capacities use `font-variant-numeric: tabular-nums`.
   - **Inactive-Row Dimming:** Rows where `is_active === false` (or `is_eligible === false`) step typography quietly to `--ink-muted` (`#696660`, verified `4.89:1–5.67:1` WCAG AA) rather than translucent opacity hacks.
   - **Invisible UI Secondary Actions & Hover Copy:** Secondary row triggers (`Edit`, `Copy Acronym`, `Toggle Active`, `Delete`) stay hidden via `.row-reveal-action` (`opacity: 0` until row hover or keyboard `:focus-within` on `>= 640px` hover pointers; visible immediately on touch `< 640px`), paired with one-click copy triggers (`Copied` Sonner/inline feedback) for emails, course codes, acronyms, and URLs.
   - **Contextual Multi-Select Bulk Action Bar:** Hidden when 0 checkboxes are selected; slides into view smoothly (`180ms` ease-out) above the table with live count badge (`3 selected`) + explicit batch operations (`Activate`, `Deactivate`, `Remove`) only when `>= 1` rows are checked.

4. **Sticky Dirty-State Save Bar & Service Recovery Paradox:**
   - Any form edit inside a docked inspector or `/admin/timetable/settings` activates a bottom sticky dirty bar (`Unsaved changes` + `Discard` | `Save Changes`). Switching selection or pressing `Esc` while dirty prompts an accessible Radix confirmation dialog (`Esc` dismissible).
   - All mutations use explicit try/catch handling mapped to `react-hook-form` errors + persistent recoverable **Service Recovery** alert banners and `sonner` toasts — **never** silent `catch (_) {}` blocks or false success confirmations (`F-18`).

5. **5 Mandatory Async States & Overlay Separation:**
   - Every query-driven screen renders:
     1. `loading`: Layout-matched warm neutral skeleton preserving column widths.
     2. `empty`: Actionable first-use prompt (`Add First Room`, `Create Eligibility Link`, etc.).
     3. `filter-empty`: Clear zero-match explanation paired with a 1-click `Reset Filters` button.
     4. `error`: Recoverable inline alert preserving unsaved form inputs + `Retry` action.
     5. `staged-no-db`: Non-editable governance card for `/admin/timetable/courses` & `/admin/timetable/batches`.
   - **Popovers** hold lightweight table density/view toggles and account info; **Blocking Radix `Dialog` Modals + `sonner` Toasts** handle destructive deletes, whitelist removals, role changes, and `invite-admin` dispatches.

6. **Recharts v3 Dashboard Contract (`/admin/dashboard`):**
   - Strictly backend-derived (`timetable_rooms`, `routines`); zero fabricated numbers.
   - Explicit visible X and Y axes (`11.5px` `--ink-muted` ticks with `tabular-nums`), dashed subtle gridlines (`--border-subtle`), **flat unrounded bar tops** (`radius={[0, 0, 0, 0]}`), single semantic/Deep Botanical Pine scale, custom Academic Ledger tooltip, and **sibling-bar hover dimming** (non-hovered `<Bar>`/`<Cell>` items smoothly attenuate to ~35% opacity while hovered datum stays crisp `100%`).

---

## 4. Screen-by-Screen Contracts & Verified PostgreSQL Column Bindings

> **F-18 Schema Safety Rule:** Every Supabase `.select()`, `.insert()`, `.update()`, and `.upsert()` call in Phase 2 binds **strictly** to the **8 guaranteed baseline PostgreSQL columns** on `timetable_rooms` and `timetable_faculty` documented in `20261021214512_reconstructed_baseline.sql` / `F-20` across both staging and production. Do **not** run noisy HTTP 400 column probes for staging-only columns (`timetable_rooms.{campus,features}` and `timetable_faculty.home_department_id`), deferring those cleanly to Phase 4A; and **never** emit Flutter's 11 non-DB Phase A fields (`classification`, `building_and_floor`, `in_active_semester_pool`, `bound_course_codes`, `declared_window_matrix`, `employment_type`, `is_sust_adjunct`, `sust_compactness_mode`, `is_external_guest`, `has_external_block`, `slot_matrix`).

### Route Governance Summary

| Route | Capability Status | Supabase / Edge Target | Notes |
|---|---|---|---|
| `/admin/dashboard` | `live-persisted` | Counts + `routines`, `timetable_rooms`, `routine_versions` | Phase 1A polish + Recharts v3 operational load charts & deep links. |
| `/admin/timetable/rooms` | `live-persisted` | `public.timetable_rooms` | Production 8 columns (`campus`/`features` conditional). |
| `/admin/timetable/faculty` | `live-persisted` | `public.timetable_faculty` | Production 8 columns (`home_department_id` conditional). |
| `/admin/timetable/course-eligibility` | `live-persisted` | `public.timetable_course_eligibility` + `routines` codes | `cmdk` selector; solves `F-20` `0` eligibility setup. |
| `/admin/timetable/settings` | `live-persisted` | `public.timetable_settings` (`id = 1`) | 3-tab Phase B3 studio + `ClockTime` 24h validation. |
| `/admin/users` | `live-persisted` | `public.profiles`, `public.whitelists`, `invite-admin` | Directory, whitelist CRUD, & invite modal. |
| `/admin/broadcast` | `live-persisted` | `public.notifications` | Strict `check_notif_type` enum & audience parity. |
| `/admin/resources` | `live-persisted` | `public.resources` + bucket `resources` | File upload (`<semester>/<epoch>_<file>`) & Drive links. |
| `/admin/profile` | `live-persisted` | Own `public.profiles` row (`id = auth.uid()`) | Reclassified from `read-only`; zero `avatars` bucket writes (`F-30`). |
| `/admin/timetable/courses` | `staged-no-db` | None (`CapabilityRegistry`) | Disabled inputs; honest staged notice (`F-18`). |
| `/admin/timetable/batches` | `staged-no-db` | None (`CapabilityRegistry`) | Disabled inputs; honest staged notice (`F-18`). |

---

### 1. `/admin/dashboard` — Command Center Upgrade
- **Upgrades over Phase 1A:**
  - Fold in Section 1 polish (full-contrast readiness CTAs, removed `READ-ONLY` badge confusion).
  - Add 2 clean Recharts v3 analytical panels (flat bar tops, explicit X/Y axes, sibling-bar hover dimming) derived strictly from live Supabase rows:
    1. **Weekly Published Slot Load by Batch** (aggregating active `public.routines` rows by `batch`, sorted cleanly, empty-state fallback when `routines === 0`).
    2. **Configured Room Capacity Breakdown** (aggregating `public.timetable_rooms` into `Theory Rooms`, `Labs`, and `Galleries` with active/inactive counts).
  - Direct quick-action links from each Readiness row (`01`..`04`) cleanly route into the newly live Phase 2 configuration pages.

### 2. `/admin/timetable/rooms` — Room & Lab Pools
- **Verified DB Columns (`public.timetable_rooms`):**
  - Strictly the 8 baseline columns: `id` (`uuid PK`), `name` (`text not null unique`), `building` (`text | null`), `is_lab` (`boolean default false`), `is_gallery` (`boolean default false`), `capacity` (`integer | null`), `is_active` (`boolean default true`), `dept` (`text | null`). *(Staging-only `campus`/`features` deferred to Phase 4A without HTTP 400 column probing.)*
- **Layout & Interactions:**
  - 55/45 Master-Detail table & docked inspector (`Add Room` CTA, search by name/building/dept, upfront filter counts: `All`, `Labs`, `Gallery`, `Active`, `Inactive`, bulk Activate/Deactivate/Delete).
  - Hover copy on room `name`; inactive rows dimmed via `--ink-muted`.
- **Zod Validation:** `name` trimmed non-empty uppercase normalized (`e.g. RAB-302`), `capacity` optional positive integer (`1..500`), `dept` from departmental options (`CSE`, `EEE`, `BBA`, `English`, `GED`, `CE`, `Law`) or custom text. Zero non-DB Phase A fields emitted.
- **Honest Staged Notice:** Banner in inspector disclosing that R10/R11 declared lab availability window matrices and R14 term-pool assignment flags remain `staged-no-db` until database schema promotion (`F-18`).

### 3. `/admin/timetable/faculty` — Faculty Roster & Off-Day Bounds
- **Verified DB Columns (`public.timetable_faculty`):**
  - Strictly the 8 baseline columns: `id` (`uuid PK`), `acronym` (`text not null unique`), `full_name` (`text | null`), `dept` (`text | null`), `designation` (`text | null`), `off_days` (`text[] not null default '{}'`), `is_active` (`boolean default true`), `courses` (`text[] not null default '{}'`). *(Staging-only `home_department_id` deferred to Phase 4A without HTTP 400 column probing.)*
- **Layout & Interactions:**
  - Filter chips strictly backed by schema columns with upfront counts (`All`, `Active`, `Inactive`, `R7 Off-Day Advisory`, plus Department selector — omitting any non-DB `Permanent` chip), search by acronym/name/course code, `55/45` inspector with 7-day interactive off-day selector (`Sunday`–`Saturday`), `designation` selector (`Professor`, `Associate Professor`, `Assistant Professor`, `Senior Lecturer`, `Lecturer`), `dept` selector, and course code tag editor (`courses text[]`).
  - **R7 Advisory Indicator:** Highlights rows whose `off_days.length` falls outside `2..3` days (`R7 Bound`), cleanly explaining that committee policy expects 2–3 weekly off-days for permanent faculty while still permitting verified exceptions.
- **Zod Validation:** `acronym` uppercase alphanumeric (`2..10` chars), `off_days` subset of `Sunday..Saturday`, `courses` array of normalized uppercase course codes. Strictly excludes non-DB keys (`slot_matrix`, `employment_type`, etc.).
- **Honest Staged Notice:** Explicit disclosure inside inspector that R4 external service blocks, R5 adjunct guest declared windows, and R9 SUST compactness flags remain `staged-no-db` pending schema support (`F-18`).

### 4. `/admin/timetable/course-eligibility` — Course Eligibility Matrix
- **Verified DB Columns (`public.timetable_course_eligibility`):**
  - `id` (`uuid PK`), `acronym` (`text not null`), `course_code` (`text not null`), `is_eligible` (`boolean not null default true`), `priority` (`integer | null`, `CHECK (priority is null or priority > 0)`), `created_at`, `updated_at`.
  - Unique constraint: `(acronym, course_code)` — `.upsert(..., { onConflict: "acronym,course_code" })` with friendly inline error handling on duplicate conflicts.
- **Layout & Dynamic Course Derivation:**
  - `cmdk` searchable comboboxes for **Faculty Acronym** (sourced dynamically from live `timetable_faculty`) and **Course Code** (derived dynamically by unioning `subject_code` from `public.routines`, existing `timetable_course_eligibility.course_code`, and `timetable_faculty.courses`, plus custom code entry if needed — **zero hardcoded course fixtures** per roadmap Phase 2 §6.2!).
  - Upfront filter pills (`All`, `Eligible`, `Blocked`, `Prioritized`), grouped or flat TanStack Table with hover copy and bulk eligibility toggling / removal.
- **Zod Validation:** Normalized uppercase `acronym` & `course_code`, `is_eligible` boolean, `priority` nullable positive integer (`>= 1`). Clear inline banner explaining eligibility functions as a pre-publish validation gate (referencing `013_faculty_course_eligibility.sql` semantics cleanly in plain institutional language).

### 5. `/admin/timetable/settings` — Term Clock & Committee Rules (`id = 1`)
- **Verified DB Columns (`public.timetable_settings` singleton `id = 1`):**
  - `id` (`integer PK`, `CHECK (id = 1)`), `semester_label` (`text | null`), `working_days` (`text[] | null`), `periods` (`jsonb not null`, `{ idx, label, start, end, col }[]`), `weeks_in_term` (`integer not null default 14`, `1..52`), `fixed_sessions_per_week` (`integer | null default 2`, `0..7`), `friday_no_p4` (`boolean not null default true`), `blocked_periods` (`jsonb not null default '{}'`), `online_periods` (`jsonb not null default '[7]'`), `allow_online_periods` (`boolean not null default false`), `excluded_periods` (`jsonb not null default '[]'`), `semester_map` (`jsonb not null default '{}'`), `service_scope` (`text not null default 'resource_only'`), `weights` (`jsonb not null`).
- **3-Tab Structure (Matching Flutter Phase B3 Parity):**
  1. **Tab 1 — Term Clock & R15 Grid:** `semester_label`, `weeks_in_term` (`1..52`), `fixed_sessions_per_week` (`0–7` with clear notice that `0` / empty restores term-ratio derivation), `working_days` (`Sunday`–`Saturday`), R15 regular daily on-campus slot toggle (`6-Slot Grid` vs `7-Slot Grid`, defaulting to 7 regular `P1–P7` on-campus slots, decoupled cleanly from the separate `Allow Online Slot` configuration card managing `allow_online_periods` / `online_periods`), editable period timeline (`D`, `E`, `F`, `H`, `I`, `J`, `K`, preserving `col` key for engine workbook parity), and explicit `semester_map` (`batch -> study semester`) JSON/pair rows + `excluded_periods`.
  2. **Tab 2 — Committee Rules & Blocked Slots:** Authoritative interactive **Friday P4 Jummah Hard Block** control updating both `friday_no_p4` and `blocked_periods["Friday"]`, visual per-day/per-period block grid (`blocked_periods`), `service_scope` toggle (`'resource_only'` vs `'ignore'`), plus concise read-only policy ledger explaining enforced solver rules `R1–R14`.
  3. **Tab 3 — Optimization Weights:** Preset selector (`Balanced Departmental`, `Compact Cohorts`, `Faculty Off-Day Focus`) + numeric inputs (`spread`, `late_slot`, `compactness`, `different_days`) matching solver defaults `{"spread": 2, "late_slot": 1, "compactness": 3, "different_days": 8}`.
- **ClockTime 24h Parity (`ClockTime.normalize` + `repairSequence`):**
  - TypeScript port of `ClockTime` (`apps/web/src/core/utils/clockTime.ts`) normalizing inputs cleanly to strict `HH:MM` (matching `engine/render.py` `h, m = hhmm.split(":")` requirement in `clock_time.dart:83-86`!) and enforcing strictly increasing non-overlapping slot times (`start < end` and `period[i].start >= period[i-1].end`).
- **Sticky Dirty Bar:** Single full-width sticky bottom bar inside workspace showing unsaved delta badge, `Discard Changes`, and `Save Settings` (`.upsert({ id: 1, ... }, { onConflict: "id" })` so empty staging with `0` rows persists safely alongside populated production).

### 6. `/admin/users` — Directory, Whitelists & Admin Invites
- **Verified Backend Contracts:**
  - `public.profiles`: `id, email, role ('student' | 'teacher' | 'admin'), name, avatar_url, batch, section, semester, student_id, teacher_code, designation, department, courses, created_at`.
  - `public.whitelists`: `email (PK), role ('student' | 'teacher' | 'admin'), name, teacher_code, batch, section, semester, department, designation`.
  - Edge Function `invite-admin`: POST `{ email, name, redirect_to: `${window.location.origin}/` }`.
- **Layout & Interactions (2 Sub-Tabs + 55/45 Inspector + Invite Modal):**
  1. **Directory (`profiles`)**: Upfront role counts (`All`, `Admins`, `Teachers`, `Students`), search by name/email/student ID/teacher code, inspector supporting safe `role` update (trigger `guard_profile_role` permits admin updates) with explicit confirmation modal on role escalation to `admin` / demotion of own role blocked cleanly.
  2. **Whitelist & Invites (`whitelists` + `invite-admin`)**: Add/Remove teacher whitelist entries (`email, name, teacher_code, department, designation`), view existing whitelisted entries, and primary **`Invite Administrator`** modal invoking `supabase.functions.invoke("invite-admin", { body: { email, name, redirect_to: `${window.location.origin}/` } })`.
- **Honest Edge Function Recovery:** Parses `400` (`"Invitation callback is not approved."`, `"Whitelist failed"`), `401` (`"Invalid session."`), and `403` (`"Only admins can invite admins."`) from `FunctionsHttpError` / response JSON cleanly into inline alert + Sonner error toast without fake success fallback.

### 7. `/admin/broadcast` — Campus Announcements & History
- **Verified DB Columns (`public.notifications`):**
  - `id` (`uuid PK`), `title` (`text not null`), `body` (`text not null`), `type` (`text not null`, `CHECK check_notif_type`), `sent_by` (`uuid FK -> profiles.id`), `target_role` (`text | null`), `target_batch` (`text | null`), `target_section` (`text | null`), `created_at`.
- **Zod Enum & Audience Contract (Flutter Parity):**
  - `type` strictly restricted to SQL `check_notif_type`: `'university' | 'class_cancel' | 'room_change' | 'test_reminder' | 'assignment' | 'exam'`.
  - `target_role`: `'all'` -> stored as `null`, or `'student' | 'teacher' | 'admin'`; optional `target_batch` & `target_section` (`""` normalized to `null` so `NotificationItem.matchesAudience` matches all batches/sections cleanly on Android & iOS).
- **Layout & Disclosures:**
  - Two views (`Compose Broadcast` sheet + `Sent History` tabular list with delete confirmation modal and upfront type counts).
  - **Freshness & Push Honesty:** Displays explicit notice that broadcast history updates on publish, tab focus, and manual `Refresh` (`public.notifications` is not in `supabase_realtime`, `F-25`), and surfaces a pre-send confirmation summary showing exact target audience scope (`All Students & Teachers` vs filtered batch/section) because production triggers `send-push` FCM notifications on insert (`F-20`, `F-29`).

### 8. `/admin/resources` — Academic Resources & Storage Library
- **Verified DB & Storage Contract (`public.resources` + bucket `resources`):**
  - Columns: `id` (`uuid PK`), `title` (`text not null`), `category` (`text not null`), `semester` (`integer not null`), `subject_code` (`text | null`), `drive_link` (`text | null`), `file_url` (`text | null`), `uploaded_by` (`uuid FK -> profiles.id`), `created_at`.
  - Categories matching Flutter `AppConstants.resourceCategories`: `'PYQ' | 'Notes' | 'Slides' | 'Assignments'`.
  - Semesters: `1..8` (`AppConstants.semesters`).
- **Upload & Validation Rules:**
  - Choice of **File Upload** (uploads binary to Storage bucket `resources` at `${semester}/${Date.now()}_${sanitizedName}` where `sanitizedName = filename.replace(/[^A-Za-z0-9._-]/g, "_")`, retrieving `getPublicUrl(path)` matching `ResourceService.uploadFile`) OR **External Drive Link** (`https://` Zod URL validation). Requires at least one of `file` or `drive_link`, never both conflictingly blank.
  - Optional checkbox (`Notify students in Semester N`) disabled by default; when checked, inserts a matching `'university'` notification row cleanly. Delete action removes the `public.resources` row (and attempts best-effort Storage object deletion when `file_url` points to bucket `resources`, surfacing partial errors honestly).

### 9. `/admin/profile` — Administrator Profile
- **Verified DB Contract (`public.profiles` own row `.eq("id", user.id)`):**
  - Displays read-only identity badge (`email`, `role = 'admin'`, `created_at`) plus editable personal metadata form (`name`, `department`, `designation`, `teacher_code`), `Reset Password` trigger link (`resetPasswordForEmail`), and `Sign Out` button.
  - **Explicit Exclusion (`F-30`):** Zero file upload inputs touching the `avatars` Storage bucket; renders clean initials monogram or verified OAuth `avatar_url` if already populated on `profiles`.

### 10. `/admin/timetable/courses` & `/admin/timetable/batches` — Staged Capability Gates
- Retained permanently as `staged-no-db` routes via [`CapabilityRegistry`](../../apps/web/src/core/capabilities/capabilityRegistry.ts).
- Renders calm explanation linking to [`AdminDashboardPage`](../../apps/web/src/features/admin/pages/AdminDashboardPage.tsx) and clarifying why Course & Batch/Cohort CRUD remains locked until canonical institutional catalog persistence (`cohorts`, `student_groups`, `timetable_courses` reconciliation) is promoted (`F-18`). Zero writable form controls or mock save buttons rendered.

---

## 5. Phase 2 Verification & Cross-Platform Compatibility Plan

Before Phase 2 exits (and prior to any hosted writes unless separately authorized on staging `oqwvxplteqtlrhktsplj`):

1. **Static & Bundle Checks:**
   - `npm --prefix apps/web run typecheck` (`tsc --noEmit`) — zero errors.
   - `npm --prefix apps/web run build` (`tsc -b && vite build`) — verifies Recharts + `react-is` + TanStack Table v9 + Virtual + `cmdk` bundle cleanly without Vite/Rollup peer failures.

2. **Vitest Unit & Contract Suite (`apps/web/tests/unit/`):**
   - **Zero Non-DB Keys Proof (`payloadContracts.test.ts`):** Validates `toRoomPayload()` and `toFacultyPayload()` against baseline `timetable_rooms` and `timetable_faculty` whitelists, proving none of Flutter's 11 non-DB keys (`classification`, `slot_matrix`, `declared_window_matrix`, etc.) can ever be emitted when targeting baseline Postgres.
   - **Settings & `ClockTime` Parity (`clockTimeSettings.test.ts`):** Validates `ClockTime.normalize` / `toHm` (`"1:50"` -> `"13:50"`, `"08:50:00"` -> `"08:50"`, `"1:50 PM"` -> `"13:50"`), monotonic period ordering rejection, `weeks_in_term` `1..52` bounds, and `friday_no_p4` + `blocked_periods["Friday"]` synchronization matching `lib/core/utils/clock_time.dart`.
   - **Broadcast & Resource Contracts (`commsContracts.test.ts`):** Asserts `notifications.type` matches exact SQL `check_notif_type` 6-value enum, audience empty-string normalization (`"" -> null`), and Storage object path formatting (`<semester>/<epoch>_<sanitized>`).
   - **Service Recovery & Error Propagation:** Simulates Supabase `400`/`403`/`500` errors on room save, faculty update, eligibility duplicate `(acronym, course_code)`, and `invite-admin` rejection, verifying UI enters recoverable error state and never displays fake success toasts.
   - **Tokens & Capability Suites Carried Over:** All existing Phase 1A WCAG AA sRGB contrast & Capability Registry assertions continue passing.

3. **Playwright E2E & Cross-Viewport Visual Verification (`1440×900`, `1024×768`, `390×844`):**
   - Route-level E2E coverage (using deterministic HTTP route interception when offline, or staging target only under separate Phase 2 live test authorization) across all 8 live screens + 2 `staged-no-db` routes exercising:
     - All **5 async states** (`loading`, `empty`, `filter-empty` + reset, `error` + retry, `staged-no-db`).
     - 55/45 inspector open/close (`X` / `Esc`), dirty-state warning bar & `Discard` / `Save Changes`.
     - Contextual multi-select bulk actions strip appearing only when `>= 1` rows selected.
     - `cmdk` searchable selector on Course Eligibility and `invite-admin` payload assertion verifying exact `redirect_to: "${origin}/"`.
     - Zero horizontal overflow (`scrollWidth <= innerWidth`) and zero console/page errors across desktop, tablet, and mobile viewports.

4. **Cross-Platform Flutter Mobile Interoperability Check (Gated Staging Only):**
   - Under explicit Phase 2 staging verification authorization against `oqwvxplteqtlrhktsplj`, confirm broadcasts (`public.notifications`) and uploaded PDFs/Drive resources (`public.resources`) authored from React Web deserialize cleanly in Flutter `NotificationItem.fromMap` / `Resource.fromMap` without crashing Android or iOS builds.

---

## 6. Owner Approval Checkpoint

Approval is requested for:
1. **Design Direction & Layouts:** Section 1 carry-over polish fixes, Section 3 shared patterns (55/45 inspector, sticky dirty bar, Recharts v3 bars, bulk actions), and Section 4 contracts for all 8 live + 2 staged screens.
2. **Phase 2 npm Package Delta:** Installing `@tanstack/react-table@^9.3.1`, `@tanstack/react-virtual@^3.14.26`, `recharts@^3.11.0`, `react-is@^19.3.1`, and `cmdk@^1.1.1` inside `apps/web/package.json`.

Execution of `npm install` and Phase 2 React implementation will begin **only after** explicit owner approval.
