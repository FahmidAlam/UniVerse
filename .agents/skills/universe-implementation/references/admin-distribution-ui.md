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
