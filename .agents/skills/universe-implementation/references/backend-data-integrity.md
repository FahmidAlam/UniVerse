# Role 4 — Backend, Supabase SQL & RLS Integrity

## Scope

- **Migration Chain (`supabase/migrations/`):**
  - Baseline `001`–`016` (no `010`), canonical catalog `20261022140809_academic_catalog.sql`, Track 2 distribution contract `20261106130000_course_distribution_contract.sql`, and Phase 5B RLS/storage hardening `20261122160000_phase_5b_rls_and_storage_hardening.sql`.
  - **Staging (`oqwvxplteqtlrhktsplj`):** All 37 tables + Phase 5B RLS/storage hardening applied and verified (`supabase/tests/phase_5b_rls_hardening_verification.sql`).
  - **Production (`yxqyrjyzxitrgkhgauli`):** Protected; promotion follows [`docs/deployment/PHASE_4A1_AND_5B_SQL_PROMOTION_RUNBOOK.md`](../../../../docs/deployment/PHASE_4A1_AND_5B_SQL_PROMOTION_RUNBOOK.md) only upon explicit owner execution.
- **Wave 2 Authorized Backend Targets (`Phase 4A-2`):**
  - Revision-bound policy snapshot & server-authoritative `validation_report` contract (unlocking **Gate C**).
  - Durable solver job persistence + archiving, concurrency-guarded, scope-checked `publish_routine()` preserving full historical routine snapshots (unlocking **Gate D**).

## Guardrails

- **No Supabase CLI:** Never recommend, install, or run Supabase CLI in developer workflows. Use the connected Supabase plugin or provide exact SQL scripts for **Supabase Dashboard → SQL Editor** (plus matching rollback scripts in `supabase/reconciliation/`).
- Never modify hosted Supabase Auth, Storage, Edge Functions (`invite-admin`, `send-push`), or database state without explicit owner approval.
- Never trust client-supplied validation booleans (`ok=true`) as publication authority; enforce invariants server-side.
- Every new table or `SECURITY DEFINER` function requires `set search_path = ''`, least-privilege `REVOKE ALL ... FROM public, anon, authenticated` before explicit grants, owner-scoped Storage policies (`storage.foldername(name)[1] = auth.uid()::text` for avatars), and negative authorization tests in `supabase/tests/`.
