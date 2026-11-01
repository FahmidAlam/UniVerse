# ============================================================
# tool/er_diagram.py
# Renders a modern, highly legible Crow's Foot / Relational Schema
# ER Diagram for UniVerse (14 implemented production tables).
# Replaces messy Chen bubble-fans with crisp, clear Entity Tables.
# Run: python tool/er_diagram.py
# ============================================================
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, Rectangle, PathPatch
import matplotlib.path as mpath

fig, ax = plt.subplots(figsize=(38, 26), dpi=140)
ax.set_xlim(0, 380)
ax.set_ylim(0, 260)
ax.set_aspect("equal")
ax.axis("off")

# ── Color Palette ─────────────────────────────────────────────
BG_HEADER_USER    = "#1e3a8a"  # Dark Blue
BG_HEADER_ROUTINE = "#065f46"  # Dark Green
BG_HEADER_NOTIF   = "#7c2d12"  # Deep Amber/Rust
BG_HEADER_CONFIG  = "#374151"  # Slate Gray
BG_ROW_EVEN       = "#f8fafc"
BG_ROW_ODD        = "#ffffff"
BORDER_COLOR      = "#1e293b"
LINE_COLOR        = "#334155"
PK_COLOR          = "#b91c1c"  # Crimson
FK_COLOR          = "#0369a1"  # Cerulean

# ── Title Block ───────────────────────────────────────────────
ax.text(190, 252, "UniVerse — Relational Entity-Relationship Diagram (ERD)",
        ha="center", va="center", fontsize=24, fontweight="bold", color="#0f172a")
ax.text(190, 246, "14 Implemented Production Tables · Reconciled with PostgreSQL Migrations 001–016",
        ha="center", va="center", fontsize=13, color="#475569")

# ── Entity Box Helper ─────────────────────────────────────────
def draw_table(ax, x, y, w, title, columns, header_bg=BG_HEADER_USER):
    """
    Draws an Entity Table Box with a header and column rows.
    (x, y) is top-left corner.
    columns is list of tuples: (col_name, data_type, key_type)
    key_type: 'PK', 'FK', 'PK,FK', or ''
    Returns (x, y, w, total_h) and anchor points dict.
    """
    row_h = 3.6
    header_h = 5.2
    total_h = header_h + len(columns) * row_h
    
    # Outer box border
    outer = FancyBboxPatch((x, y - total_h), w, total_h,
                           boxstyle="round,pad=0.0,rounding_size=1.2",
                           facecolor="#ffffff", edgecolor=BORDER_COLOR,
                           linewidth=1.8, zorder=3)
    ax.add_patch(outer)
    
    # Header box
    hdr = FancyBboxPatch((x, y - header_h), w, header_h,
                          boxstyle="round,pad=0.0,rounding_size=1.2",
                          facecolor=header_bg, edgecolor=BORDER_COLOR,
                          linewidth=1.8, zorder=4)
    ax.add_patch(hdr)
    # Square bottom of header
    ax.add_patch(Rectangle((x, y - header_h), w, 2.0, facecolor=header_bg,
                           edgecolor="none", zorder=5))
    ax.plot([x, x + w], [y - header_h, y - header_h], color=BORDER_COLOR,
            linewidth=1.5, zorder=6)
    
    # Header text
    ax.text(x + w / 2, y - header_h / 2, title, ha="center", va="center",
            fontsize=12, fontweight="bold", color="#ffffff", zorder=7)
    
    # Rows
    curr_y = y - header_h
    for i, (col, dtype, ktype) in enumerate(columns):
        bg = BG_ROW_EVEN if i % 2 == 0 else BG_ROW_ODD
        ax.add_patch(Rectangle((x + 0.2, curr_y - row_h), w - 0.4, row_h,
                               facecolor=bg, edgecolor="none", zorder=4))
        
        # Key badge
        if ktype:
            kc = PK_COLOR if "PK" in ktype else FK_COLOR
            ax.text(x + 1.8, curr_y - row_h / 2, ktype, ha="left", va="center",
                    fontsize=8.5, fontweight="bold", color=kc, zorder=7)
        
        # Column name
        fw = "bold" if ktype else "normal"
        ax.text(x + (8.5 if any(c[2] for c in columns) else 2.5), curr_y - row_h / 2,
                col, ha="left", va="center", fontsize=9.2, fontweight=fw,
                color="#0f172a", zorder=7)
        
        # Data type
        ax.text(x + w - 1.8, curr_y - row_h / 2, dtype, ha="right", va="center",
                fontsize=8.5, style="italic", color="#64748b", zorder=7)
        
        curr_y -= row_h
        if i < len(columns) - 1:
            ax.plot([x, x + w], [curr_y, curr_y], color="#e2e8f0",
                    linewidth=0.8, zorder=5)

    anchors = {
        "top": (x + w / 2, y),
        "bottom": (x + w / 2, y - total_h),
        "left": (x, y - total_h / 2),
        "right": (x + w, y - total_h / 2),
        "tl": (x, y),
        "tr": (x + w, y),
        "bl": (x, y - total_h),
        "br": (x + w, y - total_h),
        "bounds": (x, y, w, total_h)
    }
    return anchors

