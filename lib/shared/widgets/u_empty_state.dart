import 'package:flutter/material.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';

class UEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final Color? iconColor;

  const UEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? AppColors.textMuted;

    return Center(
      child: Padding(
        padding: AppSpacing.screenPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: AppSpacing.x5l,
              height: AppSpacing.x5l,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: AppSpacing.radiusLg,
              ),
              child: Icon(icon, size: AppSpacing.iconXl, color: color),
            ),
            AppSpacing.lgGap,
            Text(title, style: AppTextStyles.h3, textAlign: TextAlign.center),
            if (message != null) ...[
              AppSpacing.smGap,
              Text(
                message!,
                style: AppTextStyles.bodySm,
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              AppSpacing.lgGap,
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
