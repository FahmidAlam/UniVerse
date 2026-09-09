-- ============================================================
-- 014 — Fix publish_routine() failing under the `safeupdate` guard.
--
-- PROBLEM (confirmed live):
--   Uploading and publishing a routine failed with:
--     PostgrestException(message: DELETE requires a WHERE clause,
--                         code: 21000, details: Bad Request, hint: null)
--
--   `publish_routine()` (migration 012) intentionally clears the ENTIRE
--   `routines` table on every publish — it holds only the active routine, so
--   a full, unconditional replace is correct, not a bug:
--
--       delete from public.routines;
--
--   That is a genuinely unqualified DELETE. Postgres core has no such error
--   message; this is the `safeupdate` extension, which blocks any UPDATE or
--   DELETE with no WHERE clause at all — a safety net against exactly the
--   accidental-wipe class of bug, which happens to also catch this
--   deliberate one.
--
-- FIX:
--   `where true` is syntactically a WHERE clause (satisfies the guard) and
--   matches every row (identical behavior to the unqualified delete). No
--   other statement in the schema does an unqualified DELETE/UPDATE — this
--   was the only place safeupdate could ever fire.
--
-- NUMBERING:
--   Written on a teammate's branch as "013", which collided with
--   013_faculty_course_eligibility.sql. Renumbered to 014 because 013 was
--   already applied to the live database first; the file numbers follow the
--   order the migrations actually ran. The two are independent — this one
--   replaces a function, 013 creates a table — so either order works, and no
--   re-run of 013 is needed.
--
-- Idempotent (create or replace). Note that CREATE OR REPLACE FUNCTION keeps
-- the existing owner and privileges, so the REVOKE/GRANT from migration 012
-- still stands and is deliberately not repeated here.
-- ============================================================

create or replace function public.publish_routine(
  p_rows           jsonb,
  p_semester_label text default null,
  p_source         text default 'engine',
  p_stats          jsonb default '{}'::jsonb,
  p_validation     jsonb default '{}'::jsonb,
  p_notes          text default null
) returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_id    uuid;
  v_count int;
begin
  if not public.is_admin() then
    raise exception 'Only an admin may publish a routine.'
      using errcode = '42501';
  end if;

  if p_rows is null or jsonb_typeof(p_rows) <> 'array'
     or jsonb_array_length(p_rows) = 0 then
    -- Refuse rather than wipe: an empty payload used to be a silent no-op
    -- that could still have cleared rows under the old delete-loop.
    raise exception 'Refusing to publish an empty routine.'
      using errcode = '22023';
  end if;

  insert into public.routine_versions
    (semester_label, source, published_by, stats, validation, notes)
  values (p_semester_label, p_source, auth.uid(), coalesce(p_stats, '{}'::jsonb),
          coalesce(p_validation, '{}'::jsonb), p_notes)
  returning id into v_id;

  -- Replace, never merge. Every previous class goes, including batches that
  -- do not appear in the incoming routine. `where true` is deliberate — see
  -- the header comment; do not "simplify" this back to a bare DELETE.
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
end $$;

comment on function public.publish_routine is
  'Atomically replaces the entire active routine. Deletes every previous class '
  '(not just colliding batches, `where true` to satisfy the safeupdate guard), '
  'inserts the new rows, and flips the active routine_versions row. Admin only.';