# ── Draw Connection Line ──────────────────────────────────────
def link(ax, p1, p2, label="", c1="1", c2="N", route="direct", rad=0.0):
    """Draws relationship path between two anchor points with cardinalities."""
    x1, y1 = p1
    x2, y2 = p2
    
    if route == "hv":
        path_data = [
            (mpath.Path.MOVETO, (x1, y1)),
            (mpath.Path.LINETO, (x2, y1)),
            (mpath.Path.LINETO, (x2, y2))
        ]
        mid = (x2, (y1 + y2) / 2)
    elif route == "vh":
        path_data = [
            (mpath.Path.MOVETO, (x1, y1)),
            (mpath.Path.LINETO, (x1, y2)),
            (mpath.Path.LINETO, (x2, y2))
        ]
        mid = ((x1 + x2) / 2, y2)
    elif route == "hvh":
        mx = (x1 + x2) / 2
        path_data = [
            (mpath.Path.MOVETO, (x1, y1)),
            (mpath.Path.LINETO, (mx, y1)),
            (mpath.Path.LINETO, (mx, y2)),
            (mpath.Path.LINETO, (x2, y2))
        ]
        mid = (mx, (y1 + y2) / 2)
    else:
        path_data = [
            (mpath.Path.MOVETO, (x1, y1)),
            (mpath.Path.LINETO, (x2, y2))
        ]
        mid = ((x1 + x2) / 2, (y1 + y2) / 2)
        
    codes, verts = zip(*path_data)
    path = mpath.Path(verts, codes)
    patch = PathPatch(path, facecolor="none", edgecolor=LINE_COLOR,
                      linewidth=1.6, zorder=2)
    ax.add_patch(patch)
    
    # Cardinality badges
    ax.text(x1 + (2.5 if x2 >= x1 else -2.5), y1 + (1.8 if y2 >= y1 else -1.8),
            c1, fontsize=11, fontweight="bold", color="#b91c1c",
            ha="center", va="center", zorder=8,
            bbox=dict(boxstyle="circle,pad=0.2", fc="#ffffff", ec="#b91c1c", lw=0.9))
    ax.text(x2 + (2.5 if x1 >= x2 else -2.5), y2 + (1.8 if y1 >= y2 else -1.8),
            c2, fontsize=11, fontweight="bold", color="#0369a1",
            ha="center", va="center", zorder=8,
            bbox=dict(boxstyle="circle,pad=0.2", fc="#ffffff", ec="#0369a1", lw=0.9))
    
    if label:
        ax.text(mid[0], mid[1] + 1.2, label, fontsize=8.5, style="italic",
                fontweight="bold", color="#1e293b", ha="center", va="center",
                zorder=9, bbox=dict(boxstyle="round,pad=0.2", fc="#ffffff", ec="#cbd5e1", lw=0.8))

# ══════════════════════════════════════════════════════════════
# ZONE 1: CORE USERS & IDENTITY (TOP LEFT)
# ══════════════════════════════════════════════════════════════
t_profiles = draw_table(ax, 16, 235, 46, "profiles", [
    ("id", "uuid", "PK"),
    ("email", "text", ""),
    ("role", "text", ""),
    ("name", "text", ""),
    ("avatar_url", "text", ""),
    ("batch", "text", ""),
    ("section", "text", ""),
    ("semester", "int", ""),
    ("student_id", "text", ""),
    ("teacher_code", "text", ""),
    ("designation", "text", ""),
    ("department", "text", ""),
    ("created_at", "timestamptz", ""),
], header_bg=BG_HEADER_USER)

t_whitelists = draw_table(ax, 16, 172, 46, "whitelists", [
    ("email", "text", "PK"),
    ("role", "text", ""),
    ("name", "text", ""),
    ("teacher_code", "text", ""),
    ("department", "text", ""),
    ("designation", "text", ""),
    ("batch", "text", ""),
    ("section", "text", ""),
    ("semester", "int", ""),
], header_bg=BG_HEADER_USER)

t_device_tokens = draw_table(ax, 16, 124, 46, "device_tokens", [
    ("token", "text", "PK"),
    ("user_id", "uuid", "FK"),
    ("platform", "text", ""),
    ("updated_at", "timestamptz", ""),
], header_bg=BG_HEADER_USER)

