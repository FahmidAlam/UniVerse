# -*- coding: utf-8 -*-
"""
Generates UniVerse_Concepts_Answers.pdf — a study/defense reference answering
Dart/Flutter concept questions with real code references from the UniVerse app.
"""
from fpdf import FPDF

# ---------- colors ----------
ORANGE = (255, 122, 0)
DARK = (26, 26, 28)
GREY = (90, 90, 95)
CODE_BG = (244, 244, 246)
HEAD_BG = (255, 240, 224)


def san(s: str) -> str:
    """fpdf core fonts are latin-1; map common unicode to ASCII."""
    repl = {
        "–": "-", "—": "-", "→": "->", "←": "<-",
        "↔": "<->", "•": "*", "…": "...", "‘": "'",
        "’": "'", "“": '"', "”": '"', "≥": ">=",
        "≤": "<=", "×": "x", " ": " ", " ": " ",
        "✓": "[ok]", "⛔": "[x]", "⚙": "*", "✅": "[ok]",
    }
    for k, v in repl.items():
        s = s.replace(k, v)
    return s.encode("latin-1", "replace").decode("latin-1")


class PDF(FPDF):
    def header(self):
        if self.page_no() == 1:
            return
        self.set_font("Helvetica", "I", 8)
        self.set_text_color(*GREY)
        self.cell(0, 8, "UniVerse - A Campus Companion | Dart/Flutter Concepts Reference",
                  0, 1, "R")
        self.ln(1)

    def footer(self):
        self.set_y(-12)
        self.set_font("Helvetica", "I", 8)
        self.set_text_color(*GREY)
        self.cell(0, 8, f"Page {self.page_no()}", 0, 0, "C")


pdf = PDF()
pdf.set_auto_page_break(auto=True, margin=15)
pdf.set_margins(15, 15, 15)
EPW = pdf.epw  # effective page width


def _lm():
    pdf.set_x(pdf.l_margin)


def h1(text):
    pdf.ln(2)
    _lm()
    pdf.set_fill_color(*ORANGE)
    pdf.set_text_color(255, 255, 255)
    pdf.set_font("Helvetica", "B", 14)
    pdf.multi_cell(0, 9, san(text), 0, "L", True)
    pdf.set_text_color(0, 0, 0)
    pdf.ln(2)


def h2(text):
    pdf.ln(1)
    _lm()
    pdf.set_fill_color(*HEAD_BG)
    pdf.set_text_color(*DARK)
    pdf.set_font("Helvetica", "B", 12)
    pdf.multi_cell(0, 8, san(text), 0, "L", True)
    pdf.set_text_color(0, 0, 0)
    pdf.ln(1)


def h3(text):
    pdf.ln(1)
    _lm()
    pdf.set_text_color(*ORANGE)
    pdf.set_font("Helvetica", "B", 10.5)
    pdf.multi_cell(0, 6, san(text))
    pdf.set_text_color(0, 0, 0)


def body(text):
    _lm()
    pdf.set_font("Helvetica", "", 10)
    pdf.set_text_color(20, 20, 20)
    pdf.multi_cell(0, 5.4, san(text))
    pdf.ln(1)


def bullet(text):
    _lm()
    pdf.set_font("Helvetica", "", 10)
    pdf.set_text_color(20, 20, 20)
    x = pdf.get_x()
    pdf.cell(5, 5.4, "-")
    pdf.set_x(x + 5)
    pdf.multi_cell(EPW - 5, 5.4, san(text))


def code(text, caption=None):
    _lm()
    if caption:
        pdf.set_font("Helvetica", "I", 8.5)
        pdf.set_text_color(*GREY)
        pdf.multi_cell(0, 4.6, san(caption))
        pdf.set_text_color(0, 0, 0)
    pdf.set_fill_color(*CODE_BG)
    pdf.set_font("Courier", "", 8.3)
    pdf.set_text_color(20, 20, 30)
    # render each line; multi_cell wraps long lines automatically
    for line in text.split("\n"):
        _lm()
        pdf.multi_cell(0, 4.4, san(line) if line else " ", 0, "L", True)
    pdf.set_text_color(0, 0, 0)
    pdf.ln(2)


# ============================================================
# TITLE PAGE
# ============================================================
pdf.add_page()
pdf.ln(40)
pdf.set_text_color(*ORANGE)
pdf.set_font("Helvetica", "B", 26)
_lm(); pdf.multi_cell(0, 12, "UniVerse", 0, "C")
pdf.set_text_color(*DARK)
pdf.set_font("Helvetica", "", 14)
_lm(); pdf.multi_cell(0, 8, "A Campus Companion", 0, "C")
pdf.ln(8)
pdf.set_font("Helvetica", "B", 16)
_lm(); pdf.multi_cell(0, 9, "Dart & Flutter Concepts", 0, "C")
pdf.set_font("Helvetica", "", 12)
_lm(); pdf.multi_cell(0, 7, "Viva / Defense Reference with Real Code from the App", 0, "C")
pdf.ln(20)
pdf.set_font("Helvetica", "", 11)
pdf.set_text_color(*GREY)
_lm(); pdf.multi_cell(0, 6,
    san("Department of CSE  -  Course CSE-3240 (Project I)\n"
        "Team Sherlocked  -  Leading University, Sylhet\n\n"
        "Covers: final, const, override, Future<void>, super.key, inheritance,\n"
        "polymorphism, static, try/catch/finally, error handling,\n"
        "main.dart initialization, and the complete navigation system."),
    0, "C")

