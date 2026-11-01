"""Build, but never execute, a rollback-only namespaced baseline/restore rehearsal."""
import argparse
import hashlib
import json
from pathlib import Path
import re

SCHEMA = 'timetable_replay'
PUBLICATION = 'timetable_replay_publication'
ROOT = Path(__file__).resolve().parents[1]


def validate_snapshot(value):
    if isinstance(value, list):
        value = value[0]
    if 'schedule_snapshot' in value:
        value = value['schedule_snapshot']
        if isinstance(value, str):
            value = json.loads(value)
    raw = value['payload']
    if hashlib.md5(raw.encode('utf-8')).hexdigest() != value['checksum_md5']:
        raise ValueError('Snapshot checksum mismatch')
    data = json.loads(raw)
    if data['schema_version'] != 1 or data['routine_count'] != len(data['routines']) \
            or data['version_count'] != len(data['routine_versions']):
        raise ValueError('Snapshot version/count mismatch')
    allowed = {'fixture_row', 'day', 'time_start', 'time_end', 'subject', 'subject_code',
               'room', 'batch', 'section', 'semester', 'is_active', 'is_service',
               'teacher_name', 'teacher_code', 'version_key'}
    keys = {v['version_key'] for v in data['routine_versions']}
    if len(keys) != data['version_count']:
        raise ValueError('Duplicate fixture version keys')
    if [r['fixture_row'] for r in data['routines']] != list(range(1, data['routine_count'] + 1)):
        raise ValueError('Incomplete fixture row keys')
    for row in data['routines']:
        if set(row) != allowed or row['version_key'] is not None and row['version_key'] not in keys:
            raise ValueError('Unexpected identity field or broken fixture version reference')
        if row['teacher_name'] is not None and not re.fullmatch(r'Teacher-\d+', row['teacher_name']):
            raise ValueError('Non-synthetic teacher name')
        if row['teacher_code'] is not None and not re.fullmatch(r'T\d+', row['teacher_code']):
            raise ValueError('Non-synthetic teacher code')
    if re.search(r'[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}', raw, re.I):
        raise ValueError('Original UUID-like value found')
    if '$replay_snapshot$' in raw:
        raise ValueError('Snapshot conflicts with SQL literal delimiter')
    return value, data


def rehome(sql):
    sql = sql.replace('public.', SCHEMA + '.').replace("'public'", "'" + SCHEMA + "'")
    # vector belongs to the existing managed extension, not the replay schema.
    sql = re.sub(r'\b' + SCHEMA + r'\.vector\b', 'public.vector', sql)
    sql = sql.replace('supabase_realtime', PUBLICATION)
    return re.sub(r'^set local search_path[^;]*;',
                  f'set local search_path = pg_catalog, {SCHEMA}, public, extensions;',
                  sql, flags=re.M | re.I)


def stage_body(source):
    if len(re.findall(r'^begin;$', source, re.M | re.I)) != 1 \
            or len(re.findall(r'^commit;$', source, re.M | re.I)) != 1:
        raise ValueError('Unexpected source transaction structure')
    source = re.sub(r'^(begin|commit);\s*$', '', source, flags=re.M | re.I)
    # The managed extension already exists in public; never move/install it.
    source = re.sub(r'^create extension[^;]*;\s*$', '', source, flags=re.M | re.I)
    return rehome(source)


def catalog_body(root):
    source = (root / 'supabase/tests/task1_catalog_checks.sql').read_text(encoding='utf-8')
    body = source[source.index('do $fidelity$'):source.index('end $fidelity$;') + len('end $fidelity$;')]
    before, expected, after = body.split('$catalog$', 2)
    after = rehome(after)
    changes = {
        'indexname,indexdef': f"indexname,replace(indexdef,'{SCHEMA}.','public.')",
        'pg_get_functiondef(p.oid)': f"replace(pg_get_functiondef(p.oid),'{SCHEMA}','public')",
        "'settings',p.proconfig": f"'settings',replace(to_jsonb(p.proconfig)::text,'{SCHEMA}','public')::jsonb",
    }
    for old, new in changes.items():
        if after.count(old) != 1:
            raise ValueError('Unexpected fidelity-query structure: ' + old)
        after = after.replace(old, new)
    return before + '$catalog$' + expected + '$catalog$' + after


