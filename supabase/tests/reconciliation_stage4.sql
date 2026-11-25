-- ONLY empty universe-timetable-test, after stages 001-003. Run as postgres.
-- Synthetic Auth/profile fixtures; no Auth API, passwords, emails or webhooks.
-- Everything, including Auth users and publication writes, is rolled back.
-- Tests legacy single-scope behavior, NOT the future publication contract.
begin;
do $$
declare t record; populated boolean;
begin
  if current_user <> 'postgres' then
    raise exception 'Use SQL Editor postgres role in disposable test project';
  end if;
  if (select count(*) from pg_tables where schemaname = 'public') <> 18
     or (select count(*) from pg_policies where schemaname = 'public') <> 50
     or exists (select 1 from pg_tables where schemaname = 'public' and not rowsecurity) then
    raise exception 'Expected stages 001-003 with RLS intact';
  end if;
  -- Do not assume that a managed Auth schema accepts a particular fixture.
  if exists (select 1 from pg_attribute a
      where a.attrelid = 'auth.users'::regclass and a.attnum > 0
        and not a.attisdropped and a.attnotnull
        and a.attname not in ('id', 'email')
        and a.attidentity = '' and a.attgenerated = ''
        and not exists (select 1 from pg_attrdef d
          where d.adrelid = a.attrelid and d.adnum = a.attnum)) then
    raise exception 'Auth fixture requires additional columns; report error, do not bypass guard';
  end if;
  if exists (select 1 from pg_trigger
      where tgrelid = 'auth.users'::regclass and not tgisinternal)
     or (select count(*) from pg_trigger g join pg_class c on c.oid = g.tgrelid
         join pg_namespace n on n.oid = c.relnamespace
         where n.nspname = 'public' and not g.tgisinternal) <> 2
     or exists (select 1 from pg_trigger
         where tgrelid = 'public.notifications'::regclass and not tgisinternal) then
    raise exception 'Unexpected triggers; inspect before using Auth fixtures';
  end if;
  if exists (select 1 from auth.users) then
    raise exception 'Auth users already exist; use empty disposable test project';
  end if;
  for t in select tablename from pg_tables where schemaname = 'public' loop
    execute format('select exists (select 1 from public.%I)', t.tablename) into populated;
    if populated then
      raise exception 'Table % contains data; do not delete it or bypass guard', t.tablename;
    end if;
  end loop;
end $$;

-- Bootstrap synthetic profiles as postgres with no end-user JWT. Keep FKs enabled.
select set_config('request.jwt.claims', '{}', true);
select set_config('request.jwt.claim.sub', '', true);
insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-000000000401', 'admin@example.invalid'),
  ('00000000-0000-4000-8000-000000000402', 'teacher@example.invalid'),
  ('00000000-0000-4000-8000-000000000403', 'student-a@example.invalid'),
  ('00000000-0000-4000-8000-000000000404', 'student-b@example.invalid');
insert into public.profiles (id, email, role) values
  ('00000000-0000-4000-8000-000000000401', 'admin@example.invalid', 'admin'),
  ('00000000-0000-4000-8000-000000000402', 'teacher@example.invalid', 'teacher'),
  ('00000000-0000-4000-8000-000000000403', 'student-a@example.invalid', 'student'),
  ('00000000-0000-4000-8000-000000000404', 'student-b@example.invalid', 'student');
insert into public.device_tokens (token, user_id) values
  ('stage4-student-a', '00000000-0000-4000-8000-000000000403'),
  ('stage4-student-b', '00000000-0000-4000-8000-000000000404');

set local role authenticated;
select set_config('request.jwt.claims',
  '{"role":"authenticated","sub":"00000000-0000-4000-8000-000000000403","email":"student-a@example.invalid"}', true);
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000403', true);
do $$
declare affected integer;
begin
  if current_user <> 'authenticated' or public.my_role() is distinct from 'student'
     or public.is_admin() then raise exception 'Student context incorrect'; end if;
  if (select count(*) from public.device_tokens) <> 1
     or not exists (select 1 from public.device_tokens where token = 'stage4-student-a') then
    raise exception 'Student token ownership isolation failed';
  end if;
  update public.device_tokens set platform = 'unauthorized' where token = 'stage4-student-b';
  get diagnostics affected = row_count;
  if affected <> 0 then raise exception 'Student updated another token'; end if;
  delete from public.device_tokens where token = 'stage4-student-b';
  get diagnostics affected = row_count;
  if affected <> 0 then raise exception 'Student deleted another token'; end if;
  begin
    insert into public.device_tokens (token, user_id)
    values ('stage4-forged', '00000000-0000-4000-8000-000000000404');
    raise exception 'Student forged token owner';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.device_tokens
      set user_id = '00000000-0000-4000-8000-000000000404'
      where token = 'stage4-student-a';
    raise exception 'Student reassigned own token to another user';
  exception when insufficient_privilege then null;
  end;
  perform public.register_device_token('stage4-student-a-new', 'test');
  if not exists (select 1 from public.device_tokens
      where token = 'stage4-student-a-new' and user_id = auth.uid()) then
    raise exception 'Own token RPC registration failed';
  end if;
  update public.profiles set name = 'Synthetic student' where id = auth.uid();
  get diagnostics affected = row_count;
  if affected <> 1 then raise exception 'Student own-profile edit failed'; end if;
  update public.profiles set name = 'Unauthorized' where id = '00000000-0000-4000-8000-000000000404';
  get diagnostics affected = row_count;
  if affected <> 0 then raise exception 'Student changed another profile'; end if;
  begin
    update public.profiles set role = 'teacher' where id = auth.uid();
    raise exception 'Student self-promoted to teacher';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.profiles set role = 'admin' where id = auth.uid();
    raise exception 'Student self-promoted to admin';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.publish_routine('[{}]'::jsonb);
    raise exception 'Student published';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

