// ============================================================
// FILE: lib/core/router/app_router.dart
// PURPOSE: Single GoRouter instance that controls ALL navigation.
// Auth redirect logic lives here — screens never push
// directly to a protected route.
//
// REDIRECT LOGIC:
// 1. If status is initial/loading → stay on splash
// 2. If unauthenticated → force to login (unless on auth pages)
// 3. If notWhitelisted → force to not-whitelisted page
// 4. If authenticated → redirect based on role:
//    student → /student/dashboard
//    teacher → /teacher/dashboard
//    admin   → /admin/dashboard
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:universe_v1/core/router/route_names.dart';
import 'package:universe_v1/features/auth/controllers/auth_controller.dart';
import 'package:universe_v1/features/auth/screens/splash_screen.dart';
import 'package:universe_v1/features/auth/screens/onboarding_screen.dart';
import 'package:universe_v1/features/auth/screens/login_screen.dart';
import 'package:universe_v1/features/auth/screens/email_login_screen.dart';
import 'package:universe_v1/features/auth/screens/email_signup_screen.dart';
import 'package:universe_v1/features/auth/screens/verify_email_screen.dart';
import 'package:universe_v1/features/auth/screens/forgot_password_screen.dart';
import 'package:universe_v1/features/auth/screens/reset_password_screen.dart';
import 'package:universe_v1/features/auth/screens/role_selection_screen.dart';
import 'package:universe_v1/features/auth/screens/student_register_screen.dart';
import 'package:universe_v1/features/auth/screens/faculty_register_screen.dart';
import 'package:universe_v1/features/auth/screens/not_whitelisted_screen.dart';
import 'package:universe_v1/features/auth/screens/placeholder_screen.dart';
import 'package:universe_v1/features/notifications/screens/notifications_screen.dart';
import 'package:universe_v1/features/profile/screens/profile_screen.dart';

class AppRouter {
  final AuthController authController;

  AppRouter({required this.authController});

