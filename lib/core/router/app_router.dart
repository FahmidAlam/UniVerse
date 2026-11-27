import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:universe/core/router/app_shell.dart';
import 'package:universe/core/router/route_names.dart';
import 'package:universe/core/theme/app_motion.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/features/auth/screens/admin_web_notice_screen.dart';
import 'package:universe/features/auth/screens/auth_error_screen.dart';
import 'package:universe/features/auth/screens/email_login_screen.dart';
import 'package:universe/features/auth/screens/email_signup_screen.dart';
import 'package:universe/features/auth/screens/faculty_register_screen.dart';
import 'package:universe/features/auth/screens/forgot_password_screen.dart';
import 'package:universe/features/auth/screens/login_screen.dart';
import 'package:universe/features/auth/screens/not_whitelisted_screen.dart';
import 'package:universe/features/auth/screens/onboarding_screen.dart';
import 'package:universe/features/auth/screens/reset_password_screen.dart';
import 'package:universe/features/auth/screens/role_selection_screen.dart';
import 'package:universe/features/auth/screens/splash_screen.dart';
import 'package:universe/features/auth/screens/student_register_screen.dart';
import 'package:universe/features/auth/screens/verify_email_screen.dart';
import 'package:universe/features/dashboard/screens/student_dashboard_screen.dart';
import 'package:universe/features/find_teacher/screens/find_teacher_screen.dart';
import 'package:universe/features/find_teacher/screens/teacher_detail_screen.dart';
import 'package:universe/features/notifications/controllers/notification_controller.dart';
import 'package:universe/features/notifications/screens/notifications_screen.dart';
import 'package:universe/features/profile/screens/profile_screen.dart';
import 'package:universe/features/resources/screens/resources_screen.dart';
import 'package:universe/features/rooms/screens/room_detail_screen.dart';
import 'package:universe/features/rooms/screens/rooms_screen.dart';
import 'package:universe/features/routine/screens/routine_screen.dart';
import 'package:universe/features/teacher/screens/manage_classes_screen.dart';
import 'package:universe/features/teacher/screens/teacher_dashboard_screen.dart';

class AppRouter {
  final AuthController authController;

  AppRouter({required this.authController});

  late final NotificationController notificationController =
      NotificationController(authController: authController);

  late final GoRouter router = GoRouter(
    initialLocation: RouteNames.splash,
    refreshListenable: authController,
    debugLogDiagnostics: false,
    redirect: (BuildContext context, GoRouterState state) async => redirectFor(
      authController.status,
      state.matchedLocation,
      authController.role,
    ),
    routes: [
      _motionRoute(
          path: RouteNames.authError,
          builder: (c, s) => AuthErrorScreen(authController: authController)),
      _motionRoute(
        path: RouteNames.splash,
        builder: (c, s) => SplashScreen(authController: authController),
      ),
      _motionRoute(
        path: RouteNames.onboarding,
        builder: (c, s) => OnboardingScreen(authController: authController),
      ),
      _motionRoute(
        path: RouteNames.login,
        builder: (c, s) => LoginScreen(authController: authController),
      ),
      _motionRoute(
        path: RouteNames.emailLogin,
        builder: (c, s) => EmailLoginScreen(authController: authController),
      ),
      _motionRoute(
        path: RouteNames.emailSignup,
        builder: (c, s) => EmailSignupScreen(authController: authController),
      ),
      _motionRoute(
        path: RouteNames.verifyEmail,
        builder: (c, s) => VerifyEmailScreen(authController: authController),
      ),
      _motionRoute(
        path: RouteNames.forgotPassword,
        builder: (c, s) => ForgotPasswordScreen(authController: authController),
      ),
      _motionRoute(
        path: RouteNames.resetPassword,
        builder: (c, s) => ResetPasswordScreen(authController: authController),
      ),
      _motionRoute(
        path: RouteNames.roleSelection,
        builder: (c, s) => RoleSelectionScreen(authController: authController),
      ),
      _motionRoute(
        path: RouteNames.studentRegister,
        builder: (c, s) =>
            StudentRegisterScreen(authController: authController),
      ),
      _motionRoute(
        path: RouteNames.facultyRegister,
        builder: (c, s) =>
            FacultyRegisterScreen(authController: authController),
      ),
      _motionRoute(
        path: RouteNames.notWhitelisted,
        builder: (c, s) => NotWhitelistedScreen(authController: authController),
      ),
      _motionRoute(
        path: RouteNames.adminDashboard,
        builder: (c, s) => AdminWebNoticeScreen(authController: authController),
      ),
      ShellRoute(
        builder: (c, s, child) => AppShell(
          authController: authController,
          notificationController: notificationController,
          child: child,
        ),
        routes: [
          // PHASE 1: Campus lists and details retain the authenticated role shell.
          ...campusRoutes(),
          _motionRoute(
            path: RouteNames.studentDashboard,
            builder: (c, s) => StudentDashboardScreen(
              authController: authController,
              notificationController: notificationController,
            ),
          ),
          _motionRoute(
            path: RouteNames.studentRoutine,
            builder: (c, s) => RoutineScreen(authController: authController),
          ),
          _motionRoute(
            path: RouteNames.resources,
            builder: (c, s) => ResourcesScreen(authController: authController),
          ),
          _motionRoute(
            path: RouteNames.notifications,
            builder: (c, s) => NotificationsScreen(
              authController: authController,
              controller: notificationController,
            ),
          ),
          _motionRoute(
            path: RouteNames.profile,
            builder: (c, s) => ProfileScreen(authController: authController),
          ),
          _motionRoute(
            path: RouteNames.teacherDashboard,
            builder: (c, s) => TeacherDashboardScreen(
              authController: authController,
              notificationController: notificationController,
            ),
          ),
          _motionRoute(
            path: RouteNames.teacherRoutine,
            builder: (c, s) => RoutineScreen(authController: authController),
          ),
          _motionRoute(
            path: RouteNames.manageClasses,
            builder: (c, s) =>
                ManageClassesScreen(authController: authController),
          ),
        ],
      ),
    ],
  );

