begin;
set local search_path = public, extensions;
select plan(9);

select ok(not has_function_privilege('anon',
  'public.append_course_distribution_correction(uuid,integer,integer,text,jsonb,jsonb,jsonb,text)', 'execute'),
  'anonymous callers cannot execute the correction RPC');
select ok(has_function_privilege('authenticated',
  'public.append_course_distribution_correction(uuid,integer,integer,text,jsonb,jsonb,jsonb,text)', 'execute'),
  'authenticated callers may reach the capability-checked correction RPC');

-- The local harness supplies a scope fixture before this contract test.
insert into public.course_distribution_sources
  (id, scheduling_scope_id, source_hash, source_bytes, sheet_name, uploaded_by)
values
  ('10000000-0000-4000-8000-000000000001', null,
   '8dcc7e601606217f3b754766511182a916b17e9a26a94c9d887104eba92e9bb2',
   decode('504b0304', 'hex'), 'Course Distribution', null);

select is((select count(*) from public.course_distribution_sources), 1::bigint,
  'immutable source bytes are stored with a SHA-256 identity');

select throws_ok(
  $$update public.course_distribution_sources set sheet_name='changed' where id='10000000-0000-4000-8000-000000000001'$$,
  '23514', 'Course distribution source is immutable',
  'source metadata cannot be changed after ingestion');

insert into public.course_distribution_revisions
  (id, source_id, revision_number, status, created_by, correction_reason)
values
  ('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001',
   1, 'accepted', null, 'initial reviewed import');

insert into public.course_distribution_artifacts
  (id, revision_id, artifact_kind, status)
values
  ('30000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001',
   'normalized_input', 'current');

select throws_ok(
  $$select public.append_course_distribution_correction(
    '20000000-0000-4000-8000-000000000001', 1, 6, 'J',
    '"=SUM(A1:A2)"'::jsonb, '14'::jsonb, '14'::jsonb,
    'committee verified cached count')$$,
  '42501', 'Authentication is required for course distribution corrections',
  'unscoped SQL caller cannot bypass the correction RPC');

select is((select revision_version from public.course_distribution_revisions
           where id='20000000-0000-4000-8000-000000000001'), 1,
  'denied correction does not advance the revision');

select is((select count(*) from public.course_distribution_corrections
           where revision_id='20000000-0000-4000-8000-000000000001'
             and source_row=6 and source_column='J'), 0::bigint,
  'denied correction creates no provenance record');

select is((select status from public.course_distribution_artifacts
           where id='30000000-0000-4000-8000-000000000001'), 'current',
  'denied correction does not invalidate derived artifacts');

select throws_ok(
  $$select public.append_course_distribution_correction(
    '20000000-0000-4000-8000-000000000001', 1, 6, 'L',
    '"=J6/14"'::jsonb, '1'::jsonb, '1'::jsonb,
    'stale client')$$,
  '42501', 'Authentication is required for course distribution corrections',
  'unauthenticated stale attempt is denied before revision disclosure');

select * from finish();
rollback;
