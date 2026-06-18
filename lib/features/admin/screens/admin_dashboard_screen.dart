// ============================================================
// FILE: lib/features/admin/screens/admin_dashboard_screen.dart
// PURPOSE: Admin hub. Identity header (avatar → profile), an
// overview stat strip, and a 2x2 grid of management actions that
// push to the four admin sub-screens. No bottom nav — admins use
// this dashboard-hub pattern, with each sub-screen's back button
// returning here. Owns its AdminDashboardController lifecycle.
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:universe_v1/core/constants/app_constants.dart';
import 'package:universe_v1/core/models/profile_model.dart';
import 'package:universe_v1/core/router/route_names.dart';
import 'package:universe_v1/core/theme/app_colors.dart';
import 'package:universe_v1/core/theme/app_spacing.dart';
import 'package:universe_v1/core/theme/app_text_styles.dart';
import 'package:universe_v1/features/admin/controllers/admin_dashboard_controller.dart';
import 'package:universe_v1/features/auth/controllers/auth_controller.dart';
import 'package:universe_v1/shared/widgets/quick_action_card.dart';
import 'package:universe_v1/shared/widgets/stat_card.dart';
import 'package:universe_v1/shared/widgets/u_app_bar.dart';
import 'package:universe_v1/shared/widgets/u_avatar.dart';

class AdminDashboardScreen extends StatefulWidget {
  final AuthController authController;

  const AdminDashboardScreen({super.key, required this.authController});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late final AdminDashboardController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AdminDashboardController();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Profile? get _me {
    final map = widget.authController.profile;
    return map == null ? null : Profile.fromMap(map);
  }

  @override
  Widget build(BuildContext context) {
    final me = _me;
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: UAppBar(
        title: me?.displayName ?? 'Admin',
        subtitle: 'Administrator · ${AppConstants.appName}',
        showBackButton: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.screenH),
            child: Center(
              child: UAvatar(
                name: me?.displayName ?? 'Admin',
                imageUrl: me?.avatarUrl,
                size: AppSpacing.avatarSm,
                onTap: () => context.go(RouteNames.profile),
              ),
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.bgCard,
            onRefresh: _controller.load,
            child: ListView(
              padding: AppSpacing.screenPadding,
              children: [
                Text('OVERVIEW', style: AppTextStyles.labelCaps),
                AppSpacing.smGap,
                _buildStats(),
                AppSpacing.sectionGap,
                Text('MANAGE', style: AppTextStyles.labelCaps),
                AppSpacing.smGap,
                _buildActions(),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── Overview stat strip ──────────────────────────────────
  Widget _buildStats() {
    final c = _controller.counts;
    String n(int v) => _controller.isLoading ? '—' : '$v';

    final cards = <Widget>[
      StatCard(
        number: n(c.students),
        label: 'Students',
        icon: PhosphorIconsRegular.graduationCap,
        color: AppColors.roleStudent,
      ),
      StatCard(
        number: n(c.teachers),
        label: 'Teachers',
        icon: PhosphorIconsRegular.chalkboardTeacher,
        color: AppColors.roleTeacher,
      ),
      StatCard(
        number: n(c.routines),
        label: 'Routine Slots',
        icon: PhosphorIconsRegular.calendarBlank,
        color: AppColors.info,
      ),
      StatCard(
        number: n(c.broadcasts),
        label: 'Broadcasts',
        icon: PhosphorIconsRegular.bell,
        color: AppColors.primary,
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: 1.7,
      children: cards,
    );
  }

  // ─── Management actions ───────────────────────────────────
  Widget _buildActions() {
    final actions = <Widget>[
      QuickActionCard(
        label: 'Generate Timetable',
        icon: PhosphorIconsRegular.magicWand,
        color: AppColors.warning,
        onTap: () =>
            context.go('${RouteNames.routineManagement}?tab=generate'),
      ),
      QuickActionCard(
        label: 'Campus Broadcast',
        icon: PhosphorIconsRegular.bellRinging,
        color: AppColors.primary,
        onTap: () => context.go(RouteNames.campusBroadcast),
      ),
      QuickActionCard(
        label: 'Routine Management',
        icon: PhosphorIconsRegular.calendarCheck,
        color: AppColors.info,
        onTap: () => context.go(RouteNames.routineManagement),
      ),
      QuickActionCard(
        label: 'Admin Registration',
        icon: PhosphorIconsRegular.identificationBadge,
        color: AppColors.success,
        onTap: () => context.push(RouteNames.adminRegistration),
      ),
      QuickActionCard(
        label: 'Manage Users',
        icon: PhosphorIconsRegular.users,
        color: AppColors.roleTeacher,
        onTap: () => context.go(RouteNames.manageUsers),
      ),
      QuickActionCard(
        label: 'Manage Resources',
        icon: PhosphorIconsRegular.folderOpen,
        color: AppColors.info,
        onTap: () => context.push(RouteNames.manageResources),
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: 1.4,
      children: actions,
    );
  }
}
