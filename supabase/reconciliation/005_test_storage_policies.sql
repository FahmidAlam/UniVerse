-- ONLY empty universe-timetable-test. Never run in UniVerse.
-- Reconstruct the four supplied legacy policies verbatim, not a secure redesign.
-- WARNING: authenticated writes are unrestricted by bucket/path/owner; reads public.
-- Keep this disposable project free of real files/users and disconnected from the app.
-- No managed Storage row writes, uploads, grants, webhook or application changes.
begin;
do $$
begin
  if current_user <> 'postgres'
     or (select count(*) from pg_tables where schemaname = 'public') <> 18
     or (select count(*) from pg_policies where schemaname = 'public') <> 50 then
    raise exception 'Expected reconstructed disposable test project as postgres';
  end if;
  if (select count(*) from storage.buckets) <> 4
     or (select array_agg(id order by id) from storage.buckets)
          is distinct from array['assignments','avatars','resources','timetables']::text[]
     or exists (select 1 from storage.buckets where name <> id or not public
                 or file_size_limit is not null or allowed_mime_types is not null) then
    raise exception 'Create only the four source-matching test buckets first';
  end if;
  if exists (select 1 from pg_policies
      where schemaname = 'storage' and tablename in ('buckets','objects')) then
    raise exception 'Refusing existing Storage policies; do not rerun or use production';
  end if;
  if exists (select 1 from storage.objects) or exists (select 1 from auth.users) then
    raise exception 'Refusing Storage setup with existing objects/users; do not clear data';
  end if;
  if (select count(*) from pg_class c join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'storage' and c.relname in ('buckets','objects')
        and c.relrowsecurity and not c.relforcerowsecurity
        and pg_get_userbyid(c.relowner) = 'supabase_storage_admin') <> 2 then
    raise exception 'Managed Storage owner/RLS flags differ; do not alter them';
  end if;
end $$;
create policy storage_public_read on storage.objects
  as permissive for select to public using (true);
create policy storage_auth_insert on storage.objects
  as permissive for insert to authenticated with check (true);
create policy storage_auth_update on storage.objects
  as permissive for update to authenticated using (true) with check (true);
create policy storage_auth_delete on storage.objects
  as permissive for delete to authenticated using (true);
commit;
