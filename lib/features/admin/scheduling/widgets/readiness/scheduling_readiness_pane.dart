import 'package:flutter/material.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/admin/scheduling/controllers/scheduling_workspace_controller.dart';
import 'package:universe/features/admin/scheduling/models/scheduling_workspace_models.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';

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
        final criticalCount =
            items.where((i) => i.severity == ReadinessSeverity.critical && !i.isResolved).length;
        final warningCount =
            items.where((i) => i.severity == ReadinessSeverity.warning && !i.isResolved).length;
        final resolvedCount = items.where((i) => i.isResolved).length;

        final isGoForSolve = criticalCount == 0;

        return ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          children: [
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
            ...items.map((item) => _buildCheckItem(context, item)),
          ],
        );
      },
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

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppSpacing.radiusMd,
        border: Border.all(
          color: isGo ? AppColors.success.withValues(alpha: 0.4) : AppColors.error.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                    Row(
                      children: [
                        Text(
                          isGo ? 'SOLVER READY (GO)' : 'PREFLIGHT BLOCKED (NO-GO)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.6,
                            color: isGo ? AppColors.success : AppColors.error,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.bgElevated,
                            borderRadius: AppSpacing.radiusSm,
                          ),
                          child: Text(
                            '$percent% Preflight Pass',
                            style: const TextStyle(
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
              if (!isGo) ...[
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primarySoft,
                    foregroundColor: AppColors.primary,
                  ),
                  onPressed: () => controller.setTabIndex(0),
                  child: const Text('Resolve Blockers'),
                ),
              ] else ...[
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.successSoft,
                    foregroundColor: AppColors.success,
                  ),
                  onPressed: () => controller.setTabIndex(3),
                  icon: const Icon(PhosphorIconsRegular.play, size: 14),
                  label: const Text('Proceed to Generate'),
                ),
              ],
            ],
          ),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$resolvedCount of $totalCount prerequisites verified',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              Row(
                children: [
                  _statBadge('$criticalCount Critical', AppColors.error),
                  const SizedBox(width: AppSpacing.xs),
                  _statBadge('$warningCount Warnings', AppColors.warning),
                  const SizedBox(width: AppSpacing.xs),
                  _statBadge('$resolvedCount Verified', AppColors.success),
                ],
              ),
            ],
          ),
        ],
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
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildCheckItem(BuildContext context, ReadinessItem item) {
    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    if (item.isResolved) {
      statusColor = AppColors.success;
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

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        border: Border.all(
          color: item.isResolved ? AppColors.border : statusColor.withValues(alpha: 0.3),
        ),
        borderRadius: AppSpacing.radiusMd,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(statusIcon, color: statusColor, size: 18),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      item.category,
                      style: const TextStyle(
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
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.description,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
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
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.bgElevated,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          e,
                          style: const TextStyle(
                            fontFamily: 'monospace',
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
          if (!item.isResolved) ...[
            const SizedBox(width: AppSpacing.sm),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.border),
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
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
