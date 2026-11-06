-- Hosted test-project smoke check. Run before stage 002 (expected failure),
-- then after stage 002 (expected success). No pgTAP installation required.
-- Catalog checks only; role/fixture behavior and complete replay remain untested.
begin;
do $$
declare
  signature text;
begin
  if (select count(*) from pg_tables where schemaname = 'public') <> 18 then
    raise exception 'Expected 18 public tables';
  end if;
  if exists (select 1 from pg_tables
             where schemaname = 'public' and not rowsecurity) then
    raise exception 'Every public table must have RLS enabled';
  end if;
  if (select count(*) from pg_policies where schemaname = 'public') <> 50 then
    raise exception 'Expected 50 reconstructed public policies';
  end if;
  foreach signature in array array[
    'public.my_role()', 'public.is_admin()',
    'public.guard_profile_role()', 'public.calculate_is_late()',
    'public.match_documents(public.vector,integer)',
    'public.register_device_token(text,text)',
    'public.publish_routine(jsonb,text,text,jsonb,jsonb,text)'
  ] loop
    if to_regprocedure(signature) is null then
      raise exception 'Missing function: %', signature;
    end if;
  end loop;
  foreach signature in array array[
    'public.my_role()', 'public.is_admin()',
    'public.register_device_token(text,text)',
    'public.publish_routine(jsonb,text,text,jsonb,jsonb,text)'
  ] loop
    if has_function_privilege('anon', to_regprocedure(signature)::oid, 'EXECUTE')
       or not has_function_privilege('authenticated', to_regprocedure(signature)::oid, 'EXECUTE') then
      raise exception 'Unexpected RPC grants: %', signature;
    end if;
  end loop;
  if not exists (select 1 from pg_trigger
      where tgrelid = 'public.profiles'::regclass
        and tgname = 'profiles_guard_role' and not tgisinternal
        and tgfoid = 'public.guard_profile_role()'::regprocedure
        and tgtype = 23 and tgenabled = 'O')
     or not exists (select 1 from pg_trigger
      where tgrelid = 'public.submissions'::regclass
        and tgname = 'trigger_calculate_is_late' and not tgisinternal
        and tgfoid = 'public.calculate_is_late()'::regprocedure
        and tgtype = 23 and tgenabled = 'O') then
    raise exception 'Missing BEFORE INSERT OR UPDATE row trigger';
  end if;
  if exists (select 1 from pg_trigger
      where tgrelid = 'public.notifications'::regclass and not tgisinternal) then
    raise exception 'Test project must not contain notification webhook triggers';
  end if;
  -- Table grants intentionally remain closed until the next reviewed stage.
  if exists (select 1 from pg_tables t
      cross join (values ('anon'), ('authenticated')) as roles(name)
      cross join (values ('SELECT'), ('INSERT'), ('UPDATE'), ('DELETE'),
                         ('TRUNCATE'), ('REFERENCES'), ('TRIGGER')) as privileges(name)
      where t.schemaname = 'public'
        and has_table_privilege(roles.name,
          format('%I.%I', t.schemaname, t.tablename), privileges.name)) then
    raise exception 'Client table privileges must remain denied at stage 002';
  end if;
end $$;
select 'PASS: stage 002 catalog smoke checks; table grants remain closed' as result;
rollback;
