-- ============================================================
-- MIGRATION 20261127220000 — Synchronized Supabase Security & Storage Parity
-- ============================================================
-- Safe & idempotent for Supabase Dashboard -> SQL Editor on both:
--   - Staging    (oqwvxplteqtlrhktsplj)
--   - Production (yxqyrjyzxitrgkhgauli)
--
-- What this hardens:
--   1. Clears remaining SQL Security Advisor WARNs:
--      - `public.guard_profile_role()` execute revoked from PUBLIC and anon
--      - `public.calculate_is_late()` recreated with `set search_path = ''`,
--        schema-qualified `public.assignments`, and execute revoked from
--        PUBLIC and anon
--      - `public.match_documents(public.vector, integer)` recreated with
--        `set search_path = ''`, `public.documents`, and explicit
--        `operator(public.<=>)` cosine operator; execute revoked from
--        PUBLIC and anon, granted to `authenticated`
--   2. Least-privilege table grants & RLS role cleanup:
--      - Revokes legacy `anon` privileges on the 13 legacy `public.*` tables
--        while preserving `authenticated` grants for mobile & web clients
--      - Tightens `TO public` policies on `public.device_tokens`,
--        `public.notification_reads`, and `public.timetable_course_eligibility`
--        to `TO authenticated` (using `(select auth.uid())`)
--   3. Storage bucket parity (`storage.buckets`):
--      - Enforces identical `file_size_limit` and `allowed_mime_types` on
--        `timetables` (15 MiB), `resources` (50 MiB), `avatars` (5 MiB),
--        and `assignments` (25 MiB) across Staging & Production.
--
-- Does NOT drop legacy tables, move `vector` out of `public`, or alter
-- `storage.objects` `storage_public_read` (all 4 buckets remain public).
-- ============================================================

begin;

-- ─── 1. Fix Security Advisor WARNs on Functions ──────────────────────────────

revoke all on function public.guard_profile_role() from public, anon;

create or replace function public.calculate_is_late()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  assignment_deadline timestamptz;
begin
  select deadline into assignment_deadline
    from public.assignments
   where id = new.assignment_id;

  if new.submitted_at > assignment_deadline then
    new.is_late := true;
  else
    new.is_late := false;
  end if;

  return new;
end;
$$;

revoke all on function public.calculate_is_late() from public, anon;

create or replace function public.match_documents(
  query_embedding public.vector,
  match_count integer default 3
)
returns table(content text, category text, similarity double precision)
language plpgsql
set search_path = ''
as $$
begin
  return query
  select
    d.content,
    d.category,
    1 - (d.embedding operator(public.<=>) query_embedding) as similarity
  from public.documents d
  order by d.embedding operator(public.<=>) query_embedding
  limit match_count;
end;
$$;

revoke all on function public.match_documents(public.vector, integer) from public, anon;
grant execute on function public.match_documents(public.vector, integer) to authenticated;

-- ─── 2. Revoke Legacy `anon` Grants on 13 `public.*` Tables ─────────────────

revoke all on table
  public.assignments,
  public.cancellations,
  public.device_tokens,
  public.documents,
  public.notification_reads,
  public.notifications,
  public.profiles,
  public.resources,
  public.routine_versions,
  public.routines,
  public.submissions,
  public.timetable_courses,
  public.whitelists
from anon;

-- ─── 3. Tighten `TO public` Policies -> `TO authenticated` ───────────────────

drop policy if exists "own_tokens_select" on public.device_tokens;
create policy "own_tokens_select" on public.device_tokens
  as permissive for select to authenticated
  using ((user_id = (select auth.uid())));

drop policy if exists "own_tokens_insert" on public.device_tokens;
create policy "own_tokens_insert" on public.device_tokens
  as permissive for insert to authenticated
  with check ((user_id = (select auth.uid())));

drop policy if exists "own_tokens_update" on public.device_tokens;
create policy "own_tokens_update" on public.device_tokens
  as permissive for update to authenticated
  using ((user_id = (select auth.uid())))
  with check ((user_id = (select auth.uid())));

drop policy if exists "own_tokens_delete" on public.device_tokens;
create policy "own_tokens_delete" on public.device_tokens
  as permissive for delete to authenticated
  using ((user_id = (select auth.uid())));

drop policy if exists "own_reads_select" on public.notification_reads;
create policy "own_reads_select" on public.notification_reads
  as permissive for select to authenticated
  using ((user_id = (select auth.uid())));

drop policy if exists "own_reads_insert" on public.notification_reads;
create policy "own_reads_insert" on public.notification_reads
  as permissive for insert to authenticated
  with check ((user_id = (select auth.uid())));

drop policy if exists "own_reads_update" on public.notification_reads;
create policy "own_reads_update" on public.notification_reads
  as permissive for update to authenticated
  using ((user_id = (select auth.uid())))
  with check ((user_id = (select auth.uid())));

drop policy if exists "own_reads_delete" on public.notification_reads;
create policy "own_reads_delete" on public.notification_reads
  as permissive for delete to authenticated
  using ((user_id = (select auth.uid())));

drop policy if exists "admin_write" on public.timetable_course_eligibility;
create policy "admin_write" on public.timetable_course_eligibility
  as permissive for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- ─── 4. Storage Bucket Size & MIME Limits Parity (`storage.buckets`) ────────

update storage.buckets
   set file_size_limit = 15728640,
       allowed_mime_types = array[
         'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
         'application/vnd.ms-excel',
         'application/octet-stream'
       ]::text[]
 where id = 'timetables';

update storage.buckets
   set file_size_limit = 52428800,
       allowed_mime_types = array[
         'application/pdf',
         'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
         'application/vnd.openxmlformats-officedocument.presentationml.presentation',
         'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
         'application/zip',
         'image/png',
         'image/jpeg',
         'text/plain'
       ]::text[]
 where id = 'resources';

update storage.buckets
   set file_size_limit = 5242880,
       allowed_mime_types = array[
         'image/png',
         'image/jpeg',
         'image/webp'
       ]::text[]
 where id = 'avatars';

update storage.buckets
   set file_size_limit = 26214400,
       allowed_mime_types = array[
         'application/pdf',
         'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
         'application/msword',
         'application/zip',
         'image/png',
         'image/jpeg',
         'image/webp',
         'text/plain',
         'application/vnd.openxmlformats-officedocument.presentationml.presentation',
         'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
       ]::text[]
 where id = 'assignments';

commit;
