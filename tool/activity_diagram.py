# ============================================================
# tool/activity_diagram.py  ->  docs/diagrams/activity-diagram.png
# UniVerse activity diagram — three side-by-side swimlanes:
#   Student / User  |  Teacher / Faculty  |  Admin
# ============================================================
import diagram_helpers as d

# Wide landscape: x 0-360, y 80-232
fig, ax = d.canvas((0, 360), (80, 232), figsize=(36, 15.5), dpi=140)

INK = d.INK

# ── helpers ──────────────────────────────────────────────────
def bx(x, y, t, w=19, h=7.5, fs=6.6, dashed=False):
    d.box(ax, x, y, w, h, t, rounded=True, fs=fs, dashed=dashed)

def dm(x, y, t, w=16, h=10, fs=6.2):
    d.diamond(ax, x, y, t, w=w, h=h, fs=fs)

def aw(p1, p2, lbl=None, fs=6.2, off=(0, 0), rad=0.0):
    d.arrow(ax, p1, p2, text=lbl, fs=fs, color=INK, lw=1.1, off=off, rad=rad)

def ln(a, b):
    d.line(ax, a, b, color=INK, lw=1.1)

# Shared y levels
BUS_Y       = 190   # fork bus bar
HEAD_Y      = 186   # branch header box center
CHAIN_START = 179   # first item in chain (center)
CHAIN_STEP  = 13    # spacing between chain items
JOIN_Y      = 117   # join bus bar
LOGOUT_Y    = 105   # logout diamond center
END_Y       = 91    # end node center

def chain(cx, items, w=18, h=7.0, fs=6.1):
    """Draw chain boxes below a branch header. Returns bottom-centre of last box."""
    y = CHAIN_START
    for i, it in enumerate(items):
        bx(cx, y, it, w=w, h=h, fs=fs)
        prev_y = HEAD_Y if i == 0 else y + CHAIN_STEP
        # arrow from previous box bottom → this box top
        aw((cx, prev_y - 3.5), (cx, y + 3.5))
        y -= CHAIN_STEP
    return (cx, y + CHAIN_STEP)   # centre of last drawn box

# ─────────────────────────────────────────────────────────────
# TITLE
# ─────────────────────────────────────────────────────────────
ax.text(180, 229, "UniVerse — Activity Diagram  (Student · Teacher / Faculty · Admin)",
        ha="center", fontsize=15, fontweight="bold")

# Section dividers
for xv in [121, 242]:
    ax.plot([xv, xv], [82, 224], color="#BBBBBB", lw=0.8, ls="--")

# ═══════════════════════════════════════════════════════════════
# SECTION 1 — STUDENT / USER    (x: 0 – 120, logical centre 60)
# ═══════════════════════════════════════════════════════════════
ax.text(5, 224, "Student / User", ha="left", fontsize=11, fontweight="bold")

# --- login block ---
d.node(ax, 8, 216)
bx(30, 216, "Create Account\n/ Login", w=22)
aw((8, 216), (19, 216), "Start")
aw((41, 216), (52, 216))
dm(63, 216, "Verify\nCredentials")
bx(63, 227, "Show Error", w=18, h=7, dashed=True, fs=6.2)
aw((63, 221), (63, 223.5), "No")
aw((54, 227), (41, 220), rad=-0.25)           # error → login
aw((71, 216), (80, 216), "Yes")
bx(91, 216, "Home /\nDashboard", w=20)

# dashboard → select option
ln((91, 212.25), (91, 201))
aw((91, 201), (71, 201))
dm(62, 201, "Select\nOption", w=18, h=10)
aw((62, 196), (62, 191))

# fork bus
COLS_U = [8, 27, 46, 65, 84, 103]
HEADS_U = ["Dashboard", "Routine", "Resources", "Notifications",
           "Manage\nClasses", "Profile"]
ln((COLS_U[0], BUS_Y), (COLS_U[-1], BUS_Y))
for cx, h in zip(COLS_U, HEADS_U):
    aw((cx, BUS_Y), (cx, HEAD_Y + 3.75))
    bx(cx, HEAD_Y, h, w=18, h=8.5, fs=6.2)

