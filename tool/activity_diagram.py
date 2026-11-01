# ============================================================
# tool/activity_diagram.py  ->  docs/diagrams/activity-diagram.png
# Modern, spacious Activity Diagram for UniVerse
# Three side-by-side vertical swimlanes:
#   Student / User  |  Teacher / Faculty  |  Admin
# Highly legible, unbloated, large text, accurate business logic.
# Run: python tool/activity_diagram.py
# ============================================================
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Circle, FancyBboxPatch, Polygon
import diagram_helpers as d

fig, ax = d.canvas((0, 380), (0, 240), figsize=(38, 24), dpi=140)

# ── Title ─────────────────────────────────────────────────────
ax.text(190, 234, "UniVerse — End-to-End System Activity Diagram",
        ha="center", va="center", fontsize=22, fontweight="bold", color="#0f172a")
ax.text(190, 227, "Role-Specific Execution Paths · Whitelist Gating (Migration 016) · Multi-Modal Routine Hub · Real-Time Campus Exploration",
        ha="center", va="center", fontsize=12, color="#475569")

# ── Swimlane Divider & Header Helper ──────────────────────────
def draw_swimlane(x1, x2, title, subtitle, header_bg="#1e3a8a"):
    w = x2 - x1
    # Swimlane boundary
    box = FancyBboxPatch((x1, 10), w, 206, boxstyle="round,pad=0.2,rounding_size=2.0",
                         facecolor="#ffffff", edgecolor="#cbd5e1", linewidth=1.6, zorder=1)
    ax.add_patch(box)
    # Header box
    hdr = FancyBboxPatch((x1, 198), w, 18, boxstyle="round,pad=0.2,rounding_size=1.8",
                          facecolor=header_bg, edgecolor="#cbd5e1", linewidth=1.6, zorder=2)
    ax.add_patch(hdr)
    ax.text((x1 + x2) / 2, 209, title, ha="center", va="center", fontsize=14,
            fontweight="bold", color="#ffffff", zorder=3)
    ax.text((x1 + x2) / 2, 203, subtitle, ha="center", va="center", fontsize=9.5,
            color="#e2e8f0", zorder=3)

draw_swimlane(10, 125, "Student / User Swimlane", "Self-Registration · Routine · Campus Explore · Resources", "#0369a1")
draw_swimlane(130, 245, "Teacher / Faculty Swimlane", "Whitelist Gated · Class Management (Cancellations) · Alerts", "#047857")
draw_swimlane(250, 370, "Admin Swimlane", "Routine Hub (Solver/Upload/CRUD) · Academic Config · Governance", "#6d28d9")

# ── Shape Drawing Helpers ─────────────────────────────────────
def act(x, y, text, w=28, h=7.5, fs=8.6, fc="#ffffff", ec="#1e293b", dashed=False):
    ls = (0, (5, 3)) if dashed else "solid"
    box = FancyBboxPatch((x - w / 2, y - h / 2), w, h,
                         boxstyle="round,pad=0.2,rounding_size=1.2",
                         facecolor=fc, edgecolor=ec, linewidth=1.4, linestyle=ls, zorder=4)
    ax.add_patch(box)
    ax.text(x, y, text, ha="center", va="center", fontsize=fs,
            fontweight="bold", color="#0f172a", zorder=5)
    return (x, y)

def dec(x, y, text, w=22, h=10, fs=8.0, fc="#f8fafc", ec="#1e293b"):
    pts = [(x, y + h / 2), (x + w / 2, y), (x, y - h / 2), (x - w / 2, y)]
    ax.add_patch(Polygon(pts, closed=True, facecolor=fc, edgecolor=ec, linewidth=1.4, zorder=4))
    ax.text(x, y, text, ha="center", va="center", fontsize=fs,
            fontweight="bold", color="#0f172a", zorder=5)
    return (x, y)

def start_node(x, y):
    ax.add_patch(Circle((x, y), 3.2, facecolor="#0f172a", edgecolor="none", zorder=5))
    return (x, y)

