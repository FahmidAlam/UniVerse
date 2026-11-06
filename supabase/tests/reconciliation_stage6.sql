-- ONLY universe-timetable-test. Read-only catalog checks, no Storage API calls.
-- Before stage 005: expected missing-policy error; after stage 005: PASS.
-- This preserves observed legacy permissions for reconciliation, NOT approval.
begin;
do $$
begin
  if (select count(*) from storage.buckets) <> 4
     or (select array_agg(id order by id) from storage.buckets)
          is distinct from array['assignments','avatars','resources','timetables']::text[]
     or exists (select 1 from storage.buckets where name <> id or not public
                 or file_size_limit is not null or allowed_mime_types is not null) then
    raise exception 'Expected four source-matching public buckets with unset bucket restrictions';
  end if;
  if (select count(*) from pg_policies
      where schemaname = 'storage' and tablename in ('buckets','objects')) <> 4
     or exists (
       select 1 from (values
         ('storage_public_read', 'SELECT', array['public']::name[], 'true'::text, null::text),
         ('storage_auth_insert', 'INSERT', array['authenticated']::name[], null::text, 'true'::text),
         ('storage_auth_update', 'UPDATE', array['authenticated']::name[], 'true'::text, 'true'::text),
         ('storage_auth_delete', 'DELETE', array['authenticated']::name[], 'true'::text, null::text)
       ) e(name, command, roles, using_expression, check_expression)
       where not exists (select 1 from pg_policies p
         where p.schemaname = 'storage' and p.tablename = 'objects'
           and p.policyname = e.name and p.cmd = e.command
           and p.permissive = 'PERMISSIVE' and p.roles = e.roles
           and p.qual is not distinct from e.using_expression
           and p.with_check is not distinct from e.check_expression)
     ) then
    raise exception 'Expected four exact legacy storage.objects policies, no bucket policies';
  end if;
  if (select count(*) from pg_class c join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'storage' and c.relname in ('buckets','objects')
        and c.relrowsecurity and not c.relforcerowsecurity
        and pg_get_userbyid(c.relowner) = 'supabase_storage_admin') <> 2 then
    raise exception 'Managed Storage owner/RLS flags differ';
  end if;
  if exists (select 1 from storage.objects) then
    raise exception 'Expected empty Storage; do not delete files to satisfy this check';
  end if;
end $$;
rollback;
select 'PASS: stage 006 bucket and legacy Storage-policy catalog match; API authorization not tested' as result;
