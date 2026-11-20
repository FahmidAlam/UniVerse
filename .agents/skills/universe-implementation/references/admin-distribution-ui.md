# Role 2 — Course Distribution & Configuration UI

## Scope

- Phase 2b editable Course Distribution workspace (`CD1`) built atop the Phase 2a data contract (`engine/distribution.py` and `supabase/migrations/20261106130000_course_distribution_contract.sql`).
- Source vs. effective value inspection across columns `A`–`L`, including formula + cached-value visibility for `J` (`No. of Classes`) and `L` (`Class/Week`), merged-row conflict highlighting, split/co-teacher visibility, and `B+C` joint-section grouping.
- Typed committee configuration workspace covering section weekends (`R1`/`D1`), batch fairness (`R2`), faculty attendance vs. off-days (`R6`/`R7`, `D3`/`D4`), external commitments (`R4`/`R5`), lab windows (`R10`/`R11`), room allocations (`R14`), and 6/7-slot period grids (`R12`/`R13`/`R15`, `D2`).

## Guardrails

- **Mandatory UI/UX Approval Gate:** Do **not** write Phase 2b or Phase 5 UI code until a grounded design brief with layout/interaction alternatives and trade-offs has been presented to the user and explicitly approved (Master Plan §0.2).
- **UI/UX Skills Reference:** Before designing or implementing Phase 2b screens, load the relevant UI/UX skills per [`AGENTS.md`](../../../../AGENTS.md) / [`CLAUDE.md`](../../../../CLAUDE.md): [`flutter-web-responsive-ui`](../../flutter-web-responsive-ui/SKILL.md) + [`universe-visual-design-system`](../../universe-visual-design-system/SKILL.md) for web screens/tables, [`universe-ux-principles`](../../universe-ux-principles/SKILL.md) for workflow/journey design, and [`accessibility-performance`](../../accessibility-performance/SKILL.md) for keyboard navigation/dense grid performance. Follow the 11-step UI/UX workflow.
- Never mutate original workbook bytes; edits create versioned corrections with author, timestamp, and reason against an expected revision version.
- Derived fields (offering IDs, normalized session counts, grouped teacher lists) are computed deterministically from the accepted revision, never hand-edited as competing truth.
- Consult [`18-committee-decisions-and-policy-baseline-2026-11-04.md`](../../../../docs/timetable-audit-2026-10-20/18-committee-decisions-and-policy-baseline-2026-11-04.md) for detailed `CD1` column semantics.


## R1–R16 Committee Scheduling Rules & Supporting Modules UI/UX Standard (Phase 5/6 Alignment)

When designing or implementing administrative configuration screens (`ManageRoomsScreen`, `ManageFacultyScreen`, `ManageCourseEligibilityScreen`, `TimetableSettingsScreen`), the `SchedulingWorkspaceScreen` panes (`SchedulingConfigurationPane`, `SchedulingReadinessPane`, `DistributionRecordInspector`), or supporting campus modules (`RoomsScreen`, `FindTeacherScreen`, `ResourcesScreen`, `NotificationsScreen`, `CampusBroadcastScreen`), enforce these mandatory rules:

### 1. Complete UI Configurability of All 16 Committee Rules (R16 Mandate)
Never hardcode scheduling assumptions invisibly. Expose structured, human-readable controls for all 16 rules across Live Admin Configuration (`/admin/timetable/*`) and the Scheduling Workbench (`/admin/scheduling`):
- **R1 & R2 (Section Calendar & Batch Parity):** 2 consecutive weekend days off per section (R1); equal weekly days off across sections of the same batch with max ±1 day variance (R2).
- **R3 (Section Compactness):** Zero 2-slot consecutive gaps for any section; 1-slot gap + scheduled break permitted.
- **R4 & R5 (Cross-Department Faculty Windows):** CSE faculty external-department teaching slot blocker (R4); External/Guest faculty (GED, EEE, Physics, English) strict available day/slot window matrix (R5).
- **R6 & R7 (Faculty Category & Off-Day Bounds):** Explicit `Permanent` vs. `Adjunct` category badge. Adjunct workload band: 2 courses -> 2 days, 3 courses -> 3–4 days, >=4 courses -> 4–5 days (R6). Permanent faculty: 4–5 working days, strictly 2–3 weekly days off (R7).
- **R8 & R9 (Faculty Slot Preferences & SUST Adjunct Compactness):** Priority day/time slot preference matrix (R8); SUST Adjunct mode enforcing compact single-half-day scheduling (all before break OR all after break) and max daily gap <= 2 consecutive slots (R9).
- **R10, R11 & R14 (Dynamic Room Pools & Shared Lab Windows):** Semester active-pool toggle for general theory classrooms (R14); explicit shared-lab availability matrices for the two EEE-owned `ECL` labs (R10) and exclusive `Physics Lab` course-code binding + conflict window blocking (R11).
- **R12 & R13 (Sessional & 1–2 Credit Theory Distribution):** Sessionals: 1 or 1.5 credits -> 2 classes/week; 2 credits -> 3 classes/week with preferred 2-slot consecutive same-lab placement (R12). 1–2 credit CSE theory courses -> completed in 1 day across 2 consecutive slots in the same classroom (R13).
- **R15 (Flexible 6-Slot vs. 7-Slot Daily Grid):** First-class `USegmentedControl<int>` switching between 6-slot and 7-slot daily period configurations with live period-header preview.

### 2. Visual & Structural Execution Laws (Video Research Synthesis)
- **"Walmart Receipt" Dissolved Cards:** Group R1–R16 settings and CRUD lists inside top-lit `UCard(isTopLit: true)` containers separated by 1px `AppColors.border` horizontal lines. Never nest 4-sided cards inside cards.
- **"Checkbox Off = Gray" Signaling:** Standard committee baseline rules (R1–R15 in default state) use calm slate-gray badges (`DEFAULT BASELINE`). Reserve `AppColors.warning` (Amber) for overridden rules/soft preferences, `AppColors.error` (Crimson) for hard R4/R5/R7/R10/R11 availability conflicts, and `AppColors.primary` (Orange) / `AppColors.info` (Cyan) for active selection.
- **Show, Don't Tell (Interactive Slot Mini-Grids):** Represent R4/R5/R8 faculty time windows and R10/R11 ECL/Physics lab availability using interactive compact `Day × Slot` pill grids (6 or 7 slots per R15) rather than raw text strings.
- **Usable-Width Master-Detail Architecture:** Evaluate all layouts via `LayoutBuilder` post-sidebar usable width:
  - `>= 900px` usable width: 55/45 or 60/40 Master-Detail split (`UMasterDetailWorkspace`) with docked right-hand inspector and URL query parameter sync (`?room=`, `?teacher=`, `?faculty=`, `?rule=`).
  - `< 900px` usable width: Single-axis list/grid with `showUAdaptiveModal` (centered top-lit modal `>= 768px`, single-handle bottom sheet `< 768px`).