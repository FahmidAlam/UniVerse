# Phase 2B Scheduling Workspace — Design Approval Package

**Status:** Proposal only — no Flutter, route, theme, database, or service implementation is authorized by this document.

**Decision requested:** Approve the proposed information architecture, web/mobile presentations, visual direction, and phased capability boundaries before any production UI work begins.

## 1. Product intent and guardrails

The Scheduling Workspace is one coherent administrative area for preparing a trustworthy scheduling input, configuring policy, checking readiness, and eventually reviewing a generated routine. It is not a second timetable engine, an editable copy of an XLSX file, or a dashboard of unconnected CRUD pages.

The accepted Course Distribution revision remains the authoritative input. The immutable source workbook, formula text, cached values, accepted corrections, effective values, policy revision, resource allocation, generation output, and validation outcome must remain distinguishable.

The proposal deliberately preserves the existing admin shell and legacy management pages while introducing one future workspace. Existing `Manage Faculty`, `Manage Rooms`, `Course Eligibility`, and `Timetable Settings` remain their present operational tools; they are not silently relabelled as revision-bound committee configuration.

### User and primary task

An authorized timetable administrator needs to answer four questions without losing academic provenance:

1. Which accepted distribution is the current input, and what source evidence or corrections define it?
2. Is the scheduling configuration complete, valid, and bound to that input revision?
3. What prevents a solve from starting, and which person can correct it?
4. Once the backend supports it, what generated result is safe to review, amend, and publish?

Academic correctness is more important than speed. A missing declaration, stale revision, denied permission, or unsupported backend feature must be explicit rather than represented as an empty success state.

## 2. Information architecture

The proposed top-level location is a single **Scheduling Workspace** entry in the existing admin desktop shell. The existing `Routine Management` entry remains available for legacy upload/generate history until its flows can be safely migrated.

```text
Admin shell
├── Dashboard
├── Routine Management                     existing; unchanged
├── Scheduling Workspace                   proposed Phase 2B location
│   ├── Distribution                       source evidence, corrections, impact
│   ├── Configuration                      version-bound future policy snapshot
│   ├── Readiness                          preflight and dependency report
│   ├── Generate                           future CP-SAT run control
│   └── Review & publish                   future result / validation / publication
├── Faculty / Rooms / Course eligibility   existing; unchanged
└── Timetable settings                     existing; unchanged
```

The workspace header always carries a compact **revision context bar**: selected scope, selected distribution revision, its accepted/effective status, revision version, and freshness. It is not a decorative status chip; it gives every pane its input boundary. If no usable revision is available, it names the missing prerequisite and does not imply a draft exists.

### Why this structure

- Distribution is evidence-oriented and table-first; its primary task is review and an audited correction, not generic record editing.
- Configuration is policy-oriented; its primary task is to make resolved defaults, overrides, and rule consequences inspectable.
- Readiness is an explanation layer, not a duplicate form. It links each incomplete item to the responsible configuration area.
- Generate and Review are operational layers that remain locked until the exact accepted-distribution, policy, engine, validation, and publication contracts exist.

## 3. Desktop design — primary experience

The desktop workspace uses a persistent local rail on wide viewports and a bounded content canvas. It favors stable columns, table scanning, and a contextual details panel over repeated cards.

```text
┌ Admin shell ─────────────────────────────────────────────────────────────────────────────┐
│ Scheduling Workspace                                      Help   [Scope selector]          │
├──────────────┬────────────────────────────────────────────────────────────────────────────┤
│ Distribution │  Scope: CSE / Fall 2026    Revision: Accepted #4 · v7        Fresh          │
│ Configuration├────────────────────────────────────────────────────────────────────────────┤
│ Readiness    │  Course Distribution                         Search  Filters  Columns      │
│ Generate     │  241 source rows · 18 corrections · 3 conflicts                              │
│ Review       ├───────────────────────────────────────┬────────────────────────────────────┤
│              │ Source record table                   │ Selected record / inspection        │
│              │ Row Batch Section Course  Teacher ... │ CSE-2201 · A + B · row 18           │
│              │ 18  2023  A+B     CSE-2201 MSA, ...   │ Original / effective comparison     │
│              │ 19  2023  A+B     CSE-2202 Pending   │ Formula and cached evidence         │
│              │ 20  2023  C       CSE-2201 ...       │ Impact preview                      │
│              │                                       │ Corrections / audit trail            │
│              └───────────────────────────────────────┴────────────────────────────────────┤
│              │ Sticky summary: 1 unresolved source conflict  ·  Last activity ...         │
└──────────────┴────────────────────────────────────────────────────────────────────────────┘
```

