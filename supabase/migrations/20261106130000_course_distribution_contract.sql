-- Phase 2a: immutable Course Distribution source and accepted-revision ledger.
-- No editor UI, hosted deployment, or legacy workbook rewrite is introduced here.
begin;

create table public.course_distribution_sources (
  id uuid primary key default gen_random_uuid(),
  scheduling_scope_id uuid references public.scheduling_scopes(id),
  source_hash text not null check (source_hash ~ '^[0-9a-f]{64}$'),
  source_bytes bytea not null check (octet_length(source_bytes) > 0),
  sheet_name text not null check (btrim(sheet_name) <> ''),
  uploaded_by uuid references auth.users(id),
  uploaded_at timestamptz not null default now(),
  unique (scheduling_scope_id, source_hash)
);

create table public.course_distribution_revisions (
  id uuid primary key default gen_random_uuid(),
  source_id uuid not null references public.course_distribution_sources(id),
  parent_revision_id uuid references public.course_distribution_revisions(id),
  revision_number integer not null check (revision_number > 0),
  revision_version integer not null default 1 check (revision_version > 0),
  status text not null check (status in ('accepted', 'superseded', 'invalid')),
  correction_reason text not null check (btrim(correction_reason) <> ''),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (source_id, revision_number),
  unique (id, source_id),
  check (parent_revision_id is null or parent_revision_id <> id)
);

create unique index course_distribution_one_accepted_revision
  on public.course_distribution_revisions(source_id) where status = 'accepted';

create table public.course_distribution_corrections (
  id uuid primary key default gen_random_uuid(),
  revision_id uuid not null references public.course_distribution_revisions(id),
  source_row integer not null check (source_row >= 6),
  source_column text not null check (source_column ~ '^(A|B|C|D|E|F|G|H|I|J|K|L)$'),
  original_formula jsonb,
  original_cached_value jsonb,
  effective_value jsonb not null,
  correction_reason text not null check (btrim(correction_reason) <> ''),
  corrected_by uuid references auth.users(id),
  corrected_at timestamptz not null default now(),
  unique (revision_id, source_row, source_column)
);

create table public.course_distribution_artifacts (
  id uuid primary key default gen_random_uuid(),
  revision_id uuid not null references public.course_distribution_revisions(id),
  artifact_kind text not null check (artifact_kind in ('normalized_input', 'validation_report', 'generation_output')),
  status text not null default 'current' check (status in ('current', 'stale')),
  invalidated_at timestamptz,
  created_at timestamptz not null default now(),
  check ((status = 'current' and invalidated_at is null) or (status = 'stale' and invalidated_at is not null))
);

create index course_distribution_revision_source_idx on public.course_distribution_revisions(source_id);
create index course_distribution_correction_revision_idx on public.course_distribution_corrections(revision_id);
create index course_distribution_artifact_revision_idx on public.course_distribution_artifacts(revision_id);

create function academic_private.assert_distribution_source_immutable()
returns trigger language plpgsql set search_path = '' as $$
begin
  if tg_op <> 'INSERT' then
    raise exception 'Course distribution source is immutable' using errcode = '23514';
  end if;
  if encode(extensions.digest(new.source_bytes, 'sha256'), 'hex') <> new.source_hash then
    raise exception 'Course distribution source hash does not match bytes' using errcode = '23514';
  end if;
  return new;
end $$;

create function academic_private.assert_distribution_correction_immutable()
returns trigger language plpgsql set search_path = '' as $$
begin
  if tg_op <> 'INSERT' then
    raise exception 'Course distribution correction is immutable' using errcode = '23514';
  end if;
  return new;
end $$;

create function academic_private.guard_distribution_revision()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.source_id is distinct from old.source_id
     or new.parent_revision_id is distinct from old.parent_revision_id
     or new.revision_number is distinct from old.revision_number
     or new.status is distinct from old.status
     or new.correction_reason is distinct from old.correction_reason
     or new.created_by is distinct from old.created_by
     or new.created_at is distinct from old.created_at then
    raise exception 'Course distribution revision identity is immutable' using errcode = '23514';
  end if;
  if new.revision_version <> old.revision_version + 1 then
    raise exception 'Course distribution revision version must advance by one' using errcode = '23514';
  end if;
  new.updated_at := now();
  return new;
end $$;

create function academic_private.invalidate_distribution_artifacts()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  update public.course_distribution_artifacts
     set status = 'stale', invalidated_at = now()
   where revision_id = new.revision_id and status = 'current';
  return new;
end $$;

create trigger course_distribution_source_immutable
  before insert or update or delete on public.course_distribution_sources
  for each row execute function academic_private.assert_distribution_source_immutable();
create trigger course_distribution_correction_immutable
  before insert or update or delete on public.course_distribution_corrections
  for each row execute function academic_private.assert_distribution_correction_immutable();
create trigger course_distribution_revision_guard
  before update on public.course_distribution_revisions
  for each row execute function academic_private.guard_distribution_revision();
create trigger course_distribution_correction_invalidates_artifacts
  after insert on public.course_distribution_corrections
  for each row execute function academic_private.invalidate_distribution_artifacts();