  // PHASE 1: Shared route definitions resolve URL-only refreshes without unsafe casts.
  static List<GoRoute> campusRoutes() => [
        _motionRoute(
            path: RouteNames.rooms, builder: (c, s) => const RoomsScreen()),
        _motionRoute(
            path: RouteNames.findTeacher,
            builder: (c, s) => const FindTeacherScreen()),
        _motionRoute(
            path: RouteNames.roomDetail,
            builder: (c, s) {
              final extra = s.extra;
              final room = extra is String && extra.trim().isNotEmpty
                  ? extra
                  : s.uri.queryParameters['room']?.trim() ?? '';
              return RoomDetailScreen(room: room);
            }),
        _motionRoute(
            path: RouteNames.teacherDetail,
            builder: (c, s) {
              final args = TeacherDetailArgs.resolve(s.extra, s.uri);
              return TeacherDetailScreen(
                  teacherCode: args.code,
                  teacherName: args.name,
                  department: args.dept,
                  designation: args.desig);
            }),
      ];

  /// Where a user with [status] and [role] is sent from [location]; `null`
  /// means they stay.
  static String? redirectFor(
    AuthStatus status,
    String location,
    String? role, {
    // PHASE 1 RECONCILE: Tests model release behavior without changing compile-time flags.
    bool? enableUnauthenticatedSchedulingPreview,
  }) {
    const authPages = [
      RouteNames.splash,
      RouteNames.onboarding,
      RouteNames.login,
      RouteNames.emailLogin,
      RouteNames.emailSignup,
      RouteNames.verifyEmail,
      RouteNames.forgotPassword,
      RouteNames.roleSelection,
      RouteNames.studentRegister,
      RouteNames.facultyRegister,
      RouteNames.notWhitelisted,
      RouteNames.authError,
    ];

    // Signed in with no profile yet: only these screens can finish the
    // account. Leaving such a user on /login made "Continue with Google" look
    // like it did nothing.
    const registrationPages = [
      RouteNames.roleSelection,
      RouteNames.studentRegister,
      RouteNames.facultyRegister,
      RouteNames.emailSignup,
      RouteNames.verifyEmail,
    ];

    if (status == AuthStatus.passwordRecovery) {
      return location == RouteNames.resetPassword
          ? null
          : RouteNames.resetPassword;
    }
    if (status == AuthStatus.profileError) {
      return location == RouteNames.authError ? null : RouteNames.authError;
    }
    if (location == RouteNames.resetPassword &&
        status == AuthStatus.authenticated) {
      return _dashboardForRole(role);
    }
    if (location == RouteNames.resetPassword &&
        status != AuthStatus.initial &&
        status != AuthStatus.loading) {
      return status == AuthStatus.registering
          ? RouteNames.roleSelection
          : RouteNames.login;
    }
    if (status == AuthStatus.initial || status == AuthStatus.loading) {
      return location == RouteNames.splash ? null : RouteNames.splash;
    }

    if (status == AuthStatus.notWhitelisted) {
      return location == RouteNames.notWhitelisted
          ? null
          : RouteNames.notWhitelisted;
    }

    if (status == AuthStatus.awaitingVerification) {
      return location == RouteNames.verifyEmail ? null : RouteNames.verifyEmail;
    }

    if (status == AuthStatus.registering) {
      return registrationPages.contains(location)
          ? null
          : RouteNames.roleSelection;
    }

    if (status == AuthStatus.unauthenticated || status == AuthStatus.error) {
      return authPages.contains(location) ? null : RouteNames.login;
    }

    if (status == AuthStatus.authenticated) {
      if (role == 'admin' && location != RouteNames.adminDashboard) {
        return RouteNames.adminDashboard;
      }
      if (authPages.contains(location) || _isWrongRolePage(location, role)) {
        return _dashboardForRole(role);
      }
    }

    return null;
  }

