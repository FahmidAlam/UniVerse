-- ============================================================
-- ROLLBACK — Stage 5C (Gate D): Durable Jobs, Co-Teachers & Archiving Publish
-- ============================================================
-- Reverses 20261127180000_stage_5c_gate_d_durable_jobs_and_archiving_publish.sql
-- idempotently while restoring the legacy 6-parameter `public.publish_routine`.
-- ============================================================

begin;

-- 1. Drop Archive v2b rollback RPC and upgraded publish_routine RPC
drop function if exists public.restore_routine_version(uuid, text);
drop function if exists public.publish_routine(
  jsonb, text, text, jsonb, jsonb, text,
  uuid, uuid, int, uuid, text, boolean
);

-- 2. Restore original 6-parameter `public.publish_routine`
create or replace function public.publish_routine(
  p_rows jsonb,
  p_semester_label text default null,
  p_source text default 'engine',
  p_stats jsonb default '{}'::jsonb,
  p_validation jsonb default '{}'::jsonb,
  p_notes text default null
) returns jsonb
language plpgsql
set search_path to 'public'
as $function$
declare
  v_id uuid;
  v_count int;
begin
  if not public.is_admin() then
    raise exception 'Only an admin may publish a routine.'
      using errcode = '42501';
  end if;

  if p_rows is null or jsonb_typeof(p_rows) <> 'array'
     or jsonb_array_length(p_rows) = 0 then
    raise exception 'Refusing to publish an empty routine.'
      using errcode = '22023';
  end if;

  insert into public.routine_versions
    (semester_label, source, published_by, stats, validation, notes)
  values (p_semester_label, p_source, auth.uid(), coalesce(p_stats, '{}'::jsonb),
          coalesce(p_validation, '{}'::jsonb), p_notes)
  returning id into v_id;

  update public.routine_versions set is_active = false where is_active;
  delete from public.routines where true;

  insert into public.routines
    (day, time_start, time_end, subject, subject_code, teacher_name,
     teacher_code, room, batch, section, semester, is_active, is_service,
     routine_version_id)
  select r.day, r.time_start::time, r.time_end::time, r.subject, r.subject_code,
         r.teacher_name, r.teacher_code, r.room, r.batch, r.section,
         coalesce(r.semester, 0), true, coalesce(r.is_service, false), v_id
    from jsonb_to_recordset(p_rows) as r(
      day text, time_start text, time_end text, subject text,
      subject_code text, teacher_name text, teacher_code text, room text,
      batch text, section text, semester int, is_service boolean);
  get diagnostics v_count = row_count;

  update public.routine_versions
     set is_active = true, row_count = v_count, published_at = now()
   where id = v_id;

  return jsonb_build_object('version_id', v_id, 'row_count', v_count);
end
$function$;

revoke all on function public.publish_routine(jsonb, text, text, jsonb, jsonb, text) from public, anon, authenticated;
grant execute on function public.publish_routine(jsonb, text, text, jsonb, jsonb, text) to authenticated;

-- 3. Restore `routine_versions` indexes & constraints
delete from public.routine_versions where source = 'rollback';
update public.routine_versions set is_active = false where is_active = true and id not in (
  select id from public.routine_versions where is_active = true order by published_at desc nulls last limit 1
);

drop index if exists public.routine_versions_active_scope_uniq;
drop index if exists public.routine_versions_active_global_uniq;
create unique index if not exists routine_versions_one_active
  on public.routine_versions using btree (is_active) where is_active;

alter table if exists public.routine_versions
  drop constraint if exists routine_versions_source_check;
alter table if exists public.routine_versions
  add constraint routine_versions_source_check
  check (source = any (array['engine'::text, 'upload'::text, 'manual'::text]));

alter table if exists public.routine_versions
  drop column if exists scheduling_scope_id,
  drop column if exists revision_id,
  drop column if exists revision_version,
  drop column if exists policy_snapshot_id,
  drop column if exists storage_path,
  drop column if exists snapshot_rows,
  drop column if exists restored_from_version_id;

-- 4. Remove co-teacher column & GIN index on `public.routines`
drop index if exists public.routines_teacher_codes_gin_idx;
alter table if exists public.routines
  drop column if exists teacher_codes;

-- 5. Drop `public.solver_jobs`
drop table if exists public.solver_jobs;

commit;
