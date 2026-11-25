---
name: backend-evolution-and-resilience
description: Safe database migrations, cross-platform contracts (Postgres, FastAPI, React Web, Flutter Android/iOS), stateless compute & durable async jobs, direct object storage, caching, and Wave 2 solver/RPC evolution. Mandatory before authoring SQL migrations, modifying RPCs, adding FastAPI endpoints (Phase 3B, Gate C/D, R1-R16), or changing shared data contracts. Do NOT use for CSS/UI styling.
---

# UniVerse Backend Evolution & System Resilience

Evolve UniVerse from React Web v1 + Track 1 into full Wave 2 (Phase 3B `.xlsx` parsing, Gate C/D durable scheduling, R1–R16 CP-SAT solver) without breaking live Flutter Android/iOS clients or losing routine data.

## 1. Expand–Contract Migrations & Environment Governance

1. **Zero Supabase CLI & Production Gate:**
   - Never install or run Supabase CLI. Apply SQL via **Supabase Dashboard → SQL Editor** (or read-only inspection via `supabase_mcp`).
   - Always test migrations and rollback scripts on **Staging (`oqwvxplteqtlrhktsplj`)** first. Never touch **Production (`yxqyrjyzxitrgkhgauli`)** without explicit owner authorization.
2. **Strictly Additive Expand–Contract Discipline:**
   - Add new columns with safe defaults (`teacher_codes text[] not null default '{}'`), new tables, or additive RPCs before updating clients. Never drop or rename columns still read by live Flutter Android/iOS builds (`routines`, `cancellations`, `notifications`, `notification_reads`, `resources`, `device_tokens`, `profiles`).
   - Pair every migration in `supabase/migrations/` with an idempotent rollback script in `supabase/reconciliation/`.

## 2. Cross-Platform Serialization Invariants (4-Layer Contract)

Any change touching shared entities must preserve all four layers simultaneously (`Postgres ↔ FastAPI ↔ React Web ↔ Flutter Mobile`):

1. **Clock Normalization:** PostgreSQL `time` columns store `HH:MM:SS`; FastAPI engine config/rows exchange `HH:MM` (or `HH:MM:SS` normalized via `ClockTime`).
2. **Co-Teacher Compatibility:** `lib/core/models/routine_model.dart` already reads `map['teachers'] ?? map['teacher_codes']` with fallback to scalar `teacher_code`. Keep `teacher_code` populated (primary/joined display) alongside `teacher_codes text[]` so older mobile clients never break when Gate D lifts `findCoTeacherBlockers`.
3. **Mobile Deep Links & Realtime:** Preserve `com.example.universe://login-callback/` and `com.example.universe://reset-callback/` in `ios/Runner/Info.plist`, `AndroidManifest.xml`, and `invite-admin/callback_policy.js`. Remember `supabase_realtime` publishes **only** `public.cancellations`; use TanStack Query invalidation + explicit Refresh elsewhere.

## 3. Stateless Compute & Durable Async State

1. **Eliminate Process-Local Volatility (Gate D):**
   - `engine/main.py`'s in-memory `JOBS` dict is wiped whenever Render's free-tier container sleeps (~15 min) or restarts.
   - For Gate D, persist solver jobs in a PostgreSQL table (`solver_jobs` with `id`, `revision_id`, `status`, `progress`, `idempotency_key`, `result_path`, `error_detail`, `created_by`, `updated_at`) and upload rendered `.xlsx` outputs to Storage so status polling, result inspection, and downloads survive container restarts.
2. **Idempotency & Bounded Client Recovery:**
   - Mutating RPCs and job submissions must support idempotency keys or optimistic version checks (`expected_revision_version`, catching `SQLSTATE 40001` stale revision conflicts without discarding user edits).
   - Client pollers must back off on `HTTP 429`, fast-fail cleanly on `401`/`403`/`404` (engine restart), and surface actionable recovery states.

## 4. Direct Object Storage, Query Discipline & CQRS Separation

1. **Never Proxy Binaries Through Render:**
   - Stream `.xlsx` downloads and archive previews directly from Supabase Storage (`timetables` bucket) in the browser rather than routing file bytes through FastAPI on Render.
2. **Bounded Reads & Query Efficiency:**
   - Never issue unbounded `SELECT *` on growing history tables (`routine_versions`, `timetable_runs`, `notifications`, `routines` archives). Select explicit columns, apply `.order(..., { ascending: false }).limit(50)` (or cursor pagination), and tune TanStack Query `staleTime` + targeted mutation invalidation.
3. **Recoverable Publication (`publish_routine()`):**
   - Replace destructive `DELETE FROM public.routines WHERE true` with scope-filtered, version-archived publication (`routine_versions` storing `storage_path` + immutable row snapshot or `is_active` partitioning) so any published routine can be rolled back atomically inside PostgreSQL.

## 5. Clean Domain Boundaries in `engine/`

- Keep pure domain types (`engine/domain.py`), deterministic workbook normalization (`engine/distribution.py`, `engine/ingest.py`), room predicates (`engine/room_policy.py`), and OR-Tools CP-SAT constraint modeling (`engine/solver.py`) decoupled from FastAPI HTTP routing (`engine/main.py`).
- Express mandatory committee rules (R1–R16, D1–D6) as hard CP-SAT constraints and soft preferences (R8, R9 break-side, R12 lab consecutiveness) as tiered weighted objectives—never drop hard constraints to fake feasibility.
- Phase 3B (`POST /api/timetable/parse-rendered`) must remain strictly non-mutating and prove 1:1 output equivalence against Flutter's `RoutineWorkbookParser` fixtures before `lib/features/admin/` is pruned.