At 1440 px and above, the table and inspector are visible together. Around 1280–1024 px, the inspector becomes a resizable side sheet so the table keeps a viable minimum width. On tablet, the local rail collapses into a labeled navigation control; the table keeps horizontal scrolling with a sticky record identity column rather than dropping important academic values.

### 3.1 Distribution table

The source-record table uses actual Phase 2a column semantics, grouped under deliberate headings:

| Column group | Initial fields | Presentation rule |
|---|---|---|
| Identity | Source row, Batch (A), Section (B), Course Code (C), Course Title (D) | Row/source identity never changes visually when a correction is proposed. Joint `B+C` sections stay visible as one source value. |
| Academic input | Credit (E), Prerequisite (F), Conducting Department (G), Students (H), Teacher (I) | Unknown headcount displays `Unknown`, never `0` or unlimited. Pending teacher portions display as pending, not as an absent row. |
| Meeting evidence | Classes (J), Duration (K), Class/Week (L) | Formula text, cached value, and effective value are distinguishable; no control suggests Excel recalculation. |
| Integrity | Correction state, conflict state, affected output | Text plus icon/tooltip; color is never the only indicator. |

Filters are scoped to evidence the contract actually has: batch, section, conducting department, teacher/pending assignment, corrected/unmodified, conflict status, and source row. Sort affects inspection order only; it never changes workbook provenance. Grouping may group rows for inspection, but it never collapses joint sections or split-teacher source evidence into a mutable aggregate.

### 3.2 Record inspector

Selecting a source row opens a keyboard-accessible inspector with five fixed sections:

1. **Evidence:** original source cell value and row context for A–L.
2. **Effective value:** accepted correction overlay when present; otherwise explicit `Same as source`.
3. **Formula / cached value:** shown for J and L whenever supplied by the contract. A formula without a cached value is an unresolved input condition, not a value the client evaluates.
4. **Impact preview:** a read-only, deterministic explanation such as `room eligibility may change because Conducting Department changes` or `session count requires normalization`. Until the engine exposes an impact API, this section says `Impact calculation unavailable — engine integration required`; it never invents a result.
5. **Audit:** correction reason, actor, timestamp, prior evidence, revision version, and stale-write outcome when supplied.

An editable correction opens a focused panel, never an inline mutable table cell. It shows the original evidence, requires a reason, makes the expected revision version visible, and labels the action **Save audited correction**. The panel promises only the behavior of `append_course_distribution_correction`: one A–L source cell, authenticated `edit_draft` capability, accepted target revision, required provenance/reason, and optimistic-concurrency rejection. It does not offer revision creation, acceptance, rejection, or local-only save.

### 3.3 Configuration

Configuration is organized by scheduling decisions, not database tables. Each section displays its future revision binding and resolution chain (`Default → override → effective policy`) when those records exist.

```text
Configuration
├── Section calendar
│   ├── Weekend default and explicit section override          R1 / D1
│   └── Batch days-off range                                  R2
├── Faculty availability and workload
│   ├── Permanent attendance / 2-or-3-day off allocation      R7 / D3
│   ├── Adjunct distinct-course view                          R6 / D4
│   ├── External commitments and incoming availability        R4 / R5
│   └── Preferences and SUST compactness                      R8 / R9
├── Rooms and allocations
│   ├── ECL / Physics Lab calendars                            R10 / R11
│   └── Semester-specific general classroom allocation        R14
└── Time grid and course patterns
    ├── Six/seven slots, clocks, breaks                        R15
    ├── Sessional break-crossing permission                    R12 / D5
    └── Theory pattern visibility                               R13 / D2
```

