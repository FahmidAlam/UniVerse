# ============================================================
# tool/dfd1.py  ->  docs/diagrams/dfd-level-1.png
# UniVerse Level-1 DFD:
#   8 processes (1.1-1.8), 10 data stores (D1-D10),
#   5 external entities (Student/Teacher, Admin, Engine, Firebase).
# ============================================================
import diagram_helpers as d

fig, ax = d.canvas((0, 224), (0, 180), figsize=(22.4, 18.0), dpi=140)

ax.text(112, 176, "UniVerse — Level 1  Data Flow Diagram",
        ha="center", fontsize=16, fontweight="bold")

# ══════════════════════════════════════════════════════════════
# EXTERNAL ENTITIES
# ══════════════════════════════════════════════════════════════
USER  = d.box(ax, 112, 90,  38, 15, "Student / Teacher\n(User)", bold=True, fs=11)
ADMIN = d.box(ax, 20,  24,  26, 12, "Admin",                     bold=True, fs=11)
FCM   = d.box(ax, 204, 24,  28, 12, "Firebase\n(FCM)",           bold=True, fs=10)
ENG   = d.box(ax, 176, 26,  30, 12, "Timetable\nEngine",         bold=True, fs=10)

# ══════════════════════════════════════════════════════════════
# PROCESSES  (8 circles)
# ══════════════════════════════════════════════════════════════
P11 = d.process(ax,  68, 144,  9, "1.1", "Auth")
P14 = d.process(ax, 156, 144,  9, "1.4", "Profile")
P12 = d.process(ax,  34, 112,  9, "1.2", "Routine\nView")
P13 = d.process(ax,  34,  60,  9, "1.3", "Resource\nMgmt")
P15 = d.process(ax, 188, 112,  9, "1.5", "Class\nMgmt")
P16 = d.process(ax, 188,  60,  9, "1.6", "Notify &\nPush")
P17 = d.process(ax, 130,  26,  9, "1.7", "Timetable\nGen")
P18 = d.process(ax,  72,  26,  9, "1.8", "Admin\nPanel")

# ══════════════════════════════════════════════════════════════
# DATA STORES  (D1-D10, Gane-Sarson open rectangles)
# ══════════════════════════════════════════════════════════════
D1  = d.datastore(ax,  32, 166, 26,  8, "D1",  "Whitelists")
D2  = d.datastore(ax, 112, 170, 28,  8, "D2",  "Profiles")            # shared, top-centre
D3  = d.datastore(ax,  12, 126, 26,  8, "D3",  "Routines")
D4  = d.datastore(ax,  12, 100, 28,  8, "D4",  "Cancellations")
D5  = d.datastore(ax,  12,  44, 26,  8, "D5",  "Resources")
D6  = d.datastore(ax, 212, 100, 28,  8, "D6",  "Notifications")       # THE HUB
D7  = d.datastore(ax, 212,  80, 30,  8, "D7",  "Notif. Reads")
D8  = d.datastore(ax, 212,  44, 28,  8, "D8",  "Device Tokens")
D9  = d.datastore(ax, 168,  10, 32,  8, "D9",  "Timetable Config")
D10 = d.datastore(ax, 102,   8, 30,  8, "D10", "Timetable Runs")

# ══════════════════════════════════════════════════════════════
# HELPERS
# ══════════════════════════════════════════════════════════════
def flow(p1, p2, txt, fs=7.2, rad=0.0, tpos=0.5, off=(0,0), double=False):
    d.arrow(ax, p1, p2, text=txt, fs=fs, rad=rad, tpos=tpos, off=off,
            double=double, color="#555", lw=1.05)

def flow2(p1, p2, txt, **kw):
    """Double-headed arrow (read+write)."""
    flow(p1, p2, txt, double=True, **kw)

# ══════════════════════════════════════════════════════════════
# USER ↔ PROCESSES  (double-headed short connectors)
# ══════════════════════════════════════════════════════════════
flow2(USER, P11, "login / session",    tpos=0.55, off=(2, -2))
flow2(USER, P12, "view routine",       tpos=0.55)
flow2(USER, P13, "browse resources",   tpos=0.55)
flow2(USER, P14, "profile update",     tpos=0.55, off=(-2, -2))
flow2(USER, P15, "cancel / notice",    tpos=0.55)
flow2(USER, P16, "alerts / dismiss",   tpos=0.55)

