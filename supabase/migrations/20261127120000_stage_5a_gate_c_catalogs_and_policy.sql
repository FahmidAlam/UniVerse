-- ============================================================
-- MIGRATION 20261127120000 — Stage 5A (Gate C):
-- Persistent Catalogs, PolicySnapshots & Validation Artifacts
-- ============================================================
-- Strictly additive (Expand-Contract). Safe & idempotent for
-- Supabase Dashboard -> SQL Editor on Staging (oqwvxplteqtlrhktsplj)
-- before Production promotion (yxqyrjyzxitrgkhgauli).
--
-- Does NOT drop or rename any legacy column or alter publish_routine().
-- ============================================================

begin;

-- ─── 1. Private Helpers (schema-qualified, search_path = '') ─────────────

create or replace function academic_private.is_valid_consecutive_weekend(days text[])
returns boolean
language sql
immutable
strict
set search_path = ''
as $$
  with week as (
    select array['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday']::text[] as arr
  ),
  pos as (
    select
      array_position(w.arr, days[1]) as p1,
      array_position(w.arr, days[2]) as p2
    from week w
  )
  select
    cardinality(days) = 2
    and days[1] is not null
    and days[2] is not null
    and days[1] <> days[2]
    and p1 is not null
    and p2 is not null
    and ((p2 - p1 + 7) % 7) in (1, 6)
  from pos;
$$;

revoke all on function academic_private.is_valid_consecutive_weekend(text[]) from public, anon, authenticated;
grant execute on function academic_private.is_valid_consecutive_weekend(text[]) to authenticated;

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

-- ─── 2. Persistent Course Catalog (`public.catalog_courses`) ─────────────

create table if not exists public.catalog_courses (
  id uuid primary key default gen_random_uuid(),
  code text not null check (academic_private.label_key(code) <> ''),
  title text not null check (academic_private.label_key(title) <> ''),
  department_id uuid references public.departments(id) on delete set null,
  dept_code text not null default 'CSE' check (btrim(dept_code) <> ''),
  credit numeric(3,1) not null default 3.0 check (credit > 0 and credit <= 12),
  class_type text not null default 'theory' check (class_type in ('theory', 'lab')),
  is_service boolean not null default false,
  is_physics_lab boolean not null default false,
  default_weekly_sessions int check (
    default_weekly_sessions is null or default_weekly_sessions between 1 and 14
  ),
  is_active boolean not null default true,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists catalog_courses_code_uniq
  on public.catalog_courses (academic_private.label_key(code));

create index if not exists catalog_courses_dept_idx
  on public.catalog_courses (department_id);

drop trigger if exists catalog_courses_touch_updated_at on public.catalog_courses;
create trigger catalog_courses_touch_updated_at
  before update on public.catalog_courses
  for each row execute function academic_private.touch_updated_at();

alter table public.catalog_courses enable row level security;
revoke all on table public.catalog_courses from public, anon, authenticated;
grant select, insert, update, delete on table public.catalog_courses to authenticated;

drop policy if exists catalog_courses_select_admin on public.catalog_courses;
create policy catalog_courses_select_admin on public.catalog_courses
  for select to authenticated
  using (public.is_admin());

drop policy if exists catalog_courses_write_admin on public.catalog_courses;
create policy catalog_courses_write_admin on public.catalog_courses
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- ─── 3. Batches / Sections & R1-R2 Overrides (`public.section_policies`) ─

create table if not exists public.section_policies (
  id uuid primary key default gen_random_uuid(),
  cohort_id uuid references public.cohorts(id) on delete set null,
  student_group_id uuid references public.student_groups(id) on delete set null,
  batch text not null check (btrim(batch) <> ''),
  section text not null check (btrim(section) <> ''),
  calendar_system text not null default 'bi_semester'
    check (calendar_system in ('trimester', 'bi_semester')),
  weekend_override_days text[] check (
    weekend_override_days is null
    or academic_private.is_valid_consecutive_weekend(weekend_override_days)
  ),
  student_count int check (student_count is null or student_count > 0),
  is_active boolean not null default true,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (batch, section)
);

create unique index if not exists section_policies_norm_key
  on public.section_policies (
    academic_private.label_key(batch),
    academic_private.label_key(section)
  );

create index if not exists section_policies_cohort_idx
  on public.section_policies (cohort_id, student_group_id);

drop trigger if exists section_policies_touch_updated_at on public.section_policies;
create trigger section_policies_touch_updated_at
  before update on public.section_policies
  for each row execute function academic_private.touch_updated_at();

alter table public.section_policies enable row level security;
revoke all on table public.section_policies from public, anon, authenticated;
grant select, insert, update, delete on table public.section_policies to authenticated;

drop policy if exists section_policies_select_admin on public.section_policies;
create policy section_policies_select_admin on public.section_policies
  for select to authenticated
  using (public.is_admin());

drop policy if exists section_policies_write_admin on public.section_policies;
create policy section_policies_write_admin on public.section_policies
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- ─── 4. Extended Faculty Columns on `public.timetable_faculty` (R4-R9, D3-D4) ─

alter table public.timetable_faculty
  add column if not exists employment_type text not null default 'permanent',
  add column if not exists allow_three_off_days boolean not null default false,
  add column if not exists is_sust_adjunct boolean not null default false,
  add column if not exists external_blocked_slots jsonb not null default '[]'::jsonb,
  add column if not exists available_slots jsonb not null default '[]'::jsonb,
  add column if not exists preferred_slots jsonb not null default '[]'::jsonb;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'timetable_faculty_employment_type_ck'
      and conrelid = 'public.timetable_faculty'::regclass
  ) then
    alter table public.timetable_faculty
      add constraint timetable_faculty_employment_type_ck
      check (employment_type in ('permanent', 'adjunct', 'guest'));
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'timetable_faculty_external_blocked_slots_ck'
      and conrelid = 'public.timetable_faculty'::regclass
  ) then
    alter table public.timetable_faculty
      add constraint timetable_faculty_external_blocked_slots_ck
      check (jsonb_typeof(external_blocked_slots) = 'array');
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'timetable_faculty_available_slots_ck'
      and conrelid = 'public.timetable_faculty'::regclass
  ) then
    alter table public.timetable_faculty
      add constraint timetable_faculty_available_slots_ck
      check (jsonb_typeof(available_slots) = 'array');
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'timetable_faculty_preferred_slots_ck'
      and conrelid = 'public.timetable_faculty'::regclass
  ) then
    alter table public.timetable_faculty
      add constraint timetable_faculty_preferred_slots_ck
      check (jsonb_typeof(preferred_slots) = 'array');
  end if;
