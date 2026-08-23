# ============================================================
# tool/er_diagram.py
# Renders the UniVerse ER diagram (Chen notation) to a PNG.
#   - entity   = rectangle
#   - attribute= ellipse (primary keys underlined)
#   - relation = diamond, with 1 / N cardinality labels
# Only the 12 tables the app actually uses are drawn
# (documents / assignments / submissions are future scope -> excluded).
# Run:  python tool/er_diagram.py
# ============================================================
import math
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle, Ellipse, Polygon, FancyBboxPatch

# ---- colors / style ----
ENT_FC   = "#ffffff"; ENT_EC = "#1a1a1a"
ATT_FC   = "#ffffff"; ATT_EC = "#333333"
REL_FC   = "#ffffff"; REL_EC = "#1a1a1a"
LINE_C   = "#555555"
TXT_C    = "#111111"

fig, ax = plt.subplots(figsize=(34, 20.5), dpi=130)
ax.set_xlim(-3, 185)
ax.set_ylim(-22, 116)
ax.set_aspect("equal")
ax.axis("off")

# ---------------------------------------------------------------
def entity(name, x, y):
    w = max(14, 0.85 * len(name) + 7)
    h = 6.2
    ax.add_patch(Rectangle((x - w / 2, y - h / 2), w, h,
                           facecolor=ENT_FC, edgecolor=ENT_EC,
                           linewidth=2.0, zorder=4))
    ax.text(x, y, name, ha="center", va="center", fontsize=11.5,
            fontweight="bold", color=TXT_C, zorder=6)
    return (x, y)

def attr(text, x, y, ex, ey, pk=False):
    w = max(8.0, 0.62 * len(text) + 3.2)
    h = 3.7
    # connector first (under the shapes)
    ax.plot([x, ex], [y, ey], color=LINE_C, linewidth=0.9, zorder=1)
    ax.add_patch(Ellipse((x, y), w, h, facecolor=ATT_FC, edgecolor=ATT_EC,
                         linewidth=1.0, zorder=3))
    if pk:
        label = r"$\underline{\mathdefault{%s}}$" % text.replace("_", r"\_")
    else:
        label = text
    ax.text(x, y, label, ha="center", va="center", fontsize=8.2,
            color=TXT_C, zorder=6)

def fan(ex, ey, attrs, base_deg, span_deg, radius, stagger=6.0):
    """Place attribute ellipses on an arc 'outward' from an entity."""
    n = len(attrs)
    if n == 1:
        angles = [base_deg]
    else:
        angles = [base_deg - span_deg / 2 + span_deg * i / (n - 1) for i in range(n)]
    for i, ((text, pk), ang) in enumerate(zip(attrs, angles)):
        r = radius + (stagger if i % 2 else 0.0)
        rad = math.radians(ang)
        ax_ = ex + r * math.cos(rad)
        ay_ = ey + r * math.sin(rad)
        attr(text, ax_, ay_, ex, ey, pk=pk)

def relationship(name, p1, p2, dx, dy, c1, c2):
    """Diamond at (dx,dy) linking entity p1 (card c1) and p2 (card c2)."""
    hw = max(8.5, 0.52 * len(name) + 3.0)
    hh = 5.2
    # connector lines entity-center -> diamond-center (under shapes)
    ax.plot([p1[0], dx], [p1[1], dy], color=LINE_C, linewidth=1.1, zorder=2)
    ax.plot([p2[0], dx], [p2[1], dy], color=LINE_C, linewidth=1.1, zorder=2)
    pts = [(dx, dy + hh), (dx + hw, dy), (dx, dy - hh), (dx - hw, dy)]
    ax.add_patch(Polygon(pts, closed=True, facecolor=REL_FC, edgecolor=REL_EC,
                         linewidth=1.6, zorder=3))
    ax.text(dx, dy, name, ha="center", va="center", fontsize=8.4,
            style="italic", color=TXT_C, zorder=6)
    # cardinality labels near each entity end
    def card(p, txt):
        t = 0.30
        cx = dx + t * (p[0] - dx)
        cy = dy + t * (p[1] - dy)
        ax.text(cx, cy, txt, ha="center", va="center", fontsize=11,
                fontweight="bold", color="#b00000", zorder=7)
    card(p1, c1)
    card(p2, c2)

# ===============================================================
# ENTITIES
# ===============================================================
profiles      = entity("profiles",            86, 58)
routines      = entity("routines",            22, 66)
whitelists    = entity("whitelists",          24, 92)
cancellations = entity("cancellations",       26, 30)
resources     = entity("resources",           54, 14)
device_tokens = entity("device_tokens",       84, 12)
timetable_runs= entity("timetable_runs",     116, 42)
notifications = entity("notifications",       140, 12)
notif_reads   = entity("notification_reads", 164, 60)
tt_settings   = entity("timetable_settings", 118, 98)
tt_faculty    = entity("timetable_faculty",  146, 100)
tt_rooms      = entity("timetable_rooms",    172, 98)

# ===============================================================
# ATTRIBUTES  (text, is_primary_key)
# ===============================================================
fan(*profiles, [
    ("id", True), ("email", False), ("role", False), ("name", False),
    ("batch", False), ("section", False), ("semester", False),
    ("student_id", False), ("teacher_code", False), ("designation", False),
    ("department", False),
], base_deg=90, span_deg=130, radius=28, stagger=8)

fan(*routines, [
    ("id", True), ("day", False), ("time_start", False), ("time_end", False),
    ("subject", False), ("subject_code", False), ("room", False),
    ("batch", False), ("section", False), ("semester", False),
    ("teacher_code", False), ("teacher_id", False),
], base_deg=176, span_deg=170, radius=24, stagger=7)

