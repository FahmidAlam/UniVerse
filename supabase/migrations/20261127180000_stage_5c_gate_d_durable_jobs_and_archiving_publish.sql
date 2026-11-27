-- ============================================================
-- MIGRATION 20261127180000 — Stage 5C (Wave 2B Final · Gate D):
-- Durable Solver Jobs, Co-Teachers (`teacher_codes`), Snapshot-Archiving
-- `publish_routine()`, and 1-Click `restore_routine_version()`
-- ============================================================
-- Strictly additive (Expand-Contract). Idempotent for Supabase Dashboard ->
-- SQL Editor on Staging (oqwvxplteqtlrhktsplj) before Production promotion
-- (yxqyrjyzxitrgkhgauli).
--
-- Does NOT drop or rename any column read by live Flutter Android/iOS builds.
-- ============================================================

begin;

-- ─── 1. Ensure `academic_private.touch_updated_at()` exists ─────────────────

create or replace function academic_private.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

revoke all on function academic_private.touch_updated_at() from public, anon, authenticated;

-- ─── 2. Durable Solver Jobs Table (`public.solver_jobs`) ─────────────────────

create table if not exists public.solver_jobs (
  job_id text primary key,
  scheduling_scope_id uuid references public.scheduling_scopes(id) on delete set null,
  revision_id uuid references public.course_distribution_revisions(id) on delete set null,
  revision_version int,
  policy_snapshot_id uuid references public.policy_snapshots(id) on delete set null,
  semester_label text,
  state text not null check (state in ('queued', 'ingesting', 'solving', 'rendering', 'done', 'failed')),
  progress double precision not null default 0 check (progress >= 0 and progress <= 1),
  outcome text,
  raw_status text,
  termination_reason text,
  proven_infeasible boolean not null default false,
  conflicts jsonb not null default '[]'::jsonb,
  stats jsonb,
  validation jsonb,
  report jsonb,
  rows jsonb,
  service_rows jsonb,
  source_contract jsonb,
  workbook_storage_path text,
  error text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists solver_jobs_created_at_idx
  on public.solver_jobs (created_at desc);

create index if not exists solver_jobs_revision_created_idx
  on public.solver_jobs (revision_id, created_at desc);

create index if not exists solver_jobs_state_idx
  on public.solver_jobs (state);

drop trigger if exists solver_jobs_touch_updated_at on public.solver_jobs;
create trigger solver_jobs_touch_updated_at
  before update on public.solver_jobs
  for each row execute function academic_private.touch_updated_at();

alter table public.solver_jobs enable row level security;
revoke all on table public.solver_jobs from public, anon, authenticated;
grant select, insert, update, delete on table public.solver_jobs to authenticated;

drop policy if exists solver_jobs_select on public.solver_jobs;
create policy solver_jobs_select on public.solver_jobs
  for select to authenticated
  using (
    public.is_admin()
    or (
      scheduling_scope_id is not null
      and academic_private.can_scope(scheduling_scope_id, 'read_catalog')
    )
  );

drop policy if exists solver_jobs_write_admin on public.solver_jobs;
create policy solver_jobs_write_admin on public.solver_jobs
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- ─── 3. Co-Teacher Array Storage on `public.routines` ──────────────────────

alter table public.routines
  add column if not exists teacher_codes text[] not null default '{}';

update public.routines
   set teacher_codes = array[btrim(teacher_code)]
 where cardinality(teacher_codes) = 0
   and teacher_code is not null
   and btrim(teacher_code) <> '';

create index if not exists routines_teacher_codes_gin_idx
  on public.routines using gin (teacher_codes);

-- ─── 4. Snapshot-Recoverable Metadata on `public.routine_versions` ─────────

alter table public.routine_versions
  add column if not exists scheduling_scope_id uuid references public.scheduling_scopes(id) on delete set null,
  add column if not exists revision_id uuid references public.course_distribution_revisions(id) on delete set null,
  add column if not exists revision_version int,
  add column if not exists policy_snapshot_id uuid references public.policy_snapshots(id) on delete set null,
  add column if not exists storage_path text,
  add column if not exists snapshot_rows jsonb,
  add column if not exists restored_from_version_id uuid references public.routine_versions(id) on delete set null;

alter table public.routine_versions
  drop constraint if exists routine_versions_source_check;

alter table public.routine_versions
  add constraint routine_versions_source_check
  check (source = any (array['engine'::text, 'upload'::text, 'manual'::text, 'rollback'::text]));

drop index if exists public.routine_versions_one_active;

create unique index if not exists routine_versions_active_scope_uniq
  on public.routine_versions (scheduling_scope_id)
  where is_active and scheduling_scope_id is not null;

create unique index if not exists routine_versions_active_global_uniq
  on public.routine_versions (is_active)
  where is_active and scheduling_scope_id is null;

-- ─── 5. Upgrade `public.publish_routine(...)` (Non-Destructive Archival) ────

drop function if exists public.publish_routine(jsonb, text, text, jsonb, jsonb, text);
drop function if exists public.publish_routine(
  jsonb, text, text, jsonb, jsonb, text,
  uuid, uuid, int, uuid, text, boolean
);

create or replace function public.publish_routine(
  p_rows jsonb,
  p_semester_label text default null,
  p_source text default 'engine',
  p_stats jsonb default '{}'::jsonb,
  p_validation jsonb default '{}'::jsonb,
  p_notes text default null,
  p_scheduling_scope_id uuid default null,
  p_revision_id uuid default null,
  p_revision_version int default null,
  p_policy_snapshot_id uuid default null,
  p_storage_path text default null,
  p_require_fresh_validation boolean default false
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
  v_count int;
  v_archived_count int := 0;
  v_scope_id uuid := p_scheduling_scope_id;
  v_rev record;
  v_rev_version int := p_revision_version;
  v_out_ver record;
  v_out_snapshot jsonb;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required to publish a routine.'
      using errcode = '42501';
  end if;

  if p_revision_id is not null then
    select s.scheduling_scope_id
      into v_rev
      from public.course_distribution_revisions r
      join public.course_distribution_sources s on s.id = r.source_id
     where r.id = p_revision_id;

    if not found then
      if not public.is_admin() then
        raise exception 'Only an admin or scoped publisher may publish a routine.'
          using errcode = '42501';
      end if;
      raise exception 'Unknown course distribution revision.'
        using errcode = 'P0002';
    end if;

    if v_scope_id is not null
       and v_rev.scheduling_scope_id is not null
       and v_scope_id <> v_rev.scheduling_scope_id then
      raise exception 'Revision scheduling scope mismatch.'
        using errcode = '42501';
    end if;

    v_scope_id := coalesce(v_rev.scheduling_scope_id, v_scope_id);
  end if;

  if not (
    public.is_admin()
    or (v_scope_id is not null and academic_private.can_scope(v_scope_id, 'publish'))
  ) then
    raise exception 'Only an admin or scoped publisher may publish a routine.'
      using errcode = '42501';
  end if;

  if p_rows is null
     or jsonb_typeof(p_rows) <> 'array'
     or jsonb_array_length(p_rows) = 0 then
    raise exception 'Refusing to publish an empty routine.'
      using errcode = '22023';
  end if;

  if coalesce(p_source, 'engine') not in ('engine', 'upload', 'manual', 'rollback') then
    raise exception 'Unsupported routine publication source: %', p_source
      using errcode = '22023';
  end if;

  if p_revision_id is not null then
    select r.id, r.status, r.revision_version, s.scheduling_scope_id
      into v_rev
      from public.course_distribution_revisions r
      join public.course_distribution_sources s on s.id = r.source_id
     where r.id = p_revision_id
     for update of r;

    if not found then
      raise exception 'Unknown course distribution revision.'
        using errcode = 'P0002';
    end if;

    v_scope_id := coalesce(v_scope_id, v_rev.scheduling_scope_id);

    if v_rev.status <> 'accepted' then
      raise exception 'Only an accepted course distribution revision can be published.'
        using errcode = '23514';
    end if;

    if p_revision_version is not null and v_rev.revision_version <> p_revision_version then
      raise exception 'Stale course distribution revision (expected v%, current v%).',
        p_revision_version, v_rev.revision_version
        using errcode = '40001';
    end if;

    v_rev_version := coalesce(v_rev_version, v_rev.revision_version);

    if coalesce(p_require_fresh_validation, false) then
      if not exists (
        select 1
          from public.course_distribution_artifacts a
         where a.revision_id = p_revision_id
           and a.artifact_kind = 'validation_report'
           and a.status = 'current'
           and a.has_blockers = false
      ) then
        raise exception 'Fresh passing validation_report artifact is required before publishing.'
          using errcode = '23514';
      end if;
    end if;
  end if;

  -- Preserve outgoing active rows into `routine_versions.snapshot_rows` when missing
  for v_out_ver in
    select id, snapshot_rows
      from public.routine_versions
     where is_active = true
       and (
         (v_scope_id is null and scheduling_scope_id is null)
         or scheduling_scope_id = v_scope_id
       )
  loop
    if v_out_ver.snapshot_rows is null then
      select coalesce(
        jsonb_agg(
          jsonb_build_object(
            'day', r.day,
            'time_start', to_char(r.time_start, 'HH24:MI:SS'),
            'time_end', to_char(r.time_end, 'HH24:MI:SS'),
            'subject', r.subject,
            'subject_code', r.subject_code,
            'teacher_name', r.teacher_name,
            'teacher_code', r.teacher_code,
            'teacher_codes', to_jsonb(
              case
                when cardinality(r.teacher_codes) > 0 then r.teacher_codes
                when r.teacher_code is not null and btrim(r.teacher_code) <> '' then array[btrim(r.teacher_code)]
                else '{}'::text[]
              end
            ),
            'room', r.room,
            'batch', r.batch,
            'section', r.section,
            'semester', r.semester,
            'is_service', r.is_service
          )
        ),
        '[]'::jsonb
      )
      into v_out_snapshot
      from public.routines r
      where r.routine_version_id = v_out_ver.id
         or (r.is_active = true and r.routine_version_id is null);

      update public.routine_versions
         set snapshot_rows = v_out_snapshot
       where id = v_out_ver.id;
    end if;
  end loop;

  -- Non-destructive archival: deactivate prior active version(s) & routine rows (ZERO DELETE)
  update public.routine_versions
     set is_active = false
   where is_active = true
     and (
       (v_scope_id is null and scheduling_scope_id is null)
       or scheduling_scope_id = v_scope_id
     );

  update public.routines
     set is_active = false
   where is_active = true
     and (v_scope_id is null or scheduling_scope_id = v_scope_id);
  get diagnostics v_archived_count = row_count;

  insert into public.routine_versions (
    semester_label,
    source,
    is_active,
    row_count,
    stats,
    validation,
    notes,
    published_at,
    published_by,
    scheduling_scope_id,
    revision_id,
    revision_version,
    policy_snapshot_id,
    storage_path,
    snapshot_rows
  ) values (
    p_semester_label,
    coalesce(p_source, 'engine'),
    true,
    0,
    coalesce(p_stats, '{}'::jsonb),
    coalesce(p_validation, '{}'::jsonb),
    p_notes,
    now(),
    auth.uid(),
    v_scope_id,
    p_revision_id,
    v_rev_version,
    p_policy_snapshot_id,
    p_storage_path,
    p_rows
  )
  returning id into v_id;

  insert into public.routines (
    day,
    time_start,
    time_end,
    subject,
    subject_code,
    teacher_name,
    teacher_code,
    teacher_codes,
    room,
    batch,
    section,
    semester,
    is_active,
    is_service,
    routine_version_id,
    scheduling_scope_id
  )
  select
    elem->>'day',
    (elem->>'time_start')::time,
    (elem->>'time_end')::time,
    elem->>'subject',
    elem->>'subject_code',
    nullif(btrim(elem->>'teacher_name'), ''),
    coalesce(nullif(btrim(elem->>'teacher_code'), ''), parsed.codes[1]),
    parsed.codes,
    coalesce(nullif(btrim(elem->>'room'), ''), 'TBA'),
    elem->>'batch',
    coalesce(elem->>'section', ''),
    coalesce((elem->>'semester')::int, 0),
    true,
    coalesce((elem->>'is_service')::boolean, false),
    v_id,
    v_scope_id
  from jsonb_array_elements(p_rows) as elem
  cross join lateral (
    select
      case
        when jsonb_typeof(elem->'teacher_codes') = 'array'
             and jsonb_array_length(elem->'teacher_codes') > 0 then
          coalesce((
            select array_agg(sub.clean_val order by sub.first_ord)
              from (
                select btrim(val) as clean_val, min(ord) as first_ord
                  from jsonb_array_elements_text(elem->'teacher_codes') with ordinality as t(val, ord)
                 where btrim(coalesce(val, '')) <> ''
                 group by btrim(val)
              ) as sub
          ), '{}'::text[])
        when jsonb_typeof(elem->'teachers') = 'array'
             and jsonb_array_length(elem->'teachers') > 0 then
          coalesce((
            select array_agg(sub.clean_val order by sub.first_ord)
              from (
                select btrim(val) as clean_val, min(ord) as first_ord
                  from jsonb_array_elements_text(elem->'teachers') with ordinality as t(val, ord)
                 where btrim(coalesce(val, '')) <> ''
                 group by btrim(val)
              ) as sub
          ), '{}'::text[])
        when nullif(btrim(elem->>'teacher_code'), '') is not null then
          array[btrim(elem->>'teacher_code')]
        else
          '{}'::text[]
      end as codes
  ) as parsed;
  get diagnostics v_count = row_count;

  update public.routine_versions
     set row_count = v_count
   where id = v_id;

  return jsonb_build_object(
    'version_id', v_id,
    'row_count', v_count,
    'archived_count', v_archived_count,
    'storage_path', p_storage_path
  );
end;
$$;

revoke all on function public.publish_routine(
  jsonb, text, text, jsonb, jsonb, text, uuid, uuid, int, uuid, text, boolean
) from public, anon, authenticated;
grant execute on function public.publish_routine(
  jsonb, text, text, jsonb, jsonb, text, uuid, uuid, int, uuid, text, boolean
) to authenticated;

-- ─── 6. New `public.restore_routine_version(...)` (Archive v2b Rollback) ───

create or replace function public.restore_routine_version(
  p_version_id uuid,
  p_notes text default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_target public.routine_versions;
  v_rows jsonb;
  v_new_id uuid;
  v_count int;
  v_archived_count int := 0;
  v_out_ver record;
  v_out_snapshot jsonb;
  v_note text;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required to restore a routine version.'
      using errcode = '42501';
  end if;

  if p_version_id is null then
    if not public.is_admin() then
      raise exception 'Only an admin or scoped publisher may restore a routine version.'
        using errcode = '42501';
    end if;
    raise exception 'p_version_id is required.'
      using errcode = '22023';
  end if;

  select * into v_target
    from public.routine_versions
   where id = p_version_id;

  if not found then
    if not public.is_admin() then
      raise exception 'Only an admin or scoped publisher may restore a routine version.'
        using errcode = '42501';
    end if;
    raise exception 'Unknown routine version: %', p_version_id
      using errcode = 'P0002';
  end if;

  if not (
    public.is_admin()
    or (
      v_target.scheduling_scope_id is not null
      and academic_private.can_scope(v_target.scheduling_scope_id, 'publish')
    )
  ) then
    raise exception 'Only an admin or scoped publisher may restore a routine version.'
      using errcode = '42501';
  end if;

  v_rows := v_target.snapshot_rows;
  if v_rows is null
     or jsonb_typeof(v_rows) <> 'array'
     or jsonb_array_length(v_rows) = 0 then
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'day', r.day,
          'time_start', to_char(r.time_start, 'HH24:MI:SS'),
          'time_end', to_char(r.time_end, 'HH24:MI:SS'),
          'subject', r.subject,
          'subject_code', r.subject_code,
          'teacher_name', r.teacher_name,
          'teacher_code', r.teacher_code,
          'teacher_codes', to_jsonb(
            case
              when cardinality(r.teacher_codes) > 0 then r.teacher_codes
              when r.teacher_code is not null and btrim(r.teacher_code) <> '' then array[btrim(r.teacher_code)]
              else '{}'::text[]
            end
          ),
          'room', r.room,
          'batch', r.batch,
          'section', r.section,
          'semester', r.semester,
          'is_service', r.is_service
        )
      ),
      '[]'::jsonb
    )
    into v_rows
    from public.routines r
    where r.routine_version_id = p_version_id;
  end if;

  if v_rows is null
     or jsonb_typeof(v_rows) <> 'array'
     or jsonb_array_length(v_rows) = 0 then
    raise exception 'Target routine version has no recoverable snapshot rows.'
      using errcode = '22023';
  end if;

  -- Preserve outgoing active rows before deactivating
  for v_out_ver in
    select id, snapshot_rows
      from public.routine_versions
     where is_active = true
       and (
         (v_target.scheduling_scope_id is null and scheduling_scope_id is null)
         or scheduling_scope_id = v_target.scheduling_scope_id
       )
  loop
    if v_out_ver.snapshot_rows is null then
      select coalesce(
        jsonb_agg(
          jsonb_build_object(
            'day', r.day,
            'time_start', to_char(r.time_start, 'HH24:MI:SS'),
            'time_end', to_char(r.time_end, 'HH24:MI:SS'),
            'subject', r.subject,
            'subject_code', r.subject_code,
            'teacher_name', r.teacher_name,
            'teacher_code', r.teacher_code,
            'teacher_codes', to_jsonb(
              case
                when cardinality(r.teacher_codes) > 0 then r.teacher_codes
                when r.teacher_code is not null and btrim(r.teacher_code) <> '' then array[btrim(r.teacher_code)]
                else '{}'::text[]
              end
            ),
            'room', r.room,
            'batch', r.batch,
            'section', r.section,
            'semester', r.semester,
            'is_service', r.is_service
          )
        ),
        '[]'::jsonb
      )
      into v_out_snapshot
      from public.routines r
      where r.routine_version_id = v_out_ver.id;

      update public.routine_versions
         set snapshot_rows = v_out_snapshot
       where id = v_out_ver.id;
    end if;
  end loop;

  update public.routine_versions
     set is_active = false
   where is_active = true
     and (
       (v_target.scheduling_scope_id is null and scheduling_scope_id is null)
       or scheduling_scope_id = v_target.scheduling_scope_id
     );

  update public.routines
     set is_active = false
   where is_active = true
     and (v_target.scheduling_scope_id is null or scheduling_scope_id = v_target.scheduling_scope_id);
  get diagnostics v_archived_count = row_count;

  v_note := coalesce(
    nullif(btrim(p_notes), ''),
    'Rolled back to version ' || coalesce(v_target.semester_label, p_version_id::text)
  );

  insert into public.routine_versions (
    semester_label,
    source,
    is_active,
    row_count,
    stats,
    validation,
    notes,
    published_at,
    published_by,
    scheduling_scope_id,
    revision_id,
    revision_version,
    policy_snapshot_id,
    storage_path,
    snapshot_rows,
    restored_from_version_id
  ) values (
    v_target.semester_label,
    'rollback',
    true,
    0,
    coalesce(v_target.stats, '{}'::jsonb),
    coalesce(v_target.validation, '{}'::jsonb),
    v_note,
    now(),
    auth.uid(),
    v_target.scheduling_scope_id,
    v_target.revision_id,
    v_target.revision_version,
    v_target.policy_snapshot_id,
    v_target.storage_path,
    v_rows,
    p_version_id
  )
  returning id into v_new_id;

  insert into public.routines (
    day,
    time_start,
    time_end,
    subject,
    subject_code,
    teacher_name,
    teacher_code,
    teacher_codes,
    room,
    batch,
    section,
    semester,
    is_active,
    is_service,
    routine_version_id,
    scheduling_scope_id
  )
  select
    elem->>'day',
    (elem->>'time_start')::time,
    (elem->>'time_end')::time,
    elem->>'subject',
    elem->>'subject_code',
    nullif(btrim(elem->>'teacher_name'), ''),
    coalesce(nullif(btrim(elem->>'teacher_code'), ''), parsed.codes[1]),
    parsed.codes,
    coalesce(nullif(btrim(elem->>'room'), ''), 'TBA'),
    elem->>'batch',
    coalesce(elem->>'section', ''),
    coalesce((elem->>'semester')::int, 0),
    true,
    coalesce((elem->>'is_service')::boolean, false),
    v_new_id,
    v_target.scheduling_scope_id
  from jsonb_array_elements(v_rows) as elem
  cross join lateral (
    select
      case
        when jsonb_typeof(elem->'teacher_codes') = 'array'
             and jsonb_array_length(elem->'teacher_codes') > 0 then
          coalesce((
            select array_agg(sub.clean_val order by sub.first_ord)
              from (
                select btrim(val) as clean_val, min(ord) as first_ord
                  from jsonb_array_elements_text(elem->'teacher_codes') with ordinality as t(val, ord)
                 where btrim(coalesce(val, '')) <> ''
                 group by btrim(val)
              ) as sub
          ), '{}'::text[])
        when jsonb_typeof(elem->'teachers') = 'array'
             and jsonb_array_length(elem->'teachers') > 0 then
          coalesce((
            select array_agg(sub.clean_val order by sub.first_ord)
              from (
                select btrim(val) as clean_val, min(ord) as first_ord
                  from jsonb_array_elements_text(elem->'teachers') with ordinality as t(val, ord)
                 where btrim(coalesce(val, '')) <> ''
                 group by btrim(val)
              ) as sub
          ), '{}'::text[])
        when nullif(btrim(elem->>'teacher_code'), '') is not null then
          array[btrim(elem->>'teacher_code')]
        else
          '{}'::text[]
      end as codes
  ) as parsed;
  get diagnostics v_count = row_count;

  update public.routine_versions
     set row_count = v_count
   where id = v_new_id;

  return jsonb_build_object(
    'version_id', v_new_id,
    'restored_from_version_id', p_version_id,
    'row_count', v_count,
    'archived_count', v_archived_count,
    'storage_path', v_target.storage_path
  );
end;
$$;

revoke all on function public.restore_routine_version(uuid, text) from public, anon, authenticated;
grant execute on function public.restore_routine_version(uuid, text) to authenticated;

commit;
