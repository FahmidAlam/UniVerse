-- RECONSTRUCTED TEST BASELINE stage 002: functions, public RLS policies, local triggers.
-- Only for universe-timetable-test after stage 001. NOT a production migration.
-- Source: user-supplied deployed function and policy metadata, 22 October 2026.
-- Policies preserve observed legacy behavior; this does not certify their security.
-- Client table grants remain revoked. No webhook, Storage, Realtime, FCM or data writes.
begin;
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

commit;
