-- ============================================================
-- MIGRATION 003 — routines.teacher_name / teacher_code (text)
-- PURPOSE: routines.teacher_id is a UUID FK to profiles (-> auth.users),
--   so teachers can't be seeded without real accounts, AND it disagrees
--   with generated_timetable which already stores `teacher TEXT`.
--   Add text columns so routines can carry a teacher the same way the
--   engine output does. teacher_id stays (nullable) for the future case
--   where a real teacher account "owns" a class.
-- Safe / additive. Run once in the Supabase SQL editor.
-- ============================================================

alter table public.routines add column if not exists teacher_name text;
alter table public.routines add column if not exists teacher_code text;
