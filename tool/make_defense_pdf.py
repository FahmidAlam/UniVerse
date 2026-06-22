# -*- coding: utf-8 -*-
"""
Generates DEFENSE_QA.pdf - a defense-ready Q&A cheat sheet for UniVerse.
Run: python tool/make_defense_pdf.py
"""
from fpdf import FPDF

# ---- palette (UniVerse theme) ----
ORANGE = (255, 122, 0)
DARK = (26, 26, 28)
GREY = (110, 114, 120)
CODE_BG = (244, 244, 246)
LINE = (220, 220, 224)


def clean(s: str) -> str:
    # keep PDF latin-1 safe
    return (s.replace("’", "'").replace("‘", "'")
             .replace("“", '"').replace("”", '"')
             .replace("–", "-").replace("—", "-")
             .replace("→", "->").replace("≤", "<=")
             .replace("≥", ">=").replace("…", "...")
             .replace(" ", " "))


class PDF(FPDF):
    def header(self):
        if self.page_no() == 1:
            return
        self.set_font("Helvetica", "", 8)
        self.set_text_color(*GREY)
        self.cell(0, 6, "UniVerse - Defense Q&A", align="L")
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


def qnum(n, title):
    pdf.ln(2)
    if pdf.get_y() > pdf.h - 40:
        pdf.add_page()
    pdf.set_font("Helvetica", "B", 12.5)
    pdf.set_text_color(*ORANGE)
    pdf.cell(9, 7, f"{n}.", new_x="RIGHT", new_y="TOP")
    pdf.set_text_color(*DARK)
    pdf.multi_cell(EPW - 9, 7, clean(title))
    pdf.ln(1)


def body(text):
    pdf.set_font("Helvetica", "", 10.5)
    pdf.set_text_color(40, 40, 42)
    pdf.multi_cell(EPW, 5.4, clean(text), markdown=True)
    pdf.ln(1)


def code(text):
    pdf.ln(0.5)
    pdf.set_font("Courier", "", 9)
    pdf.set_fill_color(*CODE_BG)
    pdf.set_text_color(20, 20, 22)
    x0 = pdf.get_x()
    for ln in text.split("\n"):
        pdf.set_x(x0)
        pdf.cell(EPW, 5, "  " + clean(ln), fill=True, new_x="LMARGIN", new_y="NEXT")
    pdf.ln(1.5)


def tip(text):
    pdf.set_font("Helvetica", "I", 10)
    pdf.set_text_color(*ORANGE)
    pdf.multi_cell(EPW, 5.2, clean("One-liner: " + text))
    pdf.set_text_color(40, 40, 42)
    pdf.ln(1)


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


# ============ COVER ============
pdf.add_page()
pdf.ln(30)
pdf.set_font("Helvetica", "B", 30)
pdf.set_text_color(*ORANGE)
pdf.cell(0, 14, "UniVerse", align="C", new_x="LMARGIN", new_y="NEXT")
pdf.set_font("Helvetica", "", 13)
pdf.set_text_color(*DARK)
pdf.cell(0, 8, "A Campus Companion", align="C", new_x="LMARGIN", new_y="NEXT")
pdf.ln(6)
pdf.set_font("Helvetica", "B", 17)
pdf.cell(0, 9, "Project Defense - Q&A Cheat Sheet", align="C", new_x="LMARGIN", new_y="NEXT")
pdf.ln(10)
pdf.set_font("Helvetica", "", 11)
pdf.set_text_color(*GREY)
for line in [
    "Leading University, Sylhet - Dept. of CSE",
    "Course CSE-3240 (Project I) - Team Sherlocked",
    "Flutter (Dart) - Supabase - OR-Tools CP-SAT Timetable Engine",
    "",
    "Covers: OOP core concepts, Dart/Flutter specifics, regex,",
    "and the project's value proposition.",
]:
    pdf.cell(0, 7, clean(line), align="C", new_x="LMARGIN", new_y="NEXT")

# ============ PART A: OOP & LANGUAGE CONCEPTS ============
section("Part A - Core OOP & Language Concepts")

