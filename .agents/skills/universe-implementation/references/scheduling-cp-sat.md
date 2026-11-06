# Role 3 — Scheduling & CP-SAT Engine

## Scope

- Phase 2a deterministic normalization (`engine/distribution.py`, `engine/domain.py`, `engine/ingest.py`) from immutable source workbooks + accepted correction revisions.
- Phase 4 CP-SAT modeling (`engine/solver.py`, `engine/validator.py`, `engine/config_schema.py`) for committee requirements `R1`–`R16` and approved decisions `D1`–`D6`.
- Solver status classification (`OPTIMAL`, `FEASIBLE`, `INFEASIBLE`, `UNKNOWN`, `TIME_LIMIT_EXHAUSTED`, `INPUT_ERROR`) and structured conflict diagnostics.

## Guardrails

- Retain Google OR-Tools CP-SAT. Express mandatory committee rules as hard constraints and preferences (`R8`, `R9` break-side preference, `R12` lab consecutiveness preference) as tiered soft objectives.
- Never silently drop or relax a mandatory academic constraint to manufacture feasibility.
- Preserve key semantics from [`18-committee-decisions-and-policy-baseline-2026-11-04.md`](../../../../docs/timetable-audit-2026-10-20/18-committee-decisions-and-policy-baseline-2026-11-04.md) and [`16-committee-traceability-2026-11-04.md`](../../../../docs/timetable-audit-2026-10-20/16-committee-traceability-2026-11-04.md):
  - `D1`: Section consecutive 2-day weekends are independent of faculty off-days; batch days-off spread ≤ 1 (`R1`, `R2`).
  - `D2`: Theory 1/1.5/2-credit courses require 2 consecutive same-day, same-room slots (`R13`); sessional break-crossing requires explicit scoped permission (`R12`).
  - `D3`: Permanent faculty non-off days are attendance days, not mandatory daily teaching constraints (`R7`).
  - `D4`: Adjunct day spans count distinct courses across sections (`R6`); undeclared external faculty have zero availability (`R5`).
