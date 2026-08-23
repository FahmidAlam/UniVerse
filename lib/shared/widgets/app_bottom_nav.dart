// ============================================================
// FILE: lib/shared/widgets/app_bottom_nav.dart
// PURPOSE: Role-aware bottom navigation. ONE place defines the tab set
// for each role. Rendered ONLY by AppShell (core/router/app_shell.dart),
// which passes the current router location — individual screens never
// place this widget. Active tab is computed from the route; taps go
// via context.go, so shared screens (Profile/Notifications) always
// show the correct tabs for whoever is logged in.
//
// Convention: top-level destinations live here. Secondary screens
// (e.g. Resources, Admin Registration) are pushed and use a back
// button instead of a tab — they are intentionally not in this list.
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/router/route_names.dart';
import 'package:universe/shared/widgets/u_bottom_nav.dart';

class AppNavDest {
  final IconData icon;
  final String label;
  final String route;

  const AppNavDest({
    required this.icon,
    required this.label,
    required this.route,
  });
}

class AppBottomNav extends StatelessWidget {
  /// The current user's role (AuthController.role). Drives the tab set.
  final String? role;

  /// The route of the screen rendering this nav — used to highlight
  /// the active tab.
  final String currentRoute;

  final int unreadNotifCount;

  const AppBottomNav({
    super.key,
    required this.role,
    required this.currentRoute,
    this.unreadNotifCount = 0,
  });

  /// The single source of truth for each role's tabs.
  static List<AppNavDest> destinationsFor(String? role) {
    switch (role) {
      case AppConstants.roleAdmin:
        return const [
          AppNavDest(
            icon: PhosphorIconsRegular.house,
            label: 'Dashboard',
            route: RouteNames.adminDashboard,
          ),
          AppNavDest(
            icon: PhosphorIconsRegular.bellRinging,
            label: 'Broadcast',
            route: RouteNames.campusBroadcast,
          ),
          AppNavDest(
            icon: PhosphorIconsRegular.calendarCheck,
            label: 'Routine',
            route: RouteNames.routineManagement,
          ),
          AppNavDest(
            icon: PhosphorIconsRegular.users,
            label: 'Users',
            route: RouteNames.manageUsers,
          ),
          AppNavDest(
            icon: PhosphorIconsRegular.user,
            label: 'Profile',
            route: RouteNames.profile,
          ),
        ];
      case AppConstants.roleTeacher:
        return const [
          AppNavDest(
            icon: PhosphorIconsRegular.house,
            label: 'Home',
            route: RouteNames.teacherDashboard,
          ),
          AppNavDest(
            icon: PhosphorIconsRegular.calendarBlank,
            label: 'Routine',
            route: RouteNames.teacherRoutine,
          ),
          AppNavDest(
            icon: PhosphorIconsRegular.chalkboardTeacher,
            label: 'Manage',
            route: RouteNames.manageClasses,
          ),
          AppNavDest(
            icon: PhosphorIconsRegular.bell,
            label: 'Alerts',
            route: RouteNames.notifications,
          ),
          AppNavDest(
            icon: PhosphorIconsRegular.user,
            label: 'Profile',
            route: RouteNames.profile,
          ),
        ];
      default: // student
        return const [
          AppNavDest(
            icon: PhosphorIconsRegular.house,
            label: 'Home',
            route: RouteNames.studentDashboard,
          ),
          AppNavDest(
            icon: PhosphorIconsRegular.calendarBlank,
            label: 'Routine',
            route: RouteNames.studentRoutine,
          ),
          // Resources promoted to a tab (replaces the descoped AI Assistant
          // slot). AI Assistant is kept as future scope — to restore it,
          // re-add its destination + the /student/ai-assistant route.
          AppNavDest(
            icon: PhosphorIconsRegular.folder,
            label: 'Resources',
            route: RouteNames.resources,
          ),
          AppNavDest(
            icon: PhosphorIconsRegular.bell,
            label: 'Alerts',
            route: RouteNames.notifications,
          ),
          AppNavDest(
            icon: PhosphorIconsRegular.user,
            label: 'Profile',
            route: RouteNames.profile,
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final dests = destinationsFor(role);
    var currentIndex = dests.indexWhere((d) => d.route == currentRoute);
    if (currentIndex < 0) currentIndex = 0;
    final badgeIndex = dests.indexWhere(
      (d) => d.route == RouteNames.notifications,
    );

    return UBottomNav(
      items: [for (final d in dests) UNavItem(icon: d.icon, label: d.label)],
      currentIndex: currentIndex,
      badgeIndex: badgeIndex,
      unreadNotifCount: unreadNotifCount,
      onTap: (i) {
        final route = dests[i].route;
        if (route == currentRoute) return;
        context.go(route);
      },
    );
  }
}
