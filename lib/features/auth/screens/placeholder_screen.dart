// ============================================================
// FILE: lib/features/auth/screens/placeholder_screen.dart
// PURPOSE: Temporary screen for routes not yet built.
// Shows the screen name so navigation can be tested
// end-to-end before each feature screen is implemented.
//
// When `bottomNavIndex` is provided, the screen also renders the
// 5-tab bottom nav so the built tabs (Alerts, Profile) are
// reachable from the not-yet-built student tabs.
// DELETE this file (and the bottomNavIndex wiring) once all
// screens are built.
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:universe_v1/core/router/route_names.dart';
import 'package:universe_v1/core/theme/app_colors.dart';
import 'package:universe_v1/core/theme/app_spacing.dart';
import 'package:universe_v1/core/theme/app_text_styles.dart';
import 'package:universe_v1/shared/widgets/u_bottom_nav.dart';

class PlaceholderScreen extends StatelessWidget {
  final String title;

  /// When set (0..4), renders the student bottom nav highlighting
  /// this tab. Null = no bottom nav (e.g. teacher/admin placeholders).
  final int? bottomNavIndex;

  const PlaceholderScreen({
    super.key,
    required this.title,
    this.bottomNavIndex,
  });

  void _onNavTap(BuildContext context, int i) {
    if (i == bottomNavIndex) return;
    switch (i) {
      case 0:
        context.go(RouteNames.studentDashboard);
      case 1:
        context.go(RouteNames.studentRoutine);
      case 2:
        context.go(RouteNames.aiAssistant);
      case 3:
        context.go(RouteNames.notifications);
      case 4:
        context.go(RouteNames.profile);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        title: Text(title, style: AppTextStyles.h2),
      ),
      bottomNavigationBar: bottomNavIndex == null
          ? null
          : UBottomNav(
              currentIndex: bottomNavIndex!,
              onTap: (i) => _onNavTap(context, i),
            ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: AppSpacing.avatarXl,
              height: AppSpacing.avatarXl,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: AppSpacing.radiusXl,
              ),
              child: const Icon(
                PhosphorIconsRegular.wrench,
                color: AppColors.primary,
                size: AppSpacing.iconXl,
              ),
            ),
            AppSpacing.lgGap,
            Text(title, style: AppTextStyles.h3),
            AppSpacing.smGap,
            Text(
              'This screen is under construction',
              style: AppTextStyles.bodySm,
            ),
          ],
        ),
      ),
    );
  }
}
