// ============================================================
// FILE: lib/shared/widgets/app_drawer.dart
// PURPOSE: The side menu behind the hamburger button in the top-right
// of every dashboard. Opens from the right (endDrawer) so it slides out
// from under the button that summoned it.
//
// Holds the shortcuts that do not deserve a bottom-nav tab — campus
// explore, role-specific admin/teacher tools, About — plus Sign Out.
//
// The entry list is role-aware: `_destinationsFor(role)` is the single
// place that decides what a student / teacher / admin sees, mirroring
// how `AppBottomNav.destinationsFor` owns the tab sets.
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/models/profile_model.dart';
import 'package:universe/core/router/route_names.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/shared/widgets/u_local_avatar.dart';

/// True while a dashboard's end drawer is open.
///
/// `AppShell` watches this to pull the Explore FAB out of the way. The FAB
/// sits on the shell's Scaffold and the drawer on the screen's own Scaffold,
/// so neither can find the other through the widget tree — a shared notifier
/// is the seam between them. Dashboards drive it from
/// `Scaffold.onEndDrawerChanged`.
final ValueNotifier<bool> drawerOpenNotifier = ValueNotifier<bool>(false);

/// One row in the drawer. `push` keeps the bottom nav visible for tab
/// routes (`context.go`) and pushes a back-button page otherwise.
class _DrawerEntry {
  final IconData icon;
  final String label;
  final String route;
  final bool push;

  const _DrawerEntry(this.icon, this.label, this.route, {this.push = false});
}

class AppDrawer extends StatelessWidget {
  final Profile? profile;
  final String? userId;
  final String? role;
  final Future<void> Function() onSignOut;

  const AppDrawer({
    super.key,
    required this.profile,
    required this.userId,
    required this.role,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(
          left: Radius.circular(AppSpacing.radiusXlD),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(context),
            const Divider(color: AppColors.border, height: AppSpacing.lg),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                children: [
                  for (final entry in _destinationsFor(role))
                    _tile(context, entry),
                ],
              ),
            ),
            const Divider(color: AppColors.border, height: AppSpacing.lg),
            _signOutTile(context),
            AppSpacing.smGap,
          ],
        ),
      ),
    );
  }

  // ─── Header — who is signed in ────────────────────────────
  Widget _header(BuildContext context) {
    final name = profile?.displayName ?? 'UniVerse';
    final subtitle = profile?.email ?? AppConstants.university;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          ULocalAvatar(
            userId: userId,
            name: name,
            imageUrl: profile?.avatarUrl,
            size: AppSpacing.avatarMd,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.h4.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Rows ─────────────────────────────────────────────────
  Widget _tile(BuildContext context, _DrawerEntry entry) {
    return _DrawerTile(
      icon: entry.icon,
      label: entry.label,
      onTap: () {
        Navigator.pop(context); // close the drawer before navigating
        if (entry.push) {
          context.push(entry.route);
        } else {
          context.go(entry.route);
        }
      },
    );
  }

  Widget _signOutTile(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: _DrawerTile(
        icon: PhosphorIconsRegular.signOut,
        label: 'Sign Out',
        danger: true,
        onTap: () => _confirmSignOut(context),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: AppSpacing.radiusLg),
        title: Text('Sign out?', style: AppTextStyles.h3),
        content: Text(
          'You\'ll need to sign in again to access your account.',
          style: AppTextStyles.bodySm,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Sign out', style: AppTextStyles.danger),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (context.mounted) Navigator.pop(context); // close the drawer
    await onSignOut();
  }

  // ─── Role-aware entries ───────────────────────────────────
  // Every role opens with the same three: Profile, then campus explore
  // (Find Teacher, Room Availability). Whatever is specific to the role
  // follows underneath.
  List<_DrawerEntry> _destinationsFor(String? role) {
    const common = [
      _DrawerEntry(PhosphorIconsRegular.user, 'Profile', RouteNames.profile),
      _DrawerEntry(PhosphorIconsRegular.magnifyingGlass, 'Find Teacher',
          RouteNames.findTeacher, push: true),
      _DrawerEntry(PhosphorIconsRegular.door, 'Room Availability',
          RouteNames.rooms, push: true),
    ];

    switch (role) {
      case AppConstants.roleTeacher:
        return [
          ...common,
          const _DrawerEntry(PhosphorIconsRegular.calendarBlank, 'My Routine',
              RouteNames.teacherRoutine),
          const _DrawerEntry(PhosphorIconsRegular.chalkboardTeacher,
              'Manage Classes', RouteNames.manageClasses),
          const _DrawerEntry(
              PhosphorIconsRegular.bell, 'Alerts', RouteNames.notifications),
        ];

      case AppConstants.roleAdmin:
        return [
          ...common,
          const _DrawerEntry(PhosphorIconsRegular.calendarCheck, 'Routine Hub',
              RouteNames.routineManagement),
          const _DrawerEntry(PhosphorIconsRegular.folder, 'Manage Resources',
              RouteNames.manageResources, push: true),
          const _DrawerEntry(PhosphorIconsRegular.identificationBadge,
              'Admin Registration', RouteNames.adminRegistration, push: true),
          const _DrawerEntry(PhosphorIconsRegular.buildings, 'Manage Rooms',
              RouteNames.manageRooms, push: true),
          const _DrawerEntry(PhosphorIconsRegular.usersThree, 'Manage Faculty',
              RouteNames.manageFaculty, push: true),
          const _DrawerEntry(PhosphorIconsRegular.sliders,
              'Timetable Settings', RouteNames.timetableSettings, push: true),
        ];

      default:
        return [
          ...common,
          const _DrawerEntry(PhosphorIconsRegular.calendarBlank, 'My Routine',
              RouteNames.studentRoutine),
          const _DrawerEntry(
              PhosphorIconsRegular.books, 'Resources', RouteNames.resources),
          const _DrawerEntry(
              PhosphorIconsRegular.bell, 'Alerts', RouteNames.notifications),
        ];
    }
  }
}

// ─── Hamburger button ───────────────────────────────────────

/// The three-line button that opens [AppDrawer]. Lives in `UAppBar.actions`,
/// so it needs its own `Builder` — the screen's context sits above the
/// Scaffold and cannot find the drawer to open.
class UDrawerButton extends StatelessWidget {
  const UDrawerButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: Builder(
        builder: (innerContext) => IconButton(
          tooltip: 'Menu',
          icon: const Icon(
            PhosphorIconsRegular.hamburger,
            color: AppColors.textPrimary,
            size: AppSpacing.iconLg,
          ),
          onPressed: () => Scaffold.of(innerContext).openEndDrawer(),
        ),
      ),
    );
  }
}

// ─── Tile ───────────────────────────────────────────────────

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  const _DrawerTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final tint = danger ? AppColors.error : AppColors.textSecondary;

    return Material(
      color: Colors.transparent,
      borderRadius: AppSpacing.radiusMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.radiusMd,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Icon(icon, size: AppSpacing.iconMd, color: tint),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: danger ? AppColors.error : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