# ============================================================
# PART 1 - CORE LANGUAGE CONCEPTS
# ============================================================
pdf.add_page()
h1("PART 1  -  Dart / Flutter Concept Questions")

body("Each concept below gives a short definition, a real code reference taken "
     "directly from the UniVerse codebase (with the file it lives in), and a plain "
     "explanation of how it is used in the app.")

# ---- final ----
h2("1.  final")
body("A 'final' variable can be assigned only ONCE. After that first assignment its "
     "value cannot change. It is assigned at RUNTIME, so its value can be computed "
     "while the app is running (e.g. a value that comes from the database or "
     "Supabase.instance.client). 'final' freezes the variable (the reference), not "
     "necessarily the object's internal fields.")
h3("Code reference - lib/features/teacher/services/teacher_service.dart")
code(
"class TeacherService {\n"
"  // Assigned ONCE at runtime - the value is fetched from the\n"
"  // running Supabase instance, so it cannot be 'const'.\n"
"  final SupabaseClient _supabase = Supabase.instance.client;\n"
"  final NotificationService _notifications = NotificationService();\n"
"}")
body("Here _supabase and _notifications are created when a TeacherService object is "
     "built. They never get reassigned, so 'final' both documents that intent and "
     "lets the compiler enforce it. They cannot be 'const' because the values are "
     "produced at runtime, not known at compile time.")

# ---- const ----
h2("2.  const")
body("A 'const' value is a COMPILE-TIME constant - it must be fully known before the "
     "app runs. 'const' is stronger than 'final': the object and everything inside it "
     "is deeply frozen, and Dart 'canonicalizes' it (identical const values share a "
     "single object in memory, which is faster and saves memory). Widgets marked "
     "'const' are skipped during rebuilds, which is a real performance win in Flutter.")
h3("Code reference - lib/core/router/route_names.dart")
code(
"abstract class RouteNames {\n"
"  // Known at compile time -> declared const. These strings never\n"
"  // change, so the compiler can lock and reuse them everywhere.\n"
"  static const String splash = '/';\n"
"  static const String studentDashboard = '/student/dashboard';\n"
"  static const String findTeacher = '/find-teacher';\n"
"}")
h3("Code reference - const widget constructors (used app-wide)")
code(
"// lib/core/router/app_router.dart\n"
"GoRoute(path: RouteNames.rooms, builder: (c, s) => const RoomsScreen()),\n"
"GoRoute(path: RouteNames.manageUsers,\n"
"        builder: (c, s) => const ManageUsersScreen()),")
body("Because RoomsScreen takes no changing inputs, it is built as 'const'. Flutter "
     "reuses the same widget instance and skips rebuilding it, improving performance.")

# ---- const vs final (the highlighted question) ----
h2("3.  const vs final  +  \"what if I use final instead of const?\"")
body("KEY DIFFERENCE: const is fixed at COMPILE TIME (before the program runs); final "
     "is fixed at RUNTIME (once, when the line executes).")
bullet("const  ->  value must be known when the code is compiled; deeply immutable; "
       "canonicalized (shared in memory); usable in places that REQUIRE a constant.")
bullet("final  ->  value is computed while running, assigned exactly once; the "
       "reference can't change, but the object's internals still can.")
h3("Worked example")
code(
"const String appName = 'UniVerse';        // OK: literal known at compile time\n"
"final DateTime now = DateTime.now();      // OK: value only known at RUNTIME\n"
"\n"
"// const DateTime now = DateTime.now();   // COMPILE ERROR\n"
"// DateTime.now() runs at runtime, so it can never be const.")
h3("The exam question: \"if I write final instead of const, will it CRASH?\"")
body("No - it will NOT crash. Replacing 'const' with 'final' almost always still "
     "compiles and runs correctly. 'final' is simply less strict than 'const'. What "
     "you lose is the compile-time guarantee and the optimizations, NOT correctness.")
body("There are only two situations to remember:")
bullet("Going from const to final (relaxing): safe. e.g. 'final splash = \"/\";' works "
       "just like 'const splash = \"/\";' - no crash, you only lose canonicalization "
       "and the const-widget rebuild optimization.")