Each group has an **effective-policy summary** before its controls. For example, a permanent faculty member’s screen distinguishes attendance days, selected off-days, teaching days, external busy intervals, and preferences; no empty teaching day is shown as an off-day. The sessional break-crossing control is off by default, scoped to its applicable pattern, and cannot imply permission for theory adjacency, section gaps, or SUST preferences.

During Phase 2B’s current backend state, this entire area is a clear capability boundary: it can show an explanatory empty/locked state, requirement identifiers, and expected policy snapshot fields, but it does not persist a local replacement for the future snapshot.

### 3.4 Readiness, generation, and review

Readiness lists actionable blockers by category: accepted distribution, source conflicts, missing external availability, unallocated room, unresolved policy decision, stale artifact, permission denial, or unavailable service. A row includes the requirement ID, affected entities, the reason it blocks, and a deep link to the relevant workspace pane when that pane exists.

The future generation screen has three stages: preflight, run, and outcome. It must show raw meaningful outcomes (`OPTIMAL`, `FEASIBLE`, `INFEASIBLE`, `UNKNOWN`, `TIME_LIMIT_EXHAUSTED`, `INPUT_ERROR`) through a human explanation. It never claims that `UNKNOWN` means timeout, that a time-limited candidate is publishable, or that a failed preference is a hard conflict.

The future review screen has filterable section/faculty/room grids, a conflict inspector, a revision comparison, and a publish action. Its publish action is unavailable until server-authoritative validation and atomic publication bind to the exact distribution/configuration/resource revisions.

## 4. Mobile design — independent presentation

Mobile retains the same domain controller and data contracts, but replaces the desktop table-plus-inspector composition.

