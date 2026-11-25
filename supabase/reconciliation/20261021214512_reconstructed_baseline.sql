-- LOCAL REHEARSAL ONLY: CLI-named reconstructed restricted baseline.
-- Source migration history is unavailable; never push this to a hosted project.
-- RECONSTRUCTED TEST BASELINE: table/constraint/index stage only.
-- Source: user-supplied deployed metadata, 22 October 2026.
-- NOT an applied migration, full schema dump, or production rollout script.
-- Target ONLY: empty universe-timetable-test project in the Supabase SQL Editor.
-- This stage deliberately denies client access pending separate policy/grant reconciliation.
-- No schedules, users, credentials, webhook triggers or Edge Functions are imported.

do $$
begin
  if exists (select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
             where n.nspname = 'public' and c.relkind in ('r', 'p')) then
    raise exception 'Refusing baseline: public already contains tables. Use an empty disposable test project.';
  end if;
end $$;

-- Match the supplied vector type/index dependency; fail if unavailable.
create extension if not exists vector with schema public version '0.8.2';

create table public."assignments" (
  "id" uuid default gen_random_uuid() not null,
  "title" text not null,
  "description" text,
  "subject_code" text not null,
  "teacher_id" uuid,
  "batch" text not null,
  "section" text not null,
  "deadline" timestamp with time zone not null,
  "created_at" timestamp with time zone default now()
);
alter table public."assignments" enable row level security;
revoke all on table public."assignments" from public, anon, authenticated;

create table public."cancellations" (
  "id" uuid default gen_random_uuid() not null,
  "routine_id" uuid,
  "cancelled_by" uuid,
  "reason" text,
  "created_at" timestamp with time zone default now(),
  "class_date" date,
  "batch" text,
  "section" text,
  "subject" text,
  "day" text,
  "time_start" text
);
alter table public."cancellations" enable row level security;
revoke all on table public."cancellations" from public, anon, authenticated;

create table public."device_tokens" (
  "token" text not null,
  "user_id" uuid not null,
  "platform" text default 'android'::text not null,
  "updated_at" timestamp with time zone default now() not null
);
alter table public."device_tokens" enable row level security;
revoke all on table public."device_tokens" from public, anon, authenticated;

create table public."documents" (
  "id" uuid default gen_random_uuid() not null,
  "content" text not null,
  "embedding" vector(768),
  "category" text not null
);
alter table public."documents" enable row level security;
revoke all on table public."documents" from public, anon, authenticated;

create table public."notification_reads" (
  "user_id" uuid not null,
  "notification_id" uuid not null,
  "read_at" timestamp with time zone default now() not null
);
alter table public."notification_reads" enable row level security;
revoke all on table public."notification_reads" from public, anon, authenticated;

create table public."notifications" (
  "id" uuid default gen_random_uuid() not null,
  "title" text not null,
  "body" text not null,
  "type" text not null,
  "sent_by" uuid,
  "target_role" text,
  "target_batch" text,
  "target_section" text,
  "created_at" timestamp with time zone default now()
);
alter table public."notifications" enable row level security;
revoke all on table public."notifications" from public, anon, authenticated;

create table public."profiles" (
  "id" uuid not null,
  "email" text not null,
  "role" text not null,
  "name" text,
  "avatar_url" text,
  "batch" text,
  "section" text,
  "semester" integer,
  "student_id" text,
  "teacher_code" text,
  "designation" text,
  "department" text,
  "courses" text[],
  "created_at" timestamp with time zone default now()
);
alter table public."profiles" enable row level security;
revoke all on table public."profiles" from public, anon, authenticated;

create table public."resources" (
  "id" uuid default gen_random_uuid() not null,
  "title" text not null,
  "category" text not null,
  "semester" integer not null,
  "subject_code" text,
  "drive_link" text,
  "file_url" text,
  "uploaded_by" uuid,
  "created_at" timestamp with time zone default now()
);
alter table public."resources" enable row level security;
revoke all on table public."resources" from public, anon, authenticated;

