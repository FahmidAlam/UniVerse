import sys, os, re
sys.path.insert(0, os.path.abspath('engine'))
import json
from room_policy import room_key

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

with open('.task1-local/showcase/summer-profile.json') as f:
    prof = json.load(f)

cfg_raw = prof['config']
aliases = cfg_raw.get('room_aliases') or {}
lab_rooms = [r['name'] for r in cfg_raw['rooms'] if r.get('is_lab')]
ecl_labs = [r for r in lab_rooms if is_ecl_room(r, aliases)]
cse_labs = [r for r in lab_rooms if not is_ecl_room(r, aliases)]

print("Total lab rooms:", len(lab_rooms), lab_rooms)
print("ECL labs:", len(ecl_labs), ecl_labs)
print("CSE labs:", len(cse_labs), cse_labs)

assert set(ecl_labs) == {'ECL-1', 'ECL-2'}
assert set(cse_labs) == {'ACL-1', 'ACL-2', 'ACL-3', 'ACL-4', 'GL', 'NL'}
print("Room partitioning verified successfully!")

