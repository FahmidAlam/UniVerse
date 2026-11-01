# ============================================================
# tool/usecase_diagram.py -> docs/diagrams/use-case-diagram.png
# Modern, spacious Use Case Diagram for UniVerse
# Includes all 3 human actors, 3 external systems, and complete
# feature packages (Campus Explore, Routine Hub, Academic Config,
# Whitelist Gating, Push Notification Pipeline).
# Run: python tool/usecase_diagram.py
# ============================================================
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle, FancyBboxPatch, Ellipse
import diagram_helpers as d

fig, ax = d.canvas((0, 360), (0, 240), figsize=(36, 24), dpi=140)

# ── Title ─────────────────────────────────────────────────────
ax.text(180, 234, "UniVerse — Comprehensive System Use Case Diagram",
        ha="center", va="center", fontsize=22, fontweight="bold", color="#0f172a")
ax.text(180, 228, "Human Actors, External Subsystems, Multi-Modal Ingest, and Automated Notification Pipeline",
        ha="center", va="center", fontsize=12, color="#475569")

# ── System Boundary ───────────────────────────────────────────
boundary = FancyBboxPatch((44, 10), 266, 212,
                          boxstyle="round,pad=0.5,rounding_size=3.0",
                          facecolor="#f8fafc", edgecolor="#1e293b",
                          linewidth=2.2, zorder=1)
ax.add_patch(boundary)
ax.text(52, 218, "System Boundary: UniVerse — A Campus Companion",
        fontsize=13, fontweight="bold", color="#1e3a8a", zorder=3)

# ── Primary Human Actors (Left) ───────────────────────────────
ST_POS = (22, 160)
TE_POS = (22, 100)
AD_POS = (22, 40)

d.actor(ax, ST_POS[0], ST_POS[1], "Student", s=3.8, zorder=5)
d.actor(ax, TE_POS[0], TE_POS[1], "Teacher\n(Faculty)", s=3.8, zorder=5)
d.actor(ax, AD_POS[0], AD_POS[1], "Admin\n(Department)", s=3.8, zorder=5)

# Role Generalization (Teacher & Admin inherit Common student capabilities)
def gen_arrow(p1, p2):
    ax.annotate("", xy=p2, xytext=p1,
                arrowprops=dict(arrowstyle="-|>", color="#334155", lw=1.6,
                                facecolor="#ffffff", edgecolor="#334155", mutation_scale=14))
gen_arrow((TE_POS[0], TE_POS[1] + 12), (ST_POS[0], ST_POS[1] - 8))
gen_arrow((AD_POS[0], AD_POS[1] + 12), (TE_POS[0], TE_POS[1] - 8))

# ── Secondary External Actors (Right) ─────────────────────────
AUTH_POS = (335, 185)
ENG_POS  = (335, 105)
FCM_POS  = (335, 35)

d.box(ax, AUTH_POS[0], AUTH_POS[1], 36, 15,
      "Supabase Auth /\nGoogle OAuth", bold=True, fs=9.5, fc="#eff6ff", ec="#1e40af", rounded=True)
d.box(ax, ENG_POS[0], ENG_POS[1], 36, 15,
      "Timetable Engine\n(FastAPI / OR-Tools)", bold=True, fs=9.5, fc="#f0fdf4", ec="#166534", rounded=True)
d.box(ax, FCM_POS[0], FCM_POS[1], 36, 16,
      "Supabase Webhook\n& Firebase FCM", bold=True, fs=9.5, fc="#fff7ed", ec="#9a3412", rounded=True)

# ── Use Case Ellipse Helper ───────────────────────────────────
def uc(x, y, text, w=32, h=8.5, fs=8.2, fc="#ffffff", ec="#1e293b"):
    lines = text.split("\n")
    computed_w = max(w, max(len(s) for s in lines) * 0.95 + 6.0)
    ax.add_patch(Ellipse((x, y), computed_w, h, facecolor=fc, edgecolor=ec,
                         linewidth=1.4, zorder=4))
    ax.text(x, y, text, ha="center", va="center", fontsize=fs,
            fontweight="bold", color="#0f172a", zorder=5)
    return (x, y, computed_w, h)

def connect(p_actor, u_target, side="left", color="#475569", lw=1.1):
    ax_x, ax_y = p_actor[0] + 5, p_actor[1] + 2
    ux, uy, uw, uh = u_target
    tx = ux - uw / 2 if side == "left" else ux + uw / 2
    ax.plot([ax_x, tx], [ax_y, uy], color=color, linewidth=lw, zorder=2)

def rel_dash(u_from, u_to, label, rad=0.0, fs=7.2, tpos=0.5):
    d.arrow(ax, (u_from[0], u_from[1]), (u_to[0], u_to[1]),
            text=label, fs=fs, dashed=True, color="#1e293b", lw=1.1,
            tpos=tpos, rad=rad)

# ── Package Containers ────────────────────────────────────────
def draw_pkg(x, y, w, h, label, color="#cbd5e1"):
    ax.add_patch(FancyBboxPatch((x, y - h), w, h,
                                boxstyle="round,pad=0.2,rounding_size=1.5",
                                facecolor="#ffffff", edgecolor=color,
                                linewidth=1.2, linestyle="--", zorder=2))
    ax.text(x + 3.0, y - 3.2, label, fontsize=9.0, fontweight="bold",
            color="#475569", zorder=3)

# ══════════════════════════════════════════════════════════════
# USE CASES BY PACKAGE
# ══════════════════════════════════════════════════════════════

