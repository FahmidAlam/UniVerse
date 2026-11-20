import 'package:universe/shared/widgets/u_segmented_control.dart';
// PHASE 1: Custom mobile headers retain shell account access too.
import 'package:universe/shared/widgets/desktop_shell_scope.dart';
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
        return LayoutBuilder(
          builder: (context, constraints) {
            // PHASE 5: Drive header layout from LayoutBuilder usable width so 390px never clips.
            final isNarrow = constraints.maxWidth < 680;

            return Container(
              padding: EdgeInsets.symmetric(
                horizontal: isNarrow ? AppSpacing.md : AppSpacing.lg,
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
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                              runSpacing: 4,
                              children: [
                                Text(
                                  // PHASE 1 RECONCILE: Preserve workspace heading for regressions while repeating preview boundary.
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
                                        style:
                                            AppTextStyles.captionMedium.copyWith(
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
                                if (isPreview)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.bgElevated,
                                      borderRadius: AppSpacing.radiusFull,
                                      border:
                                          Border.all(color: AppColors.border),
                                    ),
                                    child: Text(
                                      'SIMULATED PREVIEW · NO DATABASE WRITES',
                                      style: AppTextStyles.caption.copyWith(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                        color: AppColors.textMuted,
                                      ),
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
                      // PHASE 1: The custom workbench header also exposes mobile account access.
                      if (DesktopShellScope.maybeOf(context)?.isDesktop == false)
                        const ProfileAccountAction(),
                      if (!isNarrow) ...[
                        _buildModeToggle(context, isPreview, isCompact: false),
                        const SizedBox(width: AppSpacing.sm),
                        _buildRefreshButton(context),
                      ],
                    ],
                  ),
                  if (isNarrow) ...[
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: _buildModeToggle(
                            context,
                            isPreview,
                            isCompact: true,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _buildRefreshButton(context),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModeToggle(
    BuildContext context,
    bool isPreview, {
    required bool isCompact,
  }) {
    final control = USegmentedControl<bool>(
      compact: true,
      selected: isPreview,
      onChanged: controller.togglePreviewMode,
      segments: [
        USegment(
            value: false,
            label: isCompact ? 'Live' : 'Live Backend',
            icon: PhosphorIconsRegular.database),
        USegment(
            value: true,
            label: isCompact ? 'Preview' : 'Design Preview',
            icon: PhosphorIconsRegular.sparkle),
      ],
    );
    if (isCompact) return control;
    return SizedBox(width: 310, child: control);
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