# branch chains
lu0 = chain(COLS_U[0], ["Live / Next Class\nCountdown", "Today's Classes", "Recent Alerts"])
lu1 = chain(COLS_U[1], ["Load Routine", "View Weekly\nGrid", "Cancelled\nClasses"])
lu2 = chain(COLS_U[2], ["Load Resources", "Browse by\nSemester", "Open File /\nLink"])
lu3 = chain(COLS_U[3], ["Load Alerts", "Mark / Dismiss\nAlert"])
lu4 = chain(COLS_U[4], ["Select Class", "Cancel / Post\nNotice / Undo", "Alert Sent to\nStudents"])
lu5 = chain(COLS_U[5], ["Load Profile", "Edit Profile"])

for lf in [lu0, lu1, lu2, lu3, lu4, lu5]:
    ln((lf[0], lf[1] - 3.5), (lf[0], JOIN_Y))
ln((COLS_U[0], JOIN_Y), (COLS_U[-1], JOIN_Y))
aw((62, JOIN_Y), (62, LOGOUT_Y + 5))
dm(62, LOGOUT_Y, "Logout?", w=15, h=9, fs=6.2)
d.node(ax, 62, END_Y, end=True)
aw((62, LOGOUT_Y - 5), (62, END_Y + 3.5), "Yes")
ax.text(66, END_Y, "End", va="center", fontsize=8)
# "No" loop → right rail → back to Select Option
ln((70, LOGOUT_Y), (119, LOGOUT_Y))
ln((119, LOGOUT_Y), (119, 201))
aw((119, 201), (71, 201), "No")

# ═══════════════════════════════════════════════════════════════
# SECTION 2 — TEACHER / FACULTY  (x: 124 – 240, centre 182)
# ═══════════════════════════════════════════════════════════════
ax.text(126, 224, "Teacher / Faculty", ha="left", fontsize=11, fontweight="bold")

T_CX = 182   # main vertical spine

# --- login block ---
d.node(ax, 127, 216)
bx(148, 216, "Teacher Login", w=21)
aw((127, 216), (137.5, 216), "Start")
aw((158.5, 216), (167, 216))
dm(178, 216, "Verify\nCredentials")
bx(178, 227, "Show Error", w=18, h=7, dashed=True, fs=6.2)
aw((178, 221), (178, 223.5), "No")
aw((169, 227), (159, 220), rad=-0.25)         # error → login
aw((186, 216), (196, 216), "Yes")
bx(208, 216, "Teacher\nDashboard", w=21)

# dashboard → select option
ln((208, 212.25), (208, 201))
aw((208, 201), (191, 201))
dm(T_CX, 201, "Select\nOption", w=18, h=10)
aw((T_CX, 196), (T_CX, 191))

# fork bus
COLS_T = [128, 149, 172, 198, 222]
HEADS_T = ["Dashboard", "Routine", "Manage\nClasses", "Notifications", "Profile"]
ln((COLS_T[0], BUS_Y), (COLS_T[-1], BUS_Y))
for cx, h in zip(COLS_T, HEADS_T):
    aw((cx, BUS_Y), (cx, HEAD_Y + 3.75))
    bx(cx, HEAD_Y, h, w=19, h=8.5, fs=6.2)

# branch chains
lt0 = chain(COLS_T[0], ["Live / Next Class\nCountdown", "Today's Classes", "Recent Alerts"])
lt1 = chain(COLS_T[1], ["Load Routine", "View Weekly\nGrid", "Cancelled\nClasses"])
lt2 = chain(COLS_T[2], ["Select Day\n& Class", "Cancel / Post\nNotice / Undo",
                          "Confirm &\nSend Alert"])
lt3 = chain(COLS_T[3], ["Load Alerts", "Mark / Dismiss\nAlert"])
lt4 = chain(COLS_T[4], ["Load Profile", "Edit Profile"])