end $$;

-- ─── 5. Extended Room Columns on `public.timetable_rooms` (R10, R11, R14) ─

alter table public.timetable_rooms
  add column if not exists room_pool_role text not null default 'general',
  add column if not exists available_slots jsonb not null default '[]'::jsonb;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'timetable_rooms_pool_role_ck'
      and conrelid = 'public.timetable_rooms'::regclass
  ) then
    alter table public.timetable_rooms
      add constraint timetable_rooms_pool_role_ck
      check (room_pool_role in ('general', 'cse_lab', 'ecl_lab', 'physics_lab', 'gallery', 'other'));
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'timetable_rooms_available_slots_ck'
      and conrelid = 'public.timetable_rooms'::regclass
  ) then
    alter table public.timetable_rooms
      add constraint timetable_rooms_available_slots_ck
      check (jsonb_typeof(available_slots) = 'array');
  end if;
end $$;

-- Non-destructive backfill for rows still at default 'general'
update public.timetable_rooms
   set room_pool_role = case
     when is_gallery then 'gallery'
     when name ~* '^ECL([-_ \d]|$)' then 'ecl_lab'
     when is_lab and name ~* '(^|[^a-z])phy(sics)?([-_ \d]|$)' then 'physics_lab'
     when is_lab then 'cse_lab'
     else 'general'
   end
 where room_pool_role = 'general'
   and (
     is_gallery
     or is_lab
     or name ~* '^ECL([-_ \d]|$)'
   );

-- ─── 6. Versioned `public.policy_snapshots` (Gate C — R1-R16) ──────────

