import 'package:universe/core/theme/app_motion.dart';
import 'package:universe/shared/widgets/u_pressable_scale.dart';
import 'package:flutter/material.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/admin/scheduling/controllers/scheduling_workspace_controller.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';

/// Toolbar with search, filters, quick toggles, and inspector toggle for Course Distribution.
class DistributionFiltersBar extends StatelessWidget {
  final SchedulingWorkspaceController controller;

  const DistributionFiltersBar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 650;

            return Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                border: Border.all(color: AppColors.border),
                borderRadius: AppSpacing.radiusMd,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isNarrow) ...[
                    // Narrow: Search field on top row
                    SizedBox(
                      height: 38,
                      child: _buildSearchField(),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // Narrow: Dropdowns on second row
                    Row(
                      children: [
                        Expanded(
                          child: _buildDropdown<String>(
                            label: 'Batch',
                            value: controller.selectedBatch,
                            items: controller.availableBatches,
                            onChanged: controller.setBatchFilter,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _buildDropdown<String>(
                            label: 'Section',
                            value: controller.selectedSection,
                            items: controller.availableSections,
                            onChanged: controller.setSectionFilter,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    // Desktop / Wide: All in single row
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: SizedBox(
                            height: 38,
                            child: _buildSearchField(),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _buildDropdown<String>(
                          label: 'Batch',
                          value: controller.selectedBatch,
                          items: controller.availableBatches,
                          onChanged: controller.setBatchFilter,
                          width: 110,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _buildDropdown<String>(
                          label: 'Section',
                          value: controller.selectedSection,
                          items: controller.availableSections,
                          onChanged: controller.setSectionFilter,
                          width: 115,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _buildDropdown<String>(
                          label: 'Dept',
                          value: controller.selectedDept,
                          items: controller.availableDepartments,
                          onChanged: controller.setDeptFilter,
                          width: 105,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _buildInspectorToggle(),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  // Filter chips row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _filterChip(
                          context,
                          label: 'Conflicts (${controller.conflictsCount})',
                          icon: PhosphorIconsRegular.warningCircle,
                          isActive: controller.onlyConflicts,
                          activeColor: AppColors.error,
                          onTap: () => controller
                              .setOnlyConflicts(!controller.onlyConflicts),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        _filterChip(
                          context,
                          label: 'Corrected (${controller.correctionsCount})',
                          icon: PhosphorIconsRegular.pencilSimple,
                          isActive: controller.onlyCorrected,
                          activeColor: AppColors.warning,
                          onTap: () => controller
                              .setOnlyCorrected(!controller.onlyCorrected),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        _filterChip(
                          context,
                          label:
                              'Pending Teacher (${controller.pendingTeacherCount})',
                          icon: PhosphorIconsRegular.userCircleDashed,
                          isActive: controller.onlyPendingTeacher,
                          activeColor: AppColors.info,
                          onTap: () => controller.setOnlyPendingTeacher(
                              !controller.onlyPendingTeacher),
                        ),
                        if (controller.selectedBatch != null ||
                            controller.selectedSection != null ||
                            controller.selectedDept != null ||
                            controller.onlyConflicts ||
                            controller.onlyCorrected ||
                            controller.onlyPendingTeacher ||
                            controller.searchQuery.isNotEmpty) ...[
                          const SizedBox(width: AppSpacing.sm),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: controller.resetFilters,
                            icon: const Icon(
                              PhosphorIconsRegular.xCircle,
                              size: 14,
                              color: AppColors.textMuted,
                            ),
                            label: Text(
                              'Clear Filters',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSearchField() {
    return TextField(
      onChanged: controller.setSearchQuery,
      style: AppTextStyles.bodySm.copyWith(
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: 'Search course code, title, teacher, or row #…',
        hintStyle: AppTextStyles.caption.copyWith(
          color: AppColors.textMuted,
        ),
        prefixIcon: const Icon(
          PhosphorIconsRegular.magnifyingGlass,
          size: 16,
          color: AppColors.textMuted,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 0,
        ),
        filled: true,
        fillColor: AppColors.bgPrimary,
        border: OutlineInputBorder(
          borderRadius: AppSpacing.radiusSm,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppSpacing.radiusSm,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppSpacing.radiusSm,
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    double? width,
  }) {
    return Container(
      height: 38,
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.bgPrimary,
        border: Border.all(color: AppColors.border),
        borderRadius: AppSpacing.radiusSm,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T?>(
          value: value,
          isDense: true,
          isExpanded: true,
          hint: Text(
            label,
            style: AppTextStyles.captionMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          icon: const Icon(
            PhosphorIconsRegular.caretDown,
            size: 13,
            color: AppColors.textMuted,
          ),
          dropdownColor: AppColors.bgCard,
          items: [
            DropdownMenuItem<T?>(
              value: null,
              child: Text(
                'All $label',
                style: AppTextStyles.bodySm.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            ...items.map(
              (item) => DropdownMenuItem<T?>(
                value: item,
                child: Text(
                  item.toString(),
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _filterChip(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return Semantics(
      selected: isActive,
      child: UPressableScale(
          child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.radiusSm,
        child: AnimatedContainer(
          duration: AppMotion.duration(context, AppMotion.fast),
          curve: AppMotion.snappy,
          constraints: BoxConstraints(
              minHeight: MediaQuery.sizeOf(context).width < 768 ? 48 : 40),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isActive
                ? activeColor.withValues(alpha: 0.15)
                : AppColors.bgPrimary,
            border: Border.all(
              color: isActive ? activeColor : AppColors.border,
              width: isActive ? 1.5 : 1.0,
            ),
            borderRadius: AppSpacing.radiusSm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13,
                color: isActive ? activeColor : AppColors.textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: AppTextStyles.captionMedium.copyWith(
                  color: isActive ? activeColor : AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      )),
    );
  }

  Widget _buildInspectorToggle() {
    return IconButton(
      tooltip: controller.isInspectorOpen
          ? 'Hide Record Inspector'
          : 'Show Record Inspector',
      icon: Icon(
        PhosphorIconsRegular.sidebarSimple,
        size: 18,
        color: controller.isInspectorOpen
            ? AppColors.primary
            : AppColors.textSecondary,
      ),
      style: IconButton.styleFrom(
        backgroundColor: controller.isInspectorOpen
            ? AppColors.primarySoft
            : AppColors.bgPrimary,
        side: BorderSide(
          color: controller.isInspectorOpen
              ? AppColors.primary.withValues(alpha: 0.4)
              : AppColors.border,
        ),
      ),
      onPressed: controller.toggleInspector,
    );
  }
}