for lf in [lt0, lt1, lt2, lt3, lt4]:
    ln((lf[0], lf[1] - 3.5), (lf[0], JOIN_Y))
ln((COLS_T[0], JOIN_Y), (COLS_T[-1], JOIN_Y))
aw((T_CX, JOIN_Y), (T_CX, LOGOUT_Y + 5))
dm(T_CX, LOGOUT_Y, "Logout?", w=15, h=9, fs=6.2)
d.node(ax, T_CX, END_Y, end=True)
aw((T_CX, LOGOUT_Y - 5), (T_CX, END_Y + 3.5), "Yes")
ax.text(T_CX + 4, END_Y, "End", va="center", fontsize=8)
# "No" loop → right rail
ln((T_CX + 7.5, LOGOUT_Y), (240, LOGOUT_Y))
ln((240, LOGOUT_Y), (240, 201))
aw((240, 201), (191, 201), "No")

# ═══════════════════════════════════════════════════════════════
# SECTION 3 — ADMIN              (x: 245 – 358, centre 303)
# ═══════════════════════════════════════════════════════════════
ax.text(248, 224, "Admin", ha="left", fontsize=11, fontweight="bold")

A_CX = 302   # main vertical spine

# --- login block ---
d.node(ax, 248, 216)
bx(268, 216, "Admin Login", w=20)
aw((248, 216), (258, 216), "Start")
aw((278, 216), (287, 216))
dm(298, 216, "Verify\nCredentials")
bx(298, 227, "Show Error", w=18, h=7, dashed=True, fs=6.2)
aw((298, 221), (298, 223.5), "No")
aw((289, 227), (279, 220), rad=-0.25)         # error → login
aw((306, 216), (315, 216), "Yes")
bx(327, 216, "Admin\nDashboard", w=21)

# dashboard → select option
ln((327, 212.25), (327, 201))
aw((327, 201), (311, 201))
dm(A_CX, 201, "Select\nOption", w=18, h=10)
aw((A_CX, 196), (A_CX, 191))

# fork bus
COLS_A = [252, 272, 298, 322, 345]
HEADS_A = ["Manage\nRoutine", "Generate\nTimetable", "Broadcast", "Manage\nUsers",
           "Manage\nResources"]
ln((COLS_A[0], BUS_Y), (COLS_A[-1], BUS_Y))
for cx, h in zip(COLS_A, HEADS_A):
    aw((cx, BUS_Y), (cx, HEAD_Y + 3.75))
    bx(cx, HEAD_Y, h, w=19, h=8.5, fs=6.2)

# branch chains
la0 = chain(COLS_A[0], ["Add / Edit /\nDelete Routine"])
la1 = chain(COLS_A[1], ["Upload Excel", "Run Engine\n& Review", "Publish\nRoutine"])
la2 = chain(COLS_A[2], ["Compose &\nSend Broadcast"])
la3 = chain(COLS_A[3], ["View Users /\nChange Role", "Invite Admin"])
la4 = chain(COLS_A[4], ["Upload /\nDelete Resource"])

for lf in [la0, la1, la2, la3, la4]:
    ln((lf[0], lf[1] - 3.5), (lf[0], JOIN_Y))
ln((COLS_A[0], JOIN_Y), (COLS_A[-1], JOIN_Y))
aw((A_CX, JOIN_Y), (A_CX, LOGOUT_Y + 5))
dm(A_CX, LOGOUT_Y, "Logout?", w=15, h=9, fs=6.2)
d.node(ax, A_CX, END_Y, end=True)
aw((A_CX, LOGOUT_Y - 5), (A_CX, END_Y + 3.5), "Yes")
ax.text(A_CX + 4, END_Y, "End", va="center", fontsize=8)
# "No" loop → right rail
ln((A_CX + 7.5, LOGOUT_Y), (357, LOGOUT_Y))
ln((357, LOGOUT_Y), (357, 201))
aw((357, 201), (311, 201), "No")

d.save(fig, "docs/diagrams/activity-diagram.png")
