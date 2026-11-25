-- RECONSTRUCTED TEST BASELINE: table/constraint/index stage only.
-- Source: user-supplied deployed metadata, 22 October 2026.
-- NOT an applied migration, full schema dump, or production rollout script.
-- Target ONLY: empty universe-timetable-test project in the Supabase SQL Editor.
-- This stage deliberately denies client access pending separate policy/grant reconciliation.
-- No schedules, users, credentials, webhook triggers or Edge Functions are imported.
begin;

do $$
begin
  if exists (select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
             where n.nspname = 'public' and c.relkind in ('r', 'p')) then
    raise exception 'Refusing baseline: public already contains tables. Use an empty disposable test project.';
  end if;
end $$;

-- Match the supplied vector type/index dependency; fail if unavailable.
create extension if not exists vector with schema public version '0.8.0';

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
commit;
