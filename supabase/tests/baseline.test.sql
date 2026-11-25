-- Initial repository-derived baseline contract, NOT a deployed-schema snapshot.
-- Run only in an authorized disposable database with pgTAP already available.
-- No fixtures, migrations, external calls or application writes are performed.
-- These catalog checks do not replace role-based RLS/Edge Function tests,
-- full column/FK/policy reconciliation, or the twice-repeated restore drill.
begin;
select no_plan();

-- Source: AppConstants table names used by the current Dart services.
select has_table('public', name, 'Dart table exists: ' || name)
from unnest(array[
  'whitelists', 'profiles', 'routines', 'routine_versions',
  'cancellations', 'notifications', 'notification_reads', 'resources',
  'assignments', 'submissions', 'documents', 'device_tokens',
  'timetable_rooms', 'timetable_faculty', 'timetable_settings',
  'timetable_runs', 'timetable_course_eligibility'
]) as expected(name);

-- Sources: migrations 006, 008, 012 and 013. Missing tables fail too.
select ok(coalesce((
  select c.relrowsecurity from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relname = name and c.relkind = 'r'
), false), 'RLS enabled: ' || name)
from unnest(array[
  'whitelists', 'profiles', 'routines', 'routine_versions',
  'cancellations', 'notifications', 'notification_reads', 'resources',
  'assignments', 'submissions', 'documents', 'device_tokens',
  'timetable_rooms', 'timetable_faculty', 'timetable_settings',
  'timetable_runs', 'timetable_course_eligibility'
]) as expected(name);

-- Sources: migrations 005, 006, 012/014 and their Dart callers.
-- Missing signatures must fail, rather than silently passing a privilege check.
with expected(signature) as (values
  ('public.register_device_token(text,text)'),
  ('public.my_role()'),
  ('public.is_admin()'),
  ('public.publish_routine(jsonb,text,text,jsonb,jsonb,text)')
)
select ok(to_regprocedure(signature) is not null,
          'RPC signature exists: ' || signature)
from expected;

-- Required security contract; not a claim that repository or deployed grants
-- already satisfy it. Effective privilege includes inherited PUBLIC grants.
with expected(signature) as (values
  ('public.register_device_token(text,text)'),
  ('public.my_role()'),
  ('public.is_admin()'),
  ('public.publish_routine(jsonb,text,text,jsonb,jsonb,text)')
)
select ok(case when to_regprocedure(signature) is null then false
               else not has_function_privilege(
                 'anon', to_regprocedure(signature)::oid, 'EXECUTE') end,
          'Anonymous execution denied: ' || signature)
from expected;

select has_column('public', 'routines', 'routine_version_id',
                  'Legacy routine version reference remains available');
select has_trigger('public', 'profiles', 'profiles_guard_role',
                   'Profile role guard exists (migration 016)');

select * from finish();
rollback;
