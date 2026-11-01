"""Independent acceptance across changed distributions; synthetic identities."""
from copy import deepcopy
import io
import sys
from pathlib import Path

import pytest
import openpyxl
from conftest import build_workbook, make_config, make_row, period
import ingest
import render
import solver

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'tool'))
from cross_semester_rehearsal import independent_audit, rendered_audit


@pytest.mark.parametrize('generation', range(3))
@pytest.mark.parametrize('season', ['summer', 'winter'])
def test_changed_source_fields_and_scoped_resources_survive_generation(season, generation):
    winter=season=='winter'
    teacher='NEW-FACULTY' if winter else 'OLD-FACULTY'
    batch='93' if winter else '81'
    code='CSE-7301' if winter else 'CSE-2101'
    start,end=('10:20','11:20') if winter else ('08:10','09:25')
    rows=[make_row(batch=batch,section='B+C',code=code,title='Changed Course' if winter else 'Original Course',teacher=teacher,classes=14),
          make_row(batch=batch,section='B',code='CSE-9003',teacher=None,classes=14)]
    raw=make_config(teachers=[teacher],days=['Monday','Tuesday'],periods=[period(1,start,end,'D')],semester_map={batch:3 if winter else 1})
    raw['rooms']=[dict(name='ROOM-202' if winter else 'ROOM-101',is_lab=False,capacity=40)]
    cfg=solver.load_config(raw)
    ds=ingest.ingest_bytes(build_workbook(rows))
    expected={(batch,'B+C',code):dict(count=1,teachers=[teacher],primary=teacher),
              (batch,'B','CSE-9003'):dict(count=1,teachers=[],primary=None)}
    result=solver.solve(ds,cfg,time_limit_s=2)
    all_rows=result['rows']+result['service_rows']
    assert result['validation']['ok']
    assert independent_audit(all_rows,expected,cfg)=={}
    assert {r['semester'] for r in all_rows}=={3 if winter else 1}
    assert next(r for r in all_rows if r['subject_code']==code)['subject']==('Changed Course' if winter else 'Original Course')
    assert {r['room'] for r in all_rows}=={'ROOM-202' if winter else 'ROOM-101'}
    assert rendered_audit(render.render_bytes(result['rows'],ds['cohorts'],cfg),result['rows'],ds['cohorts'],cfg)==dict(missing_cells=0,unexpected_cells=0,header_errors=0)
    # Prove the independent checker is capable of finding a corrupted result.
    damaged=deepcopy(all_rows);damaged[0]['time_end']=damaged[0]['time_start']
    assert independent_audit(damaged,expected,cfg)['clock']==1
    assert independent_audit(all_rows[:-1],expected,cfg)['meeting_count']==1


def test_removed_faculty_does_not_receive_implicit_replacement():
    ds=ingest.ingest_bytes(build_workbook([make_row(teacher='REMOVED',classes=14)]))
    result=solver.solve(ds,solver.load_config(make_config(teachers=['REPLACEMENT'])),time_limit_s=2)
    assert result['rows'][0]['teacher_code']=='REMOVED'
    assert result['validation']['unresolved_teachers']==1
    assert not result['validation']['ok']


def test_configured_extra_period_column_cannot_retain_an_old_class(tmp_path):
    raw=make_config(days=['Monday','Tuesday'],periods=[period(8,'19:00','20:00','L')])
    cfg=solver.load_config(raw)
    wb=openpyxl.load_workbook(render.TEMPLATE)
    wb['Tuesday']['L3']='STALE-1001 OLD ROOM-1'
    template=tmp_path/'expanded.xlsx';wb.save(template)
    row=dict(day='Monday',batch='93',section='A',subject_code='CSE-9001',
             teacher_code='AAA',room='R-101',period=8)
    blob=render.render_bytes([row],['93-A'],cfg,template_path=template)
    result=openpyxl.load_workbook(io.BytesIO(blob))
    assert result['Monday']['L3'].value=='CSE-9001 AAA R-101'
    assert result['Tuesday']['L3'].value is None


@pytest.mark.parametrize('columns', [('G',),('B',),('D','D')])
def test_unsafe_template_period_columns_fail_explicitly(columns):
    cfg=solver.load_config(make_config(periods=[period(i+1,f'{9+i:02d}:00',f'{10+i:02d}:00',c) for i,c in enumerate(columns)]))
    with pytest.raises(ValueError,match='column'):
        render.render_bytes([],['93-A'],cfg)


@pytest.mark.parametrize('label,flag', [('M. Sc',False),('95',True)])
def test_explicit_source_service_flag_wins_over_batch_label(label,flag):
    wb=openpyxl.load_workbook(io.BytesIO(build_workbook([make_row(batch=label,classes=14)])))
    ws=wb['Course Distribution'];ws.cell(5,13,'Is Service');ws.cell(6,13,flag)
    data=io.BytesIO();wb.save(data)
    ds=ingest.ingest_bytes(data.getvalue())
    assert ds['offerings'][0]['is_service'] is flag


def test_ambiguous_explicit_service_flag_is_not_silently_guessed():
    wb=openpyxl.load_workbook(io.BytesIO(build_workbook([make_row(classes=14)])))
    ws=wb['Course Distribution'];ws.cell(5,13,'Is Service');ws.cell(6,13,'maybe')
    data=io.BytesIO();wb.save(data)
    with pytest.raises(ValueError,match='Is Service'):
        ingest.ingest_bytes(data.getvalue())


def test_four_morning_periods_use_configured_break_position():
    raw=make_config(periods=[period(1,'10:50','11:50','F'),period(2,'11:50','12:50','G'),period(3,'13:10','14:10','I')])
    raw['settings']['break_col']='H'
    cfg=solver.load_config(raw)
    row=dict(day='Monday',batch='93',section='A',subject_code='CSE-9001',teacher_code='AAA',room='R-101',period=2)
    blob=render.render_bytes([row],['93-A'],cfg)
    wb=openpyxl.load_workbook(io.BytesIO(blob))
    assert wb['Monday']['G3'].value=='CSE-9001 AAA R-101'
    assert wb['Monday']['G2'].value=='11:50-12:50PM'
    assert wb['Monday']['H2'].value=='12:50-1:10PM'
    assert wb['Friday']['H2'].value=='12:50-1:10PM'