bullet("Going from final to const (tightening): this is where you get a COMPILE-TIME "
       "ERROR (not a runtime crash) if the value isn't known at compile time - e.g. "
       "trying to make 'const x = Supabase.instance.client;' const. The compiler "
       "refuses to build; the app never even launches, so it can't 'crash' at runtime.")
body("Bottom line: a crash is a runtime failure. const/final mistakes are caught by "
     "the COMPILER first, so the usual outcome is 'won't compile', not 'crashes while "
     "running'. Using 'final' where 'const' was possible is legal and safe - it just "
     "misses an optimization.")
h3("Why it matters in this app")
body("In RouteNames every path is 'const' because the strings are fixed forever. If we "
     "wrote 'final' instead, the app would still run identically, but we'd lose the "
     "ability to use those values inside other 'const' expressions (like 'const "
     "authPages = [RouteNames.splash, ...]' in app_router.dart, which REQUIRES its "
     "elements to be compile-time constants).")

# ---- override ----
pdf.add_page()
h2("4.  @override")
body("'@override' is an annotation that tells Dart (and the reader) that this method "
     "is intentionally REPLACING a method inherited from a parent class or interface. "
     "It is not required to compile, but it makes the compiler verify that a method "
     "with that exact name/signature really exists in the parent - catching typos.")
h3("Code reference - lib/main.dart")
code(
"class UniVerseApp extends StatelessWidget {\n"
"  final AppRouter router;\n"
"  const UniVerseApp({super.key, required this.router});\n"
"\n"
"  @override                       // replaces StatelessWidget.build\n"
"  Widget build(BuildContext context) {\n"
"    return MaterialApp.router(\n"
"      title: AppConstants.appName,\n"
"      theme: AppTheme.dark,\n"
"      routerConfig: router.router,\n"
"    );\n"
"  }\n"
"}")
body("Every Flutter widget overrides build(). State classes override initState() and "
     "dispose(); controllers (ChangeNotifier subclasses) are used through overridden "
     "lifecycle hooks. See app_shell.dart below for initState/dispose overrides.")
code(
"// lib/core/router/app_shell.dart\n"
"class _AppShellState extends State<AppShell> {\n"
"  @override\n"
"  void initState() {\n"
"    super.initState();\n"
"    widget.notificationController.startRealtime();\n"
"  }\n"
"\n"
"  @override\n"
"  void dispose() {\n"
"    widget.authController.removeListener(_onAuthChanged);\n"
"    super.dispose();\n"
"  }\n"
"}")

# ---- Future<void> ----
h2("5.  Future<void>")
body("A 'Future' represents a value that will be available LATER - the result of an "
     "asynchronous operation (network call, database query, file read). 'Future<T>' "
     "completes with a value of type T. 'Future<void>' means the async work completes "
     "but returns NO value - you await it only for its side effect (e.g. an insert "
     "finishing), not for data coming back.")
h3("Code reference - lib/features/teacher/services/teacher_service.dart")
code(
"// Returns nothing; we await it only to know the insert + alert finished.\n"
"Future<void> cancelClass({\n"
"  required RoutineEntry entry,\n"
"  required DateTime date,\n"
"  required String reason,\n"
"  required String userId,\n"
"}) async {\n"
"  await _supabase.from(AppConstants.tableCancellations).insert({\n"
"    'routine_id': entry.id,\n"
"    'class_date': dateKey(date),\n"
"    'cancelled_by': userId,\n"
"  });\n"
"  await _notifications.createBroadcast(/* ... */);\n"
"}")
body("Contrast with a Future that DOES return data - e.g. the rooms controller fetches "
     "a list:")
code(
"// lib/features/rooms/controllers/rooms_controller.dart\n"
"Future<void> fetchRoomStatuses() async {     // void: just updates state\n"
"  _allRoutines = await _service.fetchAllRoutines();  // Future<List<...>>\n"
"  notifyListeners();\n"
"}")
body("'async' marks a function that contains 'await'; an async function ALWAYS returns "
     "a Future. 'await' pauses inside the function until the Future completes, without "
     "freezing the whole app.")

# ---- super.key ----
pdf.add_page()
h2("6.  super.key")
body("In Flutter every widget can take an optional 'Key'. A Key helps Flutter tell "
     "widgets apart when the widget tree rebuilds, so it can preserve state correctly. "
     "'super.key' is modern Dart shorthand: it forwards the 'key' argument straight up "
     "to the parent (super) class constructor (StatelessWidget / StatefulWidget) "
     "instead of writing 'Key? key' and ': super(key: key)' by hand.")
