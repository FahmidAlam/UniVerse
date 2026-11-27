-- ============================================================
-- VERIFICATION — Stage 5A (Gate C) RLS, RPC & Artifact Assertions
-- ============================================================
-- Run in Supabase Dashboard -> SQL Editor AFTER applying
-- 20261127120000_stage_5a_gate_c_catalogs_and_policy.sql.
-- Wrapped in BEGIN ... ROLLBACK so zero test rows persist.
-- ============================================================

begin;

do $$
declare
  v_student uuid := '11111111-1111-4111-8111-111111111111';
  v_teacher uuid := '33333333-3333-4333-8333-333333333333';
  v_admin   uuid := '44444444-4444-4444-8444-444444444444';
  v_count   int;
  v_failed  boolean;
  v_src_id  uuid;
  v_rev_id  uuid;
  v_snap1   jsonb;
  v_snap2   jsonb;
  v_art     jsonb;
  v_art_status text;
  v_bytes   bytea := decode('504b0304', 'hex');
  v_hash    text := encode(extensions.digest(decode('504b0304', 'hex'), 'sha256'), 'hex');
begin
  -- Seed synthetic auth.users + profiles inside rollback transaction
  insert into auth.users (id, email)
  values
    (v_student, 'verify-5a-student@example.test'),
    (v_teacher, 'verify-5a-teacher@example.test'),
    (v_admin,   'verify-5a-admin@example.test')
  on conflict (id) do nothing;

  insert into public.profiles (id, email, name, role)
  values
    (v_student, 'verify-5a-student@example.test', 'Student 5A', 'student'),
    (v_teacher, 'verify-5a-teacher@example.test', 'Teacher 5A', 'teacher'),
    (v_admin,   'verify-5a-admin@example.test',   'Admin 5A',   'admin')
  on conflict (id) do update set role = excluded.role;

  -- Seed synthetic Track 2 source + accepted revision (as postgres inside txn)
  insert into public.course_distribution_sources (
    scheduling_scope_id, source_hash, source_bytes, sheet_name, uploaded_by
  ) values (
    null, v_hash, v_bytes, 'Course Distribution', v_admin
  )
  returning id into v_src_id;

  insert into public.course_distribution_revisions (
    source_id, revision_number, revision_version, status, correction_reason, created_by
  ) values (
    v_src_id, 99, 1, 'accepted', 'Stage 5A RLS verification fixture', v_admin
  )
  returning id into v_rev_id;

  -- ─── 1. Anonymous role assertions (must reject) ───────────
  perform set_config('request.jwt.claims', '{}', true);
  set local role anon;

  v_failed := false;
  begin
    perform count(*) from public.catalog_courses;
  exception when insufficient_privilege then
    v_failed := true;
  end;
  if not v_failed then
    raise exception 'FAIL: anon was permitted to query catalog_courses';
  end if;

  v_failed := false;
  begin
    perform count(*) from public.section_policies;
  exception when insufficient_privilege then
    v_failed := true;
  end;
  if not v_failed then
    raise exception 'FAIL: anon was permitted to query section_policies';
  end if;

  v_failed := false;
  begin
    perform count(*) from public.policy_snapshots;
  exception when insufficient_privilege then
    v_failed := true;
  end;
  if not v_failed then
    raise exception 'FAIL: anon was permitted to query policy_snapshots';
  end if;

  v_failed := false;
  begin
    perform public.read_active_policy_snapshot(v_rev_id, null);
  exception when insufficient_privilege then
    v_failed := true;
  end;
  if not v_failed then
    raise exception 'FAIL: anon was permitted to execute read_active_policy_snapshot';
  end if;

  v_failed := false;
  begin
    perform public.save_policy_snapshot(v_rev_id, null, 'Anon Hack');
  exception when insufficient_privilege then
    v_failed := true;
  end;
  if not v_failed then
    raise exception 'FAIL: anon was permitted to execute save_policy_snapshot';
  end if;

  v_failed := false;
  begin
    perform public.save_validation_report_artifact(v_rev_id, null, '{}'::jsonb, '{}'::jsonb, false);
  exception when insufficient_privilege then
    v_failed := true;
  end;
  if not v_failed then
    raise exception 'FAIL: anon was permitted to execute save_validation_report_artifact';
  end if;

  reset role;

  -- ─── 2. Student role assertions (0 rows + 42501 on DML/RPC) ─
  perform set_config('request.jwt.claims', json_build_object('sub', v_student::text, 'email', 'verify-5a-student@example.test', 'role', 'authenticated')::text, true);
  set local role authenticated;

  select count(*) into v_count from public.catalog_courses;
  if v_count <> 0 then
    raise exception 'FAIL: Student read catalog_courses (count=%)', v_count;
  end if;

  select count(*) into v_count from public.section_policies;
  if v_count <> 0 then
    raise exception 'FAIL: Student read section_policies (count=%)', v_count;
  end if;

  select count(*) into v_count from public.policy_snapshots;
  if v_count <> 0 then
    raise exception 'FAIL: Student read policy_snapshots (count=%)', v_count;
  end if;

  v_failed := false;
  begin
    insert into public.catalog_courses (code, title) values ('CSE-9999', 'Hack');
  exception when insufficient_privilege then
    v_failed := true;
  end;
  if not v_failed then
    raise exception 'FAIL: Student inserted into catalog_courses';
  end if;

  v_failed := false;
  begin
    perform public.read_active_policy_snapshot(v_rev_id, null);
  exception when insufficient_privilege then
    v_failed := true;
  end;
  if not v_failed then
    raise exception 'FAIL: Student called read_active_policy_snapshot';
  end if;

  v_failed := false;
  begin
    perform public.save_policy_snapshot(v_rev_id, null, 'Student Hack');
  exception when insufficient_privilege then
    v_failed := true;
  end;
  if not v_failed then
    raise exception 'FAIL: Student called save_policy_snapshot';
  end if;

  v_failed := false;
  begin
    perform public.save_validation_report_artifact(v_rev_id, null, '{}'::jsonb, '{}'::jsonb, false);
  exception when insufficient_privilege then
    v_failed := true;
  end;
  if not v_failed then
    raise exception 'FAIL: Student called save_validation_report_artifact';
  end if;

  reset role;

  -- ─── 3. Teacher role assertions (0 rows + 42501 on DML/RPC) ─
  perform set_config('request.jwt.claims', json_build_object('sub', v_teacher::text, 'email', 'verify-5a-teacher@example.test', 'role', 'authenticated')::text, true);
  set local role authenticated;

  select count(*) into v_count from public.catalog_courses;
  if v_count <> 0 then
    raise exception 'FAIL: Teacher read catalog_courses (count=%)', v_count;
  end if;

  v_failed := false;
  begin
    insert into public.section_policies (batch, section) values ('99', 'A');
  exception when insufficient_privilege then
    v_failed := true;
  end;
  if not v_failed then
    raise exception 'FAIL: Teacher inserted into section_policies';
  end if;

  v_failed := false;
  begin
    perform public.save_policy_snapshot(v_rev_id, null, 'Teacher Hack');
  exception when insufficient_privilege then
    v_failed := true;
  end;
  if not v_failed then
    raise exception 'FAIL: Teacher called save_policy_snapshot';
  end if;

  v_failed := false;
  begin
    perform public.save_validation_report_artifact(v_rev_id, null, '{}'::jsonb, '{}'::jsonb, false);
  exception when insufficient_privilege then
    v_failed := true;
  end;
  if not v_failed then
    raise exception 'FAIL: Teacher called save_validation_report_artifact';
  end if;

  reset role;

  -- ─── 4. Admin role assertions (CRUD + Gate C RPCs + staleness) ─
  perform set_config('request.jwt.claims', json_build_object('sub', v_admin::text, 'email', 'verify-5a-admin@example.test', 'role', 'authenticated')::text, true);
  set local role authenticated;

  insert into public.catalog_courses (code, title, credit, class_type, is_physics_lab)
  values ('PHY-1104', 'Physics Lab', 1.5, 'lab', true);

  insert into public.section_policies (batch, section, calendar_system, weekend_override_days, student_count)
  values ('61', 'A', 'bi_semester', array['Saturday', 'Sunday'], 48);

  -- Save initial PolicySnapshot (assert allow_sessional_across_break defaults false + 64-hex policy_hash)
  v_snap1 := public.save_policy_snapshot(
    v_rev_id,
    null,
    'Stage 5A Baseline',
    array['Friday', 'Saturday'],
    1,
    1,
    false,
    array['PHY-1104'],
    '{"daily_slot_count": 7}'::jsonb
  );

  if (v_snap1->>'version')::int <> 1
     or (v_snap1->>'allow_sessional_across_break')::boolean <> false
     or length(v_snap1->>'policy_hash') <> 64 then
    raise exception 'FAIL: Unexpected initial policy snapshot: %', v_snap1;
  end if;

  if public.read_active_policy_snapshot(v_rev_id, null)->>'id' <> v_snap1->>'id' then
    raise exception 'FAIL: read_active_policy_snapshot did not return snap1';
  end if;

  -- Persist a current validation_report artifact bound to snap1
  v_art := public.save_validation_report_artifact(
    v_rev_id,
    (v_snap1->>'id')::uuid,
    '{"ok": true, "checks": []}'::jsonb,
    '{"blocker_count": 0, "warning_count": 0}'::jsonb,
    false
  );

  if v_art->>'status' <> 'current' or v_art->>'artifact_kind' <> 'validation_report' then
    raise exception 'FAIL: Unexpected validation_report artifact: %', v_art;
  end if;

  -- Save a new PolicySnapshot for the same revision -> bumps version & marks prior validation_report stale
  v_snap2 := public.save_policy_snapshot(
    v_rev_id,
    null,
    'Stage 5A Updated',
    array['Friday', 'Saturday'],
    1,
    1,
    true,
    array['PHY-1104'],
    '{"daily_slot_count": 6}'::jsonb
  );

  if (v_snap2->>'version')::int <> 2 then
    raise exception 'FAIL: Expected snap2 version=2, got %', v_snap2->>'version';
  end if;

  select status into v_art_status
    from public.course_distribution_artifacts
   where id = (v_art->>'id')::uuid;

  if v_art_status <> 'stale' then
    raise exception 'FAIL: Expected prior validation_report to become stale, got %', v_art_status;
  end if;

  reset role;

  raise notice 'PASS: All Stage 5A Gate C RLS, RPC, and artifact staleness assertions succeeded.';
end $$;

rollback;
