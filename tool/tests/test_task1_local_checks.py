import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('task1_local_checks', ROOT / 'tool/task1_local_checks.py')


class LocalChecksTests(unittest.TestCase):
    def setUp(self):
        self.assertTrue(Path(SPEC.origin).exists(), 'Local verifier not implemented')
        self.module = importlib.util.module_from_spec(SPEC)
        SPEC.loader.exec_module(self.module)

    def test_linked_or_unowned_directory_is_rejected(self):
        with tempfile.TemporaryDirectory() as path:
            folder = Path(path)
            with self.assertRaises(ValueError):
                self.module.check_local_project(folder)
            (folder / 'supabase/.temp').mkdir(parents=True)
            (folder / 'supabase/config.toml').write_text('project_id = "universe-task1-local"')
            (folder / '.task1-owned').write_text('universe-task1-local')
            self.module.check_local_project(folder)
            (folder / 'supabase/.temp/project-ref').write_text('oqwvxplteqtlrhktsplj')
            with self.assertRaises(ValueError):
                self.module.check_local_project(folder)

    def test_local_baseline_preserves_public_namespace_and_restricts_grants(self):
        sql = self.module.build_baseline(ROOT)
        self.assertIn('create table public.', sql)
        self.assertNotIn('timetable_replay', sql)
        self.assertNotIn("version '0.8.0'", sql)
        self.assertIn("extversion <> '0.8.2'", sql)
        self.assertNotRegex(sql, r'(?im)^\s*(?:begin|commit|drop)\s*;')
        self.assertIn('grant select, insert, update, delete', sql)

    def test_restore_uses_real_fixture_and_rolls_back_public_rows(self):
        sql = self.module.restore_sql(ROOT)
        self.assertIn('insert into public.routines', sql)
        self.assertIn('07da7d69a5d0b0dd816133f41716eae7', sql)
        self.assertIn('restored_payload is distinct from snapshot', sql)
        self.assertIn('rollback;', sql)
        self.assertNotIn('timetable_replay', sql)

    def test_non_local_docker_context_is_rejected(self):
        for host in ('tcp://example.com:2375', 'ssh://remote', 'unix:///tmp/remote.sock'):
            with self.assertRaises(ValueError):
                self.module.check_docker_endpoint(host)
        self.module.check_docker_endpoint('npipe:////./pipe/docker_engine')
        self.module.check_docker_endpoint('unix:///var/run/docker.sock')

    def test_conflicting_context_cannot_override_pinned_local_host(self):
        original = {'DOCKER_HOST': 'npipe:////./pipe/docker_engine',
                    'DOCKER_CONTEXT': 'remote-production', 'SUPABASE_ACCESS_TOKEN': 'private',
                    'PGPASSWORD': 'private', 'PATH': 'keep'}
        env = self.module.local_environment(original, 'npipe:////./pipe/docker_engine')
        self.assertNotIn('DOCKER_CONTEXT', env)
        self.assertNotIn('SUPABASE_ACCESS_TOKEN', env)
        self.assertNotIn('PGPASSWORD', env)
        self.assertEqual(env['DOCKER_HOST'], 'npipe:////./pipe/docker_engine')
        self.assertEqual(env['PATH'], 'keep')


if __name__ == '__main__':
    unittest.main()
