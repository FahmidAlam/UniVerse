import 'routine_convergence_showcase.dart';
import 'package:flutter/material.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';

class OnboardSlide extends StatelessWidget {
  final int stage;
  final bool showVisual;
  final IconData icon;
  final String title;
  final String description;
  final Color iconColor;

  const OnboardSlide({
    super.key,
    this.stage = 0,
    this.showVisual = true,
    required this.icon,
    required this.title,
    required this.description,
    this.iconColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // PHASE 3: Bounded mobile illustration; desktop art lives in the shell.
          if (showVisual) ...[
            RoutineConvergenceShowcase(
                stage: stage, compact: true, interactive: false),
            AppSpacing.lgGap,
          ],
          Text(
            title,
            style: AppTextStyles.onboardTitle,
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppSpacing.md),

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