h3("Code reference - lib/shared/widgets/explore_fab_menu.dart")
code(
"class ExploreFabMenu extends StatelessWidget {\n"
"  // 'super.key' passes the key up to StatelessWidget's constructor.\n"
"  const ExploreFabMenu({super.key});\n"
"  // ...\n"
"}")
h3("Code reference - widget with its own fields + super.key")
code(
"// lib/core/router/app_shell.dart\n"
"class AppShell extends StatefulWidget {\n"
"  final AuthController authController;\n"
"  final NotificationController notificationController;\n"
"  final Widget child;\n"
"\n"
"  const AppShell({\n"
"    super.key,                       // forwarded to StatefulWidget\n"
"    required this.authController,\n"
"    required this.notificationController,\n"
"    required this.child,\n"
"  });\n"
"}")
body("Before super-parameters, the same code was: 'const AppShell({Key? key, ...}) : "
     "super(key: key);'. 'super.key' is just a cleaner way to write that. Notice these "
     "constructors are also 'const' (Concept 2) because their fields are 'final'.")

# ---- Inheritance ----
h2("7.  Inheritance")
body("Inheritance lets a class REUSE and EXTEND another class using the 'extends' "
     "keyword. The child (subclass) gets all the fields and methods of the parent "
     "(superclass) and can add its own or replace existing ones (override). It models "
     "an 'is-a' relationship.")
h3("Code reference - the whole app is built on inheritance")
code(
"// lib/main.dart\n"
"class UniVerseApp extends StatelessWidget { ... }   // is-a Widget\n"
"\n"
"// lib/core/router/app_shell.dart\n"
"class AppShell extends StatefulWidget { ... }       // is-a Widget\n"
"class _AppShellState extends State<AppShell> { ... } // is-a State\n"
"\n"
"// lib/features/rooms/controllers/rooms_controller.dart\n"
"class RoomsController extends ChangeNotifier { ... } // is-a ChangeNotifier")
body("RoomsController 'extends ChangeNotifier', so it inherits notifyListeners(), "
     "addListener(), removeListener() for free - we never wrote those; we only call "
     "them. That inherited behaviour is exactly how the UI is told to rebuild. "
     "RouteNames uses 'abstract class' (a class never meant to be instantiated, only a "
     "namespace of constants) - another piece of the same class system.")

# ---- Polymorphism ----
pdf.add_page()
h2("8.  Polymorphism (types)  +  9. method override = which polymorphism?")
body("Polymorphism = 'many forms': the same call behaves differently depending on the "
     "actual object/type behind it. Dart (like most OOP languages) has two kinds:")
h3("(a) Compile-time / static polymorphism")
bullet("Achieved by method OVERLOADING and/or generics + operator behaviour. The "
       "compiler decides which form to use. NOTE: Dart does NOT support classic method "
       "overloading (two methods with the same name, different parameters); it uses "
       "optional/named parameters and GENERICS instead. e.g. Future<void> vs "
       "Future<List<RoutineEntry>> - the same 'Future' type takes many forms via the "
       "generic <T>.")
h3("(b) Run-time / dynamic polymorphism")
bullet("Achieved by method OVERRIDING with inheritance. The decision of WHICH build() "
       "or WHICH toString() runs is made at RUN TIME based on the real object type. "
       "This is the form Flutter relies on constantly.")
h3("DIRECT ANSWER: method override is RUN-TIME (dynamic) polymorphism.")
body("When you override a method, the parent type's reference can point to any "
     "subclass, and the OVERRIDDEN version runs at run time. This is also called "
     "'dynamic dispatch'.")
h3("Code reference - run-time polymorphism via override")
code(
"// Flutter calls build() on a Widget reference, but the OVERRIDDEN\n"
"// build() of the real subclass runs at runtime - dynamic dispatch.\n"
"\n"
"// lib/main.dart\n"
"class UniVerseApp extends StatelessWidget {\n"
"  @override Widget build(BuildContext c) => MaterialApp.router(...);\n"
"}\n"
"// lib/shared/widgets/explore_fab_menu.dart\n"
"class ExploreFabMenu extends StatelessWidget {\n"
"  @override Widget build(BuildContext c) => FloatingActionButton(...);\n"
"}")
body("Both are 'a Widget', both respond to build(), but each produces a DIFFERENT UI - "
     "the same method call, many forms. That is run-time polymorphism in action, and "
     "it is enabled by '@override' (Concept 4) on top of inheritance (Concept 7).")
h3("Code reference - generics (compile-time polymorphism)")
code(
"// One generic factory shape reused for any type the column holds:\n"
"// lib/core/models/routine_model.dart\n"
"factory RoutineEntry.fromMap(Map<String, dynamic> map) => RoutineEntry(\n"
"  semester: (map['semester'] as int?) ?? 0,\n"
"  isActive: (map['is_active'] as bool?) ?? true,\n"
");\n"
"// List<RoutineEntry>, Set<String>, Future<void> - 'many forms' of\n"
"// the same container types, resolved by the compiler.")

# ---- static ----
pdf.add_page()
h2("10.  static")
body("'static' members belong to the CLASS ITSELF, not to any single object (instance) "
     "of it. You access them through the class name without creating an object. Use "
     "static for shared constants and pure helper functions that don't depend on "
     "instance data.")