```text
┌──────────────────────────────────────┐
│ Scheduling workspace             ⌄    │
│ CSE · Fall 2026 · Accepted #4         │
│ [Distribution] [Config] [Readiness]   │
│ Search source records                 │
│ Filter: Corrected · Pending teacher   │
├──────────────────────────────────────┤
│ CSE-2201                              │
│ 2023 · A + B · source row 18          │
│ MSA + pending portion                 │
│ Correction recorded · inspect         │
├──────────────────────────────────────┤
│ CSE-2202                              │
│ 2023 · A + B · source row 19          │
│ Missing teacher declaration           │
└──────────────────────────────────────┘
Record detail is a full-screen route (not a narrow modal table). It leads with record identity and integrity state, then presents collapsible Evidence, Effective value, Formula/cached evidence, Impact, and Audit sections. Editing opens a bottom sheet with a labeled value field, mandatory reason, and a fixed summary of the expected revision version; it keeps the form value on a recoverable network or stale-write error.

Configuration uses task-oriented lists, one policy group per route, with a persistent unsaved/pending capability state only when a real draft exists. Multi-column desktop forms become a sequence of labeled mobile forms and calendars. Readiness remains a prioritized list that opens the affected record or policy group. Dense generation and routine grids are not compressed into phone width; future mobile review uses a selected-section/day view and focused filters.

## 5. Interaction, states, and accessibility contract

| Situation | Required behavior |
|---|---|
| Initial load | Skeleton/table row placeholders only while a real request is pending; no synthetic sample schedule or correction data. |
| No distribution revision | Explain the missing accepted revision and the required backend/import path. No empty table presented as confirmation that no courses exist. |
| No results | Preserve active filters and offer one clear reset action. |
| Read-only capability | Explain why the user can inspect but cannot correct; do not hide the control without explanation. |
| Correction pending | Disable duplicate submission, retain input, and show honest progress. |
| Stale revision | Preserve the attempted value/reason, show the current revision-version conflict, and offer refresh/review; never overwrite. |
| Source conflict | Describe affected source rows/fields and prevent an ambiguous effective value from being presented as settled. |
| Backend unavailable | Distinguish service failure from empty data and permission denial; offer retry only when meaningful. |
| Future capability | Disabled action plus `Coming soon — requires [specific contract]`; no fake success path. |
| Destructive/final action | Explain consequence and revision scope, then require confirmation once a server operation exists. |

Pointer, keyboard, and motion behavior are consistent across platforms. Table rows and buttons have hover, focus, pressed, selected, disabled, loading, success, and error states as applicable. Enter/Space opens the focused record; Escape closes inspector/sheet and restores focus. Side-panel transitions are restrained (roughly 180–220 ms) and are removed/reduced when motion preference requires it. Large table rows do not animate during sort or filter.

Focus order follows the operational task: workspace navigation → revision context → filters → table/list → record inspector/actions. Statuses include a text label and semantic announcement; contrast and screen-reader behavior must be browser-tested later rather than claimed compliant from this proposal.

## 6. Visual system direction

The proposal retains UniVerse’s dark surfaces, Inter typography, orange primary action, and existing `AppColors`/`AppSpacing` foundation. It recommends refinement, not a brand replacement:

| Element | Proposal | Rationale |
|---|---|---|
| Workspace hierarchy | Primary background, one elevated workspace surface, sparse dividers, and a stable table header | Supports dense scanning without card nesting. |
| Orange accent | Reserve for primary actions, active navigation, keyboard focus, and exceptional attention | Keeps the established accent meaningful. |
| Integrity states | Semantic success/warning/error/info treatments with icon and text | Separates academic state from decoration and avoids color-only status. |
| Typography | Existing Inter scale; strengthen table header/record identity distinction before adding new display styles | The task needs legible evidence more than promotional hierarchy. |
| Shape and elevation | Existing moderate radii; no gradients, glass, decorative charts, or repeated pill surfaces | Maintains a calm academic tool rather than a generic dashboard. |
| Motion | Short panel/menu feedback only; no animated table data or false progress | Preserves spatial context without implying authoritative changes. |

No token changes are proposed for implementation in this stage. The future implementation should first validate contrast and current component behavior across existing student, teacher, and admin screens before centralizing any approved token adjustment.

## 7. Backend-readiness matrix

| Capability | Classification | Actual present contract / boundary | Proposed user-facing state |
|---|---|---|---|
| Inspect source/revision/corrections | Already supported in Phase 2a schema/RLS, subject to deployment and scoped `read_catalog` capability | `course_distribution_*` reads and `read_course_distribution_revision(revision_id)` return immutable bytes/hash, revision metadata, and correction overlays | Load real revision when the client integration exists; otherwise explicit unavailable state. |
| Append one audited correction | Supported through audited correction operation | `append_course_distribution_correction` requires accepted revision, expected version, A–L cell provenance, evidence, effective value, reason, auth, and `edit_draft` capability | The only live Phase 2B editing action proposed once client wiring exists. |
| Create/import a source and initial revision | Requires new backend API or integrated import boundary | No client API/flow is present in the current contract | Locked: `A distribution import contract is required`. |
| Create, accept, reject, supersede revision | Requires new backend API/schema behavior | Current schema has statuses but no authorized client mutation contract for lifecycle management | Locked: `Revision workflow API is required`. |
| Deterministic source-row impact preview | Requires engine integration API | Python normalization exists, but client has no impact/preview endpoint and must not normalize independently | `Impact calculation unavailable — engine integration required`. |
| Revision-bound policy configuration | Requires new backend schema/API and policy snapshot integration | Legacy timetable settings/faculty/rooms are mutable and not a valid substitute | Locked configuration groups with concrete required snapshot fields. |
| External availability, lab calendars, semester room allocation | Requires later policy/resource contracts | Current capability is partial legacy static config only | Planned configuration design, no simulated storage. |
| CP-SAT preflight/run/progress/diagnostics | Planned for later integration | Current engine path ingests legacy bytes/config and does not consume the canonical accepted revision/policy snapshot end-to-end | Locked Generate tab with defined future states. |
| Generation review, manual adjustment, atomic publication | Planned for Phase 3/5 integration | Server-authoritative shared validation and revision-bound publication are not available | Locked Review & publish tab. |
| Existing faculty/room/eligibility/settings management | Already supported by existing legacy screens | These services are separate, mutable operational tools | Remain linked/referenceable, never shown as revision-bound configuration. |

**Verification note:** the current master plan’s Phase 2a status text records secondary-project verification, while the active project instruction supplied for this work says the SQL files have not yet been verified against the target Supabase project. This design therefore treats deployment availability as unknown and never presents database-backed capabilities as live until the connected environment is verified.

## 8. Proposed architecture when implementation is authorized

No production files are changed by this proposal. The intended implementation boundary is:

```text
Shared domain/controller state
  ├── Distribution revision reader + audited correction command
  ├── Capability/readiness model (derived only from real contracts)
  └── Workspace navigation and selected revision context

