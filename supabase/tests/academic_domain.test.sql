-- Task 2: synthetic, rollback-only; use the owned local verifier, never production.
begin;
set local search_path = public, extensions;
select no_plan();

select has_table('public', t, 'Academic catalog table: ' || t)
from unnest(array['departments','programs','academic_calendars','academic_years',
  'academic_terms','cohorts','student_groups','cohort_terms','scheduling_scopes',
  'department_memberships','group_aliases','group_alias_members',
  'routine_group_links','academic_mapping_batches','academic_mapping_quarantine']) t;
select has_function('public','academic_catalog',array[]::text[],'Atomic catalog snapshot exists');
select has_function('public','apply_academic_mapping',array['uuid'],'Reviewed mapping application exists');
select ok(not has_function_privilege('anon','public.academic_catalog()','execute'),'Anonymous catalog RPC denied');

-- Controlled synthetic users/profiles; all rolled back.
insert into auth.users(id,email) values
 ('10000000-0000-0000-0000-000000000001','academic-admin@example.invalid'),
 ('10000000-0000-0000-0000-000000000002','academic-editor@example.invalid'),
 ('10000000-0000-0000-0000-000000000003','academic-other@example.invalid'),
 ('10000000-0000-0000-0000-000000000004','academic-outsider@example.invalid');
insert into public.profiles(id,email,role) select id,email,
 case when email='academic-admin@example.invalid' then 'admin' else 'teacher' end
 from auth.users where email like 'academic-%@example.invalid';

-- The synthetic fixture uses stable UUIDs and deliberately different calendars.
insert into departments(id,code,name) values
 ('20000000-0000-0000-0000-000000000001','CSE','Synthetic computing'),
 ('20000000-0000-0000-0000-000000000002','EEE','Synthetic electrical');
insert into academic_calendars(id,name,timezone) values
 ('20000000-0000-0000-0000-000000000003','Three terms','Asia/Dhaka'),
 ('20000000-0000-0000-0000-000000000004','Four terms','Asia/Dhaka');
insert into academic_years(id,calendar_id,label) values
 ('20000000-0000-0000-0000-000000000005','20000000-0000-0000-0000-000000000003','2026'),
 ('20000000-0000-0000-0000-000000000006','20000000-0000-0000-0000-000000000004','2026');
insert into programs(id,department_id,calendar_id,code,title) values
 ('20000000-0000-0000-0000-000000000007','20000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000003','BSc','Synthetic program'),
 ('20000000-0000-0000-0000-000000000008','20000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000004','BSc','Synthetic program');
insert into academic_terms(id,academic_year_id,sequence,label,start_date,end_date) values
 ('20000000-0000-0000-0000-000000000009','20000000-0000-0000-0000-000000000005',3,'Third','2026-09-01','2026-12-31'),
 ('20000000-0000-0000-0000-000000000010','20000000-0000-0000-0000-000000000006',4,'Fourth','2026-09-01','2026-12-31');
insert into cohorts(id,program_id,code,admitted_on) values
 ('20000000-0000-0000-0000-000000000011','20000000-0000-0000-0000-000000000007','66','2025-01-01'),
 ('20000000-0000-0000-0000-000000000012','20000000-0000-0000-0000-000000000008','66','2024-01-01');
insert into student_groups(id,cohort_id,code) values
 ('20000000-0000-0000-0000-000000000014','20000000-0000-0000-0000-000000000011','B'),
 ('20000000-0000-0000-0000-000000000015','20000000-0000-0000-0000-000000000011','C'),
 ('20000000-0000-0000-0000-000000000016','20000000-0000-0000-0000-000000000012','B');
insert into cohort_terms(cohort_id,term_id,study_stage) values
 ('20000000-0000-0000-0000-000000000011','20000000-0000-0000-0000-000000000009',3),
 ('20000000-0000-0000-0000-000000000012','20000000-0000-0000-0000-000000000010',5);
insert into scheduling_scopes(id,department_id,program_id,term_id) values
 ('20000000-0000-0000-0000-000000000024','20000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000007','20000000-0000-0000-0000-000000000009'),
 ('20000000-0000-0000-0000-000000000025','20000000-0000-0000-0000-000000000001',null,'20000000-0000-0000-0000-000000000009');
select throws_ok($$insert into scheduling_scopes(department_id,program_id,term_id)
 values ('20000000-0000-0000-0000-000000000001',null,'20000000-0000-0000-0000-000000000009')$$,
 '23505',null,'Nullable program scopes are unique');
select throws_ok($$insert into cohort_terms(cohort_id,term_id,study_stage)
 values ('20000000-0000-0000-0000-000000000011','20000000-0000-0000-0000-000000000010',1)$$,
 '23514',null,'Cross-calendar progression rejected');
