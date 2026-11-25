-- ONLY universe-timetable-test: aggregate fidelity + existing Storage/Realtime checks.
-- Read-only. Expected metadata comes from supplied original-project exports.
-- Intentional difference: client maintenance privileges absent in the test project.
-- Physical column-position gaps from dropped source columns are not compared.
-- Source history is unavailable; this does not assert migration-history fidelity.
begin read only;
-- Keep built-ins ahead of extensions, matching PostgreSQL's normal implicit
-- pg_catalog precedence. Otherwise pgcrypto's gen_random_uuid shadows the core
-- function and pg_get_expr prints a misleading pg_catalog qualification.
set local search_path = pg_catalog, public, extensions;
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
 where n.nspname='public' and c.relkind in ('r','p') and a.attnum>0 and not a.attisdropped),
'constraints', (select jsonb_object_agg(c.conrelid::regclass::text || '.' || c.conname, pg_get_constraintdef(c.oid,true))
 from pg_constraint c join pg_namespace n on n.oid=c.connamespace where n.nspname='public'),
'indexes', (select jsonb_object_agg(tablename || '.' || indexname,indexdef) from pg_indexes where schemaname='public'),
'policies', (select jsonb_object_agg(tablename || '.' || policyname,jsonb_build_object(
 'cmd',cmd,'roles',roles,'using',qual,'check',with_check)) from pg_policies where schemaname='public'),
'functions', (select jsonb_object_agg(p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')',jsonb_build_object(
 'owner',pg_get_userbyid(p.proowner),'settings',p.proconfig,
 'anon_execute',has_function_privilege('anon',p.oid,'EXECUTE'),
 'authenticated_execute',has_function_privilege('authenticated',p.oid,'EXECUTE'),
 'definition',regexp_replace(replace(pg_get_functiondef(p.oid), E'\r\n', E'\n'),'[[:space:];]+$','')))
 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and p.prokind='f'
 and not exists (select 1 from pg_depend d where d.classid='pg_proc'::regclass
   and d.objid=p.oid and d.refclassid='pg_extension'::regclass and d.deptype='e')),
'rls', (select jsonb_object_agg(c.relname,c.relrowsecurity) from pg_class c join pg_namespace n on n.oid=c.relnamespace
 where n.nspname='public' and c.relkind in ('r','p')),
'client_privileges', (select jsonb_object_agg(r.name || '.' || t.tablename || '.' || p.name,
 has_table_privilege(r.name,format('%I.%I',t.schemaname,t.tablename),p.name))
 from pg_tables t cross join (values ('anon'),('authenticated')) r(name)
 cross join (values ('SELECT'),('INSERT'),('UPDATE'),('DELETE'),('TRUNCATE'),('REFERENCES'),('TRIGGER')) p(name)
 where t.schemaname='public')) into actual;
 for category in select jsonb_object_keys(expected) loop
   if expected->category is distinct from actual->category then
     raise exception 'Baseline fidelity mismatch in %. Stop and return this error; do not change definitions to force a pass.', category;
   end if;
 end loop;
end $fidelity$;

do $$
begin
  if not exists (select 1 from pg_publication
      where pubname = 'supabase_realtime'
        and pg_get_userbyid(pubowner) = 'postgres'
        and not puballtables and not pubviaroot
        and pubinsert and pubupdate and pubdelete and pubtruncate) then
    raise exception 'Realtime publication settings differ from supplied baseline';
  end if;
  if (select count(*) from pg_publication_tables
      where pubname = 'supabase_realtime') <> 1
     or not exists (select 1 from pg_publication_tables
       where pubname = 'supabase_realtime' and schemaname = 'public'
         and tablename = 'cancellations' and rowfilter is null
         and attnames = array[
           'id', 'routine_id', 'cancelled_by', 'reason', 'created_at',
           'class_date', 'batch', 'section', 'subject', 'day', 'time_start'
         ]::name[]) then
    raise exception 'Expected cancellations-only Realtime membership with all columns and no row filter';
  end if;
  if not exists (select 1 from pg_class
      where oid = 'public.cancellations'::regclass
        and relreplident = 'd' and relrowsecurity) then
    raise exception 'Cancellations must retain default replica identity and RLS';
  end if;
  if exists (select 1 from pg_trigger
      where tgrelid = 'public.notifications'::regclass and not tgisinternal) then
    raise exception 'Unexpected notification webhook in test project';
  end if;
end $$;

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
select 'PASS: baseline catalog fidelity, restricted test grants, Storage and Realtime configuration; no data changed' as result;
