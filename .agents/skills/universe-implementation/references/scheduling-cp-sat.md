# Role 3 — Scheduling & CP-SAT Engine (Current & Wave 2)

## Scope

- **Deterministic Normalization (`engine/distribution.py`, `engine/domain.py`, `engine/ingest.py`):** Parse row-5 `Course Distribution` headers, preserve `B+C` joint sections and split/co-teacher arrays, validate formula + cached provenance on columns `J` and `L`, and bind solver runs to immutable source revisions.
- **API Auth & CORS (`engine/main.py`, `engine/auth.py`, `render.yaml`):** Dual-client Supabase Bearer JWT + `profiles.role == 'admin'` verification (`ENGINE_AUTH_MODE=optional|enforced`) and `ALLOWED_ORIGINS` exact-origin CORS (whitespace & trailing slashes stripped). `GET /` remains public for health checks.
- **Wave 2 Authorized Targets (Require Explicit Owner Go-Ahead Before Editing `solver.py` / `render.py`):**
  - **Phase 4A-2:** Full `R1`–`R16` & `D1`–`D6` CP-SAT constraint modeling, structured solver conflict diagnostics (`OPTIMAL`, `FEASIBLE`, `INFEASIBLE`, `TIME_LIMIT_EXHAUSTED`, `INPUT_ERROR`), and durable job storage replacing in-memory `JOBS`.
  - **Phase 3B:** Additive, non-mutating FastAPI rendered-workbook parse/validation endpoint achieving fixture-verified equivalence with Flutter's `RoutineWorkbookParser`.

## Guardrails

- Retain Google OR-Tools CP-SAT. Express mandatory committee rules as hard constraints and preferences (`R8`, `R9` break-side preference, `R12` lab consecutiveness preference) as tiered soft objectives — never silently drop mandatory academic constraints to fake feasibility.
- Preserve key committee decisions from [`18-committee-decisions-and-policy-baseline-2026-11-04.md`](../../../../docs/timetable-audit-2026-10-20/18-committee-decisions-and-policy-baseline-2026-11-04.md) and [`16-committee-traceability-2026-11-04.md`](../../../../docs/timetable-audit-2026-10-20/16-committee-traceability-2026-11-04.md):
  - `D1`: Section consecutive 2-day weekends are independent of faculty off-days; batch days-off spread `<= 1` (`R1`, `R2`).
  - `D2`: Theory 1/1.5/2-credit courses require 2 consecutive same-day, same-room slots (`R13`); sessional break-crossing requires explicit scoped permission (`R12`).
  - `D3`: Permanent faculty non-off days are attendance days, not mandatory daily teaching constraints (`R7`).
  - `D4`: Adjunct day spans count distinct courses across sections (`R6`); undeclared external faculty have zero availability (`R5`).
