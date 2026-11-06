import json, sys, time
from pathlib import Path
sys.path.insert(0, "engine")
import ingest, solver, render

file_path = Path("workbook/new/Main_Distribution_Fall 2026.xlsx")
data = file_path.read_bytes()
ds = ingest.ingest_bytes(data)

profile_path = Path("workbook/new/fall-2026-profile.json")
profile = json.loads(profile_path.read_text(encoding="utf-8"))
cfg = solver.load_config(profile["config"])

print("Running CP-SAT solver for Fall 2026 with matching profile...")
t0 = time.time()
res = solver.solve(ds, cfg, time_limit_s=60.0)
t1 = time.time()

print(f"Solve completed in {t1 - t0:.2f}s!")
print("Status:", res["stats"]["status"])
print(f"Meetings scheduled: {res['stats']['meetings']} regular + {res['stats']['service_meetings']} service = {res['stats']['meetings'] + res['stats']['service_meetings']} total")
print("Validation OK:", res["validation"]["ok"])
print("Lab room violations:", res["validation"]["lab_room_violations"])
print("Teacher clashes:", res["validation"]["teacher_clashes"])
print("Room clashes:", res["validation"]["room_clashes"])
print("Cohort clashes:", res["validation"]["cohort_clashes"])

if not res["validation"]["ok"]:
    for k, v in res["validation"]["details"].items():
        if v:
            print(f"  {k} ({len(v)}): {v[:2]}")

out_xlsx = Path("workbook/new/CSE_Routine_Fall_2026_Generated.xlsx")
print("Rendering Excel workbook to:", out_xlsx)
all_rows = res["rows"] + res["service_rows"]
excel_bytes = render.render_bytes(all_rows, ds["cohorts"], cfg)
out_xlsx.write_bytes(excel_bytes)
print(f"Saved {len(excel_bytes)} bytes successfully!")

