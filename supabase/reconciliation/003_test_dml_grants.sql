-- ONLY universe-timetable-test, after stages 001/002; NOT a production migration.
-- Deliberate restricted test variant of supplied deployment grants:
-- reproduce client SELECT/INSERT/UPDATE/DELETE, omit TRUNCATE/REFERENCES/TRIGGER.
-- RLS remains enabled. Does not alter policies, Storage, Realtime or row data.
begin;
do $$
declare table_name text;
begin
  if (select count(*) from pg_tables where schemaname = 'public') <> 18
     or (select count(*) from pg_policies where schemaname = 'public') <> 50 then
    raise exception 'Expected completed stages 001 and 002 in disposable test project';
  end if;
  if exists (select 1 from pg_tables
      where schemaname = 'public' and not rowsecurity) then
    raise exception 'Refusing grants while any public table has RLS disabled';
  end if;
  if exists (select 1 from pg_tables t
      cross join (values ('anon'), ('authenticated')) as roles(name)
      cross join (values ('SELECT'), ('INSERT'), ('UPDATE'), ('DELETE'),
                         ('TRUNCATE'), ('REFERENCES'), ('TRIGGER')) as privileges(name)
      where t.schemaname = 'public'
        and has_table_privilege(roles.name,
          format('%I.%I', t.schemaname, t.tablename), privileges.name)) then
    raise exception 'Expected stage 002 closed table grants; do not rerun or use production';
  end if;
  if exists (select 1 from pg_trigger
      where tgrelid = 'public.notifications'::regclass and not tgisinternal) then
    raise exception 'Refusing grants with notification webhook installed';
  end if;
  foreach table_name in array array[
    'assignments', 'cancellations', 'device_tokens', 'documents',
    'notification_reads', 'notifications', 'profiles', 'resources',
    'routine_versions', 'routines', 'submissions', 'timetable_course_eligibility',
    'timetable_courses', 'timetable_faculty', 'timetable_rooms',
    'timetable_runs', 'timetable_settings', 'whitelists'
  ] loop
    if to_regclass(format('public.%I', table_name)) is null then
      raise exception 'Missing expected baseline table: %', table_name;
    end if;
    execute format(
      'grant select, insert, update, delete on table public.%I to anon, authenticated',
      table_name);
  end loop;
end $$;
commit;