create table public."routine_versions" (
  "id" uuid default gen_random_uuid() not null,
  "semester_label" text,
  "source" text default 'engine'::text not null,
  "is_active" boolean default false not null,
  "row_count" integer default 0 not null,
  "stats" jsonb default '{}'::jsonb not null,
  "validation" jsonb default '{}'::jsonb not null,
  "notes" text,
  "published_at" timestamp with time zone,
  "published_by" uuid,
  "created_at" timestamp with time zone default now() not null
);
alter table public."routine_versions" enable row level security;
revoke all on table public."routine_versions" from public, anon, authenticated;

create table public."routines" (
  "id" uuid default gen_random_uuid() not null,
  "day" text not null,
  "time_start" time without time zone not null,
  "time_end" time without time zone not null,
  "subject" text not null,
  "subject_code" text not null,
  "teacher_id" uuid,
  "room" text not null,
  "batch" text not null,
  "section" text not null,
  "semester" integer not null,
  "is_active" boolean default true,
  "teacher_name" text,
  "teacher_code" text,
  "routine_version_id" uuid,
  "is_service" boolean default false not null
);
alter table public."routines" enable row level security;
revoke all on table public."routines" from public, anon, authenticated;

create table public."submissions" (
  "id" uuid default gen_random_uuid() not null,
  "assignment_id" uuid,
  "student_id" uuid,
  "file_url" text not null,
  "submitted_at" timestamp with time zone default now(),
  "is_late" boolean
);
alter table public."submissions" enable row level security;
revoke all on table public."submissions" from public, anon, authenticated;

create table public."timetable_course_eligibility" (
  "id" uuid default gen_random_uuid() not null,
  "acronym" text not null,
  "course_code" text not null,
  "is_eligible" boolean default true not null,
  "priority" integer,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null
);
alter table public."timetable_course_eligibility" enable row level security;
revoke all on table public."timetable_course_eligibility" from public, anon, authenticated;

create table public."timetable_courses" (
  "id" uuid default gen_random_uuid() not null,
  "code" text not null,
  "title" text,
  "batch" text,
  "section" text,
  "dept" text,
  "is_lab" boolean default false not null,
  "file_teacher" text,
  "assigned_teacher" text,
  "updated_at" timestamp with time zone default now() not null
);
alter table public."timetable_courses" enable row level security;
revoke all on table public."timetable_courses" from public, anon, authenticated;

create table public."timetable_faculty" (
  "id" uuid default gen_random_uuid() not null,
  "acronym" text not null,
  "full_name" text,
  "dept" text,
  "designation" text,
  "off_days" text[] default '{}'::text[] not null,
  "is_active" boolean default true not null,
  "courses" text[] default '{}'::text[] not null
);
alter table public."timetable_faculty" enable row level security;
revoke all on table public."timetable_faculty" from public, anon, authenticated;

create table public."timetable_rooms" (
  "id" uuid default gen_random_uuid() not null,
  "name" text not null,
  "building" text,
  "is_lab" boolean default false not null,
  "is_gallery" boolean default false not null,
  "capacity" integer,
  "is_active" boolean default true not null,
  "dept" text
);
alter table public."timetable_rooms" enable row level security;
revoke all on table public."timetable_rooms" from public, anon, authenticated;

create table public."timetable_runs" (
  "id" uuid default gen_random_uuid() not null,
  "semester_label" text,
  "file_path" text,
  "stats" jsonb,
  "validation" jsonb,
  "status" text default 'generated'::text not null,
  "row_count" integer,
  "created_by" uuid,
  "created_at" timestamp with time zone default now()
);
alter table public."timetable_runs" enable row level security;
revoke all on table public."timetable_runs" from public, anon, authenticated;

create table public."timetable_settings" (
  "id" integer default 1 not null,
  "semester_label" text,
  "periods" jsonb not null,
  "friday_no_p4" boolean default true not null,
  "service_scope" text default 'resource_only'::text not null,
  "weights" jsonb default '{"spread": 2, "late_slot": 1, "compactness": 3, "different_days": 8}'::jsonb not null,
  "working_days" text[],
  "weeks_in_term" integer default 14 not null,
  "blocked_periods" jsonb default '{}'::jsonb not null,
  "online_periods" jsonb default '[7]'::jsonb not null,
  "allow_online_periods" boolean default false not null,
  "excluded_periods" jsonb default '[]'::jsonb not null,
  "semester_map" jsonb default '{}'::jsonb not null,
  "fixed_sessions_per_week" integer default 2
);
alter table public."timetable_settings" enable row level security;
revoke all on table public."timetable_settings" from public, anon, authenticated;

