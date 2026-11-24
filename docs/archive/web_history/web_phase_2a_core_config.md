# UniVerse React Web v1 — Sub-Phase 2A Implementation Report

## 1. Scope Summary

Sub-Phase 2A implemented the first half of `docs/architecture/WEB_PHASE_2_DESIGN_BRIEF.md` strictly inside `apps/web/` (plus targeted documentation deduplication/sync):

1. **Doc Deduplication & Brief Sync:**
   - Removed duplicate `docs/architecture/web-separation/WEB_IMPLEMENTATION_ROADMAP.md`.
   - Synchronized `docs/architecture/WEB_PHASE_2_DESIGN_BRIEF.md` with the 4 owner-approved Sub-Phase 2A adjustments (1B `409` race fix, removal of non-DB `Permanent` faculty filter chip, `.upsert({ id: 1 }, { onConflict: "id" })` singleton persistence, and strict 8-column PostgreSQL binding on `timetable_rooms` and `timetable_faculty`).
2. **Sub-Phase 1B Auth `409 Conflict` Fix (`apps/web/src/features/auth/AuthProvider.tsx`):**
   - Added `inFlightGateRef` per-`user.id` promise deduplication so concurrent `INITIAL_SESSION` and `SIGNED_IN` events share a single `resolveAdminGate` execution.
   - Added PostgreSQL `23505` / HTTP `409` `isDuplicateProfileError` fallback re-selecting `public.profiles` (`id = user.id`).
3. **Phase 1A Visual Polish Carry-Overs:**
   - Loaded `Source Serif 4` weight `700` (`apps/web/index.html`).
   - Restored `w-[240px]` desktop rail width, added `CaretDown` beside admin monogram, removed `READ-ONLY` sidebar badge so pills appear strictly for `LOCKED` and `STAGED`, and wired `CommandPalette` (`Ctrl+K`/`Cmd+K`) trigger in `apps/web/src/features/admin/AdminShell.tsx`.
   - Removed `.row-reveal-action` hiding from primary readiness CTA buttons on `apps/web/src/features/admin/pages/AdminDashboardPage.tsx`.
   - Reclassified `admin.profile` to `"live-persisted"` and relabeled `track1.workbook-upload` to `"Rendered Routine Upload"` (`badgeLabel: "Gated · Phase 3B"`) in `apps/web/src/core/capabilities/capabilityRegistry.ts`.
   - Updated `apps/web/src/shared/components/EngineHealthBadge.tsx` to display `"Engine · Preview"` in dev preview.
   - Updated `apps/web/src/features/auth/PublicAuthLayout.tsx` (`"Back to Home"`), removed `"01 —"` eyebrows on `LandingPage.tsx` and `PublicAuthLayout.tsx`, and defaulted mobile `< 768px` specimen view to `"list"` with right-edge CSS mask fade (`specimenStore.ts` / `AcademicLedgerPreview.tsx`).
4. **Packages Installed (`apps/web/package.json` & `package-lock.json`):**
   - `@tanstack/react-table@^9.3.1`, `@tanstack/react-virtual@^3.14.26`, `recharts@^3.11.0`, `react-is@^19.3.1`, `cmdk@^1.1.1`.
5. **Shared Phase 2 Primitives (`apps/web/src/`):**
   - `components/ui/DataLedgerTable.tsx` (TanStack Table v9 `tableFeatures`/`useTable`, TanStack Virtual virtualization, `HoverCopyButton`, `.row-reveal-action`, and contextual `bulk-action-bar`).
   - `components/ui/MasterDetailShell.tsx` (`55/45` desktop split `>= 1024px`, Radix `Dialog` `< 1024px`).
   - `components/ui/CommandCombobox.tsx`, `components/ui/CommandPalette.tsx`, `components/ui/ConfirmDialog.tsx`, `components/ui/StickyDirtyBar.tsx`, `components/ui/AsyncStates.tsx`.
   - `core/utils/clockTime.ts` & `core/hooks/useWorkspaceShortcuts.ts`.
6. **Dashboard Charts & 4 Live Configuration Workspaces (`apps/web/src/App.tsx`):**
   - `/admin/dashboard`: Backend-derived Recharts v3 BarCharts (Weekly Published Slot Load by Batch & Configured Room Inventory Breakdown) with flat bar tops (`radius={[0, 0, 0, 0]}`), synchronous render (`isAnimationActive={false}`), sibling-bar hover dimming, and empty states.
   - `/admin/timetable/rooms`: Live CRUD strictly pinned to 8 baseline `timetable_rooms` columns (`ManageRoomsPage.tsx`, `roomsService.ts`).
   - `/admin/timetable/faculty`: Live CRUD strictly pinned to 8 baseline `timetable_faculty` columns with R7 `2..3` off-day advisory (`ManageFacultyPage.tsx`, `facultyService.ts`). No non-DB `Permanent` filter chip.
   - `/admin/timetable/course-eligibility`: Live CRUD & bulk status toggle over `timetable_course_eligibility` (`ManageCourseEligibilityPage.tsx`, `eligibilityService.ts`) with dynamic course code union and `CommandCombobox`.
   - `/admin/timetable/settings`: 3-tab Phase B3 studio bound to singleton `timetable_settings` (`id = 1`) via `.upsert(..., { onConflict: "id" })`, `ClockTime` validation (`D, E, F, H, I, J, K` col alignment), synchronized `friday_no_p4` <-> `blocked_periods.Friday`, `service_scope` (`resource_only` vs `ignore`), `semester_map`, `excluded_periods`, and weight presets (`TimetableSettingsPage.tsx`, `settingsService.ts`).
   - Remaining Sub-Phase 2B routes (`/admin/users`, `/admin/broadcast`, `/admin/resources`, `/admin/profile`) and `staged-no-db` routes (`/admin/timetable/courses`, `/admin/timetable/batches`) stay cleanly mapped to `AdminRouteStubPage`.

## 2. Verification Results

- **TypeScript (`npm --prefix apps/web run typecheck`):** Passed (`0` errors).
- **Vitest (`npm --prefix apps/web test`):** Passed — `7` test files, `59` tests passed (`tokensContrast.test.ts` 30, `capabilityRegistry.test.ts` 5, `configServiceRecovery.test.ts` 1, `payloadContracts.test.ts` 3, `clockTimeSettings.test.ts` 5, `authHardening.test.tsx` 10 including concurrent `409`/`23505` recovery test, `adminDashboard.test.tsx` 5).
- **Production Build (`npm --prefix apps/web run build`):** `tsc -b && vite build` passed (`0` TypeScript errors, `dist/` built cleanly).
- **Playwright E2E (`npm --prefix apps/web run test:e2e`):** Passed — `6` of `6` tests passed (`phase1a.spec.ts` 4 tests, `phase2a.spec.ts` 2 tests) using isolated empty Supabase env overrides (`VITE_SUPABASE_URL: ""`, `VITE_SUPABASE_ANON_KEY: ""` in `playwright.config.ts`) and mocked Render `/health` responses across `1440×900`, `1024×768`, and `390×844` viewports, with screenshots saved to `docs/screenshots/web_phase_2a/`.
- **Boundary Integrity (`git status --short`):** Zero modifications to `lib/`, `android/`, `ios/`, `test/`, `engine/`, `supabase/`, or `apps/web/.env.local`.
