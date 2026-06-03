// ============================================================
// FILE: lib/core/router/route_names.dart
// PURPOSE: Every route path string lives here as a constant.
// GoRouter uses these strings to navigate. No screen
// ever hardcodes a path like '/dashboard' directly.
//
// HOW TO USE:
// context.go(RouteNames.splash)
// context.go(RouteNames.studentDashboard)
// context.pushNamed(RouteNames.login)
// ============================================================

abstract class RouteNames {
  // Auth flow
  static const String splash             = '/';
  static const String onboarding         = '/onboarding';
  static const String login              = '/login';
  static const String emailLogin         = '/login/email';
  static const String emailSignup        = '/signup/email';
  static const String verifyEmail        = '/verify-email';
  static const String forgotPassword     = '/forgot-password';
  static const String resetPassword      = '/reset-password';
  static const String roleSelection      = '/role-selection';
  static const String studentRegister    = '/register/student';
  static const String facultyRegister    = '/register/faculty';
  static const String notWhitelisted     = '/not-whitelisted';

  // Student
  static const String studentDashboard   = '/student/dashboard';
  static const String studentRoutine     = '/student/routine';
  static const String aiAssistant        = '/student/ai-assistant';
  static const String resources          = '/student/resources';
  static const String notifications      = '/notifications';
  static const String profile            = '/profile';
  static const String teacherDirectory   = '/teacher-directory';

  // Teacher
  static const String teacherDashboard   = '/teacher/dashboard';
  static const String teacherRoutine     = '/teacher/routine';
  static const String manageClasses      = '/teacher/manage-classes';

  // Admin
  static const String adminDashboard     = '/admin/dashboard';
  static const String routineManagement  = '/admin/routine';
  static const String campusBroadcast    = '/admin/broadcast';
  static const String adminRegistration  = '/admin/registration';
  static const String manageUsers        = '/admin/users';
}