create table public."whitelists" (
  "email" text not null,
  "role" text not null,
  "name" text,
  "teacher_code" text,
  "batch" text,
  "section" text,
  "semester" integer,
  "department" text,
  "designation" text
);
alter table public."whitelists" enable row level security;
revoke all on table public."whitelists" from public, anon, authenticated;

alter table public."assignments" add constraint "assignments_pkey" PRIMARY KEY (id);
alter table public."cancellations" add constraint "cancellations_pkey" PRIMARY KEY (id);
alter table public."device_tokens" add constraint "device_tokens_pkey" PRIMARY KEY (token);
alter table public."documents" add constraint "documents_pkey" PRIMARY KEY (id);
alter table public."notification_reads" add constraint "notification_reads_pkey" PRIMARY KEY (user_id, notification_id);
alter table public."notifications" add constraint "check_notif_type" CHECK (type = ANY (ARRAY['university'::text, 'class_cancel'::text, 'room_change'::text, 'test_reminder'::text, 'assignment'::text, 'exam'::text]));
alter table public."notifications" add constraint "notifications_pkey" PRIMARY KEY (id);
alter table public."profiles" add constraint "check_profile_role" CHECK (role = ANY (ARRAY['student'::text, 'teacher'::text, 'admin'::text]));
alter table public."profiles" add constraint "profiles_pkey" PRIMARY KEY (id);
alter table public."resources" add constraint "resources_pkey" PRIMARY KEY (id);
alter table public."routine_versions" add constraint "routine_versions_pkey" PRIMARY KEY (id);
alter table public."routine_versions" add constraint "routine_versions_source_check" CHECK (source = ANY (ARRAY['engine'::text, 'upload'::text, 'manual'::text]));
alter table public."routines" add constraint "routines_pkey" PRIMARY KEY (id);
alter table public."submissions" add constraint "submissions_pkey" PRIMARY KEY (id);
alter table public."timetable_course_eligibility" add constraint "timetable_course_eligibility_pkey" PRIMARY KEY (id);
alter table public."timetable_course_eligibility" add constraint "timetable_course_eligibility_priority_positive" CHECK (priority IS NULL OR priority > 0);
alter table public."timetable_course_eligibility" add constraint "timetable_course_eligibility_unique" UNIQUE (acronym, course_code);
alter table public."timetable_courses" add constraint "timetable_courses_code_batch_section_key" UNIQUE (code, batch, section);
alter table public."timetable_courses" add constraint "timetable_courses_pkey" PRIMARY KEY (id);
alter table public."timetable_faculty" add constraint "timetable_faculty_acronym_key" UNIQUE (acronym);
alter table public."timetable_faculty" add constraint "timetable_faculty_pkey" PRIMARY KEY (id);
alter table public."timetable_rooms" add constraint "timetable_rooms_name_key" UNIQUE (name);
alter table public."timetable_rooms" add constraint "timetable_rooms_pkey" PRIMARY KEY (id);
alter table public."timetable_runs" add constraint "timetable_runs_pkey" PRIMARY KEY (id);
alter table public."timetable_settings" add constraint "timetable_settings_fixed_sessions_ck" CHECK (fixed_sessions_per_week IS NULL OR fixed_sessions_per_week >= 0 AND fixed_sessions_per_week <= 7);
alter table public."timetable_settings" add constraint "timetable_settings_id_check" CHECK (id = 1);
alter table public."timetable_settings" add constraint "timetable_settings_pkey" PRIMARY KEY (id);
alter table public."timetable_settings" add constraint "timetable_settings_weeks_in_term_ck" CHECK (weeks_in_term >= 1 AND weeks_in_term <= 52);
alter table public."whitelists" add constraint "check_role" CHECK (role = ANY (ARRAY['student'::text, 'teacher'::text, 'admin'::text]));
alter table public."whitelists" add constraint "whitelists_pkey" PRIMARY KEY (email);
alter table public."assignments" add constraint "assignments_teacher_id_fkey" FOREIGN KEY (teacher_id) REFERENCES profiles(id) ON DELETE CASCADE;
alter table public."cancellations" add constraint "cancellations_cancelled_by_fkey" FOREIGN KEY (cancelled_by) REFERENCES profiles(id) ON DELETE SET NULL;
alter table public."cancellations" add constraint "cancellations_routine_id_fkey" FOREIGN KEY (routine_id) REFERENCES routines(id) ON DELETE SET NULL;
alter table public."device_tokens" add constraint "device_tokens_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public."notification_reads" add constraint "notification_reads_notification_id_fkey" FOREIGN KEY (notification_id) REFERENCES notifications(id) ON DELETE CASCADE;
alter table public."notification_reads" add constraint "notification_reads_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public."notifications" add constraint "notifications_sent_by_fkey" FOREIGN KEY (sent_by) REFERENCES profiles(id) ON DELETE SET NULL;
alter table public."profiles" add constraint "profiles_id_fkey" FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public."resources" add constraint "resources_uploaded_by_fkey" FOREIGN KEY (uploaded_by) REFERENCES profiles(id) ON DELETE SET NULL;
alter table public."routine_versions" add constraint "routine_versions_published_by_fkey" FOREIGN KEY (published_by) REFERENCES auth.users(id);
alter table public."routines" add constraint "routines_routine_version_id_fkey" FOREIGN KEY (routine_version_id) REFERENCES routine_versions(id) ON DELETE CASCADE;
alter table public."routines" add constraint "routines_teacher_id_fkey" FOREIGN KEY (teacher_id) REFERENCES profiles(id) ON DELETE SET NULL;
alter table public."submissions" add constraint "submissions_assignment_id_fkey" FOREIGN KEY (assignment_id) REFERENCES assignments(id) ON DELETE CASCADE;
alter table public."submissions" add constraint "submissions_student_id_fkey" FOREIGN KEY (student_id) REFERENCES profiles(id) ON DELETE CASCADE;
alter table public."timetable_runs" add constraint "timetable_runs_created_by_fkey" FOREIGN KEY (created_by) REFERENCES profiles(id);

