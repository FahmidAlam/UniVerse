import io
import hashlib

import openpyxl
import pytest

import distribution
import main
import solver
from conftest import build_workbook, make_config, make_row


def test_generation_boundary_uses_accepted_distribution_normalization():
    config = solver.load_config(override=make_config(teachers=['AAA']))
    dataset = main.normalize_generation_distribution(
        build_workbook([make_row(teacher='AAA', classes=14)]), config)

    assert dataset['offerings'][0]['code'] == 'CSE-1101'
    assert dataset['source_contract']['revision'] == 0
    assert len(dataset['source_contract']['source_sha256']) == 64


def test_generation_replays_a_persisted_accepted_revision():
    raw = build_workbook([make_row(teacher='AAA', classes=14)])
    source_contract = {
        'source_id': '10000000-0000-4000-8000-000000000001',
        'revision_id': '20000000-0000-4000-8000-000000000001',
        'revision_number': 1,
        'revision_version': 2,
        'status': 'accepted',
        'source_sha256': hashlib.sha256(raw).hexdigest(),
        'corrections': [{
            'source_row': 6,
            'source_column': 'D',
            'original_formula': None,
            'original_cached_value': 'Course CSE-1101',
            'effective_value': 'Committee-approved title',
        }],
    }

    dataset = main.normalize_generation_distribution(
        raw, solver.load_config(override=make_config(teachers=['AAA'])),
        source_contract=source_contract)

    assert dataset['offerings'][0]['title'] == 'Committee-approved title'
    assert dataset['source_contract']['revision_id'] == source_contract['revision_id']
    assert dataset['source_contract']['revision'] == 2
    assert dataset['source_contract']['revision_number'] == 1


def test_generation_rejects_a_persisted_contract_with_the_wrong_source_hash():
    raw = build_workbook([make_row(teacher='AAA', classes=14)])
    source_contract = {
        'source_id': '10000000-0000-4000-8000-000000000001',
        'revision_id': '20000000-0000-4000-8000-000000000001',
        'revision_number': 1,
        'revision_version': 1,
        'status': 'accepted',
        'source_sha256': '0' * 64,
        'corrections': [],
    }

    with pytest.raises(distribution.ValidationError, match='hash'):
        main.normalize_generation_distribution(
            raw, solver.load_config(override=make_config(teachers=['AAA'])),
            source_contract=source_contract)


def test_completed_job_exposes_the_exact_source_contract_used_for_generation():
    job_id = 'source-contract-test'
    main.JOBS[job_id] = {'state': 'queued', 'progress': 0.0}
    try:
        main._run_job(
            job_id,
            build_workbook([make_row(teacher='AAA', classes=14)]),
            make_config(teachers=['AAA']),
            2,
        )
        job = main.JOBS[job_id]
        assert job['state'] == 'done'
        assert job['source_contract']['revision'] == 0
        assert job['report']['source_contract'] == job['source_contract']
        assert job['validation']['source_contract'] == job['source_contract']
        rendered = openpyxl.load_workbook(io.BytesIO(job['file']))
        assert job['source_contract']['source_sha256'] in rendered.properties.subject
        assert 'revision=0' in rendered.properties.subject
    finally:
        main.JOBS.pop(job_id, None)


def test_completed_job_retains_the_selected_persisted_revision_identity():
    job_id = 'persisted-source-contract-test'
    raw = build_workbook([make_row(teacher='AAA', classes=14)])
    source_contract = {
        'source_id': '10000000-0000-4000-8000-000000000001',
        'revision_id': '20000000-0000-4000-8000-000000000001',
        'revision_number': 1,
        'revision_version': 1,
        'status': 'accepted',
        'source_sha256': hashlib.sha256(raw).hexdigest(),
        'corrections': [],
    }
    main.JOBS[job_id] = {'state': 'queued', 'progress': 0.0}
    try:
        main._run_job(
            job_id, raw, make_config(teachers=['AAA']), 2,
            source_contract=source_contract)
        job = main.JOBS[job_id]
        assert job['state'] == 'done'
        assert job['source_contract']['source_id'] == source_contract['source_id']
        assert job['source_contract']['revision_id'] == source_contract['revision_id']
        assert job['validation']['source_contract'] == job['source_contract']
        rendered = openpyxl.load_workbook(io.BytesIO(job['file']))
        assert source_contract['revision_id'] in rendered.properties.subject
    finally:
        main.JOBS.pop(job_id, None)


