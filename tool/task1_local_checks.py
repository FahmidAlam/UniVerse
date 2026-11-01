"""Rebuild ONLY a newly owned local Supabase project twice; never link remotely.

Requires Supabase CLI 2.121.0 and a running Docker engine. No hosted credentials.
The generated migration is a restricted reconstructed baseline, not applied history.
"""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import tomllib
import urllib.request
import uuid

ROOT = Path(__file__).resolve().parents[1]
PROJECT = 'universe-task1-local'
CLI_VERSION = '2.121.0'


def check_local_project(folder):
    marker = folder / '.task1-owned'
    config = folder / 'supabase/config.toml'
    if not marker.is_file() or not config.is_file():
        raise ValueError('Refusing unowned local project')
    project_id = marker.read_text()
    if not re.fullmatch(PROJECT + r'(?:-[0-9a-f]{8})?', project_id):
        raise ValueError('Unexpected local ownership marker')
    if tomllib.loads(config.read_text(encoding='utf-8'))['project_id'] != project_id:
        raise ValueError('Unexpected local project identifier')
    if (folder / 'supabase/.temp/project-ref').exists():
        raise ValueError('Refusing a linked project')


def build_baseline(root):
    parts = []
    for name in ('001_test_tables.sql', '002_test_functions_policies.sql',
                 '003_test_dml_grants.sql', '004_test_realtime.sql'):
        source = (root / 'supabase/reconciliation' / name).read_text(encoding='utf-8')
        source = re.sub(r'^(begin|commit);\s*$', '', source, flags=re.M | re.I)
        # Local compatibility variant: preserve the observed hosted-test version.
        source = source.replace("version '0.8.0'", "version '0.8.2'")
        parts.append(source)
    parts.insert(1, """do $$ begin
if exists(select 1 from pg_extension where extname='vector' and extversion <> '0.8.2') then
 raise exception 'Local vector version differs; do not silently accept drift';
end if; end $$;""")
    return '\n'.join(parts)


def restore_sql(root):
    source = (root / 'supabase/tests/task1_replay_rehearsal.sql').read_text(encoding='utf-8')
    block = source[source.index('do $restore$'):source.index('end $restore$;') + len('end $restore$;')]
    block = block.replace('timetable_replay.', 'public.')
    return "begin;\nset local search_path = pg_catalog, public, extensions;\n" + block + """
rollback;
do $$ begin
 if exists(select 1 from public.routines) or exists(select 1 from public.routine_versions) then
  raise exception 'Restore fixture rollback failed';
 end if;
end $$;
select 'PASS: public-namespace 795-row/4-version restore and exact checksum; rolled back';
"""


def local_environment(original, docker_host=None):
    # Do not pass platform credentials or user-provided remote targets to the CLI.
    env = {k: v for k, v in original.items() if not k.upper().startswith('SUPABASE_')
           and k.upper() not in ('PGHOST', 'PGPORT', 'PGDATABASE', 'PGUSER', 'PGPASSWORD',
                                'DATABASE_URL', 'DOCKER_CONTEXT', 'DOCKER_HOST')}
    if docker_host is not None:
        check_docker_endpoint(docker_host)
        env['DOCKER_HOST'] = docker_host
    return env


def run(command, folder, input_text=None, quiet=False, docker_host=None):
    env = local_environment(os.environ, docker_host)
    result = subprocess.run(command, cwd=folder, input=input_text, text=True,
                            encoding='utf-8', capture_output=True, env=env)
    if result.returncode:
        # Commands here contain only generated local config/synthetic data.
        if not quiet:
            print(result.stdout[-3000:], result.stderr[-3000:], flush=True)
        raise RuntimeError('Local command failed: ' + ' '.join(command[:3]))
    if not quiet:
        print(result.stdout[-3000:], flush=True)
    return result.stdout


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        raise ValueError('Local Storage redirect refused')