  static String _dashboardForRole(String? role) {
    switch (role) {
      case 'teacher':
        return RouteNames.teacherDashboard;
      case 'admin':
        return RouteNames.adminDashboard;
      default:
        return RouteNames.studentDashboard;
    }
  }

  static bool _isWrongRolePage(String location, String? role) {
    if (role == 'student' && location.startsWith('/admin')) return true;
    if (role == 'student' && location.startsWith('/teacher')) return true;
    if (role == 'teacher' && location.startsWith('/admin')) return true;
    if (role == 'teacher' && location.startsWith('/student')) return true;
    if (role == 'admin' && location.startsWith('/student')) return true;
    if (role == 'admin' && location.startsWith('/teacher')) return true;
    return false;
  }
}

// One page transition at the child Navigator boundary; shell chrome stays still.
GoRoute _motionRoute({
  required String path,
  required Widget Function(BuildContext, GoRouterState) builder,
}) =>
    GoRoute(
      path: path,
      pageBuilder: (context, state) => _transitionPage(
          context: context, state: state, child: builder(context, state)),
    );

enum RouteTransitionKind { authFlow, shellBranch, detailPush }

RouteTransitionKind routeTransitionKindFor(String path) {
  if (path == RouteNames.roomDetail ||
      path == RouteNames.teacherDetail ||
      path == RouteNames.timetableGrid) {
    return RouteTransitionKind.detailPush;
  }
  if (path.startsWith('/admin') ||
      path.startsWith('/student') ||
      path.startsWith('/teacher') ||
      path == RouteNames.rooms ||
      path == RouteNames.findTeacher ||
      path == RouteNames.profile ||
      path == RouteNames.notifications) {
    return RouteTransitionKind.shellBranch;
  }
  return RouteTransitionKind.authFlow;
}

CustomTransitionPage<void> _transitionPage({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  final path = state.uri.path;
  final kind = routeTransitionKindFor(path);
  final reduced = AppMotion.reduced(context) || path == RouteNames.splash;
  final isMobile = MediaQuery.sizeOf(context).width < 768;
  final normalDuration = switch (kind) {
    RouteTransitionKind.authFlow => const Duration(milliseconds: 260),
    RouteTransitionKind.shellBranch => const Duration(milliseconds: 170),
    RouteTransitionKind.detailPush => isMobile
        ? const Duration(milliseconds: 280)
        : const Duration(milliseconds: 200),
  };
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: reduced ? Duration.zero : normalDuration,
    reverseTransitionDuration: reduced ? Duration.zero : AppMotion.micro,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (AppMotion.reduced(context) || reduced) return child;
      final curved = animation.drive(CurveTween(curve: Curves.easeOutCubic));
      final mobileViewport = MediaQuery.sizeOf(context).width < 768;
      Widget result = child;
      switch (kind) {
        case RouteTransitionKind.authFlow:
          result = SlideTransition(
            position: curved.drive(
              Tween(begin: const Offset(0.03, 0), end: Offset.zero),
            ),
            child: child,
          );
        case RouteTransitionKind.shellBranch:
          result = SlideTransition(
            position: curved.drive(
              Tween(begin: const Offset(0, 0.015), end: Offset.zero),
            ),
            child: child,
          );
        case RouteTransitionKind.detailPush:
          if (mobileViewport) {
            result = SlideTransition(
              position: curved.drive(
                Tween(begin: const Offset(0, 0.06), end: Offset.zero),
              ),
              child: child,
            );
          } else {
            result = ScaleTransition(
              scale: curved.drive(Tween(begin: 0.98, end: 1.0)),
              child: child,
            );
          }
      }
      return FadeTransition(opacity: curved, child: result);
    },
  );
}