h3("Code reference - static constants (route names)")
code(
"// lib/core/router/route_names.dart - access as RouteNames.splash\n"
"abstract class RouteNames {\n"
"  static const String splash = '/';\n"
"  static const String studentDashboard = '/student/dashboard';\n"
"}")
h3("Code reference - static helper method (no object needed)")
code(
"// lib/features/teacher/services/teacher_service.dart\n"
"// Called as TeacherService.dateKey(DateTime.now()) - pure, no state.\n"
"static String dateKey(DateTime d) =>\n"
"    '${d.year.toString().padLeft(4, '0')}-'\n"
"    '${d.month.toString().padLeft(2, '0')}-'\n"
"    '${d.day.toString().padLeft(2, '0')}';")
h3("Code reference - static factory list (the nav menu)")
code(
"// lib/shared/widgets/app_bottom_nav.dart\n"
"// Single source of truth for each role's tabs - belongs to the\n"
"// class, not an instance, so it is 'static'.\n"
"static List<AppNavDest> destinationsFor(String? role) {\n"
"  switch (role) {\n"
"    case AppConstants.roleAdmin:   return const [ /* admin tabs */ ];\n"
"    case AppConstants.roleTeacher: return const [ /* teacher tabs */ ];\n"
"    default:                       return const [ /* student tabs */ ];\n"
"  }\n"
"}")
body("Contrast: _supabase in TeacherService is an INSTANCE field (each service object "
     "has its own), while dateKey() is static (one shared function for the whole "
     "class). A static method cannot read instance fields because no object is "
     "involved when it runs.")

# ---- try/catch/finally ----
pdf.add_page()
h2("11.  try / catch / finally  +  error handling")
body("This is Dart's structured way to deal with errors so the app does not crash:")
bullet("try    -> wrap the risky code that might throw an error/exception.")
bullet("catch  -> runs ONLY if something inside try threw; here you handle/report the "
       "error (the caught error object is usually named 'e').")
bullet("finally -> ALWAYS runs afterwards, whether or not an error was thrown. Ideal "
       "for cleanup (closing things, turning a loading flag off).")
h3("Code reference - try / typed-catch in the app")
code(
"// lib/features/teacher/services/teacher_service.dart\n"
"try {\n"
"  await _supabase.from(AppConstants.tableCancellations).insert({...});\n"
"  await _notifications.createBroadcast(/* ... */);\n"
"} on PostgrestException catch (e) {\n"
"  // Surface the REAL DB / RLS reason instead of a generic failure.\n"
"  throw Exception(e.message);\n"
"}")
body("'on PostgrestException catch (e)' catches ONLY that specific Supabase error type "
     "- this is targeted error handling: the error object 'e' carries the database's "
     "real message (e.g. a row-level-security rejection), which we re-throw so the UI "
     "can show a meaningful message.")
h3("Code reference - try/catch driving UI state safely")
code(
"// lib/features/rooms/controllers/rooms_controller.dart\n"
"Future<void> fetchRoomStatuses() async {\n"
"  try {\n"
"    _isLoading = true; _error = null; notifyListeners();\n"
"    _allRoutines = await _service.fetchAllRoutines();\n"
"    // ... build statuses ...\n"
"    _isLoading = false; notifyListeners();\n"
"  } catch (e) {\n"
"    _error = e.toString();   // store message, show error UI\n"
"    _isLoading = false;      // never get stuck on a spinner\n"
"    notifyListeners();\n"
"  }\n"
"}")
body("Note on 'finally': UniVerse currently turns off _isLoading in BOTH the success "
     "path and the catch block (as above) rather than using a 'finally' clause. The "
     "cleaner, equivalent pattern is to put that single cleanup line in 'finally' so "
     "it can never be forgotten:")
code(
"Future<void> fetchRoomStatuses() async {\n"
"  try {\n"
"    _isLoading = true; notifyListeners();\n"
"    _allRoutines = await _service.fetchAllRoutines();\n"
"  } catch (e) {\n"
"    _error = e.toString();        // runs only on failure\n"
"  } finally {\n"
"    _isLoading = false;           // ALWAYS runs - success OR failure\n"
"    notifyListeners();\n"
"  }\n"
"}")
body("CONCEPT SUMMARY (as asked): an error is raised inside 'try'; 'catch (e)' handles "
     "it; 'finally' runs no matter what. And tying back to Concept 3 - 'const is fixed "
     "at compile time, final is fixed once at run time'.")

# ============================================================
# PART 2 - MAIN.DART INITIALIZATION
# ============================================================
pdf.add_page()
h1("PART 2  -  How main.dart Initializes Everything & Connects the App")

body("main.dart (lib/main.dart) is the single entry point. Flutter calls main() first. "
     "It wires together every major subsystem in a strict order, then hands control to "
     "the router. Below is the real file, broken into its initialization steps.")

