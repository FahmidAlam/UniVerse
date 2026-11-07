import 'package:flutter/material.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/admin/scheduling/controllers/scheduling_workspace_controller.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';

/// Top header bar for the Scheduling Workspace.
/// Features workspace title, scope context, and the Mode Switcher (Live vs Preview).
class SchedulingHeaderBar extends StatelessWidget {
  final SchedulingWorkspaceController controller;

  const SchedulingHeaderBar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final isPreview = controller.isPreviewMode;
        final isMobile = MediaQuery.of(context).size.width < 768;

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? AppSpacing.md : AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            border: Border.all(color: AppColors.border),
            borderRadius: AppSpacing.radiusMd,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top line: Title & Actions
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: AppSpacing.radiusMd,
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(
                      PhosphorIconsRegular.stack,
                      color: AppColors.primary,
                      size: AppSpacing.iconMd,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: AppSpacing.sm,
                          runSpacing: 2,
                          children: [
                            Text(
                              'Scheduling Workspace',
                              style: AppTextStyles.h2.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isPreview
                                    ? AppColors.infoSoft
                                    : AppColors.bgElevated,
                                border: Border.all(
                                  color: isPreview
                                      ? AppColors.info.withValues(alpha: 0.5)
                                      : AppColors.border,
                                ),
                                borderRadius: AppSpacing.radiusFull,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isPreview
                                        ? PhosphorIconsRegular.eye
                                        : PhosphorIconsRegular.database,
                                    size: 11,
                                    color: isPreview
                                        ? AppColors.info
                                        : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isPreview
                                        ? 'DESIGN PREVIEW'
                                        : 'LIVE BACKEND',
                                    style: AppTextStyles.captionMedium.copyWith(
                                      color: isPreview
                                          ? AppColors.info
                                          : AppColors.textSecondary,
                                      fontSize: 10,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Prepare, configure, and inspect traceable timetable scheduling inputs.',
                          style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isMobile) ...[
                    _buildModeToggle(context, isPreview, isCompact: false),
                    const SizedBox(width: AppSpacing.sm),
                    _buildRefreshButton(context),
                  ],
                ],
              ),
              if (isMobile) ...[
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildModeToggle(context, isPreview, isCompact: true),
                    _buildRefreshButton(context),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildModeToggle(
    BuildContext context,
    bool isPreview, {
    required bool isCompact,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgPrimary,
        borderRadius: AppSpacing.radiusFull,
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _modeButton(
            title: isCompact ? 'Live' : 'Live Backend',
            icon: PhosphorIconsRegular.database,
            isActive: !isPreview,
            onTap: () => controller.togglePreviewMode(false),
          ),
          _modeButton(
            title: isCompact ? 'Preview' : 'Design Preview',
            icon: PhosphorIconsRegular.sparkle,
            isActive: isPreview,
            onTap: () => controller.togglePreviewMode(true),
          ),
        ],
      ),
    );
  }

  Widget _modeButton({
    required String title,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppSpacing.radiusFull,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.transparent,
          borderRadius: AppSpacing.radiusFull,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isActive ? AppColors.textPrimary : AppColors.textMuted,
            ),
            const SizedBox(width: 5),
            Text(
              title,
              style: AppTextStyles.captionMedium.copyWith(
                color: isActive ? AppColors.textPrimary : AppColors.textMuted,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRefreshButton(BuildContext context) {
    return IconButton(
      tooltip: 'Recheck Supabase backend contracts',
      icon: const Icon(PhosphorIconsRegular.arrowsClockwise, size: 16),
      style: IconButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        backgroundColor: AppColors.bgPrimary,
        side: const BorderSide(color: AppColors.border),
      ),
      onPressed: () => controller.checkBackendAvailability(),
    );
  }
}
