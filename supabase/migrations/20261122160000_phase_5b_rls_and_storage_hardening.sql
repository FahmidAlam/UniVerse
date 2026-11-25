-- ============================================================
-- MIGRATION 20261122160000 — Phase 5B RLS & Storage Hardening
-- ============================================================
-- Safe for both 18-table Production (yxqyrjyzxitrgkhgauli) and
-- 37-table Staging (oqwvxplteqtlrhktsplj). Idempotent for SQL Editor.
--
-- What this hardens:
--   1. Standardizes SECURITY DEFINER helpers with `set search_path = ''`
--      and explicit `public.` table qualification.
--   2. Tightens `public.profiles` SELECT to `id = auth.uid() or public.is_admin()`.
--   3. Restricts `timetable_*` admin configuration tables SELECT to
--      `public.is_admin()` and revokes `anon` grants on those tables.
--   4. Replaces wildcard `storage_auth_*` policies on `storage.objects`
--      with bucket-scoped policies (`timetables`, `resources`, `avatars`,
--      `assignments`).
--   5. Conditionally tightens `course_distribution_*_read` when Track 2
--      tables exist, removing `TO public` / `scheduling_scope_id is null`
--      exposure.
-- ============================================================

begin;

-- ─── 1. Standardize SECURITY DEFINER helpers (search_path = '') ─────────

create or replace function public.my_role()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select role from public.profiles where id = auth.uid();
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(public.my_role() = 'admin', false);
$$;

revoke execute on function public.my_role(), public.is_admin() from anon, public;
grant  execute on function public.my_role(), public.is_admin() to authenticated;

create or replace function public.guard_profile_role()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- No end-user JWT (SQL editor, service role) or an admin: any role.
  if auth.uid() is null or public.is_admin() then
    return new;
  end if;

  -- The role is not changing: ordinary profile edits.
  if tg_op = 'UPDATE' and new.role is not distinct from old.role then
    return new;
  end if;

  -- Same, for an upsert of an existing row.
  if tg_op = 'INSERT' and exists (
    select 1 from public.profiles p where p.id = new.id and p.role = new.role
  ) then
    return new;
  end if;

  if new.role = 'student' then
    return new;
  end if;

  if exists (
    select 1 from public.whitelists w
    where lower(w.email) = lower(auth.jwt() ->> 'email')
      and w.role = new.role
  ) then
    return new;
  end if;

  raise exception 'The % role needs to be added by the department admin.', new.role
    using errcode = '42501', hint = 'not_whitelisted';
end;
$$;

create or replace function public.register_device_token(
  p_token    text,
  p_platform text default 'android'
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  -- Clear a stale row left by a previous user of this device.
  delete from public.device_tokens
   where token = p_token
     and user_id <> auth.uid();

  insert into public.device_tokens (token, user_id, platform, updated_at)
  values (p_token, auth.uid(), p_platform, now())
  on conflict (token) do update
     set user_id    = excluded.user_id,
         platform   = excluded.platform,
         updated_at = now();
end;
$$;

revoke execute on function public.register_device_token(text, text) from anon, public;
grant  execute on function public.register_device_token(text, text) to authenticated;

-- ─── 2. Tighten public.profiles SELECT ──────────────────────────────────

drop policy if exists "profiles_select" on public.profiles;
create policy "profiles_select" on public.profiles
  for select to authenticated
  using (id = auth.uid() or public.is_admin());

-- ─── 3. Restrict timetable_* admin configuration tables ─────────────────

revoke all on table
  public.timetable_rooms,
  public.timetable_faculty,
  public.timetable_settings,
  public.timetable_runs,
  public.timetable_course_eligibility
from anon;

drop policy if exists "timetable_rooms_select" on public.timetable_rooms;
create policy "timetable_rooms_select" on public.timetable_rooms
  for select to authenticated
  using (public.is_admin());

drop policy if exists "timetable_faculty_select" on public.timetable_faculty;
create policy "timetable_faculty_select" on public.timetable_faculty
  for select to authenticated
  using (public.is_admin());

drop policy if exists "timetable_settings_select" on public.timetable_settings;
create policy "timetable_settings_select" on public.timetable_settings
  for select to authenticated
  using (public.is_admin());

drop policy if exists "timetable_runs_select" on public.timetable_runs;
create policy "timetable_runs_select" on public.timetable_runs
  for select to authenticated
  using (public.is_admin());

drop policy if exists "read_all" on public.timetable_course_eligibility;
drop policy if exists "timetable_course_eligibility_select" on public.timetable_course_eligibility;
create policy "timetable_course_eligibility_select" on public.timetable_course_eligibility
  for select to authenticated
  using (public.is_admin());

-- ─── 4. Replace wildcard storage.objects write policies ─────────────────

drop policy if exists "storage_auth_insert" on storage.objects;
drop policy if exists "storage_auth_update" on storage.objects;
drop policy if exists "storage_auth_delete" on storage.objects;

-- timetables: admins only
drop policy if exists "storage_timetables_insert_admin" on storage.objects;
create policy "storage_timetables_insert_admin" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'timetables' and public.is_admin());