-- Constraint-owned indexes are created by their constraints.
CREATE INDEX cancellations_date_idx ON public.cancellations USING btree (class_date);
CREATE UNIQUE INDEX cancellations_routine_date_uniq ON public.cancellations USING btree (routine_id, class_date);
CREATE INDEX idx_device_tokens_user ON public.device_tokens USING btree (user_id);
CREATE INDEX documents_embedding_idx ON public.documents USING hnsw (embedding vector_cosine_ops);
CREATE INDEX idx_notification_reads_user ON public.notification_reads USING btree (user_id);
CREATE UNIQUE INDEX routine_versions_one_active ON public.routine_versions USING btree (is_active) WHERE is_active;
CREATE INDEX routines_lookup_idx ON public.routines USING btree (batch, section, day);
CREATE INDEX routines_teacher_idx ON public.routines USING btree (teacher_code, day);
CREATE INDEX routines_version_idx ON public.routines USING btree (routine_version_id);
CREATE INDEX timetable_course_eligibility_acronym_idx ON public.timetable_course_eligibility USING btree (acronym);

-- Stop here: functions, policies, grants, Storage, Realtime and fixtures are separate.

do $$ begin
if exists(select 1 from pg_extension where extname='vector' and extversion <> '0.8.2') then
 raise exception 'Local vector version differs; do not silently accept drift';
end if; end $$;
-- RECONSTRUCTED TEST BASELINE stage 002: functions, public RLS policies, local triggers.
-- Only for universe-timetable-test after stage 001. NOT a production migration.
-- Source: user-supplied deployed function and policy metadata, 22 October 2026.
-- Policies preserve observed legacy behavior; this does not certify their security.
-- Client table grants remain revoked. No webhook, Storage, Realtime, FCM or data writes.

set local search_path = public, extensions, pg_catalog;