create table if not exists public.policy_snapshots (
  id uuid primary key default gen_random_uuid(),
  scheduling_scope_id uuid references public.scheduling_scopes(id) on delete set null,
  revision_id uuid references public.course_distribution_revisions(id) on delete set null,
  label text not null default 'Committee Policy Snapshot' check (btrim(label) <> ''),
  version int not null default 1 check (version > 0),
  is_active boolean not null default true,
  schema_version int not null default 1 check (schema_version = 1),
  default_section_weekend text[] not null default array['Friday', 'Saturday']
    check (academic_private.is_valid_consecutive_weekend(default_section_weekend)),
  batch_max_off_day_spread int not null default 1 check (batch_max_off_day_spread between 0 and 3),
  max_section_internal_gap int not null default 1 check (max_section_internal_gap between 0 and 3),
  allow_sessional_across_break boolean not null default false,
  physics_lab_course_codes text[] not null default '{}',
  policy_payload jsonb not null default '{}'::jsonb check (jsonb_typeof(policy_payload) = 'object'),
  policy_hash text not null check (policy_hash ~ '^[0-9a-f]{64}$'),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create unique index if not exists policy_snapshots_active_rev_uniq
  on public.policy_snapshots (revision_id)
  where is_active and revision_id is not null;

create unique index if not exists policy_snapshots_active_scope_uniq
  on public.policy_snapshots (scheduling_scope_id)
  where is_active and revision_id is null and scheduling_scope_id is not null;

create unique index if not exists policy_snapshots_active_global_uniq
  on public.policy_snapshots (is_active)
  where is_active and revision_id is null and scheduling_scope_id is null;

create index if not exists policy_snapshots_rev_ver_idx
  on public.policy_snapshots (revision_id, version desc);

alter table public.policy_snapshots enable row level security;
revoke all on table public.policy_snapshots from public, anon, authenticated;
grant select, insert, update, delete on table public.policy_snapshots to authenticated;

drop policy if exists policy_snapshots_select on public.policy_snapshots;
create policy policy_snapshots_select on public.policy_snapshots
  for select to authenticated
  using (
    public.is_admin()
    or (
      scheduling_scope_id is not null
      and academic_private.can_scope(scheduling_scope_id, 'read_catalog')
    )
  );

drop policy if exists policy_snapshots_write on public.policy_snapshots;
create policy policy_snapshots_write on public.policy_snapshots
  for all to authenticated
  using (
    public.is_admin()
    or (
      scheduling_scope_id is not null
      and academic_private.can_scope(scheduling_scope_id, 'manage_policy')
    )
  )
  with check (
    public.is_admin()
    or (
      scheduling_scope_id is not null
      and academic_private.can_scope(scheduling_scope_id, 'manage_policy')
    )
  );

-- ─── 7. Server-Persisted `validation_report` Artifacts ───────────────────

alter table public.course_distribution_artifacts
  add column if not exists policy_snapshot_id uuid references public.policy_snapshots(id) on delete set null,
  add column if not exists payload jsonb not null default '{}'::jsonb,
  add column if not exists summary jsonb not null default '{}'::jsonb,
  add column if not exists has_blockers boolean not null default false,
  add column if not exists computed_by uuid references auth.users(id) on delete set null,
  add column if not exists updated_at timestamptz not null default now();

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'course_distribution_artifacts_payload_ck'
      and conrelid = 'public.course_distribution_artifacts'::regclass
  ) then
    alter table public.course_distribution_artifacts
      add constraint course_distribution_artifacts_payload_ck
      check (jsonb_typeof(payload) = 'object');
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'course_distribution_artifacts_summary_ck'
      and conrelid = 'public.course_distribution_artifacts'::regclass
  ) then
    alter table public.course_distribution_artifacts
      add constraint course_distribution_artifacts_summary_ck
      check (jsonb_typeof(summary) = 'object');
  end if;
end $$;

create index if not exists course_distribution_artifacts_rev_kind_idx
  on public.course_distribution_artifacts (revision_id, artifact_kind, created_at desc);

-- ─── 8. Hardened Gate C RPCs (SECURITY DEFINER, search_path = '') ──────

