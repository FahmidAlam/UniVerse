import 'package:flutter/material.dart';
import 'package:universe/core/theme/app_motion.dart';
import 'package:universe/shared/widgets/u_animated_swap.dart';
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/shared/widgets/u_card.dart';

class RoleCard extends StatelessWidget {
  final String role;
  final String description;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const RoleCard({
    super.key,
    required this.role,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  Color get _roleColor {
    switch (role) {
      case AppConstants.roleTeacher:
        return AppColors.roleTeacher;
      case AppConstants.roleAdmin:
        return AppColors.roleAdmin;
      default:
        return AppColors.roleStudent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _roleColor;

    return UCard(
      isTopLit: true,
      padding: EdgeInsets.zero,
      onTap: onTap,
      border: Border.all(
        color: isSelected ? color : AppColors.border,
        width: isSelected ? AppSpacing.borderNormal : AppSpacing.borderThin,
      ),
      color: isSelected ? color.withValues(alpha: 0.08) : AppColors.bgCard,
      child: IntrinsicHeight(
        child: Row(
          children: [
            AnimatedContainer(
              duration: AppMotion.duration(context, AppMotion.fast),
              width: 3,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isSelected ? 1 : 0.3),
                borderRadius: AppSpacing.radiusSm,
              ),
            ),
            Expanded(
                child: Padding(
                    padding: AppSpacing.cardPadding,
                    child: Row(children: [
                      Container(
                        width: AppSpacing.iconXl,
                        height: AppSpacing.iconXl,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: AppSpacing.radiusMd,
                        ),
                        child:
                            Icon(icon, size: AppSpacing.iconMd, color: color),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              role[0].toUpperCase() + role.substring(1),
                              style: AppTextStyles.h4.copyWith(
                                color:
                                    isSelected ? color : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(description, style: AppTextStyles.bodySm),
                            const SizedBox(height: AppSpacing.sm),
                            Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm,
                                    vertical: AppSpacing.xs),
                                decoration: BoxDecoration(
                                    color: color.withValues(alpha: .1),
                                    borderRadius: AppSpacing.radiusSm),
                                child: Text(
                                  role == AppConstants.roleTeacher
                                      ? 'TEACHING & TOOLS'
                                      : role == AppConstants.roleAdmin
                                          ? 'ENGINE & GOVERNANCE'
                                          : 'COHORT ROUTINE',
                                  style: AppTextStyles.badge
                                      .copyWith(color: color),
                                )),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      UAnimatedSwap(
                          child: Icon(
                        isSelected
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        key: ValueKey(isSelected),
                        color: isSelected ? color : AppColors.textMuted,
                        size: AppSpacing.iconMd,
                      )),
                    ]))),
          ],
        ),
      ),
    );
  }
}
