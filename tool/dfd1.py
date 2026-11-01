# ============================================================
# tool/dfd1.py  ->  docs/diagrams/dfd-level-1.png
# Modern, spacious Level-1 Data Flow Diagram for UniVerse
# 10 Sub-processes (1.1-1.10), 12 Production Data Stores (D1-D12),
# External Entities, Multi-modal ingest, Campus exploration,
# Whitelist gating, and automated Notification Push Hub.
# Run: python tool/dfd1.py
# ============================================================
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Circle, Rectangle, FancyBboxPatch
import diagram_helpers as d

fig, ax = d.canvas((0, 380), (0, 260), figsize=(38, 26), dpi=140)

# ── Title ─────────────────────────────────────────────────────
ax.text(190, 252, "UniVerse — Level 1 Data Flow Diagram (Subsystem Architecture)",
        ha="center", va="center", fontsize=22, fontweight="bold", color="#0f172a")
ax.text(190, 245, "10 Functional Processes · 12 Production Data Stores · Dual Ingest Pipeline · Automated Push Dispatch",
        ha="center", va="center", fontsize=12, color="#475569")

# ── Process Drawing Helper ────────────────────────────────────
def proc(x, y, num, name, r=10.5, fc="#ffffff", ec="#1e3a8a"):
    ax.add_patch(Circle((x, y), r, facecolor=fc, edgecolor=ec, linewidth=2.0, zorder=4))
    chord_y = y + r * 0.32
    ax.plot([x - r * 0.94, x + r * 0.94], [chord_y, chord_y], color=ec, linewidth=1.4, zorder=5)
    ax.text(x, y + r * 0.62, num, ha="center", va="center", fontsize=11, fontweight="bold",
            color=ec, zorder=6)
    ax.text(x, y - r * 0.22, name, ha="center", va="center", fontsize=8.6, fontweight="bold",
            color="#0f172a", zorder=6)
    return (x, y, r)

# ── Data Store Helper (Gane-Sarson open rectangle) ────────────
def store(x, y, w, h, did, name, fc="#f8fafc", ec="#334155"):
    left, right = x - w / 2, x + w / 2
    top, bot = y + h / 2, y - h / 2
    # Background
    ax.add_patch(Rectangle((left, bot), w, h, facecolor=fc, edgecolor="none", zorder=3))
    # Open right side
    ax.plot([right, left, left, right], [top, top, bot, bot], color=ec, linewidth=1.6, zorder=4)
    # ID separator
    id_w = min(h * 1.2, w * 0.25)
    ax.plot([left + id_w, left + id_w], [top, bot], color=ec, linewidth=1.4, zorder=4)
    ax.text(left + id_w / 2, y, did, ha="center", va="center", fontsize=9.5, fontweight="bold",
            color="#b91c1c", zorder=5)
    ax.text((left + id_w + right) / 2, y, name, ha="center", va="center", fontsize=9.0,
            fontweight="bold", color="#0f172a", zorder=5)
    return (x, y, w, h)

# ── Flow Connector Helper ─────────────────────────────────────
def df(p1, p2, txt="", rad=0.0, off=(0, 0), double=False, fs=7.8, color="#334155"):
    d.arrow(ax, p1, p2, text=txt, fs=fs, rad=rad, off=off,
            double=double, color=color, lw=1.2)

# ══════════════════════════════════════════════════════════════
# EXTERNAL ENTITIES (Boundary Nodes)
# ══════════════════════════════════════════════════════════════
def draw_ext(x, y, w, h, text, color="#0284c7", bg="#f0f9ff"):
    b = FancyBboxPatch((x - w / 2, y - h / 2), w, h,
                       boxstyle="round,pad=0.2,rounding_size=1.2",
                       facecolor=bg, edgecolor=color, linewidth=2.0, zorder=4)
    ax.add_patch(b)
    ax.text(x, y, text, ha="center", va="center", fontsize=10.5,
            fontweight="bold", color="#0f172a", zorder=5)
    return (x, y)

ENT_STUDENT = draw_ext(30, 215, 38, 14, "Student (E1)", color="#0284c7", bg="#f0f9ff")
ENT_TEACHER = draw_ext(30, 145, 38, 14, "Teacher (E2)", color="#059669", bg="#f0fdf4")
ENT_ADMIN   = draw_ext(30, 45, 38, 14, "Admin (E3)",   color="#7c3aed", bg="#f5f3ff")
ENT_ENGINE  = draw_ext(345, 45, 44, 16, "Timetable Engine\n(Render / E4)", color="#166534", bg="#f0fdf4")
ENT_FCM     = draw_ext(345, 145, 42, 16, "Firebase FCM\n(Mobile Push / E5)", color="#c2410c", bg="#fff7ed")

