# Role 4 — Backend, Supabase SQL & RLS Integrity

## Cross-Referenced Mandatory Skills

Load [`system-security-and-hardening`](../../system-security-and-hardening/SKILL.md) (RLS/grants, `SET search_path = ''`, Storage bounds, negative authorization tests) and [`backend-evolution-and-resilience`](../../backend-evolution-and-resilience/SKILL.md) (expand–contract discipline, `supabase/reconciliation/` rollbacks, 4-layer serialization, durable jobs, recoverable publication) before modifying any SQL, RPC, or Storage policy.

## Scope

- **Migration Chain (`supabase/migrations/`):**
  - Baseline `001`–`016` (no `010`), canonical catalog `20261022140809_academic_catalog.sql`, Track 2 distribution contract `20261106130000_course_distribution_contract.sql`, and Phase 5B RLS/storage hardening `20261122160000_phase_5b_rls_and_storage_hardening.sql`.
  - **Staging (`oqwvxplteqtlrhktsplj`):** All 37 tables + Phase 5B RLS/storage hardening applied and verified (`supabase/tests/phase_5b_rls_hardening_verification.sql`).
  - **Production (`yxqyrjyzxitrgkhgauli`):** Protected; promotion follows [`docs/deployment/PHASE_4A1_AND_5B_SQL_PROMOTION_RUNBOOK.md`](../../../../docs/deployment/PHASE_4A1_AND_5B_SQL_PROMOTION_RUNBOOK.md) only upon explicit owner execution (Stage 3).
- **Wave 2 Authorized Backend Targets (`Phase 4A-2`):**
  - Revision-bound policy snapshot & server-authoritative `validation_report` contract (unlocking **Gate C**).
  - Durable Postgres solver job persistence + archiving, concurrency-guarded, scope-checked `publish_routine()` preserving full historical routine snapshots + `teacher_codes text[]` expand–contract support (unlocking **Gate D**).

## Role-Specific Guardrails

- Never modify hosted Supabase Auth, Storage, Edge Functions (`invite-admin`, `send-push`), or database state without explicit owner approval.
- Never trust client-supplied validation booleans (`ok=true`) as publication authority; enforce invariants server-side and pair every migration with `supabase/reconciliation/` rollback SQL and `supabase/tests/` negative checks.
