# -*- coding: utf-8 -*-
"""
Generates SEARCH_SYSTEM.pdf - a deep-dive on how UniVerse's search /
campus-explore system works: Find Teacher + Room Availability, the
frontend-to-backend connection, the code files behind it, and how data
is retrieved (real-time), with visual diagrams.

Run: python tool/make_search_system_pdf.py
"""
from fpdf import FPDF

# ---- palette (UniVerse theme) ----
ORANGE = (255, 122, 0)
DARK = (26, 26, 28)
GREY = (110, 114, 120)
CODE_BG = (244, 244, 246)
LINE = (220, 220, 224)
BOX_BG = (255, 244, 232)
BOX2_BG = (232, 240, 255)
GREEN = (34, 197, 94)


def clean(s: str) -> str:
    return (s.replace("’", "'").replace("‘", "'")
             .replace("“", '"').replace("”", '"')
             .replace("–", "-").replace("—", "-")
             .replace("→", "->").replace("≤", "<=")
             .replace("≥", ">=").replace("…", "...")
             .replace("•", "-").replace(" ", " "))


class PDF(FPDF):
    def header(self):
        if self.page_no() == 1:
            return
        self.set_font("Helvetica", "", 8)
        self.set_text_color(*GREY)
        self.cell(0, 6, "UniVerse - Search & Campus Explore System", align="L")
        self.cell(0, 6, "Team Sherlocked", align="R", new_x="LMARGIN", new_y="NEXT")
        self.set_draw_color(*LINE)
        self.line(self.l_margin, self.get_y(), self.w - self.r_margin, self.get_y())
        self.ln(3)

    def footer(self):
        self.set_y(-12)
        self.set_font("Helvetica", "", 8)
        self.set_text_color(*GREY)
        self.cell(0, 6, f"Page {self.page_no()}", align="C")


pdf = PDF()
pdf.set_auto_page_break(auto=True, margin=15)
pdf.set_margins(18, 16, 18)
EPW = pdf.w - pdf.l_margin - pdf.r_margin


# ---------- helpers ----------
def section(title):
    pdf.add_page()
    pdf.set_font("Helvetica", "B", 15)
    pdf.set_text_color(*DARK)
    pdf.cell(0, 9, clean(title), new_x="LMARGIN", new_y="NEXT")
    pdf.set_draw_color(*ORANGE)
    pdf.set_line_width(0.8)
    pdf.line(pdf.l_margin, pdf.get_y(), pdf.l_margin + 40, pdf.get_y())
    pdf.set_line_width(0.2)
    pdf.ln(4)


def heading(title):
    if pdf.get_y() > pdf.h - 40:
        pdf.add_page()
    pdf.ln(1.5)
    pdf.set_font("Helvetica", "B", 12)
    pdf.set_text_color(*ORANGE)
    pdf.multi_cell(EPW, 6.5, clean(title))
    pdf.ln(0.5)


def body(text):
    pdf.set_font("Helvetica", "", 10.5)
    pdf.set_text_color(40, 40, 42)
    pdf.multi_cell(EPW, 5.4, clean(text), markdown=True)
    pdf.ln(1)


def code(text):
    pdf.ln(0.5)
    pdf.set_font("Courier", "", 8.6)
    pdf.set_fill_color(*CODE_BG)
    pdf.set_text_color(20, 20, 22)
    x0 = pdf.get_x()
    for ln in text.split("\n"):
        pdf.set_x(x0)
        pdf.cell(EPW, 4.6, "  " + clean(ln), fill=True, new_x="LMARGIN", new_y="NEXT")
    pdf.ln(1.5)


def tip(text):
    pdf.set_font("Helvetica", "I", 10)
    pdf.set_text_color(*ORANGE)
    pdf.multi_cell(EPW, 5.2, clean("Key idea: " + text))
    pdf.set_text_color(40, 40, 42)
    pdf.ln(1)