def end_node(x, y):
    ax.add_patch(Circle((x, y), 3.8, facecolor="none", edgecolor="#0f172a", linewidth=1.4, zorder=4))
    ax.add_patch(Circle((x, y), 2.4, facecolor="#0f172a", edgecolor="none", zorder=5))
    return (x, y)

def flow(p1, p2, label="", fs=7.8, rad=0.0, off=(0, 0), color="#1e293b"):
    d.arrow(ax, p1, p2, text=label, fs=fs, rad=rad, off=off, color=color, lw=1.2)

# ══════════════════════════════════════════════════════════════
# SWIMLANE 1: STUDENT
# ══════════════════════════════════════════════════════════════
# Entry
start_node(67.5, 192)
act(67.5, 181, "Create Account / Login\n(Google / Email)", w=34, h=8)
flow((67.5, 188.8), (67.5, 185))

dec(67.5, 166, "Verify\nCredentials?", w=24, h=9)
flow((67.5, 177), (67.5, 170.5))

# Error loopback
act(25, 166, "Show Error", w=18, h=6.5, fs=7.8, dashed=True)
flow((55.5, 166), (34, 166), "No", off=(0, 2))
flow((25, 169.5), (50, 181), rad=0.2)

act(67.5, 150, "Student Dashboard", w=28, h=7.5, fc="#e0f2fe", ec="#0369a1")
flow((67.5, 161.5), (67.5, 153.8), "Yes", off=(3, 0))

dec(67.5, 137, "Select\nFeature", w=22, h=8.5)
flow((67.5, 146.2), (67.5, 141.2))

# Fork Bar
FORK_Y_S = 126
ax.plot([20, 115], [FORK_Y_S, FORK_Y_S], color="#0f172a", linewidth=3.5, zorder=4)
flow((67.5, 132.8), (67.5, FORK_Y_S))

# Branches
# B1: Dashboard
flow((24, FORK_Y_S), (24, 118))
act(24, 114, "Live / Next Class\nCountdown", w=20, h=7.5)
act(24, 102, "Today's Schedule\n& Alerts", w=20, h=7.5)
flow((24, 110.2), (24, 105.8))

# B2: Routine
flow((46, FORK_Y_S), (46, 118))
act(46, 114, "Load Routine\n(Batch / Section)", w=20, h=7.5)
act(46, 102, "View Weekly Grid &\nCancelled Slots", w=20, h=7.5)
flow((46, 110.2), (46, 105.8))

# B3: Campus Explore
flow((68, FORK_Y_S), (68, 118))
act(68, 114, "Find Teacher:\nLive Classroom", w=20, h=7.5)
act(68, 102, "Room Availability:\nVacancy & Grid", w=20, h=7.5)
flow((68, 110.2), (68, 105.8))

# B4: Resources
flow((90, FORK_Y_S), (90, 118))
act(90, 114, "Browse Resources\nby Semester", w=20, h=7.5)
act(90, 102, "Download File /\nOpen Drive Link", w=20, h=7.5)
flow((90, 110.2), (90, 105.8))

# B5: Notifications & Profile
flow((111, FORK_Y_S), (111, 118))
act(111, 114, "View Notifications\n& Dismiss", w=20, h=7.5)
act(111, 102, "View & Update\nProfile Details", w=20, h=7.5)
flow((111, 110.2), (111, 105.8))

# Join Bar
JOIN_Y_S = 88
ax.plot([20, 115], [JOIN_Y_S, JOIN_Y_S], color="#0f172a", linewidth=3.5, zorder=4)
for bx_pos in [24, 46, 68, 90, 111]:
    flow((bx_pos, 98.2), (bx_pos, JOIN_Y_S))

dec(67.5, 74, "Sign Out?", w=20, h=8.5)
flow((67.5, JOIN_Y_S), (67.5, 78.2))
end_node(67.5, 56)
flow((67.5, 69.8), (67.5, 60), "Yes", off=(3, 0))
# No loopback
flow((77.5, 74), (120, 74))
ax.plot([120, 120], [74, 137], color="#1e293b", linewidth=1.2)
flow((120, 137), (78.5, 137), "No", off=(0, 2))