create function public.append_course_distribution_correction(
  target_revision uuid,
  expected_revision_version integer,
  target_row integer,
  target_column text,
  prior_formula jsonb,
  prior_cached_value jsonb,
  next_effective_value jsonb,
  reason text
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  revision public.course_distribution_revisions;
  correction_id uuid;
  scope_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required for course distribution corrections' using errcode = '42501';
  end if;
  select * into revision from public.course_distribution_revisions
    where id = target_revision for update;
  if not found then
    raise exception 'Unknown course distribution revision' using errcode = 'P0002';
  end if;
  if revision.status <> 'accepted' then
    raise exception 'Only an accepted course distribution revision can be corrected' using errcode = '23514';
  end if;
  select scheduling_scope_id into scope_id
    from public.course_distribution_sources where id = revision.source_id;
  if scope_id is null or not academic_private.can_scope(scope_id, 'edit_draft') then
    raise exception 'Course distribution correction needs scoped edit_draft capability' using errcode = '42501';
  end if;
  if revision.revision_version <> expected_revision_version then
    raise exception 'Stale course distribution revision' using errcode = '40001';
  end if;
  if target_row < 6 or target_column !~ '^(A|B|C|D|E|F|G|H|I|J|K|L)$'
     or next_effective_value is null or btrim(coalesce(reason, '')) = '' then
    raise exception 'Invalid course distribution correction provenance' using errcode = '23514';
  end if;
  insert into public.course_distribution_corrections
    (revision_id, source_row, source_column, original_formula, original_cached_value,
     effective_value, correction_reason, corrected_by)
  values
    (target_revision, target_row, target_column, prior_formula, prior_cached_value,
     next_effective_value, reason, auth.uid())
  returning id into correction_id;
  update public.course_distribution_revisions
     set revision_version = revision_version + 1
   where id = target_revision;
  return correction_id;
end $$;

-- Returns the immutable source and its audited overlays as one read-only
-- bundle. The client forwards this bundle to the isolated scheduling engine;
-- the engine verifies the hash and every original-cell value before use.
create function public.read_course_distribution_revision(
  target_revision uuid
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  revision public.course_distribution_revisions;
  source public.course_distribution_sources;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required for course distribution generation' using errcode = '42501';
  end if;
  select r.* into revision
    from public.course_distribution_revisions r
   where r.id = target_revision;
  if not found then
    raise exception 'Unknown course distribution revision' using errcode = 'P0002';
  end if;
  select s.* into source
    from public.course_distribution_sources s
   where s.id = revision.source_id;
  if not found or source.scheduling_scope_id is null
     or not academic_private.can_scope(source.scheduling_scope_id, 'read_catalog') then
    raise exception 'Course distribution generation needs scoped read_catalog capability' using errcode = '42501';
  end if;
  if revision.status <> 'accepted' then
    raise exception 'Only an accepted course distribution revision can be generated' using errcode = '23514';
  end if;
  return jsonb_build_object(
    'source_id', source.id,
    'revision_id', revision.id,
    'revision_number', revision.revision_number,
    'revision_version', revision.revision_version,
    'status', revision.status,
    'source_sha256', source.source_hash,
    'source_bytes_base64', encode(source.source_bytes, 'base64'),
    'sheet_name', source.sheet_name,
    'corrections', coalesce((
      select jsonb_agg(jsonb_build_object(
        'source_row', c.source_row,
        'source_column', c.source_column,
        'original_formula', c.original_formula,
        'original_cached_value', c.original_cached_value,
        'effective_value', c.effective_value
      ) order by c.corrected_at, c.id)
      from public.course_distribution_corrections c
      where c.revision_id = revision.id
    ), '[]'::jsonb)
  );
end $$;

alter table public.course_distribution_sources enable row level security;
alter table public.course_distribution_revisions enable row level security;
alter table public.course_distribution_corrections enable row level security;
alter table public.course_distribution_artifacts enable row level security;

create policy course_distribution_sources_read on public.course_distribution_sources
  for select using (scheduling_scope_id is null or academic_private.can_scope(scheduling_scope_id, 'read_catalog'));
create policy course_distribution_revisions_read on public.course_distribution_revisions
  for select using (exists (select 1 from public.course_distribution_sources s
    where s.id = source_id and (s.scheduling_scope_id is null or academic_private.can_scope(s.scheduling_scope_id, 'read_catalog'))));
create policy course_distribution_corrections_read on public.course_distribution_corrections
  for select using (exists (select 1 from public.course_distribution_revisions r join public.course_distribution_sources s on s.id = r.source_id
    where r.id = revision_id and (s.scheduling_scope_id is null or academic_private.can_scope(s.scheduling_scope_id, 'read_catalog'))));
create policy course_distribution_artifacts_read on public.course_distribution_artifacts
  for select using (exists (select 1 from public.course_distribution_revisions r join public.course_distribution_sources s on s.id = r.source_id
    where r.id = revision_id and (s.scheduling_scope_id is null or academic_private.can_scope(s.scheduling_scope_id, 'read_catalog'))));

revoke all on public.course_distribution_sources, public.course_distribution_revisions,
  public.course_distribution_corrections, public.course_distribution_artifacts from anon, authenticated;
grant select on public.course_distribution_sources, public.course_distribution_revisions,
  public.course_distribution_corrections, public.course_distribution_artifacts to authenticated;
revoke all on function public.append_course_distribution_correction(uuid, integer, integer, text, jsonb, jsonb, jsonb, text) from public, anon, authenticated;
revoke all on function public.read_course_distribution_revision(uuid) from public, anon, authenticated;
grant execute on function public.append_course_distribution_correction(uuid, integer, integer, text, jsonb, jsonb, jsonb, text) to authenticated;
grant execute on function public.read_course_distribution_revision(uuid) to authenticated;
commit;
