import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/router/route_names.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/shared/widgets/u_adaptive_overlay.dart';
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
  final String? role;

  final String currentRoute;

  final int unreadNotifCount;

  const AppBottomNav({
    super.key,
    required this.role,
    required this.currentRoute,
    this.unreadNotifCount = 0,
  });

  // PHASE 1: Exactly five role destinations; Campus includes both lookup routes.
  static List<AppNavDest> destinationsFor(String? role) {
    const campus = AppNavDest(
        icon: PhosphorIconsRegular.door,
        label: 'Campus',
        route: RouteNames.rooms);
    const alerts = AppNavDest(
        icon: PhosphorIconsRegular.bell,
        label: 'Alerts',
        route: RouteNames.notifications);
    if (role == AppConstants.roleAdmin) {
      return const [
        AppNavDest(
            icon: PhosphorIconsRegular.house,
            label: 'Overview',
            route: RouteNames.adminDashboard),
        AppNavDest(
            icon: PhosphorIconsRegular.calendarBlank,
            // PHASE 1 RECONCILE: This preserves the operational, non-preview routine route.
            label: 'Routine Operations',
            route: RouteNames.routineManagement),
        AppNavDest(
            icon: PhosphorIconsRegular.stack,
            // PHASE 1 RECONCILE: The destination remains visibly simulation-only.
            label: 'Scheduling Workbench · Preview',
            route: RouteNames.schedulingWorkspace),
        AppNavDest(
            icon: PhosphorIconsRegular.bellRinging,
            label: 'Broadcast',
            route: RouteNames.campusBroadcast),
        AppNavDest(
            icon: PhosphorIconsRegular.dotsThree, label: 'More', route: ''),
      ];
    }
    if (role == AppConstants.roleTeacher) {
      return const [
        AppNavDest(
            icon: PhosphorIconsRegular.house,
            label: 'Today',
            route: RouteNames.teacherDashboard),
        AppNavDest(
            icon: PhosphorIconsRegular.calendarBlank,
            label: 'Teaching',
            route: RouteNames.teacherRoutine),
        AppNavDest(
            icon: PhosphorIconsRegular.door, label: 'Campus', route: RouteNames.rooms),
        AppNavDest(
            icon: PhosphorIconsRegular.chalkboardTeacher,
            label: 'Class Tools',
            route: RouteNames.manageClasses),
        alerts,
      ];
    }
    return const [
      AppNavDest(
          icon: PhosphorIconsRegular.house,
          label: 'Today',
          route: RouteNames.studentDashboard),
      AppNavDest(
          icon: PhosphorIconsRegular.calendarBlank,
          label: 'Routine',
          route: RouteNames.studentRoutine),
      campus,
      AppNavDest(
          icon: PhosphorIconsRegular.folder,
          label: 'Resources',
          route: RouteNames.resources),
      alerts,
    ];
  }

  // PHASE 1: Descendants retain their parent tab; secondary admin tools select More.
  static int selectedIndexFor(String? role, String location) {
    final path = Uri.parse(location).path;
    final destinations = destinationsFor(role);
    if (path == RouteNames.findTeacher ||
        path.startsWith('${RouteNames.findTeacher}/')) {
      final campus =
          destinations.indexWhere((d) => d.route == RouteNames.rooms);
      return campus >= 0
          ? campus
          : role == AppConstants.roleAdmin
              ? 4
              : -1;
    }
    final index = destinations.indexWhere((d) =>
        d.route.isNotEmpty &&
        (path == d.route || path.startsWith('${d.route}/')));
    return index >= 0
        ? index
        : role == AppConstants.roleAdmin
            ? 4
            : -1;
  }

  // PHASE 1: Mobile admin tools stay reachable through existing guarded routes.
  static const adminTools = <({String label, String route})>[
    (label: 'Courses', route: RouteNames.manageCourses),
    (label: 'Batches & Sections', route: RouteNames.manageBatches),
    (label: 'Users', route: RouteNames.manageUsers),
    (label: 'Registration', route: RouteNames.adminRegistration),
    (label: 'Faculty', route: RouteNames.manageFaculty),
    (label: 'Rooms', route: RouteNames.manageRooms),
    (label: 'Course Eligibility', route: RouteNames.manageCourseEligibility),
    (label: 'Settings', route: RouteNames.timetableSettings),
    (label: 'Resources', route: RouteNames.manageResources),
    (label: 'Resource Library', route: RouteNames.resourceLibrary),
    (label: 'Routine Preview', route: RouteNames.timetableGrid),
    (label: 'Broadcast History', route: RouteNames.broadcastHistory),
    (label: 'Campus Lookup', route: RouteNames.rooms),
    (label: 'Profile', route: RouteNames.profile),
  ];

  @override
  Widget build(BuildContext context) {
    final dests = destinationsFor(role);
    // PHASE 2: Preserve SafeArea bottom clearance for mobile gesture/home bars.
    return SafeArea(
        top: false,
        bottom: true,
        child: UBottomNav(
          items: [
            for (final d in dests) UNavItem(icon: d.icon, label: d.label)
          ],
          currentIndex: selectedIndexFor(role, currentRoute),
          badgeIndex:
              dests.indexWhere((d) => d.route == RouteNames.notifications),
          unreadNotifCount: unreadNotifCount,
          onTap: (index) {
            final route = dests[index].route;
            if (route.isEmpty && role == AppConstants.roleAdmin) {
              showUAdaptiveModal<void>(
                context: context,
                title: 'Admin tools',
                badge: 'OPERATIONS DIRECTORY',
                icon: PhosphorIconsRegular.dotsThree,
                accentColor: AppColors.roleAdmin,
                builder: (sheetContext) => ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.56,
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final tool in adminTools)
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                          title: Text(tool.label),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: AppColors.textMuted,
                          ),
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            context.go(tool.route);
                          },
                        ),
                    ],
                  ),
                ),
              );
            } else if (route != Uri.parse(currentRoute).path) {
              context.go(route);
            }
          },
        ));
  }
}