# ══════════════════════════════════════════════════════════════
# SWIMLANE 2: TEACHER / FACULTY
# ══════════════════════════════════════════════════════════════
start_node(187.5, 192)
act(187.5, 181, "Teacher Login\n(Google / Email)", w=32, h=8)
flow((187.5, 188.8), (187.5, 185))

dec(187.5, 167, "Verify\nCredentials?", w=22, h=8.5)
flow((187.5, 177), (187.5, 171.2))

# Whitelist Decision (Migration 016)
dec(187.5, 151, "Whitelisted as\nTeacher?", w=24, h=9)
flow((187.5, 162.8), (187.5, 155.5), "Yes", off=(3, 0))

# Not Whitelisted Screen
act(144, 151, "Not Whitelisted\nScreen", w=20, h=7.5, dashed=True)
flow((175.5, 151), (154, 151), "No", off=(0, 2))
act(144, 137, "Contact Admin /\nSwitch Account", w=20, h=7)
flow((144, 147.2), (144, 140.5))

act(187.5, 135, "Teacher Dashboard", w=28, h=7.5, fc="#ecfdf5", ec="#047857")
flow((187.5, 146.5), (187.5, 138.8))

dec(187.5, 122, "Select\nFeature", w=22, h=8.5)
flow((187.5, 131.2), (187.5, 126.2))

# Fork Bar
FORK_Y_T = 111
ax.plot([138, 237], [FORK_Y_T, FORK_Y_T], color="#0f172a", linewidth=3.5, zorder=4)
flow((187.5, 117.8), (187.5, FORK_Y_T))

# B1: Dashboard
flow((148, FORK_Y_T), (148, 103))
act(148, 99, "Live Teaching\nCountdown", w=20, h=7.5)
act(148, 87, "Today's Teaching\nRoster", w=20, h=7.5)
flow((148, 95.2), (148, 90.8))

# B2: Routine
flow((172, FORK_Y_T), (172, 103))
act(172, 99, "Load Routine\nby Acronym", w=20, h=7.5)
act(172, 87, "View Weekly\nSchedule Grid", w=20, h=7.5)
flow((172, 95.2), (172, 90.8))

# B3: Manage Classes (Signature Feature)
flow((198, FORK_Y_T), (198, 103))
act(198, 99, "Select Class Slot\n& Date", w=22, h=7.5)
act(198, 87, "Cancel Class /\nNotice / Undo", w=22, h=7.5)
act(198, 75, "Write DB Event →\nAuto Push to FCM", w=22, h=7.5, fc="#fff7ed", ec="#c2410c")
flow((198, 95.2), (198, 90.8))
flow((198, 83.2), (198, 78.8))

# B4: Campus Explore & Alerts
flow((226, FORK_Y_T), (226, 103))
act(226, 99, "Find Teacher &\nRoom Vacancy", w=20, h=7.5)
act(226, 87, "Dismiss Alerts &\nUpdate Profile", w=20, h=7.5)
flow((226, 95.2), (226, 90.8))

# Join Bar
JOIN_Y_T = 64
ax.plot([138, 237], [JOIN_Y_T, JOIN_Y_T], color="#0f172a", linewidth=3.5, zorder=4)
flow((148, 83.2), (148, JOIN_Y_T))
flow((172, 83.2), (172, JOIN_Y_T))
flow((198, 71.2), (198, JOIN_Y_T))
flow((226, 83.2), (226, JOIN_Y_T))

dec(187.5, 52, "Sign Out?", w=20, h=8.5)
flow((187.5, JOIN_Y_T), (187.5, 56.2))
end_node(187.5, 36)
flow((187.5, 47.8), (187.5, 40), "Yes", off=(3, 0))
# No loopback
flow((197.5, 52), (240, 52))
ax.plot([240, 240], [52, 122], color="#1e293b", linewidth=1.2)
flow((240, 122), (198.5, 122), "No", off=(0, 2))

