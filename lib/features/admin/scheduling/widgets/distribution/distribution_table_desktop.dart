import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/admin/scheduling/controllers/scheduling_workspace_controller.dart';
import 'package:universe/features/admin/scheduling/models/scheduling_workspace_models.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';

/// Information-dense, desktop-first Course Distribution table.
/// Implements academic provenance, column grouping, formulas badges,
/// correction overlays, and interactive row selection.
class DistributionTableDesktop extends StatefulWidget {
  final SchedulingWorkspaceController controller;
  // PHASE 5: Optional callback for medium-tier adaptive modal inspection.
  final ValueChanged<DistributionSourceRecord>? onInspectRecord;

  const DistributionTableDesktop({
    super.key,
    required this.controller,
    this.onInspectRecord,
  });

  @override
  State<DistributionTableDesktop> createState() =>
      _DistributionTableDesktopState();
}

class _DistributionTableDesktopState extends State<DistributionTableDesktop> {
  // PHASE 5: Explicit axes prevent a visible horizontal scrollbar from
  // borrowing the workspace's vertical PrimaryScrollController in captures.
  final _horizontalScroll = ScrollController();
  final _verticalScroll = ScrollController();

  SchedulingWorkspaceController get controller => widget.controller;
  ValueChanged<DistributionSourceRecord>? get onInspectRecord =>
      widget.onInspectRecord;