# ══════════════════════════════════════════════════════════════
# PROCESS 1.1 — Authentication
# ══════════════════════════════════════════════════════════════
flow2(P11, D1, "verify admin\nrole",    tpos=0.52, off=(2, 0))
flow2(P11, D2, "create / read\nprofile", tpos=0.55, off=(-2, 0))
flow( P11, D8, "save device\ntoken (W)", tpos=0.45, off=(-2, 0))

# ══════════════════════════════════════════════════════════════
# PROCESS 1.2 — Routine Viewing
# ══════════════════════════════════════════════════════════════
flow2(P12, D3, "read rows (R)",         tpos=0.5)
flow2(P12, D4, "read cancellations (R)", tpos=0.5)

# ══════════════════════════════════════════════════════════════
# PROCESS 1.3 — Resource Management
# ══════════════════════════════════════════════════════════════
flow2(P13, D5, "read / write (R/W)",    tpos=0.5)
flow( P13, D6, "upload alert (W)",      tpos=0.45, off=(0, 3), rad=-0.1)

# ══════════════════════════════════════════════════════════════
# PROCESS 1.4 — Profile Management
# ══════════════════════════════════════════════════════════════
flow2(P14, D2, "read / update (R/W)",   tpos=0.52, off=(2, 0))

# ══════════════════════════════════════════════════════════════
# PROCESS 1.5 — Class Management  (teacher cancel / notice)
# ══════════════════════════════════════════════════════════════
flow( P15, D3, "read slot (R)",         tpos=0.45, off=(4, 2), rad=0.2)
flow( P15, D4, "write cancel (W)",      tpos=0.55, off=(2, 0))
flow( P15, D6, "class alert (W)",       tpos=0.45, off=(0, 2))

# ══════════════════════════════════════════════════════════════
# PROCESS 1.6 — Notification & Push Dispatch  (THE HUB reader)
# ══════════════════════════════════════════════════════════════
flow( P16, D6, "read notifs (R)",       tpos=0.50, off=(-3, 0))
flow2(P16, D7, "dismiss marks (R/W)",   tpos=0.5)
flow( P16, D8, "read tokens (R)",       tpos=0.50, off=(-3, 0))
flow( P16, D2, "audience lookup (R)",   tpos=0.45, off=(3, 2), rad=-0.25)

# ══════════════════════════════════════════════════════════════
# PROCESS 1.7 — Timetable Generation & Publish
# ══════════════════════════════════════════════════════════════
flow( P17, D9,  "read config (R)",      tpos=0.5)
flow( P17, D3,  "publish rows (W)",     tpos=0.48, off=(0, 3), rad=0.15)
flow( P17, D10, "record run (W)",       tpos=0.5)
flow( P17, D6,  "publish alert (W)",    tpos=0.44, off=(2, 3), rad=-0.2)

# ══════════════════════════════════════════════════════════════
# PROCESS 1.8 — Admin Panel
# ══════════════════════════════════════════════════════════════
flow( P18, D6, "broadcast (W)",         tpos=0.48, off=(-2, 2), rad=0.1)
flow2(P18, D2, "manage users (R/W)",    tpos=0.55, off=(0, 3), rad=0.1)
flow2(P18, D1, "whitelist (R/W)",       tpos=0.5,  off=(2, 0))

# ══════════════════════════════════════════════════════════════
# EXTERNAL ENTITY CONNECTIONS
# ══════════════════════════════════════════════════════════════
# Admin → 1.8 (routine, broadcast, users, resources)
flow2((ADMIN[0], ADMIN[1]+4), (P18[0]-7, P18[1]),
      "routine · broadcast\nusers · resources", tpos=0.50, off=(0, 3))
# Admin → 1.7 (upload Excel)
flow( (ADMIN[0]+10, ADMIN[1]-3), (P17[0]-8, P17[1]-4),
      "upload Excel", tpos=0.28, off=(0, -4), rad=-0.18)
# 1.7 ↔ Engine
flow2((P17[0]+8, P17[1]+2), (ENG[0]-8, ENG[1]-2),
      "file+config /\nrows+stats", tpos=0.5, off=(0, 3))
# 1.6 ↔ Firebase
flow2((P16[0]+8, P16[1]-2), (FCM[0]-6, FCM[1]+4),
      "tokens /\npush", tpos=0.5, off=(3, 0))

# ══════════════════════════════════════════════════════════════
# ANNOTATION — D6 as notification hub
# ══════════════════════════════════════════════════════════════
ax.text(212, 90, "← HUB\n4 writers\n1 reader", ha="left", va="center",
        fontsize=6.2, color="#AA4400", style="italic")

d.save(fig, "docs/diagrams/dfd-level-1.png")
