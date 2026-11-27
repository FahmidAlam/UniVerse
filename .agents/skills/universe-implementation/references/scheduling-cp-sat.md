# Role 3 — Scheduling & CP-SAT Engine (Current & Wave 2)

## Scope

- **Deterministic Normalization (`engine/distribution.py`, `engine/domain.py`, `engine/ingest.py`):** Parse row-5 `Course Distribution` headers, preserve `B+C` joint sections and split/co-teacher arrays, validate formula + cached provenance on columns `J` and `L`, and bind solver runs to immutable source revisions.
- **API Auth, Security Guards & Phase 3B Parser (`engine/main.py`, `engine/auth.py`, `engine/security_guards.py`, `engine/parse_rendered.py`, `render.yaml`):**
  - Dual-client Supabase Bearer JWT + `profiles.role == 'admin'` verification (`ENGINE_AUTH_MODE=enforced` in Production) supporting both legacy `eyJ...` and 2027 opaque `sb_publishable_...`/`sb_secret_...` keys, plus exact-origin `ALLOWED_ORIGINS` CORS (`GET /` remains public for health checks).
  - Zero-trust OOXML upload preflight (`validate_xlsx_upload`: ≤ 15 MiB compressed, ≤ 100 MiB uncompressed, ZIP-bomb ratio bound, macro/encrypted/ActiveX rejection), sliding-window per-caller `RateLimiter` (`429` + `Retry-After`), and `ConcurrencyGuard` (`MAX_CONCURRENT_SOLVES=2`).
  - **Phase 3B (Implemented):** Additive, strictly non-mutating `POST /api/timetable/parse-rendered-workbook` (`engine/parse_rendered.py`) achieving fixture-verified 1:1 parity with Flutter's `RoutineWorkbookParser`.
- **Dynamic 3-Tier Room-Pool Classification (`engine/ingest.py`, `engine/room_policy.py`, `engine/policy_constraints.py`, `engine/solver.py`):** Tier 1 explicit `course_room_overrides` / `catalog_courses` (`[pool:theory|cse_lab|ecl_lab|physics_lab]`, `class_type`, `is_physics_lab`) > Tier 2 `_infer_is_lab(code, title, credit)` (lab/sessional/drawing/cad/simulation title keyword OR even final digit with `credit is None or credit <= 2.0`) > Tier 3 room-pool routing (`PHYSICS_LAB`, `ECL-*`, or CSE Lab Pool bounded by `<= open_cse` in Phase 1 CP-SAT).
- **Render 512 MB Memory & Durability (`render.yaml`, `engine/main.py`, `engine/job_store.py`):** `SOLVER_WORKERS=1`, `SOLVER_NUM_WORKERS=1`, `SOLVER_MAX_MEMORY_MB=320`, `SOLVER_LINEARIZATION_LEVEL=0`, `MAX_CONCURRENT_SOLVES=1`, startup orphan-job sweep (`mark_orphaned_jobs_on_startup`), and durable Postgres `public.solver_jobs` + Storage `timetables/solver_jobs/` persistence.
- **Wave 2B (`Phase 4A-2` / Stage 5C):** Full `R1`–`R16` & `D1`–`D6` CP-SAT modeling + Hybrid R7/R6 off-day resolution and structured solver diagnostics (`OPTIMAL`, `FEASIBLE`, `INFEASIBLE`, `TIME_LIMIT_EXHAUSTED`, `INPUT_ERROR`) are implemented.

## Guardrails

- Retain Google OR-Tools CP-SAT. Express mandatory committee rules as hard constraints and preferences (`R8`, `R9` break-side preference, `R12` lab consecutiveness preference) as tiered soft objectives — never silently drop mandatory academic constraints to fake feasibility.
- Preserve key committee decisions from [`18-committee-decisions-and-policy-baseline-2026-11-04.md`](../../../../docs/timetable-audit-2026-10-20/18-committee-decisions-and-policy-baseline-2026-11-04.md) and [`16-committee-traceability-2026-11-04.md`](../../../../docs/timetable-audit-2026-10-20/16-committee-traceability-2026-11-04.md):
  - `D1`: Section consecutive 2-day weekends are independent of faculty off-days; batch days-off spread `<= 1` (`R1`, `R2`).
  - `D2`: Theory 1/1.5/2-credit courses require 2 consecutive same-day, same-room slots (`R13`); sessional break-crossing requires explicit scoped permission (`R12`).
  - `D3`: Permanent faculty non-off days are attendance days, not mandatory daily teaching constraints (`R7`).
  - `D4`: Adjunct day spans count distinct courses across sections (`R6`); undeclared external faculty have zero availability (`R5`).
