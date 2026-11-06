-- READ ONLY: run separately in UniVerse and universe-timetable-test.
-- Returns one metadata cell; no object names/content, users, keys or webhooks.
-- Do not replace this with direct writes to managed storage tables.
select jsonb_pretty(jsonb_build_object(
  'database_timezone', current_setting('TimeZone'),
  'buckets', (
    select coalesce(jsonb_agg(jsonb_build_object(
      'id', b.id, 'name', b.name, 'public', b.public,
      'file_size_limit', b.file_size_limit,
      'allowed_mime_types', b.allowed_mime_types
    ) order by b.id), '[]'::jsonb)
    from storage.buckets b
  ),
  'storage_table_security', (
    select jsonb_agg(jsonb_build_object(
      'table', c.relname, 'owner', pg_get_userbyid(c.relowner),
      'rls', c.relrowsecurity, 'force_rls', c.relforcerowsecurity
    ) order by c.relname)
    from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'storage' and c.relname in ('buckets', 'objects')
  ),
  'storage_policies', (
    select coalesce(jsonb_agg(jsonb_build_object(
      'table', tablename, 'name', policyname, 'permissive', permissive,
      'roles', roles, 'command', cmd, 'using', qual, 'check', with_check
    ) order by tablename, policyname), '[]'::jsonb)
    from pg_policies
    where schemaname = 'storage' and tablename in ('buckets', 'objects')
  ),
  'storage_effective_privileges', (
    select jsonb_agg(jsonb_build_object(
      'role', r.name, 'table', t.name, 'privilege', p.name,
      'allowed', has_table_privilege(r.name, 'storage.' || t.name, p.name)
    ) order by r.name, t.name, p.name)
    from (values ('anon'), ('authenticated')) r(name)
    cross join (values ('buckets'), ('objects')) t(name)
    cross join (values ('SELECT'), ('INSERT'), ('UPDATE'), ('DELETE'),
                       ('TRUNCATE'), ('REFERENCES'), ('TRIGGER')) p(name)
  ),
  'realtime_publication', (
    select jsonb_agg(jsonb_build_object(
      'name', pubname, 'owner', pg_get_userbyid(pubowner),
      'all_tables', puballtables, 'insert', pubinsert, 'update', pubupdate,
      'delete', pubdelete, 'truncate', pubtruncate, 'via_root', pubviaroot
    )) from pg_publication where pubname = 'supabase_realtime'
  ),
  'realtime_membership', (
    select coalesce(jsonb_agg(jsonb_build_object(
      'schema', schemaname, 'table', tablename,
      'columns', attnames, 'row_filter', rowfilter
    ) order by schemaname, tablename), '[]'::jsonb)
    from pg_publication_tables where pubname = 'supabase_realtime'
  ),
  'public_replica_identity', (
    select jsonb_agg(jsonb_build_object(
      'table', c.relname, 'identity', c.relreplident
    ) order by c.relname)
    from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r', 'p')
  )
)) as storage_realtime_inventory;
