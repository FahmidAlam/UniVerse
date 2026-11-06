-- Task 2 additive catalog. CLI-created filename; apply only in owned local tests.
-- Requires the reconstructed Task 1 baseline. No seed/backfill, drops or legacy-label rewrites.
begin;
create schema academic_private;
revoke all on schema academic_private from public, anon;
grant usage on schema academic_private to authenticated;

create function academic_private.label_key(value text) returns text
language sql immutable strict set search_path='' as $$
 select lower(btrim(value, U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000\FEFF'));
$$;

create table public.departments (
 id uuid primary key default gen_random_uuid(), code text not null check(academic_private.label_key(code)<>''),
 name text not null check(academic_private.label_key(name)<>''), is_active boolean not null default true
);
create unique index departments_code_key on public.departments(academic_private.label_key(code));
create table public.academic_calendars (
 id uuid primary key default gen_random_uuid(), name text not null check(academic_private.label_key(name)<>''),
 timezone text not null check(timezone<>'')
);
create table public.academic_years (
 id uuid primary key default gen_random_uuid(), calendar_id uuid not null references public.academic_calendars,
 label text not null check(academic_private.label_key(label)<>'')
);
create unique index academic_years_label_key on public.academic_years(calendar_id,academic_private.label_key(label));
create table public.programs (
 id uuid primary key default gen_random_uuid(), department_id uuid not null references public.departments,
 calendar_id uuid not null references public.academic_calendars,
 code text not null check(academic_private.label_key(code)<>''), title text not null check(academic_private.label_key(title)<>''),
 is_active boolean not null default true, unique(id,department_id)
);
create unique index programs_code_key on public.programs(department_id,academic_private.label_key(code));
create index programs_calendar_idx on public.programs(calendar_id);
create table public.academic_terms (
 id uuid primary key default gen_random_uuid(), academic_year_id uuid not null references public.academic_years,
 sequence integer not null check(sequence>0), label text not null check(academic_private.label_key(label)<>''),
 start_date date not null, end_date date not null, check(start_date<=end_date), unique(academic_year_id,sequence)
);
create table public.cohorts (
 id uuid primary key default gen_random_uuid(), program_id uuid not null references public.programs,
 code text not null check(academic_private.label_key(code)<>''), admitted_on date not null,
 status text not null default 'active' check(status in ('active','graduated','archived')),
 graduated_on date, archived_on date, unique(id,program_id),
 check((status<>'active' or graduated_on is null) and (status<>'graduated' or graduated_on is not null)
   and ((status='archived')=(archived_on is not null))),
 check(graduated_on>=admitted_on), check(archived_on>=admitted_on), check(archived_on>=graduated_on)
);
create unique index cohorts_code_key on public.cohorts(program_id,academic_private.label_key(code));
create table public.student_groups (
 id uuid primary key default gen_random_uuid(), cohort_id uuid not null references public.cohorts,
 code text not null check(academic_private.label_key(code)<>''), is_active boolean not null default true,
 unique(id,cohort_id)
);
create unique index student_groups_code_key on public.student_groups(cohort_id,academic_private.label_key(code));
create table public.cohort_terms (
 id uuid primary key default gen_random_uuid(), cohort_id uuid not null references public.cohorts,
 term_id uuid not null references public.academic_terms, study_stage integer not null check(study_stage>0), unique(cohort_id,term_id)
);
create index cohort_terms_term_idx on public.cohort_terms(term_id);
create table public.scheduling_scopes (
 id uuid primary key default gen_random_uuid(), department_id uuid not null references public.departments,
 program_id uuid, term_id uuid not null references public.academic_terms,
 foreign key(program_id,department_id) references public.programs(id,department_id),
 unique nulls not distinct(department_id,program_id,term_id)
);
create index scheduling_scopes_program_idx on public.scheduling_scopes(program_id);
create index scheduling_scopes_term_idx on public.scheduling_scopes(term_id);
create table public.department_memberships (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id),
 department_id uuid not null references public.departments, program_id uuid,
 capabilities text[] not null check(cardinality(capabilities)>0 and capabilities <@ array[
 'read_catalog','manage_catalog','import','edit_draft','review','approve','publish','manage_policy']::text[]
 and array_position(capabilities,null) is null),
 valid_from timestamptz not null default now(), valid_until timestamptz,
 check(valid_until is null or valid_until>valid_from),
 foreign key(program_id,department_id) references public.programs(id,department_id),
 unique nulls not distinct(user_id,department_id,program_id)
);
create index department_memberships_department_idx on public.department_memberships(department_id,program_id);
create table public.group_aliases (
 id uuid primary key default gen_random_uuid(), cohort_id uuid not null references public.cohorts,
 label text not null check(academic_private.label_key(label)<>''), reviewed boolean not null default false,
 unique(id,cohort_id)
);
create unique index group_aliases_label_key on public.group_aliases(cohort_id,academic_private.label_key(label));
create table public.group_alias_members (
 alias_id uuid not null, cohort_id uuid not null, group_id uuid not null, primary key(alias_id,group_id),
 foreign key(alias_id,cohort_id) references public.group_aliases(id,cohort_id) on delete cascade,
 foreign key(group_id,cohort_id) references public.student_groups(id,cohort_id)
);
create index group_alias_members_group_idx on public.group_alias_members(group_id);
create index group_alias_members_cohort_idx on public.group_alias_members(cohort_id);

alter table public.timetable_faculty add column home_department_id uuid references public.departments;
create index timetable_faculty_home_department_idx on public.timetable_faculty(home_department_id);
alter table public.timetable_rooms add column campus text, add column features text[] not null default '{}';
alter table public.timetable_rooms add constraint academic_room_capacity check(capacity>0) not valid;
alter table public.profiles
 add column department_id uuid references public.departments,
 add column program_id uuid references public.programs,
 add column cohort_id uuid references public.cohorts,
 add column student_group_id uuid references public.student_groups,
 add column faculty_id uuid references public.timetable_faculty;
alter table public.routines
 add column scheduling_scope_id uuid references public.scheduling_scopes,
 add column cohort_id uuid references public.cohorts,
 add column student_group_id uuid references public.student_groups,
 add column faculty_id uuid references public.timetable_faculty,
 add column room_id uuid references public.timetable_rooms;
alter table public.routines add unique(id,cohort_id);
create table public.routine_group_links (
 routine_id uuid not null, cohort_id uuid not null, group_id uuid not null, primary key(routine_id,group_id),
 foreign key(routine_id,cohort_id) references public.routines(id,cohort_id) on delete cascade,
 foreign key(group_id,cohort_id) references public.student_groups(id,cohort_id)
);
create index routine_group_links_group_idx on public.routine_group_links(group_id);
create index routine_group_links_cohort_idx on public.routine_group_links(cohort_id);
create table public.academic_mapping_batches (
 id uuid primary key default gen_random_uuid(), source_checksum text not null check(source_checksum<>''),
 links jsonb not null check(jsonb_typeof(links)='array'),
 approved_by uuid references auth.users, approved_at timestamptz,
 applied_at timestamptz, check((approved_by is null)=(approved_at is null))
);
create table public.academic_mapping_quarantine (
 id uuid primary key default gen_random_uuid(), routine_id uuid references public.routines on delete set null,
 source_checksum text not null, reason text not null, details jsonb not null default '{}',
 unique nulls not distinct(routine_id,source_checksum,reason)
);
create index academic_mapping_batches_approver_idx on public.academic_mapping_batches(approved_by);
create index academic_mapping_quarantine_routine_idx on public.academic_mapping_quarantine(routine_id);

-- Membership authority is DB-owned; profile department text never grants access.
create function academic_private.can_access(dept uuid, program uuid, capability text)
returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and (public.is_admin() or exists(
 select 1 from public.department_memberships m where m.user_id=auth.uid() and m.department_id=dept
 and (m.program_id is null or m.program_id=program or (capability='read_catalog' and program is null))
 and now()>=m.valid_from and (m.valid_until is null or now()<m.valid_until)
 and (capability='read_catalog' or capability=any(m.capabilities))));
$$;
create function academic_private.can_directory() returns boolean
language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and (public.is_admin() or exists(select 1 from public.department_memberships m
 where m.user_id=auth.uid() and now()>=m.valid_from and (m.valid_until is null or now()<m.valid_until)));
$$;
create function academic_private.can_cohort(cohort uuid, capability text) returns boolean
language sql stable security definer set search_path='' as $$
 select coalesce((select academic_private.can_access(p.department_id,p.id,capability)
 from public.cohorts c join public.programs p on p.id=c.program_id where c.id=cohort),false);
$$;
create function academic_private.can_scope(scope uuid, capability text) returns boolean
language sql stable security definer set search_path='' as $$
 select coalesce((select academic_private.can_access(s.department_id,s.program_id,capability)
 from public.scheduling_scopes s where s.id=scope),false);
$$;
create function academic_private.calendar_visible(calendar uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and (public.is_admin() or exists(select 1 from public.programs p
 where p.calendar_id=calendar and academic_private.can_access(p.department_id,p.id,'read_catalog'))
 or exists(select 1 from public.scheduling_scopes s
 join public.academic_terms t on t.id=s.term_id
 join public.academic_years y on y.id=t.academic_year_id
 where y.calendar_id=calendar and academic_private.can_access(s.department_id,s.program_id,'read_catalog')));
$$;
create function academic_private.year_visible(year_id uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select coalesce((select academic_private.calendar_visible(y.calendar_id) from public.academic_years y where y.id=year_id),false);
$$;
create function academic_private.validate_calendar_links() returns trigger
language plpgsql security definer set search_path='' as $$
declare program_calendar uuid; term_calendar uuid;
begin
 if tg_table_name='academic_calendars' then
  if not exists(select 1 from pg_timezone_names where name=new.timezone) then
   raise exception 'Unknown calendar timezone' using errcode='23514';
  end if;
  return new;
 end if;
 if tg_table_name='cohort_terms' then
  select p.calendar_id into program_calendar from public.cohorts c join public.programs p on p.id=c.program_id where c.id=new.cohort_id;
 else
  if new.program_id is null then return new; end if;
  select calendar_id into program_calendar from public.programs where id=new.program_id;
 end if;
 select y.calendar_id into term_calendar from public.academic_terms t join public.academic_years y on y.id=t.academic_year_id where t.id=new.term_id;
 if program_calendar is distinct from term_calendar then
  raise exception 'Program/cohort term calendar mismatch' using errcode='23514';
 end if;
 return new;
end $$;
create trigger academic_calendar_zone before insert or update on public.academic_calendars
 for each row execute function academic_private.validate_calendar_links();
create trigger cohort_term_calendar before insert or update on public.cohort_terms
 for each row execute function academic_private.validate_calendar_links();
create trigger scope_term_calendar before insert or update on public.scheduling_scopes
 for each row execute function academic_private.validate_calendar_links();

-- Identity ownership cannot be reassigned by a later parent edit.
create function academic_private.keep_identity() returns trigger language plpgsql set search_path='' as $$
declare field text;
begin
 foreach field in array tg_argv loop
  if to_jsonb(new)->field is distinct from to_jsonb(old)->field then
   raise exception 'Canonical identity/ownership is immutable: %',field using errcode='23514';
  end if;
 end loop;
 return new;
end $$;
create function academic_private.review_alias() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if tg_op='UPDATE' and (new.label is distinct from old.label) then new.reviewed:=false; end if;
 if new.reviewed and (tg_op='INSERT' or not old.reviewed) then
  if auth.uid() is not null and not academic_private.can_cohort(new.cohort_id,'approve') then
   raise exception 'Alias review needs approve capability' using errcode='42501';
  end if;
  if not exists(select 1 from public.group_alias_members where alias_id=new.id) then
   raise exception 'Alias review needs explicit atomic members' using errcode='23514';
  end if;
 end if;
 return new;
end $$;
create function academic_private.invalidate_alias_review() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if tg_op<>'INSERT' then update public.group_aliases set reviewed=false where id=old.alias_id; end if;
 if tg_op<>'DELETE' then update public.group_aliases set reviewed=false where id=new.alias_id; end if;
 return null;
end $$;
create trigger group_alias_review before insert or update on public.group_aliases
 for each row execute function academic_private.review_alias();
create trigger group_alias_member_review after insert or update or delete on public.group_alias_members
 for each row execute function academic_private.invalidate_alias_review();

-- Legacy row text and auth/profile UUIDs remain unchanged. New affiliations
-- are writable only by a global administrator or the offline SQL owner.
create function academic_private.guard_legacy_refs() returns trigger
language plpgsql security definer set search_path='' as $$
declare fields text[]; field text; changed boolean:=false; c public.cohorts; p public.programs;
 s public.scheduling_scopes; g public.student_groups;
begin
 if tg_table_name='profiles' then fields:=array['department_id','program_id','cohort_id','student_group_id','faculty_id'];
 else fields:=array['scheduling_scope_id','cohort_id','student_group_id','faculty_id','room_id']; end if;
 foreach field in array fields loop
  if (tg_op='INSERT' and to_jsonb(new)->field<>'null'::jsonb) or
     (tg_op='UPDATE' and to_jsonb(new)->field is distinct from to_jsonb(old)->field) then changed:=true; end if;
 end loop;
 if changed and auth.uid() is not null and not public.is_admin() then
  raise exception 'Canonical legacy links require reviewed administrative mapping' using errcode='42501';
 end if;
 if not changed then return new; end if;
 if new.cohort_id is not null then select * into c from public.cohorts where id=new.cohort_id; end if;
 if new.student_group_id is not null then
  select * into g from public.student_groups where id=new.student_group_id;
  if new.cohort_id is null or g.cohort_id is distinct from new.cohort_id then
   raise exception 'Group/cohort mismatch' using errcode='23514';
  end if;
 end if;
 if tg_table_name='profiles' then
  if new.program_id is not null then
   select * into p from public.programs where id=new.program_id;
   if new.department_id is null or p.department_id is distinct from new.department_id then
    raise exception 'Profile program/department mismatch' using errcode='23514'; end if;
  end if;
  if new.cohort_id is not null and (new.program_id is null or c.program_id is distinct from new.program_id) then
   raise exception 'Profile cohort/program mismatch' using errcode='23514'; end if;
 else
  if new.scheduling_scope_id is not null then
   select * into s from public.scheduling_scopes where id=new.scheduling_scope_id;
   if new.cohort_id is null or (s.program_id is not null and c.program_id is distinct from s.program_id)
    or not exists(select 1 from public.programs where id=c.program_id and department_id=s.department_id) then
    raise exception 'Routine cohort/scope mismatch' using errcode='23514'; end if;
  elsif new.cohort_id is not null then raise exception 'Routine cohort needs scope' using errcode='23514'; end if;
 end if;
 return new;
end $$;
create trigger academic_profile_refs before insert or update on public.profiles
 for each row execute function academic_private.guard_legacy_refs();
create trigger academic_routine_refs before insert or update on public.routines
 for each row execute function academic_private.guard_legacy_refs();
create trigger departments_identity before update on public.departments for each row execute function academic_private.keep_identity('id');
create trigger academic_calendars_identity before update on public.academic_calendars for each row execute function academic_private.keep_identity('id');
create trigger academic_years_identity before update on public.academic_years for each row execute function academic_private.keep_identity('id','calendar_id');
create trigger programs_identity before update on public.programs for each row execute function academic_private.keep_identity('id','department_id','calendar_id');
create trigger academic_terms_identity before update on public.academic_terms for each row execute function academic_private.keep_identity('id','academic_year_id');
create trigger cohorts_identity before update on public.cohorts for each row execute function academic_private.keep_identity('id','program_id');
create trigger student_groups_identity before update on public.student_groups for each row execute function academic_private.keep_identity('id','cohort_id');
create trigger cohort_terms_identity before update on public.cohort_terms for each row execute function academic_private.keep_identity('id','cohort_id','term_id');
create trigger scheduling_scopes_identity before update on public.scheduling_scopes for each row execute function academic_private.keep_identity('id','department_id','program_id','term_id');
create trigger group_aliases_identity before update on public.group_aliases for each row execute function academic_private.keep_identity('id','cohort_id');
create index profiles_department_id_idx on public.profiles(department_id);
create index profiles_program_id_idx on public.profiles(program_id);
create index profiles_cohort_id_idx on public.profiles(cohort_id);
create index profiles_student_group_id_idx on public.profiles(student_group_id);
create index profiles_faculty_id_idx on public.profiles(faculty_id);
create index routines_scheduling_scope_id_idx on public.routines(scheduling_scope_id);
create index routines_cohort_id_idx on public.routines(cohort_id);
create index routines_student_group_id_idx on public.routines(student_group_id);
create index routines_faculty_id_idx on public.routines(faculty_id);
create index routines_room_id_idx on public.routines(room_id);

create function academic_private.guard_mapping_batch() returns trigger
language plpgsql set search_path='' as $$
begin
 if tg_op='UPDATE' and old.approved_at is not null and
  (to_jsonb(new)-'applied_at') is distinct from (to_jsonb(old)-'applied_at') then
  raise exception 'Approved mapping is immutable; create another reviewed batch' using errcode='23514';
 end if;
 if new.approved_at is not null and auth.uid() is not null and new.approved_by<>auth.uid() then
  raise exception 'Mapping approval actor must be the caller' using errcode='42501'; end if;
 return new;
end $$;
create trigger academic_mapping_review before insert or update on public.academic_mapping_batches
 for each row execute function academic_private.guard_mapping_batch();

create function public.apply_academic_mapping(p_mapping_id uuid) returns jsonb
language plpgsql set search_path='' as $$
declare batch public.academic_mapping_batches; link jsonb; legacy public.routines;
 scope public.scheduling_scopes; cohort public.cohorts; teacher public.timetable_faculty;
 room public.timetable_rooms; gids uuid[]; actual uuid[]; alias public.group_aliases;
 changed integer:=0; canonical text[]:=array['scheduling_scope_id','cohort_id','student_group_id','faculty_id','room_id'];
begin
 if auth.uid() is not null and not public.is_admin() then
  raise exception 'Only global administrators apply legacy mappings' using errcode='42501'; end if;
 select * into batch from public.academic_mapping_batches where id=p_mapping_id for update;
 if not found or batch.approved_at is null or batch.approved_by is null then
  raise exception 'An approved mapping batch is required' using errcode='42501'; end if;
 if batch.applied_at is not null then return jsonb_build_object('applied_count',jsonb_array_length(batch.links),'already_applied',true); end if;
 if jsonb_array_length(batch.links)=0 then raise exception 'Empty mapping batch' using errcode='22023'; end if;
 if (select count(distinct l->>'routine_id') from jsonb_array_elements(batch.links) l)<>jsonb_array_length(batch.links) then
  raise exception 'Duplicate routine mapping' using errcode='22023'; end if;
 for link in select value from jsonb_array_elements(batch.links) loop
  select * into legacy from public.routines where id=(link->>'routine_id')::uuid for update;
  if not found or (to_jsonb(legacy)-canonical) is distinct from link->'legacy' then
   raise exception 'Legacy row changed or missing; re-review mapping' using errcode='40001'; end if;
  if legacy.scheduling_scope_id is not null or legacy.time_start>=legacy.time_end then
   raise exception 'Already linked or invalid legacy time; quarantine instead' using errcode='23514'; end if;
  select * into scope from public.scheduling_scopes where id=(link->>'scope_id')::uuid;
  select * into cohort from public.cohorts where id=(link->>'cohort_id')::uuid;
  if cohort.code is distinct from legacy.batch or not exists(select 1 from public.cohort_terms ct
    where ct.cohort_id=cohort.id and ct.term_id=scope.term_id and ct.study_stage=legacy.semester) then
   raise exception 'Unresolved cohort/term/study stage' using errcode='23514'; end if;
  select array_agg(value::uuid order by value::uuid) into gids from jsonb_array_elements_text(link->'group_ids');
  if coalesce(cardinality(gids),0)=0 or (select count(distinct g) from unnest(gids) g)<>cardinality(gids) then
   raise exception 'Explicit atomic groups required' using errcode='23514'; end if;
  if link->>'alias_id' is not null then
   select * into alias from public.group_aliases where id=(link->>'alias_id')::uuid;
   select array_agg(group_id order by group_id) into actual from public.group_alias_members where alias_id=alias.id;
   if alias.reviewed is distinct from true or alias.cohort_id is distinct from cohort.id
      or academic_private.label_key(alias.label) is distinct from academic_private.label_key(legacy.section)
      or gids is distinct from actual then
    raise exception 'Unreviewed/ambiguous group alias' using errcode='23514'; end if;
  elsif cardinality(gids)<>1 or not exists(select 1 from public.student_groups g where g.id=gids[1]
    and g.cohort_id=cohort.id and academic_private.label_key(g.code)=academic_private.label_key(legacy.section)) then
   raise exception 'Combined/unknown section needs reviewed alias' using errcode='23514';
  end if;
  if link->>'faculty_id' is not null then
   select * into teacher from public.timetable_faculty where id=(link->>'faculty_id')::uuid;
   if teacher.id is null or teacher.acronym is distinct from legacy.teacher_code then
    raise exception 'Unresolved faculty identity' using errcode='23514'; end if;
  elsif legacy.teacher_code is not null or legacy.teacher_name is not null then
   raise exception 'Nonblank teacher cannot become pending' using errcode='23514';
  end if;
  select * into room from public.timetable_rooms where id=(link->>'room_id')::uuid;
  if room.id is null or room.name is distinct from legacy.room then
   raise exception 'Unresolved room identity' using errcode='23514'; end if;
  update public.routines set scheduling_scope_id=scope.id,cohort_id=cohort.id,
   student_group_id=case when cardinality(gids)=1 then gids[1] else null end,
   faculty_id=(link->>'faculty_id')::uuid,room_id=room.id where id=legacy.id;
  insert into public.routine_group_links(routine_id,cohort_id,group_id) select legacy.id,cohort.id,g from unnest(gids) g;
  if (select to_jsonb(r)-canonical from public.routines r where id=legacy.id) is distinct from (to_jsonb(legacy)-canonical) then
   raise exception 'Legacy fields changed' using errcode='23514'; end if;
  changed:=changed+1;
 end loop;
 update public.academic_mapping_batches set applied_at=now() where id=batch.id;
 return jsonb_build_object('applied_count',changed,'already_applied',false);
end $$;
alter table public.departments enable row level security;
revoke all on public.departments from public,anon,authenticated;
grant select,insert,update,delete on public.departments to authenticated;
create policy academic_read on public.departments for select to authenticated using (academic_private.can_directory());
create policy academic_write on public.departments for all to authenticated using (academic_private.can_access(id,null,'manage_catalog')) with check (academic_private.can_access(id,null,'manage_catalog'));
alter table public.academic_calendars enable row level security;
revoke all on public.academic_calendars from public,anon,authenticated;
grant select,insert,update,delete on public.academic_calendars to authenticated;
create policy academic_read on public.academic_calendars for select to authenticated using (academic_private.calendar_visible(id));
create policy academic_write on public.academic_calendars for all to authenticated using (public.is_admin()) with check (public.is_admin());
alter table public.academic_years enable row level security;
revoke all on public.academic_years from public,anon,authenticated;
grant select,insert,update,delete on public.academic_years to authenticated;
create policy academic_read on public.academic_years for select to authenticated using (academic_private.calendar_visible(calendar_id));
create policy academic_write on public.academic_years for all to authenticated using (public.is_admin()) with check (public.is_admin());
alter table public.programs enable row level security;
revoke all on public.programs from public,anon,authenticated;
grant select,insert,update,delete on public.programs to authenticated;
create policy academic_read on public.programs for select to authenticated using (academic_private.can_access(department_id,id,'read_catalog'));
create policy academic_write on public.programs for all to authenticated using (academic_private.can_access(department_id,id,'manage_catalog')) with check (academic_private.can_access(department_id,id,'manage_catalog'));
alter table public.academic_terms enable row level security;
revoke all on public.academic_terms from public,anon,authenticated;
grant select,insert,update,delete on public.academic_terms to authenticated;
create policy academic_read on public.academic_terms for select to authenticated using (academic_private.year_visible(academic_year_id));
create policy academic_write on public.academic_terms for all to authenticated using (public.is_admin()) with check (public.is_admin());
alter table public.cohorts enable row level security;
revoke all on public.cohorts from public,anon,authenticated;
grant select,insert,update,delete on public.cohorts to authenticated;
create policy academic_read on public.cohorts for select to authenticated using (exists(select 1 from public.programs p where p.id=program_id and academic_private.can_access(p.department_id,p.id,'read_catalog')));
create policy academic_write on public.cohorts for all to authenticated using (exists(select 1 from public.programs p where p.id=program_id and academic_private.can_access(p.department_id,p.id,'manage_catalog'))) with check (exists(select 1 from public.programs p where p.id=program_id and academic_private.can_access(p.department_id,p.id,'manage_catalog')));
alter table public.student_groups enable row level security;
revoke all on public.student_groups from public,anon,authenticated;
grant select,insert,update,delete on public.student_groups to authenticated;
create policy academic_read on public.student_groups for select to authenticated using (academic_private.can_cohort(cohort_id,'read_catalog'));
create policy academic_write on public.student_groups for all to authenticated using (academic_private.can_cohort(cohort_id,'manage_catalog')) with check (academic_private.can_cohort(cohort_id,'manage_catalog'));
alter table public.cohort_terms enable row level security;
revoke all on public.cohort_terms from public,anon,authenticated;
grant select,insert,update,delete on public.cohort_terms to authenticated;
create policy academic_read on public.cohort_terms for select to authenticated using (academic_private.can_cohort(cohort_id,'read_catalog'));
create policy academic_write on public.cohort_terms for all to authenticated using (academic_private.can_cohort(cohort_id,'manage_catalog')) with check (academic_private.can_cohort(cohort_id,'manage_catalog'));
alter table public.scheduling_scopes enable row level security;
revoke all on public.scheduling_scopes from public,anon,authenticated;
grant select,insert,update,delete on public.scheduling_scopes to authenticated;
create policy academic_read on public.scheduling_scopes for select to authenticated using (academic_private.can_access(department_id,program_id,'read_catalog'));
create policy academic_write on public.scheduling_scopes for all to authenticated using (academic_private.can_access(department_id,program_id,'manage_catalog')) with check (academic_private.can_access(department_id,program_id,'manage_catalog'));
alter table public.department_memberships enable row level security;
revoke all on public.department_memberships from public,anon,authenticated;
grant select,insert,update,delete on public.department_memberships to authenticated;
create policy academic_read on public.department_memberships for select to authenticated using (user_id=(select auth.uid()) or public.is_admin());
create policy academic_write on public.department_memberships for all to authenticated using (public.is_admin()) with check (public.is_admin());
alter table public.group_aliases enable row level security;
revoke all on public.group_aliases from public,anon,authenticated;
grant select,insert,update,delete on public.group_aliases to authenticated;
create policy academic_read on public.group_aliases for select to authenticated using (academic_private.can_cohort(cohort_id,'read_catalog'));
create policy academic_write on public.group_aliases for all to authenticated using (academic_private.can_cohort(cohort_id,'manage_catalog')) with check (academic_private.can_cohort(cohort_id,'manage_catalog'));
alter table public.group_alias_members enable row level security;
revoke all on public.group_alias_members from public,anon,authenticated;
grant select,insert,update,delete on public.group_alias_members to authenticated;
create policy academic_read on public.group_alias_members for select to authenticated using (academic_private.can_cohort(cohort_id,'read_catalog'));
create policy academic_write on public.group_alias_members for all to authenticated using (academic_private.can_cohort(cohort_id,'manage_catalog')) with check (academic_private.can_cohort(cohort_id,'manage_catalog'));
alter table public.routine_group_links enable row level security;
revoke all on public.routine_group_links from public,anon,authenticated;
grant select,insert,update,delete on public.routine_group_links to authenticated;
create policy academic_read on public.routine_group_links for select to authenticated using (exists(select 1 from public.routines r where r.id=routine_id and academic_private.can_scope(r.scheduling_scope_id,'read_catalog')));
create policy academic_write on public.routine_group_links for all to authenticated using (public.is_admin()) with check (public.is_admin());
alter table public.academic_mapping_batches enable row level security;
revoke all on public.academic_mapping_batches from public,anon,authenticated;
grant select,insert,update,delete on public.academic_mapping_batches to authenticated;
create policy academic_read on public.academic_mapping_batches for select to authenticated using (public.is_admin());
create policy academic_write on public.academic_mapping_batches for all to authenticated using (public.is_admin()) with check (public.is_admin());
alter table public.academic_mapping_quarantine enable row level security;
revoke all on public.academic_mapping_quarantine from public,anon,authenticated;
grant select,insert,update,delete on public.academic_mapping_quarantine to authenticated;
create policy academic_read on public.academic_mapping_quarantine for select to authenticated using (public.is_admin());
create policy academic_write on public.academic_mapping_quarantine for all to authenticated using (public.is_admin()) with check (public.is_admin());
revoke all on all functions in schema academic_private from public,anon,authenticated;
grant execute on function academic_private.label_key(text) to authenticated;
grant execute on function academic_private.can_access(uuid,uuid,text) to authenticated;
grant execute on function academic_private.can_directory() to authenticated;
grant execute on function academic_private.can_cohort(uuid,text) to authenticated;
grant execute on function academic_private.can_scope(uuid,text) to authenticated;
grant execute on function academic_private.calendar_visible(uuid) to authenticated;
grant execute on function academic_private.year_visible(uuid) to authenticated;
revoke all on function public.apply_academic_mapping(uuid) from public,anon,authenticated;
grant execute on function public.apply_academic_mapping(uuid) to authenticated;
create function public.academic_catalog() returns jsonb language sql stable set search_path='' as $$
select jsonb_build_object('schema_version',1,
 'departments',coalesce((select jsonb_agg(to_jsonb(r) order by r.id) from public.departments r),'[]'::jsonb),
 'calendars',coalesce((select jsonb_agg(to_jsonb(r) order by r.id) from public.academic_calendars r),'[]'::jsonb),
 'academic_years',coalesce((select jsonb_agg(to_jsonb(r) order by r.id) from public.academic_years r),'[]'::jsonb),
 'programs',coalesce((select jsonb_agg(to_jsonb(r) order by r.id) from public.programs r),'[]'::jsonb),
 'terms',coalesce((select jsonb_agg(to_jsonb(r) order by r.id) from public.academic_terms r),'[]'::jsonb),
 'cohorts',coalesce((select jsonb_agg(to_jsonb(r) order by r.id) from public.cohorts r),'[]'::jsonb),
 'student_groups',coalesce((select jsonb_agg(to_jsonb(r) order by r.id) from public.student_groups r),'[]'::jsonb),
 'cohort_terms',coalesce((select jsonb_agg(to_jsonb(r) order by r.id) from public.cohort_terms r),'[]'::jsonb),
 'scopes',coalesce((select jsonb_agg(to_jsonb(r) order by r.id) from public.scheduling_scopes r),'[]'::jsonb),
 'faculty',coalesce((select jsonb_agg(to_jsonb(f) order by f.id) from (
 select id,home_department_id,coalesce(nullif(full_name,''),acronym) as display_name,is_active
 from public.timetable_faculty where academic_private.can_directory()) f),'[]'::jsonb),
 'rooms',coalesce((select jsonb_agg(to_jsonb(r) order by r.id) from (
 select id,name,campus,capacity,features,is_active from public.timetable_rooms
 where academic_private.can_directory()) r),'[]'::jsonb),
 'group_aliases',coalesce((select jsonb_agg(to_jsonb(a) order by a.id) from (
 select a.id,a.cohort_id,a.label,a.reviewed,
 coalesce((select jsonb_agg(m.group_id order by m.group_id) from public.group_alias_members m where m.alias_id=a.id),'[]'::jsonb) as group_ids
 from public.group_aliases a) a),'[]'::jsonb));
$$;
revoke all on function public.academic_catalog() from public,anon,authenticated;
grant execute on function public.academic_catalog() to authenticated;

create function public.review_academic_alias(p_alias_id uuid) returns void
language plpgsql security definer set search_path='' as $$
declare cohort uuid;
begin
 select cohort_id into cohort from public.group_aliases where id=p_alias_id for update;
 if cohort is null or not academic_private.can_cohort(cohort,'approve') then
  raise exception 'Alias review needs scoped approval capability' using errcode='42501'; end if;
 update public.group_aliases set reviewed=true where id=p_alias_id;
end $$;
revoke all on function public.review_academic_alias(uuid) from public,anon,authenticated;
grant execute on function public.review_academic_alias(uuid) to authenticated;

create function public.replace_academic_alias_members(p_alias_id uuid,p_group_ids uuid[]) returns void
language plpgsql security definer set search_path='' as $$
declare cohort uuid;
begin
 select cohort_id into cohort from public.group_aliases where id=p_alias_id for update;
 if cohort is null or not academic_private.can_cohort(cohort,'manage_catalog') then
  raise exception 'Alias edits need scoped catalog capability' using errcode='42501'; end if;
 if p_group_ids is null or cardinality(p_group_ids)=0 or array_position(p_group_ids,null) is not null or
  (select count(distinct g) from unnest(p_group_ids) g)<>cardinality(p_group_ids) then
  raise exception 'Explicit distinct atomic groups required' using errcode='23514'; end if;
 delete from public.group_alias_members where alias_id=p_alias_id;
 insert into public.group_alias_members(alias_id,cohort_id,group_id) select p_alias_id,cohort,g from unnest(p_group_ids) g;
end $$;
revoke all on function public.replace_academic_alias_members(uuid,uuid[]) from public,anon,authenticated;
grant execute on function public.replace_academic_alias_members(uuid,uuid[]) to authenticated;

create function public.save_academic_alias(p_id uuid,p_cohort_id uuid,p_label text,p_group_ids uuid[]) returns void
language plpgsql security definer set search_path='' as $$
begin
 if not academic_private.can_cohort(p_cohort_id,'manage_catalog') then
  raise exception 'Alias edits need scoped catalog capability' using errcode='42501'; end if;
 insert into public.group_aliases(id,cohort_id,label) values(p_id,p_cohort_id,p_label)
 on conflict(id) do update set label=excluded.label,reviewed=false;
 if not exists(select 1 from public.group_aliases where id=p_id and cohort_id=p_cohort_id) then
  raise exception 'Alias identity cannot move cohorts' using errcode='23514'; end if;
 perform public.replace_academic_alias_members(p_id,p_group_ids);
end $$;
revoke all on function public.save_academic_alias(uuid,uuid,text,uuid[]) from public,anon,authenticated;
grant execute on function public.save_academic_alias(uuid,uuid,text,uuid[]) to authenticated;

create function academic_private.require_alias_members() returns trigger
language plpgsql security definer set search_path='' as $$
declare alias_id_to_check uuid;
begin
 if tg_table_name='group_aliases' then alias_id_to_check:=new.id;
 elsif tg_op='DELETE' then alias_id_to_check:=old.alias_id;
 else alias_id_to_check:=new.alias_id; end if;
 if exists(select 1 from public.group_aliases where id=alias_id_to_check) and
 not exists(select 1 from public.group_alias_members where alias_id=alias_id_to_check) then
  raise exception 'Group alias needs explicit atomic members' using errcode='23514'; end if;
 return null;
end $$;
revoke all on function academic_private.require_alias_members() from public,anon,authenticated;
create constraint trigger alias_members_required after insert or update on public.group_aliases
 deferrable initially deferred for each row execute function academic_private.require_alias_members();
create constraint trigger alias_member_list_required after delete or update on public.group_alias_members
 deferrable initially deferred for each row execute function academic_private.require_alias_members();
commit;
