// ============================================================
// FILE: lib/features/auth/screens/placeholder_screen.dart
// PURPOSE: Temporary screen for routes not yet built.
// Shows the screen name so navigation can be tested
// end-to-end before each feature screen is implemented.
// DELETE this file once all screens are built.
// ============================================================

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:universe_v1/core/theme/app_colors.dart';
import 'package:universe_v1/core/theme/app_spacing.dart';
import 'package:universe_v1/core/theme/app_text_styles.dart';

class PlaceholderScreen extends StatelessWidget {
  final String title;

  const PlaceholderScreen({super.key, required this.title});

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
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: AppSpacing.radiusXl,
              ),
              child: const Icon(
                PhosphorIconsRegular.wrench,
                color: AppColors.primary,
                size: 36,
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