def box(x, y, w, h, label, sub="", fill=BOX_BG, border=ORANGE):
    pdf.set_fill_color(*fill)
    pdf.set_draw_color(*border)
    pdf.set_line_width(0.4)
    pdf.rect(x, y, w, h, style="DF")
    pdf.set_xy(x, y + (h / 2 - (5 if sub else 2.5)))
    pdf.set_font("Helvetica", "B", 9)
    pdf.set_text_color(*DARK)
    pdf.multi_cell(w, 4.4, clean(label), align="C")
    if sub:
        pdf.set_xy(x, y + h / 2 + 0.5)
        pdf.set_font("Courier", "", 7)
        pdf.set_text_color(*GREY)
        pdf.multi_cell(w, 3.4, clean(sub), align="C")
    pdf.set_line_width(0.2)


def arrow_down(x, y1, y2, label=""):
    pdf.set_draw_color(*GREY)
    pdf.set_line_width(0.4)
    pdf.line(x, y1, x, y2)
    # arrowhead
    pdf.line(x, y2, x - 1.3, y2 - 2.2)
    pdf.line(x, y2, x + 1.3, y2 - 2.2)
    if label:
        pdf.set_xy(x + 2, (y1 + y2) / 2 - 2)
        pdf.set_font("Helvetica", "I", 7)
        pdf.set_text_color(*GREY)
        pdf.cell(60, 4, clean(label))
    pdf.set_line_width(0.2)


# ============ COVER ============
pdf.add_page()
pdf.ln(28)
pdf.set_font("Helvetica", "B", 30)
pdf.set_text_color(*ORANGE)
pdf.cell(0, 14, "UniVerse", align="C", new_x="LMARGIN", new_y="NEXT")
pdf.set_font("Helvetica", "", 13)
pdf.set_text_color(*DARK)
pdf.cell(0, 8, "A Campus Companion", align="C", new_x="LMARGIN", new_y="NEXT")
pdf.ln(6)
pdf.set_font("Helvetica", "B", 17)
pdf.cell(0, 9, "The Search & Campus-Explore System", align="C", new_x="LMARGIN", new_y="NEXT")
pdf.set_font("Helvetica", "", 11.5)
pdf.set_text_color(*GREY)
pdf.cell(0, 7, "Find Teacher  *  Room Availability", align="C", new_x="LMARGIN", new_y="NEXT")
pdf.ln(10)
pdf.set_font("Helvetica", "", 11)
for line in [
    "Leading University, Sylhet - Dept. of CSE",
    "Course CSE-3240 (Project I) - Team Sherlocked",
    "",
    "How search works - the code files & functions behind it -",
    "the full frontend-to-backend connection - and how data is",
    "retrieved in real time, with visual diagrams.",
]:
    pdf.cell(0, 7, clean(line), align="C", new_x="LMARGIN", new_y="NEXT")

# ============ 1. OVERVIEW ============
section("1. What 'Search' Means in UniVerse")
body("UniVerse's search system is the **Campus Explore** feature - reached from the floating **Explore** button on every dashboard. It has two faces that share one engine:")
body("- **Find Teacher** - type a name or teacher code and instantly see *where that teacher is right now* (which room, time remaining) or *when their next class is*.")
body("- **Room Availability** - browse every room and see whether it is **OCCUPIED** or **AVAILABLE** right now, with the current class and the next one.")
pdf.ln(1)
body("The clever part: there is **no separate 'search index' or extra database table**. Both features read only the existing **routines** table (the published weekly timetable) plus **cancellations**, and *derive* live status by comparing the current clock time against the schedule. Search is therefore two things working together:")
body("**(a) Retrieval** - pull the weekly schedule from Supabase (once, then live updates).")
body("**(b) Filtering + derivation** - in the app, narrow the list by the typed query and compute each teacher's / room's current state from `DateTime.now()`.")
tip("Search = retrieve the timetable once, keep it live, then filter & time-derive on the device. No search server, no extra tables.")

# ============ 2. ARCHITECTURE DIAGRAM ============
section("2. The Layered Architecture (Screen -> Controller -> Service -> DB)")
body("UniVerse enforces a strict one-way layering. The screen never talks to the database; it goes through a controller, which goes through a service, which is the *only* layer allowed to touch Supabase.")
pdf.ln(2)