def test_generation_rejects_persisted_contract_with_unaccepted_status():
    raw = build_workbook([make_row(teacher='AAA', classes=14)])
    source_contract = {
        'source_id': '10000000-0000-4000-8000-000000000001',
        'revision_id': '20000000-0000-4000-8000-000000000001',
        'revision_number': 1,
        'revision_version': 1,
        'status': 'superseded',
        'source_sha256': hashlib.sha256(raw).hexdigest(),
        'corrections': [],
    }

    with pytest.raises(distribution.ValidationError, match='not accepted'):
        main.normalize_generation_distribution(
            raw, solver.load_config(override=make_config(teachers=['AAA'])),
            source_contract=source_contract)


def test_generation_rejects_persisted_contract_with_invalid_uuid():
    raw = build_workbook([make_row(teacher='AAA', classes=14)])
    source_contract = {
        'source_id': 'invalid-uuid-string',
        'revision_id': '20000000-0000-4000-8000-000000000001',
        'revision_number': 1,
        'revision_version': 1,
        'status': 'accepted',
        'source_sha256': hashlib.sha256(raw).hexdigest(),
        'corrections': [],
    }

    with pytest.raises(distribution.ValidationError, match='invalid identity'):
        main.normalize_generation_distribution(
            raw, solver.load_config(override=make_config(teachers=['AAA'])),
            source_contract=source_contract)


def test_generation_rejects_persisted_contract_with_provenance_mismatch():
    raw = build_workbook([make_row(teacher='AAA', classes=14)])
    source_contract = {
        'source_id': '10000000-0000-4000-8000-000000000001',
        'revision_id': '20000000-0000-4000-8000-000000000001',
        'revision_number': 1,
        'revision_version': 1,
        'status': 'accepted',
        'source_sha256': hashlib.sha256(raw).hexdigest(),
        'corrections': [{
            'source_row': 6,
            'source_column': 'D',
            'original_formula': None,
            'original_cached_value': 'Mismatch Title Not in Sheet',
            'effective_value': 'New Title',
        }],
    }

    with pytest.raises(distribution.ValidationError, match='provenance does not match'):
        main.normalize_generation_distribution(
            raw, solver.load_config(override=make_config(teachers=['AAA'])),
            source_contract=source_contract)


def test_generation_rejects_duplicate_corrections_for_same_cell():
    raw = build_workbook([make_row(teacher='AAA', classes=14)])
    source_contract = {
        'source_id': '10000000-0000-4000-8000-000000000001',
        'revision_id': '20000000-0000-4000-8000-000000000001',
        'revision_number': 1,
        'revision_version': 1,
        'status': 'accepted',
        'source_sha256': hashlib.sha256(raw).hexdigest(),
        'corrections': [
            {
                'source_row': 6,
                'source_column': 'D',
                'original_formula': None,
                'original_cached_value': 'Course CSE-1101',
                'effective_value': 'Title 1',
            },
            {
                'source_row': 6,
                'source_column': 'D',
                'original_formula': None,
                'original_cached_value': 'Course CSE-1101',
                'effective_value': 'Title 2',
            },
        ],
    }

    with pytest.raises(distribution.ValidationError, match='target one source cell'):
        main.normalize_generation_distribution(
            raw, solver.load_config(override=make_config(teachers=['AAA'])),
            source_contract=source_contract)


def test_generation_allows_persisted_correction_of_formula_without_cached_value():
    raw = build_workbook([make_row(teacher='AAA', classes=14)])
    wb = openpyxl.load_workbook(io.BytesIO(raw))
    wb['Course Distribution']['J6'] = '=7*2'
    out = io.BytesIO()
    wb.save(out)
    uncached_raw = out.getvalue()

    cfg = solver.load_config(override=make_config(teachers=['AAA']))

    # Uncorrected normalization fails because J6 formula has no cached value
    with pytest.raises(distribution.ValidationError, match='cached value'):
        main.normalize_generation_distribution(uncached_raw, cfg)

    # Persisted accepted correction supplying effective value succeeds
    source_contract = {
        'source_id': '10000000-0000-4000-8000-000000000001',
        'revision_id': '20000000-0000-4000-8000-000000000001',
        'revision_number': 1,
        'revision_version': 1,
        'status': 'accepted',
        'source_sha256': hashlib.sha256(uncached_raw).hexdigest(),
        'corrections': [{
            'source_row': 6,
            'source_column': 'J',
            'original_formula': '=7*2',
            'original_cached_value': None,
            'effective_value': 14,
        }],
    }

    dataset = main.normalize_generation_distribution(
        uncached_raw, cfg, source_contract=source_contract)
    assert dataset['offerings'][0]['classes_total'] == 14
    assert dataset['source_contract']['revision_id'] == source_contract['revision_id']