# ══════════════════════════════════════════════════════════════
# SWIMLANE 3: ADMIN
# ══════════════════════════════════════════════════════════════
start_node(310, 192)
act(310, 181, "Admin Login\n(Google / Email)", w=32, h=8)
flow((310, 188.8), (310, 185))

dec(310, 166, "Admin Whitelist\nVerified?", w=26, h=9)
flow((310, 177), (310, 170.5))

# Deny loop
act(265, 166, "Access Denied", w=18, h=6.5, dashed=True)
flow((297, 166), (274, 166), "No", off=(0, 2))

act(310, 150, "Admin Dashboard", w=28, h=7.5, fc="#faf5ff", ec="#6d28d9")
flow((310, 161.5), (310, 153.8), "Yes", off=(3, 0))

dec(310, 137, "Select\nConsole", w=22, h=8.5)
flow((310, 146.2), (310, 141.2))

# Fork Bar
FORK_Y_A = 126
ax.plot([258, 362], [FORK_Y_A, FORK_Y_A], color="#0f172a", linewidth=3.5, zorder=4)
flow((310, 132.8), (310, FORK_Y_A))

# B1: Routine Hub (Triple Modal)
flow((270, FORK_Y_A), (270, 118))
act(270, 114, "Upload Distribution\n/ Workbook", w=22, h=7.5)
act(270, 102, "Run CP-SAT Engine\n/ Parse Sheets", w=22, h=7.5)
act(270, 90, "Atomic Routine\nPublish RPC", w=22, h=7.5, fc="#f0fdf4", ec="#166534")
flow((270, 110.2), (270, 105.8))
flow((270, 98.2), (270, 93.8))

# B2: Academic Config
flow((296, FORK_Y_A), (296, 118))
act(296, 114, "Manage Rooms &\nFaculty Directory", w=22, h=7.5)
act(296, 102, "Manage Course\nEligibility Matrix", w=22, h=7.5)
act(296, 90, "Configure Rules:\nWeeks & Limits", w=22, h=7.5)
flow((296, 110.2), (296, 105.8))
flow((296, 98.2), (296, 93.8))

# B3: Broadcasts
flow((322, FORK_Y_A), (322, 118))
act(322, 114, "Compose Campus\nBroadcast Alert", w=20, h=7.5)
act(322, 102, "Select Target &\nPush to FCM", w=20, h=7.5, fc="#fff7ed", ec="#c2410c")
flow((322, 110.2), (322, 105.8))

# B4: Staff Registration & Governance
flow((348, FORK_Y_A), (348, 118))
act(348, 114, "Add Teacher to WL\n/ Invite Admin", w=22, h=7.5)
act(348, 102, "Manage Users &\nLearning Resources", w=22, h=7.5)
flow((348, 110.2), (348, 105.8))

# Join Bar
JOIN_Y_A = 78
ax.plot([258, 362], [JOIN_Y_A, JOIN_Y_A], color="#0f172a", linewidth=3.5, zorder=4)
flow((270, 86.2), (270, JOIN_Y_A))
flow((296, 86.2), (296, JOIN_Y_A))
flow((322, 98.2), (322, JOIN_Y_A))
flow((348, 98.2), (348, JOIN_Y_A))

dec(310, 64, "Sign Out?", w=20, h=8.5)
flow((310, JOIN_Y_A), (310, 68.2))
end_node(310, 48)
flow((310, 59.8), (310, 52), "Yes", off=(3, 0))
# No loopback
flow((320, 64), (365, 64))
ax.plot([365, 365], [64, 137], color="#1e293b", linewidth=1.2)
flow((365, 137), (321, 137), "No", off=(0, 2))

out = "docs/diagrams/activity-diagram.png"
fig.savefig(out, dpi=140, facecolor="#ffffff", bbox_inches="tight", pad_inches=0.3)
print("wrote", out)
