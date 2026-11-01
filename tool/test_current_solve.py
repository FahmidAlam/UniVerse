import sys, os
sys.path.insert(0, os.path.abspath('engine'))
import json
import ingest, solver

# Load summer distribution
with open('workbook/Main_Distribution_Summer25.xlsx', 'rb') as f:
    ds = ingest.ingest_bytes(f.read())

# Load summer profile
with open('.task1-local/showcase/summer-profile.json') as f:
    prof = json.load(f)

cfg = solver.load_config(prof['config'])

print("Starting test solve with new logic...")
# Let's see how solver currently solves
res = solver.solve(ds, cfg, time_limit_s=60)
print("Current solve status:", res['stats']['status'])
print("Validation ok:", res['validation']['ok'])