h2("Step 0 - Bindings")
code(
"void main() async {\n"
"  WidgetsFlutterBinding.ensureInitialized();   // must be first\n")
body("ensureInitialized() prepares the Flutter engine before we call any native "
     "plugins (Firebase, Supabase). Without it, plugin setup would fail.")

h2("Step 1 - System UI theming")
code(
"  AppTheme.setSystemUI();   // from lib/core/theme/app_theme.dart")
body("Connects to core/theme: sets a transparent status bar with light icons so the "
     "dark theme looks right from the very first frame.")

h2("Step 2 - Firebase + Push (mobile only)")
code(
"  if (!kIsWeb) {\n"
"    await Firebase.initializeApp(\n"
"      options: DefaultFirebaseOptions.currentPlatform, // firebase_options.dart\n"
"    );\n"
"    await PushService.instance.init();   // core/services/push_service.dart\n"
"  }")
body("Connects to firebase_options.dart (generated config) and core/services/"
     "push_service.dart. Guarded by '!kIsWeb' because the project has no web Firebase "
     "config - calling it on web would throw and kill startup.")

h2("Step 3 - Supabase backend")
code(
"  await Supabase.initialize(\n"
"    url: AppConstants.supabaseUrl,         // core/constants/app_constants.dart\n"
"    anonKey: AppConstants.supabaseAnonKey,\n"
"    authOptions: const FlutterAuthClientOptions(\n"
"      authFlowType: AuthFlowType.pkce,     // secure OAuth flow for mobile\n"
"    ),\n"
"  );")
body("Connects to core/constants/app_constants.dart for the URL + anon key. After this "
     "line, every service in features/.../services can use Supabase.instance.client "
     "(that is the 'final _supabase' field we saw in TeacherService).")

h2("Step 4 - Controllers & Router")
code(
"  final authController = AuthController();                  // features/auth\n"
"  final appRouter = AppRouter(authController: authController); // core/router")
body("AuthController (a ChangeNotifier) holds the auth state. It is injected into "
     "AppRouter, which uses it as 'refreshListenable' so navigation reacts to "
     "login/logout automatically (see Part 3).")

pdf.add_page()
h2("Step 5 - Push tap + OAuth deep-link wiring")
code(
"  if (!kIsWeb) {\n"
"    PushService.instance.onNotificationTap =\n"
"        (_) => appRouter.router.go(RouteNames.notifications);\n"
"  }\n"
"\n"
"  AuthService().authStateChanges.listen((event) async {\n"
"    if (event.event == AuthChangeEvent.signedIn) {\n"
"      if (authController.status != AuthStatus.authenticated &&\n"
"          !authController.isLoading) {\n"
"        await authController.handleOAuthCallback();\n"
"      }\n"
"      final userId = event.session?.user.id;\n"
"      if (!kIsWeb && userId != null) {\n"
"        unawaited(PushService.instance.registerToken(userId));\n"
"      }\n"
"    } else if (event.event == AuthChangeEvent.passwordRecovery) {\n"
"      appRouter.router.go(RouteNames.resetPassword);\n"
"    }\n"
"  });")
body("This is the glue between three features: AuthService (auth), PushService "
     "(notifications), and the router. When Google OAuth completes, Supabase fires "
     "'signedIn'; the listener resolves the session and saves the device's FCM token "
     "(fire-and-forget via 'unawaited', so navigation is never blocked).")

h2("Step 6 - Launch the app")
code(
"  runApp(UniVerseApp(router: appRouter));\n"
"}\n"
"\n"
"class UniVerseApp extends StatelessWidget {\n"
"  final AppRouter router;\n"
"  const UniVerseApp({super.key, required this.router});\n"
"  @override\n"
"  Widget build(BuildContext context) {\n"
"    return MaterialApp.router(\n"
"      title: AppConstants.appName,\n"
"      debugShowCheckedModeBanner: false,\n"
"      theme: AppTheme.dark,              // core/theme\n"
"      routerConfig: router.router,       // core/router -> all screens\n"
"    );\n"
"  }\n"
"}")
body("runApp() mounts the root widget. MaterialApp.router hands navigation entirely to "
     "GoRouter via routerConfig. From here on, the router decides which screen shows.")

h3("How main.dart connects to the folders (summary)")
bullet("core/theme  -> AppTheme.setSystemUI(), AppTheme.dark (look & feel).")
bullet("core/constants -> AppConstants (Supabase keys, app name, table names).")
bullet("core/services -> PushService (FCM token + tap handling).")
bullet("core/router -> AppRouter + RouteNames (the entire navigation graph).")
bullet("features/auth -> AuthController + AuthService (who is logged in).")
bullet("firebase_options.dart -> generated Firebase config for Android.")
bullet("Every features/.../services file -> uses the Supabase client that main() "
       "initialized in Step 3.")

# ============================================================
# PART 3 - NAVIGATION SYSTEM
# ============================================================
pdf.add_page()
h1("PART 3  -  The Complete Navigation System")

