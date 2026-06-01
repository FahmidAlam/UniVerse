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

// Auth screens
import 'package:universe_v1/features/auth/screens/splash_screen.dart';
import 'package:universe_v1/features/auth/screens/onboarding_screen.dart';
import 'package:universe_v1/features/auth/screens/login_screen.dart';
import 'package:universe_v1/features/auth/screens/role_selection_screen.dart';
import 'package:universe_v1/features/auth/screens/student_register_screen.dart';
import 'package:universe_v1/features/auth/screens/faculty_register_screen.dart';
import 'package:universe_v1/features/auth/screens/not_whitelisted_screen.dart';

// Placeholder screens (replace with real implementations as built)
import 'package:universe_v1/features/auth/screens/placeholder_screen.dart';

class AppRouter {
  final AuthController authController;

  AppRouter({required this.authController});

  late final GoRouter router = GoRouter(
    initialLocation: RouteNames.splash,
    refreshListenable: authController,
    debugLogDiagnostics: true,

    // ─── Redirect Logic ─────────────────────────────────────
    redirect: (BuildContext context, GoRouterState state) async {
      final status   = authController.status;
      final location = state.matchedLocation;

      // Pages that are always accessible regardless of auth
      const authPages = [
        RouteNames.splash,
        RouteNames.onboarding,
        RouteNames.login,
        RouteNames.roleSelection,
        RouteNames.studentRegister,
        RouteNames.facultyRegister,
        RouteNames.notWhitelisted,
      ];

      // Still initializing — stay on splash
      if (status == AuthStatus.initial || status == AuthStatus.loading) {
        return location == RouteNames.splash ? null : RouteNames.splash;
      }

      // Not whitelisted — force to that screen
      if (status == AuthStatus.notWhitelisted) {
        return location == RouteNames.notWhitelisted
            ? null
            : RouteNames.notWhitelisted;
      }

      // Unauthenticated — send to login unless already on an auth page
      if (status == AuthStatus.unauthenticated ||
          status == AuthStatus.error) {
        return authPages.contains(location) ? null : RouteNames.login;
      }

      // Authenticated — redirect from auth pages to correct dashboard
      if (status == AuthStatus.authenticated) {
        if (authPages.contains(location)) {
          return _dashboardForRole(authController.role);
        }
        // Also guard cross-role access
        if (_isWrongRolePage(location, authController.role)) {
          return _dashboardForRole(authController.role);
        }
      }

      return null; // No redirect needed
    },

    // ─── Routes ──────────────────────────────────────────────
    routes: [
      // Auth flow
      GoRoute(
        path: RouteNames.splash,
        builder: (context, state) => SplashScreen(
          authController: authController,
        ),
      ),
      GoRoute(
        path: RouteNames.onboarding,
        builder: (context, state) => OnboardingScreen(
          authController: authController,
        ),
      ),
      GoRoute(
        path: RouteNames.login,
        builder: (context, state) => LoginScreen(
          authController: authController,
        ),
      ),
      GoRoute(
        path: RouteNames.roleSelection,
        builder: (context, state) => const RoleSelectionScreen(),
      ),
      GoRoute(
        path: RouteNames.studentRegister,
        builder: (context, state) => StudentRegisterScreen(
          authController: authController,
        ),
      ),
      GoRoute(
        path: RouteNames.facultyRegister,
        builder: (context, state) => FacultyRegisterScreen(
          authController: authController,
        ),
      ),
      GoRoute(
        path: RouteNames.notWhitelisted,
        builder: (context, state) => NotWhitelistedScreen(
          authController: authController,
        ),
      ),

      // Student routes (placeholders until screens are built)
      GoRoute(
        path: RouteNames.studentDashboard,
        builder: (context, state) => const PlaceholderScreen(
          title: 'Student Dashboard',
        ),
      ),
      GoRoute(
        path: RouteNames.studentRoutine,
        builder: (context, state) => const PlaceholderScreen(
          title: 'My Routine',
        ),
      ),
      GoRoute(
        path: RouteNames.aiAssistant,
        builder: (context, state) => const PlaceholderScreen(
          title: 'AI Assistant',
        ),
      ),
      GoRoute(
        path: RouteNames.resources,
        builder: (context, state) => const PlaceholderScreen(
          title: 'Resources',
        ),
      ),
      GoRoute(
        path: RouteNames.notifications,
        builder: (context, state) => const PlaceholderScreen(
          title: 'Notifications',
        ),
      ),
      GoRoute(
        path: RouteNames.profile,
        builder: (context, state) => const PlaceholderScreen(
          title: 'Profile',
        ),
      ),

      // Teacher routes
      GoRoute(
        path: RouteNames.teacherDashboard,
        builder: (context, state) => const PlaceholderScreen(
          title: 'Teacher Dashboard',
        ),
      ),
      GoRoute(
        path: RouteNames.teacherRoutine,
        builder: (context, state) => const PlaceholderScreen(
          title: 'My Classes',
        ),
      ),
      GoRoute(
        path: RouteNames.manageClasses,
        builder: (context, state) => const PlaceholderScreen(
          title: 'Manage Classes',
        ),
      ),

      // Admin routes
      GoRoute(
        path: RouteNames.adminDashboard,
        builder: (context, state) => const PlaceholderScreen(
          title: 'Admin Dashboard',
        ),
      ),
      GoRoute(
        path: RouteNames.routineManagement,
        builder: (context, state) => const PlaceholderScreen(
          title: 'Routine Management',
        ),
      ),
      GoRoute(
        path: RouteNames.campusBroadcast,
        builder: (context, state) => const PlaceholderScreen(
          title: 'Campus Broadcast',
        ),
      ),
      GoRoute(
        path: RouteNames.adminRegistration,
        builder: (context, state) => const PlaceholderScreen(
          title: 'Admin Registration',
        ),
      ),
      GoRoute(
        path: RouteNames.manageUsers,
        builder: (context, state) => const PlaceholderScreen(
          title: 'Manage Users',
        ),
      ),
    ],
  );

  // ─── Helpers ──────────────────────────────────────────────
  String _dashboardForRole(String? role) {
    switch (role) {
      case 'teacher':
        return RouteNames.teacherDashboard;
      case 'admin':
        return RouteNames.adminDashboard;
      default:
        return RouteNames.studentDashboard;
    }
  }

  bool _isWrongRolePage(String location, String? role) {
    if (role == 'student' && location.startsWith('/admin')) return true;
    if (role == 'student' && location.startsWith('/teacher')) return true;
    if (role == 'teacher' && location.startsWith('/admin')) return true;
    if (role == 'teacher' && location.startsWith('/student')) return true;
    if (role == 'admin' && location.startsWith('/student')) return true;
    if (role == 'admin' && location.startsWith('/teacher')) return true;
    return false;
  }
}