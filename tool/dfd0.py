# ============================================================
# tool/dfd0.py  ->  docs/diagrams/dfd-level-0.png
# UniVerse Level-0 (context) Data Flow Diagram.
# One process (0 UniVerse), 5 external entities, 10 labelled flows.
# ============================================================
import diagram_helpers as d

fig, ax = d.canvas((0, 162), (0, 118), figsize=(16.2, 11.8), dpi=140)

ax.text(81, 114, "UniVerse — Level 0  Data Flow Diagram (Context)",
        ha="center", fontsize=15, fontweight="bold")

# ── Central process ───────────────────────────────────────────
P = d.process(ax, 81, 56, 14, "0", "UniVerse\nA Campus Companion", fs=10)

# ── External entities ─────────────────────────────────────────
student = d.box(ax, 16,  85, 26, 12, "Student",                 bold=True, fs=11)
teacher = d.box(ax, 16,  32, 26, 12, "Teacher",                 bold=True, fs=11)
admin   = d.box(ax, 146, 85, 26, 12, "Admin",                   bold=True, fs=11)
engine  = d.box(ax, 146, 32, 32, 13, "Timetable Engine\n(OR-Tools)", bold=True, fs=9.5)
fcm     = d.box(ax, 81,   9, 30, 11, "Firebase FCM",            bold=True, fs=11)

# ── F1 / F2 — Student ─────────────────────────────────────────
d.arrow(ax, (29, 88), (68, 65),
        "login · sign-up · profile edits\ndismiss alerts", fs=7.8,
        rad=0.05, tpos=0.42, off=(0, 2))
d.arrow(ax, (67, 60), (29, 82),
        "routine · dashboard\nresources · notifications", fs=7.8,
        rad=0.05, tpos=0.58, off=(0, -2))

# ── F3 / F4 — Teacher ─────────────────────────────────────────
d.arrow(ax, (29, 34), (68, 48),
        "login · cancel class\nnotice / room change", fs=7.8,
        rad=-0.05, tpos=0.36, off=(0, -3))
d.arrow(ax, (67, 53), (29, 38),
        "routine · class list\ncancellation alerts", fs=7.8,
        rad=-0.05, tpos=0.60, off=(0, 3))

# ── F5 / F6 — Admin ───────────────────────────────────────────
d.arrow(ax, (133, 88), (94, 65),
        "Excel file · routine edits\nconfig · broadcast · resources", fs=7.8,
        rad=-0.05, tpos=0.44, off=(0, 3))
d.arrow(ax, (94, 60), (133, 82),
        "reports · validation\nuser lists · dashboard counts", fs=7.8,
        rad=-0.05, tpos=0.58, off=(0, -3))

# ── F7 / F8 — Timetable Engine ────────────────────────────────
d.arrow(ax, (94, 52), (131, 38),
        "distribution .xlsx\n+ config JSON", fs=7.8,
        rad=0.06, tpos=0.56, off=(0, -3))
d.arrow(ax, (132, 32), (95, 51),
        "generated rows · stats\nvalidation · workbook", fs=7.8,
        rad=0.06, tpos=0.36, off=(0, 3))

# ── F9 / F10 — Firebase FCM ───────────────────────────────────
d.arrow(ax, (75, 40), (75, 15),
        "notification payload\n+ device tokens", fs=7.8,
        off=(-10, 0), tpos=0.5)
d.arrow(ax, (87, 15), (87, 40),
        "push notification\n→ phones", fs=7.8,
        off=(10, 0), tpos=0.5)

# ── Flow labels ───────────────────────────────────────────────
# small flow identifiers at arrow midpoints (subtle reference for the MD file)
for label, pos in [("F1", (44, 76)), ("F2", (45, 71)),
                   ("F3", (42, 43)), ("F4", (42, 48)),
                   ("F5", (115, 77)), ("F6", (116, 71)),
                   ("F7", (116, 44)), ("F8", (114, 40)),
                   ("F9", (60, 27)), ("F10", (98, 27))]:
    ax.text(*pos, label, ha="center", va="center", fontsize=6.5,
            color="#888", style="italic")

d.save(fig, "docs/diagrams/dfd-level-0.png")
