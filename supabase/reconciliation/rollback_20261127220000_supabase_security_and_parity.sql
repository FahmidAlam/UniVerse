-- ============================================================
-- ROLLBACK — 20261127220000 Synchronized Supabase Security & Storage Parity
-- ============================================================
-- Run in Supabase Dashboard -> SQL Editor ONLY if an emergency rollback
-- of 20261127220000_supabase_security_and_parity_hardening.sql is required.
-- ============================================================

begin;

-- 1. Restore function definitions / grants to pre-20261127220000 baseline
grant execute on function public.guard_profile_role() to anon;

create or replace function public.calculate_is_late()
returns trigger
language plpgsql
as $$
declare
  assignment_deadline timestamptz;
begin
  select deadline into assignment_deadline
    from assignments
   where id = new.assignment_id;

  if new.submitted_at > assignment_deadline then
    new.is_late := true;
  else
    new.is_late := false;
  end if;

  return new;
end;
$$;

grant execute on function public.calculate_is_late() to anon, authenticated;

create or replace function public.match_documents(
  query_embedding public.vector,
  match_count integer default 3
)
returns table(content text, category text, similarity double precision)
language plpgsql
as $$
begin
  return query
  select d.content, d.category, 1 - (d.embedding <=> query_embedding) as similarity
  from documents d
  order by d.embedding <=> query_embedding
  limit match_count;
end;
$$;

grant execute on function public.match_documents(public.vector, integer) to anon, authenticated;

-- 2. Restore legacy anon table grants (DML only)
grant select, insert, update, delete on table
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
to anon;

-- 3. Restore prior `TO public` policies
drop policy if exists "own_tokens_select" on public.device_tokens;
create policy "own_tokens_select" on public.device_tokens
  as permissive for select to public
  using ((user_id = auth.uid()));

drop policy if exists "own_tokens_insert" on public.device_tokens;
create policy "own_tokens_insert" on public.device_tokens
  as permissive for insert to public
  with check ((user_id = auth.uid()));

drop policy if exists "own_tokens_update" on public.device_tokens;
create policy "own_tokens_update" on public.device_tokens
  as permissive for update to public
  using ((user_id = auth.uid()));

drop policy if exists "own_tokens_delete" on public.device_tokens;
create policy "own_tokens_delete" on public.device_tokens
  as permissive for delete to public
  using ((user_id = auth.uid()));

drop policy if exists "own_reads_select" on public.notification_reads;
create policy "own_reads_select" on public.notification_reads
  as permissive for select to public
  using ((user_id = auth.uid()));

drop policy if exists "own_reads_insert" on public.notification_reads;
create policy "own_reads_insert" on public.notification_reads
  as permissive for insert to public
  with check ((user_id = auth.uid()));

drop policy if exists "own_reads_update" on public.notification_reads;
create policy "own_reads_update" on public.notification_reads
  as permissive for update to public
  using ((user_id = auth.uid()));

drop policy if exists "own_reads_delete" on public.notification_reads;
create policy "own_reads_delete" on public.notification_reads
  as permissive for delete to public
  using ((user_id = auth.uid()));

drop policy if exists "admin_write" on public.timetable_course_eligibility;
create policy "admin_write" on public.timetable_course_eligibility
  as permissive for all to public
  using (is_admin())
  with check (is_admin());

-- 4. Restore `assignments.allowed_mime_types` back to null (pre-hardening Prod state)
update storage.buckets
   set allowed_mime_types = null
 where id = 'assignments';

commit;
