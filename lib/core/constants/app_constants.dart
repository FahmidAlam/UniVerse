// ============================================================
// FILE: lib/core/constants/app_constants.dart
// PURPOSE: App-wide constants — Supabase config, semester list,
// day names, slot times, and other shared fixed values.
//
// IMPORTANT: Replace the Supabase URL and anon key with your
// actual project values from supabase.com → Project Settings
// → API. NEVER commit real keys to public GitHub — use a
// .env loader or --dart-define in production.
// ============================================================

abstract class AppConstants {
  // ─── Supabase ─────────────────────────────────────────────
  static const String supabaseUrl    = 'https://yxqyrjyzxitrgkhgauli.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl4cXlyanl6eGl0cmdraGdhdWxpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk0NzM2OTYsImV4cCI6MjA5NTA0OTY5Nn0.smtNEPQrag9yETZXdA2UqqCmxu_fjmGG8K4Vbot2O-w';

  // ─── Gemini ───────────────────────────────────────────────
  static const String geminiApiKey   = 'YOUR_GEMINI_API_KEY';
  static const String embeddingModel = 'text-embedding-004';
  static const String generationModel = 'gemini-2.0-flash';

  // ─── Timetable Engine (FastAPI on Railway/Render) ─────────
  static const String timetableBaseUrl = 'YOUR_FASTAPI_URL';

  // ─── App Identity ─────────────────────────────────────────
  static const String appName     = 'UniVerse';
  static const String appSubtitle = 'A Campus Companion';
  static const String university  = 'Leading University, Sylhet';
  static const String department  = 'Computer Science and Engineering';

  // ─── User Roles ───────────────────────────────────────────
  static const String roleStudent = 'student';
  static const String roleTeacher = 'teacher';
  static const String roleAdmin   = 'admin';

  // ─── Semesters ────────────────────────────────────────────
  static const List<int> semesters = [1, 2, 3, 4, 5, 6, 7, 8];

  // ─── Days (Sun–Thu, university schedule) ──────────────────
  static const List<String> weekDays = [
    'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday',
  ];

  static const List<String> weekDaysShort = [
    'Sun', 'Mon', 'Tue', 'Wed', 'Thu',
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
  static const String tableAssignments      = 'assignments';
  static const String tableSubmissions      = 'submissions';
  static const String tableDocuments        = 'documents';
  static const String tableGeneratedTimetable = 'generated_timetable';

  // ─── Storage Buckets ──────────────────────────────────────
  static const String bucketAvatars     = 'avatars';
  static const String bucketResources   = 'resources';
  static const String bucketSubmissions = 'submissions';
  static const String bucketTimetables  = 'timetables';

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