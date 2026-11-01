import hashlib
import json
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
try:
    import build_replay_rehearsal as replay
except ModuleNotFoundError:
    replay = None


def fixture():
    payload = {
        'schema_version': 1, 'routine_count': 1, 'version_count': 1,
        'routine_versions': [{'version_key': 1, 'source': 'manual', 'is_active': True, 'row_count': 1}],
        'routines': [{'fixture_row': 1, 'day': 'Sunday', 'time_start': '09:00:00',
                      'time_end': '10:00:00', 'subject': 'Synthetic', 'subject_code': 'TEST',
                      'room': 'TEST', 'batch': 'TEST', 'section': 'A', 'semester': 1,
                      'is_active': True, 'is_service': False, 'teacher_name': 'Teacher-1',
                      'teacher_code': 'T1', 'version_key': 1}],
        'limitations': ['synthetic fixture'],
    }
    text = json.dumps(payload)
    return {'payload': text, 'checksum_md5': hashlib.md5(text.encode()).hexdigest()}


class ReplayBuilderTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(replay, 'Replay builder is not implemented')

    def test_snapshot_tampering_is_rejected(self):
        value = fixture()
        value['payload'] = value['payload'].replace('Synthetic', 'Tampered')
        with self.assertRaises(ValueError):
            replay.validate_snapshot(value)

    def test_original_identity_fields_are_rejected_even_with_valid_checksum(self):
        value = fixture()
        payload = json.loads(value['payload'])
        payload['routines'][0]['teacher_id'] = 'private-source-id'
        value['payload'] = json.dumps(payload)
        value['checksum_md5'] = hashlib.md5(value['payload'].encode()).hexdigest()
        with self.assertRaises(ValueError):
            replay.validate_snapshot(value)

    def test_namespace_conversion_preserves_public_role_and_managed_schemas(self):
        source = "begin;\ncreate table public.example(id uuid references auth.users(id));\n" \
                 "grant select on public.example to public;\ncommit;\n"
        converted = replay.stage_body(source)
        self.assertIn('create table timetable_replay.example', converted)
        self.assertIn('references auth.users', converted)
        self.assertIn('to public;', converted)
        self.assertNotIn('commit;', converted)

    def test_function_moves_but_vector_extension_type_stays_in_public(self):
        source = 'begin;\nalter function public.match_documents(public.vector,integer) owner to postgres;\ncommit;\n'
        converted = replay.stage_body(source)
        self.assertIn('timetable_replay.match_documents(public.vector,integer)', converted)
        self.assertNotIn('timetable_replay.vector', converted)

    def test_generated_rehearsal_has_no_drop_or_commit_and_verifies_rollback(self):
        root = Path(__file__).resolve().parents[2]
        sql = replay.build_rehearsal(fixture(), root)
        self.assertNotRegex(sql, r'(?im)^\s*(?:drop|commit)\b')
        self.assertIn('create schema timetable_replay;', sql)
        self.assertIn('create publication timetable_replay_publication', sql)
        self.assertNotIn('alter publication supabase_realtime', sql)
        self.assertIn('restored_payload is distinct from snapshot', sql)
        self.assertIn('md5(restored_payload::text)', sql)
        self.assertLess(sql.index('rollback;'), sql.rindex("select jsonb_build_object("))
        self.assertIn("to_regnamespace('timetable_replay') is not null", sql)


if __name__ == '__main__':
    unittest.main()
