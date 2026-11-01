"""Regenerate Summer 2025 routine with laboratory allocation constraints and TBA rendering.

Saves output to workbook/new/corrected_CSE_Routine_Summer_2025.xlsx.
Preserves workbook/new/new_CSE_Routine_Summer_2025.xlsx unmodified.
"""
import json
from pathlib import Path
import sys
import time

sys.path.insert(0, "engine")
from ingest import ingest_bytes
from solver import load_config, solve
from render import render_bytes

DIST_PATH = Path("workbook/Main_Distribution_Summer25.xlsx")
PROFILE_PATH = Path(".task1-local/showcase/summer-profile.json")
OUTPUT_PATH = Path("workbook/new/corrected_CSE_Routine_Summer_2025.xlsx")

print("1. Ingesting distribution workbook:", DIST_PATH)
dist_bytes = DIST_PATH.read_bytes()
dataset = ingest_bytes(dist_bytes)
print(f"   Offerings: {len(dataset['offerings'])}, Sessions: {len(dataset['sessions'])}, Cohorts: {len(dataset['cohorts'])}")

print("2. Loading Summer profile configuration:", PROFILE_PATH)
profile_json = json.loads(PROFILE_PATH.read_text(encoding="utf-8"))
config = load_config(profile_json["config"])
print(f"   ECL labs ({len(config['ecl_lab_rooms'])}): {config['ecl_lab_rooms']}")
print(f"   CSE labs ({len(config['cse_lab_rooms'])}): {config['cse_lab_rooms']}")
print(f"   Theory rooms ({len(config['theory_rooms'])}): {config['theory_rooms'][:5]}...")

print("3. Solving routine with CP-SAT engine...")
t0 = time.time()
res = solve(dataset, config, time_limit_s=60.0)
t1 = time.time()
print(f"   Solve completed in {t1 - t0:.2f}s, status: {res['stats']['status']}")
print(f"   Meetings scheduled: {res['stats']['meetings']} regular + {res['stats']['service_meetings']} service")
print(f"   Validation OK: {res['validation']['ok']}")
print(f"   Lab room violations: {res['validation']['lab_room_violations']}")
print(f"   Teacher clashes: {res['validation']['teacher_clashes']}")
print(f"   Room clashes: {res['validation']['room_clashes']}")
print(f"   Cohort clashes: {res['validation']['cohort_clashes']}")

if not res["validation"]["ok"]:
    print("FATAL: Validation failed!")
    for k, v in res["validation"]["details"].items():
        if v:
            print(f"   {k}: {v[:3]}")
    sys.exit(1)

print("4. Rendering Excel workbook...")
all_rows = res["rows"] + res["service_rows"]
excel_bytes = render_bytes(all_rows, dataset["cohorts"], config)

print(f"5. Writing corrected workbook to {OUTPUT_PATH} ({len(excel_bytes)} bytes)...")
OUTPUT_PATH.write_bytes(excel_bytes)
print("   Saved successfully!")

