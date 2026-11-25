import 'package:flutter/material.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/admin/scheduling/controllers/scheduling_workspace_controller.dart';
import 'package:universe/features/admin/scheduling/models/scheduling_workspace_models.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/shared/widgets/u_card.dart';

/// Readiness & Preflight Validation pane.
/// Scans accepted distribution, faculty availability, room pools, and policy snapshots
/// to produce an actionable go/no-go diagnostic before CP-SAT solving starts.
class SchedulingReadinessPane extends StatelessWidget {
  final SchedulingWorkspaceController controller;

  const SchedulingReadinessPane({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final items = controller.readinessItems;
        final criticalCount = items
            .where((i) =>
                i.severity == ReadinessSeverity.critical && !i.isResolved)
            .length;
        final warningCount =
            items.where((i) => i.severity == ReadinessSeverity.warning && !i.isResolved).length;
        final resolvedCount = items.where((i) => i.isResolved).length;

        final isGoForSolve = criticalCount == 0;
        final isArtifactsStale = controller.artifactFreshness.validationReportStatus ==
            ArtifactStatus.stale;

        return ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          children: [
            if (isArtifactsStale) ...[
              _buildStaleArtifactsBanner(context),
              const SizedBox(height: AppSpacing.md),
            ],
            _buildOverallStatusCard(
              context,
              isGo: isGoForSolve,
              criticalCount: criticalCount,
              warningCount: warningCount,
              resolvedCount: resolvedCount,
              totalCount: items.length,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'PREFLIGHT CHECKPOINTS & BLOCKERS',
              style: AppTextStyles.labelCaps.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.sm),
            // PHASE 5: Single top-lit UCard with 1px horizontal divider rows ("Walmart receipt" edge alignment).
            UCard(
              isTopLit: true,
              padding: EdgeInsets.zero,
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (context, index) =>
                    const Divider(color: AppColors.border, height: 1),
                itemBuilder: (context, index) =>
                    _buildCheckItem(context, items[index]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStaleArtifactsBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: AppSpacing.radiusMd,
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.45)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 620;
          final button = FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: AppColors.bgPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: controller.revalidateArtifacts,
            icon: const Icon(PhosphorIconsRegular.arrowsClockwise, size: 14),
            label: Text(
              'Re-run Preflight Validation',
              style: AppTextStyles.captionMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.bgPrimary,
              ),
            ),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    PhosphorIconsRegular.clockCounterClockwise,
                    color: AppColors.warning,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PREFLIGHT REPORT STALE FOR v${controller.currentRevisionNumber}',
                          style: AppTextStyles.labelCaps.copyWith(
                            color: AppColors.warning,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Course distribution corrections or policy parameters were updated after the last preflight run. Re-run preflight validation to synchronize validation report artifacts.',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isNarrow) ...[
                    const SizedBox(width: AppSpacing.md),
                    button,
                  ],
                ],
              ),
              if (isNarrow) ...[
                const SizedBox(height: AppSpacing.sm),
                SizedBox(width: double.infinity, child: button),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildOverallStatusCard(
    BuildContext context, {
    required bool isGo,
    required int criticalCount,
    required int warningCount,
    required int resolvedCount,
    required int totalCount,
  }) {
    final percent = ((resolvedCount / totalCount) * 100).round();

    final actionButton = !isGo
        ? FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primarySoft,
              foregroundColor: AppColors.primary,
            ),
            onPressed: () => controller.setTabIndex(0),
            child: const Text('Resolve Blockers'),
          )
        : FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.successSoft,
              foregroundColor: AppColors.success,
            ),
            onPressed: () => controller.setTabIndex(3),
            icon: const Icon(PhosphorIconsRegular.play, size: 14),
            label: const Text('Proceed to Generate'),
          );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppSpacing.radiusMd,
        border: Border.all(
          color: isGo
              ? AppColors.success.withValues(alpha: 0.4)
              : AppColors.error.withValues(alpha: 0.4),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 640;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isGo ? AppColors.successSoft : AppColors.errorSoft,
                      borderRadius: AppSpacing.radiusSm,
                    ),
                    child: Icon(
                      isGo
                          ? PhosphorIconsRegular.checkCircle
                          : PhosphorIconsRegular.warningCircle,
                      color: isGo ? AppColors.success : AppColors.error,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              isGo
                                  ? 'SOLVER READY (GO)'
                                  : 'PREFLIGHT BLOCKED (NO-GO)',
                              style: AppTextStyles.h4.copyWith(
                                fontSize: 13,
                                letterSpacing: 0.6,
                                color: isGo ? AppColors.success : AppColors.error,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.bgElevated,
                                borderRadius: AppSpacing.radiusSm,
                              ),
                              child: Text(
                                '$percent% Preflight Pass',
                                style: AppTextStyles.captionMedium.copyWith(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isGo
                              ? 'All critical academic prerequisites are satisfied. Ready to proceed to CP-SAT solver execution.'
                              : 'CP-SAT generation is blocked by $criticalCount critical issue. Resolve all blocking items to enable solve.',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isNarrow) ...[
                    const SizedBox(width: AppSpacing.md),
                    actionButton,
                  ],
                ],
              ),
              if (isNarrow) ...[
                const SizedBox(height: AppSpacing.sm),
                SizedBox(width: double.infinity, child: actionButton),
              ],
              const SizedBox(height: AppSpacing.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: resolvedCount / totalCount,
                  minHeight: 6,
                  backgroundColor: AppColors.bgElevated,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isGo ? AppColors.success : AppColors.warning,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: 6,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '$resolvedCount of $totalCount prerequisites verified',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: 4,
                    children: [
                      _statBadge('$criticalCount Critical', AppColors.error),
                      _statBadge('$warningCount Warnings', AppColors.warning),
                      _statBadge(
                        '$resolvedCount Verified',
                        AppColors.textSecondary,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _statBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: AppTextStyles.captionMedium.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  // PHASE 5: "Checkbox Off = Gray" signaling discipline:
  // Resolved/verified items dissolve into quiet, compact rows with muted slate-gray.
  // Unresolved BLOCKER and WARNING items carry prominent 3px left accent bars and responsive actions.
  Widget _buildCheckItem(BuildContext context, ReadinessItem item) {
    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    if (item.isResolved) {
      statusColor = AppColors.textMuted;
      statusIcon = PhosphorIconsRegular.checkCircle;
      statusLabel = 'VERIFIED';
    } else {
      switch (item.severity) {
        case ReadinessSeverity.critical:
          statusColor = AppColors.error;
          statusIcon = PhosphorIconsRegular.xCircle;
          statusLabel = 'BLOCKER';
          break;
        case ReadinessSeverity.warning:
          statusColor = AppColors.warning;
          statusIcon = PhosphorIconsRegular.warning;
          statusLabel = 'WARNING';
          break;
        case ReadinessSeverity.info:
          statusColor = AppColors.info;
          statusIcon = PhosphorIconsRegular.info;
          statusLabel = 'INFO';
          break;
      }
    }

    final actionButton = !item.isResolved
        ? OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: BorderSide(color: statusColor.withValues(alpha: 0.45)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () {
              controller.setTabIndex(item.targetTab);
              if (item.targetRow != null) {
                controller.selectRecordByRow(item.targetRow!);
              }
            },
            icon: const Icon(PhosphorIconsRegular.arrowSquareOut, size: 12),
            label: Text(
              item.targetTab == 0 ? 'Fix in Distribution' : 'Fix in Config',
              style: AppTextStyles.captionMedium.copyWith(fontSize: 11),
            ),
          )
        : null;

    return Container(
      decoration: BoxDecoration(
        color: item.isResolved
            ? Colors.transparent
            : statusColor.withValues(alpha: 0.06),
        border: item.isResolved
            ? null
            : Border(
                left: BorderSide(color: statusColor, width: 3),
              ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: item.isResolved ? AppSpacing.sm : AppSpacing.md,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(statusIcon, color: statusColor, size: 18),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: item.isResolved
                                    ? AppColors.bgElevated
                                    : statusColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                statusLabel,
                                style: AppTextStyles.labelCaps.copyWith(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: item.isResolved
                                      ? AppColors.textSecondary
                                      : statusColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            Text(
                              item.category,
                              style: AppTextStyles.captionMedium.copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.title,
                          style: AppTextStyles.bodySmMedium.copyWith(
                            color: item.isResolved
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                            fontWeight: item.isResolved
                                ? FontWeight.w600
                                : FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.description,
                          style: AppTextStyles.caption.copyWith(
                            color: item.isResolved
                                ? AppColors.textMuted
                                : AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        if (item.affectedEntities.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: item.affectedEntities.map((e) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.bgElevated,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  e,
                                  style: AppTextStyles.timeCode.copyWith(
                                    fontSize: 10,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!isNarrow && actionButton != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    actionButton,
                  ],
                ],
              ),
              if (isNarrow && actionButton != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: actionButton,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
