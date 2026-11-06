-- Read-only catalog test: ONLY universe-timetable-test after stage 004/Realtime.
-- Before 004_test_realtime.sql: expected membership error; after it: PASS.
-- Verifies configuration, NOT WebSocket delivery, latency or client lifecycle.
begin;
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
rollback;
select 'PASS: stage 005 cancellations-only Realtime configuration matches supplied baseline; delivery not tested' as result;