drop policy if exists "storage_timetables_update_admin" on storage.objects;
create policy "storage_timetables_update_admin" on storage.objects
  for update to authenticated
  using (bucket_id = 'timetables' and public.is_admin())
  with check (bucket_id = 'timetables' and public.is_admin());

drop policy if exists "storage_timetables_delete_admin" on storage.objects;
create policy "storage_timetables_delete_admin" on storage.objects
  for delete to authenticated
  using (bucket_id = 'timetables' and public.is_admin());

-- resources: teachers and admins
drop policy if exists "storage_resources_insert_staff" on storage.objects;
create policy "storage_resources_insert_staff" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'resources' and public.my_role() in ('teacher', 'admin'));

drop policy if exists "storage_resources_update_staff" on storage.objects;
create policy "storage_resources_update_staff" on storage.objects
  for update to authenticated
  using (bucket_id = 'resources' and public.my_role() in ('teacher', 'admin'))
  with check (bucket_id = 'resources' and public.my_role() in ('teacher', 'admin'));

drop policy if exists "storage_resources_delete_staff" on storage.objects;
create policy "storage_resources_delete_staff" on storage.objects
  for delete to authenticated
  using (bucket_id = 'resources' and public.my_role() in ('teacher', 'admin'));

-- avatars: owner-prefixed folder (`<uid>/...`) or admin
drop policy if exists "storage_avatars_insert_own" on storage.objects;
create policy "storage_avatars_insert_own" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin())
  );

drop policy if exists "storage_avatars_update_own" on storage.objects;
create policy "storage_avatars_update_own" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'avatars'
    and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin())
  )
  with check (
    bucket_id = 'avatars'
    and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin())
  );

drop policy if exists "storage_avatars_delete_own" on storage.objects;
create policy "storage_avatars_delete_own" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'avatars'
    and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin())
  );

-- assignments: owner-prefixed folder (`<uid>/...`) or teacher/admin
drop policy if exists "storage_assignments_insert_scoped" on storage.objects;
create policy "storage_assignments_insert_scoped" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'assignments'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or public.my_role() in ('teacher', 'admin')
    )
  );

drop policy if exists "storage_assignments_update_scoped" on storage.objects;
create policy "storage_assignments_update_scoped" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'assignments'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or public.my_role() in ('teacher', 'admin')
    )
  )
  with check (
    bucket_id = 'assignments'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or public.my_role() in ('teacher', 'admin')
    )
  );

drop policy if exists "storage_assignments_delete_scoped" on storage.objects;
create policy "storage_assignments_delete_scoped" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'assignments'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or public.my_role() in ('teacher', 'admin')
    )
  );

-- ─── 5. Conditionally tighten Track 2 course_distribution_*_read ────────

do $$
begin
  if to_regclass('public.course_distribution_sources') is not null then
    drop policy if exists course_distribution_sources_read on public.course_distribution_sources;
    create policy course_distribution_sources_read on public.course_distribution_sources
      for select to authenticated
      using (
        public.is_admin()
        or (scheduling_scope_id is not null and academic_private.can_scope(scheduling_scope_id, 'read_catalog'))
      );
  end if;

  if to_regclass('public.course_distribution_revisions') is not null then
    drop policy if exists course_distribution_revisions_read on public.course_distribution_revisions;
    create policy course_distribution_revisions_read on public.course_distribution_revisions
      for select to authenticated
      using (
        public.is_admin()
        or exists (
          select 1 from public.course_distribution_sources s
          where s.id = source_id
            and s.scheduling_scope_id is not null
            and academic_private.can_scope(s.scheduling_scope_id, 'read_catalog')
        )
      );
  end if;

  if to_regclass('public.course_distribution_corrections') is not null then
    drop policy if exists course_distribution_corrections_read on public.course_distribution_corrections;
    create policy course_distribution_corrections_read on public.course_distribution_corrections
      for select to authenticated
      using (
        public.is_admin()
        or exists (
          select 1
          from public.course_distribution_revisions r
          join public.course_distribution_sources s on s.id = r.source_id
          where r.id = revision_id
            and s.scheduling_scope_id is not null
            and academic_private.can_scope(s.scheduling_scope_id, 'read_catalog')
        )
      );
  end if;

  if to_regclass('public.course_distribution_artifacts') is not null then
    drop policy if exists course_distribution_artifacts_read on public.course_distribution_artifacts;
    create policy course_distribution_artifacts_read on public.course_distribution_artifacts
      for select to authenticated
      using (
        public.is_admin()
        or exists (
          select 1
          from public.course_distribution_revisions r
          join public.course_distribution_sources s on s.id = r.source_id
          where r.id = revision_id
            and s.scheduling_scope_id is not null
            and academic_private.can_scope(s.scheduling_scope_id, 'read_catalog')
        )
      );
  end if;
end $$;

commit;
