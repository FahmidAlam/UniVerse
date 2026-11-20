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
  // PHASE 5: Allow medium-tier desktop layouts to open the inspector in an adaptive modal.
  final VoidCallback? onToggleInspector;

  const DistributionFiltersBar({
    super.key,
    required this.controller,
    this.onToggleInspector,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final controlWidth = constraints.maxWidth < 650
                ? (constraints.maxWidth -
                        AppSpacing.md * 2 -
                        AppSpacing.sm -
                        2) /
                    2
                : 144.0;

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
                  // PHASE 5: Above-field labels cannot intersect control borders.
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.md,
                    crossAxisAlignment: WrapCrossAlignment.end,
                    children: [
                      SizedBox(
                        width: constraints.maxWidth < 650
                            ? constraints.maxWidth - AppSpacing.md * 2 - 2
                            : 280,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('SEARCH',
                                style: AppTextStyles.labelCaps
                                    .copyWith(color: AppColors.textMuted)),
                            const SizedBox(height: AppSpacing.xs),
                            SizedBox(
                                height: 48, child: _buildSearchField(context)),
                          ],
                        ),
                      ),
                      _buildDropdown<String>(
                        context,
                        label: 'Batch',
                        value: controller.selectedBatch,
                        items: controller.availableBatches,
                        onChanged: controller.setBatchFilter,
                        width: controlWidth,
                      ),
                      _buildDropdown<String>(
                        context,
                        label: 'Section',
                        value: controller.selectedSection,
                        items: controller.availableSections,
                        onChanged: controller.setSectionFilter,
                        width: controlWidth,
                      ),
                      _buildDropdown<String>(
                        context,
                        label: 'Dept',
                        value: controller.selectedDept,
                        items: controller.availableDepartments,
                        onChanged: controller.setDeptFilter,
                        width: controlWidth,
                      ),
                      _buildInspectorToggle(),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Filter chips row with upfront option count pill
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // PHASE 5: Upfront live match count pill before/as you click filters.
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.bgElevated,
                            borderRadius: AppSpacing.radiusSm,
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            'Showing ${controller.filteredRecords.length} of ${controller.totalRecordsCount} offerings',
                            style: AppTextStyles.numeric.copyWith(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        // PHASE B / C: 1-Tap bridge to synthesize and preview distribution directly from UI Catalog
                        InkWell(
                          onTap: () async {
                            final count = await controller
                                .loadSynthesizedCatalogDistribution();
                            if (!context.mounted) return;
                            final String msg;
                            if (count < 0) {
                              msg = 'Could not synthesize offerings from Native UI Catalog.';
                            } else if (count == 0) {
                              msg = 'No catalog offerings available to synthesize.';
                            } else {
                              msg = 'Synthesized and loaded $count offerings from Native UI Catalog.';
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(msg),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          borderRadius: AppSpacing.radiusSm,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: AppSpacing.radiusSm,
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  PhosphorIconsRegular.database,
                                  size: 13,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Sync UI Catalog',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
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

  Widget _buildSearchField(BuildContext context) {
    return TextField(
      onChanged: controller.setSearchQuery,
      style: AppTextStyles.bodySm.copyWith(
        fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
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

  Widget _buildDropdown<T>(
    BuildContext context, {
    required String label,
    required T? value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    double? width,
  }) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label.toUpperCase(),
              style:
                  AppTextStyles.labelCaps.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: AppSpacing.xs),
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.bgPrimary,
              border: Border.all(color: AppColors.border),
              borderRadius: AppSpacing.radiusSm,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T?>(
                value: value,
                isExpanded: true,
                dropdownColor: AppColors.bgElevated,
                style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.textPrimary,
                    fontFamily:
                        Theme.of(context).textTheme.bodyMedium?.fontFamily),
                icon: const Icon(PhosphorIconsRegular.caretDown,
                    size: 16, color: AppColors.textMuted),
                items: [
                  DropdownMenuItem<T?>(
                      value: null,
                      child:
                          Text('All $label', overflow: TextOverflow.ellipsis)),
                  ...items.map((item) => DropdownMenuItem<T?>(
                      value: item,
                      child: Text(item.toString(),
                          overflow: TextOverflow.ellipsis))),
                ],
                onChanged: onChanged,
              ),
            ),
          ),
        ],
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
    final isModalMode = onToggleInspector != null;
    final isActive = !isModalMode && controller.isInspectorOpen;
    return IconButton(
      tooltip: isModalMode
          ? 'Open Record Inspector'
          : (controller.isInspectorOpen
              ? 'Hide Record Inspector'
              : 'Show Record Inspector'),
      icon: Icon(
        PhosphorIconsRegular.sidebarSimple,
        size: 18,
        color: isActive ? AppColors.primary : AppColors.textSecondary,
      ),
      style: IconButton.styleFrom(
        backgroundColor: isActive ? AppColors.primarySoft : AppColors.bgPrimary,
        side: BorderSide(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.4)
              : AppColors.border,
        ),
      ),
      onPressed: onToggleInspector ?? controller.toggleInspector,
    );
  }
}