qnum(1, "Error vs Exception")
body("Both are problems at runtime, but the *intent* differs:")
body("- **Exception**: a problem you *expect and can recover from*. You catch it and keep the app alive. e.g. the network drops while fetching routines from Supabase -> catch it, show a snackbar.")
body("- **Error**: a serious *programmer mistake* you are NOT meant to catch - the app should crash so you fix the code. e.g. null access, calling a missing method, stack overflow.")
tip("Exceptions are for situations, Errors are for bugs. I handle exceptions; I fix errors.")
body("In UniVerse I catch PostgrestException / AuthException in the service layer and surface a friendly message.")

qnum(2, "How is an object created?")
body("From a **class** (the blueprint) using a **constructor**, called with the class name:")
code("final controller = TimetableGenController();")
body("Steps: memory is allocated -> the constructor runs and initializes the fields -> a **reference** to that object is returned and stored in the variable. In Dart the 'new' keyword is optional, so we just write RoutineService().")

qnum(3, "super keyword")
body("`super` refers to the **parent class**. It lets a child call the parent's constructor or methods.")
body("- super(...) -> call the parent's constructor.")
body("- super.method() -> run the parent's version of an overridden method.")
code("class DashboardScreen extends StatefulWidget {\n  const DashboardScreen({super.key}); // passes key up\n}")

qnum(4, "this keyword")
body("`this` refers to the **current object** - used to tell a field apart from a parameter with the same name.")
code("class Profile {\n  String name;\n  Profile(String name) {\n    this.name = name; // this.name = field, name = parameter\n  }\n}")
tip("this = me (the current instance). super = my parent.")

qnum(5, "final vs static")
body("They answer **different questions** - people confuse them:")
body("- **final** -> 'can this value change?' No - assigned **once**, per object.")
body("- **static** -> 'does it belong to the object or the class itself?' It belongs to the **class**, is shared by all instances, and is accessed without an object.")
code("class AppConstants {\n  static const weekDays = [...]; // one shared list, no object\n}\nfinal id = user.id;              // set once for this user")
body("My whole design system (AppColors, AppConstants) is static const - that is why I write AppColors.primary, not AppColors().primary.")

qnum(6, "const vs final  (the one examiners love)")
body("Both make a value unchangeable. The difference is **WHEN** the value is fixed:")
body("- **const** -> a **compile-time** constant. The value must be known *before the app runs*, fixed permanently, can never change. e.g. const pi = 3.1416; const weekDays = [...].")
body("- **final** -> a **run-time** constant. The value is set **once when the object is created**, can be a value computed at runtime. e.g. final now = DateTime.now();")
code("const maxRetries = 3;        // known at compile time\nfinal createdAt = DateTime.now(); // known only at runtime")
tip("const = locked at compile time (never changes); final = locked once at runtime (set when the object is built).")
body("Note: every const is also final, but not every final can be const. const objects are also **canonicalized** (identical consts share one instance in memory), which is why Flutter loves const widgets - they are not rebuilt.")

qnum(7, "Method Override vs Overload")
body("- **Override** -> a child class **replaces** a parent method using the **same signature** (same name + same parameters). Dart supports this.")
body("- **Overload** -> **same name, different parameters** in one class. **Dart does NOT support overloading** - instead we use **named / optional parameters**.")
code("@override\nWidget build(BuildContext context) { ... } // override\n\n// Dart's replacement for overloading:\nvoid notify({String? title, String? body}) { ... }")
tip("Java has overloading; Dart replaces it with named & optional parameters.")

qnum(8, "try / catch / finally")
body("A safety net for risky code:")
body("- **try** -> run the risky code (e.g. an HTTP call to the timetable engine).")
body("- **catch** -> if it throws, handle it instead of crashing.")
body("- **finally** -> runs **no matter what** (success or failure) - used for cleanup (stop a loader, close a connection).")
code("try {\n  final rows = await engine.generate(file); // risky\n} catch (e) {\n  showError('Generation failed');           // recover\n} finally {\n  isLoading = false;                        // always runs\n  notifyListeners();\n}")

qnum(9, "Parent class vs Child class")
body("- **Parent (superclass / base)** -> the general blueprint.")
body("- **Child (subclass / derived)** -> a specialized version that **inherits** everything from the parent and adds or overrides behavior.")
body("Example: StatefulWidget (parent) -> DashboardScreen extends StatefulWidget (child). The child gets the parent's machinery for free.")

