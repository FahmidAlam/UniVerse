import 'package:flutter/material.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/admin/scheduling/controllers/scheduling_workspace_controller.dart';
import 'package:universe/features/admin/scheduling/models/scheduling_workspace_models.dart';
import 'package:universe/features/admin/scheduling/widgets/distribution/distribution_record_inspector.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';

/// Touch-friendly, card-based mobile presentation for Course Distribution records.
/// Avoids crushed table columns by providing scannable cards with a modal inspector.
class DistributionListMobile extends StatelessWidget {
  final SchedulingWorkspaceController controller;

  const DistributionListMobile({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final records = controller.filteredRecords;

        if (records.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    PhosphorIconsRegular.funnelX,
                    size: 36,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text('No matching records', style: AppTextStyles.h4),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Try adjusting your search query or filter chips.',
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.border),
                    ),
                    onPressed: controller.resetFilters,
                    icon: const Icon(PhosphorIconsRegular.arrowsClockwise, size: 14),
                    label: const Text('Reset Filters'),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          itemCount: records.length,
          separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final record = records[index];
            return _buildRecordCard(context, record);
          },
        );
      },
    );
  }

  Widget _buildRecordCard(BuildContext context, DistributionSourceRecord r) {
    final isSelected = controller.selectedRecord?.row == r.row;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.border,
          width: isSelected ? 1.5 : 1.0,
        ),
        borderRadius: AppSpacing.radiusMd,
      ),
      child: InkWell(
        onTap: () {
          controller.selectRecord(r);
          _showMobileInspectorBottomSheet(context, r);
        },
        borderRadius: AppSpacing.radiusMd,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top line: Row number + Batch/Section chip + Status
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.bgElevated,
                      borderRadius: AppSpacing.radiusSm,
                    ),
                    child: Text(
                      'Row ${r.row} · ${r.batch} ${r.section}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: r.section.contains('+')
                            ? AppColors.warning
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  _buildStatusChip(r),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              // Course Code and Title
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.courseCode,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      r.courseTitle,
                      style: AppTextStyles.bodySmMedium.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              // Meta Row: Teacher, Credits, Department
              Row(
                children: [
                  const Icon(
                    PhosphorIconsRegular.user,
                    size: 13,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      r.teacher,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: r.isTeacherPending
                            ? AppColors.error
                            : AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: AppSpacing.radiusSm,
                    ),
                    child: Text(
                      '${r.credit} Cr',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.bgElevated,
                      borderRadius: AppSpacing.radiusSm,
                    ),
                    child: Text(
                      '${r.classesPerWeek}x/wk',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  const Icon(
                    PhosphorIconsRegular.caretRight,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
              // Conflict / Correction warning banner if present
              if (r.hasConflict) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: AppColors.errorSoft,
                    borderRadius: AppSpacing.radiusSm,
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        PhosphorIconsRegular.warningCircle,
                        size: 13,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          r.conflicts.first,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.error,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(DistributionSourceRecord r) {
    Color bg;
    Color fg;
    String label;

    switch (r.status) {
      case DistributionRecordStatus.conflict:
        bg = AppColors.errorSoft;
        fg = AppColors.error;
        label = 'Conflict';
        break;
      case DistributionRecordStatus.pendingTeacher:
        bg = AppColors.infoSoft;
        fg = AppColors.info;
        label = 'Pending';
        break;
      case DistributionRecordStatus.corrected:
        bg = AppColors.warningSoft;
        fg = AppColors.warning;
        label = 'Corrected';
        break;
      case DistributionRecordStatus.verified:
        // PHASE 5: "Checkbox Off = Gray" signaling discipline for verified baseline records.
        bg = AppColors.bgElevated;
        fg = AppColors.textSecondary;
        label = 'Verified';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppSpacing.radiusSm,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }

  void _showMobileInspectorBottomSheet(
    BuildContext context,
    DistributionSourceRecord record,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgPrimary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.88,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (sheetContext, scrollController) {
            return DistributionRecordInspector(
              controller: controller,
              scrollController: scrollController,
              isMobileModal: true,
            );
          },
        );
      },
    );
  }
}