# ══════════════════════════════════════════════════════════════
# DATA STORES (D1 - D12)
# ══════════════════════════════════════════════════════════════
D1  = store(105, 235, 34, 9, "D1", "Whitelists")
D2  = store(105, 195, 34, 9, "D2", "Profiles (Central)")
D8  = store(105, 155, 34, 9, "D8", "Device Tokens")
D9  = store(105, 80,  34, 9, "D9", "Resources")

D3  = store(205, 235, 36, 9, "D3", "Routines (Active)")
D4  = store(205, 195, 36, 9, "D4", "Routine Versions")
D5  = store(205, 155, 36, 9, "D5", "Cancellations")

D6  = store(295, 175, 38, 10, "D6", "Notifications (HUB)", fc="#fff1f2", ec="#be123c")
D7  = store(295, 120, 38, 9,  "D7", "Notification Reads")

D10 = store(205, 80,  36, 9, "D10", "Timetable Config")
D11 = store(205, 45,  36, 9, "D11", "Course Eligibility")
D12 = store(295, 45,  38, 9, "D12", "Timetable Runs")

# ══════════════════════════════════════════════════════════════
# PROCESSES (1.1 - 1.10)
# ══════════════════════════════════════════════════════════════
P11 = proc(55,  180, "1.1", "Auth &\nWhitelist Gate")
P15 = proc(55,  115, "1.5", "Profile\nManagement")
P12 = proc(155, 220, "1.2", "Routine\nViewing")
P13 = proc(155, 175, "1.3", "Campus\nExploration")
P16 = proc(155, 130, "1.6", "Class\nManagement")
P14 = proc(55,  80,  "1.4", "Resource\nManagement")
P17 = proc(295, 215, "1.7", "Notification &\nPush Dispatch")
P18 = proc(250, 105, "1.8", "Timetable Ingest\n& Atomic Publish", r=12)
P19 = proc(155, 60,  "1.9", "Academic &\nRules Config")
P110= proc(85,  35,  "1.10","Campus Governance\n& Whitelist")

# ══════════════════════════════════════════════════════════════
# DATA FLOWS (Clean, Non-bloated, Non-colliding Routing)
# ══════════════════════════════════════════════════════════════

# Process 1.1 (Auth)
df((ENT_STUDENT[0], ENT_STUDENT[1] - 7), (P11[0] - 8, P11[1] + 8), "credentials", rad=0.08)
df((ENT_TEACHER[0], ENT_TEACHER[1] + 7), (P11[0] - 8, P11[1] - 8), "credentials", rad=-0.08)
df((P11[0] + 8, P11[1] + 8), (D1[0] - 17, D1[1] - 2), "check whitelist (R)", rad=-0.08)
df((P11[0] + 10, P11[1]), (D2[0] - 17, D2[1]), "read/write profile (R/W)", double=True)
df((P11[0] + 8, P11[1] - 8), (D8[0] - 17, D8[1] + 2), "register token (W)", rad=0.08)

# Process 1.5 (Profile)
df((ENT_STUDENT[0], ENT_STUDENT[1] - 25), (P15[0] - 10, P15[1] + 4), "profile edit", rad=0.05)
df((P15[0] + 10, P15[1]), (D2[0] - 12, D2[1] - 5), "update profile (R/W)", double=True, rad=-0.12)

# Process 1.2 (Routine Viewing)
df((ENT_STUDENT[0] + 19, ENT_STUDENT[1] + 3), (P12[0] - 10, P12[1] + 4), "request schedule", rad=-0.08)
df((P12[0] + 10, P12[1] + 5), (D3[0] - 18, D3[1] - 2), "read class rows (R)", rad=0.05)
df((P12[0] + 10, P12[1] - 5), (D5[0] - 18, D5[1] + 4), "read cancellations (R)", rad=-0.12)
df((P12[0] - 6, P12[1] - 8), (ENT_STUDENT[0] + 19, ENT_STUDENT[1] - 3), "weekly routine grid", rad=0.08)

# Process 1.3 (Campus Exploration - Find Teacher & Rooms)
df((ENT_STUDENT[0] + 19, ENT_STUDENT[1] - 15), (P13[0] - 10, P13[1] + 5), "teacher/room query", rad=-0.08)
df((ENT_TEACHER[0] + 19, ENT_TEACHER[1] + 5), (P13[0] - 10, P13[1] - 5), "availability query", rad=0.08)
df((P13[0] + 10, P13[1] + 4), (D3[0] - 18, D3[1] - 5), "inspect live slots (R)", rad=0.12)
df((P13[0] - 10, P13[1] - 2), (ENT_STUDENT[0] + 19, ENT_STUDENT[1] - 18), "live room/teacher location", rad=0.08)

