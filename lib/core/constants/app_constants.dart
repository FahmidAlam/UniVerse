// ============================================================
// FILE: lib/core/constants/app_constants.dart
// PURPOSE: App-wide constants — Supabase config, semester list,
// day names, slot times, and other shared fixed values.
//
// CONFIG VIA ENV: secrets/URLs come from --dart-define so real keys
// don't have to live in source. Run with:
//   flutter run --dart-define-from-file=dart_defines.json
// Each value falls back to a working default when no define is passed,
// so a plain `flutter run` still works for the team. Copy
// dart_defines.example.json → dart_defines.json (gitignored) and fill
// in real values; never commit the service-role key (it stays in the
// invite-admin Edge Function, never in the app).
// ============================================================

abstract class AppConstants {
  // ─── Supabase ─────────────────────────────────────────────
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://yxqyrjyzxitrgkhgauli.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl4cXlyanl6eGl0cmdraGdhdWxpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk0NzM2OTYsImV4cCI6MjA5NTA0OTY5Nn0.smtNEPQrag9yETZXdA2UqqCmxu_fjmGG8K4Vbot2O-w',
  );

  // ─── Gemini ───────────────────────────────────────────────
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: 'YOUR_GEMINI_API_KEY',
  );
  static const String embeddingModel = 'text-embedding-004';
  static const String generationModel = 'gemini-2.0-flash';

  // ─── Timetable Engine (FastAPI + OR-Tools) ────────────────
  // Defaults to the deployed engine on Render so a plain release APK
  // works out of the box. For local engine dev, override with:
  //   --dart-define=TIMETABLE_BASE_URL=http://10.0.2.2:8000   (emulator)
  static const String timetableBaseUrl = String.fromEnvironment(
    'TIMETABLE_BASE_URL',
    defaultValue: 'https://universe-timetable-engine.onrender.com',
  );

  // ─── App Identity ─────────────────────────────────────────
  static const String appName     = 'UniVerse';
  static const String appSubtitle = 'A Campus Companion';
  static const String university  = 'Leading University, Sylhet';
  static const String department  = 'Computer Science and Engineering';
  static const String course      = 'CSE-3240 · Project I';
  static const String teamName    = 'Team Sherlocked';

  // ─── Credits (About dialog) ───────────────────────────────
  // Supervisor + the development team, shown in Profile → About.
  static const String supervisorName  = 'Md. Jamaner Rahaman';
  static const String supervisorRole  = 'Assistant Professor, Leading University';
  static const String supervisorTitle = 'Supervisor';

  /// Development team, in student-ID order. `(name, id)` pairs.
  static const List<({String name, String id})> developers = [
    (name: 'Fahmid Alam',          id: '0182320012101309'),
    (name: 'Swadheen Islam Robi',  id: '0182320012101278'),
    (name: 'Shahriar Rashid Ratul', id: '0182320012101276'),
  ];

  // ─── User Roles ───────────────────────────────────────────
  static const String roleStudent = 'student';
  static const String roleTeacher = 'teacher';
  static const String roleAdmin   = 'admin';

  // ─── Semesters ────────────────────────────────────────────
  static const List<int> semesters = [1, 2, 3, 4, 5, 6, 7, 8];

  // ─── Days (Sun–Sat) ───────────────────────────────────────
  // Leading University runs classes across all 7 days (Friday has no
  // period 4 — see timetable engine). Order matches engine config.json
  // "days", so routine `day` text lines up with what the engine emits.
  static const List<String> weekDays = [
    'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
  ];

  static const List<String> weekDaysShort = [
    'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat',
  ];

  // ─── Time Slots ───────────────────────────────────────────
  static const List<String> timeSlots = [
    '9:30 AM – 10:50 AM',
    '10:50 AM – 12:10 PM',
    '12:10 PM – 1:30 PM',
    '2:10 PM – 3:30 PM',
    '3:30 PM – 4:50 PM',
  ];

  // ─── Notification Types ───────────────────────────────────
  static const String notifUniversity  = 'university';
  static const String notifClassCancel = 'class_cancel';
  static const String notifRoomChange  = 'room_change';
  static const String notifTestReminder = 'test_reminder';
  static const String notifAssignment  = 'assignment';
  static const String notifExam        = 'exam';

  // ─── Resource Categories ──────────────────────────────────
  static const List<String> resourceCategories = [
    'All', 'PYQ', 'Notes', 'Slides', 'Assignments',
  ];

  // ─── Departments ──────────────────────────────────────────
  static const List<String> departments = [
    'CSE', 'EEE', 'BBA', 'English', 'GED', 'CE', 'Law',
  ];

  // ─── Designations ─────────────────────────────────────────
  static const List<String> designations = [
    'Professor',
    'Associate Professor',
    'Assistant Professor',
    'Senior Lecturer',
    'Lecturer',
  ];

  // ─── SharedPreferences Keys ───────────────────────────────
  static const String prefOnboardingDone = 'onboarding_done';
  static const String prefUserRole       = 'user_role';

  // ─── Supabase Table Names ─────────────────────────────────
  static const String tableWhitelists       = 'whitelists';
  static const String tableProfiles         = 'profiles';
  static const String tableRoutines         = 'routines';
  static const String tableCancellations    = 'cancellations';
  static const String tableNotifications    = 'notifications';
  static const String tableNotificationReads = 'notification_reads';
  static const String tableResources        = 'resources';
  // Reserved for future scope — tables exist (RLS-protected) but no
  // feature is wired yet: assignments/submissions (assignment feature),
  // documents (AI assistant).
  static const String tableAssignments      = 'assignments';
  static const String tableSubmissions      = 'submissions';
  static const String tableDocuments        = 'documents';
  static const String tableDeviceTokens     = 'device_tokens';
  static const String tableTimetableRooms    = 'timetable_rooms';
  static const String tableTimetableFaculty  = 'timetable_faculty';
  static const String tableTimetableSettings = 'timetable_settings';
  static const String tableTimetableRuns     = 'timetable_runs';

  // ─── Storage Buckets ──────────────────────────────────────
  static const String bucketResources   = 'resources';
  static const String bucketTimetables  = 'timetables';
  // Reserved for future scope (buckets exist; no upload path wired yet).
  static const String bucketAvatars     = 'avatars';
  static const String bucketSubmissions = 'submissions';

  // ─── Push Notifications (FCM) ─────────────────────────────
  // Channel id MUST match AndroidManifest's default_notification_channel_id.
  static const String pushChannelId   = 'universe_high_importance';
  static const String pushChannelName = 'UniVerse Alerts';
  static const String pushChannelDesc =
      'Class cancellations, room changes, and campus announcements.';

  // ─── RAG ──────────────────────────────────────────────────
  static const int embeddingDimension = 768;
  static const int ragMatchCount      = 3;
  static const String rpcMatchDocuments = 'match_documents';

  // ─── AI Suggested Questions ───────────────────────────────
  static const List<String> suggestedQuestions = [
    'When is my DSA class?',
    'Who teaches Operating Systems?',
    'What is my Friday schedule?',
    'Is Thursday Math class cancelled?',
    'What rooms are available now?',
    'Show me Batch 62 Section G routine',
  ];
}