def build_rehearsal(value, root=ROOT):
    value, data = validate_snapshot(value)
    raw, checksum = value['payload'], value['checksum_md5']
    header = f"""-- ONLY universe-timetable-test. Run the complete file as postgres TWICE.
-- Transactional scratch-schema rehearsal: NO DROP, RESET or COMMIT.
-- Public tables, managed Storage, Auth users and original Realtime stay untouched.
-- Replays namespace-adapted stages 001-004, restores a limited sanitized fixture,
-- checks exact content/count/checksum and catalog, then rolls everything back.
-- This is NOT full new-project provisioning or a complete account/Storage restore.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '90s';
set local search_path = pg_catalog, {SCHEMA}, public, extensions;
do $preflight$
declare t record; populated boolean;
begin
 if current_user <> 'postgres' then raise exception 'Use test-project postgres role'; end if;
 if to_regnamespace('{SCHEMA}') is not null
    or exists (select 1 from pg_publication where pubname='{PUBLICATION}') then
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
create schema {SCHEMA};
"""
    stages = []
    for name in ['001_test_tables.sql', '002_test_functions_policies.sql', '003_test_dml_grants.sql']:
        stages.append(stage_body((root / 'supabase/reconciliation' / name).read_text(encoding='utf-8')))
    stages.append(f"create publication {PUBLICATION} with (publish='insert, update, delete, truncate', publish_via_partition_root=false);")
    stages.append(stage_body((root / 'supabase/reconciliation/004_test_realtime.sql').read_text(encoding='utf-8')))
    restore = f"""
set local search_path = pg_catalog, {SCHEMA}, public, extensions;
do $restore$
declare
 payload_text text := $replay_snapshot${raw}$replay_snapshot$;
 snapshot jsonb;
 restored_rows jsonb;
 restored_versions jsonb;
 restored_payload jsonb;
begin
 if md5(payload_text) <> '{checksum}' then raise exception 'Embedded snapshot checksum mismatch'; end if;
 snapshot := payload_text::jsonb;
 insert into {SCHEMA}.routine_versions (id,source,is_active,row_count)
 select md5('task1-version-' || v.version_key)::uuid,v.source,v.is_active,v.row_count
 from jsonb_to_recordset(snapshot->'routine_versions')
   as v(version_key integer,source text,is_active boolean,row_count integer);
 insert into {SCHEMA}.routines
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
   from row_keys k join {SCHEMA}.routines r on r.id=md5('task1-row-' || k.fixture_row)::uuid
   left join version_keys v on r.routine_version_id=md5('task1-version-' || v.version_key)::uuid
 ) select coalesce(jsonb_agg(to_jsonb(r) order by fixture_row),'[]'::jsonb) into restored_rows from restored r;
 with restored as (
   select k.version_key,v.source,v.is_active,v.row_count
   from jsonb_to_recordset(snapshot->'routine_versions') as k(version_key integer)
   join {SCHEMA}.routine_versions v on v.id=md5('task1-version-' || k.version_key)::uuid
 ) select coalesce(jsonb_agg(to_jsonb(v) order by version_key),'[]'::jsonb) into restored_versions from restored v;
 restored_payload := jsonb_build_object('schema_version',snapshot->'schema_version',
   'routine_count',(select count(*) from {SCHEMA}.routines),
   'version_count',(select count(*) from {SCHEMA}.routine_versions),
   'routines',restored_rows,'routine_versions',restored_versions,'limitations',snapshot->'limitations');
 if restored_payload is distinct from snapshot or md5(restored_payload::text) <> '{checksum}' then
   raise exception 'Restored data/count/checksum differs; no successful restore claimed';
 end if;
 if exists(select 1 from {SCHEMA}.routines where teacher_id is not null)
    or exists(select 1 from {SCHEMA}.routine_versions where published_by is not null) then
   raise exception 'Unexpected source identity in limited sanitized restore';
 end if;
end $restore$;
"""
    realtime = (root / 'supabase/tests/reconciliation_stage5.sql').read_text(encoding='utf-8')
    realtime = realtime[realtime.index('do $$'):realtime.index('end $$;') + len('end $$;')]
    footer = f"""
rollback;
do $cleanup$
begin
 if to_regnamespace('{SCHEMA}') is not null
    or exists(select 1 from pg_publication where pubname='{PUBLICATION}') then
   raise exception 'Scratch cleanup not verified';
 end if;
 if (select count(*) from pg_tables where schemaname='public') <> 18 then
   raise exception 'Unexpected public table count after rollback';
 end if;
end $cleanup$;
select jsonb_build_object('result','PASS: namespaced baseline replay and sanitized schedule restore; rolled back',
 'routine_count',{data['routine_count']},'version_count',{data['version_count']},
 'checksum_md5','{checksum}','scope','public baseline adapted to isolated scratch namespace; not full project restore') as result;
"""
    sql = header + '\n'.join(stages) + restore + '\n' + catalog_body(root) + '\n' + rehome(realtime) + footer
    if re.search(r'^\s*(drop|commit)\b', sql, re.M | re.I):
        raise ValueError('Persistent/destructive transaction statement found')
    return sql


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('snapshot', type=Path)
    args = parser.parse_args()
    value = json.loads(args.snapshot.read_text(encoding='utf-8-sig'))
    out = ROOT / 'supabase/tests/task1_replay_rehearsal.sql'
    out.write_bytes(build_rehearsal(value).encode('utf-8'))
    print('Prepared', out, '- not executed. Review and run only in universe-timetable-test.')


if __name__ == '__main__':
    main()