insert into group_aliases(id,cohort_id,label) values
 ('20000000-0000-0000-0000-000000000027','20000000-0000-0000-0000-000000000011','B+C');
insert into group_alias_members(alias_id,cohort_id,group_id) values
 ('20000000-0000-0000-0000-000000000027','20000000-0000-0000-0000-000000000011','20000000-0000-0000-0000-000000000014'),
 ('20000000-0000-0000-0000-000000000027','20000000-0000-0000-0000-000000000011','20000000-0000-0000-0000-000000000015');
select throws_ok($$insert into group_alias_members(alias_id,cohort_id,group_id) values
 ('20000000-0000-0000-0000-000000000027','20000000-0000-0000-0000-000000000011','20000000-0000-0000-0000-000000000016')$$,
 '23503',null,'Alias cannot link another cohort');
select throws_ok($$insert into group_aliases(cohort_id,label) values
 ('20000000-0000-0000-0000-000000000011',E'\ufeffB+C')$$,
 '23505',null,'Normalized alias ambiguity rejected');

insert into department_memberships(user_id,department_id,program_id,capabilities) values
 ('10000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000007',array['manage_catalog']),
 ('10000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000002',null,array['read_catalog']);
insert into department_memberships(user_id,department_id,capabilities,valid_from,valid_until) values
 ('10000000-0000-0000-0000-000000000004','20000000-0000-0000-0000-000000000001',array['manage_catalog'],now()-interval '2 days',now()-interval '1 day');
-- A department-wide scope may use another program's calendar. Its readable
-- snapshot must include the referenced term/year/calendar without that program.
insert into scheduling_scopes(department_id,program_id,term_id) values
 ('20000000-0000-0000-0000-000000000001',null,'20000000-0000-0000-0000-000000000010');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"10000000-0000-0000-0000-000000000002","role":"authenticated"}',true);
select is((select count(*)::int from programs),1,'Editor reads only its program');
select ok(not exists(
 select 1 from jsonb_array_elements(academic_catalog()->'scopes') s
 where not exists(select 1 from jsonb_array_elements(academic_catalog()->'terms') t where t->>'id'=s->>'term_id')
),'Scoped snapshot includes every referenced term across calendars');
select lives_ok($$insert into student_groups(cohort_id,code) values ('20000000-0000-0000-0000-000000000011','D')$$,'Editor can edit own catalog');
select throws_ok($$insert into student_groups(cohort_id,code) values ('20000000-0000-0000-0000-000000000012','D')$$,
 '42501',null,'Editor cannot edit another department');
select throws_ok($$update group_aliases set reviewed=true where id='20000000-0000-0000-0000-000000000027'$$,
 '42501',null,'Editor cannot approve its own alias without approve capability');
select throws_ok($$insert into department_memberships(user_id,department_id,capabilities) values
 ('10000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000002',array['manage_catalog'])$$,
 '42501',null,'Editor cannot self-grant scope membership');
select throws_ok($$update profiles set department_id='20000000-0000-0000-0000-000000000002' where id=auth.uid()$$,
 '42501',null,'Self-edit cannot change canonical affiliations');
select is(jsonb_array_length(academic_catalog()->'programs'),1,'Snapshot follows RLS');
select lives_ok($$select replace_academic_alias_members('20000000-0000-0000-0000-000000000027',
 array['20000000-0000-0000-0000-000000000014','20000000-0000-0000-0000-000000000015']::uuid[])$$,'Alias membership replacement is atomic');
select throws_ok($$select replace_academic_alias_members('20000000-0000-0000-0000-000000000027',
 array['20000000-0000-0000-0000-000000000016']::uuid[])$$,'23503',null,'Invalid alias replacement rolls back');
select is((select count(*)::int from group_alias_members where alias_id='20000000-0000-0000-0000-000000000027'),2,'Failed replacement preserves old members');
select throws_ok($$select review_academic_alias('20000000-0000-0000-0000-000000000027')$$,'42501',null,'Review RPC checks scoped approve capability');
select set_config('request.jwt.claims','{"sub":"10000000-0000-0000-0000-000000000004","role":"authenticated"}',true);
select is((select count(*)::int from student_groups),0,'Unscoped user reads no student group catalog');
select is(jsonb_array_length(academic_catalog()->'programs'),0,'Unscoped snapshot has no programs');
reset role;
select set_config('request.jwt.claims','{}',true);