qnum(10, "Difference between child and children (Flutter)")
body("This is a **Flutter** point, not OOP:")
body("- **child** -> takes **one** widget (Container, Center, Padding).")
body("- **children** -> takes a **list** of widgets (Column, Row, ListView).")
code("Center(child: Text('Hi'))\nColumn(children: [Text('a'), Text('b')])")
tip("Singular = one widget; plural = a list of widgets.")

qnum(11, "What is setState?")
body("A Flutter method (on a StatefulWidget) that tells the framework **'my data changed - rebuild this widget'**. It re-runs build() with the new values.")
code("setState(() { counter++; }); // UI updates")
body("Important for my defense: I mostly do NOT use setState for app data - I use **ChangeNotifier + ListenableBuilder** (my architecture rule). setState is only for tiny local UI like toggling password visibility.")

qnum(12, "Access modifiers - types and what")
body("They control **visibility** - who can access a member. Dart is simpler than Java: it has only **two**, based on the underscore '_':")
body("- **Public** (default, no underscore) -> accessible everywhere.")
body("- **Private** (_ prefix) -> accessible **only within that file/library**.")
code("class AuthService {\n  String email;          // public\n  String _sessionToken;  // private to this file\n}")
tip("Java has public/private/protected/default; Dart simplifies to public vs library-private using '_'.")

qnum(13, "Validation vs Verification")
body("A classic trap:")
body("- **Validation** -> 'is the **data** correct / are we building the right thing?' Checks input against rules (email format, password length).")
body("- **Verification** -> 'is this **authentic** / are we building it correctly?' Confirms truth (email verify link, OTP).")
body("In UniVerse: validation = form checks before submit; verification = the email-verify deep-link step after signup.")

qnum(14, "Override / Polymorphism / Abstraction / Interface")
body("These four go together - the OOP centerpiece:")
body("- **Polymorphism** -> 'many forms'. One interface, many behaviors. A Widget reference can hold a Text, a Column, a Card - each renders differently from the same build() call.")
body("- **Override** -> the *mechanism* enabling runtime polymorphism (child redefines a parent method).")
body("- **Abstraction** -> hiding *how* something works, exposing *what* it does. My screens call RoutineService.fetchForStudent() with no idea about SQL or Supabase. That is abstraction.")
body("- **Interface** -> a **contract**: methods a class must implement, with no implementation itself. In Dart **every class is an implicit interface**, and abstract class is used for this.")
tip("Abstraction hides detail, an interface defines a contract, override fulfills it differently, polymorphism treats them all the same at runtime.")
body("Real example: my Screen -> Controller -> Service layering means a controller depends on the service's *abstraction*, not its Supabase internals.")

qnum(15, "super();")
body("Explicitly calls the **parent constructor**. If omitted, Dart calls the parent's no-arg constructor automatically. You write it when the parent needs arguments:")
code("class Admin extends User {\n  Admin(String name) : super(name); // pass name up to User\n}")

qnum(16, "super.key")
body("The Flutter shorthand seen in **every widget**:")
code("const DashboardScreen({super.key});")
body("A **key** uniquely identifies a widget so Flutter knows which is which when the tree rebuilds (preserves state, reorders lists correctly). super.key means 'take the key parameter and pass it up to the parent Widget'. It is modern Dart sugar for the older: Key? key}) : super(key: key).")

qnum(17, "Local variable vs Instance variable")
body("- **Local variable** -> declared **inside a method**; lives only while that method runs, then dies. Not visible outside.")
body("- **Instance variable (field)** -> declared **inside the class**; lives as long as the object lives; shared across the object's methods.")
code("class RoutineController {\n  List<Routine> routines = [];      // instance variable (state)\n  void load() {\n    final res = await fetch();       // local variable (gone after)\n    routines = res;\n  }\n}")

# ============ PART B: REGEX (detailed) ============
section("Part B - Regular Expressions (Regex)")

body("**Regex = Regular Expression**: a *pattern* used to match or search text. In UniVerse I use it for **two** things:")
body("1. **Validate user input** - e.g. is this a correctly formatted email or student ID before sign-up?")
body("2. **Search inside text** - e.g. check whether a description contains a certain pattern.")

pdf.ln(1)
body("**How to use it in Dart** - build a RegExp with a *raw string* (the r'...' prefix stops Dart from treating backslashes as escape characters):")
code("final emailRegex = RegExp(r'^[\\w.+-]+@[\\w-]+\\.[\\w.-]+$');\nif (!emailRegex.hasMatch(input)) showError('Invalid email');")

