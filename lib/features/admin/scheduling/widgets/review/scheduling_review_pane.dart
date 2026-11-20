import 'package:universe/shared/widgets/u_animated_swap.dart';
import 'package:universe/shared/widgets/u_segmented_control.dart';
import 'package:flutter/material.dart';
import 'package:universe/core/models/routine_model.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/admin/scheduling/controllers/scheduling_workspace_controller.dart';
import 'package:universe/features/admin/scheduling/fixtures/scheduling_preview_fixtures.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/features/admin/widgets/admin_schedule_slot.dart';
import 'package:universe/shared/widgets/u_adaptive_overlay.dart';
import 'package:universe/shared/widgets/u_card.dart';

/// Review & Publish pane.
/// Provides a filterable timetable grid (Section, Faculty, Room views),
/// conflict inspector, revision comparison diff, and an atomic publication gate.
class SchedulingReviewPane extends StatefulWidget {
  final SchedulingWorkspaceController controller;

  const SchedulingReviewPane({super.key, required this.controller});

  @override
  State<SchedulingReviewPane> createState() => _SchedulingReviewPaneState();
}

class _SchedulingReviewPaneState extends State<SchedulingReviewPane> {
  int _viewModeIndex =
      0; // 0=Section Grid, 1=Faculty Schedule, 2=Room Occupancy
  String _selectedDay = 'Sunday';
  String _selectedBatch = '2024';
  String _selectedTeacher = 'MSA';
  String _selectedRoom = 'RAB-201';

  final List<String> _teachers = [
    'MSA',
    'FK',
    'NJ',
    'MHR',
    'SR',
    'TI',
    'MM',
    'SH',
    'FA',
  ];
  final List<String> _rooms = [
    'RAB-201',
    'RAB-202',
    'RAB-301',
    'SW-LAB-1',
    'PHY-LAB',
  ];

