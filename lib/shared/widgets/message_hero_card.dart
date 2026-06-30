import 'package:flutter/material.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/shared/widgets/u_card.dart';

class MessageHeroCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color? accent;

  const MessageHeroCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppColors.success;

    return UCard(
      child: SizedBox(
        height: AppSpacing.heroCardHeight - AppSpacing.lg * 2,
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: AppSpacing.x4l,
              height: AppSpacing.x4l,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: AppSpacing.radiusMd,
              ),
              child: Icon(icon, size: AppSpacing.iconLg, color: color),
            ),
            AppSpacing.mdGap,
            Text(title, style: AppTextStyles.h3, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              style: AppTextStyles.bodySm,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
