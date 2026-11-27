-- ============================================================
-- ROLLBACK — Stage 5A (Gate C): Catalogs, PolicySnapshots & Validation Artifacts
-- ============================================================
-- Reverses 20261127120000_stage_5a_gate_c_catalogs_and_policy.sql idempotently.
-- Preserves all pre-existing Track 1 & Track 2 tables and rows.
-- ============================================================

begin;

-- 1. Drop Gate C RPCs
drop function if exists public.save_validation_report_artifact(uuid, uuid, jsonb, jsonb, boolean);
drop function if exists public.save_policy_snapshot(uuid, uuid, text, text[], int, int, boolean, text[], jsonb);
drop function if exists public.read_active_policy_snapshot(uuid, uuid);

-- 2. Remove additive Gate C columns from `public.course_distribution_artifacts`
drop index if exists public.course_distribution_artifacts_rev_kind_idx;
alter table if exists public.course_distribution_artifacts
  drop constraint if exists course_distribution_artifacts_payload_ck,
  drop constraint if exists course_distribution_artifacts_summary_ck,
  drop column if exists policy_snapshot_id,
  drop column if exists payload,
  drop column if exists summary,
  drop column if exists has_blockers,
  drop column if exists computed_by,
  drop column if exists updated_at;

-- 3. Drop `public.policy_snapshots`
drop table if exists public.policy_snapshots;

-- 4. Remove additive Gate C columns from `public.timetable_rooms`
alter table if exists public.timetable_rooms
  drop constraint if exists timetable_rooms_pool_role_ck,
  drop constraint if exists timetable_rooms_available_slots_ck,
  drop column if exists room_pool_role,
  drop column if exists available_slots;

-- 5. Remove additive Gate C columns from `public.timetable_faculty`
alter table if exists public.timetable_faculty
  drop constraint if exists timetable_faculty_employment_type_ck,
  drop constraint if exists timetable_faculty_external_blocked_slots_ck,
  drop constraint if exists timetable_faculty_available_slots_ck,
  drop constraint if exists timetable_faculty_preferred_slots_ck,
  drop column if exists employment_type,
  drop column if exists allow_three_off_days,
  drop column if exists is_sust_adjunct,
  drop column if exists external_blocked_slots,
  drop column if exists available_slots,
  drop column if exists preferred_slots;

-- 6. Drop `public.section_policies` and `public.catalog_courses`
drop table if exists public.section_policies;
drop table if exists public.catalog_courses;

-- 7. Drop private Stage 5A helper functions
drop function if exists academic_private.touch_updated_at();
drop function if exists academic_private.is_valid_consecutive_weekend(text[]);

commit;