  final List<String> _days = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];
  final List<String> _periods = [
    '09:00-09:50',
    '10:00-10:50',
    '11:00-11:50',
    '12:00-13:00 (Break)',
    '13:00-13:50',
    '14:00-14:50',
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final rows = SchedulingPreviewFixtures.candidateRoutineRows;

        return ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          children: [
            _buildViewSelector(),
            const SizedBox(height: AppSpacing.lg),
            _buildTimetableGridCard(rows),
            const SizedBox(height: AppSpacing.lg),
            _buildConflictInspectorCard(),
            const SizedBox(height: AppSpacing.lg),
            _buildRevisionComparisonCard(),
            const SizedBox(height: AppSpacing.lg),
            _buildAtomicPublishGateCard(context),
          ],
        );
      },
    );
  }

  // PHASE 5: Responsive view selector using USegmentedControl<int> that stacks cleanly at 390px.
  Widget _buildViewSelector() {
    // PHASE 5: Persistent labels sit outside the selector border.
    final entitySelector = SizedBox(
      width: 184,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _viewModeIndex == 0
                ? 'COHORT'
                : _viewModeIndex == 1
                    ? 'FACULTY MEMBER'
                    : 'ROOM POOL',
            style: AppTextStyles.labelCaps.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.xs),
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.bgPrimary,
              borderRadius: AppSpacing.radiusSm,
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _viewModeIndex == 0
                    ? _selectedBatch
                    : _viewModeIndex == 1
                        ? _selectedTeacher
                        : _selectedRoom,
                isExpanded: true,
                dropdownColor: AppColors.bgElevated,
                style: AppTextStyles.bodySmMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontFamily:
                        Theme.of(context).textTheme.bodyMedium?.fontFamily),
                items: (_viewModeIndex == 0
                        ? ['2021', '2022', '2023', '2024']
                        : _viewModeIndex == 1
                            ? _teachers
                            : _rooms)
                    .map((value) => DropdownMenuItem(
                          value: value,
                          child: Text(
                              _viewModeIndex == 0 ? 'Batch $value' : value,
                              overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    if (_viewModeIndex == 0) {
                      _selectedBatch = value;
                    } else if (_viewModeIndex == 1) {
                      _selectedTeacher = value;
                    } else {
                      _selectedRoom = value;
                    }
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        border: Border.all(color: AppColors.border),
        borderRadius: AppSpacing.radiusMd,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 720;

          final segmented = USegmentedControl<int>(
            compact: true,
            selected: _viewModeIndex,
            onChanged: (idx) => setState(() => _viewModeIndex = idx),
            segments: const [
              USegment(
                value: 0,
                label: 'Section Grid',
                icon: PhosphorIconsRegular.gridFour,
              ),
              USegment(
                value: 1,
                label: 'Faculty Schedule',
                icon: PhosphorIconsRegular.users,
              ),
              USegment(
                value: 2,
                label: 'Room Occupancy',
                icon: PhosphorIconsRegular.door,
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: constraints.maxWidth,
                      maxWidth: constraints.maxWidth < 620
                          ? 620
                          : constraints.maxWidth,
                    ),
                    child: segmented,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: entitySelector,
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: segmented),
              const SizedBox(width: AppSpacing.lg),
              entitySelector,
            ],
          );
        },
      ),
    );
  }

  Widget _buildTimetableGridCard(List<RoutineEntry> allRows) {
    final titleText = _viewModeIndex == 0
        ? 'CANDIDATE ROUTINE GRID · BATCH $_selectedBatch'
        : _viewModeIndex == 1
            ? 'FACULTY SCHEDULE TIMELINE · $_selectedTeacher'
            : 'ROOM OCCUPANCY SCHEDULE · $_selectedRoom';

    final dayChipRow = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _days.map((day) {
          final isSelected = _selectedDay == day;
          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: ChoiceChip(
              label: Text(day),
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedDay = day),
              selectedColor: AppColors.primarySoft,
              backgroundColor: AppColors.bgElevated,
              side: BorderSide(
                color: isSelected ? AppColors.primary : AppColors.border,
              ),
              labelStyle: TextStyle(
                fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          );
        }).toList(),
      ),
    );

    return UCard(
      isTopLit: true,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Day selector (responsive at 390px)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 1000;
                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            PhosphorIconsRegular.calendarCheck,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              titleText,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      dayChipRow,
                    ],
                  );
                }
                return Row(
                  children: [
                    const Icon(
                      PhosphorIconsRegular.calendarCheck,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        titleText,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    dayChipRow,
                  ],
                );
              },
            ),
          ),
          const Divider(color: AppColors.border, height: 1),
          // Day's schedule timeline
          UAnimatedSwap(
            child: KeyedSubtree(
              key: ValueKey(
                  '$_viewModeIndex-$_selectedDay-$_selectedBatch-$_selectedTeacher-$_selectedRoom'),
              child: _buildDayScheduleView(allRows),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayScheduleView(List<RoutineEntry> allRows) {
    final dayRows = allRows.where((r) {
      if (r.day != _selectedDay) return false;
      if (_viewModeIndex == 0) return r.batch == _selectedBatch;
      if (_viewModeIndex == 1) {
        return r.teacherCode == _selectedTeacher ||
            r.coTeacherCodes.contains(_selectedTeacher);
      }
      return r.room == _selectedRoom;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 560;

          return Column(
            children: _periods.map((period) {
              final isLunchBreak = period.contains('Break');
              final isFridayJummah = _selectedDay == 'Friday' &&
                  (isLunchBreak ||
                      period.contains('12:00') ||
                      period.contains('12:50') ||
                      period.contains('13:00') ||
                      period.contains('14:05') ||
                      period.toLowerCase().contains('prayer'));
              final matchingEntries = dayRows.where((r) {
                final start = r.timeStart.split(':').take(2).join(':');
                final pStart = period.substring(0, 5);
                return start == pStart;
              }).toList();

              final periodContent = isFridayJummah
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(PhosphorIconsRegular.lock, size: 13, color: AppColors.error),
                        const SizedBox(width: 6),
                        Text(
                          'FRIDAY JUMMAH PRAYER BLOCK (friday_no_p4 — No classes permitted)',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    )
                  : isLunchBreak
                      ? const Text(
                          'PRAYER & LUNCH BREAK (R15 · University-wide pause)',
                          style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: AppColors.textMuted,
                          ),
                        )
                  : matchingEntries.isEmpty
                      ? const Text(
                          'Free / Unscheduled Slot',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final entry in matchingEntries)
                              Padding(
                                padding: const EdgeInsets.only(
                                    bottom: AppSpacing.sm),
                                child: AdminScheduleSlot(
                                  entry: entry,
                                  onTap: () => _inspectSlot(entry),
                                ),
                              ),
                          ],
                        );

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color:
                      isLunchBreak ? AppColors.bgElevated : AppColors.bgPrimary,
                  borderRadius: AppSpacing.radiusSm,
                  border: Border.all(
                    color: isLunchBreak
                        ? AppColors.border.withValues(alpha: 0.5)
                        : AppColors.border,
                  ),
                ),
                child: isNarrow
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isLunchBreak
                                    ? PhosphorIconsRegular.coffee
                                    : PhosphorIconsRegular.clock,
                                size: 13,
                                color: isLunchBreak
                                    ? AppColors.warning
                                    : AppColors.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  period,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isLunchBreak
                                        ? AppColors.warning
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          periodContent,
                        ],
                      )
                    : Row(
                        children: [
                          // Period time badge
                          SizedBox(
                            width: 160,
                            child: Row(
                              children: [
                                Icon(
                                  isLunchBreak
                                      ? PhosphorIconsRegular.coffee
                                      : PhosphorIconsRegular.clock,
                                  size: 13,
                                  color: isLunchBreak
                                      ? AppColors.warning
                                      : AppColors.textMuted,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    period,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isLunchBreak
                                          ? AppColors.warning
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 28,
                            color: AppColors.border,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          // Period Content
                          Expanded(child: periodContent),
                        ],
                      ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  void _inspectSlot(RoutineEntry entry) {
    showUAdaptiveModal<void>(
      context: context,
      title: entry.subjectCode,
      subtitle: entry.subject,
      badge: 'SIMULATED CANDIDATE · NOT PUBLISHED',
      icon: PhosphorIconsRegular.calendarCheck,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminScheduleSlot(entry: entry),
          const SizedBox(height: AppSpacing.lg),
          Text('Primary faculty', style: AppTextStyles.labelCaps),
          Text(entry.teacherName ?? entry.teacherCode ?? 'Not assigned',
              style: AppTextStyles.body),
          if (entry.coTeacherCodes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text('Co-teachers', style: AppTextStyles.labelCaps),
            Text(entry.coTeacherCodes.join(' · '), style: AppTextStyles.body),
          ],
          const SizedBox(height: AppSpacing.md),
          Text('${entry.day} · ${entry.timeLabel}',
              style: AppTextStyles.timeCode),
          const SizedBox(height: AppSpacing.sm),
          Text(
              'Candidate fixture for visual review. Publication remains gated by the workspace controller.',
              style: AppTextStyles.caption),
        ],
      ),
    );
  }

  Widget _buildConflictInspectorCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppSpacing.radiusMd,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.successSoft,
              borderRadius: AppSpacing.radiusSm,
            ),
            child: const Icon(
              PhosphorIconsRegular.shieldCheck,
              color: AppColors.success,
              size: 20,
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
                    const Text(
                      'Conflict Inspector: Zero Hard Collisions',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.successSoft,
                        borderRadius: AppSpacing.radiusSm,
                      ),
                      child: const Text(
                        'AUDIT CLEAN',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  '0 room double-bookings · 0 faculty time overlaps · 0 cohort section collisions · 0 sessional break-crossings.',
                  style:
                      TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevisionComparisonCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppSpacing.radiusMd,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    PhosphorIconsRegular.gitDiff,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Flexible(
                    child: Text(
                      'REVISION COMPARISON (CANDIDATE VS CURRENT PUBLISHED)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                'Comparing vs Active Routine #3',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _diffRow(
            '+',
            'Joint Section CSE-2201 (A+B) co-teaching MSA / FK applied per Chair resolution',
            AppColors.success,
          ),
          _diffRow(
            '+',
            'Service course EEE-2205 assigned to 92-seat lecture hall RAB-301',
            AppColors.success,
          ),
          _diffRow(
            '~',
            'Physics Lab (PHY-1104) shifted to Sunday afternoon per shared lab calendar',
            AppColors.info,
          ),
        ],
      ),
    );
  }

  Widget _diffRow(String symbol, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              symbol,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAtomicPublishGateCard(BuildContext context) {
    final isPublished = widget.controller.publishedConfirmationId != null;
    final isPublishing = widget.controller.isPublishing;

    final publishButton = !isPublished
        ? FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textPrimary,
            ),
            onPressed:
                isPublishing ? null : () => _confirmPublishDialog(context),
            icon: isPublishing
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.textPrimary,
                    ),
                  )
                : const Icon(PhosphorIconsRegular.uploadSimple, size: 16),
            label: Text(
              isPublishing ? 'Publishing…' : 'Publish to Campus',
            ),
          )
        : null;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isPublished ? AppColors.successSoft : AppColors.bgElevated,
        borderRadius: AppSpacing.radiusMd,
        border: Border.all(
          color: isPublished ? AppColors.success : AppColors.border,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.infoSoft,
                  borderRadius: AppSpacing.radiusSm,
                  border: Border.all(
                    color: AppColors.info.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  'SIMULATED PREVIEW · NO DATABASE WRITES',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: AppColors.info,
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isPublished
                        ? PhosphorIconsRegular.checkFat
                        : PhosphorIconsRegular.lockKey,
                    size: 20,
                    color: isPublished ? AppColors.success : AppColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPublished
                              ? 'ROUTINE PUBLISHED TO CAMPUS'
                              : 'SERVER-AUTHORITATIVE ATOMIC PUBLICATION GATE',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.6,
                            color: isPublished
                                ? AppColors.success
                                : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isPublished
                              ? 'Confirmation Token: ${widget.controller.publishedConfirmationId} · Routine versions table updated atomically.'
                              : 'Publishing will atomically activate this routine across all student and teacher portals, binding to Revision #${widget.controller.revision.revisionNumber}.',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isNarrow && publishButton != null) ...[
                    const SizedBox(width: AppSpacing.md),
                    publishButton,
                  ],
                ],
              ),
              if (isNarrow && publishButton != null) ...[
                const SizedBox(height: AppSpacing.md),
                SizedBox(width: double.infinity, child: publishButton),
              ],
            ],
          );
        },
      ),
    );
  }

  void _confirmPublishDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: Row(
          children: [
            const Icon(
              PhosphorIconsRegular.warning,
              color: AppColors.warning,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child:
                  Text('Confirm Routine Publication', style: AppTextStyles.h4),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.infoSoft,
                  borderRadius: AppSpacing.radiusSm,
                  border: Border.all(
                    color: AppColors.info.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  'SIMULATED PREVIEW · NO DATABASE WRITES',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: AppColors.info,
                  ),
                ),
              ),
              Text(
                'You are about to publish the generated routine for CSE Fall 2026. This will:',
                style: AppTextStyles.bodySm,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '• Atomically activate version #4 for all students & teachers.\n'
                '• Supersede current active routine #3.\n'
                '• Record an authoritative audit log with your digital signature.',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textPrimary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // PHASE 5: Tactile Slide-to-Confirm safety control alongside accessible keyboard button.
              _SlideToConfirmPublish(
                label: 'Slide to Publish Routine (Simulated)',
                onConfirmed: () {
                  Navigator.of(ctx).pop();
                  widget.controller.simulatePublishRoutine();
                },
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
              widget.controller.simulatePublishRoutine();
            },
            child: const Text('Confirm & Publish Atomically'),
          ),
        ],
      ),
    );
  }
}

