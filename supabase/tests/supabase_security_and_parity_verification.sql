-- ============================================================
-- VERIFICATION — 20261127220000 Security & Storage Parity Assertions
-- ============================================================
-- Run in Supabase Dashboard -> SQL Editor AFTER applying
-- 20261127220000_supabase_security_and_parity_hardening.sql.
-- Wrapped in BEGIN ... ROLLBACK so zero test rows persist.
-- ============================================================

begin;

do $$
declare
  v_student uuid := '11111111-1111-4111-8111-111111112201';
  v_teacher uuid := '33333333-3333-4333-8333-333333332203';
  v_admin   uuid := '44444444-4444-4444-8444-444444442204';
  v_notif_id uuid;
  v_assign_id uuid;
  v_sub_id uuid;
  v_is_late boolean;
  v_count int;
  v_failed boolean;
  v_vec public.vector := array_fill(0.1::real, array[768])::public.vector;
  v_fn record;
  v_bucket record;
begin
  -- ─── 1. Function search_path & anon/public privilege assertions ───────────
  for v_fn in
    select
      p.proname,
      p.oid,
      p.proconfig,
      has_function_privilege('anon', p.oid, 'EXECUTE') as anon_exec,
      has_function_privilege('public', p.oid, 'EXECUTE') as pub_exec
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in ('guard_profile_role', 'calculate_is_late', 'match_documents')
  loop
    if v_fn.proconfig is null or not ('search_path=""' = any(v_fn.proconfig)) then
      raise exception 'FAIL: %.proconfig missing search_path="" (got %)', v_fn.proname, v_fn.proconfig;
    end if;
    if v_fn.anon_exec then
      raise exception 'FAIL: anon still has EXECUTE on public.%()', v_fn.proname;
    end if;
    if v_fn.pub_exec then
      raise exception 'FAIL: PUBLIC still has EXECUTE on public.%()', v_fn.proname;
    end if;
  end loop;

  if not has_function_privilege('authenticated', 'public.match_documents(public.vector, integer)', 'EXECUTE') then
    raise exception 'FAIL: authenticated lost EXECUTE on public.match_documents';
  end if;

  -- ─── 2. Zero anon table grants & zero TO public policies on target tables ─
  select count(*) into v_count
    from pg_tables t
    cross join (values ('anon')) as r(name)
    cross join (values ('SELECT'), ('INSERT'), ('UPDATE'), ('DELETE'), ('TRUNCATE'), ('REFERENCES'), ('TRIGGER')) as p(name)
   where t.schemaname = 'public'
     and has_table_privilege(r.name, format('%I.%I', t.schemaname, t.tablename), p.name);
  if v_count <> 0 then
    raise exception 'FAIL: anon still retains % table privileges in public schema', v_count;
  end if;

  select count(*) into v_count
    from pg_policies
   where schemaname = 'public'
     and tablename in ('device_tokens', 'notification_reads', 'timetable_course_eligibility')
     and 'public' = any(roles);
  if v_count <> 0 then
    raise exception 'FAIL: % policies still target TO public on hardened tables', v_count;
  end if;

  -- ─── 3. Storage bucket parity assertions ─────────────────────────────────
  for v_bucket in
    select id, file_size_limit, allowed_mime_types
      from storage.buckets
     where id in ('timetables', 'resources', 'avatars', 'assignments')
  loop
    if v_bucket.file_size_limit is null or v_bucket.file_size_limit <= 0 then
      raise exception 'FAIL: bucket % missing file_size_limit', v_bucket.id;
    end if;
    if v_bucket.allowed_mime_types is null or coalesce(cardinality(v_bucket.allowed_mime_types), 0) = 0 then
      raise exception 'FAIL: bucket % missing allowed_mime_types', v_bucket.id;
    end if;
  end loop;

  select count(*) into v_count
    from storage.buckets
   where (id = 'timetables' and file_size_limit = 15728640)
      or (id = 'resources' and file_size_limit = 52428800)
      or (id = 'avatars' and file_size_limit = 5242880)
      or (id = 'assignments' and file_size_limit = 26214400);
  if v_count <> 4 then
    raise exception 'FAIL: Expected all 4 storage.buckets with target file_size_limit (matched %)', v_count;
  end if;

  -- ─── 4. Seed synthetic users & fixtures for role behavior assertions ──────
  insert into auth.users (id, email)
  values
    (v_student, 'verify-220-student@example.test'),
    (v_teacher, 'verify-220-teacher@example.test'),
    (v_admin,   'verify-220-admin@example.test')
  on conflict (id) do nothing;

  insert into public.profiles (id, email, name, role)
  values
    (v_student, 'verify-220-student@example.test', 'Student 220', 'student'),
    (v_teacher, 'verify-220-teacher@example.test', 'Teacher 220', 'teacher'),
    (v_admin,   'verify-220-admin@example.test',   'Admin 220',   'admin')
  on conflict (id) do update set role = excluded.role;

  insert into public.documents (content, embedding, category)
  values ('Verify vector search under empty search_path', v_vec, 'routine');

  select id into v_notif_id from public.notifications limit 1;
  if v_notif_id is null then
    insert into public.notifications (title, body, type, sent_by, target_batch)
    values ('Verify Alert', 'Body', 'university', v_admin, '__verify_none__')
    returning id into v_notif_id;
  end if;

  insert into public.assignments (title, subject_code, teacher_id, batch, section, deadline)
  values ('Verify HW', 'CSE-2201', v_teacher, '62', 'A', now() - interval '1 hour')
  returning id into v_assign_id;

  -- ─── 5. Anonymous negative execution & table checks ──────────────────────
  perform set_config('request.jwt.claims', '{}', true);
  set local role anon;

  v_failed := false;
  begin
    perform * from public.match_documents(v_vec, 1);
  exception when insufficient_privilege then
    v_failed := true;
  end;
  if not v_failed then
    raise exception 'FAIL: anon executed public.match_documents';
  end if;

  v_failed := false;
  begin
    perform count(*) from public.routines;
  exception when insufficient_privilege then
    v_failed := true;
  end;
  if not v_failed then
    raise exception 'FAIL: anon queried public.routines';
  end if;

  reset role;

  -- ─── 6. Authenticated Student runtime checks ─────────────────────────────
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', v_student::text, 'email', 'verify-220-student@example.test', 'role', 'authenticated')::text,
    true
  );
  set local role authenticated;

  -- 6a. match_documents works cleanly with OPERATOR(public.<=>) under search_path=''
  select count(*) into v_count from public.match_documents(v_vec, 1);
  if v_count < 1 then
    raise exception 'FAIL: authenticated match_documents returned 0 rows';
  end if;

  -- 6b. Student retains full mobile read access
  perform count(*) from public.routines;
  perform count(*) from public.notifications;
  perform count(*) from public.resources;

  -- 6c. Student retains own device_tokens & notification_reads CRUD
  insert into public.device_tokens (token, user_id, platform)
  values ('verify-fcm-token-220', v_student, 'android');
  select count(*) into v_count from public.device_tokens where token = 'verify-fcm-token-220';
  if v_count <> 1 then
    raise exception 'FAIL: Student could not read own device_tokens';
  end if;

  insert into public.notification_reads (user_id, notification_id)
  values (v_student, v_notif_id);
  select count(*) into v_count from public.notification_reads where notification_id = v_notif_id and user_id = v_student;
  if v_count <> 1 then
    raise exception 'FAIL: Student could not read own notification_reads';
  end if;

  -- 6d. Student triggers calculate_is_late() cleanly
  insert into public.submissions (assignment_id, student_id, file_url, submitted_at)
  values (v_assign_id, v_student, 'https://example.test/hw.pdf', now())
  returning id, is_late into v_sub_id, v_is_late;
  if v_is_late is distinct from true then
    raise exception 'FAIL: calculate_is_late trigger did not compute is_late=true (got %)', v_is_late;
  end if;

  -- 6e. Student cannot write timetable_course_eligibility
  v_failed := false;
  begin
    insert into public.timetable_course_eligibility (acronym, course_code)
    values ('TST', 'CSE-9999');
  exception when insufficient_privilege then
    v_failed := true;
  end;
  if not v_failed then
    raise exception 'FAIL: Student wrote to timetable_course_eligibility';
  end if;

  -- 6f. guard_profile_role still blocks unwhitelisted teacher role escalation
  v_failed := false;
  begin
    update public.profiles set role = 'teacher' where id = v_student;
  exception when insufficient_privilege then
    v_failed := true;
  end;
  if not v_failed then
    raise exception 'FAIL: Student self-promoted to teacher despite guard_profile_role';
  end if;

  reset role;

  raise notice 'PASS: All 20261127220000 Security, RLS, Vector Search, Trigger & Storage Parity assertions succeeded.';
end $$;

rollback;