def check_docker_endpoint(host):
    if host not in ('npipe:////./pipe/docker_engine', 'npipe:////./pipe/dockerDesktopLinuxEngine',
                    'unix:///var/run/docker.sock'):
        raise ValueError('Refusing non-local Docker endpoint: ' + host)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cli', default='supabase', help='Pinned CLI executable; no remote options accepted')
    parser.add_argument('--task2', action='store_true', help='Also apply/test the additive academic catalog locally')
    args = parser.parse_args()
    cli = shutil.which(args.cli)
    if not cli:
        raise ValueError('Supabase CLI not found')
    version = run([cli, '--version'], ROOT).strip()
    if version != CLI_VERSION:
        raise ValueError('Expected Supabase CLI ' + CLI_VERSION)
    context = json.loads(run(['docker', 'context', 'inspect'], ROOT, quiet=True))[0]
    docker_host = os.environ.get('DOCKER_HOST') or context['Endpoints']['docker']['Host']
    check_docker_endpoint(docker_host)
    run(['docker', 'info', '--format', '{{.ServerVersion}}'], ROOT, docker_host=docker_host)
    folder = Path(tempfile.mkdtemp(prefix='universe-task1-local-'))
    print('Owned disposable local workdir:', folder, flush=True)
    (folder / 'supabase').mkdir()
    config = (ROOT / 'supabase/config.toml').read_text(encoding='utf-8')
    project_id = PROJECT + '-' + uuid.uuid4().hex[:8]
    config = config.replace('project_id = "' + PROJECT + '"', 'project_id = "' + project_id + '"')
    # Only this freshly created directory enables the reconstructed migration.
    config = config.replace('[db.migrations]\n# Historical files require reconciliation; never replay them automatically.\nenabled = false',
                            '[db.migrations]\nenabled = true')
    (folder / 'supabase/config.toml').write_text(config, encoding='utf-8')
    (folder / '.task1-owned').write_text(project_id)
    check_local_project(folder)

    def local(*command, quiet=False):
        check_local_project(folder)
        return run([cli, *command, '--workdir', str(folder)], folder, quiet=quiet, docker_host=docker_host)

    local('migration', 'new', 'reconstructed_baseline')
    migration, = (folder / 'supabase/migrations').glob('*.sql')
    migration.write_text(build_baseline(ROOT), encoding='utf-8')
    tests = folder / 'supabase/tests'
    tests.mkdir()
    shutil.copyfile(ROOT / 'supabase/tests/baseline.test.sql', tests / 'baseline.test.sql')
    container = 'supabase_db_' + project_id

    def sql(text):
        check_local_project(folder)
        return run(['docker', 'exec', '-i', container, 'psql', '-U', 'postgres',
                    '-d', 'postgres', '-X', '-v', 'ON_ERROR_STOP=1', '-q'], folder, text, docker_host=docker_host)

    try:
        # Services irrelevant to database/Storage verification stay disabled.
        local('start', '--exclude', 'studio,imgproxy,edge-runtime,logflare,vector,supavisor', quiet=True)
        for iteration in (1, 2):
            print('Fresh public-namespace rebuild', iteration, 'of 2', flush=True)
            local('db', 'reset', '--local', '--no-seed', '--yes')
            sql((ROOT / 'supabase/tests/reconciliation_stage4.sql').read_text(encoding='utf-8'))
            # Obtain ONLY this local stack's keys; never print them or follow redirects.
            status = json.loads(local('status', '-o', 'json', quiet=True))
            url = status['API_URL']
            if url not in ('http://127.0.0.1:54321', 'http://localhost:54321'):
                raise ValueError('Refusing non-local Storage endpoint')
            opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())
            for bucket in ('assignments', 'avatars', 'resources', 'timetables'):
                req = urllib.request.Request(url + '/storage/v1/bucket',
                    data=json.dumps({'id': bucket, 'name': bucket, 'public': True}).encode(),
                    headers={'Authorization': 'Bearer ' + status['SERVICE_ROLE_KEY'],
                             'apikey': status['SERVICE_ROLE_KEY'], 'Content-Type': 'application/json'}, method='POST')
                with opener.open(req, timeout=30) as response:
                    if response.status not in (200, 201):
                        raise RuntimeError('Local bucket creation failed')
            sql((ROOT / 'supabase/reconciliation/005_test_storage_policies.sql').read_text(encoding='utf-8'))
            sql((ROOT / 'supabase/tests/task1_catalog_checks.sql').read_text(encoding='utf-8'))
            sql('create extension if not exists pgtap with schema extensions;')
            local('test', 'db', '--local', 'supabase/tests/baseline.test.sql')
            sql(restore_sql(ROOT))
            if args.task2:
                task2_migration, = (ROOT / 'supabase/migrations').glob('*_academic_catalog.sql')
                # Persist only the sanitized fixture in this owned disposable DB.
                sql(restore_sql(ROOT).split('rollback;')[0] + 'commit;')
                fingerprint = "select md5(jsonb_agg(to_jsonb(r) - array['scheduling_scope_id','cohort_id','student_group_id','faculty_id','room_id'] order by id)::text) from public.routines r;"
                before = sql(fingerprint)
                sql(task2_migration.read_text(encoding='utf-8'))
                if sql(fingerprint) != before:
                    raise RuntimeError('Academic migration changed legacy schedule content')
                shutil.copyfile(ROOT / 'supabase/tests/academic_domain.test.sql', tests / 'academic_domain.test.sql')
                local('test', 'db', '--local', 'supabase/tests/academic_domain.test.sql')
                # Round-trip the mixed-calendar, program-scoped SQL snapshot
                # through the same strict engine contract used by consumers.
                fixture = (ROOT / 'supabase/tests/academic_domain.test.sql').read_text(encoding='utf-8')
                snapshot_output = sql(fixture.split("select is((select count(*)::int from programs),1")[0]
                                      + 'select academic_catalog(); rollback;')
                snapshots = [json.loads(line.strip()) for line in snapshot_output.splitlines()
                             if line.strip().startswith('{') and '"schema_version"' in line]
                if len(snapshots) != 1:
                    raise RuntimeError('Expected one scoped academic catalog snapshot')
                import sys
                sys.path.insert(0, str(ROOT / 'engine'))
                from domain import AcademicCatalog
                AcademicCatalog.from_map(snapshots[0])
                print('PASS: academic catalog/RLS tests and all 795 legacy rows preserved', flush=True)
            sql("select version(); select extname,extversion from pg_extension where extname in ('vector','pgtap');")
        print('PASS: two fresh local public-namespace rebuilds, role/catalog/pgTAP checks and exact limited schedule restores')
    finally:
        # Stop only this owned local stack; preserve its files/volumes for diagnosis.
        local('stop')


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        # HTTP errors must not echo request headers or key-bearing status output.
        print('FAIL:', type(error).__name__, str(error) if not isinstance(error, urllib.error.URLError) else 'Local Storage request failed')
        raise SystemExit(1)