# ══════════════════════════════════════════════════════════════
# ZONE 2: ROUTINE VERSIONING & CLASSES (TOP CENTER & RIGHT)
# ══════════════════════════════════════════════════════════════
t_versions = draw_table(ax, 100, 235, 52, "routine_versions", [
    ("id", "uuid", "PK"),
    ("semester_label", "text", ""),
    ("source", "text", ""),
    ("is_active", "boolean", ""),
    ("row_count", "int", ""),
    ("stats", "jsonb", ""),
    ("validation", "jsonb", ""),
    ("published_by", "uuid", "FK"),
    ("published_at", "timestamptz", ""),
    ("created_at", "timestamptz", ""),
], header_bg=BG_HEADER_ROUTINE)

t_routines = draw_table(ax, 184, 235, 54, "routines", [
    ("id", "uuid", "PK"),
    ("routine_version_id", "uuid", "FK"),
    ("day", "text", ""),
    ("time_start", "time", ""),
    ("time_end", "time", ""),
    ("subject", "text", ""),
    ("subject_code", "text", ""),
    ("room", "text", ""),
    ("batch", "text", ""),
    ("section", "text", ""),
    ("semester", "int", ""),
    ("teacher_name", "text", ""),
    ("teacher_code", "text", ""),
    ("teacher_id", "uuid", "FK"),
    ("is_active", "boolean", ""),
    ("is_service", "boolean", ""),
], header_bg=BG_HEADER_ROUTINE)

t_cancellations = draw_table(ax, 270, 235, 50, "cancellations", [
    ("id", "uuid", "PK"),
    ("routine_id", "uuid", "FK"),
    ("cancelled_by", "uuid", "FK"),
    ("class_date", "date", ""),
    ("reason", "text", ""),
    ("batch", "text", ""),
    ("section", "text", ""),
    ("subject", "text", ""),
    ("created_at", "timestamptz", ""),
], header_bg=BG_HEADER_ROUTINE)

# ══════════════════════════════════════════════════════════════
# ZONE 3: COMMUNICATIONS & ACADEMIC CONTENT (MIDDLE LEFT)
# ══════════════════════════════════════════════════════════════
t_notifications = draw_table(ax, 100, 180, 52, "notifications", [
    ("id", "uuid", "PK"),
    ("title", "text", ""),
    ("body", "text", ""),
    ("type", "text", ""),
    ("sent_by", "uuid", "FK"),
    ("target_role", "text", ""),
    ("target_batch", "text", ""),
    ("target_section", "text", ""),
    ("created_at", "timestamptz", ""),
], header_bg=BG_HEADER_NOTIF)

t_reads = draw_table(ax, 184, 154, 54, "notification_reads", [
    ("user_id", "uuid", "PK,FK"),
    ("notification_id", "uuid", "PK,FK"),
    ("read_at", "timestamptz", ""),
], header_bg=BG_HEADER_NOTIF)

t_resources = draw_table(ax, 100, 130, 52, "resources", [
    ("id", "uuid", "PK"),
    ("title", "text", ""),
    ("category", "text", ""),
    ("semester", "int", ""),
    ("subject_code", "text", ""),
    ("drive_link", "text", ""),
    ("file_url", "text", ""),
    ("uploaded_by", "uuid", "FK"),
    ("created_at", "timestamptz", ""),
], header_bg=BG_HEADER_NOTIF)

# ══════════════════════════════════════════════════════════════
# ZONE 4: SOLVER ENGINE & CONFIGURATION (BOTTOM)
# ══════════════════════════════════════════════════════════════
t_rooms = draw_table(ax, 16, 75, 46, "timetable_rooms", [
    ("id", "uuid", "PK"),
    ("name", "text", ""),
    ("building", "text", ""),
    ("is_lab", "boolean", ""),
    ("is_gallery", "boolean", ""),
    ("capacity", "int", ""),
    ("is_active", "boolean", ""),
], header_bg=BG_HEADER_CONFIG)

t_faculty = draw_table(ax, 72, 75, 52, "timetable_faculty", [
    ("id", "uuid", "PK"),
    ("acronym", "text", ""),
    ("full_name", "text", ""),
    ("dept", "text", ""),
    ("designation", "text", ""),
    ("off_days", "text[]", ""),
    ("is_active", "boolean", ""),
], header_bg=BG_HEADER_CONFIG)

t_eligibility = draw_table(ax, 134, 75, 54, "timetable_course_eligibility", [
    ("id", "uuid", "PK"),
    ("acronym", "text", ""),
    ("course_code", "text", ""),
    ("is_eligible", "boolean", ""),
    ("priority", "int", ""),
    ("created_at", "timestamptz", ""),
], header_bg=BG_HEADER_CONFIG)

