import 'package:flutter/material.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/shared/widgets/u_card.dart';

// PHASE 4: Hero presenter for Done-for-Today, Weekend, and Free-Day states with tomorrow preview support.
class MessageHeroCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color? accent;
  final String? badge;
  final String? secondaryText;
  final Widget? action;

  const MessageHeroCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.accent,
    this.badge,
    this.secondaryText,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppColors.success;

    return UCard(
      isTopLit: true,
      borderRadius: AppSpacing.radiusLg,
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 3,
            child: ColoredBox(color: color),
          ),
          Padding(
            padding: AppSpacing.cardPaddingLg,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppSpacing.heroCardHeight - AppSpacing.xl * 2,
              ),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (badge != null && badge!.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.14),
                          borderRadius: AppSpacing.radiusSm,
                          border: Border.all(
                            color: color.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          badge!,
                          style: AppTextStyles.badge.copyWith(color: color),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
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
                    Text(
                      title,
                      style: AppTextStyles.h3,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      message,
                      style: AppTextStyles.bodySm,
                      textAlign: TextAlign.center,
                    ),
                    if (secondaryText != null &&
                        secondaryText!.trim().isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.bgElevated,
                          borderRadius: AppSpacing.radiusSm,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          secondaryText!,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                    if (action != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      action!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
