-- ============================================================
-- VERIFICATION — Stage 5C (Gate D) RLS, Co-Teacher, Archiving & Rollback
-- ============================================================
-- Run in Supabase Dashboard -> SQL Editor AFTER applying
-- 20261127180000_stage_5c_gate_d_durable_jobs_and_archiving_publish.sql.
-- Wrapped in BEGIN ... ROLLBACK so zero test rows persist.
-- ============================================================

begin;

do $$
declare
  v_student uuid := '11111111-1111-4111-8111-1111111115c1';
  v_teacher uuid := '33333333-3333-4333-8333-3333333335c3';
  v_admin   uuid := '44444444-4444-4444-8444-4444444445c4';
  v_src_id  uuid;
  v_rev_id  uuid;
  v_failed  boolean;
  v_count   int;
  v_pub1    jsonb;
  v_pub2    jsonb;
  v_restored jsonb;
  v_v1_id   uuid;
  v_v2_id   uuid;
  v_v3_id   uuid;
  v_codes   text[];
  v_primary text;
  v_snap    jsonb;
  v_bytes   bytea := decode('504b0304', 'hex');
  v_hash    text := encode(extensions.digest(decode('504b0304', 'hex'), 'sha256'), 'hex');
begin
  insert into auth.users (id, email)
  values
    (v_student, 'verify-5c-student@example.test'),
    (v_teacher, 'verify-5c-teacher@example.test'),
    (v_admin,   'verify-5c-admin@example.test')
  on conflict (id) do nothing;

  insert into public.profiles (id, email, name, role)
  values
    (v_student, 'verify-5c-student@example.test', 'Student 5C', 'student'),
    (v_teacher, 'verify-5c-teacher@example.test', 'Teacher 5C', 'teacher'),
    (v_admin,   'verify-5c-admin@example.test',   'Admin 5C',   'admin')
  on conflict (id) do update set role = excluded.role;

  insert into public.course_distribution_sources (
    scheduling_scope_id, source_hash, source_bytes, sheet_name, uploaded_by
  ) values (
    null, v_hash, v_bytes, 'Course Distribution', v_admin
  )
  returning id into v_src_id;

  insert into public.course_distribution_revisions (
    source_id, revision_number, revision_version, status, correction_reason, created_by
  ) values (
    v_src_id, 501, 2, 'accepted', 'Stage 5C Gate D RLS verification fixture', v_admin
  )
  returning id into v_rev_id;

  insert into public.course_distribution_artifacts (
    revision_id, artifact_kind, status, has_blockers, computed_by
  ) values (
    v_rev_id, 'validation_report', 'current', false, v_admin
  );

  -- Seed a durable solver_job row as postgres to test non-admin isolation
  insert into public.solver_jobs (
    job_id, revision_id, revision_version, semester_label, state, progress, created_by
  ) values (
    'job-5c-verify-1', v_rev_id, 2, 'Stage 5C Verify', 'done', 1.0, v_admin
  );

  -- ─── 1. Anonymous role assertions ──────────────────────────
  perform set_config('request.jwt.claims', '{}', true);
  set local role anon;

  v_failed := false;
  begin
    perform count(*) from public.solver_jobs;
  exception when insufficient_privilege then
    v_failed := true;
  end;
  if not v_failed then
    raise exception 'FAIL: anon was permitted to query solver_jobs';
  end if;

  v_failed := false;
  begin
    perform public.publish_routine('[{"day":"Sunday","time_start":"08:50:00","time_end":"10:05:00","subject":"Test","subject_code":"CSE-1101","room":"RAB-301","batch":"61","section":"A","semester":1}]'::jsonb);
  exception when insufficient_privilege then
    v_failed := true;
  end;
  if not v_failed then
    raise exception 'FAIL: anon was permitted to execute publish_routine';
  end if;

  v_failed := false;
  begin
    perform public.restore_routine_version(gen_random_uuid(), null);
  exception when insufficient_privilege then
    v_failed := true;
  end;
  if not v_failed then
    raise exception 'FAIL: anon was permitted to execute restore_routine_version';
  end if;

  reset role;

  -- ─── 2. Student role assertions ────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', v_student::text, 'email', 'verify-5c-student@example.test', 'role', 'authenticated')::text, true);
  set local role authenticated;

  select count(*) into v_count from public.solver_jobs;
  if v_count <> 0 then
    raise exception 'FAIL: Student read solver_jobs (count=%)', v_count;
  end if;

  v_failed := false;
  begin
    perform public.publish_routine('[{"day":"Sunday","time_start":"08:50:00","time_end":"10:05:00","subject":"Test","subject_code":"CSE-1101","room":"RAB-301","batch":"61","section":"A","semester":1}]'::jsonb);
  exception when insufficient_privilege then
    v_failed := true;
  end;
  if not v_failed then
    raise exception 'FAIL: Student executed publish_routine';
  end if;

  v_failed := false;
  begin
    perform public.publish_routine(
      '[{"day":"Sunday","time_start":"08:50:00","time_end":"10:05:00","subject":"Test","subject_code":"CSE-1101","room":"RAB-301","batch":"61","section":"A","semester":1}]'::jsonb,
      'Rev Probe',
      'engine',
      '{}'::jsonb,
      '{}'::jsonb,
      null,
      null,
      gen_random_uuid()
    );
  exception when insufficient_privilege then
    v_failed := true;
  end;
  if not v_failed then
    raise exception 'FAIL: Student probing p_revision_id on publish_routine was not denied with 42501';
  end if;

  v_failed := false;
  begin
    perform public.restore_routine_version(gen_random_uuid(), null);
  exception when insufficient_privilege then
    v_failed := true;
  end;
  if not v_failed then
    raise exception 'FAIL: Student executed restore_routine_version';
  end if;

  reset role;

  -- ─── 3. Teacher role assertions ────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', v_teacher::text, 'email', 'verify-5c-teacher@example.test', 'role', 'authenticated')::text, true);
  set local role authenticated;

  select count(*) into v_count from public.solver_jobs;
  if v_count <> 0 then
    raise exception 'FAIL: Teacher read solver_jobs (count=%)', v_count;
  end if;

  v_failed := false;
  begin
    perform public.publish_routine('[{"day":"Sunday","time_start":"08:50:00","time_end":"10:05:00","subject":"Test","subject_code":"CSE-1101","room":"RAB-301","batch":"61","section":"A","semester":1}]'::jsonb);
  exception when insufficient_privilege then
    v_failed := true;
  end;
  if not v_failed then
    raise exception 'FAIL: Teacher executed publish_routine';
  end if;

  v_failed := false;
  begin
    perform public.restore_routine_version(gen_random_uuid(), null);
  exception when insufficient_privilege then
    v_failed := true;
  end;
  if not v_failed then
    raise exception 'FAIL: Teacher executed restore_routine_version';
  end if;

  reset role;

  -- ─── 4. Admin assertions: Co-Teachers, Archiving, 40001, Rollback ─
  perform set_config('request.jwt.claims', json_build_object('sub', v_admin::text, 'email', 'verify-5c-admin@example.test', 'role', 'authenticated')::text, true);
  set local role authenticated;

  select count(*) into v_count from public.solver_jobs where job_id = 'job-5c-verify-1';
  if v_count <> 1 then
    raise exception 'FAIL: Admin could not read solver_jobs';
  end if;

  -- 4a. Publish v1 with co-teachers ['MSR', 'EBH']
  v_pub1 := public.publish_routine(
    '[{"day":"Sunday","time_start":"08:50:00","time_end":"10:05:00","subject":"DBMS Lab","subject_code":"CSE-3102","teacher_name":"Mohammad Shoaib Rahman","teacher_code":"MSR","teacher_codes":["MSR","EBH"],"room":"ACL-1","batch":"58","section":"B+C","semester":6,"is_service":false}]'::jsonb,
    'Stage 5C V1',
    'engine',
    '{"status":"OPTIMAL"}'::jsonb,
    '{"ok":true}'::jsonb,
    'Initial v1 publish',
    null,
    v_rev_id,
    2,
    null,
    'stage5c_v1.xlsx',
    true
  );
  v_v1_id := (v_pub1->>'version_id')::uuid;

  select teacher_code, teacher_codes
    into v_primary, v_codes
    from public.routines
   where routine_version_id = v_v1_id and is_active = true
   limit 1;

  if v_primary <> 'MSR' or v_codes <> array['MSR', 'EBH']::text[] then
    raise exception 'FAIL: Co-teacher array mismatch (primary=%, codes=%)', v_primary, v_codes;
  end if;

  -- 4b. Stale revision_version (expected 1 vs current 2) must raise SQLSTATE 40001
  v_failed := false;
  begin
    perform public.publish_routine(
      '[{"day":"Monday","time_start":"08:50:00","time_end":"10:05:00","subject":"Algorithms","subject_code":"CSE-2201","teacher_code":"SAB","room":"RAB-304","batch":"59","section":"A","semester":4}]'::jsonb,
      'Stale Publish',
      'engine',
      '{}'::jsonb,
      '{"ok":true}'::jsonb,
      null,
      null,
      v_rev_id,
      1,
      null,
      null,
      true
    );
  exception when serialization_failure then
    v_failed := true;
  end;
  if not v_failed then
    raise exception 'FAIL: Stale p_revision_version did not raise SQLSTATE 40001';
  end if;

  -- 4c. Publish v2 -> v1 rows must become is_active = false (NEVER deleted!)
  v_pub2 := public.publish_routine(
    '[{"day":"Monday","time_start":"08:50:00","time_end":"10:05:00","subject":"Algorithms","subject_code":"CSE-2201","teacher_code":"SAB","room":"RAB-304","batch":"59","section":"A","semester":4}]'::jsonb,
    'Stage 5C V2',
    'engine',
    '{"status":"OPTIMAL"}'::jsonb,
    '{"ok":true}'::jsonb,
    'Second publish',
    null,
    v_rev_id,
    2,
    null,
    'stage5c_v2.xlsx',
    true
  );
  v_v2_id := (v_pub2->>'version_id')::uuid;

  select count(*) into v_count
    from public.routines
   where routine_version_id = v_v1_id and is_active = false;
  if v_count <> 1 then
    raise exception 'FAIL: Expected v1 routine row archived (is_active=false), got count=%', v_count;
  end if;

  select snapshot_rows into v_snap
    from public.routine_versions
   where id = v_v1_id;
  if v_snap is null or jsonb_array_length(v_snap) <> 1 then
    raise exception 'FAIL: Expected v1 snapshot_rows preserved';
  end if;

  -- 4d. Restore v1 via restore_routine_version() -> creates rollback active version with exact co-teachers
  v_restored := public.restore_routine_version(v_v1_id, 'Rollback verification');
  v_v3_id := (v_restored->>'version_id')::uuid;

  if (v_restored->>'restored_from_version_id')::uuid <> v_v1_id then
    raise exception 'FAIL: restored_from_version_id mismatch';
  end if;

  select count(*) into v_count
    from public.routines
   where routine_version_id = v_v2_id and is_active = false;
  if v_count <> 1 then
    raise exception 'FAIL: Expected v2 routine row archived on rollback';
  end if;

  select teacher_codes into v_codes
    from public.routines
   where routine_version_id = v_v3_id and is_active = true
   limit 1;
  if v_codes <> array['MSR', 'EBH']::text[] then
    raise exception 'FAIL: Restored routine did not preserve co-teacher array (got %)', v_codes;
  end if;

  reset role;

  raise notice 'PASS: All Stage 5C Gate D RLS, co-teacher, 40001 guard, non-destructive archive, and rollback assertions succeeded.';
end $$;

rollback;
