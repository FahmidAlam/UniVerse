import 'package:flutter/material.dart';
import 'package:universe_v1/core/theme/app_colors.dart';
import 'package:universe_v1/core/theme/app_spacing.dart';
import 'package:universe_v1/core/theme/app_text_styles.dart';
import 'package:universe_v1/shared/widgets/u_card.dart';

class StatCard extends StatelessWidget {
  final String number;
  final String label;
  final IconData? icon;
  final Color? color;

  const StatCard({
    super.key,
    required this.number,
    required this.label,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final statColor = color ?? AppColors.primary;

    return UCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: AppSpacing.iconMd, color: statColor),
            AppSpacing.smGap,
          ],
          Text(
            number,
            style: AppTextStyles.statNumber.copyWith(color: statColor),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: AppTextStyles.statLabel,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
