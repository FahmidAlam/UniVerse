-- ONLY universe-timetable-test. Run the complete file as postgres TWICE.
-- Transactional scratch-schema rehearsal: NO DROP, RESET or COMMIT.
-- Public tables, managed Storage, Auth users and original Realtime stay untouched.
-- Replays namespace-adapted stages 001-004, restores a limited sanitized fixture,
-- checks exact content/count/checksum and catalog, then rolls everything back.
-- This is NOT full new-project provisioning or a complete account/Storage restore.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '90s';
set local search_path = pg_catalog, timetable_replay, public, extensions;
do $preflight$
declare t record; populated boolean;
begin
 if current_user <> 'postgres' then raise exception 'Use test-project postgres role'; end if;
 if to_regnamespace('timetable_replay') is not null
    or exists (select 1 from pg_publication where pubname='timetable_replay_publication') then
   raise exception 'Scratch objects already exist; do not delete them or bypass guard';
 end if;
 if (select count(*) from pg_tables where schemaname='public') <> 18
    or (select count(*) from pg_policies where schemaname='public') <> 50 then
   raise exception 'Expected reconstructed disposable test project';
 end if;
 for t in select tablename from pg_tables where schemaname='public' loop
   execute format('select exists(select 1 from public.%I)',t.tablename) into populated;
   if populated then raise exception 'Public data exists; do not run or clear it'; end if;
 end loop;
 if exists(select 1 from storage.objects)
    or exists(select 1 from pg_trigger where tgrelid='public.notifications'::regclass and not tgisinternal) then
   raise exception 'Unexpected Storage objects or notification webhook';
 end if;
 if not exists(select 1 from pg_extension e join pg_namespace n on n.oid=e.extnamespace
    where e.extname='vector' and e.extversion='0.8.2' and n.nspname='public') then
   raise exception 'Expected observed test-project public vector 0.8.2; no extension installation attempted';
 end if;
end $preflight$;
create schema timetable_replay;
-- RECONSTRUCTED TEST BASELINE: table/constraint/index stage only.
-- Source: user-supplied deployed metadata, 22 October 2026.
-- NOT an applied migration, full schema dump, or production rollout script.
-- Target ONLY: empty universe-timetable-test project in the Supabase SQL Editor.
-- This stage deliberately denies client access pending separate policy/grant reconciliation.
-- No schedules, users, credentials, webhook triggers or Edge Functions are imported.

do $$
begin
  if exists (select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
             where n.nspname = 'timetable_replay' and c.relkind in ('r', 'p')) then
    raise exception 'Refusing baseline: public already contains tables. Use an empty disposable test project.';
  end if;
end $$;

-- Match the supplied vector type/index dependency; fail if unavailable.

