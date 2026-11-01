"""Synthetic regressions for advisor-demo correctness; no personal data."""
import copy
import pytest
import ingest
import solver
from conftest import build_workbook, make_config, make_row, period


def generated(rows=None, raw=None):
    dataset = ingest.ingest_bytes(build_workbook(rows or [make_row(classes=14)]))
    cfg = solver.load_config(raw or make_config())
    result = solver.solve(dataset, cfg, time_limit_s=2)
    return dataset, cfg, result


def validate(dataset, cfg, result):
    return solver._validate(dataset, cfg, result['rows']+result['service_rows'],
                            cfg['days'], {p['idx']:p for p in cfg['periods']})


def test_overlapping_clock_periods_reject_before_placing_by_period_id():
    with pytest.raises(ValueError, match='overlap'):
        solver.load_config(make_config(periods=[
            period(1,'09:00','10:30','D'),period(2,'10:00','11:30','E')]))


def test_combined_source_section_reserves_each_attending_group():
    raw=make_config(days=['Sunday'], periods=[period(1,'09:00','10:00','D')])
    with pytest.raises(RuntimeError):
        generated([make_row(section='B',teacher='AAA',classes=14),
                   make_row(section='B+C',code='CSE-1201',teacher='BBB',classes=14)],raw)


def test_validator_rejects_reassignment_away_from_distribution_teacher():
    ds,cfg,res=generated()
    res=copy.deepcopy(res)
    res['rows'][0].update(teacher_code='BBB',teachers=['BBB'])
    assert validate(ds,cfg,res)['teacher_assignment_mismatches']==1
    assert not validate(ds,cfg,res)['ok']


def test_validator_rejects_a_room_outside_configured_inventory():
    ds,cfg,res=generated()
    res['rows'][0]['room']='UNKNOWN-999'
    assert validate(ds,cfg,res)['unknown_rooms']==1
    assert not validate(ds,cfg,res)['ok']


def test_unknown_faculty_is_distinct_from_unconfigured_course_eligibility():
    ds,cfg,res=generated([make_row(teacher='UNKNOWN',classes=14)])
    assert res['validation']['unresolved_teachers']==1
    assert not res['validation']['ok']


def test_missing_faculty_preserves_required_course_as_pending_without_substitution():
    ds,cfg,res=generated([make_row(teacher=None,classes=14)])
    assert len(ds['offerings'])==1 and not ds['excluded']
    assert len(res['rows'])==1
    assert res['rows'][0]['teacher_code'] is None
    assert res['rows'][0]['teachers']==[]
    assert res['rows'][0]['room'] and res['rows'][0]['time_start']
    assert res['validation']['pending_faculty_assignments']==1
    assert res['validation']['ok']


def test_cse_retake_is_a_valid_rendered_course_not_an_external_service():
    ds,cfg,res=generated([make_row(batch='Retake',section='DLD',classes=14)])
    assert len(res['rows'])==1 and not res['service_rows']
    assert res['rows'][0]['batch']=='Retake'
    assert res['validation']['ok']


def test_pending_faculty_renders_explicit_marker_not_a_fictitious_teacher():
    import io
    import openpyxl
    import render
    ds,cfg,res=generated([make_row(teacher=None,classes=14)])
    wb=openpyxl.load_workbook(io.BytesIO(render.render_bytes(res['rows'],ds['cohorts'],cfg)))
    classes=[str(c.value) for sheet in wb for row in sheet for c in row if 'CSE-1101' in str(c.value or '')]
    assert len(classes)==1 and 'TBA' in classes[0]
    assert 'FACULTY-PENDING' not in classes[0]
    assert 'None' not in classes[0]


def test_assigned_row_cannot_silently_fill_a_pending_row_of_same_offering():
    ds,cfg,res=generated([make_row(teacher='AAA',classes=14),
                         make_row(teacher=None,classes=14)])
    assert ds['offerings'][0]['pending_faculty_source_rows']
    assert all(r['teacher_code'] is None and r['teachers']==['AAA'] for r in res['rows'])
    assert res['validation']['pending_faculty_assignments']==2
    assert res['validation']['ok']


def test_room_aliases_share_one_resource_and_room_usage_is_run_scoped():
    raw=make_config(days=['Sunday'],periods=[period(1,'09:00','10:00','D')])
    raw['rooms']=[{'name':'phy lab','is_lab':True},{'name':'RAB-106','is_lab':True}]
    raw['room_aliases']={'PHY LAB':'RAB-106'}
    cfg=solver.load_config(raw)
    assert len(cfg['lab_rooms'])==1
    with pytest.raises(RuntimeError):
        generated([make_row(code='CSE-1102',section='A',classes=14),
                   make_row(code='CSE-1202',section='B',teacher='BBB',classes=14)],raw)
    historical=make_config()
    historical['rooms']=[{'name':'RAB-104','is_lab':False}]
    assert solver.load_config(historical)['theory_rooms']==['RAB-104']
    current=copy.deepcopy(historical);current['unavailable_rooms']=['rab-104']
    assert solver.load_config(current)['theory_rooms']==[]


def test_legacy_room_arrays_cannot_inflate_physical_capacity():
    raw=make_config();raw.pop('rooms')
    raw.update(lab_rooms=['phy lab','RAB-106'],theory_rooms=['ROOM-1'],
               room_aliases={'PHY LAB':'RAB-106'})
    assert len(solver.load_config(raw)['lab_rooms'])==1
    raw['theory_rooms']=['RAB-106']
    with pytest.raises(ValueError,match='room kind'):
        solver.load_config(raw)


def test_validator_rechecks_capacity_after_manual_room_change():
    raw=make_config(n_theory=2)
    raw['rooms'][-2]['capacity']=20
    raw['rooms'][-1]['capacity']=200
    ds,cfg,res=generated([make_row(classes=14,students=100)],raw)
    res['rows'][0]['room']=raw['rooms'][-2]['name']
    assert validate(ds,cfg,res)['room_capacity_violations']==1
    assert not validate(ds,cfg,res)['ok']


def test_room_assignment_uses_known_capacity_when_source_enrollment_is_known():
    raw=make_config(n_theory=2)
    raw['rooms'][-2]['capacity']=20
    raw['rooms'][-1]['capacity']=200
    _,_,res=generated([make_row(classes=14,students=100)],raw)
    assert res['rows'][0]['room']==raw['rooms'][-1]['name']


def test_small_class_cannot_consume_only_room_suitable_for_large_class():
    raw=make_config(n_theory=2,days=['Sunday'],
                    periods=[period(1,'09:00','10:00','D')])
    raw['rooms'][-2]['capacity']=200
    raw['rooms'][-1]['capacity']=20
    _,_,res=generated([make_row(batch='70',teacher='AAA',classes=14,students=10),
                       make_row(batch='71',teacher='BBB',classes=14,students=100)],raw)
    assert res['validation']['ok']
    assert {r['batch']:r['room'] for r in res['rows']} == {
        '70':raw['rooms'][-1]['name'], '71':raw['rooms'][-2]['name']}