create or replace function public.read_active_policy_snapshot(
  p_revision_id uuid default null,
  p_scope_id uuid default null
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope_id uuid := p_scope_id;
  v_snap public.policy_snapshots;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required to read policy snapshots' using errcode = '42501';
  end if;

  if v_scope_id is null and p_revision_id is not null then
    select s.scheduling_scope_id into v_scope_id
      from public.course_distribution_revisions r
      join public.course_distribution_sources s on s.id = r.source_id
     where r.id = p_revision_id;
  end if;

  if not (
    public.is_admin()
    or (v_scope_id is not null and academic_private.can_scope(v_scope_id, 'read_catalog'))
  ) then
    raise exception 'Policy snapshot read requires admin or scoped read_catalog capability' using errcode = '42501';
  end if;

  if p_revision_id is not null then
    select * into v_snap
      from public.policy_snapshots
     where revision_id = p_revision_id and is_active
     order by version desc, created_at desc
     limit 1;
    if found then
      return to_jsonb(v_snap);
    end if;
  end if;

  if v_scope_id is not null then
    select * into v_snap
      from public.policy_snapshots
     where scheduling_scope_id = v_scope_id and revision_id is null and is_active
     order by version desc, created_at desc
     limit 1;
    if found then
      return to_jsonb(v_snap);
    end if;
  end if;

  select * into v_snap
    from public.policy_snapshots
   where revision_id is null and scheduling_scope_id is null and is_active
   order by version desc, created_at desc
   limit 1;

  if found then
    return to_jsonb(v_snap);
  end if;

  return null;
end;
$$;

revoke all on function public.read_active_policy_snapshot(uuid, uuid) from public, anon, authenticated;
grant execute on function public.read_active_policy_snapshot(uuid, uuid) to authenticated;

create or replace function public.save_policy_snapshot(
  p_revision_id uuid default null,
  p_scope_id uuid default null,
  p_label text default 'Committee Policy Snapshot',
  p_default_section_weekend text[] default array['Friday', 'Saturday'],
  p_batch_max_off_day_spread int default 1,
  p_max_section_internal_gap int default 1,
  p_allow_sessional_across_break boolean default false,
  p_physics_lab_course_codes text[] default '{}',
  p_policy_payload jsonb default '{}'::jsonb
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_scope_id uuid := p_scope_id;
  v_label text := coalesce(nullif(btrim(p_label), ''), 'Committee Policy Snapshot');
  v_weekend text[] := coalesce(p_default_section_weekend, array['Friday', 'Saturday']);
  v_spread int := coalesce(p_batch_max_off_day_spread, 1);
  v_gap int := coalesce(p_max_section_internal_gap, 1);
  v_cross_break boolean := coalesce(p_allow_sessional_across_break, false);
  v_physics text[];
  v_payload jsonb := coalesce(p_policy_payload, '{}'::jsonb);
  v_canonical jsonb;
  v_hash text;
  v_next_version int;
  v_inserted public.policy_snapshots;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required to save policy snapshots' using errcode = '42501';
  end if;

  if p_revision_id is not null then
    select s.scheduling_scope_id into v_scope_id
      from public.course_distribution_revisions r
      join public.course_distribution_sources s on s.id = r.source_id
     where r.id = p_revision_id;
    if not found then
      raise exception 'Unknown course distribution revision' using errcode = 'P0002';
    end if;
    v_scope_id := coalesce(p_scope_id, v_scope_id);
  end if;

  if not (
    public.is_admin()
    or (v_scope_id is not null and academic_private.can_scope(v_scope_id, 'manage_policy'))
  ) then
    raise exception 'Policy snapshot write requires admin or scoped manage_policy capability' using errcode = '42501';
  end if;

  if not academic_private.is_valid_consecutive_weekend(v_weekend) then
    raise exception 'default_section_weekend must be 2 distinct consecutive weekdays' using errcode = '23514';
  end if;

  if v_spread < 0 or v_spread > 3 or v_gap < 0 or v_gap > 3 then
    raise exception 'Spread and gap bounds must be between 0 and 3' using errcode = '23514';
  end if;

  if jsonb_typeof(v_payload) <> 'object' then
    raise exception 'policy_payload must be a JSON object' using errcode = '22023';
  end if;

  select coalesce(array_agg(distinct upper(btrim(c)) order by upper(btrim(c))), '{}'::text[])
    into v_physics
    from unnest(coalesce(p_physics_lab_course_codes, '{}'::text[])) as c
   where btrim(coalesce(c, '')) <> '';

  v_canonical := jsonb_build_object(
    'schema_version', 1,
    'revision_id', p_revision_id,
    'scheduling_scope_id', v_scope_id,
    'default_section_weekend', v_weekend,
    'batch_max_off_day_spread', v_spread,
    'max_section_internal_gap', v_gap,
    'allow_sessional_across_break', v_cross_break,
    'physics_lab_course_codes', v_physics,
    'policy_payload', v_payload
  );

  v_hash := encode(extensions.digest(convert_to(v_canonical::text, 'UTF8'), 'sha256'), 'hex');

  if p_revision_id is not null then
    select coalesce(max(version), 0) + 1 into v_next_version
      from public.policy_snapshots
     where revision_id = p_revision_id;

    update public.policy_snapshots
       set is_active = false
     where revision_id = p_revision_id and is_active;
  elsif v_scope_id is not null then
    select coalesce(max(version), 0) + 1 into v_next_version
      from public.policy_snapshots
     where scheduling_scope_id = v_scope_id and revision_id is null;

    update public.policy_snapshots
       set is_active = false
     where scheduling_scope_id = v_scope_id and revision_id is null and is_active;
  else
    select coalesce(max(version), 0) + 1 into v_next_version
      from public.policy_snapshots
     where revision_id is null and scheduling_scope_id is null;

    update public.policy_snapshots
       set is_active = false
     where revision_id is null and scheduling_scope_id is null and is_active;
  end if;

  insert into public.policy_snapshots (
    scheduling_scope_id,
    revision_id,
    label,
    version,
    is_active,
    schema_version,
    default_section_weekend,
    batch_max_off_day_spread,
    max_section_internal_gap,
    allow_sessional_across_break,
    physics_lab_course_codes,
    policy_payload,
    policy_hash,
    created_by
  ) values (
    v_scope_id,
    p_revision_id,
    v_label,
    v_next_version,
    true,
    1,
    v_weekend,
    v_spread,
    v_gap,
    v_cross_break,
    v_physics,
    v_payload,
    v_hash,
    auth.uid()
  )
  returning * into v_inserted;

  if p_revision_id is not null then
    update public.course_distribution_artifacts
       set status = 'stale',
           invalidated_at = now(),
           updated_at = now()
     where revision_id = p_revision_id
       and artifact_kind = 'validation_report'
       and status = 'current';
  end if;

  return to_jsonb(v_inserted);
end;
$$;

revoke all on function public.save_policy_snapshot(uuid, uuid, text, text[], int, int, boolean, text[], jsonb) from public, anon, authenticated;
grant execute on function public.save_policy_snapshot(uuid, uuid, text, text[], int, int, boolean, text[], jsonb) to authenticated;

create or replace function public.save_validation_report_artifact(
  p_revision_id uuid,
  p_policy_snapshot_id uuid default null,
  p_payload jsonb default '{}'::jsonb,
  p_summary jsonb default '{}'::jsonb,
  p_has_blockers boolean default false
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_scope_id uuid;
  v_payload jsonb := coalesce(p_payload, '{}'::jsonb);
  v_summary jsonb := coalesce(p_summary, '{}'::jsonb);
  v_inserted public.course_distribution_artifacts;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required to save validation reports' using errcode = '42501';
  end if;

  if p_revision_id is null then
    raise exception 'p_revision_id is required' using errcode = '22023';
  end if;

  select s.scheduling_scope_id into v_scope_id
    from public.course_distribution_revisions r
    join public.course_distribution_sources s on s.id = r.source_id
   where r.id = p_revision_id
   for update;

  if not found then
    raise exception 'Unknown course distribution revision' using errcode = 'P0002';
  end if;

  if not (
    public.is_admin()
    or (
      v_scope_id is not null
      and (
        academic_private.can_scope(v_scope_id, 'review')
        or academic_private.can_scope(v_scope_id, 'manage_policy')
      )
    )
  ) then
    raise exception 'Validation artifact persistence requires admin or scoped review/manage_policy capability' using errcode = '42501';
  end if;

  if jsonb_typeof(v_payload) <> 'object' or jsonb_typeof(v_summary) <> 'object' then
    raise exception 'Validation payload and summary must be JSON objects' using errcode = '22023';
  end if;

  update public.course_distribution_artifacts
     set status = 'stale',
         invalidated_at = now(),
         updated_at = now()
   where revision_id = p_revision_id
     and artifact_kind = 'validation_report'
     and status = 'current';

  insert into public.course_distribution_artifacts (
    revision_id,
    artifact_kind,
    status,
    invalidated_at,
    policy_snapshot_id,
    payload,
    summary,
    has_blockers,
    computed_by,
    updated_at
  ) values (
    p_revision_id,
    'validation_report',
    'current',
    null,
    p_policy_snapshot_id,
    v_payload,
    v_summary,
    coalesce(p_has_blockers, false),
    auth.uid(),
    now()
  )
  returning * into v_inserted;

  return to_jsonb(v_inserted);
end;
$$;

revoke all on function public.save_validation_report_artifact(uuid, uuid, jsonb, jsonb, boolean) from public, anon, authenticated;
grant execute on function public.save_validation_report_artifact(uuid, uuid, jsonb, jsonb, boolean) to authenticated;

commit;
