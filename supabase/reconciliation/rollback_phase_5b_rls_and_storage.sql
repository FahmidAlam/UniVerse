-- ============================================================
-- ROLLBACK — Phase 5B RLS & Storage Hardening (Emergency Restore)
-- ============================================================
-- Run in Supabase Dashboard -> SQL Editor ONLY if an emergency
-- rollback of 20261122160000_phase_5b_rls_and_storage_hardening.sql
-- is required. Restores prior 006 / 008 / 013 / 20261106130000 policies.
-- ============================================================

begin;

-- 1. Restore profiles_select
drop policy if exists "profiles_select" on public.profiles;
create policy "profiles_select" on public.profiles
  for select to authenticated using (true);

-- 2. Restore timetable_* SELECT policies
drop policy if exists "timetable_rooms_select" on public.timetable_rooms;
create policy "timetable_rooms_select" on public.timetable_rooms
  for select to authenticated using (true);

drop policy if exists "timetable_faculty_select" on public.timetable_faculty;
create policy "timetable_faculty_select" on public.timetable_faculty
  for select to authenticated using (true);

drop policy if exists "timetable_settings_select" on public.timetable_settings;
create policy "timetable_settings_select" on public.timetable_settings
  for select to authenticated using (true);

drop policy if exists "timetable_runs_select" on public.timetable_runs;
create policy "timetable_runs_select" on public.timetable_runs
  for select to authenticated using (true);

drop policy if exists "timetable_course_eligibility_select" on public.timetable_course_eligibility;
drop policy if exists "read_all" on public.timetable_course_eligibility;
create policy "read_all" on public.timetable_course_eligibility
  for select using (true);

-- 3. Restore wildcard storage.objects policies
drop policy if exists "storage_timetables_insert_admin" on storage.objects;
drop policy if exists "storage_timetables_update_admin" on storage.objects;
drop policy if exists "storage_timetables_delete_admin" on storage.objects;
drop policy if exists "storage_resources_insert_staff" on storage.objects;
drop policy if exists "storage_resources_update_staff" on storage.objects;
drop policy if exists "storage_resources_delete_staff" on storage.objects;
drop policy if exists "storage_avatars_insert_own" on storage.objects;
drop policy if exists "storage_avatars_update_own" on storage.objects;
drop policy if exists "storage_avatars_delete_own" on storage.objects;
drop policy if exists "storage_assignments_insert_scoped" on storage.objects;
drop policy if exists "storage_assignments_update_scoped" on storage.objects;
drop policy if exists "storage_assignments_delete_scoped" on storage.objects;

create policy "storage_auth_insert" on storage.objects
  for insert to authenticated with check (true);
create policy "storage_auth_update" on storage.objects
  for update to authenticated using (true) with check (true);
create policy "storage_auth_delete" on storage.objects
  for delete to authenticated using (true);

-- 4. Conditionally restore Track 2 course_distribution_*_read
do $$
begin
  if to_regclass('public.course_distribution_sources') is not null then
    drop policy if exists course_distribution_sources_read on public.course_distribution_sources;
    create policy course_distribution_sources_read on public.course_distribution_sources
      for select using (scheduling_scope_id is null or academic_private.can_scope(scheduling_scope_id, 'read_catalog'));
  end if;

  if to_regclass('public.course_distribution_revisions') is not null then
    drop policy if exists course_distribution_revisions_read on public.course_distribution_revisions;
    create policy course_distribution_revisions_read on public.course_distribution_revisions
      for select using (exists (select 1 from public.course_distribution_sources s
        where s.id = source_id and (s.scheduling_scope_id is null or academic_private.can_scope(s.scheduling_scope_id, 'read_catalog'))));
  end if;

  if to_regclass('public.course_distribution_corrections') is not null then
    drop policy if exists course_distribution_corrections_read on public.course_distribution_corrections;
    create policy course_distribution_corrections_read on public.course_distribution_corrections
      for select using (exists (select 1 from public.course_distribution_revisions r join public.course_distribution_sources s on s.id = r.source_id
        where r.id = revision_id and (s.scheduling_scope_id is null or academic_private.can_scope(s.scheduling_scope_id, 'read_catalog'))));
  end if;

  if to_regclass('public.course_distribution_artifacts') is not null then
    drop policy if exists course_distribution_artifacts_read on public.course_distribution_artifacts;
    create policy course_distribution_artifacts_read on public.course_distribution_artifacts
      for select using (exists (select 1 from public.course_distribution_revisions r join public.course_distribution_sources s on s.id = r.source_id
        where r.id = revision_id and (s.scheduling_scope_id is null or academic_private.can_scope(s.scheduling_scope_id, 'read_catalog'))));
  end if;
end $$;

commit;
