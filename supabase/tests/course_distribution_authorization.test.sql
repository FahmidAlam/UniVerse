begin;
set local search_path = public, extensions;
select plan(19);

select ok(not has_function_privilege('anon','public.append_course_distribution_correction(uuid,integer,integer,text,jsonb,jsonb,jsonb,text)','execute'),'anon execution is revoked');
select ok(has_function_privilege('authenticated','public.append_course_distribution_correction(uuid,integer,integer,text,jsonb,jsonb,jsonb,text)','execute'),'authenticated reaches capability gate');
select ok(not has_function_privilege('anon','public.read_course_distribution_revision(uuid)','execute'),'anon cannot fetch an accepted source revision');
select ok(has_function_privilege('authenticated','public.read_course_distribution_revision(uuid)','execute'),'authenticated reaches the source-revision capability gate');

insert into auth.users(id,email) values
 ('51000000-0000-4000-8000-000000000001','distribution-editor@example.invalid'),
 ('51000000-0000-4000-8000-000000000002','distribution-reader@example.invalid'),
 ('51000000-0000-4000-8000-000000000003','distribution-outsider@example.invalid');
insert into departments(id,code,name) values ('52000000-0000-4000-8000-000000000001','DST','Distribution test');
insert into academic_calendars(id,name,timezone) values ('52000000-0000-4000-8000-000000000002','Distribution calendar','Asia/Dhaka');
insert into academic_years(id,calendar_id,label) values ('52000000-0000-4000-8000-000000000003','52000000-0000-4000-8000-000000000002','2026');
insert into programs(id,department_id,calendar_id,code,title) values ('52000000-0000-4000-8000-000000000004','52000000-0000-4000-8000-000000000001','52000000-0000-4000-8000-000000000002','DST','Distribution test');
insert into academic_terms(id,academic_year_id,sequence,label,start_date,end_date) values ('52000000-0000-4000-8000-000000000005','52000000-0000-4000-8000-000000000003',1,'Test','2026-01-01','2026-12-31');
insert into scheduling_scopes(id,department_id,program_id,term_id) values ('52000000-0000-4000-8000-000000000006','52000000-0000-4000-8000-000000000001','52000000-0000-4000-8000-000000000004','52000000-0000-4000-8000-000000000005');
insert into department_memberships(user_id,department_id,program_id,capabilities) values
 ('51000000-0000-4000-8000-000000000001','52000000-0000-4000-8000-000000000001','52000000-0000-4000-8000-000000000004',array['edit_draft']),
 ('51000000-0000-4000-8000-000000000002','52000000-0000-4000-8000-000000000001','52000000-0000-4000-8000-000000000004',array['read_catalog']);
insert into course_distribution_sources(id,scheduling_scope_id,source_hash,source_bytes,sheet_name) values ('53000000-0000-4000-8000-000000000001','52000000-0000-4000-8000-000000000006','8dcc7e601606217f3b754766511182a916b17e9a26a94c9d887104eba92e9bb2',decode('504b0304','hex'),'Course Distribution');
insert into course_distribution_revisions(id,source_id,revision_number,status,correction_reason) values ('53000000-0000-4000-8000-000000000002','53000000-0000-4000-8000-000000000001',1,'accepted','initial');
insert into course_distribution_artifacts(id,revision_id,artifact_kind) values ('53000000-0000-4000-8000-000000000003','53000000-0000-4000-8000-000000000002','normalized_input');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select lives_ok($$select append_course_distribution_correction('53000000-0000-4000-8000-000000000002',1,6,'J','"=7*2"'::jsonb,'14'::jsonb,'14'::jsonb,'reviewed')$$,'edit_draft correction succeeds');
select is((select revision_version from course_distribution_revisions where id='53000000-0000-4000-8000-000000000002'),2,'success advances version');
select is((select count(*) from course_distribution_corrections where revision_id='53000000-0000-4000-8000-000000000002'),1::bigint,'success creates exactly one immutable correction');
select is((select status from course_distribution_artifacts where id='53000000-0000-4000-8000-000000000003'),'stale','success invalidates derived artifact');
select set_config('request.jwt.claims','{"sub":"51000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select throws_ok($$select append_course_distribution_correction('53000000-0000-4000-8000-000000000002',2,6,'L',null,'1'::jsonb,'1'::jsonb,'reader')$$,'42501','Course distribution correction needs scoped edit_draft capability','member without capability is rejected');
select is((select count(*) from course_distribution_corrections where revision_id='53000000-0000-4000-8000-000000000002'),1::bigint,'denied caller leaves correction history unchanged');
select lives_ok($$select public.read_course_distribution_revision('53000000-0000-4000-8000-000000000002')$$,'active scoped member can fetch an accepted revision bundle');
select is((public.read_course_distribution_revision('53000000-0000-4000-8000-000000000002')->>'source_sha256'),'8dcc7e601606217f3b754766511182a916b17e9a26a94c9d887104eba92e9bb2','revision bundle preserves immutable source hash');
select set_config('request.jwt.claims','{"sub":"51000000-0000-4000-8000-000000000003","role":"authenticated"}',true);
select throws_ok($$select public.read_course_distribution_revision('53000000-0000-4000-8000-000000000002')$$,'42501','Course distribution generation needs scoped read_catalog capability','non-member cannot fetch an accepted revision bundle');
reset role;
delete from department_memberships where user_id='51000000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select throws_ok($$select append_course_distribution_correction('53000000-0000-4000-8000-000000000002',2,6,'L',null,'1'::jsonb,'1'::jsonb,'revoked')$$,'42501','Course distribution correction needs scoped edit_draft capability','revoked capability is rejected');
select set_config('request.jwt.claims','{}',true);
select throws_ok($$select append_course_distribution_correction('53000000-0000-4000-8000-000000000002',2,6,'L',null,'1'::jsonb,'1'::jsonb,'unauthenticated')$$,'42501','Authentication is required for course distribution corrections','unauthenticated invocation is rejected');
select throws_ok($$select public.read_course_distribution_revision('53000000-0000-4000-8000-000000000002')$$,'42501','Authentication is required for course distribution generation','unauthenticated caller cannot fetch an accepted revision bundle');
reset role;
set local role anon;
select throws_ok($$select append_course_distribution_correction('53000000-0000-4000-8000-000000000002',2,6,'L',null,'1'::jsonb,'1'::jsonb,'anon')$$,'42501',null,'anonymous invocation is denied');
reset role;
insert into department_memberships(user_id,department_id,program_id,capabilities) values ('51000000-0000-4000-8000-000000000001','52000000-0000-4000-8000-000000000001','52000000-0000-4000-8000-000000000004',array['edit_draft']);
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"51000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select throws_ok($$select append_course_distribution_correction('53000000-0000-4000-8000-000000000002',1,6,'L',null,'1'::jsonb,'1'::jsonb,'stale')$$,'40001','Stale course distribution revision','stale expected version is rejected');
select is((select revision_version from course_distribution_revisions where id='53000000-0000-4000-8000-000000000002'),2,'rejections leave source revision unchanged');
reset role;
select * from finish();
rollback;
