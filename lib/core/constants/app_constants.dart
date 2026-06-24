abstract class AppConstants {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://yxqyrjyzxitrgkhgauli.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl4cXlyanl6eGl0cmdraGdhdWxpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk0NzM2OTYsImV4cCI6MjA5NTA0OTY5Nn0.smtNEPQrag9yETZXdA2UqqCmxu_fjmGG8K4Vbot2O-w',
  );

  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: 'YOUR_GEMINI_API_KEY',
  );
  static const String embeddingModel = 'text-embedding-004';
  static const String generationModel = 'gemini-2.0-flash';

  static const String timetableBaseUrl = String.fromEnvironment(
    'TIMETABLE_BASE_URL',
    defaultValue: 'https://universe-timetable-engine.onrender.com',
  );

  static const String appName     = 'UniVerse';
  static const String appSubtitle = 'A Campus Companion';
  static const String university  = 'Leading University, Sylhet';
  static const String department  = 'Computer Science and Engineering';

  static const String roleStudent = 'student';
  static const String roleTeacher = 'teacher';
  static const String roleAdmin   = 'admin';

  static const List<int> semesters = [1, 2, 3, 4, 5, 6, 7, 8];

  static const List<String> weekDays = [
    'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
  ];

  static const List<String> weekDaysShort = [
    'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat',
  ];

  static const List<String> timeSlots = [
    '9:30 AM – 10:50 AM',
    '10:50 AM – 12:10 PM',
    '12:10 PM – 1:30 PM',
    '2:10 PM – 3:30 PM',
    '3:30 PM – 4:50 PM',
  ];

  static const String notifUniversity  = 'university';
  static const String notifClassCancel = 'class_cancel';
  static const String notifRoomChange  = 'room_change';
  static const String notifTestReminder = 'test_reminder';
  static const String notifAssignment  = 'assignment';
  static const String notifExam        = 'exam';

  static const List<String> resourceCategories = [
    'All', 'PYQ', 'Notes', 'Slides', 'Assignments',
  ];

  static const List<String> departments = [
    'CSE', 'EEE', 'BBA', 'English', 'GED', 'CE', 'Law',
  ];

  static const List<String> designations = [
    'Professor',
    'Associate Professor',
    'Assistant Professor',
    'Senior Lecturer',
    'Lecturer',
  ];

  static const String prefOnboardingDone = 'onboarding_done';
  static const String prefUserRole       = 'user_role';

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
  static const String tableDeviceTokens     = 'device_tokens';
  static const String tableTimetableRooms    = 'timetable_rooms';
  static const String tableTimetableFaculty  = 'timetable_faculty';
  static const String tableTimetableSettings = 'timetable_settings';
  static const String tableTimetableRuns     = 'timetable_runs';

  static const String bucketResources   = 'resources';
  static const String bucketTimetables  = 'timetables';
  static const String bucketAvatars     = 'avatars';
  static const String bucketSubmissions = 'submissions';

  static const String pushChannelId   = 'universe_high_importance';
  static const String pushChannelName = 'UniVerse Alerts';
  static const String pushChannelDesc =
      'Class cancellations, room changes, and campus announcements.';

  static const int embeddingDimension = 768;
  static const int ragMatchCount      = 3;
  static const String rpcMatchDocuments = 'match_documents';

  static const List<String> suggestedQuestions = [
    'When is my DSA class?',
    'Who teaches Operating Systems?',
    'What is my Friday schedule?',
    'Is Thursday Math class cancelled?',
    'What rooms are available now?',
    'Show me Batch 62 Section G routine',
  ];
}
