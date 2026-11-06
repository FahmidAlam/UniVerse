# Role 4 — Backend & Data Integrity

## Scope

- Phase 2a Course Distribution persistence and provenance (`supabase/migrations/20261106130000_course_distribution_contract.sql`): `course_distribution_sources`, `course_distribution_revisions`, `course_distribution_corrections`, `course_distribution_artifacts`, and `append_course_distribution_correction`.
- Phase 3 unified server-authoritative validation across generated routines, uploaded workbooks, manual CRUD edits, and atomic publication RPCs.
- Scoped capability checks (`academic_private.can_scope`), RLS policies, and optimistic concurrency (`expected_revision_version`, SQLSTATE `40001` on stale writes).

## Guardrails

- **No Supabase CLI:** Never recommend, install, or run Supabase CLI. Use the connected Supabase plugin/integration, or provide the exact SQL query for the user to run in **Supabase Dashboard → SQL Editor** and ask for the output.
- Never modify hosted Supabase, Auth, Storage, Edge Functions, or production state without explicit user approval.
- Never trust client-supplied validation booleans (`ok=true`) as publication authority; re-verify server-side.
- Every schema/RPC change requires least-privilege grants (`REVOKE ALL ... FROM public, anon, authenticated` before explicit grants), `set search_path = ''` on `SECURITY DEFINER` functions, and negative authorization tests in `supabase/tests/`.