# 1. Authentication & Profile
draw_pkg(52, 210, 80, 52, "Authentication & Profile")
uc_login   = uc(72, 196, "Sign Up / Log In")
uc_verify  = uc(114, 196, "Verify Email (OTP)", w=24, fs=7.5)
uc_wl      = uc(114, 182, "Verify Whitelist Gate\n(Teacher & Admin)", w=26, fs=7.2)
uc_profile = uc(72, 178, "Edit Profile", w=24)
uc_logout  = uc(72, 166, "Sign Out", w=20)

rel_dash(uc_verify, uc_login, "<<extend>>")
rel_dash(uc_wl, uc_login, "<<extend>>")

# 2. Campus Exploration (Common to All Roles)
draw_pkg(140, 210, 84, 52, "Campus Exploration (All Roles)")
uc_find_t = uc(182, 196, "Find Teacher\n(Live Classroom Location)", w=34, fs=7.8)
uc_rooms  = uc(182, 182, "View Room Availability\n(Live Vacancy & Grid)", w=34, fs=7.8)
uc_notif  = uc(182, 168, "View Notifications & Alerts", w=32, fs=7.8)

# 3. Student Features
draw_pkg(52, 152, 80, 48, "Student Features")
uc_routine = uc(92, 138, "View Weekly Routine", w=28)
uc_dash    = uc(92, 124, "View Student Dashboard\n(Live Countdown)", w=30)
uc_res     = uc(92, 110, "Browse Academic Resources", w=30)

# 4. Teacher Features
draw_pkg(140, 152, 84, 48, "Teacher Features")
uc_tdash   = uc(182, 138, "View Teacher Dashboard", w=30)
uc_manage  = uc(182, 120, "Manage Classes\n(Cancel, Notice, Undo)", w=32, fs=8.0)

# 5. Routine Hub (Admin)
draw_pkg(52, 98, 114, 82, "Admin — Routine Hub")
uc_man_rout = uc(108, 86, "Manage Routine (Manual CRUD)", w=36)
uc_gen_tt   = uc(108, 68, "Generate Timetable (CP-SAT Solver)", w=36)
uc_upload_w = uc(108, 50, "Upload Routine Workbook (Direct)", w=36)
uc_solve    = uc(108, 32, "Run CP-SAT Solver", w=28, fc="#f0fdf4")
uc_publish  = uc(108, 16, "Publish Routine (Atomic RPC)", w=32, fc="#f0fdf4")

rel_dash(uc_gen_tt, uc_solve, "<<include>>")
rel_dash(uc_gen_tt, uc_publish, "<<include>>", rad=0.2)
rel_dash(uc_upload_w, uc_publish, "<<include>>")

# 6. Academic Configuration & Governance (Admin)
draw_pkg(172, 98, 130, 82, "Admin — Configuration & Governance")
uc_conf_rf   = uc(236, 86, "Manage Rooms & Faculty Pools", w=36)
uc_eligib    = uc(236, 70, "Manage Course Eligibility Matrix", w=36)
uc_settings  = uc(236, 54, "Configure Scheduling Rules (Term & Limits)", w=36)
uc_broadcast = uc(236, 38, "Dispatch Campus Broadcast", w=34)
uc_staff_reg = uc(236, 22, "Admin Registration (Add Teacher / Invite)", w=36)

# 7. Automated Notification Sub-Use-Case
uc_push = uc(275, 140, "Send Push\nNotification (FCM)", w=28, h=10, fs=8.2, fc="#fff7ed", ec="#9a3412")

# ── Connections to Push Notification ──────────────────────────
rel_dash(uc_publish, uc_push, "<<include>>", rad=0.22)
rel_dash(uc_manage, uc_push, "<<include>>", rad=0.1)
rel_dash(uc_broadcast, uc_push, "<<include>>", rad=-0.15)

# ── Actor to Use Case Links ───────────────────────────────────
# Student connections
connect(ST_POS, uc_login)
connect(ST_POS, uc_profile)
connect(ST_POS, uc_logout)
connect(ST_POS, uc_find_t)
connect(ST_POS, uc_rooms)
connect(ST_POS, uc_notif)
connect(ST_POS, uc_routine)
connect(ST_POS, uc_dash)
connect(ST_POS, uc_res)

# Teacher connections
connect(TE_POS, uc_tdash)
connect(TE_POS, uc_manage)

# Admin connections
connect(AD_POS, uc_man_rout)
connect(AD_POS, uc_gen_tt)
connect(AD_POS, uc_upload_w)
connect(AD_POS, uc_conf_rf)
connect(AD_POS, uc_eligib)
connect(AD_POS, uc_settings)
connect(AD_POS, uc_broadcast)
connect(AD_POS, uc_staff_reg)

# ── External System Links ─────────────────────────────────────
# Auth link
ax.plot([uc_login[0] + uc_login[2]/2, AUTH_POS[0] - 18],
        [uc_login[1], AUTH_POS[1]], color="#1d4ed8", lw=1.4, linestyle=":")

# Solver Engine link
ax.plot([uc_solve[0] + uc_solve[2]/2, ENG_POS[0] - 18],
        [uc_solve[1], ENG_POS[1]], color="#15803d", lw=1.4, linestyle=":")

# Push FCM link
ax.plot([uc_push[0] + uc_push[2]/2, FCM_POS[0] - 18],
        [uc_push[1], FCM_POS[1]], color="#c2410c", lw=1.4, linestyle=":")

out = "docs/diagrams/use-case-diagram.png"
fig.savefig(out, dpi=140, facecolor="#ffffff", bbox_inches="tight", pad_inches=0.3)
print("wrote", out)
