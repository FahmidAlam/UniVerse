-- READ ONLY: run ONLY in original UniVerse to prepare a sanitized restore fixture.
-- One statement = one consistent snapshot; no data, schema or settings changed.
-- No original UUIDs, teacher names/codes, publisher IDs or free-text notes exported.
-- Teacher labels are synthetic ranks, consistent only within this export.
-- Review course/room/batch/section display text before sharing the result.
-- This is a CURRENT SCHEDULE fixture, not a full account/config/Storage backup.
with version_keys as (
  select id, row_number() over (order by id) as version_key
  from public.routine_versions
), sanitized_versions as (
  select k.version_key, v.source, v.is_active, v.row_count
  from public.routine_versions v join version_keys k on k.id = v.id
), teacher_labels as (
  select r.*,
    dense_rank() over (order by coalesce(teacher_id::text, ''),
      coalesce(teacher_code, ''), coalesce(teacher_name, '')) as teacher_label
  from public.routines r
), sanitized_rows as (
  select row_number() over (order by r.day, r.time_start, r.time_end,
      r.batch, r.section, r.subject_code, r.room, r.id) as fixture_row,
    r.day, r.time_start::text, r.time_end::text, r.subject, r.subject_code,
    r.room, r.batch, r.section, r.semester, r.is_active, r.is_service,
    case when r.teacher_id is null
      and nullif(trim(r.teacher_code), '') is null
      and nullif(trim(r.teacher_name), '') is null then null
      else 'Teacher-' || r.teacher_label::text end as teacher_name,
    case when r.teacher_id is null
      and nullif(trim(r.teacher_code), '') is null
      and nullif(trim(r.teacher_name), '') is null then null
      else 'T' || r.teacher_label::text end as teacher_code,
    k.version_key
  from teacher_labels r left join version_keys k on k.id = r.routine_version_id
), payload as (
  select jsonb_build_object(
    'schema_version', 1,
    'routine_count', (select count(*) from sanitized_rows),
    'version_count', (select count(*) from sanitized_versions),
    'routines', (select coalesce(jsonb_agg(to_jsonb(r) order by fixture_row), '[]'::jsonb)
                 from sanitized_rows r),
    'routine_versions', (select coalesce(jsonb_agg(to_jsonb(v) order by version_key), '[]'::jsonb)
                         from sanitized_versions v),
    'limitations', jsonb_build_array(
      'teacher profile FKs omitted; restore as nullable teacher_id',
      'publisher identity and notes omitted',
      'historical version metadata does not reconstruct deleted historical rows',
      'not a full account/config/Storage backup'
    )
  )::text as text
)
select jsonb_pretty(jsonb_build_object(
  'payload', text,
  'checksum_md5', md5(text)
)) as schedule_snapshot from payload;
