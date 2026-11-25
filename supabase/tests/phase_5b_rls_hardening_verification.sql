-- ============================================================
-- VERIFICATION — Phase 5B RLS & Storage Hardening Assertions
-- ============================================================
-- Run in Supabase Dashboard -> SQL Editor AFTER applying
-- 20261122160000_phase_5b_rls_and_storage_hardening.sql.
-- Wrapped in BEGIN ... ROLLBACK so zero test rows persist.
-- ============================================================

begin;

do $$
declare
  v_student_a uuid := '11111111-1111-4111-8111-111111111111';
  v_student_b uuid := '22222222-2222-4222-8222-222222222222';
  v_teacher   uuid := '33333333-3333-4333-8333-333333333333';
  v_admin     uuid := '44444444-4444-4444-8444-444444444444';
  v_count     int;
  v_failed    boolean;
begin
  -- Seed synthetic auth.users + profiles for the rollback-only transaction
  insert into auth.users (id, email)
  values
    (v_student_a, 'verify-student-a@example.test'),
    (v_student_b, 'verify-student-b@example.test'),
    (v_teacher,   'verify-teacher@example.test'),
    (v_admin,     'verify-admin@example.test')
  on conflict (id) do nothing;

  insert into public.profiles (id, email, name, role)
  values
    (v_student_a, 'verify-student-a@example.test', 'Student A', 'student'),
    (v_student_b, 'verify-student-b@example.test', 'Student B', 'student'),
    (v_teacher,   'verify-teacher@example.test',   'Teacher T', 'teacher'),
    (v_admin,     'verify-admin@example.test',     'Admin A',   'admin')
  on conflict (id) do update set role = excluded.role;

  -- ─── 1. Student A assertions ──────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', v_student_a::text, 'email', 'verify-student-a@example.test', 'role', 'authenticated')::text, true);
  set local role authenticated;

  -- Can read own profile
  select count(*) into v_count from public.profiles where id = v_student_a;
  if v_count <> 1 then
    raise exception 'FAIL: Student A could not read own profile';
  end if;

  -- Cannot read Student B's profile
  select count(*) into v_count from public.profiles where id = v_student_b;
  if v_count <> 0 then
    raise exception 'FAIL: Student A read Student B profile (count=%)', v_count;
  end if;

  -- Cannot read timetable_* config tables
  select count(*) into v_count from public.timetable_rooms;
  if v_count <> 0 then
    raise exception 'FAIL: Student A read timetable_rooms (count=%)', v_count;
  end if;

  -- Can read student-facing tables (routines, cancellations, notifications, resources)
  perform count(*) from public.routines;
  perform count(*) from public.cancellations;
  perform count(*) from public.notifications;
  perform count(*) from public.resources;

  -- Cannot insert into timetables bucket
  v_failed := false;
  begin
    insert into storage.objects (bucket_id, name, owner) values ('timetables', 'unauth_test.xlsx', v_student_a);
  exception when insufficient_privilege then
    v_failed := true;
  end;
  if not v_failed then
    raise exception 'FAIL: Student A inserted into timetables bucket';
  end if;

  -- Cannot insert into resources bucket
  v_failed := false;
  begin
    insert into storage.objects (bucket_id, name, owner) values ('resources', 'unauth_resource.pdf', v_student_a);
  exception when insufficient_privilege then
    v_failed := true;
  end;
  if not v_failed then
    raise exception 'FAIL: Student A inserted into resources bucket';
  end if;

  reset role;

  -- ─── 2. Teacher assertions ────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', v_teacher::text, 'email', 'verify-teacher@example.test', 'role', 'authenticated')::text, true);
  set local role authenticated;

  -- Cannot read Student A's profile
  select count(*) into v_count from public.profiles where id = v_student_a;
  if v_count <> 0 then
    raise exception 'FAIL: Teacher read Student A profile (count=%)', v_count;
  end if;

  -- Can insert into resources bucket
  insert into storage.objects (bucket_id, name, owner) values ('resources', 'verify/teacher_note.pdf', v_teacher);

  -- Cannot insert into timetables bucket
  v_failed := false;
  begin
    insert into storage.objects (bucket_id, name, owner) values ('timetables', 'teacher_hack.xlsx', v_teacher);
  exception when insufficient_privilege then
    v_failed := true;
  end;
  if not v_failed then
    raise exception 'FAIL: Teacher inserted into timetables bucket';
  end if;

  reset role;

  -- ─── 3. Admin assertions ──────────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', v_admin::text, 'email', 'verify-admin@example.test', 'role', 'authenticated')::text, true);
  set local role authenticated;

  select count(*) into v_count from public.profiles where id in (v_student_a, v_student_b, v_teacher, v_admin);
  if v_count < 4 then
    raise exception 'FAIL: Admin could not read all profiles (count=%)', v_count;
  end if;

  insert into storage.objects (bucket_id, name, owner) values ('timetables', 'verify/admin_routine.xlsx', v_admin);

  reset role;

  raise notice 'PASS: All Phase 5B negative & positive RLS/Storage assertions succeeded.';
end $$;

rollback;