body("UniVerse uses GoRouter (declarative routing). There is exactly ONE router, built "
     "in core/router/app_router.dart and handed to MaterialApp.router in main.dart. "
     "Screens NEVER use MaterialPageRoute - they call context.go(...) / context.push("
     "...) with a constant from RouteNames. The system has four parts:")
bullet("1. RouteNames  - every path as a const string (one source of truth).")
bullet("2. AppRouter   - the GoRouter: route table + auth redirect guard.")
bullet("3. AppShell + AppBottomNav - the tab frame for top-level screens.")
bullet("4. Screens     - call context.go / context.push to move around.")

h2("Part A - Route names (core/router/route_names.dart)")
code(
"abstract class RouteNames {\n"
"  static const String splash = '/';\n"
"  static const String login = '/login';\n"
"  static const String studentDashboard = '/student/dashboard';\n"
"  static const String teacherDashboard = '/teacher/dashboard';\n"
"  static const String adminDashboard   = '/admin/dashboard';\n"
"  static const String rooms       = '/rooms';\n"
"  static const String findTeacher = '/find-teacher';\n"
"  // ...all other paths...\n"
"}")
body("Because these are 'const', they can be reused inside other const lists (like the "
     "redirect guard's authPages) and the compiler guarantees no typo'd path string.")

h2("Part B - The router + redirect guard (core/router/app_router.dart)")
body("AppRouter wraps a GoRouter. 'refreshListenable: authController' means: every "
     "time auth state changes, GoRouter re-runs its redirect logic. The redirect is "
     "the security gate - it decides if the user is ALLOWED on the requested page.")
code(
"late final GoRouter router = GoRouter(\n"
"  initialLocation: RouteNames.splash,\n"
"  refreshListenable: authController,        // re-check on login/logout\n"
"  redirect: (context, state) async {\n"
"    final status = authController.status;\n"
"    final location = state.matchedLocation;\n"
"\n"
"    if (status == AuthStatus.unauthenticated) {\n"
"      return authPages.contains(location) ? null : RouteNames.login;\n"
"    }\n"
"    if (status == AuthStatus.authenticated) {\n"
"      if (authPages.contains(location))\n"
"        return _dashboardForRole(authController.role);\n"
"      if (_isWrongRolePage(location, authController.role))\n"
"        return _dashboardForRole(authController.role);\n"
"    }\n"
"    return null;   // null = allow the navigation\n"
"  },\n"
"  routes: [ /* see Part C + D */ ],\n"
");")
body("Returning a path = redirect there; returning null = allow. _isWrongRolePage() "
     "blocks a student from ever opening an /admin or /teacher URL, sending them back "
     "to their own dashboard. This is why screens can navigate freely - the guard is "
     "the safety net.")
code(
"String _dashboardForRole(String? role) {\n"
"  switch (role) {\n"
"    case 'teacher': return RouteNames.teacherDashboard;\n"
"    case 'admin':   return RouteNames.adminDashboard;\n"
"    default:        return RouteNames.studentDashboard;\n"
"  }\n"
"}")

pdf.add_page()
h2("Part C - ShellRoute: the tabbed area")
body("Top-level tab screens are wrapped in a ShellRoute. The ShellRoute builds ONE "
     "AppShell (one Scaffold + one bottom nav) and injects each tab screen as 'child'. "
     "This is why the bottom nav stays put while tabs change.")
code(
"ShellRoute(\n"
"  builder: (c, s, child) => AppShell(\n"
"    authController: authController,\n"
"    notificationController: notificationController,\n"
"    child: child,                     // the active tab screen\n"
"  ),\n"
"  routes: [\n"
"    GoRoute(path: RouteNames.studentDashboard,\n"
"            builder: (c, s) => StudentDashboardScreen(...)),\n"
"    GoRoute(path: RouteNames.studentRoutine,\n"
"            builder: (c, s) => RoutineScreen(authController: authController)),\n"
"    GoRoute(path: RouteNames.teacherDashboard,\n"
"            builder: (c, s) => TeacherDashboardScreen(...)),\n"
"    GoRoute(path: RouteNames.adminDashboard,\n"
"            builder: (c, s) => AdminDashboardScreen(...)),\n"
"    // ...other tab routes...\n"
"  ],\n"
")")
h3("Secondary screens are OUTSIDE the shell (pushed, with a back button)")
code(
"// Top-level (not tabs) -> no bottom nav, uses back button\n"
"GoRoute(path: RouteNames.rooms,       builder: (c,s) => const RoomsScreen()),\n"
"GoRoute(path: RouteNames.findTeacher, builder: (c,s) => const FindTeacherScreen()),\n"
"GoRoute(path: RouteNames.timetableGrid,\n"
"  builder: (c, s) => TimetableGridScreen(\n"
"    rows: (s.extra as List<RoutineEntry>?) ?? const [],  // pass data via extra\n"
"  )),")
body("Note 's.extra' - GoRouter's way to pass an object (here a list of routine rows) "
     "to the next screen without putting it in the URL.")