do $$
begin
  if (select count(*) from pg_tables where schemaname = 'public') <> 18
     or to_regclass('public.routines') is null
     or to_regclass('public.timetable_courses') is null then
    raise exception 'Stage 001 must have created exactly 18 tables in the disposable test project.';
  end if;
  if exists (select 1 from pg_policies where schemaname = 'public') then
    raise exception 'Refusing stage 002: public policies already exist. Do not rerun or use production.';
  end if;
  if exists (select 1 from pg_tables t
      cross join (values ('anon'), ('authenticated')) as roles(name)
      cross join (values ('SELECT'), ('INSERT'), ('UPDATE'), ('DELETE'),
                         ('TRUNCATE'), ('REFERENCES'), ('TRIGGER')) as privileges(name)
      where t.schemaname = 'public'
        and has_table_privilege(roles.name,
          format('%I.%I', t.schemaname, t.tablename), privileges.name)) then
    raise exception 'Refusing stage 002: stage 001 client table restrictions are absent.';
  end if;
end $$;

CREATE OR REPLACE FUNCTION public.my_role()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select role from profiles where id = auth.uid();
$function$;
alter function public."my_role"() owner to "postgres";
revoke all on function public."my_role"() from public, anon, authenticated;
grant execute on function public."my_role"() to authenticated;

CREATE OR REPLACE FUNCTION public.is_admin()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(public.my_role() = 'admin', false);
$function$;
alter function public."is_admin"() owner to "postgres";
revoke all on function public."is_admin"() from public, anon, authenticated;
grant execute on function public."is_admin"() to authenticated;

