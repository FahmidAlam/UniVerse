// ============================================================
// FILE: lib/features/auth/screens/placeholder_screen.dart
// PURPOSE: Temporary screen for routes not yet built.
// Shows the screen name so navigation can be tested
// end-to-end before each feature screen is implemented.
//
// When `authController` + `navRoute` are provided, the screen renders
// the role-aware bottom nav (AppBottomNav) highlighting `navRoute`, so
// the not-yet-built tabs stay reachable from the built ones.
// DELETE this file (and its wiring) once all screens are built.
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:universe_v1/core/theme/app_colors.dart';
import 'package:universe_v1/core/theme/app_spacing.dart';
import 'package:universe_v1/core/theme/app_text_styles.dart';
import 'package:universe_v1/features/auth/controllers/auth_controller.dart';
import 'package:universe_v1/shared/widgets/app_bottom_nav.dart';
import 'package:universe_v1/shared/widgets/u_button.dart';

class PlaceholderScreen extends StatelessWidget {
  final String title;

  /// When both [authController] and [navRoute] are set, renders the
  /// role-aware bottom nav highlighting [navRoute]. Null = no nav
  /// (e.g. a secondary screen).
  final AuthController? authController;
  final String? navRoute;

  /// Temporary links to built screens that don't yet have a permanent
  /// entry point (e.g. Resources hangs off the not-yet-built dashboard).
  /// Rendered as secondary buttons. Remove when the real screen lands.
  final List<({String label, String route})> quickLinks;

  const PlaceholderScreen({
    super.key,
    required this.title,
    this.authController,
    this.navRoute,
    this.quickLinks = const [],
  });

  @override
  Widget build(BuildContext context) {
    final showNav = authController != null && navRoute != null;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        title: Text(title, style: AppTextStyles.h2),
      ),
      bottomNavigationBar: showNav
          ? AppBottomNav(
              role: authController!.role,
              currentRoute: navRoute!,
            )
          : null,
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
            if (quickLinks.isNotEmpty) ...[
              AppSpacing.xxlGap,
              for (final link in quickLinks)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.x4l,
                    vertical: AppSpacing.xs,
                  ),
                  child: UButton(
                    label: link.label,
                    variant: UButtonVariant.secondary,
                    onPressed: () => context.push(link.route),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
