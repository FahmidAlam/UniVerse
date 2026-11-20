---
name: ui-backend-policy-correlation
description: Enforces strict 1:1 correlation between Flutter UI/UX controls, Supabase/FastAPI backend contracts, and Routine Committee policies (R1-R16, D1-D6, CD1). Prevents fabricated UI matrices, dead controls, and visual redesign drift.
---

# UI/UX & Backend Policy Correlation Skill

## 1. Core Mandate (Zero Fabrication Policy)
1. **No Redesign Drift:** The Obsidian Orbit design system (`AppColors`, `AppSpacing`, `AppTextStyles`, `AppMotion`, `AppTheme.dark`) and Phase 0–5 responsive layouts (usable-width `LayoutBuilder` tiers, dissolved `UCard` containers, "Checkbox Off = Gray" signaling) are LOCKED. Never alter visual themes or layout shells unless fixing an explicit overflow or wiring a backend-bound control.
2. **Zero Unbacked UI Matrices:** Never invent, render, or mock a UI matrix, chart, toggle, or input field that does not map 1:1 to:
   - An existing or planned column/RPC in Supabase (`supabase/migrations/`),
   - A parameter in `GenerationProfile` / `engine/domain.py` / `engine/solver.py` / `engine/distribution.py`, OR
   - An explicit Routine Committee requirement (`Routine Generation System.docx`, `18-committee-decisions-and-policy-baseline-2026-11-04.md`, `16-committee-traceability-2026-11-04.md`).
3. **progressive Disclosure ("Invisible UI" Until Needed):** Following senior UX density principles, conditional backend attributes must not clutter primary tables. Reveal dependent fields contextually (e.g., showing `External Institution: SUST | Others` only when `Faculty Category == Adjunct`, or tucking secondary metadata into docked inspectors/adaptive modals).

## 2. Mandatory Pre-Implementation Correlation Check
Before adding or modifying any widget in `lib/features/admin/`, `lib/features/teacher/`, or `lib/features/routine/`, the agent MUST verify and document:
- **UI Control & Screen:** Exact widget and file path.
- **Model & State Owner:** Exact Dart model field (`lib/core/models/` or `lib/features/admin/scheduling/models/`) and `SafeChangeNotifier` controller method.
- **Backend / Solver Target:** Exact Supabase table column / RPC or Python FastAPI / CP-SAT payload key (`generation_profile.dart` -> `engine/solver.py`).
- **Operational Boundary:** Whether the control is **Live-Wired** (mutates Supabase/FastAPI now) or **Contract-Staged** (bound to typed Dart models & `SchedulingWorkspaceGateway` awaiting production SQL migration).

## 3. Routine Committee Policy-to-UI Architecture Rules

### A. Faculty Classification & Priority Windowing (`ManageFacultyScreen` & `SchedulingConfigurationPane`)
- **Employment Category (`employment_type`):** Explicit segmented/chip selector: `Permanent` vs. `Adjunct` (Visiting/Part-time).
- **External Institution Provenance (`external_institution`):** Conditional selector revealed ONLY when `Adjunct` is selected (or optional provenance tag): `SUST` | `Others` (with optional custom institution code/note).
- **Scheduling Impact:** Adjunct/External faculty (especially `SUST`) require strict preferred day/slot windowing and off-day hard constraints in the solver, whereas Permanent faculty follow standard departmental load distribution and compactness rules.
- **Designation & Max Load:** Explicit binding to `designation` (Professor, Associate Prof, Assistant Prof, Lecturer) which auto-suggests baseline weekly credit/slot limits while allowing audited admin overrides.

### B. Course Eligibility & Assignment Matrix (`ManageCourseEligibilityScreen`)
- **No Confusing Unbacked Grids:** Do not render unconstrained N×M visual matrices that cannot be serialized. Use filterable, cohort/semester-scoped assignment rows or cards where each course binds to qualified Teacher Codes with explicit priority/eligibility tiers (`Primary`, `Secondary`, `Lab-Co-Teacher`).

### C. Course Distribution & Provenance (`SchedulingWorkspaceScreen` — Stage 1)
- **Cols A–L Contract Fidelity:** Every column and inspector field must map strictly to `engine/distribution.py` (`SourceWorkbook`, `CellCorrection`, `CorrectionRevision`):
  - Cohort identity (`Batch`, `Section`, `Combined/Joint Section` e.g., `B+C`).
  - Split-teacher allocation (Theory Teacher vs. Lab Teacher 1 / Lab Teacher 2).
  - Formula vs. Cached value discrepancy inspection (Cols J & L).

### D. Solver Constraints & Shift Rules (`TimetableSettingsScreen` & Stage 2 Configuration)
- **R1–R16 & D1–D6 Traceability:** Every slider, switch, or time-window input must map to real solver parameters:
  - Daily Shift Windows, Friday/Jummah break rules, Lunch break windows.
  - Theory daily cap, consecutive slot limits, Sessional/Lab continuity (must not cross breaks illegally), and Room suitability pools (Theory Hall vs. Specialized CSE Lab).
  - Keep untouched baseline rules in calm slate-gray (`AppColors.bgElevated`); highlight only active overrides in Amber (`AppColors.warning`).

## 4. Verification Protocol
1. Run `flutter analyze --no-pub` (Must be 0 errors, 0 warnings).
2. Verify all model serialization (`toJson` / `fromJson` / `copyWith`) matches the backend contract.
3. Run targeted widget tests (`flutter test`) to ensure zero `RenderFlex` overflows across `390px`, `1024px`, and `1440px`.