# Process 1.6 (Class Management - Faculty)
df((ENT_TEACHER[0] + 19, ENT_TEACHER[1] - 5), (P16[0] - 10, P16[1] + 2), "cancel/notice/undo", rad=-0.05)
df((P16[0] + 8, P16[1] + 5), (D3[0] - 15, D3[1] - 8), "read target slot (R)", rad=0.1)
df((P16[0] + 10, P16[1]), (D5[0] - 18, D5[1]), "write cancel (W)", rad=0.05)
df((P16[0] + 10, P16[1] + 8), (D6[0] - 19, D6[1] - 5), "class alert (W)", rad=0.12, color="#be123c")

# Process 1.4 (Resource Management)
df((P14[0] + 10, P14[1]), (D9[0] - 17, D9[1]), "read/write resources (R/W)", double=True)
df((P14[0] + 8, P14[1] + 8), (D6[0] - 19, D6[1] - 15), "upload alert (W)", rad=0.2, color="#be123c")

# Process 1.7 (Notification Pipeline & Push)
df((D6[0], D6[1] + 5), (P17[0], P17[1] - 10), "new alert event (R)", color="#be123c")
df((P17[0] - 8, P17[1] - 8), (D2[0] + 17, D2[1] + 4), "resolve audience (R)", rad=-0.12)
df((P17[0] - 10, P17[1] - 4), (D8[0] + 17, D8[1] + 4), "fetch tokens (R)", rad=-0.2)
df((P17[0] + 10, P17[1] - 5), (ENT_FCM[0] - 21, ENT_FCM[1] + 8), "dispatch payload + tokens", rad=-0.1, color="#c2410c")
df((ENT_FCM[0] - 2, ENT_FCM[1] - 8), (ENT_STUDENT[0] + 20, ENT_STUDENT[1] + 12), "native push alert", rad=-0.25, color="#c2410c")
df((P17[0], P17[1] - 10), (D7[0], D7[1] + 4), "track read receipts (R/W)", double=True)

# Process 1.8 (Timetable Ingest & Atomic Publishing)
df((ENT_ADMIN[0] + 19, ENT_ADMIN[1] + 8), (P18[0] - 12, P18[1] - 2), "upload distribution / workbook", rad=-0.1)
df((P18[0] - 8, P18[1] - 8), (D10[0] + 18, D10[1] + 2), "read solver config (R)", rad=-0.08)
df((P18[0] - 10, P18[1] - 4), (D11[0] + 18, D11[1] + 3), "validate eligibility (R)", rad=-0.05)
df((P18[0] + 12, P18[1] - 4), (ENT_ENGINE[0] - 22, ENT_ENGINE[1] + 6), "POST .xlsx + params (Solver)", rad=-0.1, color="#166534")
df((ENT_ENGINE[0] - 22, ENT_ENGINE[1] - 2), (P18[0] + 12, P18[1] - 8), "return solved rows & stats", rad=0.1, color="#166534")
df((P18[0] - 6, P18[1] + 11), (D4[0] + 18, D4[1] - 2), "activate version (W)", rad=0.08)
df((P18[0] - 12, P18[1] + 6), (D3[0] + 18, D3[1] - 5), "publish routines (Atomic RPC)", rad=0.12)
df((P18[0] + 8, P18[1] - 8), (D12[0] - 19, D12[1] + 4), "record run stats (W)", rad=0.08)
df((P18[0] + 10, P18[1] + 8), (D6[0] - 10, D6[1] - 5), "publish alert (W)", rad=0.1, color="#be123c")

# Process 1.9 (Academic & Rules Config)
df((ENT_ADMIN[0] + 19, ENT_ADMIN[1] + 2), (P19[0] - 10, P19[1] - 2), "manage rooms/faculty/settings", rad=-0.05)
df((P19[0] + 10, P19[1] + 3), (D10[0] - 18, D10[1] - 2), "rooms/faculty/settings (R/W)", double=True)
df((P19[0] + 10, P19[1] - 3), (D11[0] - 18, D11[1]), "manage eligibility (R/W)", double=True)

# Process 1.10 (Campus Governance & Whitelist)
df((ENT_ADMIN[0] + 19, ENT_ADMIN[1] - 4), (P110[0] - 10, P110[1] + 2), "add teacher / invite admin", rad=0.05)
df((P110[0] + 4, P110[1] + 8), (D1[0] - 10, D1[1] - 4), "provision whitelist (R/W)", double=True, rad=0.2)
df((P110[0] + 10, P110[1] - 2), (D6[0] - 15, D6[1] - 20), "broadcast alert (W)", rad=0.25, color="#be123c")

out = "docs/diagrams/dfd-level-1.png"
fig.savefig(out, dpi=140, facecolor="#ffffff", bbox_inches="tight", pad_inches=0.3)
print("wrote", out)
