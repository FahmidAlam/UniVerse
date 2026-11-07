import 'package:flutter/material.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/admin/scheduling/controllers/scheduling_workspace_controller.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';

/// Context bar displaying the currently scoped academic distribution revision.
///
/// In live mode with no contract deployed, it truthfully reports that no accepted
/// revision is selected. In design-preview mode, it displays the full provenance
/// metadata for the reviewable Fall 2026 revision.
class SchedulingRevisionBar extends StatelessWidget {
  final SchedulingWorkspaceController controller;

  const SchedulingRevisionBar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final isPreview = controller.isPreviewMode;
        final rev = controller.revision;
        final isMobile = MediaQuery.of(context).size.width < 768;

        if (!isPreview && !controller.isLiveBackendReady) {
          return _buildLiveUnavailableContext(context);
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 1080;

            return Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? AppSpacing.md : AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: AppColors.bgElevated,
                border: Border.all(color: AppColors.border),
                borderRadius: AppSpacing.radiusMd,
              ),
              child: isCompact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              PhosphorIconsRegular.fileXls,
                              color: AppColors.success,
                              size: 18,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                '${rev.department} · ${rev.semester}',
                                style: AppTextStyles.bodySmMedium.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            _buildStatusChip(rev.status),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Rev #${rev.revisionNumber} (v${rev.revisionVersion})',
                              style: AppTextStyles.captionMedium.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                            Text(
                              '${controller.totalRecordsCount} rows · ${controller.correctionsCount} corr · ${controller.conflictsCount} clashes',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
                            if (controller.correctionsCount > 0) ...[
                              InkWell(
                                onTap: () => _showSealRevisionDialog(context),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primarySoft,
                                    borderRadius: AppSpacing.radiusSm,
                                    border: Border.all(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: const Text(
                                    'Seal Draft',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.successSoft,
                            borderRadius: AppSpacing.radiusSm,
                          ),
                          child: const Icon(
                            PhosphorIconsRegular.fileXls,
                            color: AppColors.success,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      'Scope: ${rev.department}',
                                      style: AppTextStyles.bodySmMedium.copyWith(
                                        color: AppColors.textPrimary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Text(
                                    '· ${rev.semester}',
                                    style: AppTextStyles.bodySm.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    'Revision: Accepted #${rev.revisionNumber} · v${rev.revisionVersion}',
                                    style: AppTextStyles.captionMedium.copyWith(
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Flexible(
                                    child: Text(
                                      'Hash: ${rev.sourceHash.substring(0, 12)}…',
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.textMuted,
                                        fontFamily: 'monospace',
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Wrap(
                          spacing: AppSpacing.xs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _buildMetricChip(
                              icon: PhosphorIconsRegular.rows,
                              label: '${controller.totalRecordsCount} rows',
                              color: AppColors.textSecondary,
                            ),
                            _buildMetricChip(
                              icon: PhosphorIconsRegular.pencilSimple,
                              label: '${controller.correctionsCount} corr',
                              color: AppColors.warning,
                            ),
                            _buildMetricChip(
                              icon: PhosphorIconsRegular.warningCircle,
                              label: '${controller.conflictsCount} clashes',
                              color: controller.conflictsCount > 0
                                  ? AppColors.error
                                  : AppColors.success,
                            ),
                            const SizedBox(width: 4),
                            _buildStatusChip(rev.status),
                            if (controller.correctionsCount > 0) ...[
                              const SizedBox(width: 4),
                              FilledButton.tonalIcon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primarySoft,
                                  foregroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () => _showSealRevisionDialog(context),
                                icon: const Icon(
                                  PhosphorIconsRegular.shieldCheck,
                                  size: 13,
                                ),
                                label: const Text(
                                  'Seal Revision',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 2),
                              IconButton(
                                tooltip: 'Reset corrections to baseline',
                                icon: const Icon(
                                  PhosphorIconsRegular.arrowCounterClockwise,
                                  size: 13,
                                  color: AppColors.textMuted,
                                ),
                                onPressed: controller.resetToBaseline,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 24,
                                  minHeight: 24,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
            );
          },
        );
      },
    );
  }

  void _showSealRevisionDialog(BuildContext context) {
    final reasonCtrl = TextEditingController(
      text: 'Accepted Departmental Distribution Baseline with Faculty Overlays',
    );
    final authorCtrl = TextEditingController(
      text: 'Admin (Academic Timetable Lead)',
    );

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: Row(
          children: [
            const Icon(
              PhosphorIconsRegular.shieldCheck,
              color: AppColors.primary,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Seal Revision #${controller.revision.revisionNumber + 1}',
              style: AppTextStyles.h4,
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This creates a sealed, immutable accepted revision snapshot incorporating ${controller.correctionsCount} audited correction(s). '
                'Downstream engine normalization and CP-SAT solver inputs will bind directly to this new revision.',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Acceptance Reason / Resolution Reference',
                  hintText: 'e.g. Approved joint sections & lab assignments',
                  isDense: true,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: authorCtrl,
                decoration: const InputDecoration(
                  labelText: 'Approving Authority',
                  hintText: 'e.g. Dept Chair / Academic Committee',
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textPrimary,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              controller.sealDraftRevision(
                reason: reasonCtrl.text.trim(),
                author: authorCtrl.text.trim(),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.bgElevated,
                  content: Text(
                    'Sealed Revision #${controller.revision.revisionNumber} (v1) created successfully.',
                    style: const TextStyle(color: AppColors.success),
                  ),
                ),
              );
            },
            child: const Text('Confirm & Seal Snapshot'),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveUnavailableContext(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        border: Border.all(color: AppColors.border),
        borderRadius: AppSpacing.radiusMd,
      ),
      child: Wrap(
        spacing: AppSpacing.xl,
        runSpacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Icon(PhosphorIconsRegular.fileXls, color: AppColors.textMuted),
          Text(
            'No accepted distribution revision selected',
            style: AppTextStyles.bodySmMedium,
          ),
          Text(
            'A scoped, accepted revision is required before scheduling can begin.',
            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.successSoft,
        borderRadius: AppSpacing.radiusSm,
        border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            status.toUpperCase(),
            style: AppTextStyles.caption.copyWith(
              color: AppColors.success,
              fontWeight: FontWeight.bold,
              fontSize: 10,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bgPrimary,
        borderRadius: AppSpacing.radiusSm,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.captionMedium.copyWith(
              color: color,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