body("**Flags** (in JS-style /pattern/flags notation, e.g. /color/gi):")
code("g  -> global      (find all matches, not just the first)\ni  -> insensitive (ignore upper/lower case)")

pdf.ln(1)
body("**Common tokens (the building blocks):**")

# token table
rows = [
    ("^", "start of string"),
    ("$", "end of string"),
    ("\\d", "any digit (0-9)"),
    ("\\w", "any word char (A-Z, a-z, 0-9, _)"),
    ("\\s", "any whitespace (space, tab)"),
    (".", "any single character"),
    ("+", "one or more of the previous"),
    ("*", "zero or more of the previous"),
    ("[A-Z]", "any one uppercase letter (a 'set')"),
    ("{8,}", "at least 8 of the previous"),
]
pdf.set_font("Helvetica", "B", 9.5)
pdf.set_fill_color(*ORANGE)
pdf.set_text_color(255, 255, 255)
pdf.cell(28, 7, "  Token", border=0, fill=True, new_x="RIGHT", new_y="TOP")
pdf.cell(EPW - 28, 7, "  Meaning", border=0, fill=True, new_x="LMARGIN", new_y="NEXT")
fill = False
for tok, mean in rows:
    pdf.set_fill_color(248, 248, 250) if fill else pdf.set_fill_color(255, 255, 255)
    pdf.set_font("Courier", "B", 9.5)
    pdf.set_text_color(*ORANGE)
    pdf.cell(28, 6.5, "  " + tok, border=0, fill=True, new_x="RIGHT", new_y="TOP")
    pdf.set_font("Helvetica", "", 9.5)
    pdf.set_text_color(40, 40, 42)
    pdf.cell(EPW - 28, 6.5, "  " + clean(mean), border=0, fill=True, new_x="LMARGIN", new_y="NEXT")
    fill = not fill
pdf.ln(3)

body("**Worked example - a strong password rule:**")
code("RegExp(r'^(?=.*[A-Z])(?=.*\\d).{8,}$')")
body("Read it left to right:")
body("- ^ ... $  -> match the whole string start to end.")
body("- (?=.*[A-Z]) -> must contain **at least one uppercase** letter.")
body("- (?=.*\\d)   -> must contain **at least one digit**.")
body("- .{8,}       -> **at least 8 characters** total.")
tip("Regex is a compact search pattern; I use it to validate emails, IDs and passwords in the auth forms.")

# ============ PART C: PROJECT VALUE ============
section("Part C - Why will a user use your app?")

body("Answer as **problem -> solution -> differentiator**:")
pdf.ln(1)
body("Right now students, teachers and admin at Leading University juggle scattered PDFs, WhatsApp groups and manual notice boards. **UniVerse is one campus companion** that brings routines, resources, class cancellations and push notifications into a single role-aware app.")
body("But the real reason - our **differentiator** - is the **automatic department timetable generator**. Building a clash-free routine for 55 cohorts, 76 teachers and limited rooms is normally days of manual work. UniVerse does it in **seconds** using an **OR-Tools CP-SAT constraint solver**, guarantees no teacher/room/cohort double-booking, and the admin publishes it to every student and teacher with **one tap** - which instantly fires a push notification.")
body("So: students get a live dashboard with their next class and a countdown; teachers can cancel a class and instantly alert students; the admin automates the hardest scheduling job on campus. **That mix of convenience + automation is why they will use it.**")

pdf.ln(2)
body("**Likely follow-up questions (be ready):**")
body("- *Why CP-SAT / OR-Tools?* -> scheduling is a constraint-satisfaction problem; CP-SAT finds a provably clash-free solution far faster than brute force.")
body("- *Why ChangeNotifier, not Riverpod/Bloc?* -> it is built into Flutter, simple, and enough for our app's scale - less boilerplate for the team.")
body("- *Why Supabase?* -> Postgres + Auth + Storage + Realtime in one, with Row Level Security so each role only sees its own data.")
body("- *How do push notifications work?* -> any INSERT into the notifications table fires a Supabase Edge Function (send-push) via a DB webhook, which delivers an OS push through Firebase FCM.")

pdf.output("DEFENSE_QA.pdf")
print("OK -> DEFENSE_QA.pdf")
