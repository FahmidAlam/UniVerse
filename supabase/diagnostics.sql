-- ============================================================
-- DIAGNOSTICS — read-only DB introspection for cleanup + RLS audit
-- ONE query → one JSON cell. Run it all, click the result cell,
-- copy, and paste back. Nothing here mutates data.
--
-- Row counts come from pg_stat_user_tables (live-tuple estimates) so
-- the query never errors on a missing table. They're approximate —
-- before DROPping anything I'll have you run an exact count(*) on
-- that single table to be 100% sure it's empty.
-- ============================================================

select jsonb_pretty(jsonb_build_object(

  -- Tables: RLS flag + policy count + estimated rows
  'tables', (
    select jsonb_agg(jsonb_build_object(
      'table',       c.relname,
      'rls_enabled', c.relrowsecurity,
      'policies',    (select count(*) from pg_policies p
                        where p.schemaname = 'public' and p.tablename = c.relname),
      'est_rows',    greatest(c.reltuples::bigint, 0)
    ) order by c.relname)
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r'
  ),

  -- RLS GAP FINDER: RLS off OR zero policies
  'rls_gaps', (
    select jsonb_agg(jsonb_build_object(
      'table',        c.relname,
      'rls_on',       c.relrowsecurity,
      'policy_count', (select count(*) from pg_policies p
                         where p.schemaname = 'public' and p.tablename = c.relname)
    ) order by c.relname)
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r'
      and (c.relrowsecurity = false
           or (select count(*) from pg_policies p
                 where p.schemaname = 'public' and p.tablename = c.relname) = 0)
  ),

  -- Live-tuple row estimates per table (no enumeration, never errors)
  'row_estimates', (
    select jsonb_object_agg(relname, n_live_tup)
    from pg_stat_user_tables where schemaname = 'public'
  ),

  -- Columns for every public table
  'columns', (
    select jsonb_agg(jsonb_build_object(
      'table',    table_name,
      'column',   column_name,
      'type',     data_type,
      'nullable', is_nullable,
      'default',  column_default
    ) order by table_name, ordinal_position)
    from information_schema.columns where table_schema = 'public'
  ),

  -- All RLS policies (full definitions)
  'policies', (
    select jsonb_agg(jsonb_build_object(
      'table',  tablename, 'policy', policyname, 'cmd', cmd,
      'roles',  roles, 'using', qual, 'check', with_check
    ) order by tablename, policyname)
    from pg_policies where schemaname = 'public'
  ),

  -- Foreign keys (dependency map before dropping anything)
  'foreign_keys', (
    select jsonb_agg(jsonb_build_object(
      'table',      tc.table_name,
      'column',     kcu.column_name,
      'references', ccu.table_name,
      'ref_column', ccu.column_name
    ))
    from information_schema.table_constraints tc
    join information_schema.key_column_usage kcu
      on tc.constraint_name = kcu.constraint_name and tc.table_schema = kcu.table_schema
    join information_schema.constraint_column_usage ccu
      on ccu.constraint_name = tc.constraint_name and ccu.table_schema = tc.table_schema
    where tc.constraint_type = 'FOREIGN KEY' and tc.table_schema = 'public'
  ),

  -- Functions / RPCs in public
  'functions', (
    select jsonb_agg(jsonb_build_object(
      'name', p.proname,
      'args', pg_get_function_identity_arguments(p.oid),
      'returns', pg_get_function_result(p.oid),
      'security_definer', p.prosecdef
    ) order by p.proname)
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
  ),

  -- Triggers (incl. the notifications->send-push webhook)
  'triggers', (
    select jsonb_agg(jsonb_build_object(
      'table', event_object_table, 'trigger', trigger_name,
      'event', event_manipulation, 'timing', action_timing,
      'action', action_statement
    ) order by event_object_table, trigger_name)
    from information_schema.triggers where trigger_schema = 'public'
  ),

  -- Storage buckets + object counts
  'buckets', (
    select jsonb_agg(jsonb_build_object(
      'bucket', b.id, 'public', b.public,
      'objects', (select count(*) from storage.objects o where o.bucket_id = b.id)
    ) order by b.id)
    from storage.buckets b
  ),

  -- Storage policies on storage.objects
  'storage_policies', (
    select jsonb_agg(jsonb_build_object(
      'policy', policyname, 'cmd', cmd, 'roles', roles,
      'using', qual, 'check', with_check
    ) order by policyname)
    from pg_policies where schemaname = 'storage' and tablename = 'objects'
  )

)) as diagnostics;
