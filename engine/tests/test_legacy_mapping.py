from copy import deepcopy
import pytest
from legacy_mapping import quarantine_unapproved


def test_unapproved_mapping_never_splits_aliases_or_infers_batch_stage():
    rows = [dict(fixture_row=1, batch='66', section='B+C', semester=3,
                 time_start='09:00:00', time_end='10:00:00', teacher_code='T1')]
    before = deepcopy(rows)
    result = quarantine_unapproved(rows)
    assert rows == before
    assert result[0].reasons == ('mapping_not_approved',)
    assert result[0].fixture_row == 1


def test_quarantine_records_invalid_legacy_times_and_unresolved_resources():
    row = dict(fixture_row=1, time_start='23:10:00', time_end='12:15:00', is_service=True)
    assert quarantine_unapproved([row])[0].reasons == (
        'mapping_not_approved', 'invalid_same_day_interval',
        'service_scope_unresolved', 'teacher_unresolved')
    with pytest.raises(ValueError): quarantine_unapproved([row, row])


def test_recorded_quarantine_assessment_matches_checksum_verified_fixture():
    import hashlib
    import json
    from collections import Counter
    from pathlib import Path
    root = Path(__file__).resolve().parents[2]
    raw = (root / 'supabase/tests/task1_replay_rehearsal.sql').read_text(encoding='utf-8').split('$replay_snapshot$')[1]
    report = json.loads((root / 'docs/timetable-audit-2026-10-20/task2-backfill-status.json').read_text(encoding='utf-8'))
    assert hashlib.md5(raw.encode()).hexdigest() == report['source_checksum_md5']
    rows = quarantine_unapproved(json.loads(raw)['routines'])
    assert len(rows) == report['quarantined_count'] == report['routine_count'] == 795
    assert dict(Counter(reason for row in rows for reason in row.reasons)) == report['reason_counts']
    assert report['approval_status'] == 'not_approved'
    assert report['proposed_or_applied_links'] == 0