create table timetable_replay."assignments" (
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
alter table timetable_replay."assignments" enable row level security;
revoke all on table timetable_replay."assignments" from public, anon, authenticated;

create table timetable_replay."cancellations" (
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
alter table timetable_replay."cancellations" enable row level security;
revoke all on table timetable_replay."cancellations" from public, anon, authenticated;

create table timetable_replay."device_tokens" (
  "token" text not null,
  "user_id" uuid not null,
  "platform" text default 'android'::text not null,
  "updated_at" timestamp with time zone default now() not null
);
alter table timetable_replay."device_tokens" enable row level security;
revoke all on table timetable_replay."device_tokens" from public, anon, authenticated;

create table timetable_replay."documents" (
  "id" uuid default gen_random_uuid() not null,
  "content" text not null,
  "embedding" vector(768),
  "category" text not null
);
alter table timetable_replay."documents" enable row level security;
revoke all on table timetable_replay."documents" from public, anon, authenticated;

create table timetable_replay."notification_reads" (
  "user_id" uuid not null,
  "notification_id" uuid not null,
  "read_at" timestamp with time zone default now() not null
);
alter table timetable_replay."notification_reads" enable row level security;
revoke all on table timetable_replay."notification_reads" from public, anon, authenticated;

create table timetable_replay."notifications" (
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
alter table timetable_replay."notifications" enable row level security;
revoke all on table timetable_replay."notifications" from public, anon, authenticated;

create table timetable_replay."profiles" (
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
alter table timetable_replay."profiles" enable row level security;
revoke all on table timetable_replay."profiles" from public, anon, authenticated;

create table timetable_replay."resources" (
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
alter table timetable_replay."resources" enable row level security;
revoke all on table timetable_replay."resources" from public, anon, authenticated;

create table timetable_replay."routine_versions" (
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
alter table timetable_replay."routine_versions" enable row level security;
revoke all on table timetable_replay."routine_versions" from public, anon, authenticated;

create table timetable_replay."routines" (
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
alter table timetable_replay."routines" enable row level security;
revoke all on table timetable_replay."routines" from public, anon, authenticated;

create table timetable_replay."submissions" (
  "id" uuid default gen_random_uuid() not null,
  "assignment_id" uuid,
  "student_id" uuid,
  "file_url" text not null,
  "submitted_at" timestamp with time zone default now(),
  "is_late" boolean
);
alter table timetable_replay."submissions" enable row level security;
revoke all on table timetable_replay."submissions" from public, anon, authenticated;

create table timetable_replay."timetable_course_eligibility" (
  "id" uuid default gen_random_uuid() not null,
  "acronym" text not null,
  "course_code" text not null,
  "is_eligible" boolean default true not null,
  "priority" integer,
  "created_at" timestamp with time zone default now() not null,
  "updated_at" timestamp with time zone default now() not null
);
alter table timetable_replay."timetable_course_eligibility" enable row level security;
revoke all on table timetable_replay."timetable_course_eligibility" from public, anon, authenticated;

create table timetable_replay."timetable_courses" (
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
alter table timetable_replay."timetable_courses" enable row level security;
revoke all on table timetable_replay."timetable_courses" from public, anon, authenticated;

create table timetable_replay."timetable_faculty" (
  "id" uuid default gen_random_uuid() not null,
  "acronym" text not null,
  "full_name" text,
  "dept" text,
  "designation" text,
  "off_days" text[] default '{}'::text[] not null,
  "is_active" boolean default true not null,
  "courses" text[] default '{}'::text[] not null
);
alter table timetable_replay."timetable_faculty" enable row level security;
revoke all on table timetable_replay."timetable_faculty" from public, anon, authenticated;

create table timetable_replay."timetable_rooms" (
  "id" uuid default gen_random_uuid() not null,
  "name" text not null,
  "building" text,
  "is_lab" boolean default false not null,
  "is_gallery" boolean default false not null,
  "capacity" integer,
  "is_active" boolean default true not null,
  "dept" text
);
alter table timetable_replay."timetable_rooms" enable row level security;
revoke all on table timetable_replay."timetable_rooms" from public, anon, authenticated;

create table timetable_replay."timetable_runs" (
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
alter table timetable_replay."timetable_runs" enable row level security;
revoke all on table timetable_replay."timetable_runs" from public, anon, authenticated;

create table timetable_replay."timetable_settings" (
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
alter table timetable_replay."timetable_settings" enable row level security;
revoke all on table timetable_replay."timetable_settings" from public, anon, authenticated;

create table timetable_replay."whitelists" (
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
alter table timetable_replay."whitelists" enable row level security;
revoke all on table timetable_replay."whitelists" from public, anon, authenticated;

alter table timetable_replay."assignments" add constraint "assignments_pkey" PRIMARY KEY (id);
alter table timetable_replay."cancellations" add constraint "cancellations_pkey" PRIMARY KEY (id);
alter table timetable_replay."device_tokens" add constraint "device_tokens_pkey" PRIMARY KEY (token);
alter table timetable_replay."documents" add constraint "documents_pkey" PRIMARY KEY (id);
alter table timetable_replay."notification_reads" add constraint "notification_reads_pkey" PRIMARY KEY (user_id, notification_id);
alter table timetable_replay."notifications" add constraint "check_notif_type" CHECK (type = ANY (ARRAY['university'::text, 'class_cancel'::text, 'room_change'::text, 'test_reminder'::text, 'assignment'::text, 'exam'::text]));
alter table timetable_replay."notifications" add constraint "notifications_pkey" PRIMARY KEY (id);
alter table timetable_replay."profiles" add constraint "check_profile_role" CHECK (role = ANY (ARRAY['student'::text, 'teacher'::text, 'admin'::text]));
alter table timetable_replay."profiles" add constraint "profiles_pkey" PRIMARY KEY (id);
alter table timetable_replay."resources" add constraint "resources_pkey" PRIMARY KEY (id);
alter table timetable_replay."routine_versions" add constraint "routine_versions_pkey" PRIMARY KEY (id);
alter table timetable_replay."routine_versions" add constraint "routine_versions_source_check" CHECK (source = ANY (ARRAY['engine'::text, 'upload'::text, 'manual'::text]));
alter table timetable_replay."routines" add constraint "routines_pkey" PRIMARY KEY (id);
alter table timetable_replay."submissions" add constraint "submissions_pkey" PRIMARY KEY (id);
alter table timetable_replay."timetable_course_eligibility" add constraint "timetable_course_eligibility_pkey" PRIMARY KEY (id);
alter table timetable_replay."timetable_course_eligibility" add constraint "timetable_course_eligibility_priority_positive" CHECK (priority IS NULL OR priority > 0);
alter table timetable_replay."timetable_course_eligibility" add constraint "timetable_course_eligibility_unique" UNIQUE (acronym, course_code);
alter table timetable_replay."timetable_courses" add constraint "timetable_courses_code_batch_section_key" UNIQUE (code, batch, section);
alter table timetable_replay."timetable_courses" add constraint "timetable_courses_pkey" PRIMARY KEY (id);
alter table timetable_replay."timetable_faculty" add constraint "timetable_faculty_acronym_key" UNIQUE (acronym);
alter table timetable_replay."timetable_faculty" add constraint "timetable_faculty_pkey" PRIMARY KEY (id);
alter table timetable_replay."timetable_rooms" add constraint "timetable_rooms_name_key" UNIQUE (name);
alter table timetable_replay."timetable_rooms" add constraint "timetable_rooms_pkey" PRIMARY KEY (id);
alter table timetable_replay."timetable_runs" add constraint "timetable_runs_pkey" PRIMARY KEY (id);
alter table timetable_replay."timetable_settings" add constraint "timetable_settings_fixed_sessions_ck" CHECK (fixed_sessions_per_week IS NULL OR fixed_sessions_per_week >= 0 AND fixed_sessions_per_week <= 7);
alter table timetable_replay."timetable_settings" add constraint "timetable_settings_id_check" CHECK (id = 1);
alter table timetable_replay."timetable_settings" add constraint "timetable_settings_pkey" PRIMARY KEY (id);
alter table timetable_replay."timetable_settings" add constraint "timetable_settings_weeks_in_term_ck" CHECK (weeks_in_term >= 1 AND weeks_in_term <= 52);
alter table timetable_replay."whitelists" add constraint "check_role" CHECK (role = ANY (ARRAY['student'::text, 'teacher'::text, 'admin'::text]));
alter table timetable_replay."whitelists" add constraint "whitelists_pkey" PRIMARY KEY (email);
alter table timetable_replay."assignments" add constraint "assignments_teacher_id_fkey" FOREIGN KEY (teacher_id) REFERENCES profiles(id) ON DELETE CASCADE;
alter table timetable_replay."cancellations" add constraint "cancellations_cancelled_by_fkey" FOREIGN KEY (cancelled_by) REFERENCES profiles(id) ON DELETE SET NULL;
alter table timetable_replay."cancellations" add constraint "cancellations_routine_id_fkey" FOREIGN KEY (routine_id) REFERENCES routines(id) ON DELETE SET NULL;
alter table timetable_replay."device_tokens" add constraint "device_tokens_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table timetable_replay."notification_reads" add constraint "notification_reads_notification_id_fkey" FOREIGN KEY (notification_id) REFERENCES notifications(id) ON DELETE CASCADE;
alter table timetable_replay."notification_reads" add constraint "notification_reads_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table timetable_replay."notifications" add constraint "notifications_sent_by_fkey" FOREIGN KEY (sent_by) REFERENCES profiles(id) ON DELETE SET NULL;
alter table timetable_replay."profiles" add constraint "profiles_id_fkey" FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table timetable_replay."resources" add constraint "resources_uploaded_by_fkey" FOREIGN KEY (uploaded_by) REFERENCES profiles(id) ON DELETE SET NULL;
alter table timetable_replay."routine_versions" add constraint "routine_versions_published_by_fkey" FOREIGN KEY (published_by) REFERENCES auth.users(id);
alter table timetable_replay."routines" add constraint "routines_routine_version_id_fkey" FOREIGN KEY (routine_version_id) REFERENCES routine_versions(id) ON DELETE CASCADE;
alter table timetable_replay."routines" add constraint "routines_teacher_id_fkey" FOREIGN KEY (teacher_id) REFERENCES profiles(id) ON DELETE SET NULL;
alter table timetable_replay."submissions" add constraint "submissions_assignment_id_fkey" FOREIGN KEY (assignment_id) REFERENCES assignments(id) ON DELETE CASCADE;
alter table timetable_replay."submissions" add constraint "submissions_student_id_fkey" FOREIGN KEY (student_id) REFERENCES profiles(id) ON DELETE CASCADE;
alter table timetable_replay."timetable_runs" add constraint "timetable_runs_created_by_fkey" FOREIGN KEY (created_by) REFERENCES profiles(id);

-- Constraint-owned indexes are created by their constraints.
CREATE INDEX cancellations_date_idx ON timetable_replay.cancellations USING btree (class_date);
CREATE UNIQUE INDEX cancellations_routine_date_uniq ON timetable_replay.cancellations USING btree (routine_id, class_date);
CREATE INDEX idx_device_tokens_user ON timetable_replay.device_tokens USING btree (user_id);
CREATE INDEX documents_embedding_idx ON timetable_replay.documents USING hnsw (embedding vector_cosine_ops);
CREATE INDEX idx_notification_reads_user ON timetable_replay.notification_reads USING btree (user_id);
CREATE UNIQUE INDEX routine_versions_one_active ON timetable_replay.routine_versions USING btree (is_active) WHERE is_active;
CREATE INDEX routines_lookup_idx ON timetable_replay.routines USING btree (batch, section, day);
CREATE INDEX routines_teacher_idx ON timetable_replay.routines USING btree (teacher_code, day);
CREATE INDEX routines_version_idx ON timetable_replay.routines USING btree (routine_version_id);
CREATE INDEX timetable_course_eligibility_acronym_idx ON timetable_replay.timetable_course_eligibility USING btree (acronym);

-- Stop here: functions, policies, grants, Storage, Realtime and fixtures are separate.

-- RECONSTRUCTED TEST BASELINE stage 002: functions, public RLS policies, local triggers.
-- Only for universe-timetable-test after stage 001. NOT a production migration.
-- Source: user-supplied deployed function and policy metadata, 22 October 2026.
-- Policies preserve observed legacy behavior; this does not certify their security.
-- Client table grants remain revoked. No webhook, Storage, Realtime, FCM or data writes.

set local search_path = pg_catalog, timetable_replay, public, extensions;

do $$
begin
  if (select count(*) from pg_tables where schemaname = 'timetable_replay') <> 18
     or to_regclass('timetable_replay.routines') is null
     or to_regclass('timetable_replay.timetable_courses') is null then
    raise exception 'Stage 001 must have created exactly 18 tables in the disposable test project.';
  end if;
  if exists (select 1 from pg_policies where schemaname = 'timetable_replay') then
    raise exception 'Refusing stage 002: public policies already exist. Do not rerun or use production.';
  end if;
  if exists (select 1 from pg_tables t
      cross join (values ('anon'), ('authenticated')) as roles(name)
      cross join (values ('SELECT'), ('INSERT'), ('UPDATE'), ('DELETE'),
                         ('TRUNCATE'), ('REFERENCES'), ('TRIGGER')) as privileges(name)
      where t.schemaname = 'timetable_replay'
        and has_table_privilege(roles.name,
          format('%I.%I', t.schemaname, t.tablename), privileges.name)) then
    raise exception 'Refusing stage 002: stage 001 client table restrictions are absent.';
  end if;
end $$;

CREATE OR REPLACE FUNCTION timetable_replay.my_role()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'timetable_replay'
AS $function$
  select role from profiles where id = auth.uid();
$function$;
alter function timetable_replay."my_role"() owner to "postgres";
revoke all on function timetable_replay."my_role"() from public, anon, authenticated;
grant execute on function timetable_replay."my_role"() to authenticated;

CREATE OR REPLACE FUNCTION timetable_replay.is_admin()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'timetable_replay'
AS $function$
  select coalesce(timetable_replay.my_role() = 'admin', false);
$function$;
alter function timetable_replay."is_admin"() owner to "postgres";
revoke all on function timetable_replay."is_admin"() from public, anon, authenticated;
grant execute on function timetable_replay."is_admin"() to authenticated;

CREATE OR REPLACE FUNCTION timetable_replay.register_device_token(p_token text, p_platform text DEFAULT 'android'::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'timetable_replay'
AS $function$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  -- Clear a stale row left by a previous user of this device.
  delete from timetable_replay.device_tokens
   where token = p_token
     and user_id <> auth.uid();

  insert into timetable_replay.device_tokens (token, user_id, platform, updated_at)
  values (p_token, auth.uid(), p_platform, now())
  on conflict (token) do update
     set user_id    = excluded.user_id,
         platform   = excluded.platform,
         updated_at = now();
end;
$function$;
alter function timetable_replay."register_device_token"(text,text) owner to "postgres";
revoke all on function timetable_replay."register_device_token"(text,text) from public, anon, authenticated;
grant execute on function timetable_replay."register_device_token"(text,text) to authenticated;

CREATE OR REPLACE FUNCTION timetable_replay.guard_profile_role()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'timetable_replay'
AS $function$
begin
  -- No end-user JWT (SQL editor, service role) or an admin: any role.
  if auth.uid() is null or timetable_replay.is_admin() then
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
alter function timetable_replay."guard_profile_role"() owner to "postgres";
revoke all on function timetable_replay."guard_profile_role"() from public, anon, authenticated;
grant execute on function timetable_replay."guard_profile_role"() to anon;
grant execute on function timetable_replay."guard_profile_role"() to authenticated;

CREATE OR REPLACE FUNCTION timetable_replay.calculate_is_late()
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
alter function timetable_replay."calculate_is_late"() owner to "postgres";
revoke all on function timetable_replay."calculate_is_late"() from public, anon, authenticated;
grant execute on function timetable_replay."calculate_is_late"() to anon;
grant execute on function timetable_replay."calculate_is_late"() to authenticated;

CREATE OR REPLACE FUNCTION timetable_replay.match_documents(query_embedding vector, match_count integer DEFAULT 3)
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
alter function timetable_replay."match_documents"(public.vector,integer) owner to "postgres";
revoke all on function timetable_replay."match_documents"(public.vector,integer) from public, anon, authenticated;
grant execute on function timetable_replay."match_documents"(public.vector,integer) to anon;
grant execute on function timetable_replay."match_documents"(public.vector,integer) to authenticated;

CREATE OR REPLACE FUNCTION timetable_replay.publish_routine(p_rows jsonb, p_semester_label text DEFAULT NULL::text, p_source text DEFAULT 'engine'::text, p_stats jsonb DEFAULT '{}'::jsonb, p_validation jsonb DEFAULT '{}'::jsonb, p_notes text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'timetable_replay'
AS $function$
declare
  v_id    uuid;
  v_count int;
begin
  if not timetable_replay.is_admin() then
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

  insert into timetable_replay.routine_versions
    (semester_label, source, published_by, stats, validation, notes)
  values (p_semester_label, p_source, auth.uid(), coalesce(p_stats, '{}'::jsonb),
          coalesce(p_validation, '{}'::jsonb), p_notes)
  returning id into v_id;

  -- Replace, never merge. Every previous class goes, including batches that
  -- do not appear in the incoming routine. `where true` is deliberate — see
  -- the header comment; do not "simplify" this back to a bare DELETE.
  update timetable_replay.routine_versions set is_active = false where is_active;
  delete from timetable_replay.routines where true;

  insert into timetable_replay.routines
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

  update timetable_replay.routine_versions
     set is_active = true, row_count = v_count, published_at = now()
   where id = v_id;

  return jsonb_build_object('version_id', v_id, 'row_count', v_count);
end $function$;
alter function timetable_replay."publish_routine"(jsonb,text,text,jsonb,jsonb,text) owner to "postgres";
revoke all on function timetable_replay."publish_routine"(jsonb,text,text,jsonb,jsonb,text) from public, anon, authenticated;
grant execute on function timetable_replay."publish_routine"(jsonb,text,text,jsonb,jsonb,text) to authenticated;

create policy "assignments_delete" on timetable_replay."assignments" as permissive for DELETE to authenticated
  using (((teacher_id = auth.uid()) OR is_admin()));

create policy "assignments_insert_teacher" on timetable_replay."assignments" as permissive for INSERT to authenticated
  with check (((teacher_id = auth.uid()) AND (my_role() = ANY (ARRAY['teacher'::text, 'admin'::text]))));

create policy "assignments_modify" on timetable_replay."assignments" as permissive for UPDATE to authenticated
  using (((teacher_id = auth.uid()) OR is_admin()))
  with check (((teacher_id = auth.uid()) OR is_admin()));

create policy "assignments_select" on timetable_replay."assignments" as permissive for SELECT to authenticated
  using (true);

create policy "cancellations_delete" on timetable_replay."cancellations" as permissive for DELETE to authenticated
  using (((cancelled_by = auth.uid()) OR is_admin()));

create policy "cancellations_insert_staff" on timetable_replay."cancellations" as permissive for INSERT to authenticated
  with check (((cancelled_by = auth.uid()) AND (my_role() = ANY (ARRAY['teacher'::text, 'admin'::text]))));

create policy "cancellations_select" on timetable_replay."cancellations" as permissive for SELECT to authenticated
  using (true);

create policy "own_tokens_delete" on timetable_replay."device_tokens" as permissive for DELETE to public
  using ((user_id = auth.uid()));

create policy "own_tokens_insert" on timetable_replay."device_tokens" as permissive for INSERT to public
  with check ((user_id = auth.uid()));

create policy "own_tokens_select" on timetable_replay."device_tokens" as permissive for SELECT to public
  using ((user_id = auth.uid()));

create policy "own_tokens_update" on timetable_replay."device_tokens" as permissive for UPDATE to public
  using ((user_id = auth.uid()));

create policy "documents_select" on timetable_replay."documents" as permissive for SELECT to authenticated
  using (true);

create policy "documents_write_admin" on timetable_replay."documents" as permissive for ALL to authenticated
  using (is_admin())
  with check (is_admin());

create policy "own_reads_delete" on timetable_replay."notification_reads" as permissive for DELETE to public
  using ((user_id = auth.uid()));

create policy "own_reads_insert" on timetable_replay."notification_reads" as permissive for INSERT to public
  with check ((user_id = auth.uid()));

create policy "own_reads_select" on timetable_replay."notification_reads" as permissive for SELECT to public
  using ((user_id = auth.uid()));

create policy "own_reads_update" on timetable_replay."notification_reads" as permissive for UPDATE to public
  using ((user_id = auth.uid()));

create policy "notifications_delete" on timetable_replay."notifications" as permissive for DELETE to authenticated
  using (((sent_by = auth.uid()) OR is_admin()));

create policy "notifications_insert_staff" on timetable_replay."notifications" as permissive for INSERT to authenticated
  with check (((sent_by = auth.uid()) AND (my_role() = ANY (ARRAY['teacher'::text, 'admin'::text]))));

create policy "notifications_select" on timetable_replay."notifications" as permissive for SELECT to authenticated
  using (true);

create policy "profiles_delete_admin" on timetable_replay."profiles" as permissive for DELETE to authenticated
  using (is_admin());

create policy "profiles_insert_own" on timetable_replay."profiles" as permissive for INSERT to authenticated
  with check (((id = auth.uid()) AND ((role = ANY (ARRAY['student'::text, 'teacher'::text])) OR (EXISTS ( SELECT 1
   FROM whitelists w
  WHERE ((lower(w.email) = lower((auth.jwt() ->> 'email'::text))) AND (w.role = profiles.role)))))));

create policy "profiles_select" on timetable_replay."profiles" as permissive for SELECT to authenticated
  using (true);

create policy "profiles_update_own" on timetable_replay."profiles" as permissive for UPDATE to authenticated
  using (((id = auth.uid()) OR is_admin()))
  with check ((is_admin() OR ((id = auth.uid()) AND ((role = ANY (ARRAY['student'::text, 'teacher'::text])) OR (EXISTS ( SELECT 1
   FROM whitelists w
  WHERE ((lower(w.email) = lower((auth.jwt() ->> 'email'::text))) AND (w.role = profiles.role))))))));

create policy "resources_delete" on timetable_replay."resources" as permissive for DELETE to authenticated
  using (((uploaded_by = auth.uid()) OR is_admin()));

create policy "resources_insert_staff" on timetable_replay."resources" as permissive for INSERT to authenticated
  with check (((uploaded_by = auth.uid()) AND (my_role() = ANY (ARRAY['teacher'::text, 'admin'::text]))));

create policy "resources_modify" on timetable_replay."resources" as permissive for UPDATE to authenticated
  using (((uploaded_by = auth.uid()) OR is_admin()))
  with check (((uploaded_by = auth.uid()) OR is_admin()));

create policy "resources_select" on timetable_replay."resources" as permissive for SELECT to authenticated
  using (true);

create policy "routine_versions_select" on timetable_replay."routine_versions" as permissive for SELECT to authenticated
  using (true);

create policy "routine_versions_write_admin" on timetable_replay."routine_versions" as permissive for ALL to authenticated
  using (is_admin())
  with check (is_admin());

create policy "routines_select" on timetable_replay."routines" as permissive for SELECT to authenticated
  using (true);

create policy "routines_write_admin" on timetable_replay."routines" as permissive for ALL to authenticated
  using (is_admin())
  with check (is_admin());

create policy "submissions_delete" on timetable_replay."submissions" as permissive for DELETE to authenticated
  using (((student_id = auth.uid()) OR is_admin()));

create policy "submissions_insert_own" on timetable_replay."submissions" as permissive for INSERT to authenticated
  with check ((student_id = auth.uid()));

create policy "submissions_select" on timetable_replay."submissions" as permissive for SELECT to authenticated
  using (((student_id = auth.uid()) OR (my_role() = ANY (ARRAY['teacher'::text, 'admin'::text]))));

create policy "submissions_update_own" on timetable_replay."submissions" as permissive for UPDATE to authenticated
  using ((student_id = auth.uid()))
  with check ((student_id = auth.uid()));

create policy "admin_write" on timetable_replay."timetable_course_eligibility" as permissive for ALL to public
  using (is_admin())
  with check (is_admin());

create policy "read_all" on timetable_replay."timetable_course_eligibility" as permissive for SELECT to public
  using (true);

create policy "timetable_courses_select" on timetable_replay."timetable_courses" as permissive for SELECT to authenticated
  using (true);

create policy "timetable_courses_write_admin" on timetable_replay."timetable_courses" as permissive for ALL to authenticated
  using (is_admin())
  with check (is_admin());

create policy "timetable_faculty_select" on timetable_replay."timetable_faculty" as permissive for SELECT to authenticated
  using (true);

create policy "timetable_faculty_write_admin" on timetable_replay."timetable_faculty" as permissive for ALL to authenticated
  using (is_admin())
  with check (is_admin());

create policy "timetable_rooms_select" on timetable_replay."timetable_rooms" as permissive for SELECT to authenticated
  using (true);

create policy "timetable_rooms_write_admin" on timetable_replay."timetable_rooms" as permissive for ALL to authenticated
  using (is_admin())
  with check (is_admin());

create policy "timetable_runs_select" on timetable_replay."timetable_runs" as permissive for SELECT to authenticated
  using (true);

create policy "timetable_runs_write_admin" on timetable_replay."timetable_runs" as permissive for ALL to authenticated
  using (is_admin())
  with check (is_admin());

create policy "timetable_settings_select" on timetable_replay."timetable_settings" as permissive for SELECT to authenticated
  using (true);

create policy "timetable_settings_write_admin" on timetable_replay."timetable_settings" as permissive for ALL to authenticated
  using (is_admin())
  with check (is_admin());

create policy "whitelists_select" on timetable_replay."whitelists" as permissive for SELECT to authenticated
  using (((lower(email) = lower((auth.jwt() ->> 'email'::text))) OR is_admin()));

create policy "whitelists_write_admin" on timetable_replay."whitelists" as permissive for ALL to authenticated
  using (is_admin())
  with check (is_admin());

-- Only local triggers. Never copy the production notification webhook here.
create trigger profiles_guard_role before insert or update on timetable_replay.profiles
  for each row execute function timetable_replay.guard_profile_role();
create trigger trigger_calculate_is_late before insert or update on timetable_replay.submissions
  for each row execute function timetable_replay.calculate_is_late();


-- ONLY universe-timetable-test, after stages 001/002; NOT a production migration.
-- Deliberate restricted test variant of supplied deployment grants:
-- reproduce client SELECT/INSERT/UPDATE/DELETE, omit TRUNCATE/REFERENCES/TRIGGER.
-- RLS remains enabled. Does not alter policies, Storage, Realtime or row data.

do $$
declare table_name text;
begin
  if (select count(*) from pg_tables where schemaname = 'timetable_replay') <> 18
     or (select count(*) from pg_policies where schemaname = 'timetable_replay') <> 50 then
    raise exception 'Expected completed stages 001 and 002 in disposable test project';
  end if;
  if exists (select 1 from pg_tables
      where schemaname = 'timetable_replay' and not rowsecurity) then
    raise exception 'Refusing grants while any public table has RLS disabled';
  end if;
  if exists (select 1 from pg_tables t
      cross join (values ('anon'), ('authenticated')) as roles(name)
      cross join (values ('SELECT'), ('INSERT'), ('UPDATE'), ('DELETE'),
                         ('TRUNCATE'), ('REFERENCES'), ('TRIGGER')) as privileges(name)
      where t.schemaname = 'timetable_replay'
        and has_table_privilege(roles.name,
          format('%I.%I', t.schemaname, t.tablename), privileges.name)) then
    raise exception 'Expected stage 002 closed table grants; do not rerun or use production';
  end if;
  if exists (select 1 from pg_trigger
      where tgrelid = 'timetable_replay.notifications'::regclass and not tgisinternal) then
    raise exception 'Refusing grants with notification webhook installed';
  end if;
  foreach table_name in array array[
    'assignments', 'cancellations', 'device_tokens', 'documents',
    'notification_reads', 'notifications', 'profiles', 'resources',
    'routine_versions', 'routines', 'submissions', 'timetable_course_eligibility',
    'timetable_courses', 'timetable_faculty', 'timetable_rooms',
    'timetable_runs', 'timetable_settings', 'whitelists'
  ] loop
    if to_regclass(format('timetable_replay.%I', table_name)) is null then
      raise exception 'Missing expected baseline table: %', table_name;
    end if;
    execute format(
      'grant select, insert, update, delete on table timetable_replay.%I to anon, authenticated',
      table_name);
  end loop;
end $$;

create publication timetable_replay_publication with (publish='insert, update, delete, truncate', publish_via_partition_root=false);
-- ONLY universe-timetable-test after stages 001-003 and rollback-only role tests.
-- Reproduce supplied Realtime membership; no Storage, data or webhook changes.
-- This is a reconstructed test stage, NOT a production migration.

do $$
begin
  if current_user <> 'postgres'
     or (select count(*) from pg_tables where schemaname = 'timetable_replay') <> 18
     or (select count(*) from pg_policies where schemaname = 'timetable_replay') <> 50 then
    raise exception 'Expected reconstructed disposable test project as postgres';
  end if;
  if not exists (select 1 from pg_publication
      where pubname = 'timetable_replay_publication'
        and pg_get_userbyid(pubowner) = 'postgres'
        and not puballtables and not pubviaroot
        and pubinsert and pubupdate and pubdelete and pubtruncate) then
    raise exception 'Publication settings mismatch; do not overwrite managed settings';
  end if;
  if exists (select 1 from pg_publication_tables where pubname = 'timetable_replay_publication') then
    raise exception 'Refusing: publication already has members; do not rerun or use production';
  end if;
  if not exists (select 1 from pg_class
      where oid = 'timetable_replay.cancellations'::regclass
        and relreplident = 'd' and relrowsecurity) then
    raise exception 'Expected cancellations with default replica identity and RLS';
  end if;
  if exists (select 1 from pg_trigger
      where tgrelid = 'timetable_replay.notifications'::regclass and not tgisinternal) then
    raise exception 'Refusing with notification webhook installed';
  end if;
end $$;
alter publication timetable_replay_publication add table timetable_replay.cancellations;

set local search_path = pg_catalog, timetable_replay, public, extensions;
do $restore$
declare
 payload_text text := $replay_snapshot${"routines": [{"day": "Friday", "room": "RAB-304", "batch": "63", "section": "D", "subject": "CSE-3231", "semester": 7, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 1, "version_key": 3, "subject_code": "CSE-3231", "teacher_code": "T25", "teacher_name": "Teacher-25"}, {"day": "Friday", "room": "RAB-306", "batch": "63", "section": "E", "subject": "Research Methodology", "semester": 7, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 2, "version_key": 3, "subject_code": "GED-3213", "teacher_code": "T48", "teacher_name": "Teacher-48"}, {"day": "Friday", "room": "ACL-3", "batch": "64", "section": "A", "subject": "CSE-3212", "semester": 6, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 3, "version_key": 3, "subject_code": "CSE-3212", "teacher_code": "T52", "teacher_name": "Teacher-52"}, {"day": "Friday", "room": "RAB-302", "batch": "64", "section": "B", "subject": "CSE-2231", "semester": 6, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 4, "version_key": 3, "subject_code": "CSE-2231", "teacher_code": "T70", "teacher_name": "Teacher-70"}, {"day": "Friday", "room": "RKB-303", "batch": "64", "section": "C", "subject": "CSE-2231", "semester": 6, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 5, "version_key": 3, "subject_code": "CSE-2231", "teacher_code": "T59", "teacher_name": "Teacher-59"}, {"day": "Friday", "room": "RKB-402", "batch": "64", "section": "H", "subject": "GED-1291", "semester": 6, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 6, "version_key": 3, "subject_code": "GED-1291", "teacher_code": "T39", "teacher_name": "Teacher-39"}, {"day": "Friday", "room": "ACL-2", "batch": "64", "section": "I", "subject": "CSE-3212", "semester": 6, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 7, "version_key": 3, "subject_code": "CSE-3212", "teacher_code": "T21", "teacher_name": "Teacher-21"}, {"day": "Friday", "room": "RKB-103", "batch": "65", "section": "C", "subject": "CSE-3121", "semester": 5, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 8, "version_key": 3, "subject_code": "CSE-3121", "teacher_code": "T12", "teacher_name": "Teacher-12"}, {"day": "Friday", "room": "RKB-407", "batch": "65", "section": "D", "subject": "GED-1261", "semester": 5, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 9, "version_key": 3, "subject_code": "GED-1261", "teacher_code": "T62", "teacher_name": "Teacher-62"}, {"day": "Friday", "room": "RAB-401", "batch": "66", "section": "E", "subject": "GED-1201", "semester": 4, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 10, "version_key": 3, "subject_code": "GED-1201", "teacher_code": "T13", "teacher_name": "Teacher-13"}, {"day": "Friday", "room": "G2", "batch": "66", "section": "H", "subject": "CSE-2211", "semester": 4, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 11, "version_key": 3, "subject_code": "CSE-2211", "teacher_code": "T22", "teacher_name": "Teacher-22"}, {"day": "Friday", "room": "RAB-309", "batch": "67", "section": "A", "subject": "EEE-1221", "semester": 3, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 12, "version_key": 3, "subject_code": "EEE-1221", "teacher_code": "T33", "teacher_name": "Teacher-33"}, {"day": "Friday", "room": "ACL-1", "batch": "67", "section": "F+G", "subject": "CSE-2112", "semester": 3, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 13, "version_key": 3, "subject_code": "CSE-2112", "teacher_code": "T58", "teacher_name": "Teacher-58"}, {"day": "Friday", "room": "ACL-4", "batch": "Retake", "section": "ALL", "subject": "CSE-1212", "semester": 1, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 14, "version_key": 3, "subject_code": "CSE-1212", "teacher_code": "T30", "teacher_name": "Teacher-30"}, {"day": "Friday", "room": "ACL-1", "batch": "63", "section": "D", "subject": "CSE-3232", "semester": 7, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 15, "version_key": 3, "subject_code": "CSE-3232", "teacher_code": "T25", "teacher_name": "Teacher-25"}, {"day": "Friday", "room": "RAB-306", "batch": "63", "section": "E", "subject": "CSE-4161", "semester": 7, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 16, "version_key": 3, "subject_code": "CSE-4161", "teacher_code": "T48", "teacher_name": "Teacher-48"}, {"day": "Friday", "room": "RKB-407", "batch": "64", "section": "A", "subject": "CSE-2231", "semester": 6, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 17, "version_key": 3, "subject_code": "CSE-2231", "teacher_code": "T59", "teacher_name": "Teacher-59"}, {"day": "Friday", "room": "ACL-3", "batch": "64", "section": "B", "subject": "CSE-3212", "semester": 6, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 18, "version_key": 3, "subject_code": "CSE-3212", "teacher_code": "T52", "teacher_name": "Teacher-52"}, {"day": "Friday", "room": "RKB-303", "batch": "64", "section": "C", "subject": "GED-1291", "semester": 6, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 19, "version_key": 3, "subject_code": "GED-1291", "teacher_code": "T39", "teacher_name": "Teacher-39"}, {"day": "Friday", "room": "ACL-2", "batch": "64", "section": "H", "subject": "CSE-3212", "semester": 6, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 20, "version_key": 3, "subject_code": "CSE-3212", "teacher_code": "T21", "teacher_name": "Teacher-21"}, {"day": "Friday", "room": "RKB-402", "batch": "64", "section": "I", "subject": "CSE-3213", "semester": 6, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 21, "version_key": 3, "subject_code": "CSE-3213", "teacher_code": "T12", "teacher_name": "Teacher-12"}, {"day": "Friday", "room": "G2", "batch": "65", "section": "C", "subject": "GED-1261", "semester": 5, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 22, "version_key": 3, "subject_code": "GED-1261", "teacher_code": "T78", "teacher_name": "Teacher-78"}, {"day": "Friday", "room": "RKB-103", "batch": "65", "section": "D", "subject": "CSE-2101", "semester": 5, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 23, "version_key": 3, "subject_code": "CSE-2101", "teacher_code": "T79", "teacher_name": "Teacher-79"}, {"day": "Friday", "room": "RAB-304", "batch": "66", "section": "E", "subject": "CSE-2211", "semester": 4, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 24, "version_key": 3, "subject_code": "CSE-2211", "teacher_code": "T51", "teacher_name": "Teacher-51"}, {"day": "Friday", "room": "RAB-401", "batch": "66", "section": "H", "subject": "GED-1201", "semester": 4, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 25, "version_key": 3, "subject_code": "GED-1201", "teacher_code": "T13", "teacher_name": "Teacher-13"}, {"day": "Friday", "room": "RAB-302", "batch": "67", "section": "A", "subject": "CSE-2111", "semester": 3, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 26, "version_key": 3, "subject_code": "CSE-2111", "teacher_code": "T70", "teacher_name": "Teacher-70"}, {"day": "Friday", "room": "RAB-309", "batch": "67", "section": "F+G", "subject": "CSE-2111", "semester": 3, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 27, "version_key": 3, "subject_code": "CSE-2111", "teacher_code": "T58", "teacher_name": "Teacher-58"}, {"day": "Friday", "room": "ACL-4", "batch": "Retake", "section": "ALL", "subject": "CSE-1212", "semester": 1, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 28, "version_key": 3, "subject_code": "CSE-1212", "teacher_code": "T30", "teacher_name": "Teacher-30"}, {"day": "Friday", "room": "RAB-304", "batch": "63", "section": "A", "subject": "MAT-2251", "semester": 7, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 29, "version_key": 3, "subject_code": "MAT-2251", "teacher_code": "T71", "teacher_name": "Teacher-71"}, {"day": "Friday", "room": "ACL-1", "batch": "63", "section": "E", "subject": "CSE-3232", "semester": 7, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 30, "version_key": 3, "subject_code": "CSE-3232", "teacher_code": "T25", "teacher_name": "Teacher-25"}, {"day": "Friday", "room": "ACL-2", "batch": "64", "section": "D", "subject": "CSE-3212", "semester": 6, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 31, "version_key": 3, "subject_code": "CSE-3212", "teacher_code": "T21", "teacher_name": "Teacher-21"}, {"day": "Friday", "room": "RAB-309", "batch": "64", "section": "E", "subject": "GED-1291", "semester": 6, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 32, "version_key": 3, "subject_code": "GED-1291", "teacher_code": "T39", "teacher_name": "Teacher-39"}, {"day": "Friday", "room": "RAB-401", "batch": "64", "section": "F", "subject": "CSE-2231", "semester": 6, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 33, "version_key": 3, "subject_code": "CSE-2231", "teacher_code": "T79", "teacher_name": "Teacher-79"}, {"day": "Friday", "room": "ACL-3", "batch": "64", "section": "G", "subject": "CSE-3212", "semester": 6, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 34, "version_key": 3, "subject_code": "CSE-3212", "teacher_code": "T52", "teacher_name": "Teacher-52"}, {"day": "Friday", "room": "RAB-306", "batch": "65", "section": "A", "subject": "CSE-3121", "semester": 5, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 35, "version_key": 3, "subject_code": "CSE-3121", "teacher_code": "T12", "teacher_name": "Teacher-12"}, {"day": "Friday", "room": "G2", "batch": "65", "section": "B", "subject": "MAT-3151", "semester": 5, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 36, "version_key": 3, "subject_code": "MAT-3151", "teacher_code": "T64", "teacher_name": "Teacher-64"}, {"day": "Friday", "room": "ECL-1", "batch": "66", "section": "C", "subject": "EEE-1222", "semester": 4, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 37, "version_key": 3, "subject_code": "EEE-1222", "teacher_code": "T77", "teacher_name": "Teacher-77"}, {"day": "Friday", "room": "ACL-4", "batch": "66", "section": "F", "subject": "CSE-2212", "semester": 4, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 38, "version_key": 3, "subject_code": "CSE-2212", "teacher_code": "T51", "teacher_name": "Teacher-51"}, {"day": "Friday", "room": "RAB-302", "batch": "67", "section": "B", "subject": "CSE-2111", "semester": 3, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 39, "version_key": 3, "subject_code": "CSE-2111", "teacher_code": "T70", "teacher_name": "Teacher-70"}, {"day": "Friday", "room": "RAB-304", "batch": "63", "section": "A", "subject": "CSE-3231", "semester": 7, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 40, "version_key": 3, "subject_code": "CSE-3231", "teacher_code": "T48", "teacher_name": "Teacher-48"}, {"day": "Friday", "room": "G2", "batch": "64", "section": "D", "subject": "GED-1291", "semester": 6, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 41, "version_key": 3, "subject_code": "GED-1291", "teacher_code": "T39", "teacher_name": "Teacher-39"}, {"day": "Friday", "room": "ACL-3", "batch": "64", "section": "E", "subject": "CSE-3212", "semester": 6, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 42, "version_key": 3, "subject_code": "CSE-3212", "teacher_code": "T52", "teacher_name": "Teacher-52"}, {"day": "Friday", "room": "ACL-1", "batch": "64", "section": "F", "subject": "CSE-3212", "semester": 6, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 43, "version_key": 3, "subject_code": "CSE-3212", "teacher_code": "T21", "teacher_name": "Teacher-21"}, {"day": "Friday", "room": "RAB-401", "batch": "64", "section": "G", "subject": "CSE-2231", "semester": 6, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 44, "version_key": 3, "subject_code": "CSE-2231", "teacher_code": "T79", "teacher_name": "Teacher-79"}, {"day": "Friday", "room": "RAB-306", "batch": "65", "section": "A", "subject": "MAT-3151", "semester": 5, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 45, "version_key": 3, "subject_code": "MAT-3151", "teacher_code": "T64", "teacher_name": "Teacher-64"}, {"day": "Friday", "room": "RAB-309", "batch": "65", "section": "B", "subject": "GED-1261", "semester": 5, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 46, "version_key": 3, "subject_code": "GED-1261", "teacher_code": "T78", "teacher_name": "Teacher-78"}, {"day": "Friday", "room": "RKB-103", "batch": "66", "section": "C", "subject": "MAT-2251", "semester": 4, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 47, "version_key": 3, "subject_code": "MAT-2251", "teacher_code": "T71", "teacher_name": "Teacher-71"}, {"day": "Friday", "room": "RAB-302", "batch": "66", "section": "F", "subject": "CSE-2211", "semester": 4, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 48, "version_key": 3, "subject_code": "CSE-2211", "teacher_code": "T51", "teacher_name": "Teacher-51"}, {"day": "Friday", "room": "ACL-2", "batch": "67", "section": "B", "subject": "CSE-2112", "semester": 3, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 49, "version_key": 3, "subject_code": "CSE-2112", "teacher_code": "T70", "teacher_name": "Teacher-70"}, {"day": "Friday", "room": "ACL-1", "batch": "63", "section": "A", "subject": "CSE-3232", "semester": 7, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 50, "version_key": 3, "subject_code": "CSE-3232", "teacher_code": "T48", "teacher_name": "Teacher-48"}, {"day": "Friday", "room": "RAB-306", "batch": "64", "section": "E", "subject": "CSE-2231", "semester": 6, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 51, "version_key": 3, "subject_code": "CSE-2231", "teacher_code": "T79", "teacher_name": "Teacher-79"}, {"day": "Friday", "room": "RAB-401", "batch": "64", "section": "G", "subject": "GED-1291", "semester": 6, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 52, "version_key": 3, "subject_code": "GED-1291", "teacher_code": "T39", "teacher_name": "Teacher-39"}, {"day": "Friday", "room": "RAB-302", "batch": "65", "section": "B", "subject": "CSE-3121", "semester": 5, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 53, "version_key": 3, "subject_code": "CSE-3121", "teacher_code": "T12", "teacher_name": "Teacher-12"}, {"day": "Friday", "room": "RAB-304", "batch": "66", "section": "F", "subject": "GED-1201", "semester": 4, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 54, "version_key": 3, "subject_code": "GED-1201", "teacher_code": "T13", "teacher_name": "Teacher-13"}, {"day": "Friday", "room": "RAB-309", "batch": "67", "section": "B", "subject": "EEE-1221", "semester": 3, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 55, "version_key": 3, "subject_code": "EEE-1221", "teacher_code": "T77", "teacher_name": "Teacher-77"}, {"day": "Friday", "room": "RAB-304", "batch": "63", "section": "D", "subject": "CSE-4161", "semester": 7, "time_end": "12:15:00", "is_active": true, "is_service": false, "time_start": "23:10:00", "fixture_row": 56, "version_key": 3, "subject_code": "CSE-4161", "teacher_code": "T48", "teacher_name": "Teacher-48"}, {"day": "Friday", "room": "RAB-302", "batch": "63", "section": "E", "subject": "CSE-3231", "semester": 7, "time_end": "12:15:00", "is_active": true, "is_service": false, "time_start": "23:10:00", "fixture_row": 57, "version_key": 3, "subject_code": "CSE-3231", "teacher_code": "T25", "teacher_name": "Teacher-25"}, {"day": "Friday", "room": "ACL-3", "batch": "64", "section": "C", "subject": "CSE-3212", "semester": 6, "time_end": "12:15:00", "is_active": true, "is_service": false, "time_start": "23:10:00", "fixture_row": 58, "version_key": 3, "subject_code": "CSE-3212", "teacher_code": "T52", "teacher_name": "Teacher-52"}, {"day": "Friday", "room": "RKB-103", "batch": "65", "section": "A", "subject": "GED-1261", "semester": 5, "time_end": "12:15:00", "is_active": true, "is_service": false, "time_start": "23:10:00", "fixture_row": 59, "version_key": 3, "subject_code": "GED-1261", "teacher_code": "T19", "teacher_name": "Teacher-19"}, {"day": "Friday", "room": "RAB-401", "batch": "65", "section": "C", "subject": "CSE-2101", "semester": 5, "time_end": "12:15:00", "is_active": true, "is_service": false, "time_start": "23:10:00", "fixture_row": 60, "version_key": 3, "subject_code": "CSE-2101", "teacher_code": "T59", "teacher_name": "Teacher-59"}, {"day": "Friday", "room": "RAB-306", "batch": "66", "section": "C", "subject": "EEE-1221", "semester": 4, "time_end": "12:15:00", "is_active": true, "is_service": false, "time_start": "23:10:00", "fixture_row": 61, "version_key": 3, "subject_code": "EEE-1221", "teacher_code": "T77", "teacher_name": "Teacher-77"}, {"day": "Friday", "room": "ACL-1", "batch": "66", "section": "E", "subject": "CSE-2212", "semester": 4, "time_end": "12:15:00", "is_active": true, "is_service": false, "time_start": "23:10:00", "fixture_row": 62, "version_key": 3, "subject_code": "CSE-2212", "teacher_code": "T51", "teacher_name": "Teacher-51"}, {"day": "Friday", "room": "ACL-4", "batch": "66", "section": "H", "subject": "CSE-2212", "semester": 4, "time_end": "12:15:00", "is_active": true, "is_service": false, "time_start": "23:10:00", "fixture_row": 63, "version_key": 3, "subject_code": "CSE-2212", "teacher_code": "T22", "teacher_name": "Teacher-22"}, {"day": "Friday", "room": "ACL-2", "batch": "67", "section": "A", "subject": "CSE-2112", "semester": 3, "time_end": "12:15:00", "is_active": true, "is_service": false, "time_start": "23:10:00", "fixture_row": 64, "version_key": 3, "subject_code": "CSE-2112", "teacher_code": "T70", "teacher_name": "Teacher-70"}, {"day": "Friday", "room": "G2", "batch": "67", "section": "F+G", "subject": "CSE-2231", "semester": 3, "time_end": "12:15:00", "is_active": true, "is_service": false, "time_start": "23:10:00", "fixture_row": 65, "version_key": 3, "subject_code": "CSE-2231", "teacher_code": "T30", "teacher_name": "Teacher-30"}, {"day": "Monday", "room": "RKB-106", "batch": "61", "section": "C", "subject": "CSE-4135", "semester": 8, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 66, "version_key": 3, "subject_code": "CSE-4135", "teacher_code": "T61", "teacher_name": "Teacher-61"}, {"day": "Monday", "room": "NL", "batch": "62", "section": "A", "subject": "Operating System Sessional", "semester": 8, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 67, "version_key": 3, "subject_code": "CSE-4212", "teacher_code": "T63", "teacher_name": "Teacher-63"}, {"day": "Monday", "room": "ACL-2", "batch": "62", "section": "G", "subject": "CSE-4116", "semester": 8, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 68, "version_key": 3, "subject_code": "CSE-4116", "teacher_code": "T35", "teacher_name": "Teacher-35"}, {"day": "Monday", "room": "RAB-401", "batch": "63", "section": "C", "subject": "MAT-2251", "semester": 7, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 69, "version_key": 3, "subject_code": "MAT-2251", "teacher_code": "T71", "teacher_name": "Teacher-71"}, {"day": "Monday", "room": "RAB-304", "batch": "63", "section": "D", "subject": "Research Methodology", "semester": 7, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 70, "version_key": 3, "subject_code": "GED-3213", "teacher_code": "T57", "teacher_name": "Teacher-57"}, {"day": "Monday", "room": "RAB-309", "batch": "64", "section": "D", "subject": "CSE-3213", "semester": 6, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 71, "version_key": 3, "subject_code": "CSE-3213", "teacher_code": "T51", "teacher_name": "Teacher-51"}, {"day": "Monday", "room": "RKB-407", "batch": "64", "section": "G", "subject": "GED-1291", "semester": 6, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 72, "version_key": 3, "subject_code": "GED-1291", "teacher_code": "T39", "teacher_name": "Teacher-39"}, {"day": "Monday", "room": "RAB-111", "batch": "64", "section": "H", "subject": "CSE-2231", "semester": 6, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 73, "version_key": 3, "subject_code": "CSE-2231", "teacher_code": "T16", "teacher_name": "Teacher-16"}, {"day": "Monday", "room": "RAB-112", "batch": "65", "section": "E+F", "subject": "GED-1261", "semester": 5, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 74, "version_key": 3, "subject_code": "GED-1261", "teacher_code": "T62", "teacher_name": "Teacher-62"}, {"day": "Monday", "room": "ACL-3", "batch": "67", "section": "A", "subject": "GED-1262", "semester": 3, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 75, "version_key": 3, "subject_code": "GED-1262", "teacher_code": "T50", "teacher_name": "Teacher-50"}, {"day": "Monday", "room": "RAB-306", "batch": "67", "section": "D", "subject": "CSE-2111", "semester": 3, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 76, "version_key": 3, "subject_code": "CSE-2111", "teacher_code": "T4", "teacher_name": "Teacher-4"}, {"day": "Monday", "room": "RAB-302", "batch": "67", "section": "E", "subject": "CSE-2111", "semester": 3, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 77, "version_key": 3, "subject_code": "CSE-2111", "teacher_code": "T6", "teacher_name": "Teacher-6"}, {"day": "Monday", "room": "ACL-1", "batch": "67", "section": "F+G", "subject": "GED-1262", "semester": 3, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 78, "version_key": 3, "subject_code": "GED-1262", "teacher_code": "T80", "teacher_name": "Teacher-80"}, {"day": "Monday", "room": "RKB-303", "batch": "68", "section": "A", "subject": "GED-2181", "semester": 2, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 79, "version_key": 3, "subject_code": "GED-2181", "teacher_code": "T75", "teacher_name": "Teacher-75"}, {"day": "Monday", "room": "RKB-402", "batch": "68", "section": "C", "subject": "CHE-1161", "semester": 2, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 80, "version_key": 3, "subject_code": "CHE-1161", "teacher_code": "T2", "teacher_name": "Teacher-2"}, {"day": "Monday", "room": "RKB-403", "batch": "68", "section": "D", "subject": "GED-1201", "semester": 2, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 81, "version_key": 3, "subject_code": "GED-1201", "teacher_code": "T13", "teacher_name": "Teacher-13"}, {"day": "Monday", "room": "RKB-404", "batch": "68", "section": "F", "subject": "GED-1231", "semester": 2, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 82, "version_key": 3, "subject_code": "GED-1231", "teacher_code": "T11", "teacher_name": "Teacher-11"}, {"day": "Monday", "room": "ACL-4", "batch": "69", "section": "A", "subject": "CSE-1102", "semester": 1, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 83, "version_key": 3, "subject_code": "CSE-1102", "teacher_code": "T20", "teacher_name": "Teacher-20"}, {"day": "Monday", "room": "G2", "batch": "69", "section": "D", "subject": "GED-1131", "semester": 1, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 84, "version_key": 3, "subject_code": "GED-1131", "teacher_code": "T14", "teacher_name": "Teacher-14"}, {"day": "Monday", "room": "RKB-103", "batch": "69", "section": "E", "subject": "CSE-1151", "semester": 1, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 85, "version_key": 3, "subject_code": "CSE-1151", "teacher_code": "T83", "teacher_name": "Teacher-83"}, {"day": "Monday", "room": "NL", "batch": "61", "section": "C", "subject": "CSE-4268", "semester": 8, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 86, "version_key": 3, "subject_code": "CSE-4268", "teacher_code": "T8", "teacher_name": "Teacher-8"}, {"day": "Monday", "room": "RKB-403", "batch": "62", "section": "A", "subject": "Operating System", "semester": 8, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 87, "version_key": 3, "subject_code": "CSE-4211", "teacher_code": "T63", "teacher_name": "Teacher-63"}, {"day": "Monday", "room": "ACL-2", "batch": "62", "section": "G", "subject": "CSE-4161", "semester": 8, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 88, "version_key": 3, "subject_code": "CSE-4161", "teacher_code": "T79", "teacher_name": "Teacher-79"}, {"day": "Monday", "room": "RAB-401", "batch": "63", "section": "C", "subject": "Research Methodology", "semester": 7, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 89, "version_key": 3, "subject_code": "GED-3213", "teacher_code": "T27", "teacher_name": "Teacher-27"}, {"day": "Monday", "room": "RKB-407", "batch": "64", "section": "D", "subject": "CSE-2231", "semester": 6, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 90, "version_key": 3, "subject_code": "CSE-2231", "teacher_code": "T59", "teacher_name": "Teacher-59"}, {"day": "Monday", "room": "RAB-306", "batch": "64", "section": "G", "subject": "CSE-3213", "semester": 6, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 91, "version_key": 3, "subject_code": "CSE-3213", "teacher_code": "T67", "teacher_name": "Teacher-67"}, {"day": "Monday", "room": "RAB-309", "batch": "64", "section": "H", "subject": "CSE-3115", "semester": 6, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 92, "version_key": 3, "subject_code": "CSE-3115", "teacher_code": "T55", "teacher_name": "Teacher-55"}, {"day": "Monday", "room": "RAB-111", "batch": "65", "section": "E+F", "subject": "CSE-3121", "semester": 5, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 93, "version_key": 3, "subject_code": "CSE-3121", "teacher_code": "T16", "teacher_name": "Teacher-16"}, {"day": "Monday", "room": "ACL-3", "batch": "67", "section": "D", "subject": "CSE-2112", "semester": 3, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 94, "version_key": 3, "subject_code": "CSE-2112", "teacher_code": "T4", "teacher_name": "Teacher-4"}, {"day": "Monday", "room": "ACL-1", "batch": "67", "section": "E", "subject": "CSE-2112", "semester": 3, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 95, "version_key": 3, "subject_code": "CSE-2112", "teacher_code": "T6", "teacher_name": "Teacher-6"}, {"day": "Monday", "room": "RAB-304", "batch": "67", "section": "F+G", "subject": "PHY-1171", "semester": 3, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 96, "version_key": 3, "subject_code": "PHY-1171", "teacher_code": "T46", "teacher_name": "Teacher-46"}, {"day": "Monday", "room": "RKB-103", "batch": "68", "section": "A", "subject": "GED-1231", "semester": 2, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 97, "version_key": 3, "subject_code": "GED-1231", "teacher_code": "T11", "teacher_name": "Teacher-11"}, {"day": "Monday", "room": "RKB-303", "batch": "68", "section": "C", "subject": "MAT-1251", "semester": 2, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 98, "version_key": 3, "subject_code": "MAT-1251", "teacher_code": "T45", "teacher_name": "Teacher-45"}, {"day": "Monday", "room": "RKB-402", "batch": "68", "section": "D", "subject": "CHE-1161", "semester": 2, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 99, "version_key": 3, "subject_code": "CHE-1161", "teacher_code": "T2", "teacher_name": "Teacher-2"}, {"day": "Monday", "room": "RKB-404", "batch": "68", "section": "F", "subject": "CHE-1161", "semester": 2, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 100, "version_key": 3, "subject_code": "CHE-1161", "teacher_code": "T44", "teacher_name": "Teacher-44"}, {"day": "Monday", "room": "RAB-302", "batch": "69", "section": "A", "subject": "MAT-1151", "semester": 1, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 101, "version_key": 3, "subject_code": "MAT-1151", "teacher_code": "T56", "teacher_name": "Teacher-56"}, {"day": "Monday", "room": "G2", "batch": "69", "section": "B", "subject": "CSE-1151", "semester": 1, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 102, "version_key": 3, "subject_code": "CSE-1151", "teacher_code": "T21", "teacher_name": "Teacher-21"}, {"day": "Monday", "room": "ACL-4", "batch": "69", "section": "E", "subject": "CSE-1102", "semester": 1, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 103, "version_key": 3, "subject_code": "CSE-1102", "teacher_code": "T37", "teacher_name": "Teacher-37"}, {"day": "Monday", "room": "RKB-106", "batch": "61", "section": "A", "subject": "CSE-4135", "semester": 8, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 104, "version_key": 3, "subject_code": "CSE-4135", "teacher_code": "T49", "teacher_name": "Teacher-49"}, {"day": "Monday", "room": "NL", "batch": "61", "section": "C", "subject": "CSE-4203", "semester": 8, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 105, "version_key": 3, "subject_code": "CSE-4203", "teacher_code": "T76", "teacher_name": "Teacher-76"}, {"day": "Monday", "room": "RKB-403", "batch": "62", "section": "A", "subject": "CSE-4161", "semester": 8, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 106, "version_key": 3, "subject_code": "CSE-4161", "teacher_code": "T1", "teacher_name": "Teacher-1"}, {"day": "Monday", "room": "ACL-2", "batch": "62", "section": "G", "subject": "Operating System Sessional", "semester": 8, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 107, "version_key": 3, "subject_code": "CSE-4212", "teacher_code": "T59", "teacher_name": "Teacher-59"}, {"day": "Monday", "room": "RAB-306", "batch": "63", "section": "C", "subject": "CSE-4161", "semester": 7, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 108, "version_key": 3, "subject_code": "CSE-4161", "teacher_code": "T4", "teacher_name": "Teacher-4"}, {"day": "Monday", "room": "RAB-309", "batch": "63", "section": "D", "subject": "GED-1116", "semester": 7, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 109, "version_key": 3, "subject_code": "GED-1116", "teacher_code": "T7", "teacher_name": "Teacher-7"}, {"day": "Monday", "room": "ACL-3", "batch": "64", "section": "D", "subject": "CSE-3212", "semester": 6, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 110, "version_key": 3, "subject_code": "CSE-3212", "teacher_code": "T21", "teacher_name": "Teacher-21"}, {"day": "Monday", "room": "ACL-4", "batch": "64", "section": "G", "subject": "CSE-3214", "semester": 6, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 111, "version_key": 3, "subject_code": "CSE-3214", "teacher_code": "T67", "teacher_name": "Teacher-67"}, {"day": "Monday", "room": "ACL-1", "batch": "64", "section": "H", "subject": "CSE-3116", "semester": 6, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 112, "version_key": 3, "subject_code": "CSE-3116", "teacher_code": "T55", "teacher_name": "Teacher-55"}, {"day": "Monday", "room": "RKB-404", "batch": "67", "section": "A", "subject": "CSE-2231", "semester": 3, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 113, "version_key": 3, "subject_code": "CSE-2231", "teacher_code": "T68", "teacher_name": "Teacher-68"}, {"day": "Monday", "room": "RAB-304", "batch": "67", "section": "D", "subject": "MAT-2151", "semester": 3, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 114, "version_key": 3, "subject_code": "MAT-2151", "teacher_code": "T32", "teacher_name": "Teacher-32"}, {"day": "Monday", "room": "KCM LAB", "batch": "67", "section": "F+G", "subject": "PHY-1272", "semester": 3, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 115, "version_key": 3, "subject_code": "PHY-1272", "teacher_code": "T43", "teacher_name": "Teacher-43"}, {"day": "Monday", "room": "RKB-303", "batch": "68", "section": "D", "subject": "MAT-1251", "semester": 2, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 116, "version_key": 3, "subject_code": "MAT-1251", "teacher_code": "T45", "teacher_name": "Teacher-45"}, {"day": "Monday", "room": "RKB-402", "batch": "68", "section": "E", "subject": "CHE-1161", "semester": 2, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 117, "version_key": 3, "subject_code": "CHE-1161", "teacher_code": "T44", "teacher_name": "Teacher-44"}, {"day": "Monday", "room": "G2", "batch": "69", "section": "A", "subject": "GED-1131", "semester": 1, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 118, "version_key": 3, "subject_code": "GED-1131", "teacher_code": "T14", "teacher_name": "Teacher-14"}, {"day": "Monday", "room": "RAB-302", "batch": "69", "section": "B", "subject": "MAT-1151", "semester": 1, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 119, "version_key": 3, "subject_code": "MAT-1151", "teacher_code": "T56", "teacher_name": "Teacher-56"}, {"day": "Monday", "room": "RAB-401", "batch": "69", "section": "D", "subject": "MAT-1151", "semester": 1, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 120, "version_key": 3, "subject_code": "MAT-1151", "teacher_code": "T69", "teacher_name": "Teacher-69"}, {"day": "Monday", "room": "RAB-111", "batch": "69", "section": "E", "subject": "CSE-1101", "semester": 1, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 121, "version_key": 3, "subject_code": "CSE-1101", "teacher_code": "T30", "teacher_name": "Teacher-30"}, {"day": "Monday", "room": "RKB-103", "batch": "69", "section": "H", "subject": "CSE-1151", "semester": 1, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 122, "version_key": 3, "subject_code": "CSE-1151", "teacher_code": "T83", "teacher_name": "Teacher-83"}, {"day": "Monday", "room": "RKB-403", "batch": "61", "section": "A", "subject": "CSE-4203", "semester": 8, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 123, "version_key": 3, "subject_code": "CSE-4203", "teacher_code": "T12", "teacher_name": "Teacher-12"}, {"day": "Monday", "room": "NL", "batch": "61", "section": "E", "subject": "CSE-4268", "semester": 8, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 124, "version_key": 3, "subject_code": "CSE-4268", "teacher_code": "T55", "teacher_name": "Teacher-55"}, {"day": "Monday", "room": "RKB-106", "batch": "62", "section": "G", "subject": "Operating System", "semester": 8, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 125, "version_key": 3, "subject_code": "CSE-4211", "teacher_code": "T30", "teacher_name": "Teacher-30"}, {"day": "Monday", "room": "ACL-1", "batch": "63", "section": "C", "subject": "CSE-3232", "semester": 7, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 126, "version_key": 3, "subject_code": "CSE-3232", "teacher_code": "T34", "teacher_name": "Teacher-34"}, {"day": "Monday", "room": "RAB-304", "batch": "64", "section": "C", "subject": "CSE-3213", "semester": 6, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 127, "version_key": 3, "subject_code": "CSE-3213", "teacher_code": "T6", "teacher_name": "Teacher-6"}, {"day": "Monday", "room": "ACL-4", "batch": "64", "section": "D", "subject": "CSE-3214", "semester": 6, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 128, "version_key": 3, "subject_code": "CSE-3214", "teacher_code": "T8", "teacher_name": "Teacher-8"}, {"day": "Monday", "room": "RKB-402", "batch": "64", "section": "H", "subject": "GED-1291", "semester": 6, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 129, "version_key": 3, "subject_code": "GED-1291", "teacher_code": "T39", "teacher_name": "Teacher-39"}, {"day": "Monday", "room": "ACL-3", "batch": "64", "section": "I", "subject": "CSE-3214", "semester": 6, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 130, "version_key": 3, "subject_code": "CSE-3214", "teacher_code": "T67", "teacher_name": "Teacher-67"}, {"day": "Monday", "room": "RAB-306", "batch": "65", "section": "B", "subject": "CSE-3111", "semester": 5, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 131, "version_key": 3, "subject_code": "CSE-3111", "teacher_code": "T29", "teacher_name": "Teacher-29"}, {"day": "Monday", "room": "RKB-303", "batch": "65", "section": "E+F", "subject": "CSE-2101", "semester": 5, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 132, "version_key": 3, "subject_code": "CSE-2101", "teacher_code": "T79", "teacher_name": "Teacher-79"}, {"day": "Monday", "room": "RKB-103", "batch": "66", "section": "G", "subject": "EEE-1221", "semester": 4, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 133, "version_key": 3, "subject_code": "EEE-1221", "teacher_code": "T74", "teacher_name": "Teacher-74"}, {"day": "Monday", "room": "RAB-302", "batch": "67", "section": "A", "subject": "MAT-2151", "semester": 3, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 134, "version_key": 3, "subject_code": "MAT-2151", "teacher_code": "T32", "teacher_name": "Teacher-32"}, {"day": "Monday", "room": "RAB-202", "batch": "67", "section": "B", "subject": "PHY-1171", "semester": 3, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 135, "version_key": 3, "subject_code": "PHY-1171", "teacher_code": "T43", "teacher_name": "Teacher-43"}, {"day": "Monday", "room": "RAB-401", "batch": "67", "section": "C", "subject": "PHY-1171", "semester": 3, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 136, "version_key": 3, "subject_code": "PHY-1171", "teacher_code": "T46", "teacher_name": "Teacher-46"}, {"day": "Monday", "room": "RAB-111", "batch": "67", "section": "E", "subject": "CSE-2231", "semester": 3, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 137, "version_key": 3, "subject_code": "CSE-2231", "teacher_code": "T81", "teacher_name": "Teacher-81"}, {"day": "Monday", "room": "PHY LAB", "batch": "67", "section": "F+G", "subject": "PHY-1272", "semester": 3, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 138, "version_key": 3, "subject_code": "PHY-1272", "teacher_code": "T31", "teacher_name": "Teacher-31"}, {"day": "Monday", "room": "RKB-407", "batch": "68", "section": "B", "subject": "CHE-1161", "semester": 2, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 139, "version_key": 3, "subject_code": "CHE-1161", "teacher_code": "T2", "teacher_name": "Teacher-2"}, {"day": "Monday", "room": "RAB-309", "batch": "68", "section": "F", "subject": "GED-1201", "semester": 2, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 140, "version_key": 3, "subject_code": "GED-1201", "teacher_code": "T13", "teacher_name": "Teacher-13"}, {"day": "Monday", "room": "G2", "batch": "69", "section": "B", "subject": "GED-1131", "semester": 1, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 141, "version_key": 3, "subject_code": "GED-1131", "teacher_code": "T14", "teacher_name": "Teacher-14"}, {"day": "Monday", "room": "RKB-404", "batch": "69", "section": "H", "subject": "MAT-1151", "semester": 1, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 142, "version_key": 3, "subject_code": "MAT-1151", "teacher_code": "T36", "teacher_name": "Teacher-36"}, {"day": "Monday", "room": "ACL-2", "batch": "61", "section": "A", "subject": "CSE-4268", "semester": 8, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 143, "version_key": 3, "subject_code": "CSE-4268", "teacher_code": "T66", "teacher_name": "Teacher-66"}, {"day": "Monday", "room": "NL", "batch": "61", "section": "B", "subject": "CSE-4203", "semester": 8, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 144, "version_key": 3, "subject_code": "CSE-4203", "teacher_code": "T12", "teacher_name": "Teacher-12"}, {"day": "Monday", "room": "RKB-403", "batch": "61", "section": "D", "subject": "CSE-4267", "semester": 8, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 145, "version_key": 3, "subject_code": "CSE-4267", "teacher_code": "T4", "teacher_name": "Teacher-4"}, {"day": "Monday", "room": "RKB-106", "batch": "62", "section": "H", "subject": "CSE-4161", "semester": 8, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 146, "version_key": 3, "subject_code": "CSE-4161", "teacher_code": "T79", "teacher_name": "Teacher-79"}, {"day": "Monday", "room": "RAB-309", "batch": "64", "section": "C", "subject": "CSE-3115", "semester": 6, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 147, "version_key": 3, "subject_code": "CSE-3115", "teacher_code": "T55", "teacher_name": "Teacher-55"}, {"day": "Monday", "room": "RKB-303", "batch": "64", "section": "I", "subject": "GED-1291", "semester": 6, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 148, "version_key": 3, "subject_code": "GED-1291", "teacher_code": "T39", "teacher_name": "Teacher-39"}, {"day": "Monday", "room": "ACL-1", "batch": "65", "section": "B", "subject": "CSE-3112", "semester": 5, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 149, "version_key": 3, "subject_code": "CSE-3112", "teacher_code": "T29", "teacher_name": "Teacher-29"}, {"day": "Monday", "room": "ACL-3", "batch": "65", "section": "C", "subject": "CSE-3112", "semester": 5, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 150, "version_key": 3, "subject_code": "CSE-3112", "teacher_code": "T27", "teacher_name": "Teacher-27"}, {"day": "Monday", "room": "RKB-103", "batch": "66", "section": "B", "subject": "CSE-2101", "semester": 4, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 151, "version_key": 3, "subject_code": "CSE-2101", "teacher_code": "T76", "teacher_name": "Teacher-76"}, {"day": "Monday", "room": "RKB-407", "batch": "66", "section": "C", "subject": "MAT-2251", "semester": 4, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 152, "version_key": 3, "subject_code": "MAT-2251", "teacher_code": "T71", "teacher_name": "Teacher-71"}, {"day": "Monday", "room": "ACL-4", "batch": "66", "section": "G", "subject": "CSE-2212", "semester": 4, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 153, "version_key": 3, "subject_code": "CSE-2212", "teacher_code": "T51", "teacher_name": "Teacher-51"}, {"day": "Monday", "room": "ECL-1", "batch": "66", "section": "H", "subject": "EEE-1222", "semester": 4, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 154, "version_key": 3, "subject_code": "EEE-1222", "teacher_code": "T74", "teacher_name": "Teacher-74"}, {"day": "Monday", "room": "RAB-202", "batch": "67", "section": "A", "subject": "PHY-1171", "semester": 3, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 155, "version_key": 3, "subject_code": "PHY-1171", "teacher_code": "T43", "teacher_name": "Teacher-43"}, {"day": "Monday", "room": "RAB-306", "batch": "67", "section": "B", "subject": "CSE-2111", "semester": 3, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 156, "version_key": 3, "subject_code": "CSE-2111", "teacher_code": "T70", "teacher_name": "Teacher-70"}, {"day": "Monday", "room": "PHY LAB", "batch": "67", "section": "C", "subject": "PHY-1272", "semester": 3, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 157, "version_key": 3, "subject_code": "PHY-1272", "teacher_code": "T46", "teacher_name": "Teacher-46"}, {"day": "Monday", "room": "RAB-302", "batch": "68", "section": "B", "subject": "MAT-1251", "semester": 2, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 158, "version_key": 3, "subject_code": "MAT-1251", "teacher_code": "T56", "teacher_name": "Teacher-56"}, {"day": "Monday", "room": "RAB-304", "batch": "68", "section": "E", "subject": "CSE-1211", "semester": 2, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 159, "version_key": 3, "subject_code": "CSE-1211", "teacher_code": "T57", "teacher_name": "Teacher-57"}, {"day": "Monday", "room": "G2", "batch": "69", "section": "A", "subject": "CSE-1151", "semester": 1, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 160, "version_key": 3, "subject_code": "CSE-1151", "teacher_code": "T21", "teacher_name": "Teacher-21"}, {"day": "Monday", "room": "RAB-111", "batch": "69", "section": "C", "subject": "GED-1131", "semester": 1, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 161, "version_key": 3, "subject_code": "GED-1131", "teacher_code": "T14", "teacher_name": "Teacher-14"}, {"day": "Monday", "room": "RKB-402", "batch": "69", "section": "E", "subject": "MAT-1151", "semester": 1, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 162, "version_key": 3, "subject_code": "MAT-1151", "teacher_code": "T69", "teacher_name": "Teacher-69"}, {"day": "Monday", "room": "RAB-401", "batch": "69", "section": "F", "subject": "CSE-1151", "semester": 1, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 163, "version_key": 3, "subject_code": "CSE-1151", "teacher_code": "T83", "teacher_name": "Teacher-83"}, {"day": "Monday", "room": "RKB-404", "batch": "69", "section": "I", "subject": "MAT-1151", "semester": 1, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 164, "version_key": 3, "subject_code": "MAT-1151", "teacher_code": "T36", "teacher_name": "Teacher-36"}, {"day": "Monday", "room": "ACL-2", "batch": "61", "section": "B", "subject": "CSE-4268", "semester": 8, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 165, "version_key": 3, "subject_code": "CSE-4268", "teacher_code": "T66", "teacher_name": "Teacher-66"}, {"day": "Monday", "room": "RKB-403", "batch": "61", "section": "D", "subject": "CSE-4267", "semester": 8, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 166, "version_key": 3, "subject_code": "CSE-4267", "teacher_code": "T4", "teacher_name": "Teacher-4"}, {"day": "Monday", "room": "RKB-106", "batch": "61", "section": "E", "subject": "CSE-4267", "semester": 8, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 167, "version_key": 3, "subject_code": "CSE-4267", "teacher_code": "T8", "teacher_name": "Teacher-8"}, {"day": "Monday", "room": "RAB-306", "batch": "63", "section": "B", "subject": "CSE-3231", "semester": 7, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 168, "version_key": 3, "subject_code": "CSE-3231", "teacher_code": "T34", "teacher_name": "Teacher-34"}, {"day": "Monday", "room": "ACL-1", "batch": "64", "section": "C", "subject": "CSE-3116", "semester": 6, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 169, "version_key": 3, "subject_code": "CSE-3116", "teacher_code": "T55", "teacher_name": "Teacher-55"}, {"day": "Monday", "room": "RKB-407", "batch": "64", "section": "I", "subject": "CSE-2231", "semester": 6, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 170, "version_key": 3, "subject_code": "CSE-2231", "teacher_code": "T16", "teacher_name": "Teacher-16"}, {"day": "Monday", "room": "RKB-404", "batch": "65", "section": "C", "subject": "CSE-3111", "semester": 5, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 171, "version_key": 3, "subject_code": "CSE-3111", "teacher_code": "T27", "teacher_name": "Teacher-27"}, {"day": "Monday", "room": "RAB-302", "batch": "66", "section": "B", "subject": "MAT-2251", "semester": 4, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 172, "version_key": 3, "subject_code": "MAT-2251", "teacher_code": "T71", "teacher_name": "Teacher-71"}, {"day": "Monday", "room": "RKB-402", "batch": "66", "section": "C", "subject": "CSE-2101", "semester": 4, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 173, "version_key": 3, "subject_code": "CSE-2101", "teacher_code": "T76", "teacher_name": "Teacher-76"}, {"day": "Monday", "room": "RAB-304", "batch": "66", "section": "G", "subject": "CSE-2211", "semester": 4, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 174, "version_key": 3, "subject_code": "CSE-2211", "teacher_code": "T51", "teacher_name": "Teacher-51"}, {"day": "Monday", "room": "RAB-111", "batch": "66", "section": "H", "subject": "EEE-1221", "semester": 4, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 175, "version_key": 3, "subject_code": "EEE-1221", "teacher_code": "T47", "teacher_name": "Teacher-47"}, {"day": "Monday", "room": "ACL-3", "batch": "67", "section": "B", "subject": "CSE-2112", "semester": 3, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 176, "version_key": 3, "subject_code": "CSE-2112", "teacher_code": "T70", "teacher_name": "Teacher-70"}, {"day": "Monday", "room": "PHY LAB", "batch": "67", "section": "C", "subject": "PHY-1272", "semester": 3, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 177, "version_key": 3, "subject_code": "PHY-1272", "teacher_code": "T46", "teacher_name": "Teacher-46"}, {"day": "Monday", "room": "RKB-303", "batch": "68", "section": "B", "subject": "GED-1231", "semester": 2, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 178, "version_key": 3, "subject_code": "GED-1231", "teacher_code": "T11", "teacher_name": "Teacher-11"}, {"day": "Monday", "room": "ACL-4", "batch": "68", "section": "E", "subject": "CSE-1212", "semester": 2, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 179, "version_key": 3, "subject_code": "CSE-1212", "teacher_code": "T57", "teacher_name": "Teacher-57"}, {"day": "Monday", "room": "RAB-309", "batch": "69", "section": "C", "subject": "CSE-1101", "semester": 1, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 180, "version_key": 3, "subject_code": "CSE-1101", "teacher_code": "T81", "teacher_name": "Teacher-81"}, {"day": "Monday", "room": "G2", "batch": "69", "section": "F", "subject": "MAT-1151", "semester": 1, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 181, "version_key": 3, "subject_code": "MAT-1151", "teacher_code": "T69", "teacher_name": "Teacher-69"}, {"day": "Monday", "room": "RAB-401", "batch": "69", "section": "G", "subject": "CSE-1151", "semester": 1, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 182, "version_key": 3, "subject_code": "CSE-1151", "teacher_code": "T83", "teacher_name": "Teacher-83"}, {"day": "Monday", "room": "RAB-311", "batch": "69", "section": "I", "subject": "GED-1131", "semester": 1, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 183, "version_key": 3, "subject_code": "GED-1131", "teacher_code": "T28", "teacher_name": "Teacher-28"}, {"day": "Monday", "room": "RKB-403", "batch": "61", "section": "D", "subject": "CSE-4203", "semester": 8, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 184, "version_key": 3, "subject_code": "CSE-4203", "teacher_code": "T76", "teacher_name": "Teacher-76"}, {"day": "Monday", "room": "RKB-106", "batch": "61", "section": "E", "subject": "CSE-4267", "semester": 8, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 185, "version_key": 3, "subject_code": "CSE-4267", "teacher_code": "T8", "teacher_name": "Teacher-8"}, {"day": "Monday", "room": "NL", "batch": "62", "section": "H", "subject": "CSE-4116", "semester": 8, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 186, "version_key": 3, "subject_code": "CSE-4116", "teacher_code": "T16", "teacher_name": "Teacher-16"}, {"day": "Monday", "room": "RAB-302", "batch": "63", "section": "B", "subject": "MAT-2251", "semester": 7, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 187, "version_key": 3, "subject_code": "MAT-2251", "teacher_code": "T71", "teacher_name": "Teacher-71"}, {"day": "Monday", "room": "ACL-1", "batch": "64", "section": "C", "subject": "CSE-3214", "semester": 6, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 188, "version_key": 3, "subject_code": "CSE-3214", "teacher_code": "T6", "teacher_name": "Teacher-6"}, {"day": "Monday", "room": "RKB-303", "batch": "65", "section": "B", "subject": "CSE-3121", "semester": 5, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 189, "version_key": 3, "subject_code": "CSE-3121", "teacher_code": "T12", "teacher_name": "Teacher-12"}, {"day": "Monday", "room": "RKB-402", "batch": "65", "section": "C", "subject": "CSE-2101", "semester": 5, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 190, "version_key": 3, "subject_code": "CSE-2101", "teacher_code": "T59", "teacher_name": "Teacher-59"}, {"day": "Monday", "room": "RAB-111", "batch": "66", "section": "C", "subject": "GED-1201", "semester": 4, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 191, "version_key": 3, "subject_code": "GED-1201", "teacher_code": "T54", "teacher_name": "Teacher-54"}, {"day": "Monday", "room": "RKB-103", "batch": "66", "section": "G", "subject": "GED-1201", "semester": 4, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 192, "version_key": 3, "subject_code": "GED-1201", "teacher_code": "T13", "teacher_name": "Teacher-13"}, {"day": "Monday", "room": "G2", "batch": "67", "section": "B", "subject": "CSE-2231", "semester": 3, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 193, "version_key": 3, "subject_code": "CSE-2231", "teacher_code": "T24", "teacher_name": "Teacher-24"}, {"day": "Monday", "room": "ACL-4", "batch": "69", "section": "C", "subject": "CSE-1102", "semester": 1, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 194, "version_key": 3, "subject_code": "CSE-1102", "teacher_code": "T20", "teacher_name": "Teacher-20"}, {"day": "Monday", "room": "RAB-306", "batch": "69", "section": "G", "subject": "MAT-1151", "semester": 1, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 195, "version_key": 3, "subject_code": "MAT-1151", "teacher_code": "T69", "teacher_name": "Teacher-69"}, {"day": "Saturday", "room": "RKB-106", "batch": "62", "section": "G", "subject": "Research Methodology", "semester": 8, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 196, "version_key": 3, "subject_code": "GED-3213", "teacher_code": "T61", "teacher_name": "Teacher-61"}, {"day": "Saturday", "room": "ACL-2", "batch": "62", "section": "H", "subject": "CSE-4116", "semester": 8, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 197, "version_key": 3, "subject_code": "CSE-4116", "teacher_code": "T16", "teacher_name": "Teacher-16"}, {"day": "Saturday", "room": "RAB-309", "batch": "62", "section": "I", "subject": "CSE-4161", "semester": 8, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 198, "version_key": 3, "subject_code": "CSE-4161", "teacher_code": "T59", "teacher_name": "Teacher-59"}, {"day": "Saturday", "room": "RAB-306", "batch": "63", "section": "C", "subject": "CSE-3231", "semester": 7, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 199, "version_key": 3, "subject_code": "CSE-3231", "teacher_code": "T25", "teacher_name": "Teacher-25"}, {"day": "Saturday", "room": "RAB-401", "batch": "63", "section": "E", "subject": "CSE-4135", "semester": 7, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 200, "version_key": 3, "subject_code": "CSE-4135", "teacher_code": "T3", "teacher_name": "Teacher-3"}, {"day": "Saturday", "room": "ACL-3", "batch": "64", "section": "C", "subject": "CSE-3212", "semester": 6, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 201, "version_key": 3, "subject_code": "CSE-3212", "teacher_code": "T52", "teacher_name": "Teacher-52"}, {"day": "Saturday", "room": "RKB-407", "batch": "65", "section": "A", "subject": "EEE-2121", "semester": 5, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 202, "version_key": 3, "subject_code": "EEE-2121", "teacher_code": "T23", "teacher_name": "Teacher-23"}, {"day": "Saturday", "room": "RKB-404", "batch": "65", "section": "B", "subject": "MAT-3151", "semester": 5, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 203, "version_key": 3, "subject_code": "MAT-3151", "teacher_code": "T64", "teacher_name": "Teacher-64"}, {"day": "Saturday", "room": "RKB-402", "batch": "66", "section": "E", "subject": "EEE-1221", "semester": 4, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 204, "version_key": 3, "subject_code": "EEE-1221", "teacher_code": "T74", "teacher_name": "Teacher-74"}, {"day": "Saturday", "room": "RKB-303", "batch": "67", "section": "D", "subject": "EEE-1221", "semester": 3, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 205, "version_key": 3, "subject_code": "EEE-1221", "teacher_code": "T82", "teacher_name": "Teacher-82"}, {"day": "Saturday", "room": "RAB-304", "batch": "67", "section": "E", "subject": "CSE-2111", "semester": 3, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 206, "version_key": 3, "subject_code": "CSE-2111", "teacher_code": "T6", "teacher_name": "Teacher-6"}, {"day": "Saturday", "room": "RAB-302", "batch": "68", "section": "D", "subject": "CSE-1211", "semester": 2, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 207, "version_key": 3, "subject_code": "CSE-1211", "teacher_code": "T37", "teacher_name": "Teacher-37"}, {"day": "Saturday", "room": "G2", "batch": "69", "section": "E", "subject": "GED-1131", "semester": 1, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 208, "version_key": 3, "subject_code": "GED-1131", "teacher_code": "T14", "teacher_name": "Teacher-14"}, {"day": "Saturday", "room": "RKB-103", "batch": "69", "section": "J", "subject": "CSE-1151", "semester": 1, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 209, "version_key": 3, "subject_code": "CSE-1151", "teacher_code": "T83", "teacher_name": "Teacher-83"}, {"day": "Saturday", "room": "RKB-106", "batch": "62", "section": "G", "subject": "CSE-4161", "semester": 8, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 210, "version_key": 3, "subject_code": "CSE-4161", "teacher_code": "T79", "teacher_name": "Teacher-79"}, {"day": "Saturday", "room": "ACL-2", "batch": "62", "section": "H", "subject": "CSE-4116", "semester": 8, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 211, "version_key": 3, "subject_code": "CSE-4116", "teacher_code": "T16", "teacher_name": "Teacher-16"}, {"day": "Saturday", "room": "RAB-401", "batch": "63", "section": "C", "subject": "CSE-4135", "semester": 7, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 212, "version_key": 3, "subject_code": "CSE-4135", "teacher_code": "T18", "teacher_name": "Teacher-18"}, {"day": "Saturday", "room": "GL", "batch": "63", "section": "E", "subject": "GED-1116", "semester": 7, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 213, "version_key": 3, "subject_code": "GED-1116", "teacher_code": "T7", "teacher_name": "Teacher-7"}, {"day": "Saturday", "room": "RAB-309", "batch": "64", "section": "C", "subject": "CSE-2231", "semester": 6, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 214, "version_key": 3, "subject_code": "CSE-2231", "teacher_code": "T59", "teacher_name": "Teacher-59"}, {"day": "Saturday", "room": "RAB-306", "batch": "65", "section": "A", "subject": "CSE-2101", "semester": 5, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 215, "version_key": 3, "subject_code": "CSE-2101", "teacher_code": "T15", "teacher_name": "Teacher-15"}, {"day": "Saturday", "room": "RKB-407", "batch": "65", "section": "B", "subject": "EEE-2121", "semester": 5, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 216, "version_key": 3, "subject_code": "EEE-2121", "teacher_code": "T23", "teacher_name": "Teacher-23"}, {"day": "Saturday", "room": "RKB-404", "batch": "66", "section": "A", "subject": "EEE-1221", "semester": 4, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 217, "version_key": 3, "subject_code": "EEE-1221", "teacher_code": "T40", "teacher_name": "Teacher-40"}, {"day": "Saturday", "room": "ECL-1", "batch": "66", "section": "E", "subject": "EEE-1222", "semester": 4, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 218, "version_key": 3, "subject_code": "EEE-1222", "teacher_code": "T74", "teacher_name": "Teacher-74"}, {"day": "Saturday", "room": "RAB-302", "batch": "67", "section": "D", "subject": "CSE-2111", "semester": 3, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 219, "version_key": 3, "subject_code": "CSE-2111", "teacher_code": "T4", "teacher_name": "Teacher-4"}, {"day": "Saturday", "room": "ACL-4", "batch": "67", "section": "E", "subject": "CSE-2112", "semester": 3, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 220, "version_key": 3, "subject_code": "CSE-2112", "teacher_code": "T6", "teacher_name": "Teacher-6"}, {"day": "Saturday", "room": "RKB-402", "batch": "68", "section": "C", "subject": "MAT-1251", "semester": 2, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 221, "version_key": 3, "subject_code": "MAT-1251", "teacher_code": "T45", "teacher_name": "Teacher-45"}, {"day": "Saturday", "room": "ACL-1", "batch": "68", "section": "D", "subject": "CSE-1212", "semester": 2, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 222, "version_key": 3, "subject_code": "CSE-1212", "teacher_code": "T37", "teacher_name": "Teacher-37"}, {"day": "Saturday", "room": "RAB-304", "batch": "68", "section": "E", "subject": "MAT-1251", "semester": 2, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 223, "version_key": 3, "subject_code": "MAT-1251", "teacher_code": "T38", "teacher_name": "Teacher-38"}, {"day": "Saturday", "room": "RKB-103", "batch": "69", "section": "A", "subject": "CSE-1101", "semester": 1, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 224, "version_key": 3, "subject_code": "CSE-1101", "teacher_code": "T81", "teacher_name": "Teacher-81"}, {"day": "Saturday", "room": "RKB-303", "batch": "69", "section": "E", "subject": "CSE-1151", "semester": 1, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 225, "version_key": 3, "subject_code": "CSE-1151", "teacher_code": "T83", "teacher_name": "Teacher-83"}, {"day": "Saturday", "room": "G2", "batch": "69", "section": "J", "subject": "GED-1131", "semester": 1, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 226, "version_key": 3, "subject_code": "GED-1131", "teacher_code": "T28", "teacher_name": "Teacher-28"}, {"day": "Saturday", "room": "RAB-309", "batch": "62", "section": "B", "subject": "Research Methodology", "semester": 8, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 227, "version_key": 3, "subject_code": "GED-3213", "teacher_code": "T42", "teacher_name": "Teacher-42"}, {"day": "Saturday", "room": "RKB-403", "batch": "62", "section": "H", "subject": "Research Methodology", "semester": 8, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 228, "version_key": 3, "subject_code": "GED-3213", "teacher_code": "T61", "teacher_name": "Teacher-61"}, {"day": "Saturday", "room": "RKB-103", "batch": "63", "section": "B", "subject": "CSE-4161", "semester": 7, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 229, "version_key": 3, "subject_code": "CSE-4161", "teacher_code": "T25", "teacher_name": "Teacher-25"}, {"day": "Saturday", "room": "ACL-3", "batch": "64", "section": "C", "subject": "CSE-3214", "semester": 6, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 230, "version_key": 3, "subject_code": "CSE-3214", "teacher_code": "T6", "teacher_name": "Teacher-6"}, {"day": "Saturday", "room": "RKB-402", "batch": "65", "section": "D", "subject": "CSE-2101", "semester": 5, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 231, "version_key": 3, "subject_code": "CSE-2101", "teacher_code": "T79", "teacher_name": "Teacher-79"}, {"day": "Saturday", "room": "ECL-1", "batch": "65", "section": "E+F", "subject": "EEE-2122", "semester": 5, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 232, "version_key": 3, "subject_code": "EEE-2122", "teacher_code": "T47", "teacher_name": "Teacher-47"}, {"day": "Saturday", "room": "RAB-401", "batch": "66", "section": "G", "subject": "EEE-1221", "semester": 4, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 233, "version_key": 3, "subject_code": "EEE-1221", "teacher_code": "T74", "teacher_name": "Teacher-74"}, {"day": "Saturday", "room": "RAB-306", "batch": "67", "section": "C", "subject": "CSE-2111", "semester": 3, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 234, "version_key": 3, "subject_code": "CSE-2111", "teacher_code": "T4", "teacher_name": "Teacher-4"}, {"day": "Saturday", "room": "ACL-1", "batch": "68", "section": "C", "subject": "CSE-1212", "semester": 2, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 235, "version_key": 3, "subject_code": "CSE-1212", "teacher_code": "T34", "teacher_name": "Teacher-34"}, {"day": "Saturday", "room": "G2", "batch": "68", "section": "E", "subject": "GED-2181", "semester": 2, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 236, "version_key": 3, "subject_code": "GED-2181", "teacher_code": "T75", "teacher_name": "Teacher-75"}, {"day": "Saturday", "room": "RKB-303", "batch": "68", "section": "F", "subject": "CHE-1161", "semester": 2, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 237, "version_key": 3, "subject_code": "CHE-1161", "teacher_code": "T44", "teacher_name": "Teacher-44"}, {"day": "Saturday", "room": "RAB-302", "batch": "69", "section": "A", "subject": "GED-1131", "semester": 1, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 238, "version_key": 3, "subject_code": "GED-1131", "teacher_code": "T14", "teacher_name": "Teacher-14"}, {"day": "Saturday", "room": "ACL-4", "batch": "69", "section": "B", "subject": "CSE-1102", "semester": 1, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 239, "version_key": 3, "subject_code": "CSE-1102", "teacher_code": "T20", "teacher_name": "Teacher-20"}, {"day": "Saturday", "room": "RAB- 309", "batch": "M. Sc", "section": "6+7", "subject": "CSE-517", "semester": 1, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 240, "version_key": 3, "subject_code": "CSE-517", "teacher_code": "T55", "teacher_name": "Teacher-55"}, {"day": "Saturday", "room": "RKB-403", "batch": "62", "section": "A", "subject": "Research Methodology", "semester": 8, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 241, "version_key": 3, "subject_code": "GED-3213", "teacher_code": "T64", "teacher_name": "Teacher-64"}, {"day": "Saturday", "room": "RKB-106", "batch": "62", "section": "E", "subject": "CSE-4161", "semester": 8, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 242, "version_key": 3, "subject_code": "CSE-4161", "teacher_code": "T18", "teacher_name": "Teacher-18"}, {"day": "Saturday", "room": "NL", "batch": "62", "section": "H", "subject": "Operating System Sessional", "semester": 8, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 243, "version_key": 3, "subject_code": "CSE-4212", "teacher_code": "T72", "teacher_name": "Teacher-72"}, {"day": "Saturday", "room": "RAB-302", "batch": "63", "section": "A", "subject": "CSE-4161", "semester": 7, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 244, "version_key": 3, "subject_code": "CSE-4161", "teacher_code": "T25", "teacher_name": "Teacher-25"}, {"day": "Saturday", "room": "RKB-407", "batch": "63", "section": "B", "subject": "GED-1116", "semester": 7, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 245, "version_key": 3, "subject_code": "GED-1116", "teacher_code": "T7", "teacher_name": "Teacher-7"}, {"day": "Saturday", "room": "RAB-304", "batch": "63", "section": "D", "subject": "CSE-4161", "semester": 7, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 246, "version_key": 3, "subject_code": "CSE-4161", "teacher_code": "T48", "teacher_name": "Teacher-48"}, {"day": "Saturday", "room": "ACL-3", "batch": "64", "section": "E", "subject": "CSE-3212", "semester": 6, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 247, "version_key": 3, "subject_code": "CSE-3212", "teacher_code": "T52", "teacher_name": "Teacher-52"}, {"day": "Saturday", "room": "RAB-306", "batch": "64", "section": "F", "subject": "CSE-2231", "semester": 6, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 248, "version_key": 3, "subject_code": "CSE-2231", "teacher_code": "T79", "teacher_name": "Teacher-79"}, {"day": "Saturday", "room": "RKB-303", "batch": "65", "section": "C", "subject": "CSE-3121", "semester": 5, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 249, "version_key": 3, "subject_code": "CSE-3121", "teacher_code": "T12", "teacher_name": "Teacher-12"}, {"day": "Saturday", "room": "RKB-402", "batch": "65", "section": "D", "subject": "CSE-3121", "semester": 5, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 250, "version_key": 3, "subject_code": "CSE-3121", "teacher_code": "T16", "teacher_name": "Teacher-16"}, {"day": "Saturday", "room": "RKB-404", "batch": "65", "section": "E+F", "subject": "EEE-2121", "semester": 5, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 251, "version_key": 3, "subject_code": "EEE-2121", "teacher_code": "T40", "teacher_name": "Teacher-40"}, {"day": "Saturday", "room": "ECL-1", "batch": "66", "section": "F", "subject": "EEE-1222", "semester": 4, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 252, "version_key": 3, "subject_code": "EEE-1222", "teacher_code": "T74", "teacher_name": "Teacher-74"}, {"day": "Saturday", "room": "RAB-401", "batch": "66", "section": "G", "subject": "MAT-2251", "semester": 4, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 253, "version_key": 3, "subject_code": "MAT-2251", "teacher_code": "T36", "teacher_name": "Teacher-36"}, {"day": "Saturday", "room": "RKB-103", "batch": "66", "section": "H", "subject": "CSE-2101", "semester": 4, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 254, "version_key": 3, "subject_code": "CSE-2101", "teacher_code": "T59", "teacher_name": "Teacher-59"}, {"day": "Saturday", "room": "ACL-4", "batch": "67", "section": "C", "subject": "CSE-2112", "semester": 3, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 255, "version_key": 3, "subject_code": "CSE-2112", "teacher_code": "T4", "teacher_name": "Teacher-4"}, {"day": "Saturday", "room": "ACL-1", "batch": "68", "section": "B", "subject": "CSE-1212", "semester": 2, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 256, "version_key": 3, "subject_code": "CSE-1212", "teacher_code": "T37", "teacher_name": "Teacher-37"}, {"day": "Saturday", "room": "G2", "batch": "68", "section": "F", "subject": "GED-2181", "semester": 2, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 257, "version_key": 3, "subject_code": "GED-2181", "teacher_code": "T75", "teacher_name": "Teacher-75"}, {"day": "Saturday", "room": "RAB-309", "batch": "69", "section": "B", "subject": "CSE-1101", "semester": 1, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 258, "version_key": 3, "subject_code": "CSE-1101", "teacher_code": "T81", "teacher_name": "Teacher-81"}, {"day": "Saturday", "room": "ACL-2", "batch": "M. Sc", "section": "6+7", "subject": "CSE-511", "semester": 1, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 259, "version_key": 3, "subject_code": "CSE-511", "teacher_code": "T42", "teacher_name": "Teacher-42"}, {"day": "Saturday", "room": "ACL-2", "batch": "62", "section": "A", "subject": "CSE-4116", "semester": 8, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 260, "version_key": 3, "subject_code": "CSE-4116", "teacher_code": "T35", "teacher_name": "Teacher-35"}, {"day": "Saturday", "room": "RKB-106", "batch": "62", "section": "E", "subject": "Operating System", "semester": 8, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 261, "version_key": 3, "subject_code": "CSE-4211", "teacher_code": "T15", "teacher_name": "Teacher-15"}, {"day": "Saturday", "room": "RKB-403", "batch": "62", "section": "H", "subject": "Operating System", "semester": 8, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 262, "version_key": 3, "subject_code": "CSE-4211", "teacher_code": "T72", "teacher_name": "Teacher-72"}, {"day": "Saturday", "room": "NL", "batch": "62", "section": "I", "subject": "Operating System Sessional", "semester": 8, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 263, "version_key": 3, "subject_code": "CSE-4212", "teacher_code": "T58", "teacher_name": "Teacher-58"}, {"day": "Saturday", "room": "RAB-304", "batch": "63", "section": "A", "subject": "CSE-3231", "semester": 7, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 264, "version_key": 3, "subject_code": "CSE-3231", "teacher_code": "T48", "teacher_name": "Teacher-48"}, {"day": "Saturday", "room": "ACL-1", "batch": "63", "section": "B", "subject": "CSE-3232", "semester": 7, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 265, "version_key": 3, "subject_code": "CSE-3232", "teacher_code": "T34", "teacher_name": "Teacher-34"}, {"day": "Saturday", "room": "RAB-306", "batch": "63", "section": "D", "subject": "CSE-3231", "semester": 7, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 266, "version_key": 3, "subject_code": "CSE-3231", "teacher_code": "T25", "teacher_name": "Teacher-25"}, {"day": "Saturday", "room": "RAB-309", "batch": "64", "section": "E", "subject": "GED-1291", "semester": 6, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 267, "version_key": 3, "subject_code": "GED-1291", "teacher_code": "T39", "teacher_name": "Teacher-39"}, {"day": "Saturday", "room": "ACL-4", "batch": "64", "section": "F", "subject": "CSE-3214", "semester": 6, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 268, "version_key": 3, "subject_code": "CSE-3214", "teacher_code": "T6", "teacher_name": "Teacher-6"}, {"day": "Saturday", "room": "RKB-402", "batch": "65", "section": "C", "subject": "EEE-2121", "semester": 5, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 269, "version_key": 3, "subject_code": "EEE-2121", "teacher_code": "T40", "teacher_name": "Teacher-40"}, {"day": "Saturday", "room": "RKB-404", "batch": "65", "section": "D", "subject": "EEE-2121", "semester": 5, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 270, "version_key": 3, "subject_code": "EEE-2121", "teacher_code": "T23", "teacher_name": "Teacher-23"}, {"day": "Saturday", "room": "RKB-407", "batch": "65", "section": "E+F", "subject": "MAT-3151", "semester": 5, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 271, "version_key": 3, "subject_code": "MAT-3151", "teacher_code": "T73", "teacher_name": "Teacher-73"}, {"day": "Saturday", "room": "RAB-401", "batch": "66", "section": "F", "subject": "EEE-1221", "semester": 4, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 272, "version_key": 3, "subject_code": "EEE-1221", "teacher_code": "T74", "teacher_name": "Teacher-74"}, {"day": "Saturday", "room": "RKB-103", "batch": "66", "section": "G", "subject": "CSE-2101", "semester": 4, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 273, "version_key": 3, "subject_code": "CSE-2101", "teacher_code": "T1", "teacher_name": "Teacher-1"}, {"day": "Saturday", "room": "RKB-303", "batch": "66", "section": "H", "subject": "MAT-2251", "semester": 4, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 274, "version_key": 3, "subject_code": "MAT-2251", "teacher_code": "T36", "teacher_name": "Teacher-36"}, {"day": "Saturday", "room": "ACL-3", "batch": "67", "section": "C", "subject": "GED-1262", "semester": 3, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 275, "version_key": 3, "subject_code": "GED-1262", "teacher_code": "T50", "teacher_name": "Teacher-50"}, {"day": "Saturday", "room": "RAB-302", "batch": "68", "section": "B", "subject": "CSE-1211", "semester": 2, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 276, "version_key": 3, "subject_code": "CSE-1211", "teacher_code": "T37", "teacher_name": "Teacher-37"}, {"day": "Saturday", "room": "G2", "batch": "69", "section": "B", "subject": "GED-1131", "semester": 1, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 277, "version_key": 3, "subject_code": "GED-1131", "teacher_code": "T14", "teacher_name": "Teacher-14"}, {"day": "Saturday", "room": "AHB-104", "batch": "M. Sc", "section": "6+7", "subject": "CSE-511", "semester": 1, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 278, "version_key": 3, "subject_code": "CSE-511", "teacher_code": "T42", "teacher_name": "Teacher-42"}, {"day": "Saturday", "room": "RKB-405", "batch": "Retake", "section": "ALL", "subject": "CSE-1211", "semester": 1, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 279, "version_key": 3, "subject_code": "CSE-1211", "teacher_code": "T16", "teacher_name": "Teacher-16"}, {"day": "Saturday", "room": "ACL-2", "batch": "62", "section": "A", "subject": "CSE-4116", "semester": 8, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 280, "version_key": 3, "subject_code": "CSE-4116", "teacher_code": "T35", "teacher_name": "Teacher-35"}, {"day": "Saturday", "room": "NL", "batch": "62", "section": "E", "subject": "Operating System Sessional", "semester": 8, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 281, "version_key": 3, "subject_code": "CSE-4212", "teacher_code": "T15", "teacher_name": "Teacher-15"}, {"day": "Saturday", "room": "RKB-403", "batch": "62", "section": "I", "subject": "Operating System", "semester": 8, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 282, "version_key": 3, "subject_code": "CSE-4211", "teacher_code": "T58", "teacher_name": "Teacher-58"}, {"day": "Saturday", "room": "ACL-1", "batch": "63", "section": "A", "subject": "CSE-3232", "semester": 7, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 283, "version_key": 3, "subject_code": "CSE-3232", "teacher_code": "T48", "teacher_name": "Teacher-48"}, {"day": "Saturday", "room": "RKB-404", "batch": "63", "section": "D", "subject": "CSE-4135", "semester": 7, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 284, "version_key": 3, "subject_code": "CSE-4135", "teacher_code": "T18", "teacher_name": "Teacher-18"}, {"day": "Saturday", "room": "RKB-402", "batch": "64", "section": "E", "subject": "CSE-2231", "semester": 6, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 285, "version_key": 3, "subject_code": "CSE-2231", "teacher_code": "T79", "teacher_name": "Teacher-79"}, {"day": "Saturday", "room": "RAB-309", "batch": "64", "section": "F", "subject": "GED-1291", "semester": 6, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 286, "version_key": 3, "subject_code": "GED-1291", "teacher_code": "T39", "teacher_name": "Teacher-39"}, {"day": "Saturday", "room": "RAB-304", "batch": "65", "section": "C", "subject": "MAT-3151", "semester": 5, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 287, "version_key": 3, "subject_code": "MAT-3151", "teacher_code": "T64", "teacher_name": "Teacher-64"}, {"day": "Saturday", "room": "RAB-306", "batch": "65", "section": "D", "subject": "MAT-3151", "semester": 5, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 288, "version_key": 3, "subject_code": "MAT-3151", "teacher_code": "T73", "teacher_name": "Teacher-73"}, {"day": "Saturday", "room": "RAB-302", "batch": "66", "section": "F", "subject": "MAT-2251", "semester": 4, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 289, "version_key": 3, "subject_code": "MAT-2251", "teacher_code": "T36", "teacher_name": "Teacher-36"}, {"day": "Saturday", "room": "G2", "batch": "68", "section": "B", "subject": "GED-2181", "semester": 2, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 290, "version_key": 3, "subject_code": "GED-2181", "teacher_code": "T75", "teacher_name": "Teacher-75"}, {"day": "Saturday", "room": "RKB-405", "batch": "Retake", "section": "ALL", "subject": "CSE-1211", "semester": 1, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 291, "version_key": 3, "subject_code": "CSE-1211", "teacher_code": "T16", "teacher_name": "Teacher-16"}, {"day": "Saturday", "room": "ACL-2", "batch": "62", "section": "G", "subject": "Operating System Sessional", "semester": 8, "time_end": "12:15:00", "is_active": true, "is_service": false, "time_start": "23:10:00", "fixture_row": 292, "version_key": 3, "subject_code": "CSE-4212", "teacher_code": "T59", "teacher_name": "Teacher-59"}, {"day": "Saturday", "room": "RAB-309", "batch": "62", "section": "H", "subject": "CSE-4161", "semester": 8, "time_end": "12:15:00", "is_active": true, "is_service": false, "time_start": "23:10:00", "fixture_row": 293, "version_key": 3, "subject_code": "CSE-4161", "teacher_code": "T79", "teacher_name": "Teacher-79"}, {"day": "Saturday", "room": "RKB-106", "batch": "62", "section": "I", "subject": "Research Methodology", "semester": 8, "time_end": "12:15:00", "is_active": true, "is_service": false, "time_start": "23:10:00", "fixture_row": 294, "version_key": 3, "subject_code": "GED-3213", "teacher_code": "T61", "teacher_name": "Teacher-61"}, {"day": "Saturday", "room": "RKB-404", "batch": "63", "section": "B", "subject": "CSE-4135", "semester": 7, "time_end": "12:15:00", "is_active": true, "is_service": false, "time_start": "23:10:00", "fixture_row": 295, "version_key": 3, "subject_code": "CSE-4135", "teacher_code": "T3", "teacher_name": "Teacher-3"}, {"day": "Saturday", "room": "RKB-407", "batch": "63", "section": "C", "subject": "GED-1116", "semester": 7, "time_end": "12:15:00", "is_active": true, "is_service": false, "time_start": "23:10:00", "fixture_row": 296, "version_key": 3, "subject_code": "GED-1116", "teacher_code": "T7", "teacher_name": "Teacher-7"}, {"day": "Saturday", "room": "RAB-304", "batch": "64", "section": "C", "subject": "CSE-3213", "semester": 6, "time_end": "12:15:00", "is_active": true, "is_service": false, "time_start": "23:10:00", "fixture_row": 297, "version_key": 3, "subject_code": "CSE-3213", "teacher_code": "T6", "teacher_name": "Teacher-6"}, {"day": "Saturday", "room": "RKB-403", "batch": "65", "section": "A", "subject": "MAT-3151", "semester": 5, "time_end": "12:15:00", "is_active": true, "is_service": false, "time_start": "23:10:00", "fixture_row": 298, "version_key": 3, "subject_code": "MAT-3151", "teacher_code": "T64", "teacher_name": "Teacher-64"}, {"day": "Saturday", "room": "RAB-302", "batch": "65", "section": "B", "subject": "CSE-2101", "semester": 5, "time_end": "12:15:00", "is_active": true, "is_service": false, "time_start": "23:10:00", "fixture_row": 299, "version_key": 3, "subject_code": "CSE-2101", "teacher_code": "T15", "teacher_name": "Teacher-15"}, {"day": "Saturday", "room": "ECL-1", "batch": "66", "section": "A", "subject": "EEE-1222", "semester": 4, "time_end": "12:15:00", "is_active": true, "is_service": false, "time_start": "23:10:00", "fixture_row": 300, "version_key": 3, "subject_code": "EEE-1222", "teacher_code": "T40", "teacher_name": "Teacher-40"}, {"day": "Saturday", "room": "ACL-1", "batch": "67", "section": "D", "subject": "CSE-2112", "semester": 3, "time_end": "12:15:00", "is_active": true, "is_service": false, "time_start": "23:10:00", "fixture_row": 301, "version_key": 3, "subject_code": "CSE-2112", "teacher_code": "T4", "teacher_name": "Teacher-4"}, {"day": "Saturday", "room": "RAB-401", "batch": "67", "section": "E", "subject": "EEE-1221", "semester": 3, "time_end": "12:15:00", "is_active": true, "is_service": false, "time_start": "23:10:00", "fixture_row": 302, "version_key": 3, "subject_code": "EEE-1221", "teacher_code": "T82", "teacher_name": "Teacher-82"}, {"day": "Saturday", "room": "RAB-306", "batch": "68", "section": "C", "subject": "CSE-1211", "semester": 2, "time_end": "12:15:00", "is_active": true, "is_service": false, "time_start": "23:10:00", "fixture_row": 303, "version_key": 3, "subject_code": "CSE-1211", "teacher_code": "T34", "teacher_name": "Teacher-34"}, {"day": "Saturday", "room": "RKB-402", "batch": "68", "section": "D", "subject": "MAT-1251", "semester": 2, "time_end": "12:15:00", "is_active": true, "is_service": false, "time_start": "23:10:00", "fixture_row": 304, "version_key": 3, "subject_code": "MAT-1251", "teacher_code": "T45", "teacher_name": "Teacher-45"}, {"day": "Saturday", "room": "RKB-103", "batch": "68", "section": "E", "subject": "CHE-1161", "semester": 2, "time_end": "12:15:00", "is_active": true, "is_service": false, "time_start": "23:10:00", "fixture_row": 305, "version_key": 3, "subject_code": "CHE-1161", "teacher_code": "T44", "teacher_name": "Teacher-44"}, {"day": "Saturday", "room": "RKB-303", "batch": "68", "section": "F", "subject": "MAT-1251", "semester": 2, "time_end": "12:15:00", "is_active": true, "is_service": false, "time_start": "23:10:00", "fixture_row": 306, "version_key": 3, "subject_code": "MAT-1251", "teacher_code": "T38", "teacher_name": "Teacher-38"}, {"day": "Saturday", "room": "ACL-4", "batch": "69", "section": "A", "subject": "CSE-1102", "semester": 1, "time_end": "12:15:00", "is_active": true, "is_service": false, "time_start": "23:10:00", "fixture_row": 307, "version_key": 3, "subject_code": "CSE-1102", "teacher_code": "T20", "teacher_name": "Teacher-20"}, {"day": "Saturday", "room": "ACL-3", "batch": "69", "section": "E", "subject": "CSE-1102", "semester": 1, "time_end": "12:15:00", "is_active": true, "is_service": false, "time_start": "23:10:00", "fixture_row": 308, "version_key": 3, "subject_code": "CSE-1102", "teacher_code": "T37", "teacher_name": "Teacher-37"}, {"day": "Saturday", "room": "G2", "batch": "69", "section": "J", "subject": "CSE-1101", "semester": 1, "time_end": "12:15:00", "is_active": true, "is_service": false, "time_start": "23:10:00", "fixture_row": 309, "version_key": 3, "subject_code": "CSE-1101", "teacher_code": "T16", "teacher_name": "Teacher-16"}, {"day": "Saturday", "room": "RAB- 309", "batch": "M. Sc", "section": "6+7", "subject": "CSE-517", "semester": 1, "time_end": "12:15:00", "is_active": true, "is_service": false, "time_start": "23:10:00", "fixture_row": 310, "version_key": 3, "subject_code": "CSE-517", "teacher_code": "T55", "teacher_name": "Teacher-55"}, {"day": "Sunday", "room": "RKB-106", "batch": "62", "section": "C", "subject": "Research Methodology", "semester": 8, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 311, "version_key": 3, "subject_code": "GED-3213", "teacher_code": "T66", "teacher_name": "Teacher-66"}, {"day": "Sunday", "room": "RKB-103", "batch": "62", "section": "E", "subject": "Research Methodology", "semester": 8, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 312, "version_key": 3, "subject_code": "GED-3213", "teacher_code": "T49", "teacher_name": "Teacher-49"}, {"day": "Sunday", "room": "ACL-2", "batch": "62", "section": "G", "subject": "CSE-4116", "semester": 8, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 313, "version_key": 3, "subject_code": "CSE-4116", "teacher_code": "T35", "teacher_name": "Teacher-35"}, {"day": "Sunday", "room": "RKB-407", "batch": "63", "section": "C", "subject": "CSE-4135", "semester": 7, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 314, "version_key": 3, "subject_code": "CSE-4135", "teacher_code": "T18", "teacher_name": "Teacher-18"}, {"day": "Sunday", "room": "NL", "batch": "64", "section": "A", "subject": "CSE-3214", "semester": 6, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 315, "version_key": 3, "subject_code": "CSE-3214", "teacher_code": "T6", "teacher_name": "Teacher-6"}, {"day": "Sunday", "room": "ACL-4", "batch": "64", "section": "D", "subject": "CSE-3214", "semester": 6, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 316, "version_key": 3, "subject_code": "CSE-3214", "teacher_code": "T8", "teacher_name": "Teacher-8"}, {"day": "Sunday", "room": "RAB-309", "batch": "64", "section": "E", "subject": "CSE-3213", "semester": 6, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 317, "version_key": 3, "subject_code": "CSE-3213", "teacher_code": "T67", "teacher_name": "Teacher-67"}, {"day": "Sunday", "room": "RAB-304", "batch": "65", "section": "C", "subject": "CSE-3111", "semester": 5, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 318, "version_key": 3, "subject_code": "CSE-3111", "teacher_code": "T27", "teacher_name": "Teacher-27"}, {"day": "Sunday", "room": "ACL-3", "batch": "66", "section": "D", "subject": "CSE-2212", "semester": 4, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 319, "version_key": 3, "subject_code": "CSE-2212", "teacher_code": "T41", "teacher_name": "Teacher-41"}, {"day": "Sunday", "room": "RAB-401", "batch": "66", "section": "E", "subject": "MAT-2251", "semester": 4, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 320, "version_key": 3, "subject_code": "MAT-2251", "teacher_code": "T60", "teacher_name": "Teacher-60"}, {"day": "Sunday", "room": "RAB-306", "batch": "67", "section": "A", "subject": "PHY-1171", "semester": 3, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 321, "version_key": 3, "subject_code": "PHY-1171", "teacher_code": "T43", "teacher_name": "Teacher-43"}, {"day": "Sunday", "room": "ACL-1", "batch": "68", "section": "B", "subject": "CSE-1212", "semester": 2, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 322, "version_key": 3, "subject_code": "CSE-1212", "teacher_code": "T37", "teacher_name": "Teacher-37"}, {"day": "Sunday", "room": "RKB-402", "batch": "68", "section": "C", "subject": "GED-1231", "semester": 2, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 323, "version_key": 3, "subject_code": "GED-1231", "teacher_code": "T11", "teacher_name": "Teacher-11"}, {"day": "Sunday", "room": "RAB-302", "batch": "68", "section": "F", "subject": "CSE-1211", "semester": 2, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 324, "version_key": 3, "subject_code": "CSE-1211", "teacher_code": "T57", "teacher_name": "Teacher-57"}, {"day": "Sunday", "room": "G2", "batch": "69", "section": "E", "subject": "GED-1145", "semester": 1, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 325, "version_key": 3, "subject_code": "GED-1145", "teacher_code": "T17", "teacher_name": "Teacher-17"}, {"day": "Sunday", "room": "RKB-403", "batch": "Retake", "section": "DLD", "subject": "CSE-2221", "semester": 1, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 326, "version_key": 3, "subject_code": "CSE-2221", "teacher_code": "T10", "teacher_name": "Teacher-10"}, {"day": "Sunday", "room": "RKB-403", "batch": "Retake", "section": "DLD", "subject": "CSE-2221", "semester": 1, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 327, "version_key": 3, "subject_code": "CSE-2221", "teacher_code": "T10", "teacher_name": "Teacher-10"}, {"day": "Sunday", "room": "RKB-106", "batch": "62", "section": "A", "subject": "CSE-4161", "semester": 8, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 328, "version_key": 3, "subject_code": "CSE-4161", "teacher_code": "T1", "teacher_name": "Teacher-1"}, {"day": "Sunday", "room": "NL", "batch": "62", "section": "C", "subject": "CSE-4161", "semester": 8, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 329, "version_key": 3, "subject_code": "CSE-4161", "teacher_code": "T5", "teacher_name": "Teacher-5"}, {"day": "Sunday", "room": "ACL-2", "batch": "62", "section": "G", "subject": "CSE-4116", "semester": 8, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 330, "version_key": 3, "subject_code": "CSE-4116", "teacher_code": "T35", "teacher_name": "Teacher-35"}, {"day": "Sunday", "room": "RAB-304", "batch": "63", "section": "C", "subject": "CSE-4161", "semester": 7, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 331, "version_key": 3, "subject_code": "CSE-4161", "teacher_code": "T4", "teacher_name": "Teacher-4"}, {"day": "Sunday", "room": "RAB-306", "batch": "64", "section": "A", "subject": "CSE-3213", "semester": 6, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 332, "version_key": 3, "subject_code": "CSE-3213", "teacher_code": "T6", "teacher_name": "Teacher-6"}, {"day": "Sunday", "room": "RAB-309", "batch": "64", "section": "B", "subject": "CSE-3115", "semester": 6, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 333, "version_key": 3, "subject_code": "CSE-3115", "teacher_code": "T55", "teacher_name": "Teacher-55"}, {"day": "Sunday", "room": "RKB-303", "batch": "64", "section": "D", "subject": "CSE-3115", "semester": 6, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 334, "version_key": 3, "subject_code": "CSE-3115", "teacher_code": "T22", "teacher_name": "Teacher-22"}, {"day": "Sunday", "room": "ACL-4", "batch": "64", "section": "E", "subject": "CSE-3214", "semester": 6, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 335, "version_key": 3, "subject_code": "CSE-3214", "teacher_code": "T67", "teacher_name": "Teacher-67"}, {"day": "Sunday", "room": "RKB-407", "batch": "64", "section": "H", "subject": "CSE-3213", "semester": 6, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 336, "version_key": 3, "subject_code": "CSE-3213", "teacher_code": "T58", "teacher_name": "Teacher-58"}, {"day": "Sunday", "room": "ACL-3", "batch": "65", "section": "C", "subject": "CSE-3112", "semester": 5, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 337, "version_key": 3, "subject_code": "CSE-3112", "teacher_code": "T27", "teacher_name": "Teacher-27"}, {"day": "Sunday", "room": "RKB-404", "batch": "66", "section": "A", "subject": "GED-1201", "semester": 4, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 338, "version_key": 3, "subject_code": "GED-1201", "teacher_code": "T54", "teacher_name": "Teacher-54"}, {"day": "Sunday", "room": "RKB-402", "batch": "66", "section": "D", "subject": "CSE-2211", "semester": 4, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 339, "version_key": 3, "subject_code": "CSE-2211", "teacher_code": "T41", "teacher_name": "Teacher-41"}, {"day": "Sunday", "room": "RKB-403", "batch": "66", "section": "E", "subject": "GED-1201", "semester": 4, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 340, "version_key": 3, "subject_code": "GED-1201", "teacher_code": "T13", "teacher_name": "Teacher-13"}, {"day": "Sunday", "room": "RAB-302", "batch": "67", "section": "A", "subject": "MAT-2151", "semester": 3, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 341, "version_key": 3, "subject_code": "MAT-2151", "teacher_code": "T32", "teacher_name": "Teacher-32"}, {"day": "Sunday", "room": "RAB-401", "batch": "68", "section": "B", "subject": "CSE-1211", "semester": 2, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 342, "version_key": 3, "subject_code": "CSE-1211", "teacher_code": "T37", "teacher_name": "Teacher-37"}, {"day": "Sunday", "room": "RAB-111", "batch": "68", "section": "C", "subject": "GED-2181", "semester": 2, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 343, "version_key": 3, "subject_code": "GED-2181", "teacher_code": "T75", "teacher_name": "Teacher-75"}, {"day": "Sunday", "room": "ACL-1", "batch": "68", "section": "F", "subject": "CSE-1212", "semester": 2, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 344, "version_key": 3, "subject_code": "CSE-1212", "teacher_code": "T57", "teacher_name": "Teacher-57"}, {"day": "Sunday", "room": "G2", "batch": "69", "section": "E", "subject": "GED-1131", "semester": 1, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 345, "version_key": 3, "subject_code": "GED-1131", "teacher_code": "T14", "teacher_name": "Teacher-14"}, {"day": "Sunday", "room": "RKB-103", "batch": "Retake", "section": "DLD", "subject": "CSE-2221", "semester": 1, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 346, "version_key": 3, "subject_code": "CSE-2221", "teacher_code": "T10", "teacher_name": "Teacher-10"}, {"day": "Sunday", "room": "RKB-103", "batch": "Retake", "section": "DLD", "subject": "CSE-2221", "semester": 1, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 347, "version_key": 3, "subject_code": "CSE-2221", "teacher_code": "T10", "teacher_name": "Teacher-10"}, {"day": "Sunday", "room": "RKB-106", "batch": "62", "section": "E", "subject": "Operating System", "semester": 8, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 348, "version_key": 3, "subject_code": "CSE-4211", "teacher_code": "T15", "teacher_name": "Teacher-15"}, {"day": "Sunday", "room": "ACL-2", "batch": "62", "section": "F", "subject": "Operating System Sessional", "semester": 8, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 349, "version_key": 3, "subject_code": "CSE-4212", "teacher_code": "T68", "teacher_name": "Teacher-68"}, {"day": "Sunday", "room": "RKB-403", "batch": "62", "section": "H", "subject": "Research Methodology", "semester": 8, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 350, "version_key": 3, "subject_code": "GED-3213", "teacher_code": "T61", "teacher_name": "Teacher-61"}, {"day": "Sunday", "room": "RAB-306", "batch": "64", "section": "A", "subject": "CSE-3115", "semester": 6, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 351, "version_key": 3, "subject_code": "CSE-3115", "teacher_code": "T49", "teacher_name": "Teacher-49"}, {"day": "Sunday", "room": "NL", "batch": "64", "section": "B", "subject": "CSE-3116", "semester": 6, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 352, "version_key": 3, "subject_code": "CSE-3116", "teacher_code": "T55", "teacher_name": "Teacher-55"}, {"day": "Sunday", "room": "ACL-3", "batch": "64", "section": "E", "subject": "CSE-3116", "semester": 6, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 353, "version_key": 3, "subject_code": "CSE-3116", "teacher_code": "T5", "teacher_name": "Teacher-5"}, {"day": "Sunday", "room": "ACL-4", "batch": "64", "section": "H", "subject": "CSE-3214", "semester": 6, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 354, "version_key": 3, "subject_code": "CSE-3214", "teacher_code": "T58", "teacher_name": "Teacher-58"}, {"day": "Sunday", "room": "RAB-302", "batch": "64", "section": "I", "subject": "CSE-2231", "semester": 6, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 355, "version_key": 3, "subject_code": "CSE-2231", "teacher_code": "T16", "teacher_name": "Teacher-16"}, {"day": "Sunday", "room": "RAB-111", "batch": "65", "section": "C", "subject": "MAT-3151", "semester": 5, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 356, "version_key": 3, "subject_code": "MAT-3151", "teacher_code": "T64", "teacher_name": "Teacher-64"}, {"day": "Sunday", "room": "RAB-309", "batch": "66", "section": "A", "subject": "CSE-2211", "semester": 4, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 357, "version_key": 3, "subject_code": "CSE-2211", "teacher_code": "T8", "teacher_name": "Teacher-8"}, {"day": "Sunday", "room": "RKB-402", "batch": "66", "section": "B", "subject": "EEE-1221", "semester": 4, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 358, "version_key": 3, "subject_code": "EEE-1221", "teacher_code": "T40", "teacher_name": "Teacher-40"}, {"day": "Sunday", "room": "RAB-304", "batch": "66", "section": "D", "subject": "MAT-2251", "semester": 4, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 359, "version_key": 3, "subject_code": "MAT-2251", "teacher_code": "T60", "teacher_name": "Teacher-60"}, {"day": "Sunday", "room": "RKB-303", "batch": "66", "section": "F", "subject": "MAT-2251", "semester": 4, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 360, "version_key": 3, "subject_code": "MAT-2251", "teacher_code": "T36", "teacher_name": "Teacher-36"}, {"day": "Sunday", "room": "PHY LAB", "batch": "67", "section": "A", "subject": "PHY-1272", "semester": 3, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 361, "version_key": 3, "subject_code": "PHY-1272", "teacher_code": "T43", "teacher_name": "Teacher-43"}, {"day": "Sunday", "room": "RKB-103", "batch": "67", "section": "C", "subject": "CSE-2231", "semester": 3, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 362, "version_key": 3, "subject_code": "CSE-2231", "teacher_code": "T35", "teacher_name": "Teacher-35"}, {"day": "Sunday", "room": "RKB-407", "batch": "68", "section": "C", "subject": "GED-1201", "semester": 2, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 363, "version_key": 3, "subject_code": "GED-1201", "teacher_code": "T54", "teacher_name": "Teacher-54"}, {"day": "Sunday", "room": "RKB-404", "batch": "68", "section": "F", "subject": "GED-2181", "semester": 2, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 364, "version_key": 3, "subject_code": "GED-2181", "teacher_code": "T75", "teacher_name": "Teacher-75"}, {"day": "Sunday", "room": "ACL-2", "batch": "62", "section": "A", "subject": "CSE-4116", "semester": 8, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 365, "version_key": 3, "subject_code": "CSE-4116", "teacher_code": "T35", "teacher_name": "Teacher-35"}, {"day": "Sunday", "room": "NL", "batch": "62", "section": "E", "subject": "Operating System Sessional", "semester": 8, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 366, "version_key": 3, "subject_code": "CSE-4212", "teacher_code": "T15", "teacher_name": "Teacher-15"}, {"day": "Sunday", "room": "RKB-106", "batch": "62", "section": "F", "subject": "Operating System", "semester": 8, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 367, "version_key": 3, "subject_code": "CSE-4211", "teacher_code": "T68", "teacher_name": "Teacher-68"}, {"day": "Sunday", "room": "RKB-403", "batch": "62", "section": "I", "subject": "Research Methodology", "semester": 8, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 368, "version_key": 3, "subject_code": "GED-3213", "teacher_code": "T61", "teacher_name": "Teacher-61"}, {"day": "Sunday", "room": "RKB-103", "batch": "63", "section": "C", "subject": "Research Methodology", "semester": 7, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 369, "version_key": 3, "subject_code": "GED-3213", "teacher_code": "T27", "teacher_name": "Teacher-27"}, {"day": "Sunday", "room": "ACL-3", "batch": "64", "section": "A", "subject": "CSE-3116", "semester": 6, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 370, "version_key": 3, "subject_code": "CSE-3116", "teacher_code": "T49", "teacher_name": "Teacher-49"}, {"day": "Sunday", "room": "RAB-306", "batch": "64", "section": "B", "subject": "GED-1291", "semester": 6, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 371, "version_key": 3, "subject_code": "GED-1291", "teacher_code": "T26", "teacher_name": "Teacher-26"}, {"day": "Sunday", "room": "RKB-407", "batch": "64", "section": "D", "subject": "GED-1291", "semester": 6, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 372, "version_key": 3, "subject_code": "GED-1291", "teacher_code": "T39", "teacher_name": "Teacher-39"}, {"day": "Sunday", "room": "RKB-303", "batch": "64", "section": "E", "subject": "CSE-3115", "semester": 6, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 373, "version_key": 3, "subject_code": "CSE-3115", "teacher_code": "T5", "teacher_name": "Teacher-5"}, {"day": "Sunday", "room": "RAB-401", "batch": "64", "section": "F", "subject": "CSE-3213", "semester": 6, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 374, "version_key": 3, "subject_code": "CSE-3213", "teacher_code": "T58", "teacher_name": "Teacher-58"}, {"day": "Sunday", "room": "ACL-4", "batch": "64", "section": "I", "subject": "CSE-3214", "semester": 6, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 375, "version_key": 3, "subject_code": "CSE-3214", "teacher_code": "T67", "teacher_name": "Teacher-67"}, {"day": "Sunday", "room": "ACL-1", "batch": "66", "section": "A", "subject": "CSE-2212", "semester": 4, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 376, "version_key": 3, "subject_code": "CSE-2212", "teacher_code": "T8", "teacher_name": "Teacher-8"}, {"day": "Sunday", "room": "RKB-404", "batch": "66", "section": "B", "subject": "GED-1201", "semester": 4, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 377, "version_key": 3, "subject_code": "GED-1201", "teacher_code": "T54", "teacher_name": "Teacher-54"}, {"day": "Sunday", "room": "G2", "batch": "66", "section": "F", "subject": "CSE-2101", "semester": 4, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 378, "version_key": 3, "subject_code": "CSE-2101", "teacher_code": "T76", "teacher_name": "Teacher-76"}, {"day": "Sunday", "room": "PHY LAB", "batch": "67", "section": "A", "subject": "PHY-1272", "semester": 3, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 379, "version_key": 3, "subject_code": "PHY-1272", "teacher_code": "T43", "teacher_name": "Teacher-43"}, {"day": "Sunday", "room": "RAB-304", "batch": "67", "section": "C", "subject": "PHY-1171", "semester": 3, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 380, "version_key": 3, "subject_code": "PHY-1171", "teacher_code": "T46", "teacher_name": "Teacher-46"}, {"day": "Sunday", "room": "RAB-302", "batch": "67", "section": "E", "subject": "MAT-2151", "semester": 3, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 381, "version_key": 3, "subject_code": "MAT-2151", "teacher_code": "T32", "teacher_name": "Teacher-32"}, {"day": "Sunday", "room": "RAB-111", "batch": "68", "section": "B", "subject": "GED-1231", "semester": 2, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 382, "version_key": 3, "subject_code": "GED-1231", "teacher_code": "T11", "teacher_name": "Teacher-11"}, {"day": "Sunday", "room": "RAB-309", "batch": "68", "section": "D", "subject": "CHE-1161", "semester": 2, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 383, "version_key": 3, "subject_code": "CHE-1161", "teacher_code": "T2", "teacher_name": "Teacher-2"}, {"day": "Sunday", "room": "RKB-403", "batch": "62", "section": "E", "subject": "CSE-4161", "semester": 8, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 384, "version_key": 3, "subject_code": "CSE-4161", "teacher_code": "T18", "teacher_name": "Teacher-18"}, {"day": "Sunday", "room": "RKB-106", "batch": "62", "section": "F", "subject": "Research Methodology", "semester": 8, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 385, "version_key": 3, "subject_code": "GED-3213", "teacher_code": "T61", "teacher_name": "Teacher-61"}, {"day": "Sunday", "room": "NL", "batch": "62", "section": "H", "subject": "Operating System Sessional", "semester": 8, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 386, "version_key": 3, "subject_code": "CSE-4212", "teacher_code": "T72", "teacher_name": "Teacher-72"}, {"day": "Sunday", "room": "RKB-103", "batch": "63", "section": "B", "subject": "CSE-4135", "semester": 7, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 387, "version_key": 3, "subject_code": "CSE-4135", "teacher_code": "T3", "teacher_name": "Teacher-3"}, {"day": "Sunday", "room": "RAB-304", "batch": "63", "section": "D", "subject": "Research Methodology", "semester": 7, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 388, "version_key": 3, "subject_code": "GED-3213", "teacher_code": "T57", "teacher_name": "Teacher-57"}, {"day": "Sunday", "room": "ACL-1", "batch": "64", "section": "D", "subject": "CSE-3116", "semester": 6, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 389, "version_key": 3, "subject_code": "CSE-3116", "teacher_code": "T49", "teacher_name": "Teacher-49"}, {"day": "Sunday", "room": "ACL-3", "batch": "64", "section": "F", "subject": "CSE-3116", "semester": 6, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 390, "version_key": 3, "subject_code": "CSE-3116", "teacher_code": "T5", "teacher_name": "Teacher-5"}, {"day": "Sunday", "room": "RAB-309", "batch": "64", "section": "H", "subject": "CSE-3115", "semester": 6, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 391, "version_key": 3, "subject_code": "CSE-3115", "teacher_code": "T55", "teacher_name": "Teacher-55"}, {"day": "Sunday", "room": "ACL-4", "batch": "64", "section": "I", "subject": "CSE-3116", "semester": 6, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 392, "version_key": 3, "subject_code": "CSE-3116", "teacher_code": "T22", "teacher_name": "Teacher-22"}, {"day": "Sunday", "room": "RKB-402", "batch": "65", "section": "D", "subject": "CSE-3121", "semester": 5, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 393, "version_key": 3, "subject_code": "CSE-3121", "teacher_code": "T16", "teacher_name": "Teacher-16"}, {"day": "Sunday", "room": "RKB-404", "batch": "66", "section": "A", "subject": "EEE-1221", "semester": 4, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 394, "version_key": 3, "subject_code": "EEE-1221", "teacher_code": "T40", "teacher_name": "Teacher-40"}, {"day": "Sunday", "room": "RAB-306", "batch": "66", "section": "B", "subject": "CSE-2211", "semester": 4, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 395, "version_key": 3, "subject_code": "CSE-2211", "teacher_code": "T8", "teacher_name": "Teacher-8"}, {"day": "Sunday", "room": "RAB-401", "batch": "66", "section": "F", "subject": "GED-1201", "semester": 4, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 396, "version_key": 3, "subject_code": "GED-1201", "teacher_code": "T13", "teacher_name": "Teacher-13"}, {"day": "Sunday", "room": "RKB-407", "batch": "67", "section": "E", "subject": "CSE-2231", "semester": 3, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 397, "version_key": 3, "subject_code": "CSE-2231", "teacher_code": "T81", "teacher_name": "Teacher-81"}, {"day": "Sunday", "room": "G2", "batch": "68", "section": "A", "subject": "CHE-1161", "semester": 2, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 398, "version_key": 3, "subject_code": "CHE-1161", "teacher_code": "T2", "teacher_name": "Teacher-2"}, {"day": "Sunday", "room": "RAB-111", "batch": "69", "section": "A", "subject": "GED-1145", "semester": 1, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 399, "version_key": 3, "subject_code": "GED-1145", "teacher_code": "T17", "teacher_name": "Teacher-17"}, {"day": "Sunday", "room": "RAB-302", "batch": "69", "section": "B", "subject": "MAT-1151", "semester": 1, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 400, "version_key": 3, "subject_code": "MAT-1151", "teacher_code": "T56", "teacher_name": "Teacher-56"}, {"day": "Sunday", "room": "RKB-106", "batch": "62", "section": "H", "subject": "Operating System", "semester": 8, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 401, "version_key": 3, "subject_code": "CSE-4211", "teacher_code": "T72", "teacher_name": "Teacher-72"}, {"day": "Sunday", "room": "RAB-401", "batch": "63", "section": "B", "subject": "Research Methodology", "semester": 7, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 402, "version_key": 3, "subject_code": "GED-3213", "teacher_code": "T61", "teacher_name": "Teacher-61"}, {"day": "Sunday", "room": "RKB-403", "batch": "64", "section": "F", "subject": "CSE-3115", "semester": 6, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 403, "version_key": 3, "subject_code": "CSE-3115", "teacher_code": "T5", "teacher_name": "Teacher-5"}, {"day": "Sunday", "room": "NL", "batch": "64", "section": "H", "subject": "CSE-3116", "semester": 6, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 404, "version_key": 3, "subject_code": "CSE-3116", "teacher_code": "T55", "teacher_name": "Teacher-55"}, {"day": "Sunday", "room": "RKB-402", "batch": "64", "section": "I", "subject": "GED-1291", "semester": 6, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 405, "version_key": 3, "subject_code": "GED-1291", "teacher_code": "T39", "teacher_name": "Teacher-39"}, {"day": "Sunday", "room": "RAB-304", "batch": "65", "section": "D", "subject": "CSE-3111", "semester": 5, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 406, "version_key": 3, "subject_code": "CSE-3111", "teacher_code": "T27", "teacher_name": "Teacher-27"}, {"day": "Sunday", "room": "ACL-4", "batch": "66", "section": "B", "subject": "CSE-2212", "semester": 4, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 407, "version_key": 3, "subject_code": "CSE-2212", "teacher_code": "T8", "teacher_name": "Teacher-8"}, {"day": "Sunday", "room": "RAB-111", "batch": "66", "section": "F", "subject": "EEE-1221", "semester": 4, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 408, "version_key": 3, "subject_code": "EEE-1221", "teacher_code": "T74", "teacher_name": "Teacher-74"}, {"day": "Sunday", "room": "RKB-103", "batch": "66", "section": "G", "subject": "MAT-2251", "semester": 4, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 409, "version_key": 3, "subject_code": "MAT-2251", "teacher_code": "T36", "teacher_name": "Teacher-36"}, {"day": "Sunday", "room": "RAB-309", "batch": "67", "section": "C", "subject": "CSE-2111", "semester": 3, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 410, "version_key": 3, "subject_code": "CSE-2111", "teacher_code": "T4", "teacher_name": "Teacher-4"}, {"day": "Sunday", "room": "ACL-3", "batch": "67", "section": "E", "subject": "GED-1262", "semester": 3, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 411, "version_key": 3, "subject_code": "GED-1262", "teacher_code": "T80", "teacher_name": "Teacher-80"}, {"day": "Sunday", "room": "RAB-306", "batch": "68", "section": "A", "subject": "GED-1201", "semester": 2, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 412, "version_key": 3, "subject_code": "GED-1201", "teacher_code": "T54", "teacher_name": "Teacher-54"}, {"day": "Sunday", "room": "RKB-303", "batch": "68", "section": "D", "subject": "GED-2181", "semester": 2, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 413, "version_key": 3, "subject_code": "GED-2181", "teacher_code": "T75", "teacher_name": "Teacher-75"}, {"day": "Sunday", "room": "RAB-302", "batch": "69", "section": "A", "subject": "MAT-1151", "semester": 1, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 414, "version_key": 3, "subject_code": "MAT-1151", "teacher_code": "T56", "teacher_name": "Teacher-56"}, {"day": "Sunday", "room": "G2", "batch": "69", "section": "B", "subject": "GED-1145", "semester": 1, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 415, "version_key": 3, "subject_code": "GED-1145", "teacher_code": "T17", "teacher_name": "Teacher-17"}, {"day": "Sunday", "room": "RAB-106", "batch": "62", "section": "I", "subject": "CSE-4161", "semester": 8, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 416, "version_key": 3, "subject_code": "CSE-4161", "teacher_code": "T59", "teacher_name": "Teacher-59"}, {"day": "Sunday", "room": "RKB-403", "batch": "63", "section": "D", "subject": "GED-1116", "semester": 7, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 417, "version_key": 3, "subject_code": "GED-1116", "teacher_code": "T7", "teacher_name": "Teacher-7"}, {"day": "Sunday", "room": "ACL-1", "batch": "64", "section": "F", "subject": "CSE-3214", "semester": 6, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 418, "version_key": 3, "subject_code": "CSE-3214", "teacher_code": "T6", "teacher_name": "Teacher-6"}, {"day": "Sunday", "room": "RKB-303", "batch": "64", "section": "H", "subject": "CSE-2231", "semester": 6, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 419, "version_key": 3, "subject_code": "CSE-2231", "teacher_code": "T16", "teacher_name": "Teacher-16"}, {"day": "Sunday", "room": "RKB-103", "batch": "64", "section": "I", "subject": "CSE-3115", "semester": 6, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 420, "version_key": 3, "subject_code": "CSE-3115", "teacher_code": "T22", "teacher_name": "Teacher-22"}, {"day": "Sunday", "room": "ACL-3", "batch": "65", "section": "D", "subject": "CSE-3112", "semester": 5, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 421, "version_key": 3, "subject_code": "CSE-3112", "teacher_code": "T27", "teacher_name": "Teacher-27"}, {"day": "Sunday", "room": "RAB-401", "batch": "66", "section": "G", "subject": "CSE-2101", "semester": 4, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 422, "version_key": 3, "subject_code": "CSE-2101", "teacher_code": "T1", "teacher_name": "Teacher-1"}, {"day": "Sunday", "room": "NL", "batch": "67", "section": "C", "subject": "CSE-2112", "semester": 3, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 423, "version_key": 3, "subject_code": "CSE-2112", "teacher_code": "T4", "teacher_name": "Teacher-4"}, {"day": "Sunday", "room": "RAB-309", "batch": "68", "section": "A", "subject": "GED-2181", "semester": 2, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 424, "version_key": 3, "subject_code": "GED-2181", "teacher_code": "T75", "teacher_name": "Teacher-75"}, {"day": "Sunday", "room": "RAB-304", "batch": "68", "section": "D", "subject": "GED-1231", "semester": 2, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 425, "version_key": 3, "subject_code": "GED-1231", "teacher_code": "T11", "teacher_name": "Teacher-11"}, {"day": "Sunday", "room": "ACL-4", "batch": "69", "section": "B", "subject": "CSE-1102", "semester": 1, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 426, "version_key": 3, "subject_code": "CSE-1102", "teacher_code": "T20", "teacher_name": "Teacher-20"}, {"day": "Thursday", "room": "ACL-2", "batch": "61", "section": "B", "subject": "CSE-4135", "semester": 8, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 427, "version_key": 3, "subject_code": "CSE-4135", "teacher_code": "T49", "teacher_name": "Teacher-49"}, {"day": "Thursday", "room": "RKB-106", "batch": "62", "section": "A", "subject": "Operating System", "semester": 8, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 428, "version_key": 3, "subject_code": "CSE-4211", "teacher_code": "T63", "teacher_name": "Teacher-63"}, {"day": "Thursday", "room": "RAB-304", "batch": "63", "section": "A", "subject": "Research Methodology", "semester": 7, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 429, "version_key": 3, "subject_code": "GED-3213", "teacher_code": "T29", "teacher_name": "Teacher-29"}, {"day": "Thursday", "room": "NL", "batch": "63", "section": "E", "subject": "CSE-3232", "semester": 7, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 430, "version_key": 3, "subject_code": "CSE-3232", "teacher_code": "T25", "teacher_name": "Teacher-25"}, {"day": "Thursday", "room": "RKB-402", "batch": "64", "section": "A", "subject": "GED-1291", "semester": 6, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 431, "version_key": 3, "subject_code": "GED-1291", "teacher_code": "T26", "teacher_name": "Teacher-26"}, {"day": "Thursday", "room": "RKB-404", "batch": "64", "section": "D", "subject": "CSE-2231", "semester": 6, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 432, "version_key": 3, "subject_code": "CSE-2231", "teacher_code": "T59", "teacher_name": "Teacher-59"}, {"day": "Thursday", "room": "ACL-1", "batch": "64", "section": "G", "subject": "CSE-3116", "semester": 6, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 433, "version_key": 3, "subject_code": "CSE-3116", "teacher_code": "T70", "teacher_name": "Teacher-70"}, {"day": "Thursday", "room": "RAB-306", "batch": "65", "section": "D", "subject": "CSE-3111", "semester": 5, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 434, "version_key": 3, "subject_code": "CSE-3111", "teacher_code": "T27", "teacher_name": "Teacher-27"}, {"day": "Thursday", "room": "RKB-103", "batch": "67", "section": "C", "subject": "CSE-2231", "semester": 3, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 435, "version_key": 3, "subject_code": "CSE-2231", "teacher_code": "T35", "teacher_name": "Teacher-35"}, {"day": "Thursday", "room": "RKB-303", "batch": "67", "section": "E", "subject": "PHY-1171", "semester": 3, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 436, "version_key": 3, "subject_code": "PHY-1171", "teacher_code": "T46", "teacher_name": "Teacher-46"}, {"day": "Thursday", "room": "RAB-302", "batch": "68", "section": "A", "subject": "MAT-1251", "semester": 2, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 437, "version_key": 3, "subject_code": "MAT-1251", "teacher_code": "T56", "teacher_name": "Teacher-56"}, {"day": "Thursday", "room": "RAB-309", "batch": "69", "section": "D", "subject": "CSE-1101", "semester": 1, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 438, "version_key": 3, "subject_code": "CSE-1101", "teacher_code": "T30", "teacher_name": "Teacher-30"}, {"day": "Thursday", "room": "RAB-401", "batch": "69", "section": "F", "subject": "CSE-1151", "semester": 1, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 439, "version_key": 3, "subject_code": "CSE-1151", "teacher_code": "T83", "teacher_name": "Teacher-83"}, {"day": "Thursday", "room": "ACL-4", "batch": "69", "section": "H", "subject": "CSE-1102", "semester": 1, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 440, "version_key": 3, "subject_code": "CSE-1102", "teacher_code": "T57", "teacher_name": "Teacher-57"}, {"day": "Thursday", "room": "G2", "batch": "69", "section": "I", "subject": "GED-1145", "semester": 1, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 441, "version_key": 3, "subject_code": "GED-1145", "teacher_code": "T53", "teacher_name": "Teacher-53"}, {"day": "Thursday", "room": "RKB-106", "batch": "61", "section": "B", "subject": "CSE-4267", "semester": 8, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 442, "version_key": 3, "subject_code": "CSE-4267", "teacher_code": "T66", "teacher_name": "Teacher-66"}, {"day": "Thursday", "room": "ACL-2", "batch": "62", "section": "A", "subject": "Operating System Sessional", "semester": 8, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 443, "version_key": 3, "subject_code": "CSE-4212", "teacher_code": "T63", "teacher_name": "Teacher-63"}, {"day": "Thursday", "room": "RKB-404", "batch": "63", "section": "A", "subject": "CSE-4135", "semester": 7, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 444, "version_key": 3, "subject_code": "CSE-4135", "teacher_code": "T18", "teacher_name": "Teacher-18"}, {"day": "Thursday", "room": "RAB-306", "batch": "63", "section": "E", "subject": "CSE-3231", "semester": 7, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 445, "version_key": 3, "subject_code": "CSE-3231", "teacher_code": "T25", "teacher_name": "Teacher-25"}, {"day": "Thursday", "room": "RKB-402", "batch": "64", "section": "A", "subject": "CSE-2231", "semester": 6, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 446, "version_key": 3, "subject_code": "CSE-2231", "teacher_code": "T59", "teacher_name": "Teacher-59"}, {"day": "Thursday", "room": "RAB-309", "batch": "64", "section": "D", "subject": "CSE-3213", "semester": 6, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 447, "version_key": 3, "subject_code": "CSE-3213", "teacher_code": "T51", "teacher_name": "Teacher-51"}, {"day": "Thursday", "room": "RAB-304", "batch": "64", "section": "G", "subject": "CSE-3115", "semester": 6, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 448, "version_key": 3, "subject_code": "CSE-3115", "teacher_code": "T70", "teacher_name": "Teacher-70"}, {"day": "Thursday", "room": "ACL-3", "batch": "64", "section": "H", "subject": "CSE-3212", "semester": 6, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 449, "version_key": 3, "subject_code": "CSE-3212", "teacher_code": "T21", "teacher_name": "Teacher-21"}, {"day": "Thursday", "room": "NL", "batch": "65", "section": "D", "subject": "CSE-3112", "semester": 5, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 450, "version_key": 3, "subject_code": "CSE-3112", "teacher_code": "T27", "teacher_name": "Teacher-27"}, {"day": "Thursday", "room": "ACL-1", "batch": "66", "section": "C", "subject": "CSE-2212", "semester": 4, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 451, "version_key": 3, "subject_code": "CSE-2212", "teacher_code": "T41", "teacher_name": "Teacher-41"}, {"day": "Thursday", "room": "RKB-303", "batch": "66", "section": "F", "subject": "CSE-2101", "semester": 4, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 452, "version_key": 3, "subject_code": "CSE-2101", "teacher_code": "T76", "teacher_name": "Teacher-76"}, {"day": "Thursday", "room": "RAB-401", "batch": "67", "section": "A", "subject": "CSE-2231", "semester": 3, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 453, "version_key": 3, "subject_code": "CSE-2231", "teacher_code": "T68", "teacher_name": "Teacher-68"}, {"day": "Thursday", "room": "RAB-111", "batch": "67", "section": "C", "subject": "EEE-1221", "semester": 3, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 454, "version_key": 3, "subject_code": "EEE-1221", "teacher_code": "T33", "teacher_name": "Teacher-33"}, {"day": "Thursday", "room": "RKB-103", "batch": "67", "section": "E", "subject": "EEE-1221", "semester": 3, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 455, "version_key": 3, "subject_code": "EEE-1221", "teacher_code": "T82", "teacher_name": "Teacher-82"}, {"day": "Thursday", "room": "RAB-302", "batch": "68", "section": "A", "subject": "CSE-1211", "semester": 2, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 456, "version_key": 3, "subject_code": "CSE-1211", "teacher_code": "T29", "teacher_name": "Teacher-29"}, {"day": "Thursday", "room": "RKB-407", "batch": "69", "section": "D", "subject": "CSE-1151", "semester": 1, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 457, "version_key": 3, "subject_code": "CSE-1151", "teacher_code": "T83", "teacher_name": "Teacher-83"}, {"day": "Thursday", "room": "G2", "batch": "69", "section": "F", "subject": "GED-1145", "semester": 1, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 458, "version_key": 3, "subject_code": "GED-1145", "teacher_code": "T53", "teacher_name": "Teacher-53"}, {"day": "Thursday", "room": "ACL-4", "batch": "69", "section": "I", "subject": "CSE-1102", "semester": 1, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 459, "version_key": 3, "subject_code": "CSE-1102", "teacher_code": "T57", "teacher_name": "Teacher-57"}, {"day": "Thursday", "room": "RKB-106", "batch": "61", "section": "B", "subject": "CSE-4267", "semester": 8, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 460, "version_key": 3, "subject_code": "CSE-4267", "teacher_code": "T66", "teacher_name": "Teacher-66"}, {"day": "Thursday", "room": "RKB-403", "batch": "62", "section": "A", "subject": "Research Methodology", "semester": 8, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 461, "version_key": 3, "subject_code": "GED-3213", "teacher_code": "T64", "teacher_name": "Teacher-64"}, {"day": "Thursday", "room": "RKB-103", "batch": "62", "section": "D", "subject": "CSE-4161", "semester": 8, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 462, "version_key": 3, "subject_code": "CSE-4161", "teacher_code": "T5", "teacher_name": "Teacher-5"}, {"day": "Thursday", "room": "RAB-309", "batch": "63", "section": "E", "subject": "CSE-4161", "semester": 7, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 463, "version_key": 3, "subject_code": "CSE-4161", "teacher_code": "T48", "teacher_name": "Teacher-48"}, {"day": "Thursday", "room": "ACL-3", "batch": "64", "section": "G", "subject": "CSE-3212", "semester": 6, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 464, "version_key": 3, "subject_code": "CSE-3212", "teacher_code": "T52", "teacher_name": "Teacher-52"}, {"day": "Thursday", "room": "RKB-404", "batch": "64", "section": "H", "subject": "CSE-3213", "semester": 6, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 465, "version_key": 3, "subject_code": "CSE-3213", "teacher_code": "T58", "teacher_name": "Teacher-58"}, {"day": "Thursday", "room": "RKB-402", "batch": "65", "section": "D", "subject": "GED-1261", "semester": 5, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 466, "version_key": 3, "subject_code": "GED-1261", "teacher_code": "T62", "teacher_name": "Teacher-62"}, {"day": "Thursday", "room": "RAB-306", "batch": "66", "section": "C", "subject": "CSE-2211", "semester": 4, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 467, "version_key": 3, "subject_code": "CSE-2211", "teacher_code": "T41", "teacher_name": "Teacher-41"}, {"day": "Thursday", "room": "ACL-4", "batch": "66", "section": "F", "subject": "CSE-2212", "semester": 4, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 468, "version_key": 3, "subject_code": "CSE-2212", "teacher_code": "T51", "teacher_name": "Teacher-51"}, {"day": "Thursday", "room": "RAB-304", "batch": "67", "section": "A", "subject": "CSE-2111", "semester": 3, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 469, "version_key": 3, "subject_code": "CSE-2111", "teacher_code": "T70", "teacher_name": "Teacher-70"}, {"day": "Thursday", "room": "RKB-407", "batch": "67", "section": "B", "subject": "CSE-2231", "semester": 3, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 470, "version_key": 3, "subject_code": "CSE-2231", "teacher_code": "T24", "teacher_name": "Teacher-24"}, {"day": "Thursday", "room": "RAB-302", "batch": "67", "section": "C", "subject": "MAT-2151", "semester": 3, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 471, "version_key": 3, "subject_code": "MAT-2151", "teacher_code": "T32", "teacher_name": "Teacher-32"}, {"day": "Thursday", "room": "ECL-1", "batch": "67", "section": "E", "subject": "EEE-1222", "semester": 3, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 472, "version_key": 3, "subject_code": "EEE-1222", "teacher_code": "T82", "teacher_name": "Teacher-82"}, {"day": "Thursday", "room": "ACL-1", "batch": "68", "section": "A", "subject": "CSE-1212", "semester": 2, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 473, "version_key": 3, "subject_code": "CSE-1212", "teacher_code": "T29", "teacher_name": "Teacher-29"}, {"day": "Thursday", "room": "RKB-303", "batch": "69", "section": "D", "subject": "GED-1145", "semester": 1, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 474, "version_key": 3, "subject_code": "GED-1145", "teacher_code": "T17", "teacher_name": "Teacher-17"}, {"day": "Thursday", "room": "G2", "batch": "69", "section": "F", "subject": "CSE-1101", "semester": 1, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 475, "version_key": 3, "subject_code": "CSE-1101", "teacher_code": "T30", "teacher_name": "Teacher-30"}, {"day": "Thursday", "room": "RAB-111", "batch": "69", "section": "H", "subject": "GED-1145", "semester": 1, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 476, "version_key": 3, "subject_code": "GED-1145", "teacher_code": "T53", "teacher_name": "Teacher-53"}, {"day": "Thursday", "room": "RAB-401", "batch": "69", "section": "I", "subject": "CSE-1101", "semester": 1, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 477, "version_key": 3, "subject_code": "CSE-1101", "teacher_code": "T16", "teacher_name": "Teacher-16"}, {"day": "Thursday", "room": "RKB-403", "batch": "61", "section": "A", "subject": "CSE-4135", "semester": 8, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 478, "version_key": 3, "subject_code": "CSE-4135", "teacher_code": "T49", "teacher_name": "Teacher-49"}, {"day": "Thursday", "room": "RKB-106", "batch": "62", "section": "D", "subject": "Operating System", "semester": 8, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 479, "version_key": 3, "subject_code": "CSE-4211", "teacher_code": "T41", "teacher_name": "Teacher-41"}, {"day": "Thursday", "room": "RKB-103", "batch": "62", "section": "F", "subject": "CSE-4161", "semester": 8, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 480, "version_key": 3, "subject_code": "CSE-4161", "teacher_code": "T18", "teacher_name": "Teacher-18"}, {"day": "Thursday", "room": "RAB-309", "batch": "63", "section": "E", "subject": "Research Methodology", "semester": 7, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 481, "version_key": 3, "subject_code": "GED-3213", "teacher_code": "T48", "teacher_name": "Teacher-48"}, {"day": "Thursday", "room": "ACL-3", "batch": "64", "section": "H", "subject": "CSE-3214", "semester": 6, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 482, "version_key": 3, "subject_code": "CSE-3214", "teacher_code": "T58", "teacher_name": "Teacher-58"}, {"day": "Thursday", "room": "RAB-306", "batch": "65", "section": "A", "subject": "CSE-2101", "semester": 5, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 483, "version_key": 3, "subject_code": "CSE-2101", "teacher_code": "T15", "teacher_name": "Teacher-15"}, {"day": "Thursday", "room": "RAB-111", "batch": "66", "section": "A", "subject": "GED-1201", "semester": 4, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 484, "version_key": 3, "subject_code": "GED-1201", "teacher_code": "T54", "teacher_name": "Teacher-54"}, {"day": "Thursday", "room": "RKB-303", "batch": "66", "section": "C", "subject": "EEE-1221", "semester": 4, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 485, "version_key": 3, "subject_code": "EEE-1221", "teacher_code": "T77", "teacher_name": "Teacher-77"}, {"day": "Thursday", "room": "RKB-402", "batch": "66", "section": "D", "subject": "CSE-2101", "semester": 4, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 486, "version_key": 3, "subject_code": "CSE-2101", "teacher_code": "T76", "teacher_name": "Teacher-76"}, {"day": "Thursday", "room": "RAB-304", "batch": "66", "section": "F", "subject": "CSE-2211", "semester": 4, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 487, "version_key": 3, "subject_code": "CSE-2211", "teacher_code": "T51", "teacher_name": "Teacher-51"}, {"day": "Thursday", "room": "RKB-404", "batch": "66", "section": "H", "subject": "EEE-1221", "semester": 4, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 488, "version_key": 3, "subject_code": "EEE-1221", "teacher_code": "T47", "teacher_name": "Teacher-47"}, {"day": "Thursday", "room": "ACL-1", "batch": "67", "section": "A", "subject": "CSE-2112", "semester": 3, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 489, "version_key": 3, "subject_code": "CSE-2112", "teacher_code": "T70", "teacher_name": "Teacher-70"}, {"day": "Thursday", "room": "RAB-302", "batch": "67", "section": "B", "subject": "MAT-2151", "semester": 3, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 490, "version_key": 3, "subject_code": "MAT-2151", "teacher_code": "T32", "teacher_name": "Teacher-32"}, {"day": "Thursday", "room": "G2", "batch": "67", "section": "D", "subject": "PHY-1171", "semester": 3, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 491, "version_key": 3, "subject_code": "PHY-1171", "teacher_code": "T46", "teacher_name": "Teacher-46"}, {"day": "Thursday", "room": "RAB-401", "batch": "69", "section": "H", "subject": "CSE-1101", "semester": 1, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 492, "version_key": 3, "subject_code": "CSE-1101", "teacher_code": "T68", "teacher_name": "Teacher-68"}, {"day": "Thursday", "room": "RKB-106", "batch": "61", "section": "A", "subject": "CSE-4267", "semester": 8, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 493, "version_key": 3, "subject_code": "CSE-4267", "teacher_code": "T66", "teacher_name": "Teacher-66"}, {"day": "Thursday", "room": "RKB-404", "batch": "61", "section": "E", "subject": "CSE-4135", "semester": 8, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 494, "version_key": 3, "subject_code": "CSE-4135", "teacher_code": "T49", "teacher_name": "Teacher-49"}, {"day": "Thursday", "room": "NL", "batch": "62", "section": "D", "subject": "Operating System Sessional", "semester": 8, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 495, "version_key": 3, "subject_code": "CSE-4212", "teacher_code": "T15", "teacher_name": "Teacher-15"}, {"day": "Thursday", "room": "RKB-402", "batch": "64", "section": "F", "subject": "CSE-3213", "semester": 6, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 496, "version_key": 3, "subject_code": "CSE-3213", "teacher_code": "T58", "teacher_name": "Teacher-58"}, {"day": "Thursday", "room": "RAB-302", "batch": "65", "section": "A", "subject": "CSE-3111", "semester": 5, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 497, "version_key": 3, "subject_code": "CSE-3111", "teacher_code": "T29", "teacher_name": "Teacher-29"}, {"day": "Thursday", "room": "RAB-306", "batch": "65", "section": "E+F", "subject": "CSE-3111", "semester": 5, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 498, "version_key": 3, "subject_code": "CSE-3111", "teacher_code": "T27", "teacher_name": "Teacher-27"}, {"day": "Thursday", "room": "RAB-304", "batch": "66", "section": "B", "subject": "MAT-2251", "semester": 4, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 499, "version_key": 3, "subject_code": "MAT-2251", "teacher_code": "T71", "teacher_name": "Teacher-71"}, {"day": "Thursday", "room": "RKB-103", "batch": "66", "section": "D", "subject": "GED-1201", "semester": 4, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 500, "version_key": 3, "subject_code": "GED-1201", "teacher_code": "T54", "teacher_name": "Teacher-54"}, {"day": "Thursday", "room": "ACL-4", "batch": "66", "section": "E", "subject": "CSE-2212", "semester": 4, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 501, "version_key": 3, "subject_code": "CSE-2212", "teacher_code": "T51", "teacher_name": "Teacher-51"}, {"day": "Thursday", "room": "RKB-303", "batch": "66", "section": "H", "subject": "CSE-2101", "semester": 4, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 502, "version_key": 3, "subject_code": "CSE-2101", "teacher_code": "T59", "teacher_name": "Teacher-59"}, {"day": "Thursday", "room": "RKB-407", "batch": "67", "section": "D", "subject": "EEE-1221", "semester": 3, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 503, "version_key": 3, "subject_code": "EEE-1221", "teacher_code": "T82", "teacher_name": "Teacher-82"}, {"day": "Thursday", "room": "RAB-111", "batch": "67", "section": "F+G", "subject": "MAT-2151", "semester": 3, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 504, "version_key": 3, "subject_code": "MAT-2151", "teacher_code": "T69", "teacher_name": "Teacher-69"}, {"day": "Thursday", "room": "ACL-1", "batch": "68", "section": "E", "subject": "CSE-1212", "semester": 2, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 505, "version_key": 3, "subject_code": "CSE-1212", "teacher_code": "T57", "teacher_name": "Teacher-57"}, {"day": "Thursday", "room": "RAB-401", "batch": "69", "section": "C", "subject": "CSE-1151", "semester": 1, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 506, "version_key": 3, "subject_code": "CSE-1151", "teacher_code": "T21", "teacher_name": "Teacher-21"}, {"day": "Thursday", "room": "RAB-309", "batch": "69", "section": "G", "subject": "CSE-1101", "semester": 1, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 507, "version_key": 3, "subject_code": "CSE-1101", "teacher_code": "T72", "teacher_name": "Teacher-72"}, {"day": "Thursday", "room": "G2", "batch": "69", "section": "J", "subject": "CSE-1151", "semester": 1, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 508, "version_key": 3, "subject_code": "CSE-1151", "teacher_code": "T83", "teacher_name": "Teacher-83"}, {"day": "Thursday", "room": "RKB-106", "batch": "61", "section": "A", "subject": "CSE-4267", "semester": 8, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 509, "version_key": 3, "subject_code": "CSE-4267", "teacher_code": "T66", "teacher_name": "Teacher-66"}, {"day": "Thursday", "room": "RKB-404", "batch": "61", "section": "E", "subject": "CSE-4203", "semester": 8, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 510, "version_key": 3, "subject_code": "CSE-4203", "teacher_code": "T3", "teacher_name": "Teacher-3"}, {"day": "Thursday", "room": "RAB-309", "batch": "64", "section": "F", "subject": "CSE-3115", "semester": 6, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 511, "version_key": 3, "subject_code": "CSE-3115", "teacher_code": "T5", "teacher_name": "Teacher-5"}, {"day": "Thursday", "room": "ACL-1", "batch": "65", "section": "A", "subject": "CSE-3112", "semester": 5, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 512, "version_key": 3, "subject_code": "CSE-3112", "teacher_code": "T29", "teacher_name": "Teacher-29"}, {"day": "Thursday", "room": "ACL-4", "batch": "65", "section": "E+F", "subject": "CSE-3112", "semester": 5, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 513, "version_key": 3, "subject_code": "CSE-3112", "teacher_code": "T27", "teacher_name": "Teacher-27"}, {"day": "Thursday", "room": "RAB-401", "batch": "66", "section": "A", "subject": "CSE-2101", "semester": 4, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 514, "version_key": 3, "subject_code": "CSE-2101", "teacher_code": "T15", "teacher_name": "Teacher-15"}, {"day": "Thursday", "room": "RKB-103", "batch": "66", "section": "B", "subject": "CSE-2101", "semester": 4, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 515, "version_key": 3, "subject_code": "CSE-2101", "teacher_code": "T76", "teacher_name": "Teacher-76"}, {"day": "Thursday", "room": "RKB-303", "batch": "66", "section": "D", "subject": "EEE-1221", "semester": 4, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 516, "version_key": 3, "subject_code": "EEE-1221", "teacher_code": "T77", "teacher_name": "Teacher-77"}, {"day": "Thursday", "room": "G2", "batch": "66", "section": "E", "subject": "CSE-2211", "semester": 4, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 517, "version_key": 3, "subject_code": "CSE-2211", "teacher_code": "T51", "teacher_name": "Teacher-51"}, {"day": "Thursday", "room": "RKB-407", "batch": "66", "section": "H", "subject": "CSE-2211", "semester": 4, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 518, "version_key": 3, "subject_code": "CSE-2211", "teacher_code": "T22", "teacher_name": "Teacher-22"}, {"day": "Thursday", "room": "ECL-1", "batch": "67", "section": "D", "subject": "EEE-1222", "semester": 3, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 519, "version_key": 3, "subject_code": "EEE-1222", "teacher_code": "T82", "teacher_name": "Teacher-82"}, {"day": "Thursday", "room": "RAB-111", "batch": "67", "section": "F+G", "subject": "CSE-2111", "semester": 3, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 520, "version_key": 3, "subject_code": "CSE-2111", "teacher_code": "T58", "teacher_name": "Teacher-58"}, {"day": "Thursday", "room": "RAB-304", "batch": "68", "section": "E", "subject": "CSE-1211", "semester": 2, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 521, "version_key": 3, "subject_code": "CSE-1211", "teacher_code": "T57", "teacher_name": "Teacher-57"}, {"day": "Thursday", "room": "RAB-302", "batch": "69", "section": "C", "subject": "MAT-1151", "semester": 1, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 522, "version_key": 3, "subject_code": "MAT-1151", "teacher_code": "T56", "teacher_name": "Teacher-56"}, {"day": "Thursday", "room": "RKB-402", "batch": "69", "section": "G", "subject": "GED-1131", "semester": 1, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 523, "version_key": 3, "subject_code": "GED-1131", "teacher_code": "T11", "teacher_name": "Teacher-11"}, {"day": "Thursday", "room": "ACL-3", "batch": "69", "section": "J", "subject": "CSE-1102", "semester": 1, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 524, "version_key": 3, "subject_code": "CSE-1102", "teacher_code": "T30", "teacher_name": "Teacher-30"}, {"day": "Thursday", "room": "RKB-403", "batch": "61", "section": "E", "subject": "CSE-4203", "semester": 8, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 525, "version_key": 3, "subject_code": "CSE-4203", "teacher_code": "T3", "teacher_name": "Teacher-3"}, {"day": "Thursday", "room": "RKB-106", "batch": "62", "section": "D", "subject": "Research Methodology", "semester": 8, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 526, "version_key": 3, "subject_code": "GED-3213", "teacher_code": "T49", "teacher_name": "Teacher-49"}, {"day": "Thursday", "room": "G2", "batch": "65", "section": "E+F", "subject": "CSE-3121", "semester": 5, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 527, "version_key": 3, "subject_code": "CSE-3121", "teacher_code": "T16", "teacher_name": "Teacher-16"}, {"day": "Thursday", "room": "RAB-306", "batch": "66", "section": "A", "subject": "MAT-2251", "semester": 4, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 528, "version_key": 3, "subject_code": "MAT-2251", "teacher_code": "T71", "teacher_name": "Teacher-71"}, {"day": "Thursday", "room": "RKB-103", "batch": "66", "section": "B", "subject": "GED-1201", "semester": 4, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 529, "version_key": 3, "subject_code": "GED-1201", "teacher_code": "T54", "teacher_name": "Teacher-54"}, {"day": "Thursday", "room": "RKB-303", "batch": "66", "section": "E", "subject": "CSE-2101", "semester": 4, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 530, "version_key": 3, "subject_code": "CSE-2101", "teacher_code": "T76", "teacher_name": "Teacher-76"}, {"day": "Thursday", "room": "ACL-1", "batch": "66", "section": "H", "subject": "CSE-2212", "semester": 4, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 531, "version_key": 3, "subject_code": "CSE-2212", "teacher_code": "T22", "teacher_name": "Teacher-22"}, {"day": "Thursday", "room": "RAB-401", "batch": "67", "section": "D", "subject": "CSE-2231", "semester": 3, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 532, "version_key": 3, "subject_code": "CSE-2231", "teacher_code": "T5", "teacher_name": "Teacher-5"}, {"day": "Thursday", "room": "ACL-3", "batch": "67", "section": "F+G", "subject": "CSE-2112", "semester": 3, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 533, "version_key": 3, "subject_code": "CSE-2112", "teacher_code": "T58", "teacher_name": "Teacher-58"}, {"day": "Thursday", "room": "ACL-4", "batch": "69", "section": "G", "subject": "CSE-1102", "semester": 1, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 534, "version_key": 3, "subject_code": "CSE-1102", "teacher_code": "T57", "teacher_name": "Teacher-57"}, {"day": "Thursday", "room": "RAB-111", "batch": "69", "section": "J", "subject": "GED-1145", "semester": 1, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 535, "version_key": 3, "subject_code": "GED-1145", "teacher_code": "T53", "teacher_name": "Teacher-53"}, {"day": "Thursday", "room": "ACL-4", "batch": "62", "section": "E", "subject": "CSE-3232", "semester": 8, "time_end": "20:20:00", "is_active": true, "is_service": false, "time_start": "19:00:00", "fixture_row": 536, "version_key": 3, "subject_code": "CSE-3232", "teacher_code": "T48", "teacher_name": "Teacher-48"}, {"day": "Thursday", "room": "ACL-1", "batch": "66", "section": "H", "subject": "CSE-2212", "semester": 4, "time_end": "20:20:00", "is_active": true, "is_service": false, "time_start": "19:00:00", "fixture_row": 537, "version_key": 3, "subject_code": "CSE-2212", "teacher_code": "T65", "teacher_name": "Teacher-65"}, {"day": "Tuesday", "room": "RAB-111", "batch": "61", "section": "B", "subject": "CSE-4203", "semester": 8, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 538, "version_key": 3, "subject_code": "CSE-4203", "teacher_code": "T12", "teacher_name": "Teacher-12"}, {"day": "Tuesday", "room": "RKB-106", "batch": "61", "section": "C", "subject": "CSE-4135", "semester": 8, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 539, "version_key": 3, "subject_code": "CSE-4135", "teacher_code": "T61", "teacher_name": "Teacher-61"}, {"day": "Tuesday", "room": "RAB-302", "batch": "63", "section": "A", "subject": "Research Methodology", "semester": 7, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 540, "version_key": 3, "subject_code": "GED-3213", "teacher_code": "T29", "teacher_name": "Teacher-29"}, {"day": "Tuesday", "room": "RKB-404", "batch": "63", "section": "B", "subject": "GED-1116", "semester": 7, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 541, "version_key": 3, "subject_code": "GED-1116", "teacher_code": "T7", "teacher_name": "Teacher-7"}, {"day": "Tuesday", "room": "ACL-1", "batch": "64", "section": "A", "subject": "CSE-3116", "semester": 6, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 542, "version_key": 3, "subject_code": "CSE-3116", "teacher_code": "T49", "teacher_name": "Teacher-49"}, {"day": "Tuesday", "room": "RKB-403", "batch": "64", "section": "C", "subject": "GED-1291", "semester": 6, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 543, "version_key": 3, "subject_code": "GED-1291", "teacher_code": "T39", "teacher_name": "Teacher-39"}, {"day": "Tuesday", "room": "RKB-407", "batch": "64", "section": "I", "subject": "CSE-3115", "semester": 6, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 544, "version_key": 3, "subject_code": "CSE-3115", "teacher_code": "T22", "teacher_name": "Teacher-22"}, {"day": "Tuesday", "room": "RKB-402", "batch": "65", "section": "C", "subject": "GED-1261", "semester": 5, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 545, "version_key": 3, "subject_code": "GED-1261", "teacher_code": "T78", "teacher_name": "Teacher-78"}, {"day": "Tuesday", "room": "ECL-1", "batch": "67", "section": "C", "subject": "EEE-1222", "semester": 3, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 546, "version_key": 3, "subject_code": "EEE-1222", "teacher_code": "T33", "teacher_name": "Teacher-33"}, {"day": "Tuesday", "room": "RKB-303", "batch": "67", "section": "D", "subject": "PHY-1171", "semester": 3, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 547, "version_key": 3, "subject_code": "PHY-1171", "teacher_code": "T46", "teacher_name": "Teacher-46"}, {"day": "Tuesday", "room": "RAB-401", "batch": "68", "section": "B", "subject": "CHE-1161", "semester": 2, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 548, "version_key": 3, "subject_code": "CHE-1161", "teacher_code": "T2", "teacher_name": "Teacher-2"}, {"day": "Tuesday", "room": "RKB-103", "batch": "68", "section": "E", "subject": "GED-1201", "semester": 2, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 549, "version_key": 3, "subject_code": "GED-1201", "teacher_code": "T13", "teacher_name": "Teacher-13"}, {"day": "Tuesday", "room": "G2", "batch": "69", "section": "B", "subject": "GED-1145", "semester": 1, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 550, "version_key": 3, "subject_code": "GED-1145", "teacher_code": "T17", "teacher_name": "Teacher-17"}, {"day": "Tuesday", "room": "ACL-4", "batch": "69", "section": "C", "subject": "CSE-1102", "semester": 1, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 551, "version_key": 3, "subject_code": "CSE-1102", "teacher_code": "T20", "teacher_name": "Teacher-20"}, {"day": "Tuesday", "room": "RAB-304", "batch": "69", "section": "E", "subject": "MAT-1151", "semester": 1, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 552, "version_key": 3, "subject_code": "MAT-1151", "teacher_code": "T69", "teacher_name": "Teacher-69"}, {"day": "Tuesday", "room": "ACL-3", "batch": "69", "section": "F", "subject": "CSE-1102", "semester": 1, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 553, "version_key": 3, "subject_code": "CSE-1102", "teacher_code": "T37", "teacher_name": "Teacher-37"}, {"day": "Tuesday", "room": "RAB-306", "batch": "69", "section": "G", "subject": "GED-1145", "semester": 1, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 554, "version_key": 3, "subject_code": "GED-1145", "teacher_code": "T53", "teacher_name": "Teacher-53"}, {"day": "Tuesday", "room": "RAB-309", "batch": "69", "section": "H", "subject": "GED-1131", "semester": 1, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 555, "version_key": 3, "subject_code": "GED-1131", "teacher_code": "T14", "teacher_name": "Teacher-14"}, {"day": "Tuesday", "room": "RKB-106", "batch": "61", "section": "C", "subject": "CSE-4267", "semester": 8, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 556, "version_key": 3, "subject_code": "CSE-4267", "teacher_code": "T8", "teacher_name": "Teacher-8"}, {"day": "Tuesday", "room": "NL", "batch": "61", "section": "D", "subject": "CSE-4268", "semester": 8, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 557, "version_key": 3, "subject_code": "CSE-4268", "teacher_code": "T4", "teacher_name": "Teacher-4"}, {"day": "Tuesday", "room": "RKB-403", "batch": "62", "section": "B", "subject": "Operating System", "semester": 8, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 558, "version_key": 3, "subject_code": "CSE-4211", "teacher_code": "T41", "teacher_name": "Teacher-41"}, {"day": "Tuesday", "room": "RKB-103", "batch": "63", "section": "A", "subject": "GED-1116", "semester": 7, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 559, "version_key": 3, "subject_code": "GED-1116", "teacher_code": "T7", "teacher_name": "Teacher-7"}, {"day": "Tuesday", "room": "RAB-302", "batch": "63", "section": "B", "subject": "Research Methodology", "semester": 7, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 560, "version_key": 3, "subject_code": "GED-3213", "teacher_code": "T61", "teacher_name": "Teacher-61"}, {"day": "Tuesday", "room": "ACL-3", "batch": "64", "section": "A", "subject": "CSE-3212", "semester": 6, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 561, "version_key": 3, "subject_code": "CSE-3212", "teacher_code": "T52", "teacher_name": "Teacher-52"}, {"day": "Tuesday", "room": "RAB-306", "batch": "64", "section": "B", "subject": "CSE-3213", "semester": 6, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 562, "version_key": 3, "subject_code": "CSE-3213", "teacher_code": "T67", "teacher_name": "Teacher-67"}, {"day": "Tuesday", "room": "RAB-309", "batch": "64", "section": "C", "subject": "CSE-3115", "semester": 6, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 563, "version_key": 3, "subject_code": "CSE-3115", "teacher_code": "T55", "teacher_name": "Teacher-55"}, {"day": "Tuesday", "room": "ACL-1", "batch": "64", "section": "I", "subject": "CSE-3116", "semester": 6, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 564, "version_key": 3, "subject_code": "CSE-3116", "teacher_code": "T22", "teacher_name": "Teacher-22"}, {"day": "Tuesday", "room": "ECL-1", "batch": "65", "section": "A", "subject": "EEE-2122", "semester": 5, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 565, "version_key": 3, "subject_code": "EEE-2122", "teacher_code": "T23", "teacher_name": "Teacher-23"}, {"day": "Tuesday", "room": "RKB-407", "batch": "65", "section": "C", "subject": "EEE-2121", "semester": 5, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 566, "version_key": 3, "subject_code": "EEE-2121", "teacher_code": "T40", "teacher_name": "Teacher-40"}, {"day": "Tuesday", "room": "RKB-402", "batch": "67", "section": "C", "subject": "EEE-1221", "semester": 3, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 567, "version_key": 3, "subject_code": "EEE-1221", "teacher_code": "T33", "teacher_name": "Teacher-33"}, {"day": "Tuesday", "room": "PHY LAB", "batch": "67", "section": "D", "subject": "PHY-1272", "semester": 3, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 568, "version_key": 3, "subject_code": "PHY-1272", "teacher_code": "T46", "teacher_name": "Teacher-46"}, {"day": "Tuesday", "room": "RKB-404", "batch": "68", "section": "C", "subject": "CHE-1161", "semester": 2, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 569, "version_key": 3, "subject_code": "CHE-1161", "teacher_code": "T2", "teacher_name": "Teacher-2"}, {"day": "Tuesday", "room": "RKB-303", "batch": "68", "section": "F", "subject": "MAT-1251", "semester": 2, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 570, "version_key": 3, "subject_code": "MAT-1251", "teacher_code": "T38", "teacher_name": "Teacher-38"}, {"day": "Tuesday", "room": "RAB-304", "batch": "69", "section": "B", "subject": "CSE-1151", "semester": 1, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 571, "version_key": 3, "subject_code": "CSE-1151", "teacher_code": "T21", "teacher_name": "Teacher-21"}, {"day": "Tuesday", "room": "RAB-401", "batch": "69", "section": "C", "subject": "GED-1131", "semester": 1, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 572, "version_key": 3, "subject_code": "GED-1131", "teacher_code": "T14", "teacher_name": "Teacher-14"}, {"day": "Tuesday", "room": "G2", "batch": "69", "section": "E", "subject": "GED-1145", "semester": 1, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 573, "version_key": 3, "subject_code": "GED-1145", "teacher_code": "T17", "teacher_name": "Teacher-17"}, {"day": "Tuesday", "room": "RAB-111", "batch": "69", "section": "F", "subject": "GED-1145", "semester": 1, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 574, "version_key": 3, "subject_code": "GED-1145", "teacher_code": "T53", "teacher_name": "Teacher-53"}, {"day": "Tuesday", "room": "ACL-4", "batch": "69", "section": "G", "subject": "CSE-1102", "semester": 1, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 575, "version_key": 3, "subject_code": "CSE-1102", "teacher_code": "T57", "teacher_name": "Teacher-57"}, {"day": "Tuesday", "room": "NL", "batch": "61", "section": "B", "subject": "CSE-4135", "semester": 8, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 576, "version_key": 3, "subject_code": "CSE-4135", "teacher_code": "T49", "teacher_name": "Teacher-49"}, {"day": "Tuesday", "room": "RKB-106", "batch": "61", "section": "C", "subject": "CSE-4267", "semester": 8, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 577, "version_key": 3, "subject_code": "CSE-4267", "teacher_code": "T8", "teacher_name": "Teacher-8"}, {"day": "Tuesday", "room": "RKB-103", "batch": "61", "section": "D", "subject": "CSE-4135", "semester": 8, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 578, "version_key": 3, "subject_code": "CSE-4135", "teacher_code": "T61", "teacher_name": "Teacher-61"}, {"day": "Tuesday", "room": "ACL-2", "batch": "62", "section": "B", "subject": "Operating System Sessional", "semester": 8, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 579, "version_key": 3, "subject_code": "CSE-4212", "teacher_code": "T24", "teacher_name": "Teacher-24"}, {"day": "Tuesday", "room": "RKB-403", "batch": "62", "section": "C", "subject": "Operating System", "semester": 8, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 580, "version_key": 3, "subject_code": "CSE-4211", "teacher_code": "T41", "teacher_name": "Teacher-41"}, {"day": "Tuesday", "room": "RAB-304", "batch": "63", "section": "A", "subject": "CSE-4161", "semester": 7, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 581, "version_key": 3, "subject_code": "CSE-4161", "teacher_code": "T25", "teacher_name": "Teacher-25"}, {"day": "Tuesday", "room": "ACL-4", "batch": "64", "section": "B", "subject": "CSE-3214", "semester": 6, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 582, "version_key": 3, "subject_code": "CSE-3214", "teacher_code": "T67", "teacher_name": "Teacher-67"}, {"day": "Tuesday", "room": "ACL-1", "batch": "64", "section": "C", "subject": "CSE-3116", "semester": 6, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 583, "version_key": 3, "subject_code": "CSE-3116", "teacher_code": "T55", "teacher_name": "Teacher-55"}, {"day": "Tuesday", "room": "RKB-407", "batch": "65", "section": "A", "subject": "EEE-2121", "semester": 5, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 584, "version_key": 3, "subject_code": "EEE-2121", "teacher_code": "T23", "teacher_name": "Teacher-23"}, {"day": "Tuesday", "room": "ECL-1", "batch": "65", "section": "C", "subject": "EEE-2122", "semester": 5, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 585, "version_key": 3, "subject_code": "EEE-2122", "teacher_code": "T77", "teacher_name": "Teacher-77"}, {"day": "Tuesday", "room": "ACL-3", "batch": "67", "section": "B", "subject": "GED-1262", "semester": 3, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 586, "version_key": 3, "subject_code": "GED-1262", "teacher_code": "T50", "teacher_name": "Teacher-50"}, {"day": "Tuesday", "room": "RAB-302", "batch": "67", "section": "C", "subject": "MAT-2151", "semester": 3, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 587, "version_key": 3, "subject_code": "MAT-2151", "teacher_code": "T32", "teacher_name": "Teacher-32"}, {"day": "Tuesday", "room": "PHY LAB", "batch": "67", "section": "D", "subject": "PHY-1272", "semester": 3, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 588, "version_key": 3, "subject_code": "PHY-1272", "teacher_code": "T46", "teacher_name": "Teacher-46"}, {"day": "Tuesday", "room": "RKB-402", "batch": "68", "section": "B", "subject": "GED-2181", "semester": 2, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 589, "version_key": 3, "subject_code": "GED-2181", "teacher_code": "T75", "teacher_name": "Teacher-75"}, {"day": "Tuesday", "room": "RAB-306", "batch": "68", "section": "C", "subject": "CSE-1211", "semester": 2, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 590, "version_key": 3, "subject_code": "CSE-1211", "teacher_code": "T34", "teacher_name": "Teacher-34"}, {"day": "Tuesday", "room": "RKB-404", "batch": "68", "section": "E", "subject": "MAT-1251", "semester": 2, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 591, "version_key": 3, "subject_code": "MAT-1251", "teacher_code": "T38", "teacher_name": "Teacher-38"}, {"day": "Tuesday", "room": "RAB-309", "batch": "69", "section": "C", "subject": "GED-1145", "semester": 1, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 592, "version_key": 3, "subject_code": "GED-1145", "teacher_code": "T17", "teacher_name": "Teacher-17"}, {"day": "Tuesday", "room": "G2", "batch": "69", "section": "F", "subject": "GED-1131", "semester": 1, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 593, "version_key": 3, "subject_code": "GED-1131", "teacher_code": "T14", "teacher_name": "Teacher-14"}, {"day": "Tuesday", "room": "RAB-401", "batch": "69", "section": "G", "subject": "MAT-1151", "semester": 1, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 594, "version_key": 3, "subject_code": "MAT-1151", "teacher_code": "T69", "teacher_name": "Teacher-69"}, {"day": "Tuesday", "room": "RAB-111", "batch": "69", "section": "H", "subject": "MAT-1151", "semester": 1, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 595, "version_key": 3, "subject_code": "MAT-1151", "teacher_code": "T36", "teacher_name": "Teacher-36"}, {"day": "Tuesday", "room": "RKB-303", "batch": "69", "section": "J", "subject": "GED-1145", "semester": 1, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 596, "version_key": 3, "subject_code": "GED-1145", "teacher_code": "T53", "teacher_name": "Teacher-53"}, {"day": "Tuesday", "room": "NL", "batch": "61", "section": "E", "subject": "CSE-4268", "semester": 8, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 597, "version_key": 3, "subject_code": "CSE-4268", "teacher_code": "T55", "teacher_name": "Teacher-55"}, {"day": "Tuesday", "room": "RKB-403", "batch": "62", "section": "B", "subject": "CSE-4161", "semester": 8, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 598, "version_key": 3, "subject_code": "CSE-4161", "teacher_code": "T4", "teacher_name": "Teacher-4"}, {"day": "Tuesday", "room": "ACL-2", "batch": "62", "section": "C", "subject": "Operating System Sessional", "semester": 8, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 599, "version_key": 3, "subject_code": "CSE-4212", "teacher_code": "T24", "teacher_name": "Teacher-24"}, {"day": "Tuesday", "room": "ACL-3", "batch": "64", "section": "B", "subject": "CSE-3212", "semester": 6, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 600, "version_key": 3, "subject_code": "CSE-3212", "teacher_code": "T52", "teacher_name": "Teacher-52"}, {"day": "Tuesday", "room": "RAB-304", "batch": "64", "section": "E", "subject": "CSE-3213", "semester": 6, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 601, "version_key": 3, "subject_code": "CSE-3213", "teacher_code": "T67", "teacher_name": "Teacher-67"}, {"day": "Tuesday", "room": "ACL-4", "batch": "64", "section": "F", "subject": "CSE-3116", "semester": 6, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 602, "version_key": 3, "subject_code": "CSE-3116", "teacher_code": "T5", "teacher_name": "Teacher-5"}, {"day": "Tuesday", "room": "RKB-404", "batch": "65", "section": "A", "subject": "CSE-3121", "semester": 5, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 603, "version_key": 3, "subject_code": "CSE-3121", "teacher_code": "T12", "teacher_name": "Teacher-12"}, {"day": "Tuesday", "room": "RKB-407", "batch": "65", "section": "B", "subject": "GED-1261", "semester": 5, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 604, "version_key": 3, "subject_code": "GED-1261", "teacher_code": "T78", "teacher_name": "Teacher-78"}, {"day": "Tuesday", "room": "RAB-306", "batch": "66", "section": "D", "subject": "MAT-2251", "semester": 4, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 605, "version_key": 3, "subject_code": "MAT-2251", "teacher_code": "T60", "teacher_name": "Teacher-60"}, {"day": "Tuesday", "room": "RAB-302", "batch": "67", "section": "B", "subject": "MAT-2151", "semester": 3, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 606, "version_key": 3, "subject_code": "MAT-2151", "teacher_code": "T32", "teacher_name": "Teacher-32"}, {"day": "Tuesday", "room": "G2", "batch": "68", "section": "A", "subject": "CHE-1161", "semester": 2, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 607, "version_key": 3, "subject_code": "CHE-1161", "teacher_code": "T2", "teacher_name": "Teacher-2"}, {"day": "Tuesday", "room": "RAB-111", "batch": "68", "section": "B", "subject": "GED-1201", "semester": 2, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 608, "version_key": 3, "subject_code": "GED-1201", "teacher_code": "T54", "teacher_name": "Teacher-54"}, {"day": "Tuesday", "room": "ACL-1", "batch": "68", "section": "C", "subject": "CSE-1212", "semester": 2, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 609, "version_key": 3, "subject_code": "CSE-1212", "teacher_code": "T34", "teacher_name": "Teacher-34"}, {"day": "Tuesday", "room": "RKB-103", "batch": "68", "section": "E", "subject": "GED-1231", "semester": 2, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 610, "version_key": 3, "subject_code": "GED-1231", "teacher_code": "T11", "teacher_name": "Teacher-11"}, {"day": "Tuesday", "room": "RKB-303", "batch": "68", "section": "F", "subject": "GED-1201", "semester": 2, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 611, "version_key": 3, "subject_code": "GED-1201", "teacher_code": "T13", "teacher_name": "Teacher-13"}, {"day": "Tuesday", "room": "RKB-402", "batch": "69", "section": "H", "subject": "GED-1145", "semester": 1, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 612, "version_key": 3, "subject_code": "GED-1145", "teacher_code": "T53", "teacher_name": "Teacher-53"}, {"day": "Tuesday", "room": "RAB-309", "batch": "69", "section": "I", "subject": "CSE-1151", "semester": 1, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 613, "version_key": 3, "subject_code": "CSE-1151", "teacher_code": "T22", "teacher_name": "Teacher-22"}, {"day": "Tuesday", "room": "RAB-401", "batch": "69", "section": "J", "subject": "MAT-1151", "semester": 1, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 614, "version_key": 3, "subject_code": "MAT-1151", "teacher_code": "T36", "teacher_name": "Teacher-36"}, {"day": "Tuesday", "room": "RKB-403", "batch": "61", "section": "E", "subject": "CSE-4135", "semester": 8, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 615, "version_key": 3, "subject_code": "CSE-4135", "teacher_code": "T49", "teacher_name": "Teacher-49"}, {"day": "Tuesday", "room": "RKB-106", "batch": "62", "section": "C", "subject": "CSE-4161", "semester": 8, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 616, "version_key": 3, "subject_code": "CSE-4161", "teacher_code": "T5", "teacher_name": "Teacher-5"}, {"day": "Tuesday", "room": "NL", "batch": "62", "section": "F", "subject": "Operating System Sessional", "semester": 8, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 617, "version_key": 3, "subject_code": "CSE-4212", "teacher_code": "T68", "teacher_name": "Teacher-68"}, {"day": "Tuesday", "room": "RAB-304", "batch": "63", "section": "D", "subject": "MAT-2251", "semester": 7, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 618, "version_key": 3, "subject_code": "MAT-2251", "teacher_code": "T9", "teacher_name": "Teacher-9"}, {"day": "Tuesday", "room": "RAB-309", "batch": "64", "section": "B", "subject": "CSE-3115", "semester": 6, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 619, "version_key": 3, "subject_code": "CSE-3115", "teacher_code": "T55", "teacher_name": "Teacher-55"}, {"day": "Tuesday", "room": "ACL-3", "batch": "64", "section": "E", "subject": "CSE-3214", "semester": 6, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 620, "version_key": 3, "subject_code": "CSE-3214", "teacher_code": "T67", "teacher_name": "Teacher-67"}, {"day": "Tuesday", "room": "RAB-302", "batch": "65", "section": "B", "subject": "CSE-3111", "semester": 5, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 621, "version_key": 3, "subject_code": "CSE-3111", "teacher_code": "T29", "teacher_name": "Teacher-29"}, {"day": "Tuesday", "room": "ECL-1", "batch": "65", "section": "D", "subject": "EEE-2122", "semester": 5, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 622, "version_key": 3, "subject_code": "EEE-2122", "teacher_code": "T23", "teacher_name": "Teacher-23"}, {"day": "Tuesday", "room": "RKB-407", "batch": "65", "section": "E+F", "subject": "EEE-2121", "semester": 5, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 623, "version_key": 3, "subject_code": "EEE-2121", "teacher_code": "T40", "teacher_name": "Teacher-40"}, {"day": "Tuesday", "room": "ACL-1", "batch": "66", "section": "D", "subject": "CSE-2212", "semester": 4, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 624, "version_key": 3, "subject_code": "CSE-2212", "teacher_code": "T41", "teacher_name": "Teacher-41"}, {"day": "Tuesday", "room": "RKB-402", "batch": "66", "section": "E", "subject": "MAT-2251", "semester": 4, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 625, "version_key": 3, "subject_code": "MAT-2251", "teacher_code": "T60", "teacher_name": "Teacher-60"}, {"day": "Tuesday", "room": "RKB-404", "batch": "66", "section": "H", "subject": "GED-1201", "semester": 4, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 626, "version_key": 3, "subject_code": "GED-1201", "teacher_code": "T13", "teacher_name": "Teacher-13"}, {"day": "Tuesday", "room": "RKB-103", "batch": "67", "section": "B", "subject": "EEE-1221", "semester": 3, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 627, "version_key": 3, "subject_code": "EEE-1221", "teacher_code": "T77", "teacher_name": "Teacher-77"}, {"day": "Tuesday", "room": "RKB-303", "batch": "67", "section": "F+G", "subject": "PHY-1171", "semester": 3, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 628, "version_key": 3, "subject_code": "PHY-1171", "teacher_code": "T46", "teacher_name": "Teacher-46"}, {"day": "Tuesday", "room": "G2", "batch": "68", "section": "A", "subject": "GED-1201", "semester": 2, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 629, "version_key": 3, "subject_code": "GED-1201", "teacher_code": "T54", "teacher_name": "Teacher-54"}, {"day": "Tuesday", "room": "ACL-4", "batch": "68", "section": "D", "subject": "CSE-1212", "semester": 2, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 630, "version_key": 3, "subject_code": "CSE-1212", "teacher_code": "T37", "teacher_name": "Teacher-37"}, {"day": "Tuesday", "room": "RAB-111", "batch": "68", "section": "F", "subject": "GED-1231", "semester": 2, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 631, "version_key": 3, "subject_code": "GED-1231", "teacher_code": "T11", "teacher_name": "Teacher-11"}, {"day": "Tuesday", "room": "RAB-306", "batch": "69", "section": "A", "subject": "GED-1145", "semester": 1, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 632, "version_key": 3, "subject_code": "GED-1145", "teacher_code": "T17", "teacher_name": "Teacher-17"}, {"day": "Tuesday", "room": "RAB-401", "batch": "69", "section": "D", "subject": "MAT-1151", "semester": 1, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 633, "version_key": 3, "subject_code": "MAT-1151", "teacher_code": "T69", "teacher_name": "Teacher-69"}, {"day": "Tuesday", "room": "NL", "batch": "61", "section": "A", "subject": "CSE-4268", "semester": 8, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 634, "version_key": 3, "subject_code": "CSE-4268", "teacher_code": "T66", "teacher_name": "Teacher-66"}, {"day": "Tuesday", "room": "RKB-106", "batch": "62", "section": "F", "subject": "Operating System", "semester": 8, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 635, "version_key": 3, "subject_code": "CSE-4211", "teacher_code": "T68", "teacher_name": "Teacher-68"}, {"day": "Tuesday", "room": "RKB-403", "batch": "62", "section": "G", "subject": "Research Methodology", "semester": 8, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 636, "version_key": 3, "subject_code": "GED-3213", "teacher_code": "T61", "teacher_name": "Teacher-61"}, {"day": "Tuesday", "room": "ACL-4", "batch": "63", "section": "D", "subject": "CSE-3232", "semester": 7, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 637, "version_key": 3, "subject_code": "CSE-3232", "teacher_code": "T25", "teacher_name": "Teacher-25"}, {"day": "Tuesday", "room": "ACL-1", "batch": "64", "section": "B", "subject": "CSE-3116", "semester": 6, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 638, "version_key": 3, "subject_code": "CSE-3116", "teacher_code": "T55", "teacher_name": "Teacher-55"}, {"day": "Tuesday", "room": "ACL-3", "batch": "64", "section": "E", "subject": "CSE-3116", "semester": 6, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 639, "version_key": 3, "subject_code": "CSE-3116", "teacher_code": "T5", "teacher_name": "Teacher-5"}, {"day": "Tuesday", "room": "RKB-404", "batch": "64", "section": "F", "subject": "GED-1291", "semester": 6, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 640, "version_key": 3, "subject_code": "GED-1291", "teacher_code": "T39", "teacher_name": "Teacher-39"}, {"day": "Tuesday", "room": "ACL-2", "batch": "65", "section": "B", "subject": "CSE-3112", "semester": 5, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 641, "version_key": 3, "subject_code": "CSE-3112", "teacher_code": "T29", "teacher_name": "Teacher-29"}, {"day": "Tuesday", "room": "RKB-402", "batch": "65", "section": "D", "subject": "EEE-2121", "semester": 5, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 642, "version_key": 3, "subject_code": "EEE-2121", "teacher_code": "T23", "teacher_name": "Teacher-23"}, {"day": "Tuesday", "room": "RKB-407", "batch": "65", "section": "E+F", "subject": "MAT-3151", "semester": 5, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 643, "version_key": 3, "subject_code": "MAT-3151", "teacher_code": "T73", "teacher_name": "Teacher-73"}, {"day": "Tuesday", "room": "RAB-304", "batch": "66", "section": "D", "subject": "CSE-2211", "semester": 4, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 644, "version_key": 3, "subject_code": "CSE-2211", "teacher_code": "T41", "teacher_name": "Teacher-41"}, {"day": "Tuesday", "room": "RKB-303", "batch": "66", "section": "E", "subject": "EEE-1221", "semester": 4, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 645, "version_key": 3, "subject_code": "EEE-1221", "teacher_code": "T74", "teacher_name": "Teacher-74"}, {"day": "Tuesday", "room": "ECL-1", "batch": "67", "section": "B", "subject": "EEE-1222", "semester": 3, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 646, "version_key": 3, "subject_code": "EEE-1222", "teacher_code": "T33", "teacher_name": "Teacher-33"}, {"day": "Tuesday", "room": "RKB-103", "batch": "67", "section": "F+G", "subject": "EEE-1221", "semester": 3, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 647, "version_key": 3, "subject_code": "EEE-1221", "teacher_code": "T82", "teacher_name": "Teacher-82"}, {"day": "Tuesday", "room": "G2", "batch": "68", "section": "A", "subject": "GED-1231", "semester": 2, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 648, "version_key": 3, "subject_code": "GED-1231", "teacher_code": "T11", "teacher_name": "Teacher-11"}, {"day": "Tuesday", "room": "RAB-302", "batch": "68", "section": "D", "subject": "CSE-1211", "semester": 2, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 649, "version_key": 3, "subject_code": "CSE-1211", "teacher_code": "T37", "teacher_name": "Teacher-37"}, {"day": "Tuesday", "room": "RAB-306", "batch": "69", "section": "A", "subject": "CSE-1151", "semester": 1, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 650, "version_key": 3, "subject_code": "CSE-1151", "teacher_code": "T21", "teacher_name": "Teacher-21"}, {"day": "Tuesday", "room": "RAB-309", "batch": "69", "section": "D", "subject": "GED-1145", "semester": 1, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 651, "version_key": 3, "subject_code": "GED-1145", "teacher_code": "T17", "teacher_name": "Teacher-17"}, {"day": "Tuesday", "room": "RAB-401", "batch": "69", "section": "I", "subject": "MAT-1151", "semester": 1, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 652, "version_key": 3, "subject_code": "MAT-1151", "teacher_code": "T36", "teacher_name": "Teacher-36"}, {"day": "Tuesday", "room": "RAB-306", "batch": "61", "section": "A", "subject": "CSE-4203", "semester": 8, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 653, "version_key": 3, "subject_code": "CSE-4203", "teacher_code": "T12", "teacher_name": "Teacher-12"}, {"day": "Tuesday", "room": "RKB-103", "batch": "62", "section": "E", "subject": "Research Methodology", "semester": 8, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 654, "version_key": 3, "subject_code": "GED-3213", "teacher_code": "T49", "teacher_name": "Teacher-49"}, {"day": "Tuesday", "room": "RKB-403", "batch": "62", "section": "G", "subject": "Operating System", "semester": 8, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 655, "version_key": 3, "subject_code": "CSE-4211", "teacher_code": "T30", "teacher_name": "Teacher-30"}, {"day": "Tuesday", "room": "RAB-309", "batch": "63", "section": "D", "subject": "CSE-4135", "semester": 7, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 656, "version_key": 3, "subject_code": "CSE-4135", "teacher_code": "T18", "teacher_name": "Teacher-18"}, {"day": "Tuesday", "room": "RAB-302", "batch": "64", "section": "E", "subject": "CSE-3115", "semester": 6, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 657, "version_key": 3, "subject_code": "CSE-3115", "teacher_code": "T5", "teacher_name": "Teacher-5"}, {"day": "Tuesday", "room": "NL", "batch": "64", "section": "F", "subject": "CSE-3212", "semester": 6, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 658, "version_key": 3, "subject_code": "CSE-3212", "teacher_code": "T21", "teacher_name": "Teacher-21"}, {"day": "Tuesday", "room": "RKB-106", "batch": "65", "section": "D", "subject": "MAT-3151", "semester": 5, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 659, "version_key": 3, "subject_code": "MAT-3151", "teacher_code": "T73", "teacher_name": "Teacher-73"}, {"day": "Tuesday", "room": "RAB-304", "batch": "65", "section": "E+F", "subject": "CSE-2101", "semester": 5, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 660, "version_key": 3, "subject_code": "CSE-2101", "teacher_code": "T79", "teacher_name": "Teacher-79"}, {"day": "Tuesday", "room": "G2", "batch": "66", "section": "D", "subject": "GED-1201", "semester": 4, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 661, "version_key": 3, "subject_code": "GED-1201", "teacher_code": "T54", "teacher_name": "Teacher-54"}, {"day": "Tuesday", "room": "RAB-111", "batch": "66", "section": "E", "subject": "CSE-2101", "semester": 4, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 662, "version_key": 3, "subject_code": "CSE-2101", "teacher_code": "T76", "teacher_name": "Teacher-76"}, {"day": "Tuesday", "room": "RKB-303", "batch": "66", "section": "H", "subject": "MAT-2251", "semester": 4, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 663, "version_key": 3, "subject_code": "MAT-2251", "teacher_code": "T36", "teacher_name": "Teacher-36"}, {"day": "Tuesday", "room": "RAB-401", "batch": "67", "section": "F+G", "subject": "MAT-2151", "semester": 3, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 664, "version_key": 3, "subject_code": "MAT-2151", "teacher_code": "T69", "teacher_name": "Teacher-69"}, {"day": "Tuesday", "room": "ACL-4", "batch": "69", "section": "D", "subject": "CSE-1102", "semester": 1, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 665, "version_key": 3, "subject_code": "CSE-1102", "teacher_code": "T37", "teacher_name": "Teacher-37"}, {"day": "Tuesday", "room": "ACL-3", "batch": "69", "section": "I", "subject": "CSE-1102", "semester": 1, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 666, "version_key": 3, "subject_code": "CSE-1102", "teacher_code": "T57", "teacher_name": "Teacher-57"}, {"day": "Tuesday", "room": "Phy Lab", "batch": "67", "section": "F+G", "subject": "PHY-1272", "semester": 3, "time_end": "20:20:00", "is_active": true, "is_service": false, "time_start": "19:00:00", "fixture_row": 667, "version_key": 3, "subject_code": "PHY-1272", "teacher_code": "T43", "teacher_name": "Teacher-43"}, {"day": "Wednesday", "room": "RKB-106", "batch": "61", "section": "D", "subject": "CSE-4135", "semester": 8, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 668, "version_key": 3, "subject_code": "CSE-4135", "teacher_code": "T61", "teacher_name": "Teacher-61"}, {"day": "Wednesday", "room": "RKB-403", "batch": "62", "section": "B", "subject": "Operating System", "semester": 8, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 669, "version_key": 3, "subject_code": "CSE-4211", "teacher_code": "T41", "teacher_name": "Teacher-41"}, {"day": "Wednesday", "room": "NL", "batch": "62", "section": "D", "subject": "Operating System Sessional", "semester": 8, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 670, "version_key": 3, "subject_code": "CSE-4212", "teacher_code": "T15", "teacher_name": "Teacher-15"}, {"day": "Wednesday", "room": "RAB-304", "batch": "63", "section": "B", "subject": "CSE-4161", "semester": 7, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 671, "version_key": 3, "subject_code": "CSE-4161", "teacher_code": "T25", "teacher_name": "Teacher-25"}, {"day": "Wednesday", "room": "RAB-306", "batch": "63", "section": "E", "subject": "CSE-4135", "semester": 7, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 672, "version_key": 3, "subject_code": "CSE-4135", "teacher_code": "T3", "teacher_name": "Teacher-3"}, {"day": "Wednesday", "room": "RAB-302", "batch": "64", "section": "B", "subject": "CSE-2231", "semester": 6, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 673, "version_key": 3, "subject_code": "CSE-2231", "teacher_code": "T70", "teacher_name": "Teacher-70"}, {"day": "Wednesday", "room": "RAB-401", "batch": "64", "section": "D", "subject": "CSE-3115", "semester": 6, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 674, "version_key": 3, "subject_code": "CSE-3115", "teacher_code": "T22", "teacher_name": "Teacher-22"}, {"day": "Wednesday", "room": "ECL-1", "batch": "65", "section": "B", "subject": "EEE-2122", "semester": 5, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 675, "version_key": 3, "subject_code": "EEE-2122", "teacher_code": "T23", "teacher_name": "Teacher-23"}, {"day": "Wednesday", "room": "RAB-309", "batch": "66", "section": "B", "subject": "CSE-2211", "semester": 4, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 676, "version_key": 3, "subject_code": "CSE-2211", "teacher_code": "T8", "teacher_name": "Teacher-8"}, {"day": "Wednesday", "room": "RKB-404", "batch": "66", "section": "G", "subject": "GED-1201", "semester": 4, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 677, "version_key": 3, "subject_code": "GED-1201", "teacher_code": "T13", "teacher_name": "Teacher-13"}, {"day": "Wednesday", "room": "RKB-407", "batch": "67", "section": "B", "subject": "PHY-1171", "semester": 3, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 678, "version_key": 3, "subject_code": "PHY-1171", "teacher_code": "T43", "teacher_name": "Teacher-43"}, {"day": "Wednesday", "room": "ACL-1", "batch": "68", "section": "A", "subject": "CSE-1212", "semester": 2, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 679, "version_key": 3, "subject_code": "CSE-1212", "teacher_code": "T29", "teacher_name": "Teacher-29"}, {"day": "Wednesday", "room": "RKB-402", "batch": "68", "section": "C", "subject": "GED-2181", "semester": 2, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 680, "version_key": 3, "subject_code": "GED-2181", "teacher_code": "T75", "teacher_name": "Teacher-75"}, {"day": "Wednesday", "room": "ACL-3", "batch": "68", "section": "F", "subject": "CSE-1212", "semester": 2, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 681, "version_key": 3, "subject_code": "CSE-1212", "teacher_code": "T57", "teacher_name": "Teacher-57"}, {"day": "Wednesday", "room": "RAB-111", "batch": "69", "section": "C", "subject": "GED-1145", "semester": 1, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 682, "version_key": 3, "subject_code": "GED-1145", "teacher_code": "T17", "teacher_name": "Teacher-17"}, {"day": "Wednesday", "room": "ACL-4", "batch": "69", "section": "D", "subject": "CSE-1102", "semester": 1, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 683, "version_key": 3, "subject_code": "CSE-1102", "teacher_code": "T37", "teacher_name": "Teacher-37"}, {"day": "Wednesday", "room": "G2", "batch": "69", "section": "F", "subject": "GED-1131", "semester": 1, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 684, "version_key": 3, "subject_code": "GED-1131", "teacher_code": "T14", "teacher_name": "Teacher-14"}, {"day": "Wednesday", "room": "RKB-103", "batch": "69", "section": "G", "subject": "GED-1131", "semester": 1, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 685, "version_key": 3, "subject_code": "GED-1131", "teacher_code": "T11", "teacher_name": "Teacher-11"}, {"day": "Wednesday", "room": "RKB-303", "batch": "69", "section": "J", "subject": "MAT-1151", "semester": 1, "time_end": "10:05:00", "is_active": true, "is_service": false, "time_start": "09:00:00", "fixture_row": 686, "version_key": 3, "subject_code": "MAT-1151", "teacher_code": "T36", "teacher_name": "Teacher-36"}, {"day": "Wednesday", "room": "NL", "batch": "61", "section": "D", "subject": "CSE-4268", "semester": 8, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 687, "version_key": 3, "subject_code": "CSE-4268", "teacher_code": "T4", "teacher_name": "Teacher-4"}, {"day": "Wednesday", "room": "RKB-403", "batch": "62", "section": "B", "subject": "Research Methodology", "semester": 8, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 688, "version_key": 3, "subject_code": "GED-3213", "teacher_code": "T42", "teacher_name": "Teacher-42"}, {"day": "Wednesday", "room": "RKB-106", "batch": "62", "section": "D", "subject": "Operating System", "semester": 8, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 689, "version_key": 3, "subject_code": "CSE-4211", "teacher_code": "T41", "teacher_name": "Teacher-41"}, {"day": "Wednesday", "room": "RAB-306", "batch": "63", "section": "B", "subject": "CSE-3231", "semester": 7, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 690, "version_key": 3, "subject_code": "CSE-3231", "teacher_code": "T34", "teacher_name": "Teacher-34"}, {"day": "Wednesday", "room": "RKB-407", "batch": "63", "section": "E", "subject": "GED-1116", "semester": 7, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 691, "version_key": 3, "subject_code": "GED-1116", "teacher_code": "T7", "teacher_name": "Teacher-7"}, {"day": "Wednesday", "room": "RKB-404", "batch": "64", "section": "B", "subject": "GED-1291", "semester": 6, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 692, "version_key": 3, "subject_code": "GED-1291", "teacher_code": "T26", "teacher_name": "Teacher-26"}, {"day": "Wednesday", "room": "ACL-3", "batch": "64", "section": "D", "subject": "CSE-3116", "semester": 6, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 693, "version_key": 3, "subject_code": "CSE-3116", "teacher_code": "T49", "teacher_name": "Teacher-49"}, {"day": "Wednesday", "room": "RKB-402", "batch": "65", "section": "B", "subject": "EEE-2121", "semester": 5, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 694, "version_key": 3, "subject_code": "EEE-2121", "teacher_code": "T23", "teacher_name": "Teacher-23"}, {"day": "Wednesday", "room": "ACL-1", "batch": "66", "section": "B", "subject": "CSE-2212", "semester": 4, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 695, "version_key": 3, "subject_code": "CSE-2212", "teacher_code": "T8", "teacher_name": "Teacher-8"}, {"day": "Wednesday", "room": "ECL-1", "batch": "66", "section": "G", "subject": "EEE-1222", "semester": 4, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 696, "version_key": 3, "subject_code": "EEE-1222", "teacher_code": "T74", "teacher_name": "Teacher-74"}, {"day": "Wednesday", "room": "PHY LAB", "batch": "67", "section": "B", "subject": "PHY-1272", "semester": 3, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 697, "version_key": 3, "subject_code": "PHY-1272", "teacher_code": "T43", "teacher_name": "Teacher-43"}, {"day": "Wednesday", "room": "RAB-304", "batch": "68", "section": "A", "subject": "CSE-1211", "semester": 2, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 698, "version_key": 3, "subject_code": "CSE-1211", "teacher_code": "T29", "teacher_name": "Teacher-29"}, {"day": "Wednesday", "room": "RKB-303", "batch": "68", "section": "C", "subject": "GED-1231", "semester": 2, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 699, "version_key": 3, "subject_code": "GED-1231", "teacher_code": "T11", "teacher_name": "Teacher-11"}, {"day": "Wednesday", "room": "RAB-309", "batch": "68", "section": "F", "subject": "CSE-1211", "semester": 2, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 700, "version_key": 3, "subject_code": "CSE-1211", "teacher_code": "T57", "teacher_name": "Teacher-57"}, {"day": "Wednesday", "room": "RAB-302", "batch": "69", "section": "C", "subject": "MAT-1151", "semester": 1, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 701, "version_key": 3, "subject_code": "MAT-1151", "teacher_code": "T56", "teacher_name": "Teacher-56"}, {"day": "Wednesday", "room": "RAB-401", "batch": "69", "section": "D", "subject": "CSE-1151", "semester": 1, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 702, "version_key": 3, "subject_code": "CSE-1151", "teacher_code": "T83", "teacher_name": "Teacher-83"}, {"day": "Wednesday", "room": "G2", "batch": "69", "section": "F", "subject": "MAT-1151", "semester": 1, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 703, "version_key": 3, "subject_code": "MAT-1151", "teacher_code": "T69", "teacher_name": "Teacher-69"}, {"day": "Wednesday", "room": "RAB-111", "batch": "69", "section": "G", "subject": "GED-1145", "semester": 1, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 704, "version_key": 3, "subject_code": "GED-1145", "teacher_code": "T53", "teacher_name": "Teacher-53"}, {"day": "Wednesday", "room": "RKB-103", "batch": "69", "section": "J", "subject": "GED-1131", "semester": 1, "time_end": "11:10:00", "is_active": true, "is_service": false, "time_start": "10:05:00", "fixture_row": 705, "version_key": 3, "subject_code": "GED-1131", "teacher_code": "T28", "teacher_name": "Teacher-28"}, {"day": "Wednesday", "room": "NL", "batch": "61", "section": "C", "subject": "CSE-4268", "semester": 8, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 706, "version_key": 3, "subject_code": "CSE-4268", "teacher_code": "T8", "teacher_name": "Teacher-8"}, {"day": "Wednesday", "room": "RKB-403", "batch": "61", "section": "D", "subject": "CSE-4203", "semester": 8, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 707, "version_key": 3, "subject_code": "CSE-4203", "teacher_code": "T76", "teacher_name": "Teacher-76"}, {"day": "Wednesday", "room": "ACL-2", "batch": "62", "section": "B", "subject": "Operating System Sessional", "semester": 8, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 708, "version_key": 3, "subject_code": "CSE-4212", "teacher_code": "T24", "teacher_name": "Teacher-24"}, {"day": "Wednesday", "room": "RKB-106", "batch": "62", "section": "C", "subject": "Operating System", "semester": 8, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 709, "version_key": 3, "subject_code": "CSE-4211", "teacher_code": "T41", "teacher_name": "Teacher-41"}, {"day": "Wednesday", "room": "ACL-1", "batch": "63", "section": "B", "subject": "CSE-3232", "semester": 7, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 710, "version_key": 3, "subject_code": "CSE-3232", "teacher_code": "T34", "teacher_name": "Teacher-34"}, {"day": "Wednesday", "room": "RAB-401", "batch": "63", "section": "E", "subject": "MAT-2251", "semester": 7, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 711, "version_key": 3, "subject_code": "MAT-2251", "teacher_code": "T9", "teacher_name": "Teacher-9"}, {"day": "Wednesday", "room": "G2", "batch": "64", "section": "B", "subject": "CSE-3213", "semester": 6, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 712, "version_key": 3, "subject_code": "CSE-3213", "teacher_code": "T67", "teacher_name": "Teacher-67"}, {"day": "Wednesday", "room": "RAB-306", "batch": "64", "section": "G", "subject": "CSE-3115", "semester": 6, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 713, "version_key": 3, "subject_code": "CSE-3115", "teacher_code": "T70", "teacher_name": "Teacher-70"}, {"day": "Wednesday", "room": "RKB-404", "batch": "65", "section": "A", "subject": "GED-1261", "semester": 5, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 714, "version_key": 3, "subject_code": "GED-1261", "teacher_code": "T19", "teacher_name": "Teacher-19"}, {"day": "Wednesday", "room": "ECL-1", "batch": "66", "section": "B", "subject": "EEE-1222", "semester": 4, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 715, "version_key": 3, "subject_code": "EEE-1222", "teacher_code": "T77", "teacher_name": "Teacher-77"}, {"day": "Wednesday", "room": "RAB-309", "batch": "66", "section": "G", "subject": "CSE-2211", "semester": 4, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 716, "version_key": 3, "subject_code": "CSE-2211", "teacher_code": "T51", "teacher_name": "Teacher-51"}, {"day": "Wednesday", "room": "PHY LAB", "batch": "67", "section": "B", "subject": "PHY-1272", "semester": 3, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 717, "version_key": 3, "subject_code": "PHY-1272", "teacher_code": "T43", "teacher_name": "Teacher-43"}, {"day": "Wednesday", "room": "RAB-304", "batch": "67", "section": "E", "subject": "MAT-2151", "semester": 3, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 718, "version_key": 3, "subject_code": "MAT-2151", "teacher_code": "T32", "teacher_name": "Teacher-32"}, {"day": "Wednesday", "room": "RAB-302", "batch": "68", "section": "A", "subject": "MAT-1251", "semester": 2, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 719, "version_key": 3, "subject_code": "MAT-1251", "teacher_code": "T56", "teacher_name": "Teacher-56"}, {"day": "Wednesday", "room": "RKB-402", "batch": "68", "section": "C", "subject": "GED-1201", "semester": 2, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 720, "version_key": 3, "subject_code": "GED-1201", "teacher_code": "T54", "teacher_name": "Teacher-54"}, {"day": "Wednesday", "room": "RKB-407", "batch": "68", "section": "D", "subject": "GED-1231", "semester": 2, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 721, "version_key": 3, "subject_code": "GED-1231", "teacher_code": "T11", "teacher_name": "Teacher-11"}, {"day": "Wednesday", "room": "RAB-111", "batch": "69", "section": "C", "subject": "CSE-1151", "semester": 1, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 722, "version_key": 3, "subject_code": "CSE-1151", "teacher_code": "T21", "teacher_name": "Teacher-21"}, {"day": "Wednesday", "room": "RKB-103", "batch": "69", "section": "D", "subject": "GED-1131", "semester": 1, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 723, "version_key": 3, "subject_code": "GED-1131", "teacher_code": "T14", "teacher_name": "Teacher-14"}, {"day": "Wednesday", "room": "ACL-4", "batch": "69", "section": "F", "subject": "CSE-1102", "semester": 1, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 724, "version_key": 3, "subject_code": "CSE-1102", "teacher_code": "T37", "teacher_name": "Teacher-37"}, {"day": "Wednesday", "room": "RKB-303", "batch": "69", "section": "G", "subject": "CSE-1151", "semester": 1, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 725, "version_key": 3, "subject_code": "CSE-1151", "teacher_code": "T83", "teacher_name": "Teacher-83"}, {"day": "Wednesday", "room": "ACL-3", "batch": "69", "section": "J", "subject": "CSE-1102", "semester": 1, "time_end": "00:15:00", "is_active": true, "is_service": false, "time_start": "11:10:00", "fixture_row": 726, "version_key": 3, "subject_code": "CSE-1102", "teacher_code": "T30", "teacher_name": "Teacher-30"}, {"day": "Wednesday", "room": "ACL-2", "batch": "61", "section": "C", "subject": "CSE-4203", "semester": 8, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 727, "version_key": 3, "subject_code": "CSE-4203", "teacher_code": "T76", "teacher_name": "Teacher-76"}, {"day": "Wednesday", "room": "RKB-403", "batch": "62", "section": "B", "subject": "CSE-4161", "semester": 8, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 728, "version_key": 3, "subject_code": "CSE-4161", "teacher_code": "T4", "teacher_name": "Teacher-4"}, {"day": "Wednesday", "room": "NL", "batch": "62", "section": "C", "subject": "Operating System Sessional", "semester": 8, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 729, "version_key": 3, "subject_code": "CSE-4212", "teacher_code": "T24", "teacher_name": "Teacher-24"}, {"day": "Wednesday", "room": "RKB-106", "batch": "62", "section": "D", "subject": "Research Methodology", "semester": 8, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 730, "version_key": 3, "subject_code": "GED-3213", "teacher_code": "T49", "teacher_name": "Teacher-49"}, {"day": "Wednesday", "room": "RAB-304", "batch": "64", "section": "A", "subject": "CSE-3213", "semester": 6, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 731, "version_key": 3, "subject_code": "CSE-3213", "teacher_code": "T6", "teacher_name": "Teacher-6"}, {"day": "Wednesday", "room": "ACL-3", "batch": "64", "section": "B", "subject": "CSE-3214", "semester": 6, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 732, "version_key": 3, "subject_code": "CSE-3214", "teacher_code": "T67", "teacher_name": "Teacher-67"}, {"day": "Wednesday", "room": "ACL-1", "batch": "64", "section": "G", "subject": "CSE-3116", "semester": 6, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 733, "version_key": 3, "subject_code": "CSE-3116", "teacher_code": "T70", "teacher_name": "Teacher-70"}, {"day": "Wednesday", "room": "RAB-306", "batch": "65", "section": "A", "subject": "CSE-3111", "semester": 5, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 734, "version_key": 3, "subject_code": "CSE-3111", "teacher_code": "T29", "teacher_name": "Teacher-29"}, {"day": "Wednesday", "room": "RAB-309", "batch": "65", "section": "B", "subject": "CSE-2101", "semester": 5, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 735, "version_key": 3, "subject_code": "CSE-2101", "teacher_code": "T15", "teacher_name": "Teacher-15"}, {"day": "Wednesday", "room": "RAB-401", "batch": "66", "section": "A", "subject": "MAT-2251", "semester": 4, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 736, "version_key": 3, "subject_code": "MAT-2251", "teacher_code": "T71", "teacher_name": "Teacher-71"}, {"day": "Wednesday", "room": "RKB-404", "batch": "66", "section": "B", "subject": "EEE-1221", "semester": 4, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 737, "version_key": 3, "subject_code": "EEE-1221", "teacher_code": "T40", "teacher_name": "Teacher-40"}, {"day": "Wednesday", "room": "RKB-407", "batch": "66", "section": "C", "subject": "GED-1201", "semester": 4, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 738, "version_key": 3, "subject_code": "GED-1201", "teacher_code": "T54", "teacher_name": "Teacher-54"}, {"day": "Wednesday", "room": "ECL-1", "batch": "66", "section": "D", "subject": "EEE-1222", "semester": 4, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 739, "version_key": 3, "subject_code": "EEE-1222", "teacher_code": "T74", "teacher_name": "Teacher-74"}, {"day": "Wednesday", "room": "ACL-4", "batch": "66", "section": "G", "subject": "CSE-2212", "semester": 4, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 740, "version_key": 3, "subject_code": "CSE-2212", "teacher_code": "T51", "teacher_name": "Teacher-51"}, {"day": "Wednesday", "room": "RAB-302", "batch": "67", "section": "D", "subject": "MAT-2151", "semester": 3, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 741, "version_key": 3, "subject_code": "MAT-2151", "teacher_code": "T32", "teacher_name": "Teacher-32"}, {"day": "Wednesday", "room": "RKB-402", "batch": "67", "section": "E", "subject": "PHY-1171", "semester": 3, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 742, "version_key": 3, "subject_code": "PHY-1171", "teacher_code": "T46", "teacher_name": "Teacher-46"}, {"day": "Wednesday", "room": "RKB-103", "batch": "68", "section": "D", "subject": "GED-2181", "semester": 2, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 743, "version_key": 3, "subject_code": "GED-2181", "teacher_code": "T75", "teacher_name": "Teacher-75"}, {"day": "Wednesday", "room": "RKB-303", "batch": "68", "section": "E", "subject": "GED-1201", "semester": 2, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 744, "version_key": 3, "subject_code": "GED-1201", "teacher_code": "T13", "teacher_name": "Teacher-13"}, {"day": "Wednesday", "room": "G2", "batch": "69", "section": "I", "subject": "GED-1145", "semester": 1, "time_end": "13:20:00", "is_active": true, "is_service": false, "time_start": "12:15:00", "fixture_row": 745, "version_key": 3, "subject_code": "GED-1145", "teacher_code": "T53", "teacher_name": "Teacher-53"}, {"day": "Wednesday", "room": "RKB-106", "batch": "62", "section": "D", "subject": "CSE-4161", "semester": 8, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 746, "version_key": 3, "subject_code": "CSE-4161", "teacher_code": "T5", "teacher_name": "Teacher-5"}, {"day": "Wednesday", "room": "NL", "batch": "62", "section": "I", "subject": "Operating System Sessional", "semester": 8, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 747, "version_key": 3, "subject_code": "CSE-4212", "teacher_code": "T58", "teacher_name": "Teacher-58"}, {"day": "Wednesday", "room": "RKB-407", "batch": "63", "section": "A", "subject": "CSE-4135", "semester": 7, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 748, "version_key": 3, "subject_code": "CSE-4135", "teacher_code": "T18", "teacher_name": "Teacher-18"}, {"day": "Wednesday", "room": "ACL-1", "batch": "63", "section": "C", "subject": "CSE-3232", "semester": 7, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 749, "version_key": 3, "subject_code": "CSE-3232", "teacher_code": "T34", "teacher_name": "Teacher-34"}, {"day": "Wednesday", "room": "RAB-304", "batch": "64", "section": "A", "subject": "CSE-3115", "semester": 6, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 750, "version_key": 3, "subject_code": "CSE-3115", "teacher_code": "T49", "teacher_name": "Teacher-49"}, {"day": "Wednesday", "room": "ACL-3", "batch": "64", "section": "G", "subject": "CSE-3214", "semester": 6, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 751, "version_key": 3, "subject_code": "CSE-3214", "teacher_code": "T67", "teacher_name": "Teacher-67"}, {"day": "Wednesday", "room": "RKB-403", "batch": "64", "section": "I", "subject": "CSE-3213", "semester": 6, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 752, "version_key": 3, "subject_code": "CSE-3213", "teacher_code": "T12", "teacher_name": "Teacher-12"}, {"day": "Wednesday", "room": "ACL-4", "batch": "65", "section": "A", "subject": "CSE-3112", "semester": 5, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 753, "version_key": 3, "subject_code": "CSE-3112", "teacher_code": "T29", "teacher_name": "Teacher-29"}, {"day": "Wednesday", "room": "RAB-306", "batch": "65", "section": "E+F", "subject": "CSE-3111", "semester": 5, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 754, "version_key": 3, "subject_code": "CSE-3111", "teacher_code": "T27", "teacher_name": "Teacher-27"}, {"day": "Wednesday", "room": "RAB-309", "batch": "66", "section": "A", "subject": "CSE-2211", "semester": 4, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 755, "version_key": 3, "subject_code": "CSE-2211", "teacher_code": "T8", "teacher_name": "Teacher-8"}, {"day": "Wednesday", "room": "RAB-401", "batch": "66", "section": "C", "subject": "CSE-2211", "semester": 4, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 756, "version_key": 3, "subject_code": "CSE-2211", "teacher_code": "T41", "teacher_name": "Teacher-41"}, {"day": "Wednesday", "room": "RKB-404", "batch": "66", "section": "D", "subject": "EEE-1221", "semester": 4, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 757, "version_key": 3, "subject_code": "EEE-1221", "teacher_code": "T77", "teacher_name": "Teacher-77"}, {"day": "Wednesday", "room": "RKB-402", "batch": "67", "section": "A", "subject": "EEE-1221", "semester": 3, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 758, "version_key": 3, "subject_code": "EEE-1221", "teacher_code": "T33", "teacher_name": "Teacher-33"}, {"day": "Wednesday", "room": "PHY LAB", "batch": "67", "section": "E", "subject": "PHY-1272", "semester": 3, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 759, "version_key": 3, "subject_code": "PHY-1272", "teacher_code": "T46", "teacher_name": "Teacher-46"}, {"day": "Wednesday", "room": "ECL-1", "batch": "67", "section": "F+G", "subject": "EEE-1222", "semester": 3, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 760, "version_key": 3, "subject_code": "EEE-1222", "teacher_code": "T82", "teacher_name": "Teacher-82"}, {"day": "Wednesday", "room": "RAB-302", "batch": "68", "section": "B", "subject": "MAT-1251", "semester": 2, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 761, "version_key": 3, "subject_code": "MAT-1251", "teacher_code": "T56", "teacher_name": "Teacher-56"}, {"day": "Wednesday", "room": "G2", "batch": "68", "section": "D", "subject": "GED-1201", "semester": 2, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 762, "version_key": 3, "subject_code": "GED-1201", "teacher_code": "T13", "teacher_name": "Teacher-13"}, {"day": "Wednesday", "room": "RKB-303", "batch": "68", "section": "E", "subject": "GED-1231", "semester": 2, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 763, "version_key": 3, "subject_code": "GED-1231", "teacher_code": "T11", "teacher_name": "Teacher-11"}, {"day": "Wednesday", "room": "RAB-111", "batch": "69", "section": "H", "subject": "GED-1131", "semester": 1, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 764, "version_key": 3, "subject_code": "GED-1131", "teacher_code": "T14", "teacher_name": "Teacher-14"}, {"day": "Wednesday", "room": "RKB-103", "batch": "69", "section": "I", "subject": "GED-1131", "semester": 1, "time_end": "14:55:00", "is_active": true, "is_service": false, "time_start": "13:50:00", "fixture_row": 765, "version_key": 3, "subject_code": "GED-1131", "teacher_code": "T28", "teacher_name": "Teacher-28"}, {"day": "Wednesday", "room": "RKB-106", "batch": "62", "section": "C", "subject": "Research Methodology", "semester": 8, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 766, "version_key": 3, "subject_code": "GED-3213", "teacher_code": "T66", "teacher_name": "Teacher-66"}, {"day": "Wednesday", "room": "RKB-103", "batch": "62", "section": "F", "subject": "Research Methodology", "semester": 8, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 767, "version_key": 3, "subject_code": "GED-3213", "teacher_code": "T61", "teacher_name": "Teacher-61"}, {"day": "Wednesday", "room": "RKB-403", "batch": "62", "section": "I", "subject": "Operating System", "semester": 8, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 768, "version_key": 3, "subject_code": "CSE-4211", "teacher_code": "T58", "teacher_name": "Teacher-58"}, {"day": "Wednesday", "room": "RKB-407", "batch": "63", "section": "A", "subject": "GED-1116", "semester": 7, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 769, "version_key": 3, "subject_code": "GED-1116", "teacher_code": "T7", "teacher_name": "Teacher-7"}, {"day": "Wednesday", "room": "RAB-302", "batch": "63", "section": "C", "subject": "CSE-3231", "semester": 7, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 770, "version_key": 3, "subject_code": "CSE-3231", "teacher_code": "T25", "teacher_name": "Teacher-25"}, {"day": "Wednesday", "room": "RKB-404", "batch": "64", "section": "A", "subject": "GED-1291", "semester": 6, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 771, "version_key": 3, "subject_code": "GED-1291", "teacher_code": "T26", "teacher_name": "Teacher-26"}, {"day": "Wednesday", "room": "RAB-304", "batch": "64", "section": "G", "subject": "CSE-3213", "semester": 6, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 772, "version_key": 3, "subject_code": "CSE-3213", "teacher_code": "T67", "teacher_name": "Teacher-67"}, {"day": "Wednesday", "room": "ACL-4", "batch": "64", "section": "I", "subject": "CSE-3212", "semester": 6, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 773, "version_key": 3, "subject_code": "CSE-3212", "teacher_code": "T21", "teacher_name": "Teacher-21"}, {"day": "Wednesday", "room": "RKB-402", "batch": "65", "section": "E+F", "subject": "GED-1261", "semester": 5, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 774, "version_key": 3, "subject_code": "GED-1261", "teacher_code": "T62", "teacher_name": "Teacher-62"}, {"day": "Wednesday", "room": "ACL-1", "batch": "66", "section": "A", "subject": "CSE-2212", "semester": 4, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 775, "version_key": 3, "subject_code": "CSE-2212", "teacher_code": "T8", "teacher_name": "Teacher-8"}, {"day": "Wednesday", "room": "ACL-2", "batch": "66", "section": "C", "subject": "CSE-2212", "semester": 4, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 776, "version_key": 3, "subject_code": "CSE-2212", "teacher_code": "T41", "teacher_name": "Teacher-41"}, {"day": "Wednesday", "room": "RKB-303", "batch": "66", "section": "D", "subject": "CSE-2101", "semester": 4, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 777, "version_key": 3, "subject_code": "CSE-2101", "teacher_code": "T76", "teacher_name": "Teacher-76"}, {"day": "Wednesday", "room": "ECL-1", "batch": "67", "section": "A", "subject": "EEE-1222", "semester": 3, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 778, "version_key": 3, "subject_code": "EEE-1222", "teacher_code": "T33", "teacher_name": "Teacher-33"}, {"day": "Wednesday", "room": "ACL-3", "batch": "67", "section": "D", "subject": "GED-1262", "semester": 3, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 779, "version_key": 3, "subject_code": "GED-1262", "teacher_code": "T80", "teacher_name": "Teacher-80"}, {"day": "Wednesday", "room": "PHY LAB", "batch": "67", "section": "E", "subject": "PHY-1272", "semester": 3, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 780, "version_key": 3, "subject_code": "PHY-1272", "teacher_code": "T46", "teacher_name": "Teacher-46"}, {"day": "Wednesday", "room": "RAB-111", "batch": "67", "section": "F+G", "subject": "EEE-1221", "semester": 3, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 781, "version_key": 3, "subject_code": "EEE-1221", "teacher_code": "T82", "teacher_name": "Teacher-82"}, {"day": "Wednesday", "room": "RAB-401", "batch": "68", "section": "B", "subject": "GED-1201", "semester": 2, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 782, "version_key": 3, "subject_code": "GED-1201", "teacher_code": "T54", "teacher_name": "Teacher-54"}, {"day": "Wednesday", "room": "G2", "batch": "68", "section": "E", "subject": "GED-2181", "semester": 2, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 783, "version_key": 3, "subject_code": "GED-2181", "teacher_code": "T75", "teacher_name": "Teacher-75"}, {"day": "Wednesday", "room": "RAB-309", "batch": "69", "section": "H", "subject": "CSE-1151", "semester": 1, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 784, "version_key": 3, "subject_code": "CSE-1151", "teacher_code": "T83", "teacher_name": "Teacher-83"}, {"day": "Wednesday", "room": "RAB-306", "batch": "69", "section": "I", "subject": "CSE-1151", "semester": 1, "time_end": "16:00:00", "is_active": true, "is_service": false, "time_start": "14:55:00", "fixture_row": 785, "version_key": 3, "subject_code": "CSE-1151", "teacher_code": "T22", "teacher_name": "Teacher-22"}, {"day": "Wednesday", "room": "RKB-403", "batch": "62", "section": "F", "subject": "CSE-4161", "semester": 8, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 786, "version_key": 3, "subject_code": "CSE-4161", "teacher_code": "T18", "teacher_name": "Teacher-18"}, {"day": "Wednesday", "room": "RKB-103", "batch": "63", "section": "C", "subject": "GED-1116", "semester": 7, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 787, "version_key": 3, "subject_code": "GED-1116", "teacher_code": "T7", "teacher_name": "Teacher-7"}, {"day": "Wednesday", "room": "ACL-1", "batch": "64", "section": "A", "subject": "CSE-3214", "semester": 6, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 788, "version_key": 3, "subject_code": "CSE-3214", "teacher_code": "T6", "teacher_name": "Teacher-6"}, {"day": "Wednesday", "room": "RAB-401", "batch": "64", "section": "G", "subject": "CSE-2231", "semester": 6, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 789, "version_key": 3, "subject_code": "CSE-2231", "teacher_code": "T79", "teacher_name": "Teacher-79"}, {"day": "Wednesday", "room": "ACL-2", "batch": "65", "section": "E+F", "subject": "CSE-3112", "semester": 5, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 790, "version_key": 3, "subject_code": "CSE-3112", "teacher_code": "T27", "teacher_name": "Teacher-27"}, {"day": "Wednesday", "room": "RAB-304", "batch": "66", "section": "A", "subject": "CSE-2101", "semester": 4, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 791, "version_key": 3, "subject_code": "CSE-2101", "teacher_code": "T15", "teacher_name": "Teacher-15"}, {"day": "Wednesday", "room": "RAB-309", "batch": "66", "section": "C", "subject": "CSE-2101", "semester": 4, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 792, "version_key": 3, "subject_code": "CSE-2101", "teacher_code": "T76", "teacher_name": "Teacher-76"}, {"day": "Wednesday", "room": "G2", "batch": "67", "section": "D", "subject": "CSE-2231", "semester": 3, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 793, "version_key": 3, "subject_code": "CSE-2231", "teacher_code": "T5", "teacher_name": "Teacher-5"}, {"day": "Wednesday", "room": "RAB-306", "batch": "67", "section": "F+G", "subject": "CSE-2231", "semester": 3, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 794, "version_key": 3, "subject_code": "CSE-2231", "teacher_code": "T30", "teacher_name": "Teacher-30"}, {"day": "Wednesday", "room": "ACL-4", "batch": "69", "section": "H", "subject": "CSE-1102", "semester": 1, "time_end": "17:05:00", "is_active": true, "is_service": false, "time_start": "16:00:00", "fixture_row": 795, "version_key": 3, "subject_code": "CSE-1102", "teacher_code": "T57", "teacher_name": "Teacher-57"}], "limitations": ["teacher profile FKs omitted; restore as nullable teacher_id", "publisher identity and notes omitted", "historical version metadata does not reconstruct deleted historical rows", "not a full account/config/Storage backup"], "routine_count": 795, "version_count": 4, "schema_version": 1, "routine_versions": [{"source": "upload", "is_active": false, "row_count": 122, "version_key": 1}, {"source": "upload", "is_active": false, "row_count": 822, "version_key": 2}, {"source": "upload", "is_active": true, "row_count": 795, "version_key": 3}, {"source": "manual", "is_active": false, "row_count": 983, "version_key": 4}]}$replay_snapshot$;
 snapshot jsonb;
 restored_rows jsonb;
 restored_versions jsonb;
 restored_payload jsonb;
begin
 if md5(payload_text) <> '07da7d69a5d0b0dd816133f41716eae7' then raise exception 'Embedded snapshot checksum mismatch'; end if;
 snapshot := payload_text::jsonb;
 insert into timetable_replay.routine_versions (id,source,is_active,row_count)
 select md5('task1-version-' || v.version_key)::uuid,v.source,v.is_active,v.row_count
 from jsonb_to_recordset(snapshot->'routine_versions')
   as v(version_key integer,source text,is_active boolean,row_count integer);
 insert into timetable_replay.routines
   (id,day,time_start,time_end,subject,subject_code,room,batch,section,semester,
    is_active,is_service,teacher_name,teacher_code,routine_version_id)
 select md5('task1-row-' || r.fixture_row)::uuid,r.day,r.time_start::time,r.time_end::time,
   r.subject,r.subject_code,r.room,r.batch,r.section,r.semester,r.is_active,r.is_service,
   r.teacher_name,r.teacher_code,
   case when r.version_key is null then null else md5('task1-version-' || r.version_key)::uuid end
 from jsonb_to_recordset(snapshot->'routines') as r(fixture_row integer,day text,time_start text,
   time_end text,subject text,subject_code text,room text,batch text,section text,semester integer,
   is_active boolean,is_service boolean,teacher_name text,teacher_code text,version_key integer);
 with row_keys as (
   select fixture_row from jsonb_to_recordset(snapshot->'routines') as k(fixture_row integer)
 ), version_keys as (
   select version_key from jsonb_to_recordset(snapshot->'routine_versions') as k(version_key integer)
 ), restored as (
   select k.fixture_row,r.day,r.time_start::text,r.time_end::text,r.subject,r.subject_code,
     r.room,r.batch,r.section,r.semester,r.is_active,r.is_service,r.teacher_name,r.teacher_code,v.version_key
   from row_keys k join timetable_replay.routines r on r.id=md5('task1-row-' || k.fixture_row)::uuid
   left join version_keys v on r.routine_version_id=md5('task1-version-' || v.version_key)::uuid
 ) select coalesce(jsonb_agg(to_jsonb(r) order by fixture_row),'[]'::jsonb) into restored_rows from restored r;
 with restored as (
   select k.version_key,v.source,v.is_active,v.row_count
   from jsonb_to_recordset(snapshot->'routine_versions') as k(version_key integer)
   join timetable_replay.routine_versions v on v.id=md5('task1-version-' || k.version_key)::uuid
 ) select coalesce(jsonb_agg(to_jsonb(v) order by version_key),'[]'::jsonb) into restored_versions from restored v;
 restored_payload := jsonb_build_object('schema_version',snapshot->'schema_version',
   'routine_count',(select count(*) from timetable_replay.routines),
   'version_count',(select count(*) from timetable_replay.routine_versions),
   'routines',restored_rows,'routine_versions',restored_versions,'limitations',snapshot->'limitations');
 if restored_payload is distinct from snapshot or md5(restored_payload::text) <> '07da7d69a5d0b0dd816133f41716eae7' then
   raise exception 'Restored data/count/checksum differs; no successful restore claimed';
 end if;
 if exists(select 1 from timetable_replay.routines where teacher_id is not null)
    or exists(select 1 from timetable_replay.routine_versions where published_by is not null) then
   raise exception 'Unexpected source identity in limited sanitized restore';
 end if;
end $restore$;

do $fidelity$
declare
 expected jsonb := $catalog${
 "client_privileges": {
  "anon.assignments.DELETE": true,
  "anon.assignments.INSERT": true,
  "anon.assignments.REFERENCES": false,
  "anon.assignments.SELECT": true,
  "anon.assignments.TRIGGER": false,
  "anon.assignments.TRUNCATE": false,
  "anon.assignments.UPDATE": true,
  "anon.cancellations.DELETE": true,
  "anon.cancellations.INSERT": true,
  "anon.cancellations.REFERENCES": false,
  "anon.cancellations.SELECT": true,
  "anon.cancellations.TRIGGER": false,
  "anon.cancellations.TRUNCATE": false,
  "anon.cancellations.UPDATE": true,
  "anon.device_tokens.DELETE": true,
  "anon.device_tokens.INSERT": true,
  "anon.device_tokens.REFERENCES": false,
  "anon.device_tokens.SELECT": true,
  "anon.device_tokens.TRIGGER": false,
  "anon.device_tokens.TRUNCATE": false,
  "anon.device_tokens.UPDATE": true,
  "anon.documents.DELETE": true,
  "anon.documents.INSERT": true,
  "anon.documents.REFERENCES": false,
  "anon.documents.SELECT": true,
  "anon.documents.TRIGGER": false,
  "anon.documents.TRUNCATE": false,
  "anon.documents.UPDATE": true,
  "anon.notification_reads.DELETE": true,
  "anon.notification_reads.INSERT": true,
  "anon.notification_reads.REFERENCES": false,
  "anon.notification_reads.SELECT": true,
  "anon.notification_reads.TRIGGER": false,
  "anon.notification_reads.TRUNCATE": false,
  "anon.notification_reads.UPDATE": true,
  "anon.notifications.DELETE": true,
  "anon.notifications.INSERT": true,
  "anon.notifications.REFERENCES": false,
  "anon.notifications.SELECT": true,
  "anon.notifications.TRIGGER": false,
  "anon.notifications.TRUNCATE": false,
  "anon.notifications.UPDATE": true,
  "anon.profiles.DELETE": true,
  "anon.profiles.INSERT": true,
  "anon.profiles.REFERENCES": false,
  "anon.profiles.SELECT": true,
  "anon.profiles.TRIGGER": false,
  "anon.profiles.TRUNCATE": false,
  "anon.profiles.UPDATE": true,
  "anon.resources.DELETE": true,
  "anon.resources.INSERT": true,
  "anon.resources.REFERENCES": false,
  "anon.resources.SELECT": true,
  "anon.resources.TRIGGER": false,
  "anon.resources.TRUNCATE": false,
  "anon.resources.UPDATE": true,
  "anon.routine_versions.DELETE": true,
  "anon.routine_versions.INSERT": true,
  "anon.routine_versions.REFERENCES": false,
  "anon.routine_versions.SELECT": true,
  "anon.routine_versions.TRIGGER": false,
  "anon.routine_versions.TRUNCATE": false,
  "anon.routine_versions.UPDATE": true,
  "anon.routines.DELETE": true,
  "anon.routines.INSERT": true,
  "anon.routines.REFERENCES": false,
  "anon.routines.SELECT": true,
  "anon.routines.TRIGGER": false,
  "anon.routines.TRUNCATE": false,
  "anon.routines.UPDATE": true,
  "anon.submissions.DELETE": true,
  "anon.submissions.INSERT": true,
  "anon.submissions.REFERENCES": false,
  "anon.submissions.SELECT": true,
  "anon.submissions.TRIGGER": false,
  "anon.submissions.TRUNCATE": false,
  "anon.submissions.UPDATE": true,
  "anon.timetable_course_eligibility.DELETE": true,
  "anon.timetable_course_eligibility.INSERT": true,
  "anon.timetable_course_eligibility.REFERENCES": false,
  "anon.timetable_course_eligibility.SELECT": true,
  "anon.timetable_course_eligibility.TRIGGER": false,
  "anon.timetable_course_eligibility.TRUNCATE": false,
  "anon.timetable_course_eligibility.UPDATE": true,
  "anon.timetable_courses.DELETE": true,
  "anon.timetable_courses.INSERT": true,
  "anon.timetable_courses.REFERENCES": false,
  "anon.timetable_courses.SELECT": true,
  "anon.timetable_courses.TRIGGER": false,
  "anon.timetable_courses.TRUNCATE": false,
  "anon.timetable_courses.UPDATE": true,
  "anon.timetable_faculty.DELETE": true,
  "anon.timetable_faculty.INSERT": true,
  "anon.timetable_faculty.REFERENCES": false,
  "anon.timetable_faculty.SELECT": true,
  "anon.timetable_faculty.TRIGGER": false,
  "anon.timetable_faculty.TRUNCATE": false,
  "anon.timetable_faculty.UPDATE": true,
  "anon.timetable_rooms.DELETE": true,
  "anon.timetable_rooms.INSERT": true,
  "anon.timetable_rooms.REFERENCES": false,
  "anon.timetable_rooms.SELECT": true,
  "anon.timetable_rooms.TRIGGER": false,
  "anon.timetable_rooms.TRUNCATE": false,
  "anon.timetable_rooms.UPDATE": true,
  "anon.timetable_runs.DELETE": true,
  "anon.timetable_runs.INSERT": true,
  "anon.timetable_runs.REFERENCES": false,
  "anon.timetable_runs.SELECT": true,
  "anon.timetable_runs.TRIGGER": false,
  "anon.timetable_runs.TRUNCATE": false,
  "anon.timetable_runs.UPDATE": true,
  "anon.timetable_settings.DELETE": true,
  "anon.timetable_settings.INSERT": true,
  "anon.timetable_settings.REFERENCES": false,
  "anon.timetable_settings.SELECT": true,
  "anon.timetable_settings.TRIGGER": false,
  "anon.timetable_settings.TRUNCATE": false,
  "anon.timetable_settings.UPDATE": true,
  "anon.whitelists.DELETE": true,
  "anon.whitelists.INSERT": true,
  "anon.whitelists.REFERENCES": false,
  "anon.whitelists.SELECT": true,
  "anon.whitelists.TRIGGER": false,
  "anon.whitelists.TRUNCATE": false,
  "anon.whitelists.UPDATE": true,
  "authenticated.assignments.DELETE": true,
  "authenticated.assignments.INSERT": true,
  "authenticated.assignments.REFERENCES": false,
  "authenticated.assignments.SELECT": true,
  "authenticated.assignments.TRIGGER": false,
  "authenticated.assignments.TRUNCATE": false,
  "authenticated.assignments.UPDATE": true,
  "authenticated.cancellations.DELETE": true,
  "authenticated.cancellations.INSERT": true,
  "authenticated.cancellations.REFERENCES": false,
  "authenticated.cancellations.SELECT": true,
  "authenticated.cancellations.TRIGGER": false,
  "authenticated.cancellations.TRUNCATE": false,
  "authenticated.cancellations.UPDATE": true,
  "authenticated.device_tokens.DELETE": true,
  "authenticated.device_tokens.INSERT": true,
  "authenticated.device_tokens.REFERENCES": false,
  "authenticated.device_tokens.SELECT": true,
  "authenticated.device_tokens.TRIGGER": false,
  "authenticated.device_tokens.TRUNCATE": false,
  "authenticated.device_tokens.UPDATE": true,
  "authenticated.documents.DELETE": true,
  "authenticated.documents.INSERT": true,
  "authenticated.documents.REFERENCES": false,
  "authenticated.documents.SELECT": true,
  "authenticated.documents.TRIGGER": false,
  "authenticated.documents.TRUNCATE": false,
  "authenticated.documents.UPDATE": true,
  "authenticated.notification_reads.DELETE": true,
  "authenticated.notification_reads.INSERT": true,
  "authenticated.notification_reads.REFERENCES": false,
  "authenticated.notification_reads.SELECT": true,
  "authenticated.notification_reads.TRIGGER": false,
  "authenticated.notification_reads.TRUNCATE": false,
  "authenticated.notification_reads.UPDATE": true,
  "authenticated.notifications.DELETE": true,
  "authenticated.notifications.INSERT": true,
  "authenticated.notifications.REFERENCES": false,
  "authenticated.notifications.SELECT": true,
  "authenticated.notifications.TRIGGER": false,
  "authenticated.notifications.TRUNCATE": false,
  "authenticated.notifications.UPDATE": true,
  "authenticated.profiles.DELETE": true,
  "authenticated.profiles.INSERT": true,
  "authenticated.profiles.REFERENCES": false,
  "authenticated.profiles.SELECT": true,
  "authenticated.profiles.TRIGGER": false,
  "authenticated.profiles.TRUNCATE": false,
  "authenticated.profiles.UPDATE": true,
  "authenticated.resources.DELETE": true,
  "authenticated.resources.INSERT": true,
  "authenticated.resources.REFERENCES": false,
  "authenticated.resources.SELECT": true,
  "authenticated.resources.TRIGGER": false,
  "authenticated.resources.TRUNCATE": false,
  "authenticated.resources.UPDATE": true,
  "authenticated.routine_versions.DELETE": true,
  "authenticated.routine_versions.INSERT": true,
  "authenticated.routine_versions.REFERENCES": false,
  "authenticated.routine_versions.SELECT": true,
  "authenticated.routine_versions.TRIGGER": false,
  "authenticated.routine_versions.TRUNCATE": false,
  "authenticated.routine_versions.UPDATE": true,
  "authenticated.routines.DELETE": true,
  "authenticated.routines.INSERT": true,
  "authenticated.routines.REFERENCES": false,
  "authenticated.routines.SELECT": true,
  "authenticated.routines.TRIGGER": false,
  "authenticated.routines.TRUNCATE": false,
  "authenticated.routines.UPDATE": true,
  "authenticated.submissions.DELETE": true,
  "authenticated.submissions.INSERT": true,
  "authenticated.submissions.REFERENCES": false,
  "authenticated.submissions.SELECT": true,
  "authenticated.submissions.TRIGGER": false,
  "authenticated.submissions.TRUNCATE": false,
  "authenticated.submissions.UPDATE": true,
  "authenticated.timetable_course_eligibility.DELETE": true,
  "authenticated.timetable_course_eligibility.INSERT": true,
  "authenticated.timetable_course_eligibility.REFERENCES": false,
  "authenticated.timetable_course_eligibility.SELECT": true,
  "authenticated.timetable_course_eligibility.TRIGGER": false,
  "authenticated.timetable_course_eligibility.TRUNCATE": false,
  "authenticated.timetable_course_eligibility.UPDATE": true,
  "authenticated.timetable_courses.DELETE": true,
  "authenticated.timetable_courses.INSERT": true,
  "authenticated.timetable_courses.REFERENCES": false,
  "authenticated.timetable_courses.SELECT": true,
  "authenticated.timetable_courses.TRIGGER": false,
  "authenticated.timetable_courses.TRUNCATE": false,
  "authenticated.timetable_courses.UPDATE": true,
  "authenticated.timetable_faculty.DELETE": true,
  "authenticated.timetable_faculty.INSERT": true,
  "authenticated.timetable_faculty.REFERENCES": false,
  "authenticated.timetable_faculty.SELECT": true,
  "authenticated.timetable_faculty.TRIGGER": false,
  "authenticated.timetable_faculty.TRUNCATE": false,
  "authenticated.timetable_faculty.UPDATE": true,
  "authenticated.timetable_rooms.DELETE": true,
  "authenticated.timetable_rooms.INSERT": true,
  "authenticated.timetable_rooms.REFERENCES": false,
  "authenticated.timetable_rooms.SELECT": true,
  "authenticated.timetable_rooms.TRIGGER": false,
  "authenticated.timetable_rooms.TRUNCATE": false,
  "authenticated.timetable_rooms.UPDATE": true,
  "authenticated.timetable_runs.DELETE": true,
  "authenticated.timetable_runs.INSERT": true,
  "authenticated.timetable_runs.REFERENCES": false,
  "authenticated.timetable_runs.SELECT": true,
  "authenticated.timetable_runs.TRIGGER": false,
  "authenticated.timetable_runs.TRUNCATE": false,
  "authenticated.timetable_runs.UPDATE": true,
  "authenticated.timetable_settings.DELETE": true,
  "authenticated.timetable_settings.INSERT": true,
  "authenticated.timetable_settings.REFERENCES": false,
  "authenticated.timetable_settings.SELECT": true,
  "authenticated.timetable_settings.TRIGGER": false,
  "authenticated.timetable_settings.TRUNCATE": false,
  "authenticated.timetable_settings.UPDATE": true,
  "authenticated.whitelists.DELETE": true,
  "authenticated.whitelists.INSERT": true,
  "authenticated.whitelists.REFERENCES": false,
  "authenticated.whitelists.SELECT": true,
  "authenticated.whitelists.TRIGGER": false,
  "authenticated.whitelists.TRUNCATE": false,
  "authenticated.whitelists.UPDATE": true
 },
 "columns": {
  "assignments.batch": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "assignments.created_at": {
   "default_expression": "now()",
   "exact_type": "timestamp with time zone",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "assignments.deadline": {
   "default_expression": null,
   "exact_type": "timestamp with time zone",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "assignments.description": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "assignments.id": {
   "default_expression": "gen_random_uuid()",
   "exact_type": "uuid",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "assignments.section": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "assignments.subject_code": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "assignments.teacher_id": {
   "default_expression": null,
   "exact_type": "uuid",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "assignments.title": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "cancellations.batch": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "cancellations.cancelled_by": {
   "default_expression": null,
   "exact_type": "uuid",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "cancellations.class_date": {
   "default_expression": null,
   "exact_type": "date",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "cancellations.created_at": {
   "default_expression": "now()",
   "exact_type": "timestamp with time zone",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "cancellations.day": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "cancellations.id": {
   "default_expression": "gen_random_uuid()",
   "exact_type": "uuid",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "cancellations.reason": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "cancellations.routine_id": {
   "default_expression": null,
   "exact_type": "uuid",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "cancellations.section": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "cancellations.subject": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "cancellations.time_start": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "device_tokens.platform": {
   "default_expression": "'android'::text",
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "device_tokens.token": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "device_tokens.updated_at": {
   "default_expression": "now()",
   "exact_type": "timestamp with time zone",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "device_tokens.user_id": {
   "default_expression": null,
   "exact_type": "uuid",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "documents.category": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "documents.content": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "documents.embedding": {
   "default_expression": null,
   "exact_type": "vector(768)",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "documents.id": {
   "default_expression": "gen_random_uuid()",
   "exact_type": "uuid",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "notification_reads.notification_id": {
   "default_expression": null,
   "exact_type": "uuid",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "notification_reads.read_at": {
   "default_expression": "now()",
   "exact_type": "timestamp with time zone",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "notification_reads.user_id": {
   "default_expression": null,
   "exact_type": "uuid",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "notifications.body": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "notifications.created_at": {
   "default_expression": "now()",
   "exact_type": "timestamp with time zone",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "notifications.id": {
   "default_expression": "gen_random_uuid()",
   "exact_type": "uuid",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "notifications.sent_by": {
   "default_expression": null,
   "exact_type": "uuid",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "notifications.target_batch": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "notifications.target_role": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "notifications.target_section": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "notifications.title": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "notifications.type": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "profiles.avatar_url": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "profiles.batch": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "profiles.courses": {
   "default_expression": null,
   "exact_type": "text[]",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "profiles.created_at": {
   "default_expression": "now()",
   "exact_type": "timestamp with time zone",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "profiles.department": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "profiles.designation": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "profiles.email": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "profiles.id": {
   "default_expression": null,
   "exact_type": "uuid",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "profiles.name": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "profiles.role": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "profiles.section": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "profiles.semester": {
   "default_expression": null,
   "exact_type": "integer",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "profiles.student_id": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "profiles.teacher_code": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "resources.category": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "resources.created_at": {
   "default_expression": "now()",
   "exact_type": "timestamp with time zone",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "resources.drive_link": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "resources.file_url": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "resources.id": {
   "default_expression": "gen_random_uuid()",
   "exact_type": "uuid",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "resources.semester": {
   "default_expression": null,
   "exact_type": "integer",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "resources.subject_code": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "resources.title": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "resources.uploaded_by": {
   "default_expression": null,
   "exact_type": "uuid",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "routine_versions.created_at": {
   "default_expression": "now()",
   "exact_type": "timestamp with time zone",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "routine_versions.id": {
   "default_expression": "gen_random_uuid()",
   "exact_type": "uuid",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "routine_versions.is_active": {
   "default_expression": "false",
   "exact_type": "boolean",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "routine_versions.notes": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "routine_versions.published_at": {
   "default_expression": null,
   "exact_type": "timestamp with time zone",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "routine_versions.published_by": {
   "default_expression": null,
   "exact_type": "uuid",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "routine_versions.row_count": {
   "default_expression": "0",
   "exact_type": "integer",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "routine_versions.semester_label": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "routine_versions.source": {
   "default_expression": "'engine'::text",
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "routine_versions.stats": {
   "default_expression": "'{}'::jsonb",
   "exact_type": "jsonb",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "routine_versions.validation": {
   "default_expression": "'{}'::jsonb",
   "exact_type": "jsonb",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "routines.batch": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "routines.day": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "routines.id": {
   "default_expression": "gen_random_uuid()",
   "exact_type": "uuid",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "routines.is_active": {
   "default_expression": "true",
   "exact_type": "boolean",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "routines.is_service": {
   "default_expression": "false",
   "exact_type": "boolean",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "routines.room": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "routines.routine_version_id": {
   "default_expression": null,
   "exact_type": "uuid",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "routines.section": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "routines.semester": {
   "default_expression": null,
   "exact_type": "integer",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "routines.subject": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "routines.subject_code": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "routines.teacher_code": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "routines.teacher_id": {
   "default_expression": null,
   "exact_type": "uuid",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "routines.teacher_name": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "routines.time_end": {
   "default_expression": null,
   "exact_type": "time without time zone",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "routines.time_start": {
   "default_expression": null,
   "exact_type": "time without time zone",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "submissions.assignment_id": {
   "default_expression": null,
   "exact_type": "uuid",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "submissions.file_url": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "submissions.id": {
   "default_expression": "gen_random_uuid()",
   "exact_type": "uuid",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "submissions.is_late": {
   "default_expression": null,
   "exact_type": "boolean",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "submissions.student_id": {
   "default_expression": null,
   "exact_type": "uuid",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "submissions.submitted_at": {
   "default_expression": "now()",
   "exact_type": "timestamp with time zone",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "timetable_course_eligibility.acronym": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "timetable_course_eligibility.course_code": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "timetable_course_eligibility.created_at": {
   "default_expression": "now()",
   "exact_type": "timestamp with time zone",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "timetable_course_eligibility.id": {
   "default_expression": "gen_random_uuid()",
   "exact_type": "uuid",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "timetable_course_eligibility.is_eligible": {
   "default_expression": "true",
   "exact_type": "boolean",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "timetable_course_eligibility.priority": {
   "default_expression": null,
   "exact_type": "integer",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "timetable_course_eligibility.updated_at": {
   "default_expression": "now()",
   "exact_type": "timestamp with time zone",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "timetable_courses.assigned_teacher": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "timetable_courses.batch": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "timetable_courses.code": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "timetable_courses.dept": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "timetable_courses.file_teacher": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "timetable_courses.id": {
   "default_expression": "gen_random_uuid()",
   "exact_type": "uuid",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "timetable_courses.is_lab": {
   "default_expression": "false",
   "exact_type": "boolean",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "timetable_courses.section": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "timetable_courses.title": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "timetable_courses.updated_at": {
   "default_expression": "now()",
   "exact_type": "timestamp with time zone",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "timetable_faculty.acronym": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "timetable_faculty.courses": {
   "default_expression": "'{}'::text[]",
   "exact_type": "text[]",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "timetable_faculty.dept": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "timetable_faculty.designation": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "timetable_faculty.full_name": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "timetable_faculty.id": {
   "default_expression": "gen_random_uuid()",
   "exact_type": "uuid",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "timetable_faculty.is_active": {
   "default_expression": "true",
   "exact_type": "boolean",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "timetable_faculty.off_days": {
   "default_expression": "'{}'::text[]",
   "exact_type": "text[]",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "timetable_rooms.building": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "timetable_rooms.capacity": {
   "default_expression": null,
   "exact_type": "integer",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "timetable_rooms.dept": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "timetable_rooms.id": {
   "default_expression": "gen_random_uuid()",
   "exact_type": "uuid",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "timetable_rooms.is_active": {
   "default_expression": "true",
   "exact_type": "boolean",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "timetable_rooms.is_gallery": {
   "default_expression": "false",
   "exact_type": "boolean",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "timetable_rooms.is_lab": {
   "default_expression": "false",
   "exact_type": "boolean",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "timetable_rooms.name": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "timetable_runs.created_at": {
   "default_expression": "now()",
   "exact_type": "timestamp with time zone",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "timetable_runs.created_by": {
   "default_expression": null,
   "exact_type": "uuid",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "timetable_runs.file_path": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "timetable_runs.id": {
   "default_expression": "gen_random_uuid()",
   "exact_type": "uuid",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "timetable_runs.row_count": {
   "default_expression": null,
   "exact_type": "integer",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "timetable_runs.semester_label": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "timetable_runs.stats": {
   "default_expression": null,
   "exact_type": "jsonb",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "timetable_runs.status": {
   "default_expression": "'generated'::text",
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "timetable_runs.validation": {
   "default_expression": null,
   "exact_type": "jsonb",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "timetable_settings.allow_online_periods": {
   "default_expression": "false",
   "exact_type": "boolean",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "timetable_settings.blocked_periods": {
   "default_expression": "'{}'::jsonb",
   "exact_type": "jsonb",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "timetable_settings.excluded_periods": {
   "default_expression": "'[]'::jsonb",
   "exact_type": "jsonb",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "timetable_settings.fixed_sessions_per_week": {
   "default_expression": "2",
   "exact_type": "integer",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "timetable_settings.friday_no_p4": {
   "default_expression": "true",
   "exact_type": "boolean",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "timetable_settings.id": {
   "default_expression": "1",
   "exact_type": "integer",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "timetable_settings.online_periods": {
   "default_expression": "'[7]'::jsonb",
   "exact_type": "jsonb",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "timetable_settings.periods": {
   "default_expression": null,
   "exact_type": "jsonb",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "timetable_settings.semester_label": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "timetable_settings.semester_map": {
   "default_expression": "'{}'::jsonb",
   "exact_type": "jsonb",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "timetable_settings.service_scope": {
   "default_expression": "'resource_only'::text",
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "timetable_settings.weeks_in_term": {
   "default_expression": "14",
   "exact_type": "integer",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "timetable_settings.weights": {
   "default_expression": "'{\"spread\": 2, \"late_slot\": 1, \"compactness\": 3, \"different_days\": 8}'::jsonb",
   "exact_type": "jsonb",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "timetable_settings.working_days": {
   "default_expression": null,
   "exact_type": "text[]",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "whitelists.batch": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "whitelists.department": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "whitelists.designation": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "whitelists.email": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "whitelists.name": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "whitelists.role": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": true
  },
  "whitelists.section": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "whitelists.semester": {
   "default_expression": null,
   "exact_type": "integer",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  },
  "whitelists.teacher_code": {
   "default_expression": null,
   "exact_type": "text",
   "generated_kind": "",
   "identity_kind": "",
   "not_null": false
  }
 },
 "constraints": {
  "assignments.assignments_pkey": "PRIMARY KEY (id)",
  "assignments.assignments_teacher_id_fkey": "FOREIGN KEY (teacher_id) REFERENCES profiles(id) ON DELETE CASCADE",
  "cancellations.cancellations_cancelled_by_fkey": "FOREIGN KEY (cancelled_by) REFERENCES profiles(id) ON DELETE SET NULL",
  "cancellations.cancellations_pkey": "PRIMARY KEY (id)",
  "cancellations.cancellations_routine_id_fkey": "FOREIGN KEY (routine_id) REFERENCES routines(id) ON DELETE SET NULL",
  "device_tokens.device_tokens_pkey": "PRIMARY KEY (token)",
  "device_tokens.device_tokens_user_id_fkey": "FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE",
  "documents.documents_pkey": "PRIMARY KEY (id)",
  "notification_reads.notification_reads_notification_id_fkey": "FOREIGN KEY (notification_id) REFERENCES notifications(id) ON DELETE CASCADE",
  "notification_reads.notification_reads_pkey": "PRIMARY KEY (user_id, notification_id)",
  "notification_reads.notification_reads_user_id_fkey": "FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE",
  "notifications.check_notif_type": "CHECK (type = ANY (ARRAY['university'::text, 'class_cancel'::text, 'room_change'::text, 'test_reminder'::text, 'assignment'::text, 'exam'::text]))",
  "notifications.notifications_pkey": "PRIMARY KEY (id)",
  "notifications.notifications_sent_by_fkey": "FOREIGN KEY (sent_by) REFERENCES profiles(id) ON DELETE SET NULL",
  "profiles.check_profile_role": "CHECK (role = ANY (ARRAY['student'::text, 'teacher'::text, 'admin'::text]))",
  "profiles.profiles_id_fkey": "FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE",
  "profiles.profiles_pkey": "PRIMARY KEY (id)",
  "resources.resources_pkey": "PRIMARY KEY (id)",
  "resources.resources_uploaded_by_fkey": "FOREIGN KEY (uploaded_by) REFERENCES profiles(id) ON DELETE SET NULL",
  "routine_versions.routine_versions_pkey": "PRIMARY KEY (id)",
  "routine_versions.routine_versions_published_by_fkey": "FOREIGN KEY (published_by) REFERENCES auth.users(id)",
  "routine_versions.routine_versions_source_check": "CHECK (source = ANY (ARRAY['engine'::text, 'upload'::text, 'manual'::text]))",
  "routines.routines_pkey": "PRIMARY KEY (id)",
  "routines.routines_routine_version_id_fkey": "FOREIGN KEY (routine_version_id) REFERENCES routine_versions(id) ON DELETE CASCADE",
  "routines.routines_teacher_id_fkey": "FOREIGN KEY (teacher_id) REFERENCES profiles(id) ON DELETE SET NULL",
  "submissions.submissions_assignment_id_fkey": "FOREIGN KEY (assignment_id) REFERENCES assignments(id) ON DELETE CASCADE",
  "submissions.submissions_pkey": "PRIMARY KEY (id)",
  "submissions.submissions_student_id_fkey": "FOREIGN KEY (student_id) REFERENCES profiles(id) ON DELETE CASCADE",
  "timetable_course_eligibility.timetable_course_eligibility_pkey": "PRIMARY KEY (id)",
  "timetable_course_eligibility.timetable_course_eligibility_priority_positive": "CHECK (priority IS NULL OR priority > 0)",
  "timetable_course_eligibility.timetable_course_eligibility_unique": "UNIQUE (acronym, course_code)",
  "timetable_courses.timetable_courses_code_batch_section_key": "UNIQUE (code, batch, section)",
  "timetable_courses.timetable_courses_pkey": "PRIMARY KEY (id)",
  "timetable_faculty.timetable_faculty_acronym_key": "UNIQUE (acronym)",
  "timetable_faculty.timetable_faculty_pkey": "PRIMARY KEY (id)",
  "timetable_rooms.timetable_rooms_name_key": "UNIQUE (name)",
  "timetable_rooms.timetable_rooms_pkey": "PRIMARY KEY (id)",
  "timetable_runs.timetable_runs_created_by_fkey": "FOREIGN KEY (created_by) REFERENCES profiles(id)",
  "timetable_runs.timetable_runs_pkey": "PRIMARY KEY (id)",
  "timetable_settings.timetable_settings_fixed_sessions_ck": "CHECK (fixed_sessions_per_week IS NULL OR fixed_sessions_per_week >= 0 AND fixed_sessions_per_week <= 7)",
  "timetable_settings.timetable_settings_id_check": "CHECK (id = 1)",
  "timetable_settings.timetable_settings_pkey": "PRIMARY KEY (id)",
  "timetable_settings.timetable_settings_weeks_in_term_ck": "CHECK (weeks_in_term >= 1 AND weeks_in_term <= 52)",
  "whitelists.check_role": "CHECK (role = ANY (ARRAY['student'::text, 'teacher'::text, 'admin'::text]))",
  "whitelists.whitelists_pkey": "PRIMARY KEY (email)"
 },
 "functions": {
  "calculate_is_late()": {
   "anon_execute": true,
   "authenticated_execute": true,
   "definition": "CREATE OR REPLACE FUNCTION public.calculate_is_late()\n RETURNS trigger\n LANGUAGE plpgsql\nAS $function$\nDECLARE\n    assignment_deadline TIMESTAMPTZ;\nBEGIN\n    -- Fetch the deadline for the specific assignment\n    SELECT deadline INTO assignment_deadline\n    FROM assignments\n    WHERE id = NEW.assignment_id;\n\n    -- Compare submission time to deadline\n    IF NEW.submitted_at > assignment_deadline THEN\n        NEW.is_late := TRUE;\n    ELSE\n        NEW.is_late := FALSE;\n    END IF;\n\n    RETURN NEW;\nEND;\n$function$",
   "owner": "postgres",
   "settings": null
  },
  "guard_profile_role()": {
   "anon_execute": true,
   "authenticated_execute": true,
   "definition": "CREATE OR REPLACE FUNCTION public.guard_profile_role()\n RETURNS trigger\n LANGUAGE plpgsql\n SECURITY DEFINER\n SET search_path TO 'public'\nAS $function$\nbegin\n  -- No end-user JWT (SQL editor, service role) or an admin: any role.\n  if auth.uid() is null or public.is_admin() then\n    return new;\n  end if;\n\n  -- The role is not changing: ordinary profile edits.\n  if tg_op = 'UPDATE' and new.role is not distinct from old.role then\n    return new;\n  end if;\n\n  -- Same, for an upsert of an existing row. Postgres fires BEFORE INSERT\n  -- before it detects the conflict, so the existing row is looked up here.\n  if tg_op = 'INSERT' and exists (\n    select 1 from profiles p where p.id = new.id and p.role = new.role\n  ) then\n    return new;\n  end if;\n\n  if new.role = 'student' then\n    return new;\n  end if;\n\n  if exists (\n    select 1 from whitelists w\n    where lower(w.email) = lower(auth.jwt() ->> 'email')\n      and w.role = new.role\n  ) then\n    return new;\n  end if;\n\n  raise exception 'The % role needs to be added by the department admin.', new.role\n    using errcode = '42501', hint = 'not_whitelisted';\nend;\n$function$",
   "owner": "postgres",
   "settings": [
    "search_path=public"
   ]
  },
  "is_admin()": {
   "anon_execute": false,
   "authenticated_execute": true,
   "definition": "CREATE OR REPLACE FUNCTION public.is_admin()\n RETURNS boolean\n LANGUAGE sql\n STABLE SECURITY DEFINER\n SET search_path TO 'public'\nAS $function$\n  select coalesce(public.my_role() = 'admin', false);\n$function$",
   "owner": "postgres",
   "settings": [
    "search_path=public"
   ]
  },
  "match_documents(query_embedding vector, match_count integer)": {
   "anon_execute": true,
   "authenticated_execute": true,
   "definition": "CREATE OR REPLACE FUNCTION public.match_documents(query_embedding vector, match_count integer DEFAULT 3)\n RETURNS TABLE(content text, category text, similarity double precision)\n LANGUAGE plpgsql\nAS $function$\nBEGIN\n    RETURN QUERY\n    SELECT d.content, d.category, 1 - (d.embedding <=> query_embedding) AS similarity\n    FROM documents d\n    ORDER BY d.embedding <=> query_embedding\n    LIMIT match_count;\nEND;\n$function$",
   "owner": "postgres",
   "settings": null
  },
  "my_role()": {
   "anon_execute": false,
   "authenticated_execute": true,
   "definition": "CREATE OR REPLACE FUNCTION public.my_role()\n RETURNS text\n LANGUAGE sql\n STABLE SECURITY DEFINER\n SET search_path TO 'public'\nAS $function$\n  select role from profiles where id = auth.uid();\n$function$",
   "owner": "postgres",
   "settings": [
    "search_path=public"
   ]
  },
  "publish_routine(p_rows jsonb, p_semester_label text, p_source text, p_stats jsonb, p_validation jsonb, p_notes text)": {
   "anon_execute": false,
   "authenticated_execute": true,
   "definition": "CREATE OR REPLACE FUNCTION public.publish_routine(p_rows jsonb, p_semester_label text DEFAULT NULL::text, p_source text DEFAULT 'engine'::text, p_stats jsonb DEFAULT '{}'::jsonb, p_validation jsonb DEFAULT '{}'::jsonb, p_notes text DEFAULT NULL::text)\n RETURNS jsonb\n LANGUAGE plpgsql\n SET search_path TO 'public'\nAS $function$\ndeclare\n  v_id    uuid;\n  v_count int;\nbegin\n  if not public.is_admin() then\n    raise exception 'Only an admin may publish a routine.'\n      using errcode = '42501';\n  end if;\n\n  if p_rows is null or jsonb_typeof(p_rows) <> 'array'\n     or jsonb_array_length(p_rows) = 0 then\n    -- Refuse rather than wipe: an empty payload used to be a silent no-op\n    -- that could still have cleared rows under the old delete-loop.\n    raise exception 'Refusing to publish an empty routine.'\n      using errcode = '22023';\n  end if;\n\n  insert into public.routine_versions\n    (semester_label, source, published_by, stats, validation, notes)\n  values (p_semester_label, p_source, auth.uid(), coalesce(p_stats, '{}'::jsonb),\n          coalesce(p_validation, '{}'::jsonb), p_notes)\n  returning id into v_id;\n\n  -- Replace, never merge. Every previous class goes, including batches that\n  -- do not appear in the incoming routine. `where true` is deliberate \u2014 see\n  -- the header comment; do not \"simplify\" this back to a bare DELETE.\n  update public.routine_versions set is_active = false where is_active;\n  delete from public.routines where true;\n\n  insert into public.routines\n    (day, time_start, time_end, subject, subject_code, teacher_name,\n     teacher_code, room, batch, section, semester, is_active, is_service,\n     routine_version_id)\n  select r.day, r.time_start::time, r.time_end::time, r.subject, r.subject_code,\n         r.teacher_name, r.teacher_code, r.room, r.batch, r.section,\n         coalesce(r.semester, 0), true, coalesce(r.is_service, false), v_id\n    from jsonb_to_recordset(p_rows) as r(\n      day text, time_start text, time_end text, subject text,\n      subject_code text, teacher_name text, teacher_code text, room text,\n      batch text, section text, semester int, is_service boolean);\n  get diagnostics v_count = row_count;\n\n  update public.routine_versions\n     set is_active = true, row_count = v_count, published_at = now()\n   where id = v_id;\n\n  return jsonb_build_object('version_id', v_id, 'row_count', v_count);\nend $function$",
   "owner": "postgres",
   "settings": [
    "search_path=public"
   ]
  },
  "register_device_token(p_token text, p_platform text)": {
   "anon_execute": false,
   "authenticated_execute": true,
   "definition": "CREATE OR REPLACE FUNCTION public.register_device_token(p_token text, p_platform text DEFAULT 'android'::text)\n RETURNS void\n LANGUAGE plpgsql\n SECURITY DEFINER\n SET search_path TO 'public'\nAS $function$\nbegin\n  if auth.uid() is null then\n    raise exception 'not authenticated';\n  end if;\n\n  -- Clear a stale row left by a previous user of this device.\n  delete from public.device_tokens\n   where token = p_token\n     and user_id <> auth.uid();\n\n  insert into public.device_tokens (token, user_id, platform, updated_at)\n  values (p_token, auth.uid(), p_platform, now())\n  on conflict (token) do update\n     set user_id    = excluded.user_id,\n         platform   = excluded.platform,\n         updated_at = now();\nend;\n$function$",
   "owner": "postgres",
   "settings": [
    "search_path=public"
   ]
  }
 },
 "indexes": {
  "assignments.assignments_pkey": "CREATE UNIQUE INDEX assignments_pkey ON public.assignments USING btree (id)",
  "cancellations.cancellations_date_idx": "CREATE INDEX cancellations_date_idx ON public.cancellations USING btree (class_date)",
  "cancellations.cancellations_pkey": "CREATE UNIQUE INDEX cancellations_pkey ON public.cancellations USING btree (id)",
  "cancellations.cancellations_routine_date_uniq": "CREATE UNIQUE INDEX cancellations_routine_date_uniq ON public.cancellations USING btree (routine_id, class_date)",
  "device_tokens.device_tokens_pkey": "CREATE UNIQUE INDEX device_tokens_pkey ON public.device_tokens USING btree (token)",
  "device_tokens.idx_device_tokens_user": "CREATE INDEX idx_device_tokens_user ON public.device_tokens USING btree (user_id)",
  "documents.documents_embedding_idx": "CREATE INDEX documents_embedding_idx ON public.documents USING hnsw (embedding vector_cosine_ops)",
  "documents.documents_pkey": "CREATE UNIQUE INDEX documents_pkey ON public.documents USING btree (id)",
  "notification_reads.idx_notification_reads_user": "CREATE INDEX idx_notification_reads_user ON public.notification_reads USING btree (user_id)",
  "notification_reads.notification_reads_pkey": "CREATE UNIQUE INDEX notification_reads_pkey ON public.notification_reads USING btree (user_id, notification_id)",
  "notifications.notifications_pkey": "CREATE UNIQUE INDEX notifications_pkey ON public.notifications USING btree (id)",
  "profiles.profiles_pkey": "CREATE UNIQUE INDEX profiles_pkey ON public.profiles USING btree (id)",
  "resources.resources_pkey": "CREATE UNIQUE INDEX resources_pkey ON public.resources USING btree (id)",
  "routine_versions.routine_versions_one_active": "CREATE UNIQUE INDEX routine_versions_one_active ON public.routine_versions USING btree (is_active) WHERE is_active",
  "routine_versions.routine_versions_pkey": "CREATE UNIQUE INDEX routine_versions_pkey ON public.routine_versions USING btree (id)",
  "routines.routines_lookup_idx": "CREATE INDEX routines_lookup_idx ON public.routines USING btree (batch, section, day)",
  "routines.routines_pkey": "CREATE UNIQUE INDEX routines_pkey ON public.routines USING btree (id)",
  "routines.routines_teacher_idx": "CREATE INDEX routines_teacher_idx ON public.routines USING btree (teacher_code, day)",
  "routines.routines_version_idx": "CREATE INDEX routines_version_idx ON public.routines USING btree (routine_version_id)",
  "submissions.submissions_pkey": "CREATE UNIQUE INDEX submissions_pkey ON public.submissions USING btree (id)",
  "timetable_course_eligibility.timetable_course_eligibility_acronym_idx": "CREATE INDEX timetable_course_eligibility_acronym_idx ON public.timetable_course_eligibility USING btree (acronym)",
  "timetable_course_eligibility.timetable_course_eligibility_pkey": "CREATE UNIQUE INDEX timetable_course_eligibility_pkey ON public.timetable_course_eligibility USING btree (id)",
  "timetable_course_eligibility.timetable_course_eligibility_unique": "CREATE UNIQUE INDEX timetable_course_eligibility_unique ON public.timetable_course_eligibility USING btree (acronym, course_code)",
  "timetable_courses.timetable_courses_code_batch_section_key": "CREATE UNIQUE INDEX timetable_courses_code_batch_section_key ON public.timetable_courses USING btree (code, batch, section)",
  "timetable_courses.timetable_courses_pkey": "CREATE UNIQUE INDEX timetable_courses_pkey ON public.timetable_courses USING btree (id)",
  "timetable_faculty.timetable_faculty_acronym_key": "CREATE UNIQUE INDEX timetable_faculty_acronym_key ON public.timetable_faculty USING btree (acronym)",
  "timetable_faculty.timetable_faculty_pkey": "CREATE UNIQUE INDEX timetable_faculty_pkey ON public.timetable_faculty USING btree (id)",
  "timetable_rooms.timetable_rooms_name_key": "CREATE UNIQUE INDEX timetable_rooms_name_key ON public.timetable_rooms USING btree (name)",
  "timetable_rooms.timetable_rooms_pkey": "CREATE UNIQUE INDEX timetable_rooms_pkey ON public.timetable_rooms USING btree (id)",
  "timetable_runs.timetable_runs_pkey": "CREATE UNIQUE INDEX timetable_runs_pkey ON public.timetable_runs USING btree (id)",
  "timetable_settings.timetable_settings_pkey": "CREATE UNIQUE INDEX timetable_settings_pkey ON public.timetable_settings USING btree (id)",
  "whitelists.whitelists_pkey": "CREATE UNIQUE INDEX whitelists_pkey ON public.whitelists USING btree (email)"
 },
 "policies": {
  "assignments.assignments_delete": {
   "check": null,
   "cmd": "DELETE",
   "roles": [
    "authenticated"
   ],
   "using": "((teacher_id = auth.uid()) OR is_admin())"
  },
  "assignments.assignments_insert_teacher": {
   "check": "((teacher_id = auth.uid()) AND (my_role() = ANY (ARRAY['teacher'::text, 'admin'::text])))",
   "cmd": "INSERT",
   "roles": [
    "authenticated"
   ],
   "using": null
  },
  "assignments.assignments_modify": {
   "check": "((teacher_id = auth.uid()) OR is_admin())",
   "cmd": "UPDATE",
   "roles": [
    "authenticated"
   ],
   "using": "((teacher_id = auth.uid()) OR is_admin())"
  },
  "assignments.assignments_select": {
   "check": null,
   "cmd": "SELECT",
   "roles": [
    "authenticated"
   ],
   "using": "true"
  },
  "cancellations.cancellations_delete": {
   "check": null,
   "cmd": "DELETE",
   "roles": [
    "authenticated"
   ],
   "using": "((cancelled_by = auth.uid()) OR is_admin())"
  },
  "cancellations.cancellations_insert_staff": {
   "check": "((cancelled_by = auth.uid()) AND (my_role() = ANY (ARRAY['teacher'::text, 'admin'::text])))",
   "cmd": "INSERT",
   "roles": [
    "authenticated"
   ],
   "using": null
  },
  "cancellations.cancellations_select": {
   "check": null,
   "cmd": "SELECT",
   "roles": [
    "authenticated"
   ],
   "using": "true"
  },
  "device_tokens.own_tokens_delete": {
   "check": null,
   "cmd": "DELETE",
   "roles": [
    "public"
   ],
   "using": "(user_id = auth.uid())"
  },
  "device_tokens.own_tokens_insert": {
   "check": "(user_id = auth.uid())",
   "cmd": "INSERT",
   "roles": [
    "public"
   ],
   "using": null
  },
  "device_tokens.own_tokens_select": {
   "check": null,
   "cmd": "SELECT",
   "roles": [
    "public"
   ],
   "using": "(user_id = auth.uid())"
  },
  "device_tokens.own_tokens_update": {
   "check": null,
   "cmd": "UPDATE",
   "roles": [
    "public"
   ],
   "using": "(user_id = auth.uid())"
  },
  "documents.documents_select": {
   "check": null,
   "cmd": "SELECT",
   "roles": [
    "authenticated"
   ],
   "using": "true"
  },
  "documents.documents_write_admin": {
   "check": "is_admin()",
   "cmd": "ALL",
   "roles": [
    "authenticated"
   ],
   "using": "is_admin()"
  },
  "notification_reads.own_reads_delete": {
   "check": null,
   "cmd": "DELETE",
   "roles": [
    "public"
   ],
   "using": "(user_id = auth.uid())"
  },
  "notification_reads.own_reads_insert": {
   "check": "(user_id = auth.uid())",
   "cmd": "INSERT",
   "roles": [
    "public"
   ],
   "using": null
  },
  "notification_reads.own_reads_select": {
   "check": null,
   "cmd": "SELECT",
   "roles": [
    "public"
   ],
   "using": "(user_id = auth.uid())"
  },
  "notification_reads.own_reads_update": {
   "check": null,
   "cmd": "UPDATE",
   "roles": [
    "public"
   ],
   "using": "(user_id = auth.uid())"
  },
  "notifications.notifications_delete": {
   "check": null,
   "cmd": "DELETE",
   "roles": [
    "authenticated"
   ],
   "using": "((sent_by = auth.uid()) OR is_admin())"
  },
  "notifications.notifications_insert_staff": {
   "check": "((sent_by = auth.uid()) AND (my_role() = ANY (ARRAY['teacher'::text, 'admin'::text])))",
   "cmd": "INSERT",
   "roles": [
    "authenticated"
   ],
   "using": null
  },
  "notifications.notifications_select": {
   "check": null,
   "cmd": "SELECT",
   "roles": [
    "authenticated"
   ],
   "using": "true"
  },
  "profiles.profiles_delete_admin": {
   "check": null,
   "cmd": "DELETE",
   "roles": [
    "authenticated"
   ],
   "using": "is_admin()"
  },
  "profiles.profiles_insert_own": {
   "check": "((id = auth.uid()) AND ((role = ANY (ARRAY['student'::text, 'teacher'::text])) OR (EXISTS ( SELECT 1\n   FROM whitelists w\n  WHERE ((lower(w.email) = lower((auth.jwt() ->> 'email'::text))) AND (w.role = profiles.role))))))",
   "cmd": "INSERT",
   "roles": [
    "authenticated"
   ],
   "using": null
  },
  "profiles.profiles_select": {
   "check": null,
   "cmd": "SELECT",
   "roles": [
    "authenticated"
   ],
   "using": "true"
  },
  "profiles.profiles_update_own": {
   "check": "(is_admin() OR ((id = auth.uid()) AND ((role = ANY (ARRAY['student'::text, 'teacher'::text])) OR (EXISTS ( SELECT 1\n   FROM whitelists w\n  WHERE ((lower(w.email) = lower((auth.jwt() ->> 'email'::text))) AND (w.role = profiles.role)))))))",
   "cmd": "UPDATE",
   "roles": [
    "authenticated"
   ],
   "using": "((id = auth.uid()) OR is_admin())"
  },
  "resources.resources_delete": {
   "check": null,
   "cmd": "DELETE",
   "roles": [
    "authenticated"
   ],
   "using": "((uploaded_by = auth.uid()) OR is_admin())"
  },
  "resources.resources_insert_staff": {
   "check": "((uploaded_by = auth.uid()) AND (my_role() = ANY (ARRAY['teacher'::text, 'admin'::text])))",
   "cmd": "INSERT",
   "roles": [
    "authenticated"
   ],
   "using": null
  },
  "resources.resources_modify": {
   "check": "((uploaded_by = auth.uid()) OR is_admin())",
   "cmd": "UPDATE",
   "roles": [
    "authenticated"
   ],
   "using": "((uploaded_by = auth.uid()) OR is_admin())"
  },
  "resources.resources_select": {
   "check": null,
   "cmd": "SELECT",
   "roles": [
    "authenticated"
   ],
   "using": "true"
  },
  "routine_versions.routine_versions_select": {
   "check": null,
   "cmd": "SELECT",
   "roles": [
    "authenticated"
   ],
   "using": "true"
  },
  "routine_versions.routine_versions_write_admin": {
   "check": "is_admin()",
   "cmd": "ALL",
   "roles": [
    "authenticated"
   ],
   "using": "is_admin()"
  },
  "routines.routines_select": {
   "check": null,
   "cmd": "SELECT",
   "roles": [
    "authenticated"
   ],
   "using": "true"
  },
  "routines.routines_write_admin": {
   "check": "is_admin()",
   "cmd": "ALL",
   "roles": [
    "authenticated"
   ],
   "using": "is_admin()"
  },
  "submissions.submissions_delete": {
   "check": null,
   "cmd": "DELETE",
   "roles": [
    "authenticated"
   ],
   "using": "((student_id = auth.uid()) OR is_admin())"
  },
  "submissions.submissions_insert_own": {
   "check": "(student_id = auth.uid())",
   "cmd": "INSERT",
   "roles": [
    "authenticated"
   ],
   "using": null
  },
  "submissions.submissions_select": {
   "check": null,
   "cmd": "SELECT",
   "roles": [
    "authenticated"
   ],
   "using": "((student_id = auth.uid()) OR (my_role() = ANY (ARRAY['teacher'::text, 'admin'::text])))"
  },
  "submissions.submissions_update_own": {
   "check": "(student_id = auth.uid())",
   "cmd": "UPDATE",
   "roles": [
    "authenticated"
   ],
   "using": "(student_id = auth.uid())"
  },
  "timetable_course_eligibility.admin_write": {
   "check": "is_admin()",
   "cmd": "ALL",
   "roles": [
    "public"
   ],
   "using": "is_admin()"
  },
  "timetable_course_eligibility.read_all": {
   "check": null,
   "cmd": "SELECT",
   "roles": [
    "public"
   ],
   "using": "true"
  },
  "timetable_courses.timetable_courses_select": {
   "check": null,
   "cmd": "SELECT",
   "roles": [
    "authenticated"
   ],
   "using": "true"
  },
  "timetable_courses.timetable_courses_write_admin": {
   "check": "is_admin()",
   "cmd": "ALL",
   "roles": [
    "authenticated"
   ],
   "using": "is_admin()"
  },
  "timetable_faculty.timetable_faculty_select": {
   "check": null,
   "cmd": "SELECT",
   "roles": [
    "authenticated"
   ],
   "using": "true"
  },
  "timetable_faculty.timetable_faculty_write_admin": {
   "check": "is_admin()",
   "cmd": "ALL",
   "roles": [
    "authenticated"
   ],
   "using": "is_admin()"
  },
  "timetable_rooms.timetable_rooms_select": {
   "check": null,
   "cmd": "SELECT",
   "roles": [
    "authenticated"
   ],
   "using": "true"
  },
  "timetable_rooms.timetable_rooms_write_admin": {
   "check": "is_admin()",
   "cmd": "ALL",
   "roles": [
    "authenticated"
   ],
   "using": "is_admin()"
  },
  "timetable_runs.timetable_runs_select": {
   "check": null,
   "cmd": "SELECT",
   "roles": [
    "authenticated"
   ],
   "using": "true"
  },
  "timetable_runs.timetable_runs_write_admin": {
   "check": "is_admin()",
   "cmd": "ALL",
   "roles": [
    "authenticated"
   ],
   "using": "is_admin()"
  },
  "timetable_settings.timetable_settings_select": {
   "check": null,
   "cmd": "SELECT",
   "roles": [
    "authenticated"
   ],
   "using": "true"
  },
  "timetable_settings.timetable_settings_write_admin": {
   "check": "is_admin()",
   "cmd": "ALL",
   "roles": [
    "authenticated"
   ],
   "using": "is_admin()"
  },
  "whitelists.whitelists_select": {
   "check": null,
   "cmd": "SELECT",
   "roles": [
    "authenticated"
   ],
   "using": "((lower(email) = lower((auth.jwt() ->> 'email'::text))) OR is_admin())"
  },
  "whitelists.whitelists_write_admin": {
   "check": "is_admin()",
   "cmd": "ALL",
   "roles": [
    "authenticated"
   ],
   "using": "is_admin()"
  }
 },
 "rls": {
  "assignments": true,
  "cancellations": true,
  "device_tokens": true,
  "documents": true,
  "notification_reads": true,
  "notifications": true,
  "profiles": true,
  "resources": true,
  "routine_versions": true,
  "routines": true,
  "submissions": true,
  "timetable_course_eligibility": true,
  "timetable_courses": true,
  "timetable_faculty": true,
  "timetable_rooms": true,
  "timetable_runs": true,
  "timetable_settings": true,
  "whitelists": true
 }
}$catalog$::jsonb;
 actual jsonb;
 category text;
begin
 select jsonb_build_object(
'columns', (select jsonb_object_agg(c.relname || '.' || a.attname, jsonb_build_object(
 'exact_type', format_type(a.atttypid,a.atttypmod), 'not_null', a.attnotnull,
 'default_expression', pg_get_expr(d.adbin,d.adrelid), 'identity_kind', a.attidentity::text,
 'generated_kind', a.attgenerated::text))
 from pg_attribute a join pg_class c on c.oid=a.attrelid join pg_namespace n on n.oid=c.relnamespace
 left join pg_attrdef d on d.adrelid=a.attrelid and d.adnum=a.attnum
 where n.nspname='timetable_replay' and c.relkind in ('r','p') and a.attnum>0 and not a.attisdropped),
'constraints', (select jsonb_object_agg(c.conrelid::regclass::text || '.' || c.conname, pg_get_constraintdef(c.oid,true))
 from pg_constraint c join pg_namespace n on n.oid=c.connamespace where n.nspname='timetable_replay'),
'indexes', (select jsonb_object_agg(tablename || '.' || indexname,replace(indexdef,'timetable_replay.','public.')) from pg_indexes where schemaname='timetable_replay'),
'policies', (select jsonb_object_agg(tablename || '.' || policyname,jsonb_build_object(
 'cmd',cmd,'roles',roles,'using',qual,'check',with_check)) from pg_policies where schemaname='timetable_replay'),
'functions', (select jsonb_object_agg(p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')',jsonb_build_object(
 'owner',pg_get_userbyid(p.proowner),'settings',replace(to_jsonb(p.proconfig)::text,'timetable_replay','public')::jsonb,
 'anon_execute',has_function_privilege('anon',p.oid,'EXECUTE'),
 'authenticated_execute',has_function_privilege('authenticated',p.oid,'EXECUTE'),
 'definition',regexp_replace(replace(replace(pg_get_functiondef(p.oid),'timetable_replay','public'), E'\r\n', E'\n'),'[[:space:];]+$','')))
 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='timetable_replay' and p.prokind='f'
 and not exists (select 1 from pg_depend d where d.classid='pg_proc'::regclass
   and d.objid=p.oid and d.refclassid='pg_extension'::regclass and d.deptype='e')),
'rls', (select jsonb_object_agg(c.relname,c.relrowsecurity) from pg_class c join pg_namespace n on n.oid=c.relnamespace
 where n.nspname='timetable_replay' and c.relkind in ('r','p')),
'client_privileges', (select jsonb_object_agg(r.name || '.' || t.tablename || '.' || p.name,
 has_table_privilege(r.name,format('%I.%I',t.schemaname,t.tablename),p.name))
 from pg_tables t cross join (values ('anon'),('authenticated')) r(name)
 cross join (values ('SELECT'),('INSERT'),('UPDATE'),('DELETE'),('TRUNCATE'),('REFERENCES'),('TRIGGER')) p(name)
 where t.schemaname='timetable_replay')) into actual;
 for category in select jsonb_object_keys(expected) loop
   if expected->category is distinct from actual->category then
     raise exception 'Baseline fidelity mismatch in %. Stop and return this error; do not change definitions to force a pass.', category;
   end if;
 end loop;
end $fidelity$;
do $$
begin
  if not exists (select 1 from pg_publication
      where pubname = 'timetable_replay_publication'
        and pg_get_userbyid(pubowner) = 'postgres'
        and not puballtables and not pubviaroot
        and pubinsert and pubupdate and pubdelete and pubtruncate) then
    raise exception 'Realtime publication settings differ from supplied baseline';
  end if;
  if (select count(*) from pg_publication_tables
      where pubname = 'timetable_replay_publication') <> 1
     or not exists (select 1 from pg_publication_tables
       where pubname = 'timetable_replay_publication' and schemaname = 'timetable_replay'
         and tablename = 'cancellations' and rowfilter is null
         and attnames = array[
           'id', 'routine_id', 'cancelled_by', 'reason', 'created_at',
           'class_date', 'batch', 'section', 'subject', 'day', 'time_start'
         ]::name[]) then
    raise exception 'Expected cancellations-only Realtime membership with all columns and no row filter';
  end if;
  if not exists (select 1 from pg_class
      where oid = 'timetable_replay.cancellations'::regclass
        and relreplident = 'd' and relrowsecurity) then
    raise exception 'Cancellations must retain default replica identity and RLS';
  end if;
  if exists (select 1 from pg_trigger
      where tgrelid = 'timetable_replay.notifications'::regclass and not tgisinternal) then
    raise exception 'Unexpected notification webhook in test project';
  end if;
end $$;
rollback;
do $cleanup$
begin
 if to_regnamespace('timetable_replay') is not null
    or exists(select 1 from pg_publication where pubname='timetable_replay_publication') then
   raise exception 'Scratch cleanup not verified';
 end if;
 if (select count(*) from pg_tables where schemaname='public') <> 18 then
   raise exception 'Unexpected public table count after rollback';
 end if;
end $cleanup$;
select jsonb_build_object('result','PASS: namespaced baseline replay and sanitized schedule restore; rolled back',
 'routine_count',795,'version_count',4,
 'checksum_md5','07da7d69a5d0b0dd816133f41716eae7','scope','public baseline adapted to isolated scratch namespace; not full project restore') as result;