Web presentation                         Mobile presentation
  ├── dense source-record table           ├── filterable record list
  ├── side inspector                      ├── full-screen record detail
  ├── contextual configuration panels     └── focused policy routes/sheets
  └── operational review grid             └── selected section/day review
```

It follows the existing feature-first Flutter structure and `ChangeNotifier`/`SafeChangeNotifier` conventions. Web and mobile may use separate presentation widgets where the information architecture differs, while sharing models, validation display rules, services, controller state, token layer, and capability classification. No client-side normalization, mock repository, feature-flag system, or parallel theme system is proposed.

## 9. Incremental implementation sequence and risk controls

1. **Backend contract reconciliation:** settle target-project deployment evidence, revision lifecycle/import API, and one engine-side accepted-revision normalization boundary. Risk: a table that edits only a local view; control: no editable UI before its end-to-end contract is testable.
2. **Distribution vertical slice:** route/context, real revision reader, web table/mobile list, inspector, and audited correction operation with stale/denied/error states. Risk: formula/cache or split-teacher evidence loss; control: source-row inspection and original/effective separation.
3. **Revision-bound configuration contract:** schema/API/policy snapshot followed by section calendar, faculty availability, resource, and time-grid controls. Risk: legacy mutable state becoming a second truth; control: accepted snapshot is the only input wired to generation.
4. **Readiness and normalization integration:** deterministic preflight and impact explanations, with structured unavailable/invalid/stale outcomes. Risk: client claims a solver result; control: engine/server owns calculation and validation.
5. **Generation, review, and publication:** only after shared validation, diagnostics, draft persistence, and atomic publication are implemented. Risk: publishing a stale/invalid result; control: server rejects mismatched revisions and invalid validation state.

Known unresolved academic decisions—three-credit count/spread, one-course adjunct treatment, exact weekend default/counting basis, formula/contact-hour conflicts, reviewed course aliases, and some policy strictness—remain visibly unresolved. The future workspace may describe them, but it must not convert them into defaults or active solver controls without the relevant committee decision.

## 10. Approval scope

Approval of this package authorizes the next planning step only: a file-level implementation plan for the first safe vertical slice. It does **not** authorize production Flutter UI, routes, theme changes, backend/schema changes, Supabase deployment, or alteration of existing screens.

The first proposed implementation slice, after a separate plan approval, is the real-data Course Distribution reader and audited-correction flow; configuration, generation, and publication remain intentionally excluded until their backend contracts are approved.

## 11. Approval and first-slice record — 7 November 2026

The central direction was approved for implementation. The first safe foundation is now present: a dedicated Scheduling Workspace route in the existing admin shell, revision context, nested workspace tabs, and honest locked capability states. It deliberately contains no local workbook cache, sample distribution data, correction simulation, configuration persistence, generation, or publication behavior.

Read-only inspection of the Flutter app's configured `UniVerse` Supabase project found that the Phase 2a distribution tables and `read_course_distribution_revision` / `append_course_distribution_correction` RPCs are not installed there. The actual Course Distribution reader and audited-correction UI therefore remain blocked until that project has the verified contract; the workspace reports this truthfully rather than using legacy settings or fabricated data.

The Distribution tab now checks availability at runtime through a read-only accepted-revision query. It presents a transient checking state, then distinguishes an unavailable contract from an installed contract with no accepted revision. An installed revision remains locked until the source-record reader can parse and display its A-L evidence through a reviewed, authoritative boundary.

The broader administrative migration remains incremental: preserve current Routine Management, Faculty, Rooms, Course Eligibility, and Timetable Settings while first adding the accepted-distribution vertical slice; add revision-bound configuration only with its snapshot contract; then add readiness, CP-SAT operations, review, and publication only with shared server validation. No legacy mutable management screen becomes a competing scheduling truth.