  @override
  void dispose() {
    _horizontalScroll.dispose();
    _verticalScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final records = controller.filteredRecords;
        final selected = controller.selectedRecord;

        if (records.isEmpty) {
          return _buildEmptyState(context);
        }

        return Container(
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            border: Border.all(color: AppColors.border),
            borderRadius: AppSpacing.radiusMd,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // Main Table with Horizontal and Vertical scrolling
              Expanded(
                child: Scrollbar(
                  controller: _horizontalScroll,
                  thumbVisibility: true,
                  notificationPredicate: (notification) =>
                      notification.metrics.axis == Axis.horizontal,
                  child: SingleChildScrollView(
                    controller: _horizontalScroll,
                    primary: false,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: 1280,
                      child: LayoutBuilder(
                        builder: (context, tableConstraints) {
                          if (tableConstraints.maxHeight < 140) {
                            return SingleChildScrollView(
                              controller: _verticalScroll,
                              primary: false,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildSuperHeader(),
                                  const Divider(
                                    color: AppColors.border,
                                    height: 1,
                                  ),
                                  _buildColumnHeader(),
                                  const Divider(
                                    color: AppColors.border,
                                    height: 1,
                                  ),
                                  for (var i = 0; i < records.length; i++) ...[
                                    if (i > 0)
                                      const Divider(
                                        color: AppColors.border,
                                        height: 1,
                                      ),
                                    _buildTableRow(
                                      context,
                                      records[i],
                                      selected?.row == records[i].row,
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }
                          return Column(
                            children: [
                              _buildSuperHeader(),
                              const Divider(color: AppColors.border, height: 1),
                              _buildColumnHeader(),
                              const Divider(color: AppColors.border, height: 1),
                              Expanded(
                                child: ListView.separated(
                                  controller: _verticalScroll,
                                  primary: false,
                                  itemCount: records.length,
                                  separatorBuilder: (context, index) =>
                                      const Divider(
                                    color: AppColors.border,
                                    height: 1,
                                  ),
                                  itemBuilder: (context, index) {
                                    final record = records[index];
                                    final isSelected =
                                        selected?.row == record.row;
                                    return _buildTableRow(
                                      context,
                                      record,
                                      isSelected,
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              // Footer Summary Bar
              _buildTableFooter(records.length),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSuperHeader() {
    return Container(
      color: AppColors.bgElevated,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          const SizedBox(
            width: 440,
            child: Text(
              'COURSE & COHORT IDENTITY (COLS A–D)',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: AppColors.textMuted,
              ),
            ),
          ),
          Container(width: 1, height: 14, color: AppColors.border),
          const SizedBox(width: 12),
          const SizedBox(
            width: 400,
            child: Text(
              'ACADEMIC INPUT & ALLOCATION (COLS E–I)',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: AppColors.textMuted,
              ),
            ),
          ),
          Container(width: 1, height: 14, color: AppColors.border),
          const SizedBox(width: 12),
          const SizedBox(
            width: 200,
            child: Text(
              'MEETING EVIDENCE (COLS J–L)',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: AppColors.textMuted,
              ),
            ),
          ),
          const Spacer(),
          const Text(
            'STATUS & AUDIT',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumnHeader() {
    return Container(
      color: AppColors.bgPrimary,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _sortableHeader('row', 'Row', width: 44),
          _sortableHeader('batch', 'Batch', width: 60),
          _sortableHeader('section', 'Sec', width: 50),
          _sortableHeader('code', 'Code', width: 90),
          _sortableHeader('title', 'Course Title', width: 190),
          _sortableHeader('credit', 'Cr', width: 44),
          const SizedBox(
            width: 90,
            child: Text(
              'Prereq',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ),
          _sortableHeader('dept', 'Dept', width: 60),
          const SizedBox(
            width: 55,
            child: Text(
              'Enr',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ),
          _sortableHeader('teacher', 'Teacher(s)', width: 140),
          const SizedBox(
            width: 70,
            child: Text(
              'Classes (J)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(
            width: 65,
            child: Text(
              'Dur (K)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(
            width: 90,
            child: Text(
              'Cls/Wk (L)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(
            width: 125,
            child: Text(
              'Integrity',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _sortableHeader(String column, String label, {required double width}) {
    final isSorted = controller.sortColumn == column;
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: () => controller.setSorting(column),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSorted ? AppColors.primary : AppColors.textMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isSorted) ...[
              const SizedBox(width: 2),
              Icon(
                controller.sortAscending
                    ? PhosphorIconsRegular.caretUp
                    : PhosphorIconsRegular.caretDown,
                size: 11,
                color: AppColors.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTableRow(
    BuildContext context,
    DistributionSourceRecord r,
    bool isSelected,
  ) {
    return _DistributionRow(
      record: r,
      isSelected: isSelected,
      onInspect: () {
        if (onInspectRecord != null) {
          onInspectRecord!(r);
        } else {
          controller.selectRecord(r);
        }
      },
      statusChip: _buildStatusChip(r),
      formulaBadgeBuilder: _formulaBadge,
    );
  }

  Widget _formulaBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  // PHASE 5: "Checkbox Off = Gray" signaling discipline — Verified baseline rows use calm
  // recessive slate-gray so Conflict (error), Corrected (warning), and Pending (info) stand out.
  Widget _buildStatusChip(DistributionSourceRecord r) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    switch (r.status) {
      case DistributionRecordStatus.conflict:
        bg = AppColors.errorSoft;
        fg = AppColors.error;
        label = 'Conflict';
        icon = PhosphorIconsRegular.warning;
        break;
      case DistributionRecordStatus.pendingTeacher:
        bg = AppColors.infoSoft;
        fg = AppColors.info;
        label = 'Pending';
        icon = PhosphorIconsRegular.clock;
        break;
      case DistributionRecordStatus.corrected:
        bg = AppColors.warningSoft;
        fg = AppColors.warning;
        label = 'Corrected';
        icon = PhosphorIconsRegular.pencilSimple;
        break;
      case DistributionRecordStatus.verified:
        bg = AppColors.bgElevated;
        fg = AppColors.textSecondary;
        label = 'Verified';
        icon = PhosphorIconsRegular.checkCircle;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppSpacing.radiusSm,
        border: Border.all(
          color: r.status == DistributionRecordStatus.verified
              ? AppColors.border
              : fg.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: fg),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: fg,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableFooter(int count) {
    return Container(
      width: double.infinity,
      color: AppColors.bgElevated,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Showing $count source records',
            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                PhosphorIconsRegular.info,
                size: 13,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  'Click any row to open the 5-part Provenance Inspector',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        border: Border.all(color: AppColors.border),
        borderRadius: AppSpacing.radiusMd,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              PhosphorIconsRegular.funnelX,
              size: 36,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: AppSpacing.md),
            Text('No matching records found', style: AppTextStyles.h4),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'No source rows match the active filter criteria. Try resetting filters.',
              style:
                  AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textPrimary,
              ),
              onPressed: controller.resetFilters,
              icon: const Icon(PhosphorIconsRegular.arrowsClockwise, size: 14),
              label: const Text('Reset All Filters'),
            ),
          ],
        ),
      ),
    );
  }
}

// PHASE 5: Hover-aware distribution row with "Invisible UI" quick-action reveal
// and click-to-copy course code feedback.
class _DistributionRow extends StatefulWidget {
  final DistributionSourceRecord record;
  final bool isSelected;
  final VoidCallback onInspect;
  final Widget statusChip;
  final Widget Function(String label) formulaBadgeBuilder;

  const _DistributionRow({
    required this.record,
    required this.isSelected,
    required this.onInspect,
    required this.statusChip,
    required this.formulaBadgeBuilder,
  });

  @override
  State<_DistributionRow> createState() => _DistributionRowState();
}

class _DistributionRowState extends State<_DistributionRow> {
  bool _hovered = false;

  void _copyCourseCode(BuildContext context, String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.bgElevated,
          duration: const Duration(seconds: 2),
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                PhosphorIconsRegular.checkCircle,
                color: AppColors.success,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Copied $code',
                style: AppTextStyles.captionMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onInspect,
        hoverColor: AppColors.bgElevated.withValues(alpha: 0.6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          color: widget.isSelected
              ? AppColors.primarySoft.withValues(alpha: 0.4)
              : (_hovered
                  ? AppColors.bgElevated.withValues(alpha: 0.45)
                  : Colors.transparent),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Row(
            children: [
              // Row #
              SizedBox(
                width: 44,
                child: Text(
                  '${r.row}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              // Batch
              SizedBox(
                width: 60,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.bgElevated,
                    borderRadius: AppSpacing.radiusSm,
                  ),
                  child: Text(
                    r.batch,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              // Section
              SizedBox(
                width: 50,
                child: Text(
                  r.section,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: r.section.contains('+')
                        ? AppColors.warning
                        : AppColors.textPrimary,
                  ),
                ),
              ),
              // Course Code (Click-to-copy)
              SizedBox(
                width: 90,
                child: Tooltip(
                  message: 'Copy ${r.courseCode}',
                  child: InkWell(
                    onTap: () => _copyCourseCode(context, r.courseCode),
                    borderRadius: AppSpacing.radiusSm,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            r.courseCode,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_hovered) ...[
                          const SizedBox(width: 3),
                          const Icon(
                            PhosphorIconsRegular.copy,
                            size: 11,
                            color: AppColors.primary,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              // Course Title
              SizedBox(
                width: 190,
                child: Text(
                  r.courseTitle,
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Credit
              SizedBox(
                width: 44,
                child: Text(
                  r.credit.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              // Prerequisite
              SizedBox(
                width: 90,
                child: Text(
                  r.prerequisite ?? 'None',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Dept
              SizedBox(
                width: 60,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: r.conductingDept == 'CSE'
                        ? AppColors.bgElevated
                        : AppColors.infoSoft,
                    borderRadius: AppSpacing.radiusSm,
                    border: Border.all(
                      color: r.conductingDept == 'CSE'
                          ? AppColors.border
                          : AppColors.info.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    r.conductingDept,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: r.conductingDept == 'CSE'
                          ? AppColors.textSecondary
                          : AppColors.info,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              // Enrollment
              SizedBox(
                width: 55,
                child: Text(
                  r.studentCount != null ? '${r.studentCount}' : 'Unknown',
                  style: TextStyle(
                    fontSize: 12,
                    color: r.studentCount != null
                        ? AppColors.textSecondary
                        : AppColors.warning,
                  ),
                ),
              ),
              // Teacher(s)
              SizedBox(
                width: 140,
                child: Text(
                  r.teacher,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: r.isTeacherPending
                        ? AppColors.error
                        : AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Classes J
              SizedBox(
                width: 70,
                child: Row(
                  children: [
                    Text(
                      '${r.classes}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (r.formulaJ != null) ...[
                      const SizedBox(width: 4),
                      widget.formulaBadgeBuilder('fx'),
                    ],
                  ],
                ),
              ),
              // Duration K
              SizedBox(
                width: 65,
                child: Text(
                  '${r.durationMinutes}m',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              // Class/Week L
              SizedBox(
                width: 90,
                child: Row(
                  children: [
                    Text(
                      '${r.classesPerWeek}/wk',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (r.formulaL != null) ...[
                      const SizedBox(width: 4),
                      widget.formulaBadgeBuilder('fx'),
                    ],
                  ],
                ),
              ),
              // Integrity Status
              SizedBox(
                width: 125,
                child: widget.statusChip,
              ),
              // Inspect Action ("Invisible UI" quick-action reveal on hover/select)
              SizedBox(
                width: 40,
                child: IconButton(
                  tooltip: 'Inspect record',
                  icon: Icon(
                    PhosphorIconsRegular.caretRight,
                    size: 14,
                    color: (_hovered || widget.isSelected)
                        ? AppColors.primary
                        : AppColors.textMuted,
                  ),
                  onPressed: widget.onInspect,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
