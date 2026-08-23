// ============================================================
// FILE: lib/shared/widgets/explore_fab_menu.dart
// PURPOSE: Floating action button with menu for Rooms and Find Teacher.
// Shows a magnifying glass icon and opens a bottom sheet with options.
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/core/router/route_names.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';

class ExploreFabMenu extends StatelessWidget {
  const ExploreFabMenu({super.key});

  void _showExploreMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXlD),
        ),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Explore',
                style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary),
              ),
              SizedBox(height: AppSpacing.lg),
              // Rooms option
              _MenuOption(
                icon: PhosphorIconsRegular.door,
                title: 'Rooms',
                subtitle: 'Check room availability',
                onTap: () {
                  Navigator.pop(context);
                  context.push(RouteNames.rooms);
                },
              ),
              SizedBox(height: AppSpacing.md),
              // Find Teacher option
              _MenuOption(
                icon: PhosphorIconsRegular.person,
                title: 'Find Teacher',
                subtitle: 'Locate teacher by room',
                onTap: () {
                  Navigator.pop(context);
                  context.push(RouteNames.findTeacher);
                },
              ),
              SizedBox(height: AppSpacing.lg),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _showExploreMenu(context),
      backgroundColor: AppColors.primary,
      elevation: 4,
      child: Icon(
        PhosphorIconsRegular.magnifyingGlass,
        color: AppColors.textPrimary,
        size: AppSpacing.iconMd,
      ),
    );
  }
}

class _MenuOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: AppSpacing.radiusMd,
          border: Border.all(
            color: AppColors.border,
            width: AppSpacing.borderThin,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: AppSpacing.radiusMd,
              ),
              child: Icon(
                icon,
                color: AppColors.primary,
                size: AppSpacing.iconMd,
              ),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              PhosphorIconsRegular.caretRight,
              color: AppColors.textMuted,
              size: AppSpacing.iconMd,
            ),
          ],
        ),
      ),
    );
  }
}