set local role authenticated;
select set_config('request.jwt.claims',
  '{"role":"authenticated","sub":"00000000-0000-4000-8000-000000000402","email":"teacher@example.invalid"}', true);
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000402', true);
do $$
begin
  if public.my_role() is distinct from 'teacher' or public.is_admin() then
    raise exception 'Teacher context incorrect';
  end if;
  begin
    perform public.publish_routine('[{}]'::jsonb);
    raise exception 'Teacher published';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

set local role authenticated;
select set_config('request.jwt.claims',
  '{"role":"authenticated","sub":"00000000-0000-4000-8000-000000000401","email":"admin@example.invalid"}', true);
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000401', true);
do $$
declare
  result jsonb;
  first_version uuid;
  rows jsonb := '[{"day":"Sunday","time_start":"09:00","time_end":"10:00","subject":"Synthetic first","subject_code":"TEST-401","room":"TEST","batch":"TEST","section":"A","semester":1}]';
begin
  if public.my_role() is distinct from 'admin' or not public.is_admin() then
    raise exception 'Admin context incorrect';
  end if;
  result := public.publish_routine(rows, 'Synthetic test', 'manual');
  first_version := (result->>'version_id')::uuid;
  if first_version is null or (result->>'row_count')::integer is distinct from 1
     or (select count(*) from public.routines) <> 1
     or not exists (select 1 from public.routines
         where routine_version_id = first_version and subject = 'Synthetic first')
     or not exists (select 1 from public.routine_versions
         where id = first_version and is_active and row_count = 1 and published_by = auth.uid()) then
    raise exception 'Admin publication contract failed';
  end if;
  begin
    perform public.publish_routine('[]'::jsonb);
    raise exception 'Empty publication accepted';
  exception when invalid_parameter_value then null;
  end;
  -- Second row lacks mandatory subject: failure must roll back the preceding
  -- version insert, pointer flip, global delete and first row insert.
  begin
    perform public.publish_routine(rows || '[{"day":"Sunday","time_start":"10:00","time_end":"11:00","subject_code":"TEST-BAD","room":"TEST","batch":"TEST","section":"A"}]'::jsonb);
    raise exception 'Malformed publication accepted';
  exception when not_null_violation then null;
  end;
  if (select count(*) from public.routine_versions) <> 1
     or not exists (select 1 from public.routine_versions where id = first_version and is_active)
     or (select count(*) from public.routines) <> 1
     or not exists (select 1 from public.routines
         where routine_version_id = first_version and subject = 'Synthetic first') then
    raise exception 'Failed publication damaged previous snapshot';
  end if;
  result := public.publish_routine(
    jsonb_set(rows, '{0,subject}', '"Synthetic replacement"'), 'Synthetic test', 'manual');
  if (result->>'version_id')::uuid is not distinct from first_version
     or (result->>'row_count')::integer is distinct from 1
     or (select count(*) from public.routines) <> 1
     or not exists (select 1 from public.routines
         where subject = 'Synthetic replacement'
           and routine_version_id = (result->>'version_id')::uuid)
     or (select count(*) from public.routine_versions) <> 2
     or (select count(*) from public.routine_versions where is_active) <> 1
     or not exists (select 1 from public.routine_versions where id = first_version and not is_active) then
    raise exception 'Legacy replacement/version-pointer contract failed';
  end if;
end $$;
reset role;

-- ROLLBACK precedes the PASS result. Prove every fixture table is empty again.
rollback;
do $$
begin
  if exists (select 1 from auth.users) or exists (select 1 from public.profiles)
     or exists (select 1 from public.device_tokens) or exists (select 1 from public.routines)
     or exists (select 1 from public.routine_versions) then
    raise exception 'Fixture cleanup verification failed';
  end if;
end $$;
select 'PASS: stage 004 provisioned roles, token ownership, escalation denials, legacy publish atomicity; fixtures rolled back' as result;