t_settings = draw_table(ax, 198, 75, 62, "timetable_settings", [
    ("id", "int", "PK"),
    ("semester_label", "text", ""),
    ("working_days", "text[]", ""),
    ("weeks_in_term", "int", ""),
    ("blocked_periods", "jsonb", ""),
    ("online_periods", "jsonb", ""),
    ("allow_online_periods", "boolean", ""),
    ("excluded_periods", "jsonb", ""),
    ("semester_map", "jsonb", ""),
    ("fixed_sessions_per_week", "int", ""),
    ("periods", "jsonb", ""),
    ("weights", "jsonb", ""),
    ("friday_no_p4", "boolean", ""),
    ("service_scope", "text", ""),
], header_bg=BG_HEADER_CONFIG)

t_runs = draw_table(ax, 270, 75, 50, "timetable_runs", [
    ("id", "uuid", "PK"),
    ("semester_label", "text", ""),
    ("file_path", "text", ""),
    ("stats", "jsonb", ""),
    ("validation", "jsonb", ""),
    ("status", "text", ""),
    ("row_count", "int", ""),
    ("created_by", "uuid", "FK"),
    ("created_at", "timestamptz", ""),
], header_bg=BG_HEADER_CONFIG)

# ══════════════════════════════════════════════════════════════
# RELATIONSHIPS
# ══════════════════════════════════════════════════════════════
# R1: routine_versions -> routines (contains)
link(ax, (t_versions["right"][0], t_versions["right"][1] + 4),
     (t_routines["left"][0], t_routines["left"][1] + 4),
     label="contains [ON DELETE CASCADE]", c1="1", c2="N")

# R2: profiles -> routine_versions (publishes)
link(ax, (t_profiles["right"][0], t_profiles["right"][1] + 12),
     (t_versions["left"][0], t_versions["left"][1] + 12),
     label="publishes", c1="1", c2="N")

# R3: routines -> cancellations (is cancelled in)
link(ax, (t_routines["right"][0], t_routines["right"][1] + 6),
     (t_cancellations["left"][0], t_cancellations["left"][1] + 6),
     label="is cancelled in [SET NULL]", c1="1", c2="N")

# R4: profiles -> notifications (sends)
link(ax, (t_profiles["right"][0], t_profiles["right"][1] - 8),
     (t_notifications["left"][0], t_notifications["left"][1] + 6),
     label="sends", c1="1", c2="N")

# R5: notifications -> notification_reads (tracks)
link(ax, (t_notifications["right"][0], t_notifications["right"][1] - 4),
     (t_reads["left"][0], t_reads["left"][1] - 4),
     label="tracks", c1="1", c2="N")

# R6: profiles -> resources (uploads)
link(ax, (t_profiles["right"][0], t_profiles["right"][1] - 22),
     (t_resources["left"][0], t_resources["left"][1]),
     label="uploads", c1="1", c2="N")

# R7: profiles -> device_tokens (registers)
link(ax, (t_profiles["bottom"][0] - 12, t_profiles["bottom"][1]),
     (t_device_tokens["top"][0] - 12, t_device_tokens["top"][1]),
     label="registers", c1="1", c2="N")

# R8: whitelists -> profiles (authorises logical)
link(ax, (t_whitelists["top"][0], t_whitelists["top"][1]),
     (t_profiles["bottom"][0], t_profiles["bottom"][1]),
     label="authorises (by email)", c1="1", c2="1")

# R9: faculty -> eligibility (qualifies logical)
link(ax, t_faculty["right"], t_eligibility["left"],
     label="qualifies", c1="1", c2="N")

# R10: profiles -> timetable_runs (executes)
link(ax, (t_profiles["right"][0], t_profiles["right"][1] - 26),
     (t_runs["left"][0], t_runs["left"][1] + 10),
     label="executes", c1="1", c2="N", route="hvh")

# R11: routines -> profiles (teaches logical / teacher_code)
link(ax, (t_profiles["top"][0] + 16, t_profiles["top"][1]),
     (t_routines["top"][0] - 16, t_routines["top"][1]),
     label="teaches (teacher_code)", c1="1", c2="N", route="hvh")

# ── Config Box Outline ────────────────────────────────────────
cfg_box = FancyBboxPatch((10, 5), 360, 80,
                         boxstyle="round,pad=0.8,rounding_size=2.0",
                         facecolor="none", edgecolor="#94a3b8",
                         linewidth=1.4, linestyle=(0, (6, 4)), zorder=1)
ax.add_patch(cfg_box)
ax.text(14, 82.5, "Timetable Engine Configuration & Solved Run Records (Read by Python CP-SAT solver at generation)",
        fontsize=10.5, style="italic", fontweight="bold", color="#64748b")

out = "docs/diagrams/er-diagram.png"
fig.savefig(out, dpi=140, facecolor="#ffffff", bbox_inches="tight", pad_inches=0.3)
print("wrote", out)
