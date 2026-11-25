import 'package:universe/shared/widgets/u_avatar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:universe/core/router/route_names.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/shared/widgets/desktop_shell_scope.dart';

// PHASE 1: Student/teacher desktop navigation owns a fixed rail, not mobile chrome.
class RoleDesktopShell extends StatelessWidget {
  final String role;
  final String currentLocation;
  final String accountName;
  final String? accountImageUrl;
  final int unreadCount;
  final Future<void> Function() onSignOut;
  final bool compactNavigation;
  final Widget child;
  const RoleDesktopShell(
      {super.key,
      required this.role,
      required this.currentLocation,
      required this.accountName,
      this.accountImageUrl,
      required this.unreadCount,
      required this.onSignOut,
      this.compactNavigation = false,
      required this.child});

  @override
  Widget build(BuildContext context) {
    final teacher = role == 'teacher';
    final destinations = <({String label, String route, IconData icon})>[
      (
        label: 'Today',
        route:
            teacher ? RouteNames.teacherDashboard : RouteNames.studentDashboard,
        icon: Icons.today_outlined
      ),
      (
        // PHASE 1 RECONCILE: Teacher wording describes the teaching task, not a generic timetable.
        label: teacher ? 'Teaching' : 'Routine',
        route: teacher ? RouteNames.teacherRoutine : RouteNames.studentRoutine,
        icon: Icons.calendar_month_outlined
      ),
      // PHASE 1 RECONCILE: Campus lookup stays grouped while retaining both direct routes.
      (
        label: 'Room Availability',
        route: RouteNames.rooms,
        icon: Icons.meeting_room_outlined
      ),
      (
        label: 'Find Teacher',
        route: RouteNames.findTeacher,
        icon: Icons.school_outlined
      ),
      if (teacher)
        (
          label: 'Class Tools',
          route: RouteNames.manageClasses,
          icon: Icons.edit_calendar_outlined
        ),
      if (!teacher)
        (
          label: 'Resources',
          route: RouteNames.resources,
          icon: Icons.folder_outlined
        ),
      (
        label: 'Alerts',
        route: RouteNames.notifications,
        icon: Icons.notifications_outlined
      ),
    ];
    final path = Uri.parse(currentLocation).path;
    return DesktopShellScope(
        isDesktop: true,
        child: Scaffold(
          backgroundColor: AppColors.bgPrimary,
          body: SafeArea(
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                Container(
                    key: const ValueKey('role-desktop-sidebar'),
                    // PHASE 1 RECONCILE: Medium uses a compact rail; expanded retains the readable sidebar.
                    width: compactNavigation ? 96 : 220,
                    decoration: const BoxDecoration(
                        color: AppColors.bgCard,
                        border:
                            Border(right: BorderSide(color: AppColors.border))),
                    // PHASE 1: Material paints selected navigation tiles above the rail surface.
                    child: Material(
                        color: AppColors.bgCard,
                        child: Column(children: [
                          Padding(
                              padding: EdgeInsets.all(compactNavigation
                                  ? AppSpacing.md
                                  : AppSpacing.lg),
                              child: Row(children: [
                                const Icon(Icons.blur_circular,
                                    color: AppColors.primary),
                                if (!compactNavigation) ...[
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                      child: Text('UniVerse Orbit',
                                          style: AppTextStyles.h4)),
                                ],
                              ])),
                          const Divider(height: 1),
                          Expanded(
                              child: ListView(children: [
                            if (!compactNavigation && teacher)
                              const Padding(
                                  padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                                  child: Text('Campus Lookup')),
                            for (final item in destinations)
                              Semantics(
                                  selected: path == item.route ||
                                      path.startsWith('${item.route}/'),
                                  child: compactNavigation
                                      ? _CompactDestination(
                                          item: item,
                                          selected: path == item.route ||
                                              path.startsWith('${item.route}/'),
                                          onTap: () => context.go(item.route))
                                      : ListTile(
                                          selected: path == item.route ||
                                              path.startsWith('${item.route}/'),
                                          selectedTileColor:
                                              AppColors.primarySoft,
                                          selectedColor: AppColors.primary,
                                          leading: Icon(item.icon),
                                          title: Text(item.label,
                                              style: AppTextStyles.bodySm),
                                          trailing: item.route ==
                                                      RouteNames
                                                          .notifications &&
                                                  unreadCount > 0
                                              ? Badge(
                                                  label: Text('$unreadCount'))
                                              : null,
                                          onTap: () => context.go(item.route))),
                          ])),
                          const Divider(height: 1),
                          if (!compactNavigation)
                            ListTile(
                                leading: UAvatar(
                                    name: accountName,
                                    imageUrl: accountImageUrl,
                                    size: 32),
                                title: const Text('Account'),
                                subtitle: Text(accountName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                selected: path == RouteNames.profile,
                                onTap: () => context.go(RouteNames.profile)),
                          if (!compactNavigation)
                            TextButton.icon(
                                icon: const Icon(Icons.logout),
                                label: const Text('Sign Out'),
                                onPressed: () => _confirmSignOut(context)),
                        ]))),
                Expanded(
                    child: Column(children: [
                  Container(
                      color: AppColors.bgElevated,
                      padding:
                          const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      child: Row(children: [
                        Expanded(
                            child: Text(
                                teacher
                                    ? 'Teaching workspace'
                                    : 'Student workspace',
                                style: AppTextStyles.bodySmMedium)),
                        ProfileAccountAction(
                            accountName: accountName,
                            imageUrl: accountImageUrl,
                            role: role,
                            onSignOut: () => _confirmSignOut(context))
                      ])),
                  Expanded(child: child),
                ])),
              ])),
        ));
  }

  // PHASE 1: Reuse AuthController sign-out; navigation introduces no auth mutations.
  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
                title: const Text('Sign Out'),
                content: const Text('Sign out of UniVerse?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Sign Out')),
                ]));
    if (confirmed == true) await onSignOut();
  }
}

// PHASE 1 RECONCILE: The medium rail retains labels for scanability within 96px.
class _CompactDestination extends StatelessWidget {
  final ({String label, String route, IconData icon}) item;
  final bool selected;
  final VoidCallback onTap;
  const _CompactDestination(
      {required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
      message: item.label,
      child: InkWell(
          onTap: onTap,
          child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Column(children: [
                Icon(item.icon,
                    color:
                        selected ? AppColors.primary : AppColors.textSecondary),
                const SizedBox(height: 4),
                Text(item.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                        color: selected
                            ? AppColors.primary
                            : AppColors.textSecondary)),
              ]))));
}