fan(*whitelists, [
    ("email", True), ("role", False), ("name", False), ("teacher_code", False),
    ("batch", False), ("section", False), ("semester", False),
], base_deg=128, span_deg=128, radius=20, stagger=6)

fan(*cancellations, [
    ("id", True), ("routine_id", False), ("cancelled_by", False),
    ("class_date", False), ("reason", False), ("subject", False),
], base_deg=212, span_deg=128, radius=20, stagger=7)

fan(*resources, [
    ("id", True), ("title", False), ("category", False), ("semester", False),
    ("subject_code", False), ("drive_link", False), ("file_url", False),
    ("uploaded_by", False), ("created_at", False),
], base_deg=232, span_deg=132, radius=20, stagger=7)

fan(*device_tokens, [
    ("token", True), ("user_id", False), ("platform", False), ("updated_at", False),
], base_deg=294, span_deg=120, radius=18, stagger=6)

fan(*timetable_runs, [
    ("id", True), ("semester_label", False), ("file_path", False),
    ("stats", False), ("validation", False), ("status", False),
    ("row_count", False), ("created_by", False),
], base_deg=255, span_deg=110, radius=20, stagger=8)

fan(*notifications, [
    ("id", True), ("title", False), ("body", False), ("type", False),
    ("sent_by", False), ("target_role", False), ("target_batch", False),
    ("target_section", False), ("created_at", False),
], base_deg=-42, span_deg=150, radius=21, stagger=8)

fan(*notif_reads, [
    ("user_id", True), ("notification_id", True), ("read_at", False),
], base_deg=0, span_deg=110, radius=18, stagger=6)

fan(*tt_settings, [
    ("id", True), ("semester_label", False), ("periods", False),
    ("weights", False), ("friday_no_p4", False), ("service_scope", False),
], base_deg=90, span_deg=150, radius=15, stagger=6)

fan(*tt_faculty, [
    ("id", True), ("acronym", False), ("full_name", False), ("dept", False),
    ("designation", False), ("off_days", False), ("is_active", False),
], base_deg=90, span_deg=150, radius=15, stagger=6)

fan(*tt_rooms, [
    ("id", True), ("name", False), ("building", False), ("is_lab", False),
    ("is_gallery", False), ("capacity", False), ("is_active", False),
], base_deg=90, span_deg=150, radius=15, stagger=6)

# ===============================================================
# RELATIONSHIPS  (diamonds + cardinalities)
# ===============================================================
relationship("teaches",        profiles, routines,       44, 63, "1", "N")
relationship("cancels",        profiles, cancellations,  50, 41, "1", "N")
relationship("cancelled_in",   routines, cancellations,  24, 48, "1", "N")
relationship("authorises",     whitelists, profiles,     40, 84, "1", "1")
relationship("uploads",        profiles, resources,      70, 36, "1", "N")
relationship("registers",      profiles, device_tokens,  86, 34, "1", "N")
relationship("generates",      profiles, timetable_runs,101, 50, "1", "N")
relationship("sends",          profiles, notifications, 112, 35, "1", "N")
relationship("reads",          profiles, notif_reads,   126, 59, "1", "N")
relationship("acknowledged_by",notifications, notif_reads,155, 44, "1", "N")

# ===============================================================
# config-cluster note (the 3 standalone tables) + title + legend
# ===============================================================
ax.add_patch(FancyBboxPatch((101, 86), 88, 26,
             boxstyle="round,pad=0.6,rounding_size=2",
             facecolor="none", edgecolor="#9aa0a6", linewidth=1.2,
             linestyle=(0, (6, 4)), zorder=0))
ax.text(101.5, 84.0,
        "Timetable-generator configuration — read by the engine at "
        "generation time; no foreign-key links (standalone).",
        ha="left", va="top", fontsize=9.5, style="italic", color="#5f6368")

ax.text(2, 113.5, "UniVerse — Entity-Relationship Diagram",
        ha="left", va="top", fontsize=20, fontweight="bold", color="#0f0f10")
ax.text(2, 109.0,
        "Chen notation · 12 implemented tables "
        "(documents / assignments / submissions are future scope and excluded)",
        ha="left", va="top", fontsize=11, color="#444")

# legend (in the empty bottom margin, below all content)
lx, ly = 6, -15
ax.add_patch(Rectangle((lx, ly - 1.8), 7, 3.6, facecolor="white",
             edgecolor=ENT_EC, linewidth=1.8, zorder=8))
ax.text(lx + 9, ly, "Entity", fontsize=11.5, va="center", zorder=8)
ax.add_patch(Ellipse((lx + 33, ly), 8, 3.8, facecolor="white",
             edgecolor=ATT_EC, linewidth=1.0, zorder=8))
ax.text(lx + 39, ly, "Attribute  (underlined = primary key)",
        fontsize=11.5, va="center", zorder=8)
dpx, dpy = lx + 92, ly
ax.add_patch(Polygon([(dpx, dpy + 3.2), (dpx + 6.5, dpy), (dpx, dpy - 3.2),
             (dpx - 6.5, dpy)], closed=True, facecolor="white",
             edgecolor=REL_EC, linewidth=1.6, zorder=8))
ax.text(dpx + 9, dpy, "Relationship", fontsize=11.5, va="center", zorder=8)
ax.text(dpx + 35, dpy, "1 / N  =  cardinality", fontsize=11.5, va="center",
        color="#b00000", fontweight="bold", zorder=8)

plt.subplots_adjust(left=0.01, right=0.99, top=0.99, bottom=0.01)
out = "docs/diagrams/er-diagram.png"
plt.savefig(out, dpi=130, facecolor="white", bbox_inches="tight", pad_inches=0.2)
print("wrote", out)
