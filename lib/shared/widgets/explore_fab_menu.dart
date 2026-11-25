import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/core/router/route_names.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/shared/widgets/u_adaptive_overlay.dart';

class ExploreFabMenu extends StatelessWidget {
  const ExploreFabMenu({super.key});

  void _showExploreMenu(BuildContext context) {
    showUAdaptiveModal<void>(
      context: context,
      title: 'Explore',
      subtitle: 'Quick campus lookup shortcuts',
      icon: PhosphorIconsRegular.magnifyingGlass,
      builder: (sheetContext) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MenuOption(
              icon: PhosphorIconsRegular.door,
              title: 'Rooms',
              subtitle: 'Check room availability',
              onTap: () {
                Navigator.pop(sheetContext);
                context.push(RouteNames.rooms);
              },
            ),
            const SizedBox(height: AppSpacing.md),
            _MenuOption(
              icon: PhosphorIconsRegular.person,
              title: 'Find Teacher',
              subtitle: 'Locate teacher by room',
              onTap: () {
                Navigator.pop(sheetContext);
                context.push(RouteNames.findTeacher);
              },
            ),
          ],
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
