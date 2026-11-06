-- ONLY universe-timetable-test. Run as SQL Editor postgres role.
-- Before stage 003: expected failure for missing client DML privileges.
-- After stage 003: expected PASS. All synthetic fixture writes roll back.
-- Covers anon and an authenticated identity with NO profile; does not cover
-- provisioned student/teacher/admin roles, publication success, or restore.
begin;
do $$
begin
  if (select count(*) from pg_tables where schemaname = 'public') <> 18
     or (select count(*) from pg_policies where schemaname = 'public') <> 50 then
    raise exception 'Expected completed stages 001 and 002 in test project';
  end if;
  if exists (select 1 from pg_tables
      where schemaname = 'public' and not rowsecurity) then
    raise exception 'Every public table must retain RLS';
  end if;
  if exists (select 1 from pg_tables t
      cross join (values ('anon'), ('authenticated')) as roles(name)
      cross join (values ('SELECT'), ('INSERT'), ('UPDATE'), ('DELETE')) as privileges(name)
      where t.schemaname = 'public'
        and not has_table_privilege(roles.name,
          format('%I.%I', t.schemaname, t.tablename), privileges.name)) then
    raise exception 'Missing client DML privileges: run stage 003 in test project';
  end if;
  if exists (select 1 from pg_tables t
      cross join (values ('anon'), ('authenticated')) as roles(name)
      cross join (values ('TRUNCATE'), ('REFERENCES'), ('TRIGGER')) as privileges(name)
      where t.schemaname = 'public'
        and has_table_privilege(roles.name,
          format('%I.%I', t.schemaname, t.tablename), privileges.name)) then
    raise exception 'Unsafe maintenance privileges present';
  end if;
  if exists (select 1 from public.routines)
     or exists (select 1 from public.profiles)
     or exists (select 1 from public.whitelists)
     or exists (select 1 from public.routine_versions) then
    raise exception 'Expected empty disposable fixtures; do not clear existing data';
  end if;
  if exists (select 1 from pg_trigger
      where tgrelid = 'public.notifications'::regclass and not tgisinternal) then
    raise exception 'Refusing tests with notification webhook installed';
  end if;
end $$;

-- No auth.users inserts or foreign-key bypasses needed for this fixture.
insert into public.routines
  (id, day, time_start, time_end, subject, subject_code, room, batch, section, semester)
values
  ('00000000-0000-4000-8000-000000000301', 'Sunday', '09:00', '10:00',
   'Synthetic authorization fixture', 'TEST-003', 'TEST-ROOM', 'TEST', 'A', 1);

set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
select set_config('request.jwt.claim.sub', '', true);
do $$
begin
  if current_user <> 'anon' or auth.uid() is not null then
    raise exception 'Anonymous test context not established';
  end if;
  if exists (select 1 from public.routines) then
    raise exception 'Anonymous caller read a routine';
  end if;
  begin
    insert into public.routines
      (day, time_start, time_end, subject, subject_code, room, batch, section, semester)
    values ('Sunday', '10:00', '11:00', 'Unauthorized', 'TEST-DENY', 'TEST', 'TEST', 'A', 1);
    raise exception 'Anonymous routine insert unexpectedly succeeded';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.publish_routine('[{}]'::jsonb);
    raise exception 'Anonymous publish unexpectedly succeeded';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.register_device_token('synthetic-test-token', 'test');
    raise exception 'Anonymous token registration unexpectedly succeeded';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

set local role authenticated;
select set_config('request.jwt.claims',
  '{"role":"authenticated","sub":"00000000-0000-4000-8000-000000000302","email":"unprovisioned@example.invalid"}', true);
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000302', true);
do $$
declare affected integer;
begin
  if current_user <> 'authenticated'
     or auth.uid() is distinct from '00000000-0000-4000-8000-000000000302'::uuid then
    raise exception 'Authenticated test context not established';
  end if;
  if public.my_role() is not null or public.is_admin() then
    raise exception 'Unprovisioned identity acquired a profile role';
  end if;
  if (select count(*) from public.routines
      where id = '00000000-0000-4000-8000-000000000301') <> 1 then
    raise exception 'Authenticated reader did not see the fixture';
  end if;
  update public.routines set subject = 'Unauthorized change'
    where id = '00000000-0000-4000-8000-000000000301';
  get diagnostics affected = row_count;
  if affected <> 0 then raise exception 'Non-admin updated a routine'; end if;
  delete from public.routines
    where id = '00000000-0000-4000-8000-000000000301';
  get diagnostics affected = row_count;
  if affected <> 0 then raise exception 'Non-admin deleted a routine'; end if;
  begin
    insert into public.routines
      (day, time_start, time_end, subject, subject_code, room, batch, section, semester)
    values ('Sunday', '10:00', '11:00', 'Unauthorized', 'TEST-DENY', 'TEST', 'TEST', 'A', 1);
    raise exception 'Non-admin routine insert unexpectedly succeeded';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.publish_routine('[{}]'::jsonb);
    raise exception 'Non-admin publish unexpectedly succeeded';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

do $$
begin
  if (select count(*) from public.routines) <> 1
     or not exists (select 1 from public.routines
       where id = '00000000-0000-4000-8000-000000000301'
         and subject = 'Synthetic authorization fixture')
     or exists (select 1 from public.routine_versions) then
    raise exception 'Unauthorized operation changed fixture/version state';
  end if;
end $$;
rollback;
select 'PASS: stage 003 DML grants, anon denials, authenticated read/non-admin denials; fixture rolled back' as result;
