"""Comprehensive verification script comparing:
- workbook/new/new_CSE_Routine_Summer_2025.xlsx (Original generated routine with violations)
- workbook/new/corrected_CSE_Routine_Summer_2025.xlsx (Corrected generated routine)
"""
import openpyxl
from pathlib import Path
import re
import sys

ORIG_PATH = Path("workbook/new/new_CSE_Routine_Summer_2025.xlsx")
CORR_PATH = Path("workbook/new/corrected_CSE_Routine_Summer_2025.xlsx")

lab_rooms = {"ACL-1", "ACL-2", "ACL-3", "ACL-4", "GL", "NL", "ECL-1", "ECL-2"}
ecl_rooms = {"ECL-1", "ECL-2"}
cse_lab_rooms = {"ACL-1", "ACL-2", "ACL-3", "ACL-4", "GL", "NL"}

def audit_workbook(path: Path):
    wb = openpyxl.load_workbook(path, data_only=True)
    report = {
        "eee_lab_assignments": [],
        "cse_lab_assignments": [],
        "other_lab_assignments": [],
        "eee_violations": [],
        "cse_violations": [],
        "faculty_pending_cells": [],
        "tba_cells": [],
        "legend_sunday": None,
        "legend_other_days": [],
    }

    for sname in wb.sheetnames:
        ws = wb[sname]
        # Check legend at row 50..65
        for r in range(50, 70):
            val = ws.cell(row=r, column=2).value
            if val and "TBA" in str(val) and "To Be Announced" in str(val):
                if sname == "Sunday":
                    report["legend_sunday"] = (r, val)
                else:
                    report["legend_other_days"].append((sname, r, val))

        for r in range(1, ws.max_row + 1):
            for c in range(1, ws.max_column + 1):
                cell_val = ws.cell(row=r, column=c).value
                if not cell_val or not isinstance(cell_val, str):
                    continue

                if "FACULTY-PENDING" in cell_val:
                    report["faculty_pending_cells"].append((sname, r, c, cell_val))

                for part in cell_val.split("/"):
                    tokens = part.strip().split()
                    if len(tokens) >= 2:
                        code = tokens[0].upper()
                        room = tokens[-1].upper()
                        # Faculty token check
                        if "TBA" in tokens:
                            report["tba_cells"].append((sname, r, c, cell_val))

                        if room in lab_rooms:
                            info = {"day": sname, "row": r, "col": c, "code": code, "room": room, "text": part.strip()}
                            if code.startswith("EEE"):
                                report["eee_lab_assignments"].append(info)
                                if room not in ecl_rooms:
                                    report["eee_violations"].append(info)
                            elif code.startswith("CSE"):
                                report["cse_lab_assignments"].append(info)
                                if room in ecl_rooms:
                                    report["cse_violations"].append(info)
                            else:
                                report["other_lab_assignments"].append(info)

    return report

print("Auditing original workbook:", ORIG_PATH)
orig_rep = audit_workbook(ORIG_PATH)

print("Auditing corrected workbook:", CORR_PATH)
corr_rep = audit_workbook(CORR_PATH)

print("\n=================== AUDIT RESULTS COMPARISON ===================")
print(f"Original EEE lab violations: {len(orig_rep['eee_violations'])} / {len(orig_rep['eee_lab_assignments'])}")
print(f"Corrected EEE lab violations: {len(corr_rep['eee_violations'])} / {len(corr_rep['eee_lab_assignments'])}")
print("  Corrected EEE Lab Room Distribution:")
from collections import Counter
eee_rooms = Counter(x["room"] for x in corr_rep["eee_lab_assignments"])
for rm, count in sorted(eee_rooms.items()):
    print(f"    {rm}: {count} sessions (ECL only)")

print(f"\nOriginal CSE lab violations: {len(orig_rep['cse_violations'])} / {len(orig_rep['cse_lab_assignments'])}")
print(f"Corrected CSE lab violations: {len(corr_rep['cse_violations'])} / {len(corr_rep['cse_lab_assignments'])}")
print("  Corrected CSE Lab Room Distribution:")
cse_rooms = Counter(x["room"] for x in corr_rep["cse_lab_assignments"])
for rm, count in sorted(cse_rooms.items()):
    print(f"    {rm}: {count} sessions (Non-ECL only)")

print(f"\nOriginal FACULTY-PENDING occurrences: {len(orig_rep['faculty_pending_cells'])}")
print(f"Corrected FACULTY-PENDING occurrences: {len(corr_rep['faculty_pending_cells'])}")

print(f"\nOriginal TBA occurrences: {len(orig_rep['tba_cells'])}")
print(f"Corrected TBA occurrences: {len(corr_rep['tba_cells'])}")
print("  Sample Corrected TBA Cells:")
for sname, r, c, val in corr_rep["tba_cells"][:5]:
    print(f"    [{sname} R{r}C{c}]: {val}")

print(f"\nSunday Legend check in corrected workbook:")
print(f"  Sunday: {corr_rep['legend_sunday']}")
print(f"  Other days repeated count: {len(corr_rep['legend_other_days'])} (expected 0)")

assert len(corr_rep["eee_violations"]) == 0, f"Found {len(corr_rep['eee_violations'])} EEE violations in corrected!"
assert len(corr_rep["cse_violations"]) == 0, f"Found {len(corr_rep['cse_violations'])} CSE violations in corrected!"
assert len(corr_rep["faculty_pending_cells"]) == 0, f"Found {len(corr_rep['faculty_pending_cells'])} FACULTY-PENDING cells in corrected!"
assert len(corr_rep["tba_cells"]) > 0, "No TBA cells found in corrected!"
assert corr_rep["legend_sunday"] is not None, "Legend missing on Sunday in corrected!"
assert len(corr_rep["legend_other_days"]) == 0, "Legend incorrectly repeated on other days!"

print("\nALL VERIFICATION ASSERTIONS PASSED PERFECTLY!")

