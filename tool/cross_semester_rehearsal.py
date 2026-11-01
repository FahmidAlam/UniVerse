"""Private, repeatable source-to-engine-to-workbook acceptance rehearsal.

Run from repository root. All source-derived artifacts stay in ignored
.task1-local/cross-semester. No hosted writes, source edits or deployments.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
from copy import deepcopy
import hashlib
import io
import json
import math
import re
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'engine'))
import ingest
import render
import solver
from room_policy import room_key
import openpyxl

OUT = ROOT / '.task1-local/cross-semester'
SOURCE = ROOT / 'workbook/Main_Distribution_Summer25.xlsx'


def save(name, value):
    (OUT / name).write_text(json.dumps(value, indent=2, default=list), encoding='utf-8')


def key(row):
    return (str(row['batch']), str(row.get('section') or ''), row['subject_code'])


def minutes(value):
    h, m = str(value).split(':')[:2]
    return int(h)*60+int(m)


def independent_audit(rows, expected, cfg):
    """Does not call the production validator or reuse its clash counters."""
    counts = Counter(key(r) for r in rows)
    issues = Counter()
    rooms = {room_key(r, cfg['room_aliases']) for r in cfg['lab_rooms']+cfg['theory_rooms']}
    slots = {int(p['idx']):p for p in cfg['periods']}
    resources = defaultdict(list)
    for r in rows:
        k = key(r)
        e = expected.get(k)
        if e is None:
            issues['unexpected'] += 1
            continue
        if set(r.get('teachers') or []) != set(e['teachers']):
            issues['teacher_assignment'] += 1
        if r.get('teacher_code') != e['primary']:
            issues['printed_teacher'] += 1
        if 'title' in e and r.get('subject') != e['title']:
            issues['course_title'] += 1
        if 'is_service' in e and bool(r.get('is_service')) != e['is_service']:
            issues['service_classification'] += 1
        start, end = minutes(r['time_start']), minutes(r['time_end'])
        p = slots.get(int(r['period']))
        if not p or (start,end)!=(minutes(p['start']),minutes(p['end'])) or end<=start:
            issues['clock'] += 1
        if r['day'] not in cfg['days'] or int(r['period']) in cfg['blocked_periods'].get(r['day'],set()) or int(r['period']) in cfg['excluded_periods']:
            issues['forbidden_slot'] += 1
        rk=room_key(r['room'],cfg['room_aliases'])
        if rk not in rooms: issues['room_inventory'] += 1
        metadata=next((v for k,v in cfg['room_metadata'].items() if room_key(k,cfg['room_aliases'])==rk),{})
        if e.get('students') is not None and metadata.get('capacity') is not None and e['students']>metadata['capacity']:
            issues['room_capacity'] += 1
        if r.get('is_lab') and rk not in {room_key(k,cfg['room_aliases']) for k in cfg['lab_rooms']}:
            issues['lab_room'] += 1
        for t in r.get('teachers') or []:
            if r['day'] in cfg['off_days'].get(t,set()): issues['faculty_off_day'] += 1
            resources[(r['day'],'teacher',t)].append((start,end))
        resources[(r['day'],'room',rk)].append((start,end))
        for section in str(r.get('section') or '').split('+'):
            resources[(r['day'],'group',r['batch'],section.strip())].append((start,end))
    for k,e in expected.items():
        if counts[k]!=e['count']: issues['meeting_count'] += 1
    for resource, intervals in resources.items():
        for i,(a,b) in enumerate(intervals):
            for c,d in intervals[i+1:]:
                if a<d and c<b: issues[resource[1]+'_overlap'] += 1
    return dict(issues)


def distribution_expected(path, weeks=14):
    """Independent direct-cell reconciliation, including split-teacher rows."""
    ws=openpyxl.load_workbook(path,data_only=True)['Course Distribution']
    acc={}
    for cells in ws.iter_rows(min_row=6,values_only=True):
        b,s,c,title,credit,pre,dept,students,t,total,dur,hint=tuple(cells[:12])
        if not b or not c: continue
        b=str(int(b)) if isinstance(b,(float,int)) else str(b).strip()
        k=(b,str(s).strip() if s is not None else '',str(c).strip())
        e=acc.setdefault(k,dict(teachers=[],primary=None,total=0,has_total=False,hint=hint,pending=False,title=str(title).strip() if title else str(c).strip(),students=students))
        if len(cells)>12 and isinstance(cells[12],bool): e['is_service']=cells[12]
        if t is not None and str(t).strip():
            t=str(t).strip()
            if t not in e['teachers']: e['teachers'].append(t)
        else: e['pending']=True
        if total is not None:
            e['total']+=int(total);e['has_total']=True
    for e in acc.values():
        e['primary']=None if e['pending'] or not e['teachers'] else e['teachers'][0]
        e['count']=max(1,math.ceil(e['total']/weeks)) if e['has_total'] else int(e['hint'] or 2)
    return acc


def rendered_audit(blob, rows, cohorts, cfg):
    wb=openpyxl.load_workbook(io.BytesIO(blob),data_only=True)
    actual=Counter()
    for i,cohort in enumerate(cohorts,start=render.DATA_FIRST_ROW):
        for day in cfg['days']:
            if day not in wb: continue
            for p in cfg['periods']:
                value=wb[day][f"{p['col']}{i}"].value
                if value:
                    actual[(day,cohort,int(p['idx']),str(value))]+=1
    expected=Counter((r['day'],f"{r['batch']}-{r['section']}" if r['section'] else str(r['batch']),int(r['period']),
                      f"{r['subject_code']} {r.get('teacher_code') or 'TBA'} {r['room']}") for r in rows)
    def matches(label,start,end):
        m=re.fullmatch(r'(\d{1,2}):(\d{2})-(\d{1,2}):(\d{2})(AM|PM)',str(label or ''))
        if not m: return False
        sh,sm,eh,em=map(int,m.groups()[:4])
        a,b=minutes(start),minutes(end)
        return (sh%12,sm,eh%12,em,m[5])==(a//60%12,a%60,b//60%12,b%60,'AM' if b<720 else 'PM')
    header_errors=0
    for day in cfg['days']:
        usable=[p for p in cfg['periods'] if int(p['idx']) not in cfg['excluded_periods'] and int(p['idx']) not in cfg['blocked_periods'].get(day,set())]
        for p in usable:
            if not matches(wb[day][f"{p['col']}2"].value,p['start'],p['end']): header_errors+=1
        for a,b in zip(usable,usable[1:]):
            if a['end']!=b['start']:
                if not matches(wb[day][f"{cfg.get('break_col','G')}2"].value,a['end'],b['start']): header_errors+=1
                break
    return {'missing_cells':sum((expected-actual).values()),'unexpected_cells':sum((actual-expected).values()),'header_errors':header_errors}


def reconstruct_live():
    snapshot=json.loads((ROOT/'.task1-local/cross-semester-live-snapshot.json').read_text())
    source=json.loads((ROOT/'.task1-local/advisor-fall2026-room-policy-parsed.json').read_text())
    fields=['day','batch','section','subject_code','teacher_code','room']
    identity=lambda r:tuple(r.get(k) for k in fields)
    assert Counter(map(identity,source))==Counter(map(identity,snapshot['rows'])), 'Live/source identities changed'
    # Explicitly reviewed clock correction only; original raw rows stay untouched.
    corrected=deepcopy(snapshot['rows'])
    corrections=0
    for r in corrected:
        if r['time_start']=='23:50:00' and r['time_end']=='12:50:00':
            r['time_start']='11:50:00';corrections+=1
    clockid=lambda r:identity(r)+(r['time_start'],r['time_end'])
    assert Counter(map(clockid,corrected))==Counter(map(clockid,source)), 'Unreviewed clock difference'
    groups=defaultdict(list)
    for r in corrected: groups[key(r)].append(r)
    # Reuse the supplied workbook's actual formatting and header layout.
    wb=openpyxl.load_workbook(SOURCE)
    ws=wb['Course Distribution']
    for sheet in list(wb):
        if sheet is not ws: wb.remove(sheet)
    ws['A3']='Fall 2026 OBSERVED ONLY - reconstructed weekly meetings, not approved requirements'
    ws.cell(5,13,'Is Service')
    for row in ws.iter_rows(min_row=6):
        for c in row:
            if c.__class__.__name__!='MergedCell': c.value=None
    n=6
    for (b,s,code),rr in sorted(groups.items()):
        assert len({r['is_service'] for r in rr})==1, 'Source service classification disagreement'
        teachers=list(dict.fromkeys(r['teacher_code'] or '' for r in rr))
        for teacher in teachers:
            values=[b,s,code,rr[0]['subject'],None,None,None,None,teacher or None,None,None,len(rr),rr[0]['is_service']]
            for col,v in enumerate(values,start=1): ws.cell(n,col,v)
            n+=1
    wb.create_sheet('Reconstruction Notes').append([
        'OBSERVED WEEKLY MEETINGS ONLY. Not an authoritative distribution. No inferred credits, term totals, enrollment, faculty availability or room permissions. All repeated retake meetings retained.'])
    path=OUT/'Fall2026_OBSERVED_ONLY_distribution.xlsx';wb.save(path)
    save('live-provenance.json',dict(versions=snapshot['versions'],raw_rows=len(corrected),
        reviewed_clock_normalizations=corrections,retake_rows_removed=0,
        raw_snapshot_sha256=hashlib.sha256((ROOT/'.task1-local/cross-semester-live-snapshot.json').read_bytes()).hexdigest()))
    return path,corrected


def run(name,path,raw,expected,repeats,seconds):
    ds=ingest.ingest_path(str(path),weeks_in_term=14)
    parsed={(o['batch'],o['section'],o['code']):dict(count=o['required_sessions'],teachers=o['teachers'],primary=None if o['pending_faculty_source_rows'] or not o['teachers'] else o['teachers'][0]) for o in ds['offerings']}
    assert set(parsed)==set(expected), 'Ingest lost/added offerings'
    assert all(parsed[k]['count']==e['count'] and set(parsed[k]['teachers'])==set(e['teachers']) and parsed[k]['primary']==e['primary'] for k,e in expected.items()), 'Ingest/source reconciliation mismatch'
    cfg=solver.load_config(raw)
    save(name+'-config.json',raw)
    outcomes=[]
    for i in range(repeats):
        item={'run':i+1}
        print(name,i+1,'solving',flush=True)
        try:
            result=solver.solve(ds,cfg,time_limit_s=seconds)
            rows=result['rows']+result['service_rows']
            item.update(status=result['stats']['status'],meetings=len(rows),
                engine_ok=result['validation']['ok'],independent_issues=independent_audit(rows,expected,cfg),
                validation={k:v for k,v in result['validation'].items() if isinstance(v,(bool,int))},
                schedule_sha256=hashlib.sha256(json.dumps(rows,sort_keys=True).encode()).hexdigest())
            save(f'{name}-{i+1}.json',result)
            try:
                blob=render.render_bytes(result['rows'],ds['cohorts'],cfg)
                (OUT/f'{name}-{i+1}.xlsx').write_bytes(blob)
                item['workbook']=rendered_audit(blob,result['rows'],ds['cohorts'],cfg)
            except Exception as exc: item['workbook_error']=str(exc)
        except Exception as exc: item['error']=str(exc)
        outcomes.append(item)
        save(name+'-summary.json',dict(offerings=len(expected),expected_meetings=sum(e['count'] for e in expected.values()),excluded=len(ds['excluded']),runs=outcomes))
        print(name,i+1,json.dumps({k:v for k,v in item.items() if k not in ('validation','error')}),flush=True)
    return outcomes


def main():
    p=argparse.ArgumentParser();p.add_argument('--repeats',type=int,default=3);p.add_argument('--seconds',type=int,default=60);p.add_argument('--scenario',choices=['all','summer','fall'],default='all');args=p.parse_args()
    OUT.mkdir(exist_ok=True)
    source_hash=hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    originals=[SOURCE, ROOT/'.task1-local/advisor-current-fall2026.xlsx']
    hashes={str(path.relative_to(ROOT)):hashlib.sha256(path.read_bytes()).hexdigest() for path in originals}
    save('input-hashes.json',hashes)
    raw=json.loads((ROOT/'.task1-local/advisor-live-config.json').read_text())
    raw['settings']['fixed_sessions_per_week']=None
    summer=run('summer2025',SOURCE,raw,distribution_expected(SOURCE),args.repeats,args.seconds) if args.scenario in ('all','summer') else json.loads((OUT/'summer2025-summary.json').read_text())['runs']
    if args.scenario=='summer': return
    path,rows=reconstruct_live()
    expected=distribution_expected(path)
    fall=deepcopy(raw)
    # Observed codes are not evidence of employment/availability: this is an
    # explicitly relaxed reconstruction rehearsal, never a publication profile.
    fall['teachers']=[dict(acronym=t,off_days=[]) for t in sorted({r['teacher_code'] for r in rows if r['teacher_code']})]
    stages=defaultdict(set)
    for r in rows: stages[r['batch']].add(r['semester'])
    assert all(len(v)==1 for v in stages.values()), 'Source batch study-stage disagreement'
    spans=sorted({(r['time_start'][:5],r['time_end'][:5]) for r in rows})
    cols=['D','E','F','G','I','J','K','L']
    fall['settings'].update(semester_label='Fall2026 OBSERVED ONLY',semester_map={b:next(iter(v)) for b,v in stages.items()},break_col='H',periods=[dict(idx=i+1,start=a,end=b,col=cols[i]) for i,(a,b) in enumerate(spans)],online_periods=[8],allow_online_periods=True,blocked_periods={'Friday':[5]},friday_no_p4=False,allow_same_day_sessions=True)
    fall.update(room_aliases={'PHY LAB':'RAB-106'},unavailable_rooms=['RAB-104'])
    observed={room_key(r['room'],fall['room_aliases']) for r in rows}
    inventory={room_key(r['name'],fall['room_aliases']) for r in fall['rooms']}
    save('fall-inventory-gaps.json',dict(observed_not_in_catalog=sorted(observed-inventory),
        unknowns=['faculty current availability','room permissions/type/capacity for missing rooms','term totals/credits/enrollment','per-meeting split-teacher allocation'],
        relaxed_profile='Catalog rooms retained; no fabricated room metadata; observed teacher codes admitted with no claimed off-days. Same-day blocks allowed as observed.'))
    fallruns=run('fall2026-observed',path,fall,expected,args.repeats,args.seconds)
    assert hashlib.sha256(SOURCE.read_bytes()).hexdigest()==source_hash
    assert all(hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==digest for path,digest in hashes.items())
    passed=all(r.get('engine_ok') is True and not r.get('independent_issues') and
               'workbook' in r and not any(r['workbook'].values())
               for r in summer+fallruns)
    save('summary.json',dict(summer=summer,fall=fallruns,source_unchanged=True,passed=passed))
    if not passed: raise SystemExit('Acceptance failed: inspect private per-run summaries')


if __name__=='__main__': main()