# draw vertical stack of boxes
cx = pdf.l_margin
bw = EPW
bx = cx + (EPW - 150) / 2  # center a 150-wide stack
bw = 150
y = pdf.get_y() + 2
bh = 16
gap = 9

box(bx, y, bw, bh, "SCREEN  (UI)",
    "find_teacher_screen.dart  -  search box + ListView", fill=BOX_BG)
arrow_down(bx + bw / 2, y + bh, y + bh + gap, "onChanged / initState")
y2 = y + bh + gap
box(bx, y2, bw, bh, "CONTROLLER  (state + logic)",
    "FindTeacherController  -  ChangeNotifier", fill=BOX_BG)
arrow_down(bx + bw / 2, y2 + bh, y2 + bh + gap, "fetch / stream calls")
y3 = y2 + bh + gap
box(bx, y3, bw, bh, "SERVICE  (data access)",
    "TeacherLocationService  -  ONLY Supabase caller", fill=BOX_BG)
arrow_down(bx + bw / 2, y3 + bh, y3 + bh + gap, "SELECT / Realtime stream (+ RLS)")
y4 = y3 + bh + gap
box(bx, y4, bw, bh, "SUPABASE  (Postgres)",
    "routines table  (+ cancellations)", fill=BOX2_BG, border=(60, 120, 220))

pdf.set_y(y4 + bh + 6)
body("**Why this matters for retrieval:** because only the service touches Supabase, every query automatically runs under the user's session - so **Row Level Security** decides what rows come back. The routines table is `read_all` for any authenticated user, which is exactly why a student can look up *any* teacher or room.")

# ============ 3. FILE / FUNCTION MAP ============
section("3. The Code Files & Functions Behind It")
body("Find Teacher and Room Availability are mirror-image feature slices. Here is the full map:")
pdf.ln(1)


def file_table(title, rows):
    heading(title)
    pdf.set_font("Helvetica", "B", 9)
    pdf.set_fill_color(*ORANGE)
    pdf.set_text_color(255, 255, 255)
    pdf.cell(58, 6.5, "  File", fill=True, new_x="RIGHT", new_y="TOP")
    pdf.cell(EPW - 58, 6.5, "  Responsibility / key functions", fill=True,
             new_x="LMARGIN", new_y="NEXT")
    fill = False
    for f, r in rows:
        pdf.set_fill_color(248, 248, 250) if fill else pdf.set_fill_color(255, 255, 255)
        ytop = pdf.get_y()
        pdf.set_font("Courier", "", 7.6)
        pdf.set_text_color(*ORANGE)
        pdf.multi_cell(58, 4.2, "  " + clean(f), fill=True,
                       new_x="RIGHT", new_y="TOP", max_line_height=4.2)
        yafter_left = pdf.get_y()
        pdf.set_xy(pdf.l_margin + 58, ytop)
        pdf.set_font("Helvetica", "", 8.6)
        pdf.set_text_color(40, 40, 42)
        pdf.multi_cell(EPW - 58, 4.6, "  " + clean(r), fill=True,
                       new_x="LMARGIN", new_y="NEXT", max_line_height=4.6)
        # keep rows aligned to the taller column
        if yafter_left > pdf.get_y():
            pdf.set_y(yafter_left)
        fill = not fill
    pdf.ln(2)


file_table("Find Teacher (lib/features/find_teacher/)", [
    ("screens/find_teacher_screen.dart",
     "Search box (UTextField) + live ListView of teacher cards. initState() starts the controller + real-time subscription; onChanged calls controller.search()."),
    ("controllers/find_teacher_controller.dart",
     "Brain. initialize() builds the teacher list; _buildTeacherInfo() derives In Class / Free / No Class Today from the clock; search() filters by name or code; subscribeToRealTimeUpdates() keeps it live. Holds TeacherInfo model."),
    ("services/teacher_location_service.dart",
     "ONLY Supabase layer. fetchAllRoutines() (one-shot SELECT) and streamAllRoutines() (Realtime). Maps rows -> RoutineEntry."),
    ("widgets/teacher_location_card.dart",
     "Presentational card: room, remaining time, next class, status chip."),
])

