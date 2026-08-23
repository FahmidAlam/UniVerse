// ============================================================
// FILE: lib/features/auth/screens/placeholder_screen.dart
// PURPOSE: Temporary screen for routes not yet built.
// Shows the screen name so navigation can be tested
// end-to-end before each feature screen is implemented.
// The bottom nav comes from AppShell — nothing to declare here.
// DELETE this file (and its wiring) once all screens are built.
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/shared/widgets/u_button.dart';

class PlaceholderScreen extends StatelessWidget {
  final String title;

  /// Temporary links to built screens that don't yet have a permanent
  /// entry point (e.g. Resources hangs off the not-yet-built dashboard).
  /// Rendered as secondary buttons. Remove when the real screen lands.
  final List<({String label, String route})> quickLinks;

  const PlaceholderScreen({
    super.key,
    required this.title,
    this.quickLinks = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        title: Text(title, style: AppTextStyles.h2),
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
