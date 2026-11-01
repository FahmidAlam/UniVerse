# ============================================================
# tool/dfd0.py  ->  docs/diagrams/dfd-level-0.png
# Modern, high-clarity Level-0 (Context) Data Flow Diagram for UniVerse
# Includes all 5 boundary entities, clear balanced flows (F1-F10),
# multi-modal ingest, campus exploration queries, and push pipeline.
# Run: python tool/dfd0.py
# ============================================================
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Circle, FancyBboxPatch
import diagram_helpers as d

fig, ax = d.canvas((0, 260), (0, 180), figsize=(26, 18), dpi=140)

# ── Title ─────────────────────────────────────────────────────
ax.text(130, 174, "UniVerse — Level 0 Data Flow Diagram (Context Model)",
        ha="center", va="center", fontsize=20, fontweight="bold", color="#0f172a")
ax.text(130, 168, "System Boundary, External Entities, Multi-Modal Ingest, and Push Subsystem",
        ha="center", va="center", fontsize=11.5, color="#475569")

# ── Central Process (0 UniVerse) ──────────────────────────────
cx, cy, cr = 130, 92, 22
ax.add_patch(Circle((cx, cy), cr, facecolor="#f8fafc", edgecolor="#1e3a8a",
                    linewidth=2.8, zorder=3))
# Process number banner
ax.plot([cx - 21.2, cx + 21.2], [cy + 7.5, cy + 7.5], color="#1e3a8a",
        linewidth=1.8, zorder=4)
ax.text(cx, cy + 13.5, "0", ha="center", va="center", fontsize=16,
        fontweight="bold", color="#1e3a8a", zorder=5)
ax.text(cx, cy - 2.5, "UniVerse\nA Campus Companion", ha="center", va="center",
        fontsize=12, fontweight="bold", color="#0f172a", zorder=5)

# ── External Entities ─────────────────────────────────────────
def draw_entity(x, y, w, h, text, color="#1e293b", bg="#ffffff"):
    box = FancyBboxPatch((x - w / 2, y - h / 2), w, h,
                         boxstyle="round,pad=0.2,rounding_size=1.2",
                         facecolor=bg, edgecolor=color, linewidth=2.0, zorder=4)
    ax.add_patch(box)
    ax.text(x, y, text, ha="center", va="center", fontsize=11,
            fontweight="bold", color="#0f172a", zorder=5)
    return (x, y, w, h)

e_student = draw_entity(30, 138, 42, 18, "Student\n(E1)", color="#0284c7", bg="#f0f9ff")
e_teacher = draw_entity(30, 46, 42, 18, "Teacher\n(Faculty) (E2)", color="#059669", bg="#f0fdf4")
e_admin   = draw_entity(230, 138, 42, 18, "Admin\n(Department) (E3)", color="#7c3aed", bg="#f5f3ff")
e_engine  = draw_entity(230, 46, 46, 20, "Timetable Solver Engine\n(FastAPI / OR-Tools) (E4)", color="#166534", bg="#f0fdf4")
e_fcm     = draw_entity(130, 16, 48, 18, "Firebase FCM &\nMobile Push (E5)", color="#c2410c", bg="#fff7ed")

# ── Data Flow Helper ──────────────────────────────────────────
def flow(p1, p2, label, fid="", rad=0.0, off=(0, 0), fs=8.6):
    d.arrow(ax, p1, p2, text=label, fs=fs, rad=rad, off=off,
            color="#334155", lw=1.4)
    if fid:
        mx = (p1[0] + p2[0]) / 2 + off[0]
        my = (p1[1] + p2[1]) / 2 + off[1]
        ax.text(mx, my, fid, fontsize=8.0, fontweight="bold", color="#b91c1c",
                ha="center", va="center", zorder=8,
                bbox=dict(boxstyle="circle,pad=0.15", fc="#ffffff", ec="#b91c1c", lw=0.8))

# ── F1 & F2: Student Flows ────────────────────────────────────
flow((51, 144), (108, 104),
     "Credentials · profile edits · dismiss alerts\nFind Teacher & Room Availability queries",
     fid="F1", rad=0.06, off=(0, 4.5))

flow((110, 96), (51, 134),
     "Weekly routine · countdown · resources · alerts\nTeacher location & Room vacancy status",
     fid="F2", rad=0.06, off=(0, -4.5))

# ── F3 & F4: Teacher Flows ────────────────────────────────────
flow((51, 48), (110, 84),
     "Credentials (whitelist gated) · cancel class (date/reason)\nNotice/room change · Find Teacher & Room queries",
     fid="F3", rad=-0.06, off=(0, -4.5))

flow((108, 90), (51, 56),
     "Assigned routine · today's classes · cancellation status\nAlerts · Room vacancy status",
     fid="F4", rad=-0.06, off=(0, 4.5))

# ── F5 & F6: Admin Flows ──────────────────────────────────────
flow((209, 144), (152, 104),
     "Credentials · distribution .xlsx · pre-rendered .xlsx\nManual routine edits · config · broadcasts · staff whitelist",
     fid="F5", rad=-0.06, off=(0, 4.5))

flow((150, 96), (209, 134),
     "Solver diagnostics · active routine status\nUser directory · broadcast history · analytics",
     fid="F6", rad=-0.06, off=(0, -4.5))

# ── F7 & F8: Timetable Engine Flows ───────────────────────────
flow((151, 86), (207, 52),
     "Course distribution .xlsx\n+ solver parameters (time_limit, label)",
     fid="F7", rad=0.06, off=(0, -4.5))

flow((207, 44), (151, 78),
     "Generated timetable rows · service rows\nSolver stats · validation report · workbook bytes",
     fid="F8", rad=0.06, off=(0, 4.5))

# ── F9 & F10: Push Notification Subsystem ─────────────────────
flow((123, 70), (123, 25),
     "Notification payload + device tokens\n(via DB Webhook → Edge Function)",
     fid="F9", off=(-18, 0))

flow((137, 25), (137, 70),
     "Native OS push notifications\n(delivered to student & teacher phones)",
     fid="F10", off=(18, 0))

out = "docs/diagrams/dfd-level-0.png"
fig.savefig(out, dpi=140, facecolor="#ffffff", bbox_inches="tight", pad_inches=0.3)
print("wrote", out)
