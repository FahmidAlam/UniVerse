# ============================================================
# tool/usecase_diagram.py  ->  docs/diagrams/use-case-diagram.png
# UniVerse use-case diagram — 22 UCs, 3 human actors, 3 system actors,
# <<include>> / <<extend>> arrows, "Send Push" as a shared sub-UC.
# ============================================================
from matplotlib.patches import Rectangle
import diagram_helpers as d

fig, ax = d.canvas((0, 244), (0, 168), figsize=(24.4, 16.8), dpi=140)

# ── System boundary ───────────────────────────────────────────
ax.add_patch(Rectangle((28, 5), 182, 155, fc="#FAFAFA", ec=d.INK, lw=2.0))
ax.text(119, 156, "UniVerse — A Campus Companion", ha="center",
        fontsize=15, fontweight="bold")

# ── Actors ────────────────────────────────────────────────────
# Human actors LEFT (outside boundary)
d.actor(ax, 13, 130, "Guest",   s=2.8)
d.actor(ax, 13, 95,  "Student", s=2.8)
d.actor(ax, 13, 54,  "Teacher", s=2.8)
# Human actor RIGHT (outside boundary)
d.actor(ax, 228, 100, "Admin",  s=2.8)

# System actors (right, outside boundary — plain boxes)
d.box(ax, 230, 145, 28, 10, "Supabase Auth /\nGoogle OAuth", bold=True, fs=8.2)
d.box(ax, 230, 58,  28, 10, "Timetable\nEngine (OR-Tools)", bold=True, fs=8.2)
d.box(ax, 230, 18,  28, 10, "Firebase FCM", bold=True, fs=9.5)

# ── Helpers ───────────────────────────────────────────────────
def uc(x, y, text, fs=8.3):
    lines = text.split("\n")
    w = max(24, max(len(s) for s in lines) * 0.94 + 6)
    d.ellipse(ax, x, y, w, 6.2, text, fs=fs, bold=True)
    return (x, y, w)

def a2uc(ax_xy, ucx, side=1):
    """Solid line: actor head → nearest ellipse edge."""
    ax_, ay_ = ax_xy[0], ax_xy[1] + 3   # top of stick figure (approx)
    ex = ucx[0] - side * ucx[2] / 2
    d.line(ax, (ax_, ay_), (ex, ucx[1]), color="#444", lw=1.0)

def dash(u_from, u_to, label, rad=0.0, tpos=0.5):
    d.arrow(ax, (u_from[0], u_from[1]), (u_to[0], u_to[1]),
            text=label, fs=7.4, dashed=True, color="#333", lw=1.0,
            tpos=tpos, rad=rad)

# ── Guest / Auth use cases ────────────────────────────────────
GUEST = (13, 130)
g1 = uc(60, 143, "View Onboarding")
g2 = uc(60, 134, "Create Account")
g3 = uc(60, 125, "Login")
g4 = uc(60, 116, "Reset Password")
for g in (g1, g2, g3, g4):
    a2uc(GUEST, g)

ve = uc(115, 134, "Verify Email (OTP)")
wl = uc(115, 119, "Verify Whitelist\n(admin path only)")
dash(g2, ve, "<<include>>")
dash(g3, ve, "<<extend>>")
dash(wl, g3, "<<extend>>")
# Login touches Supabase Auth
d.line(ax, (g3[0] + g3[2]/2, g3[1]), (216, 145), color="#888", lw=0.9)

# ── Shared (Student + Teacher) ────────────────────────────────
STUDENT = (13, 95)
TEACHER = (13, 54)
r1 = uc(58, 100, "View Dashboard\n(live / next class)")
r2 = uc(58, 90,  "View Weekly Routine")
r3 = uc(58, 80,  "Browse Resources")
r4 = uc(58, 71,  "View Notifications")
r5 = uc(58, 62,  "Manage Profile")
r6 = uc(58, 53,  "Sign Out")
shared = (r1, r2, r3, r4, r5, r6)
for r in shared:
    a2uc(STUDENT, r)
    a2uc(TEACHER, r)

# Routine + Resources sub-UCs
rc = uc(116, 95, "View Cancelled Classes")
ro = uc(116, 80, "Open File / Link")
dash(rc, r2, "<<extend>>")
dash(ro, r3, "<<extend>>")

# ── Teacher-only use cases ────────────────────────────────────
td = uc(58, 43, "Teacher Dashboard\n(countdown + class list)")
mc = uc(58, 33, "Manage Classes")
a2uc(TEACHER, td)
a2uc(TEACHER, mc)

tc = uc(112, 43, "Cancel Class")
tn = uc(112, 34, "Post Notice /\nRoom Change",  fs=8.0)
tu = uc(112, 25, "Undo Cancellation")
dash(tc, mc, "<<extend>>")
dash(tn, mc, "<<extend>>")
dash(tu, mc, "<<extend>>")

# ── Shared sub-UC: Send Push Notification ─────────────────────
push = uc(155, 14, "Send Push\nNotification", fs=8.0)
# Teachers trigger push via Cancel / Notice
dash(tc, push, "<<include>>", rad=0.25)
dash(tn, push, "<<include>>", rad=0.15)
# Connect Send Push → Firebase FCM
d.line(ax, (push[0] + push[2]/2, push[1]), (216, 18), color="#888", lw=0.9)

# ── Admin use cases ───────────────────────────────────────────
ADMIN = (228, 100)
a1 = uc(150, 133, "Manage Routine")
a2 = uc(150, 123, "Generate Timetable")
a3 = uc(150, 113, "Manage Config\n(rooms / faculty / settings)", fs=7.8)
a4 = uc(150, 103, "Broadcast Notification")
a5 = uc(150, 93,  "Manage Users")
a6 = uc(150, 83,  "Manage Resources")
a7 = uc(150, 73,  "View Admin Dashboard")
for a in (a1, a2, a3, a4, a5, a6, a7):
    a2uc(ADMIN, a, side=-1)

# Admin sub-UCs (extend / include)
ax1 = uc(195, 140, "Add / Edit /\nDelete Routine", fs=7.8)
ax2 = uc(195, 128, "Publish to Routines")
ax4 = uc(195, 108, "View Broadcast\nHistory",        fs=7.8)
ax5 = uc(195, 93,  "Invite Admin")
ax6 = uc(195, 83,  "View Resource\nLibrary",          fs=7.8)
dash(ax1, a1, "<<extend>>")
dash(ax2, a2, "<<extend>>")
dash(ax4, a4, "<<extend>>")
dash(ax5, a5, "<<extend>>")
dash(ax6, a6, "<<extend>>")

# Generate Timetable → Engine (external system)
d.line(ax, (a2[0] + a2[2]/2, a2[1]), (216, 58), color="#888", lw=0.9)

# Broadcast, Routine Publish, Resource Upload → Send Push (include)
dash(a4,  push, "<<include>>", rad=-0.30, tpos=0.45)
dash(ax2, push, "<<include>>", rad=-0.20, tpos=0.42)
dash(a6,  push, "<<include>>", rad=-0.10, tpos=0.44)

# ── Caption ───────────────────────────────────────────────────
ax.text(119, 1, "UniVerse — Use Case Diagram", ha="center", fontsize=14,
        fontweight="bold")

d.save(fig, "docs/diagrams/use-case-diagram.png")
