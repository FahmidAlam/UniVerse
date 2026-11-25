-- ONLY universe-timetable-test after stages 001-003 and rollback-only role tests.
-- Reproduce supplied Realtime membership; no Storage, data or webhook changes.
-- This is a reconstructed test stage, NOT a production migration.
begin;
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
commit;
