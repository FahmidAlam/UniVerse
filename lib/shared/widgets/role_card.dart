import 'package:flutter/material.dart';
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
      onTap: onTap,
      border: Border.all(
        color: isSelected ? color : AppColors.border,
        width: isSelected ? AppSpacing.borderNormal : AppSpacing.borderThin,
      ),
      color: isSelected ? color.withValues(alpha: 0.08) : AppColors.bgCard,
      child: Row(
        children: [
          Container(
            width: AppSpacing.iconXl,
            height: AppSpacing.iconXl,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: AppSpacing.radiusMd,
            ),
            child: Icon(icon, size: AppSpacing.iconMd, color: color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  role[0].toUpperCase() + role.substring(1),
                  style: AppTextStyles.h4.copyWith(
                    color: isSelected ? color : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(description, style: AppTextStyles.bodySm),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
