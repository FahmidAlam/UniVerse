"""Canonical catalog identities; no database, workbook or solver dependencies."""
from copy import deepcopy
import json
from pathlib import Path
import pytest

FIXTURE = Path(__file__).resolve().parents[2] / 'test/fixtures/academic_catalog_v1.json'


def load():
    return json.loads(FIXTURE.read_text(encoding='utf-8'))


def catalog(value=None):
    from domain import AcademicCatalog
    return AcademicCatalog.from_map(load() if value is None else value)


def test_shared_json_contract_round_trips_without_inference():
    original = load()
    model = catalog(original)
    assert model.to_map() == original
    assert model.schema_version == 1
    assert model.rooms[0].capacity is None


def test_same_batch_and_section_labels_are_distinct_across_programs():
    model = catalog()
    cse, eee = model.cohorts[:2]
    assert cse.code == eee.code == '66'
    groups = [g for g in model.student_groups if g.code == 'A' and g.cohort_id in (cse.id, eee.id)]
    assert len(groups) == 2 and groups[0].id != groups[1].id
    assert groups[0].cohort_id != groups[1].cohort_id


def test_shared_label_resolves_only_reviewed_atomic_members_in_its_cohort():
    model = catalog()
    cohort = model.cohorts[0]
    members = model.resolve_group_alias(cohort.id, 'B+C')
    assert {g.code for g in members} == {'B', 'C'}
    with pytest.raises(ValueError, match='alias'):
        model.resolve_group_alias(model.cohorts[1].id, 'B+C')
    with pytest.raises(ValueError, match='alias'):
        model.resolve_group_alias(cohort.id, 'C+B')


def test_unreviewed_alias_blocks_resolution():
    data = load()
    data['group_aliases'][0]['reviewed'] = False
    with pytest.raises(ValueError, match='reviewed'):
        catalog(data).resolve_group_alias(data['cohorts'][0]['id'], 'B+C')


def test_new_intake_and_graduation_keep_existing_group_identity():
    data = load()
    old_id = data['student_groups'][0]['id']
    data['cohorts'][0].update(status='archived', graduated_on='2026-06-30', archived_on='2026-07-01')
    model = catalog(data)
    assert model.student_groups[0].id == old_id
    assert model.cohorts[2].code == '67'
    assert sum(g.cohort_id == model.cohorts[2].id for g in model.student_groups) == 1


def test_mixed_calendars_and_progression_are_explicit_not_batch_arithmetic():
    model = catalog()
    assert model.cohort_terms[0].study_stage == 3
    assert model.cohort_terms[1].study_stage == 5
    assert model.terms[1].sequence == 4  # no hard-coded two/three terms per year
    data = load()
    data['cohort_terms'][0]['term_id'] = data['terms'][1]['id']
    with pytest.raises(ValueError, match='calendar'):
        catalog(data)


@pytest.mark.parametrize('mutate', [
    lambda d: d['student_groups'].append(deepcopy(d['student_groups'][0])),
    lambda d: d['group_aliases'].append(dict(d['group_aliases'][0], id='00000000-0000-0000-0000-000000000099')),
    lambda d: d['scopes'].append(dict(d['scopes'][-1], id='00000000-0000-0000-0000-000000000099')),
])
def test_duplicate_identity_alias_or_null_program_scope_blocks_catalog(mutate):
    data = load()
    mutate(data)
    with pytest.raises(ValueError, match='Duplicate'):
        catalog(data)


@pytest.mark.parametrize('field,value', [('schema_version', 2), ('schema_version', True), ('unexpected', 1)])
def test_unknown_version_or_field_is_not_silently_accepted(field, value):
    data = load()
    data[field] = value
    with pytest.raises(ValueError):
        catalog(data)


def test_cross_cohort_alias_and_wrong_scope_department_reject():
    data = load()
    data['group_aliases'][0]['group_ids'].append(data['student_groups'][-1]['id'])
    with pytest.raises(ValueError, match='cohort'):
        catalog(data)
    data = load()
    data['scopes'][0]['department_id'] = data['departments'][1]['id']
    with pytest.raises(ValueError, match='department'):
        catalog(data)


@pytest.mark.parametrize('field,value', [('start_date', '2026-02-30'), ('end_date', '2025-01-01')])
def test_invalid_term_dates_reject(field, value):
    data = load()
    data['terms'][0][field] = value
    with pytest.raises(ValueError):
        catalog(data)


def test_snapshot_is_detached_and_immutable():
    data = load()
    model = catalog(data)
    data['rooms'][0]['features'].append('changed')
    assert model.rooms[0].features == ()
    output = model.to_map()
    output['group_aliases'][0]['group_ids'].clear()
    assert len(model.group_aliases[0].group_ids) == 2


@pytest.mark.parametrize('mutate', [
    lambda d: d['rooms'][0].update(capacity=0),
    lambda d: d['cohort_terms'][0].update(study_stage=True),
    lambda d: d['faculty'][0].update(id='Teacher One'),
    lambda d: d['cohorts'][0].update(status='active', archived_on='2026-07-01'),
])
def test_invalid_resource_identity_capacity_and_lifecycle_reject(mutate):
    data = load()
    mutate(data)
    with pytest.raises(ValueError):
        catalog(data)


def test_shared_edge_whitespace_rules_reject_bom_only_codes_and_alias_collisions():
    data = load()
    data['departments'][0]['code'] = '\ufeff'
    with pytest.raises(ValueError):
        catalog(data)
    data = load()
    data['group_aliases'].append(dict(data['group_aliases'][0],
        id='00000000-0000-0000-0000-000000000099', label='\ufeffB+C'))
    with pytest.raises(ValueError, match='Duplicate'):
        catalog(data)