CREATE OR REPLACE FUNCTION public.register_device_token(p_token text, p_platform text DEFAULT 'android'::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  -- Clear a stale row left by a previous user of this device.
  delete from public.device_tokens
   where token = p_token
     and user_id <> auth.uid();

  insert into public.device_tokens (token, user_id, platform, updated_at)
  values (p_token, auth.uid(), p_platform, now())
  on conflict (token) do update
     set user_id    = excluded.user_id,
         platform   = excluded.platform,
         updated_at = now();
end;
$function$;
alter function public."register_device_token"(text,text) owner to "postgres";
revoke all on function public."register_device_token"(text,text) from public, anon, authenticated;
grant execute on function public."register_device_token"(text,text) to authenticated;

CREATE OR REPLACE FUNCTION public.guard_profile_role()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  -- No end-user JWT (SQL editor, service role) or an admin: any role.
  if auth.uid() is null or public.is_admin() then
    return new;
  end if;

  -- The role is not changing: ordinary profile edits.
  if tg_op = 'UPDATE' and new.role is not distinct from old.role then
    return new;
  end if;

  -- Same, for an upsert of an existing row. Postgres fires BEFORE INSERT
  -- before it detects the conflict, so the existing row is looked up here.
  if tg_op = 'INSERT' and exists (
    select 1 from profiles p where p.id = new.id and p.role = new.role
  ) then
    return new;
  end if;

  if new.role = 'student' then
    return new;
  end if;

  if exists (
    select 1 from whitelists w
    where lower(w.email) = lower(auth.jwt() ->> 'email')
      and w.role = new.role
  ) then
    return new;
  end if;

  raise exception 'The % role needs to be added by the department admin.', new.role
    using errcode = '42501', hint = 'not_whitelisted';
end;
$function$;
alter function public."guard_profile_role"() owner to "postgres";
revoke all on function public."guard_profile_role"() from public, anon, authenticated;
grant execute on function public."guard_profile_role"() to anon;
grant execute on function public."guard_profile_role"() to authenticated;

CREATE OR REPLACE FUNCTION public.calculate_is_late()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
    assignment_deadline TIMESTAMPTZ;
BEGIN
    -- Fetch the deadline for the specific assignment
    SELECT deadline INTO assignment_deadline
    FROM assignments
    WHERE id = NEW.assignment_id;

    -- Compare submission time to deadline
    IF NEW.submitted_at > assignment_deadline THEN
        NEW.is_late := TRUE;
    ELSE
        NEW.is_late := FALSE;
    END IF;

    RETURN NEW;
END;
$function$;
alter function public."calculate_is_late"() owner to "postgres";
revoke all on function public."calculate_is_late"() from public, anon, authenticated;
grant execute on function public."calculate_is_late"() to anon;
grant execute on function public."calculate_is_late"() to authenticated;

CREATE OR REPLACE FUNCTION public.match_documents(query_embedding vector, match_count integer DEFAULT 3)
 RETURNS TABLE(content text, category text, similarity double precision)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT d.content, d.category, 1 - (d.embedding <=> query_embedding) AS similarity
    FROM documents d
    ORDER BY d.embedding <=> query_embedding
    LIMIT match_count;
END;
$function$;
alter function public."match_documents"(public.vector,integer) owner to "postgres";
revoke all on function public."match_documents"(public.vector,integer) from public, anon, authenticated;
grant execute on function public."match_documents"(public.vector,integer) to anon;
grant execute on function public."match_documents"(public.vector,integer) to authenticated;

CREATE OR REPLACE FUNCTION public.publish_routine(p_rows jsonb, p_semester_label text DEFAULT NULL::text, p_source text DEFAULT 'engine'::text, p_stats jsonb DEFAULT '{}'::jsonb, p_validation jsonb DEFAULT '{}'::jsonb, p_notes text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  v_id    uuid;
  v_count int;
begin
  if not public.is_admin() then
    raise exception 'Only an admin may publish a routine.'
      using errcode = '42501';
  end if;

  if p_rows is null or jsonb_typeof(p_rows) <> 'array'
     or jsonb_array_length(p_rows) = 0 then
    -- Refuse rather than wipe: an empty payload used to be a silent no-op
    -- that could still have cleared rows under the old delete-loop.
    raise exception 'Refusing to publish an empty routine.'
      using errcode = '22023';
  end if;

  insert into public.routine_versions
    (semester_label, source, published_by, stats, validation, notes)
  values (p_semester_label, p_source, auth.uid(), coalesce(p_stats, '{}'::jsonb),
          coalesce(p_validation, '{}'::jsonb), p_notes)
  returning id into v_id;

  -- Replace, never merge. Every previous class goes, including batches that
  -- do not appear in the incoming routine. `where true` is deliberate — see
  -- the header comment; do not "simplify" this back to a bare DELETE.
  update public.routine_versions set is_active = false where is_active;
  delete from public.routines where true;

  insert into public.routines
    (day, time_start, time_end, subject, subject_code, teacher_name,
     teacher_code, room, batch, section, semester, is_active, is_service,
     routine_version_id)
  select r.day, r.time_start::time, r.time_end::time, r.subject, r.subject_code,
         r.teacher_name, r.teacher_code, r.room, r.batch, r.section,
         coalesce(r.semester, 0), true, coalesce(r.is_service, false), v_id
    from jsonb_to_recordset(p_rows) as r(
      day text, time_start text, time_end text, subject text,
      subject_code text, teacher_name text, teacher_code text, room text,
      batch text, section text, semester int, is_service boolean);
  get diagnostics v_count = row_count;

  update public.routine_versions
     set is_active = true, row_count = v_count, published_at = now()
   where id = v_id;

  return jsonb_build_object('version_id', v_id, 'row_count', v_count);
end $function$;
alter function public."publish_routine"(jsonb,text,text,jsonb,jsonb,text) owner to "postgres";
revoke all on function public."publish_routine"(jsonb,text,text,jsonb,jsonb,text) from public, anon, authenticated;
grant execute on function public."publish_routine"(jsonb,text,text,jsonb,jsonb,text) to authenticated;

create policy "assignments_delete" on public."assignments" as permissive for DELETE to authenticated
  using (((teacher_id = auth.uid()) OR is_admin()));

create policy "assignments_insert_teacher" on public."assignments" as permissive for INSERT to authenticated
  with check (((teacher_id = auth.uid()) AND (my_role() = ANY (ARRAY['teacher'::text, 'admin'::text]))));

create policy "assignments_modify" on public."assignments" as permissive for UPDATE to authenticated
  using (((teacher_id = auth.uid()) OR is_admin()))
  with check (((teacher_id = auth.uid()) OR is_admin()));

create policy "assignments_select" on public."assignments" as permissive for SELECT to authenticated
  using (true);

create policy "cancellations_delete" on public."cancellations" as permissive for DELETE to authenticated
  using (((cancelled_by = auth.uid()) OR is_admin()));

create policy "cancellations_insert_staff" on public."cancellations" as permissive for INSERT to authenticated
  with check (((cancelled_by = auth.uid()) AND (my_role() = ANY (ARRAY['teacher'::text, 'admin'::text]))));

create policy "cancellations_select" on public."cancellations" as permissive for SELECT to authenticated
  using (true);

create policy "own_tokens_delete" on public."device_tokens" as permissive for DELETE to public
  using ((user_id = auth.uid()));

create policy "own_tokens_insert" on public."device_tokens" as permissive for INSERT to public
  with check ((user_id = auth.uid()));

create policy "own_tokens_select" on public."device_tokens" as permissive for SELECT to public
  using ((user_id = auth.uid()));

create policy "own_tokens_update" on public."device_tokens" as permissive for UPDATE to public
  using ((user_id = auth.uid()));

create policy "documents_select" on public."documents" as permissive for SELECT to authenticated
  using (true);

create policy "documents_write_admin" on public."documents" as permissive for ALL to authenticated
  using (is_admin())
  with check (is_admin());

create policy "own_reads_delete" on public."notification_reads" as permissive for DELETE to public
  using ((user_id = auth.uid()));

create policy "own_reads_insert" on public."notification_reads" as permissive for INSERT to public
  with check ((user_id = auth.uid()));

create policy "own_reads_select" on public."notification_reads" as permissive for SELECT to public
  using ((user_id = auth.uid()));

create policy "own_reads_update" on public."notification_reads" as permissive for UPDATE to public
  using ((user_id = auth.uid()));

create policy "notifications_delete" on public."notifications" as permissive for DELETE to authenticated
  using (((sent_by = auth.uid()) OR is_admin()));

create policy "notifications_insert_staff" on public."notifications" as permissive for INSERT to authenticated
  with check (((sent_by = auth.uid()) AND (my_role() = ANY (ARRAY['teacher'::text, 'admin'::text]))));

create policy "notifications_select" on public."notifications" as permissive for SELECT to authenticated
  using (true);

create policy "profiles_delete_admin" on public."profiles" as permissive for DELETE to authenticated
  using (is_admin());

create policy "profiles_insert_own" on public."profiles" as permissive for INSERT to authenticated
  with check (((id = auth.uid()) AND ((role = ANY (ARRAY['student'::text, 'teacher'::text])) OR (EXISTS ( SELECT 1
   FROM whitelists w
  WHERE ((lower(w.email) = lower((auth.jwt() ->> 'email'::text))) AND (w.role = profiles.role)))))));

create policy "profiles_select" on public."profiles" as permissive for SELECT to authenticated
  using (true);

create policy "profiles_update_own" on public."profiles" as permissive for UPDATE to authenticated
  using (((id = auth.uid()) OR is_admin()))
  with check ((is_admin() OR ((id = auth.uid()) AND ((role = ANY (ARRAY['student'::text, 'teacher'::text])) OR (EXISTS ( SELECT 1
   FROM whitelists w
  WHERE ((lower(w.email) = lower((auth.jwt() ->> 'email'::text))) AND (w.role = profiles.role))))))));

create policy "resources_delete" on public."resources" as permissive for DELETE to authenticated
  using (((uploaded_by = auth.uid()) OR is_admin()));

create policy "resources_insert_staff" on public."resources" as permissive for INSERT to authenticated
  with check (((uploaded_by = auth.uid()) AND (my_role() = ANY (ARRAY['teacher'::text, 'admin'::text]))));

create policy "resources_modify" on public."resources" as permissive for UPDATE to authenticated
  using (((uploaded_by = auth.uid()) OR is_admin()))
  with check (((uploaded_by = auth.uid()) OR is_admin()));

create policy "resources_select" on public."resources" as permissive for SELECT to authenticated
  using (true);

create policy "routine_versions_select" on public."routine_versions" as permissive for SELECT to authenticated
  using (true);

create policy "routine_versions_write_admin" on public."routine_versions" as permissive for ALL to authenticated
  using (is_admin())
  with check (is_admin());

create policy "routines_select" on public."routines" as permissive for SELECT to authenticated
  using (true);

create policy "routines_write_admin" on public."routines" as permissive for ALL to authenticated
  using (is_admin())
  with check (is_admin());

create policy "submissions_delete" on public."submissions" as permissive for DELETE to authenticated
  using (((student_id = auth.uid()) OR is_admin()));

create policy "submissions_insert_own" on public."submissions" as permissive for INSERT to authenticated
  with check ((student_id = auth.uid()));

create policy "submissions_select" on public."submissions" as permissive for SELECT to authenticated
  using (((student_id = auth.uid()) OR (my_role() = ANY (ARRAY['teacher'::text, 'admin'::text]))));

create policy "submissions_update_own" on public."submissions" as permissive for UPDATE to authenticated
  using ((student_id = auth.uid()))
  with check ((student_id = auth.uid()));

create policy "admin_write" on public."timetable_course_eligibility" as permissive for ALL to public
  using (is_admin())
  with check (is_admin());

create policy "read_all" on public."timetable_course_eligibility" as permissive for SELECT to public
  using (true);

create policy "timetable_courses_select" on public."timetable_courses" as permissive for SELECT to authenticated
  using (true);

create policy "timetable_courses_write_admin" on public."timetable_courses" as permissive for ALL to authenticated
  using (is_admin())
  with check (is_admin());

create policy "timetable_faculty_select" on public."timetable_faculty" as permissive for SELECT to authenticated
  using (true);

create policy "timetable_faculty_write_admin" on public."timetable_faculty" as permissive for ALL to authenticated
  using (is_admin())
  with check (is_admin());

create policy "timetable_rooms_select" on public."timetable_rooms" as permissive for SELECT to authenticated
  using (true);

create policy "timetable_rooms_write_admin" on public."timetable_rooms" as permissive for ALL to authenticated
  using (is_admin())
  with check (is_admin());

create policy "timetable_runs_select" on public."timetable_runs" as permissive for SELECT to authenticated
  using (true);

create policy "timetable_runs_write_admin" on public."timetable_runs" as permissive for ALL to authenticated
  using (is_admin())
  with check (is_admin());

create policy "timetable_settings_select" on public."timetable_settings" as permissive for SELECT to authenticated
  using (true);

create policy "timetable_settings_write_admin" on public."timetable_settings" as permissive for ALL to authenticated
  using (is_admin())
  with check (is_admin());

create policy "whitelists_select" on public."whitelists" as permissive for SELECT to authenticated
  using (((lower(email) = lower((auth.jwt() ->> 'email'::text))) OR is_admin()));

create policy "whitelists_write_admin" on public."whitelists" as permissive for ALL to authenticated
  using (is_admin())
  with check (is_admin());

-- Only local triggers. Never copy the production notification webhook here.
create trigger profiles_guard_role before insert or update on public.profiles
  for each row execute function public.guard_profile_role();
create trigger trigger_calculate_is_late before insert or update on public.submissions
  for each row execute function public.calculate_is_late();


-- ONLY universe-timetable-test, after stages 001/002; NOT a production migration.
-- Deliberate restricted test variant of supplied deployment grants:
-- reproduce client SELECT/INSERT/UPDATE/DELETE, omit TRUNCATE/REFERENCES/TRIGGER.
-- RLS remains enabled. Does not alter policies, Storage, Realtime or row data.

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

-- ONLY universe-timetable-test after stages 001-003 and rollback-only role tests.
-- Reproduce supplied Realtime membership; no Storage, data or webhook changes.
-- This is a reconstructed test stage, NOT a production migration.

do $$
begin
  if current_user <> 'postgres'
     or (select count(*) from pg_tables where schemaname = 'public') <> 18
     or (select count(*) from pg_policies where schemaname = 'public') <> 50 then
    raise exception 'Expected reconstructed disposable test project as postgres';
  end if;
  if not exists (select 1 from pg_publication
      where pubname = 'supabase_realtime'
        and pg_get_userbyid(pubowner) = 'postgres'
        and not puballtables and not pubviaroot
        and pubinsert and pubupdate and pubdelete and pubtruncate) then
    raise exception 'Publication settings mismatch; do not overwrite managed settings';
  end if;
  if exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime') then
    raise exception 'Refusing: publication already has members; do not rerun or use production';
  end if;
  if not exists (select 1 from pg_class
      where oid = 'public.cancellations'::regclass
        and relreplident = 'd' and relrowsecurity) then
    raise exception 'Expected cancellations with default replica identity and RLS';
  end if;
  if exists (select 1 from pg_trigger
      where tgrelid = 'public.notifications'::regclass and not tgisinternal) then
    raise exception 'Refusing with notification webhook installed';
  end if;
end $$;
alter publication supabase_realtime add table public.cancellations;
