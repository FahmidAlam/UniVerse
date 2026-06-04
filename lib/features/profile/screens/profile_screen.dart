// ============================================================
// FILE: lib/features/profile/screens/profile_screen.dart
// PURPOSE: Profile tab. Avatar + identity header, role-aware
// stat cards, academic/contact info rows, settings tiles, and
// a confirmed sign-out. Owns its ProfileController lifecycle.
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
import 'package:universe_v1/features/auth/controllers/auth_controller.dart';
import 'package:universe_v1/features/profile/controllers/profile_controller.dart';
import 'package:universe_v1/shared/widgets/info_row.dart';
import 'package:universe_v1/shared/widgets/settings_tile.dart';
import 'package:universe_v1/shared/widgets/stat_card.dart';
import 'package:universe_v1/shared/widgets/u_app_bar.dart';
import 'package:universe_v1/shared/widgets/u_avatar.dart';
import 'package:universe_v1/shared/widgets/u_bottom_nav.dart';
import 'package:universe_v1/shared/widgets/u_button.dart';
import 'package:universe_v1/shared/widgets/u_card.dart';
import 'package:universe_v1/shared/widgets/u_loading.dart';

class ProfileScreen extends StatefulWidget {
  final AuthController authController;

  const ProfileScreen({super.key, required this.authController});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ProfileController(authController: widget.authController);
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onNavTap(int i) {
    final isTeacher = widget.authController.role == 'teacher';
    switch (i) {
      case 0:
        context.go(isTeacher
            ? RouteNames.teacherDashboard
            : RouteNames.studentDashboard);
      case 1:
        context.go(
            isTeacher ? RouteNames.teacherRoutine : RouteNames.studentRoutine);
      case 2:
        context.go(RouteNames.aiAssistant);
      case 3:
        context.go(RouteNames.notifications);
      case 4:
        break; // already here
    }
  }

  Future<void> _confirmSignOut() async {
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
            child: Text('Cancel',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Sign out', style: AppTextStyles.danger),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _controller.signOut();
      // GoRouter redirect handles navigation back to login.
    }
  }

  void _comingSoon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label — coming soon', style: AppTextStyles.bodySm),
        backgroundColor: AppColors.bgElevated,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: const UAppBar(title: 'Profile', showBackButton: false),
      bottomNavigationBar: UBottomNav(currentIndex: 4, onTap: _onNavTap),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final p = _controller.profile;
          if (p == null) {
            return const Center(child: ULoading.spinner());
          }
          return SingleChildScrollView(
            padding: AppSpacing.screenPaddingScrollable,
            child: Column(
              children: [
                _buildHeader(p),
                AppSpacing.sectionGap,
                _buildStats(p),
                AppSpacing.sectionGap,
                _buildInfo(p),
                AppSpacing.sectionGap,
                _buildSettings(),
                AppSpacing.sectionGap,
                UButton(
                  label: 'Sign out',
                  variant: UButtonVariant.danger,
                  icon: PhosphorIconsRegular.signOut,
                  onPressed: _confirmSignOut,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────
  Widget _buildHeader(Profile p) {
    return Column(
      children: [
        UAvatar(
          name: p.displayName,
          imageUrl: p.avatarUrl,
          size: AppSpacing.avatarXl,
        ),
        AppSpacing.mdGap,
        Text(p.displayName, style: AppTextStyles.h2),
        AppSpacing.xsGap,
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: AppSpacing.radiusFull,
          ),
          child: Text(
            p.roleLabel.toUpperCase(),
            style: AppTextStyles.labelCaps.copyWith(color: AppColors.primary),
          ),
        ),
        AppSpacing.smGap,
        Text(p.email, style: AppTextStyles.bodySm),
      ],
    );
  }

  // ─── Stats (role-aware) ───────────────────────────────────
  Widget _buildStats(Profile p) {
    final List<Widget> cards;
    if (p.isTeacher) {
      cards = [
        StatCard(number: p.department ?? '—', label: 'Department'),
        StatCard(number: '${p.courses.length}', label: 'Courses'),
      ];
    } else if (p.isStudent) {
      cards = [
        StatCard(number: p.batch ?? '—', label: 'Batch'),
        StatCard(number: p.section ?? '—', label: 'Section'),
        StatCard(number: '${p.semester ?? '—'}', label: 'Semester'),
      ];
    } else {
      // Admin — no academic stats.
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) AppSpacing.smHGap,
          Expanded(child: cards[i]),
        ],
      ],
    );
  }

  // ─── Info rows ────────────────────────────────────────────
  Widget _buildInfo(Profile p) {
    final rows = <Widget>[
      InfoRow(
        label: 'Email',
        value: p.email,
        icon: PhosphorIconsRegular.envelopeSimple,
      ),
      if (p.identifier != null)
        InfoRow(
          label: p.identifierLabel,
          value: p.identifier!,
          icon: PhosphorIconsRegular.identificationCard,
        ),
      if (p.isTeacher && p.designation != null)
        InfoRow(
          label: 'Designation',
          value: p.designation!,
          icon: PhosphorIconsRegular.briefcase,
        ),
      if (p.department != null)
        InfoRow(
          label: 'Department',
          value: p.department!,
          icon: PhosphorIconsRegular.buildings,
          showDivider: false,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('INFORMATION', style: AppTextStyles.labelCaps),
        AppSpacing.smGap,
        UCard(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(children: rows),
        ),
      ],
    );
  }

  // ─── Settings ─────────────────────────────────────────────
  Widget _buildSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SETTINGS', style: AppTextStyles.labelCaps),
        AppSpacing.smGap,
        UCard(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: [
              SettingsTile(
                title: 'Edit profile',
                icon: PhosphorIconsRegular.userGear,
                onTap: () => _comingSoon('Edit profile'),
              ),
              const Divider(
                  color: AppColors.border,
                  thickness: AppSpacing.borderThin,
                  height: 0),
              SettingsTile(
                title: 'Notification settings',
                icon: PhosphorIconsRegular.bell,
                onTap: () => _comingSoon('Notification settings'),
              ),
              const Divider(
                  color: AppColors.border,
                  thickness: AppSpacing.borderThin,
                  height: 0),
              SettingsTile(
                title: 'About ${AppConstants.appName}',
                icon: PhosphorIconsRegular.info,
                onTap: _showAbout,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: AppConstants.appName,
      applicationVersion: AppConstants.appSubtitle,
      children: [
        Text(
          '${AppConstants.appName} — ${AppConstants.university}.',
          style: AppTextStyles.bodySm,
        ),
      ],
    );
  }
}
