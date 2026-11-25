# UniVerse React Web v1 — Phase 2A Fixes & Sub-Phase 2B Completion Report

## 1. Scope Summary

Executed all **5 targeted Phase 2A fixes** and implemented all **4 remaining Sub-Phase 2B live screens** strictly inside `apps/web/` (plus targeted architecture doc sync in `docs/architecture/`):

### Part 1 — Phase 2A Visual & Domain Fixes
1. **Decoupled R15 Regular Daily Slots (`6-Slot` vs. `7-Slot` On-Campus) from Separate Online Slot:**
   - Verified `engine/config.json`, `engine/solver.py` (`excluded |= online` when `!allow_online_periods`), and `engine/render.py` (`col` uniqueness) before updating `settingsService.ts` and `TimetableSettingsPage.tsx`.
   - `6-Slot Grid` | `7-Slot Grid` switches regular on-campus slots (`P1–P6` cols `D..J` vs `P1–P7` cols `D..K`, defaulting to 7 regular `On-Campus` slots) without mutating `allow_online_periods` or turning `P7` into an online slot.
   - Added separate **Optional Online Slot Allocation** card (`idx: 8`, `Col L`, default `19:00–20:20`, badged `Online Slot`) managed via `setOnlineSlotEnabled()`.
   - Updated public landing specimen (`AcademicLedgerPreview.tsx`, `routineFixtures.ts`) and synced [`WEB_PHASE_1A_DESIGN_BRIEF.md`](../architecture/WEB_PHASE_1A_DESIGN_BRIEF.md) §3 & [`WEB_PHASE_2_DESIGN_BRIEF.md`](../architecture/WEB_PHASE_2_DESIGN_BRIEF.md) §4.5.
2. **Official R1–R15 Policy Ledger (`TimetableSettingsPage.tsx` Tab 2):**
   - Replaced inaccurate summaries with exact official `R1–R15` Leading University CSE Routine Committee rules grouped under institutional pillars.
3. **Non-Occluding `StickyDirtyBar` (`StickyDirtyBar.tsx` + `TimetableSettingsPage.tsx`):**
   - Added `docked` placement on `TimetableSettingsPage` plus top-right unsaved action bar beside Settings tabs so `P5`/`P6` rows and `External Service Course Handling` are never occluded.
4. **Unclipped `240px` Sidebar (`AdminShell.tsx` + `capabilityRegistry.ts`):**
   - Retained `w-[240px]` desktop rail, shortened sidebar label to `Workbench` (`[LOCKED]`) with Radix `<Tooltip>` showing `"5-Stage Scheduling Workbench"`, and normalized `Shrink-0` pill sizing.
5. **Visual & Contract Polish:**
   - Widened `Batch to Semester Map` key input (`min-w-[160px] w-[184px]`, placeholder `"e.g. Batch 60"`).
   - Made empty-baseline dashboard alert in `AdminDashboardPage.tsx` dynamically list only zero-count stages.
   - Aligned header bar title `"Timetable Settings"` (`capabilityRegistry.ts`) and verified Playwright intercepts root `GET /` on FastAPI (`engineHealth.ts`).

### Part 2 — Sub-Phase 2B Live Admin Screens (`apps/web/src/App.tsx`)
1. **`/admin/users` (`ManageUsersPage.tsx` + `usersService.ts`):**
   - Directory (`public.profiles`) with role filters (`All`, `Admins`, `Teachers`, `Students`), `/` search, hover copy, `55/45` role inspector with confirmation modal on admin escalation, and hard-blocked administrator self-demotion.
   - Whitelists & Invites (`public.whitelists` + Edge Function `invite-admin`) with `upsert(..., { onConflict: "email" })` and `Invite Administrator` modal sending `{ email, name, redirect_to: "${origin}/" }` and parsing 400/401/403/404 Edge Function errors honestly.
2. **`/admin/broadcast` (`CampusBroadcastPage.tsx` + `broadcastService.ts`):**
   - Verified `public.notifications` author column `sent_by` and 6-value SQL `check_notif_type` enum (`university`, `class_cancel`, `room_change`, `test_reminder`, `assignment`, `exam`).
   - Normalizes `"all"` / `""` -> `null` for Flutter Android & iOS `NotificationItem.matchesAudience` parity, shows pre-send audience confirmation dialog, manual `Refresh` + `Last checked` timestamp (`F-25`), and Sent History deletion.
3. **`/admin/resources` (`ManageResourcesPage.tsx` + `resourcesService.ts`):**
   - Supports Storage bucket `resources` file upload (`${semester}/${epochMs}_${sanitized}`, matching Flutter `ResourceService.uploadFile`) or validated `https://` Drive links, optional unchecked-by-default `"Notify students in Semester N"` broadcast trigger with partial-failure recovery, and delete cleanup.
4. **`/admin/profile` (`AdminProfilePage.tsx` + `profileService.ts`):**
   - Read-only institutional identity badge, editable own metadata (`name`, `department`, `designation`, `teacher_code`), `Reset Password` trigger (`resetPasswordForEmail`), and `Sign Out`, strictly free of any `avatars` Storage uploads (`F-30`).

## 2. Verification Results

- **TypeScript (`npm --prefix apps/web run typecheck`):** Passed (`0` errors).
- **Vitest (`npm --prefix apps/web test`):** Passed — `9` test files, `67` tests passed (including `clockTimeSettings.test.ts` decoupling tests, `commsContracts.test.ts`, and `usersProfileContracts.test.ts`).
- **Production Build (`npm --prefix apps/web run build`):** `tsc -b && vite build` passed (`0` errors).
- **Playwright E2E (`npm --prefix apps/web run test:e2e`):** Passed — `8` of `8` tests passed across `phase1a.spec.ts` (`4`), `phase2a.spec.ts` (`2`), and `phase2b.spec.ts` (`2`) across `1440×900`, `1024×768`, and `390×844` with zero horizontal overflow and zero console/page errors. Screenshots saved and inspected in `docs/screenshots/web_phase_2b/`.
- **Scope Boundary (`git status --short`):** Zero edits to `lib/`, `android/`, `ios/`, `test/`, `engine/`, `supabase/`, or `apps/web/.env.local`.