file_table("Room Availability (lib/features/rooms/)", [
    ("screens/rooms_screen.dart", "Room list with OCCUPIED / AVAILABLE chips."),
    ("controllers/rooms_controller.dart",
     "fetchRoomStatuses() groups routines by room, then time-derives each room's current + next class. Holds RoomStatus model."),
    ("services/room_status_service.dart",
     "ONLY Supabase layer. fetchAllRoutines() + streamAllRoutines() on routines."),
    ("widgets/room_status_card.dart", "Occupancy chip, current teacher/subject, countdown."),
])

file_table("Shared foundations", [
    ("core/models/routine_model.dart",
     "RoutineEntry.fromMap() parses a DB row; startOn(now)/endOn(now) turn time strings into today's DateTime for comparison."),
    ("shared/widgets/explore_fab_menu.dart",
     "The Explore FAB -> bottom sheet -> pushes /find-teacher or /rooms."),
])

# ============ 4. END TO END FLOW ============
section("4. Full Frontend <-> Backend Flow (Find Teacher)")
body("This is the complete journey of one search, from a keystroke to the rendered card.")
pdf.ln(2)

# numbered flow boxes (two columns of steps connected)
steps = [
    ("1. App opens screen", "initState() -> controller.initialize()"),
    ("2. Service queries DB", "SELECT * FROM routines WHERE is_active"),
    ("3. Supabase + RLS", "returns only readable rows -> List<RoutineEntry>"),
    ("4. Controller builds list", "unique teachers + _buildTeacherInfo(now)"),
    ("5. User types query", "onChanged -> controller.search('jam')"),
    ("6. In-memory filter", ".where(name/code contains query)"),
    ("7. notifyListeners()", "ListenableBuilder rebuilds ListView"),
    ("8. Live updates", "stream pushes new rows -> re-derive -> repaint"),
]
y = pdf.get_y() + 1
bh = 13
bw = EPW
for i, (t, s) in enumerate(steps):
    box(pdf.l_margin, y, bw, bh, t + "    -    " + s, "",
        fill=(BOX_BG if i % 2 == 0 else BOX2_BG),
        border=(ORANGE if i % 2 == 0 else (60, 120, 220)))
    if i < len(steps) - 1:
        arrow_down(pdf.l_margin + 12, y + bh, y + bh + 5)
    y += bh + 5
pdf.set_y(y + 2)

body("Steps 1-4 are **retrieval** (frontend asking the backend). Steps 5-7 are **search** (pure on-device filtering - no network). Step 8 is **real-time retrieval** keeping the result fresh.")

# ============ 5. RETRIEVAL CODE ============
section("5. How Data Is Retrieved (the backend call)")
heading("5.1  One-shot fetch")
body("The service issues a single filtered SELECT. `.eq('is_active', true)` skips superseded timetables; ordering by start time makes the later 'current/next' scan simple.")
code("// teacher_location_service.dart\n"
     "Future<List<RoutineEntry>> fetchAllRoutines() async {\n"
     "  final rows = await _supabase\n"
     "      .from(AppConstants.tableRoutines)\n"
     "      .select()\n"
     "      .eq('is_active', true)\n"
     "      .order('time_start', ascending: true);\n"
     "  return _map(rows); // each row -> RoutineEntry.fromMap()\n"
     "}")

heading("5.2  Real-time retrieval (the 'live' in live search)")
body("Instead of polling, the service opens a Supabase **Realtime stream**. Whenever the routines table changes (e.g. admin publishes a new timetable), Supabase pushes the new row set; the controller re-derives every status and the UI repaints - with no user action.")
code("// teacher_location_service.dart\n"
     "Stream<List<RoutineEntry>> streamAllRoutines() {\n"
     "  return _supabase\n"
     "      .from(AppConstants.tableRoutines)\n"
     "      .stream(primaryKey: ['id'])\n"
     "      .eq('is_active', true)\n"
     "      .map((rows) => _map(rows));\n"
     "}\n\n"
     "// controller subscribes once:\n"
     "void subscribeToRealTimeUpdates() {\n"
     "  _service.streamAllRoutines().listen((routines) {\n"
     "    _allRoutines = routines;\n"
     "    initialize(); // rebuild + re-derive\n"
     "  });\n"
     "}")