h2("Part D - AppShell + AppBottomNav (the tab frame)")
body("AppShell (core/router/app_shell.dart) owns the single Scaffold. It reads the "
     "current location from GoRouter to (a) highlight the right tab and (b) show the "
     "Explore FAB only on the three dashboards.")
code(
"// lib/core/router/app_shell.dart  (inside build)\n"
"final location = GoRouterState.of(context).matchedLocation;\n"
"return Scaffold(\n"
"  body: widget.child,\n"
"  floatingActionButton: (location == '/student/dashboard' ||\n"
"          location == '/teacher/dashboard' ||\n"
"          location == '/admin/dashboard')\n"
"      ? const ExploreFabMenu() : null,\n"
"  bottomNavigationBar: AppBottomNav(\n"
"    role: widget.authController.role,        // chooses the tab set\n"
"    currentRoute: location,                  // highlights active tab\n"
"    unreadNotifCount: widget.notificationController.unreadCount,\n"
"  ),\n"
");")

pdf.add_page()
body("AppBottomNav (shared/widgets/app_bottom_nav.dart) picks the tab set by role via "
     "the static destinationsFor(role), then navigates on tap with context.go():")
code(
"// shared/widgets/app_bottom_nav.dart\n"
"final dests = destinationsFor(role);              // role-aware tabs\n"
"var currentIndex = dests.indexWhere((d) => d.route == currentRoute);\n"
"if (currentIndex < 0) currentIndex = 0;\n"
"\n"
"return UBottomNav(\n"
"  items: [for (final d in dests) UNavItem(icon: d.icon, label: d.label)],\n"
"  currentIndex: currentIndex,\n"
"  onTap: (i) {\n"
"    final route = dests[i].route;\n"
"    if (route == currentRoute) return;   // ignore tapping the current tab\n"
"    context.go(route);                   // <-- the actual tab switch\n"
"  },\n"
");")

h2("Part E - go vs push (when each is used)")
bullet("context.go(route)  -> REPLACES the current location. Used for switching tabs "
       "and for role dashboards (you don't want a back-stack between tabs).")
bullet("context.push(route) -> PUSHES on top (adds a back button). Used for secondary "
       "screens like Rooms, Find Teacher, Admin Registration, Manage Resources.")
bullet("Navigator.pop(context) -> closes a pushed screen or a bottom sheet/dialog.")

h3("Real UI usage - tab/dashboard navigation with go()")
code(
"// lib/features/dashboard/screens/student_dashboard_screen.dart\n"
"onTap: () => context.go(RouteNames.studentRoutine),   // go to Routine tab\n"
"onTap: () => context.go(RouteNames.resources),        // go to Resources\n"
"onTap: () => context.go(RouteNames.profile),          // go to Profile\n"
"\n"
"// lib/features/admin/screens/admin_dashboard_screen.dart\n"
"onTap: () =>\n"
"  context.go('${RouteNames.routineManagement}?tab=generate'),  // query param")

h3("Real UI usage - secondary screens with push() + the Explore FAB")
code(
"// lib/shared/widgets/explore_fab_menu.dart\n"
"onTap: () {\n"
"  Navigator.pop(context);              // close the bottom sheet first\n"
"  context.push(RouteNames.rooms);      // push Room Availability (back btn)\n"
"},\n"
"onTap: () {\n"
"  Navigator.pop(context);\n"
"  context.push(RouteNames.findTeacher);\n"
"},\n"
"\n"
"// lib/features/admin/screens/admin_dashboard_screen.dart\n"
"onTap: () => context.push(RouteNames.adminRegistration),\n"
"onTap: () => context.push(RouteNames.manageResources),\n"
"\n"
"// lib/features/admin/screens/generate_timetable_screen.dart\n"
"context.push(RouteNames.timetableGrid, extra: result.rows); // push + data")

h2("Navigation flow - end to end")
body("1) App launches -> main.dart -> MaterialApp.router uses GoRouter, starting at "
     "RouteNames.splash.\n"
     "2) AuthController resolves the session; because it is the router's "
     "refreshListenable, GoRouter re-runs redirect().\n"
     "3) redirect() routes by status: not logged in -> /login; logged in -> the "
     "role's dashboard; wrong-role URL -> bounced back.\n"
     "4) Inside the app, ShellRoute shows AppShell with the role's bottom nav; tapping "
     "a tab calls context.go(...).\n"
     "5) Buttons/cards open secondary screens with context.push(...); the FAB opens a "
     "bottom sheet that pushes Rooms / Find Teacher.\n"
     "6) Back button or Navigator.pop() returns from pushed screens. The redirect "
     "guard keeps every transition role-safe.")

# ---- output ----
out = r"d:\flutter projects\universe_v1\UniVerse_Concepts_Answers.pdf"
pdf.output(out)
print("WROTE:", out)