update group_aliases set reviewed=true where id='20000000-0000-0000-0000-000000000027';
delete from group_alias_members where alias_id='20000000-0000-0000-0000-000000000027' and group_id='20000000-0000-0000-0000-000000000015';
select is((select reviewed from group_aliases where id='20000000-0000-0000-0000-000000000027'),false,'Membership edits invalidate alias review');
select throws_ok($$insert into academic_mapping_batches(id,source_checksum,links)
 values ('20000000-0000-0000-0000-000000000030','synthetic','[]');
 select apply_academic_mapping('20000000-0000-0000-0000-000000000030')$$,
 '42501',null,'Unapproved mapping cannot apply');

select throws_ok($$update programs set calendar_id='20000000-0000-0000-0000-000000000004'
 where id='20000000-0000-0000-0000-000000000007'$$,'23514',null,'Parent edits cannot invalidate existing calendar relationships');

-- A reviewed synthetic mapping adds only links; real CSE mappings are unapproved.
insert into timetable_faculty(id,acronym,full_name) values ('30000000-0000-0000-0000-000000000001','AAA','Synthetic teacher');
insert into timetable_rooms(id,name) values ('30000000-0000-0000-0000-000000000002','Synthetic room');
insert into routines(id,day,time_start,time_end,subject,subject_code,teacher_code,teacher_name,room,batch,section,semester)
 values ('30000000-0000-0000-0000-000000000003','Sunday','09:00','10:00','Synthetic course','TEST','AAA','Synthetic teacher','Synthetic room','66','B+C',3);
create temporary table legacy_mapping_before as select id,to_jsonb(r)-array['scheduling_scope_id','cohort_id','student_group_id','faculty_id','room_id'] as legacy
 from routines r where id='30000000-0000-0000-0000-000000000003';
insert into group_alias_members(alias_id,cohort_id,group_id) values
 ('20000000-0000-0000-0000-000000000027','20000000-0000-0000-0000-000000000011','20000000-0000-0000-0000-000000000015');
update group_aliases set reviewed=true where id='20000000-0000-0000-0000-000000000027';
insert into academic_mapping_batches(id,source_checksum,links,approved_by,approved_at)
 select '30000000-0000-0000-0000-000000000004','synthetic-review',jsonb_build_array(jsonb_build_object(
 'routine_id',id,'legacy',legacy,'scope_id','20000000-0000-0000-0000-000000000024',
 'cohort_id','20000000-0000-0000-0000-000000000011','alias_id','20000000-0000-0000-0000-000000000027',
 'group_ids',jsonb_build_array('20000000-0000-0000-0000-000000000014','20000000-0000-0000-0000-000000000015'),
 'faculty_id','30000000-0000-0000-0000-000000000001','room_id','30000000-0000-0000-0000-000000000002')),
 '10000000-0000-0000-0000-000000000001',now() from legacy_mapping_before;
select is((apply_academic_mapping('30000000-0000-0000-0000-000000000004')->>'applied_count')::int,1,'Reviewed mapping applies exactly one row');
select is((select count(*)::int from routine_group_links where routine_id='30000000-0000-0000-0000-000000000003'),2,'Combined row links both atomic groups');
select is((select to_jsonb(r)-array['scheduling_scope_id','cohort_id','student_group_id','faculty_id','room_id'] from routines r
 where id='30000000-0000-0000-0000-000000000003'),(select legacy from legacy_mapping_before),'All original routine fields remain identical');
select is(apply_academic_mapping('30000000-0000-0000-0000-000000000004')->>'already_applied','true','Backfill retry is idempotent');
select throws_ok($$update academic_mapping_batches set links='[]' where id='30000000-0000-0000-0000-000000000004'$$,
 '23514',null,'Approved mapping history cannot be rewritten');
select throws_ok($$delete from cohorts where id='20000000-0000-0000-0000-000000000011'$$,
 '23503',null,'Referenced cohort cannot be deleted instead of archived');
update cohorts set status='archived',graduated_on='2026-12-31',archived_on='2027-01-01' where id='20000000-0000-0000-0000-000000000011';
select is((select count(*)::int from student_groups where cohort_id='20000000-0000-0000-0000-000000000011'),3,'Archive retains cohort sections');

-- All new exposed tables have both RLS and no anonymous privilege.
select ok(c.relrowsecurity and not has_table_privilege('anon',c.oid,'SELECT'), 'Closed anonymous/RLS: '||c.relname)
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relname in ('departments','programs','academic_calendars','academic_years',
 'academic_terms','cohorts','student_groups','cohort_terms','scheduling_scopes','department_memberships',
 'group_aliases','group_alias_members','routine_group_links','academic_mapping_batches','academic_mapping_quarantine');
select * from finish();
rollback;
