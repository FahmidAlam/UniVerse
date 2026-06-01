// ============================================================
// FILE: lib/features/auth/widgets/onboard_slide.dart
// PURPOSE: A single slide in the onboarding PageView.
// Receives icon, title, and description — renders them
// centered with the UniVerse design system.
// ============================================================

import 'package:flutter/material.dart';
import 'package:universe_v1/core/app_colors.dart';
import 'package:universe_v1/core/app_spacing.dart';
import 'package:universe_v1/core/app_text_styles.dart';

class OnboardSlide extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color iconColor;

  const OnboardSlide({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.iconColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.screenPadding,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon container
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: AppSpacing.radiusXl,
              border: Border.all(
                color: iconColor.withValues(alpha: 0.2),
                width: AppSpacing.borderNormal,
              ),
            ),
            child: Icon(
              icon,
              size: 44,
              color: iconColor,
            ),
          ),

          const SizedBox(height: AppSpacing.x3l),

          // Title
          Text(
            title,
            style: AppTextStyles.onboardTitle,
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppSpacing.md),

          // Description
          Text(
            description,
            style: AppTextStyles.onboardBody,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}