  late final GoRouter router = GoRouter(
    initialLocation: RouteNames.splash,
    refreshListenable: authController,
    debugLogDiagnostics: true,

    redirect: (BuildContext context, GoRouterState state) async {
      final status   = authController.status;
      final location = state.matchedLocation;

      const authPages = [
        RouteNames.splash,
        RouteNames.onboarding,
        RouteNames.login,
        RouteNames.emailLogin,
        RouteNames.emailSignup,
        RouteNames.verifyEmail,
        RouteNames.forgotPassword,
        RouteNames.resetPassword,
        RouteNames.roleSelection,
        RouteNames.studentRegister,
        RouteNames.facultyRegister,
        RouteNames.notWhitelisted,
      ];

      if (status == AuthStatus.initial || status == AuthStatus.loading) {
        return location == RouteNames.splash ? null : RouteNames.splash;
      }

      if (status == AuthStatus.notWhitelisted) {
        return location == RouteNames.notWhitelisted
            ? null
            : RouteNames.notWhitelisted;
      }

      if (status == AuthStatus.awaitingVerification) {
        return location == RouteNames.verifyEmail
            ? null
            : RouteNames.verifyEmail;
      }

      if (status == AuthStatus.unauthenticated ||
          status == AuthStatus.error) {
        return authPages.contains(location) ? null : RouteNames.login;
      }

      if (status == AuthStatus.authenticated) {
        if (authPages.contains(location)) {
          return _dashboardForRole(authController.role);
        }
        if (_isWrongRolePage(location, authController.role)) {
          return _dashboardForRole(authController.role);
        }
      }

      return null;
    },

    routes: [
      GoRoute(
        path: RouteNames.splash,
        builder: (c, s) => SplashScreen(authController: authController),
      ),
      GoRoute(
        path: RouteNames.onboarding,
        builder: (c, s) => OnboardingScreen(authController: authController),
      ),
      GoRoute(
        path: RouteNames.login,
        builder: (c, s) => LoginScreen(authController: authController),
      ),
      GoRoute(
        path: RouteNames.emailLogin,
        builder: (c, s) => EmailLoginScreen(authController: authController),
      ),
      GoRoute(
        path: RouteNames.emailSignup,
        builder: (c, s) => EmailSignupScreen(authController: authController),
      ),
      GoRoute(
        path: RouteNames.verifyEmail,
        builder: (c, s) => VerifyEmailScreen(authController: authController),
      ),
      GoRoute(
        path: RouteNames.forgotPassword,
        builder: (c, s) =>
            ForgotPasswordScreen(authController: authController),
      ),
      GoRoute(
        path: RouteNames.resetPassword,
        builder: (c, s) =>
            ResetPasswordScreen(authController: authController),
      ),
      GoRoute(
        path: RouteNames.roleSelection,
        builder: (c, s) => const RoleSelectionScreen(),
      ),
      GoRoute(
        path: RouteNames.studentRegister,
        builder: (c, s) =>
            StudentRegisterScreen(authController: authController),
      ),
      GoRoute(
        path: RouteNames.facultyRegister,
        builder: (c, s) =>
            FacultyRegisterScreen(authController: authController),
      ),
      GoRoute(
        path: RouteNames.notWhitelisted,
        builder: (c, s) =>
            NotWhitelistedScreen(authController: authController),
      ),

      // Student
      GoRoute(path: RouteNames.studentDashboard, builder: (c, s) => const PlaceholderScreen(title: 'Student Dashboard', bottomNavIndex: 0)),
      GoRoute(path: RouteNames.studentRoutine,   builder: (c, s) => const PlaceholderScreen(title: 'My Routine', bottomNavIndex: 1)),
      GoRoute(path: RouteNames.aiAssistant,      builder: (c, s) => const PlaceholderScreen(title: 'AI Assistant', bottomNavIndex: 2)),
      GoRoute(path: RouteNames.resources,        builder: (c, s) => const PlaceholderScreen(title: 'Resources')),
      GoRoute(
        path: RouteNames.notifications,
        builder: (c, s) =>
            NotificationsScreen(authController: authController),
      ),
      GoRoute(
        path: RouteNames.profile,
        builder: (c, s) => ProfileScreen(authController: authController),
      ),

      // Teacher
      GoRoute(path: RouteNames.teacherDashboard, builder: (c, s) => const PlaceholderScreen(title: 'Teacher Dashboard')),
      GoRoute(path: RouteNames.teacherRoutine,   builder: (c, s) => const PlaceholderScreen(title: 'My Classes')),
      GoRoute(path: RouteNames.manageClasses,    builder: (c, s) => const PlaceholderScreen(title: 'Manage Classes')),

      // Admin
      GoRoute(path: RouteNames.adminDashboard,    builder: (c, s) => const PlaceholderScreen(title: 'Admin Dashboard')),
      GoRoute(path: RouteNames.routineManagement, builder: (c, s) => const PlaceholderScreen(title: 'Routine Management')),
      GoRoute(path: RouteNames.campusBroadcast,   builder: (c, s) => const PlaceholderScreen(title: 'Campus Broadcast')),
      GoRoute(path: RouteNames.adminRegistration, builder: (c, s) => const PlaceholderScreen(title: 'Admin Registration')),
      GoRoute(path: RouteNames.manageUsers,       builder: (c, s) => const PlaceholderScreen(title: 'Manage Users')),
    ],
  );

  String _dashboardForRole(String? role) {
    switch (role) {
      case 'teacher': return RouteNames.teacherDashboard;
      case 'admin':   return RouteNames.adminDashboard;
      default:        return RouteNames.studentDashboard;
    }
  }

  bool _isWrongRolePage(String location, String? role) {
    if (role == 'student' && location.startsWith('/admin'))   return true;
    if (role == 'student' && location.startsWith('/teacher')) return true;
    if (role == 'teacher' && location.startsWith('/admin'))   return true;
    if (role == 'teacher' && location.startsWith('/student')) return true;
    if (role == 'admin'   && location.startsWith('/student')) return true;
    if (role == 'admin'   && location.startsWith('/teacher')) return true;
    return false;
  }
}