import sys, os, time
sys.path.insert(0, os.path.abspath('engine'))
import json, re
from collections import defaultdict
from ortools.sat.python import cp_model
from room_policy import room_key
import ingest, solver

def is_ecl_room(room_name: str, aliases: dict | None = None) -> bool:
    key = room_key(room_name, aliases)
    return bool(re.match(r'^ECL([-_ \d]|$)', key))

def is_eee_course(code: str, dept: str | None = None) -> bool:
    clean_code = str(code).strip().upper()
    clean_dept = str(dept).strip().upper() if dept else ''
    return clean_code.startswith('EEE') or clean_dept == 'EEE'

def is_cse_course(code: str, dept: str | None = None) -> bool:
    clean_code = str(code).strip().upper()
    clean_dept = str(dept).strip().upper() if dept else ''
    return clean_code.startswith('CSE') or clean_dept == 'CSE'

with open('workbook/Main_Distribution_Summer25.xlsx', 'rb') as f:
    ds = ingest.ingest_bytes(f.read())

with open('.task1-local/showcase/summer-profile.json') as f:
    prof = json.load(f)

cfg = solver.load_config(prof['config'])
aliases = cfg.get('room_aliases') or {}
lab_rooms = cfg['lab_rooms']
ecl_labs = [r for r in lab_rooms if is_ecl_room(r, aliases)]
cse_labs = [r for r in lab_rooms if not is_ecl_room(r, aliases)]
n_ecl = len(ecl_labs)
n_cse = len(cse_labs)

print(f"ECL labs ({n_ecl}): {ecl_labs}")
print(f"CSE labs ({n_cse}): {cse_labs}")

# Let's run solve by monkey-patching or creating a test solver
# Let's inspect if solve works