tip("Realtime streams obey RLS too - the live feed only carries rows the user is allowed to read.")

# ============ 6. SEARCH + DERIVATION ============
section("6. The Search Filter & Time-Derivation Logic")
heading("6.1  The actual search (substring match, case-insensitive)")
body("Search is a pure in-memory filter - instant, offline, no DB round-trip. It matches the lowercased query against either the teacher's name or code:")
code("// find_teacher_controller.dart\n"
     "void search(String query) {\n"
     "  _searchQuery = query.toLowerCase();\n"
     "  if (_searchQuery.isEmpty) {\n"
     "    _filteredTeachers = _allTeachers;\n"
     "  } else {\n"
     "    _filteredTeachers = _allTeachers.where((t) =>\n"
     "        t.name.toLowerCase().contains(_searchQuery) ||\n"
     "        t.code.toLowerCase().contains(_searchQuery)).toList();\n"
     "  }\n"
     "  notifyListeners(); // -> UI rebuilds the filtered list\n"
     "}")

heading("6.2  Deriving 'where is this teacher right now?'")
body("For each teacher, the controller keeps only today's classes, sorts them, then walks them against `DateTime.now()`:")
body("- If now is **between** a class start and end -> status **In Class** (show room + minutes remaining).")
body("- Else the first class still in the future -> status **Free** (show next class).")
body("- No classes today -> **No Class Today**.")
code("// _buildTeacherInfo(...) - the core decision\n"
     "for (final entry in teacherRoutines) {\n"
     "  final start = entry.startOn(now);\n"
     "  final end   = entry.endOn(now);\n"
     "  if (now.isAfter(start) && now.isBefore(end)) {\n"
     "    currentEntry = entry; status = 'In Class'; break;\n"
     "  }\n"
     "}")
body("'Today' is matched by mapping `DateTime.now().weekday` onto the Sun-Sat day names that the routines table stores - the project's single 7-day source of truth.")

# ============ 7. ROOMS PARALLEL ============
section("7. Room Availability - Same Engine, Grouped by Room")
body("Room Availability reuses the identical retrieval path, but the controller **groups routines by room** instead of by teacher, then time-derives occupancy:")
code("// rooms_controller.dart (shape)\n"
     "routinesByRoom[entry.room].add(entry);    // group\n"
     "for (room in routinesByRoom) {\n"
     "  if (now between start & end) -> OCCUPIED (current class)\n"
     "  else -> AVAILABLE (+ next class if any)\n"
     "}")
body("So the two features differ only in the *grouping key* (teacher_code vs room) and what each card shows. Both are read-only, real-time, and add no new tables - exactly as designed.")
tip("One retrieval engine, two lenses: group by teacher = Find Teacher; group by room = Room Availability.")

# ============ 8. SUMMARY ============
section("8. One-Page Summary (for the viva)")
body("**What is the search system?** The Campus Explore feature: Find Teacher (search by name/code) and Room Availability, both real-time.")
body("**Where does the data come from?** Only the existing `routines` table (+ `cancellations`) via a service layer - no search engine, no extra tables.")
body("**Frontend-to-backend path:** Screen -> Controller -> Service -> Supabase (under RLS) -> back as RoutineEntry objects.")
body("**How is it retrieved?** A filtered SELECT for the first paint, then a Supabase Realtime stream for live updates.")
body("**How does search itself work?** A pure in-memory, case-insensitive substring filter on the already-loaded list (instant, offline).")
body("**How is 'right now' known?** The controller compares `DateTime.now()` to each class's start/end to derive In Class / Free / Occupied / Available.")
body("**Why this design?** It is simple, needs no scheduled jobs, stays correct the instant the admin publishes a routine, and respects per-role security automatically through RLS.")
pdf.ln(2)
body("**Files to point at:** find_teacher_screen.dart (UI+search box), find_teacher_controller.dart (search() + _buildTeacherInfo()), teacher_location_service.dart (fetchAllRoutines / streamAllRoutines), and the rooms/ mirror.")

pdf.output("SEARCH_SYSTEM.pdf")
print("OK -> SEARCH_SYSTEM.pdf")