// PHASE 5: Tactile Slide-to-Confirm safety track to prevent accidental mistap on high-impact publication.
class _SlideToConfirmPublish extends StatefulWidget {
  final String label;
  final VoidCallback onConfirmed;

  const _SlideToConfirmPublish({
    required this.label,
    required this.onConfirmed,
  });

  @override
  State<_SlideToConfirmPublish> createState() => _SlideToConfirmPublishState();
}

class _SlideToConfirmPublishState extends State<_SlideToConfirmPublish> {
  double _progress = 0.0;
  bool _confirmed = false;

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_confirmed) return;
    final box = context.findRenderObject() as RenderBox?;
    final trackWidth = (box?.hasSize == true ? box!.size.width : 320.0) - 48.0;
    final maxTravel = trackWidth.clamp(1.0, 500.0);
    setState(() {
      _progress = (_progress + details.delta.dx / maxTravel).clamp(0.0, 1.0);
    });
    if (_progress >= 0.92 && !_confirmed) {
      _confirmed = true;
      widget.onConfirmed();
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_confirmed) return;
    setState(() => _progress = 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: Container(
        height: 48,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: AppSpacing.radiusFull,
          border: Border.all(color: AppColors.border),
        ),
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            FractionallySizedBox(
              widthFactor: (_progress * 0.9 + 0.1).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: AppSpacing.radiusFull,
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(left: 36, right: 12),
                child: Text(
                  widget.label,
                  style: AppTextStyles.captionMedium.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Align(
              alignment: Alignment(-1.0 + (_progress * 2.0), 0.0),
              child: GestureDetector(
                onHorizontalDragUpdate: _handleDragUpdate,
                onHorizontalDragEnd: _handleDragEnd,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: AppColors.dualElevationShadow,
                  ),
                  child: const Icon(
                    PhosphorIconsRegular.arrowRight,
                    size: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
