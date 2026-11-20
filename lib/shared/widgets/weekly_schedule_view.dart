// ============================================================
// FILE: lib/shared/widgets/weekly_schedule_view.dart
// PURPOSE: Shared schedule presenter supporting both:
// 1. Day-by-day swipeable agenda (used by RoomDetailScreen, TeacherDetailScreen,
//    and RoutineScreen Day List) with >=40 min Break / Free Window dividers.
// 2. High-Craft Academic Weekly Matrix (`WeeklyScheduleView.matrix`) with
//    AppColors.bgCard cells, 1px AppColors.border gridlines, sticky time-slot
//    headers, highlighted Today row, 3px semantic left accent bars, and
//    contextual cell detail modal/floating-sheet inspection.
// ============================================================

import 'package:flutter/material.dart';
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/constants/app_enums.dart';
import 'package:universe/core/models/routine_model.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_motion.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/shared/widgets/day_selector.dart';
import 'package:universe/shared/widgets/u_adaptive_overlay.dart';
import 'package:universe/shared/widgets/u_animated_swap.dart';
import 'package:universe/shared/widgets/u_badge.dart';
import 'package:universe/shared/widgets/u_empty_state.dart';
import 'package:universe/shared/widgets/u_staggered_list_row.dart';

/// Builds the card for one entry — lets Rooms show the teacher while
/// Find Teacher shows the room, from the same list machinery.
typedef ScheduleRowBuilder = Widget Function(
  BuildContext context,
  RoutineEntry entry,
  ClassStatus status,
);

// PHASE 4: Contextual academic detail inspection modal (Desktop >=768px) / floating sheet (Mobile <768px).
Future<void> showRoutineEntryDetailOverlay({
  required BuildContext context,
  required RoutineEntry entry,
  required ClassStatus status,
  bool isCancelledToday = false,
}) {
  final isLab = entry.subject.toLowerCase().contains('lab') ||
      entry.subject.toLowerCase().contains('sessional') ||
      entry.room.toLowerCase().contains('lab');
  final isJoint =
      entry.section.contains('+') || entry.teacherCodes.length > 1;

  final Color accentColor;
  final String badgeLabel;
  if (isCancelledToday || status == ClassStatus.cancelled) {
    accentColor = AppColors.error;
    badgeLabel = 'CANCELLED FOR TODAY';
  } else if (status == ClassStatus.live) {
    accentColor = AppColors.primary;
    badgeLabel = 'LIVE SESSION';
  } else if (isLab) {
    accentColor = AppColors.success;
    badgeLabel = 'LAB / SESSIONAL';
  } else if (isJoint) {
    accentColor = AppColors.info;
    badgeLabel = 'JOINT / CO-TAUGHT SESSION';
  } else {
    accentColor = AppColors.primary;
    badgeLabel = 'THEORY LECTURE';
  }

  return showUAdaptiveModal<void>(
    context: context,
    title: entry.subject,
    subtitle: entry.subjectCode.isNotEmpty
        ? '${entry.subjectCode} · ${entry.day}'
        : entry.day,
    badge: badgeLabel,
    icon: isCancelledToday
        ? PhosphorIconsRegular.prohibit
        : (isLab
            ? PhosphorIconsRegular.flask
            : PhosphorIconsRegular.bookOpen),
    accentColor: accentColor,
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DetailAttributeRow(
          icon: PhosphorIconsRegular.clock,
          label: 'Time Slot',
          value: '${entry.day} · ${entry.timeLabel}',
        ),
        const SizedBox(height: AppSpacing.sm),
        _DetailAttributeRow(
          icon: PhosphorIconsRegular.mapPin,
          label: 'Assigned Room',
          value: 'Room ${entry.room}',
        ),
        const SizedBox(height: AppSpacing.sm),
        _DetailAttributeRow(
          icon: PhosphorIconsRegular.usersThree,
          label: 'Cohort & Section',
          value: entry.section.contains('+')
              ? 'Batch ${entry.batch} · Section ${entry.section} (Combined / Joint Section)'
              : 'Batch ${entry.batch} · Section ${entry.section}',
        ),
        const SizedBox(height: AppSpacing.sm),
        _DetailAttributeRow(
          icon: PhosphorIconsRegular.chalkboardTeacher,
          label: entry.teacherCodes.length > 1
              ? 'Co-Teaching Faculty'
              : 'Assigned Faculty',
          value: entry.teacherDisplay,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Text('Current Status', style: AppTextStyles.caption),
            const Spacer(),
            UBadge(
              status: isCancelledToday ? ClassStatus.cancelled : status,
            ),
          ],
        ),
      ],
    ),
  );
}

class _DetailAttributeRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailAttributeRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgSubtle,
        borderRadius: AppSpacing.radiusSm,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: AppSpacing.iconSm, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.caption),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// PHASE 4: Visual Break / Free Window divider when a gap >= 40 minutes exists between classes.
class RoutineBreakDivider extends StatelessWidget {
  final int gapMinutes;
  final String startLabel;
  final String endLabel;
  final String? customLabel;
  final IconData? icon;
  final Color? color;

  const RoutineBreakDivider({
    super.key,
    required this.gapMinutes,
    required this.startLabel,
    required this.endLabel,
    this.customLabel,
    this.icon,
    this.color,
  });

  /// Parses an `'HH:mm'` string into minutes since midnight, or `null` if invalid.
  static int? parseHhMmMinutes(String hhmm) {
    final parts = hhmm.trim().split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  /// True when a gap on Friday bridges the mandatory `friday_no_p4`
  /// Jummah Prayer window (`12:50`–`14:05`, i.e., `770`–`845` minutes).
  static bool spansFridayJummah(
    String day,
    int prevEndMin,
    int nextStartMin,
  ) {
    final isFriday = day == 'Friday' || day.startsWith('Fri');
    return isFriday && prevEndMin <= 770 && nextStartMin >= 845;
  }

  /// True when a matrix slot key (`'HH:mm-HH:mm'`) on Friday overlaps the
  /// mandatory `friday_no_p4` Jummah Prayer block (`12:50`–`14:05`).
  static bool slotOverlapsFridayJummah(
    String day,
    String slotKey,
    String slotLabel,
  ) {
    final isFriday = day == 'Friday' || day.startsWith('Fri');
    if (!isFriday) return false;
    final parts = slotKey.split('-');
    if (parts.length == 2) {
      final startMin = parseHhMmMinutes(parts[0]);
      final endMin = parseHhMmMinutes(parts[1]);
      if (startMin != null && endMin != null) {
        return startMin < 845 && endMin > 770;
      }
    }
    final lower = slotLabel.toLowerCase();
    return lower.contains('jummah') || lower.contains('prayer');
  }

  /// Shared day-agenda gap builder ensuring both [WeeklyScheduleView] and
  /// [RoutineScreen] surface identical Jummah (`friday_no_p4`) and break dividers.
  static Widget buildGapOrJummahDivider({
    required String day,
    required RoutineEntry prev,
    required RoutineEntry next,
    required DateTime now,
  }) {
    final prevEnd = prev.endOn(now);
    final nextStart = next.startOn(now);
    final gapMinutes = nextStart.difference(prevEnd).inMinutes;
    final prevEndMin = prevEnd.hour * 60 + prevEnd.minute;
    final nextStartMin = nextStart.hour * 60 + nextStart.minute;

    if (spansFridayJummah(day, prevEndMin, nextStartMin)) {
      return RoutineBreakDivider(
        gapMinutes: gapMinutes,
        startLabel: prev.endLabel,
        endLabel: next.startLabel,
        customLabel: 'Jummah Prayer Break · 12:50 – 2:05 PM',
        icon: PhosphorIconsRegular.lock,
        color: AppColors.primary,
      );
    }
    if (gapMinutes >= 40) {
      return RoutineBreakDivider(
        gapMinutes: gapMinutes,
        startLabel: prev.endLabel,
        endLabel: next.startLabel,
      );
    }
    return AppSpacing.cardGap;
  }

  String get _durationLabel {
    final hours = gapMinutes ~/ 60;
    final mins = gapMinutes % 60;
    if (hours > 0 && mins > 0) return '${hours}h ${mins}m';
    if (hours > 0) return '${hours}h';
    return '${mins}m';
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = color ?? AppColors.textMuted;
    final labelText =
        customLabel ?? 'Break: $_durationLabel ($startLabel – $endLabel)';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 460;
          final pill = Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? AppSpacing.sm : AppSpacing.md,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: color != null
                  ? color!.withValues(alpha: 0.12)
                  : AppColors.bgSubtle,
              borderRadius: AppSpacing.radiusFull,
              border: Border.all(
                color: color != null
                    ? color!.withValues(alpha: 0.35)
                    : AppColors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon ?? PhosphorIconsRegular.coffee,
                  size: 13,
                  color: accentColor,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    labelText,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: color ?? AppColors.textSecondary,
                      fontWeight:
                          color != null ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          );

          return Row(
            children: [
              isCompact
                  ? SizedBox(
                      width: 12,
                      child: Container(height: 1, color: AppColors.border),
                    )
                  : Expanded(
                      flex: 1,
                      child: Container(height: 1, color: AppColors.border),
                    ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                flex: isCompact ? 1 : 8,
                child: pill,
              ),
              const SizedBox(width: AppSpacing.sm),
              isCompact
                  ? SizedBox(
                      width: 12,
                      child: Container(height: 1, color: AppColors.border),
                    )
                  : Expanded(
                      flex: 1,
                      child: Container(height: 1, color: AppColors.border),
                    ),
            ],
          );
        },
      ),
    );
  }
}

class WeeklyScheduleView extends StatefulWidget {
  /// Every entry for this room / teacher / student cohort, any day.
  final List<RoutineEntry> entries;

  /// Optional summary card pinned above the day strip.
  final Widget? header;

  final ScheduleRowBuilder? rowBuilder;

  /// Shown when the selected day has nothing scheduled.
  final String emptyMessage;

  // PHASE 4: When matrixMode is true, renders the 2D academic weekly matrix grid.
  final bool matrixMode;
  final bool isTeacherView;
  final Set<String> cancelledEntryIdsToday;
  final DateTime Function()? clock;

  const WeeklyScheduleView({
    super.key,
    required this.entries,
    required ScheduleRowBuilder this.rowBuilder,
    this.header,
    this.emptyMessage = 'Nothing scheduled for this day.',
    this.clock,
  })  : matrixMode = false,
        isTeacherView = false,
        cancelledEntryIdsToday = const {};

  const WeeklyScheduleView.matrix({
    super.key,
    required this.entries,
    this.header,
    this.isTeacherView = false,
    this.cancelledEntryIdsToday = const {},
    this.clock,
    this.emptyMessage = 'No routine entries are available yet.',
  })  : matrixMode = true,
        rowBuilder = null;

  @override
  State<WeeklyScheduleView> createState() => _WeeklyScheduleViewState();
}

class _WeeklyScheduleViewState extends State<WeeklyScheduleView> {
  late String _selectedDay;

  DateTime get _now => widget.clock?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _selectedDay = _initialDay();
  }

  /// Today, unless today is empty and some other day is not — landing on a
  /// blank day would read as "this room has no schedule at all".
  String _initialDay() {
    final today = AppConstants.weekDays[_now.weekday % 7];
    if (_entriesFor(today).isNotEmpty) return today;

    for (final day in AppConstants.weekDays) {
      if (_entriesFor(day).isNotEmpty) return day;
    }
    return today;
  }

  List<RoutineEntry> _entriesFor(String day) {
    final rows = widget.entries.where((e) => e.day == day).toList()
      ..sort((a, b) => a.timeStart.compareTo(b.timeStart));
    return rows;
  }

  void _stepDay(int delta) {
    final len = AppConstants.weekDays.length;
    final currentIndex = AppConstants.weekDays.indexOf(_selectedDay);
    if (currentIndex < 0 || len == 0) return;
    final nextIndex = (currentIndex + delta + len) % len;
    AppMotion.selectionHaptic(context);
    setState(() => _selectedDay = AppConstants.weekDays[nextIndex]);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.matrixMode) {
      return _buildMatrixGrid(context);
    }

    final dayIndex = AppConstants.weekDays.indexOf(_selectedDay);
    final shortDay = dayIndex < 0
        ? AppConstants.weekDaysShort.first
        : AppConstants.weekDaysShort[dayIndex];

    final rows = _entriesFor(_selectedDay);
    final isToday = _selectedDay == AppConstants.weekDays[_now.weekday % 7];
    final now = _now;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.header != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.md,
              AppSpacing.screenH,
              0,
            ),
            child: widget.header,
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.lg,
            AppSpacing.screenH,
            AppSpacing.sm,
          ),
          child: DaySelector(
            selectedDay: shortDay,
            onSelect: (short) {
              final i = AppConstants.weekDaysShort.indexOf(short);
              if (i < 0) return;
              setState(() => _selectedDay = AppConstants.weekDays[i]);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          child: Row(
            children: [
              Text(
                isToday
                    ? '$_selectedDay · TODAY'.toUpperCase()
                    : _selectedDay.toUpperCase(),
                style: AppTextStyles.labelCaps,
              ),
              const Spacer(),
              Text(
                rows.length == 1 ? '1 class' : '${rows.length} classes',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        AppSpacing.smGap,
        Expanded(
          // PHASE 4: Swipeable Day Agenda in WeeklyScheduleView with directional UAnimatedSwap.
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (velocity.abs() < 200) return;
              _stepDay(velocity < 0 ? 1 : -1);
            },
            child: UAnimatedSwap(
              child: KeyedSubtree(
                key: ValueKey<String>('day:$_selectedDay'),
                child: rows.isEmpty
                    ? UEmptyState(
                        icon: PhosphorIconsRegular.calendarBlank,
                        title: 'Free all day',
                        message: widget.emptyMessage,
                      )
                    : ListView(
                        padding: AppSpacing.screenPaddingScrollable,
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: _buildRowsWithBreakDividers(
                          context,
                          rows,
                          now: now,
                          isToday: isToday,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildRowsWithBreakDividers(
    BuildContext context,
    List<RoutineEntry> rows, {
    required DateTime now,
    required bool isToday,
  }) {
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      final entry = rows[i];
      if (i > 0) {
        children.add(
          RoutineBreakDivider.buildGapOrJummahDivider(
            day: _selectedDay,
            prev: rows[i - 1],
            next: entry,
            now: now,
          ),
        );
      }
      children.add(
        UStaggeredListRow(
          index: i,
          child: widget.rowBuilder!(
            context,
            entry,
            entry.statusOn(now, isToday: isToday),
          ),
        ),
      );
    }
    return children;
  }

  // PHASE 4: High-Craft Academic Weekly Matrix with sticky/highlighted time headers,
  // highlighted Today row, 3px semantic left accent bars, and cell detail inspection.
  Widget _buildMatrixGrid(BuildContext context) {
    if (widget.entries.isEmpty) {
      return UEmptyState(
        icon: PhosphorIconsRegular.calendarBlank,
        title: 'No classes',
        message: widget.emptyMessage,
      );
    }

    final now = _now;
    final todayFull = AppConstants.weekDays[now.weekday % 7];

    // Derive sorted unique time slot columns from the routine entries.
    final slotMap = <String, (String start, String end, String label)>{};
    for (final e in widget.entries) {
      final key = '${e.timeStart}-${e.timeEnd}';
      slotMap.putIfAbsent(key, () => (e.timeStart, e.timeEnd, e.timeLabel));
    }
    final slotKeys = slotMap.keys.toList()
      ..sort((a, b) => slotMap[a]!.$1.compareTo(slotMap[b]!.$1));

    // Institutional 7-Day Operational Week (Sunday–Saturday).
    final activeDays = AppConstants.weekDays;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 1024.0;
        const dayColWidth = 128.0;
        final minSlotWidth = 176.0;
        final computedSlotWidth = slotKeys.isEmpty
            ? minSlotWidth
            : ((availableWidth - AppSpacing.screenH * 2 - dayColWidth) /
                    slotKeys.length)
                .clamp(minSlotWidth, 260.0);
        final totalGridWidth =
            dayColWidth + computedSlotWidth * slotKeys.length;

        return SingleChildScrollView(
          padding: AppSpacing.screenPaddingScrollable,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.header != null) ...[
                widget.header!,
                AppSpacing.mdGap,
              ],
              _buildMatrixLegend(),
              AppSpacing.mdGap,
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: totalGridWidth),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.bgSubtle,
                      borderRadius: AppSpacing.radiusMd,
                      border: Border.all(color: AppColors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Highlighted Time-Slot Header Row
                        Container(
                          decoration: const BoxDecoration(
                            color: AppColors.bgElevated,
                            border: Border(
                              bottom: BorderSide(color: AppColors.border),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: dayColWidth,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.md,
                                ),
                                decoration: const BoxDecoration(
                                  border: Border(
                                    right: BorderSide(color: AppColors.border),
                                  ),
                                ),
                                child: Text(
                                  'DAY / SLOT',
                                  style: AppTextStyles.labelCaps.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              for (var s = 0; s < slotKeys.length; s++)
                                Container(
                                  width: computedSlotWidth,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: AppSpacing.md,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      right: s == slotKeys.length - 1
                                          ? BorderSide.none
                                          : const BorderSide(
                                              color: AppColors.border,
                                            ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        PhosphorIconsRegular.clock,
                                        size: 13,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          slotMap[slotKeys[s]]!.$3,
                                          style:
                                              AppTextStyles.timeCode.copyWith(
                                            color: AppColors.textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Day Rows
                        for (var d = 0; d < activeDays.length; d++)
                          _buildMatrixDayRow(
                            context,
                            day: activeDays[d],
                            isToday: activeDays[d] == todayFull,
                            isLastRow: d == activeDays.length - 1,
                            dayColWidth: dayColWidth,
                            slotWidth: computedSlotWidth,
                            slotKeys: slotKeys,
                            slotMap: slotMap,
                            now: now,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMatrixLegend() {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const _LegendItem(color: AppColors.primary, label: 'Theory'),
        const _LegendItem(color: AppColors.success, label: 'Lab / Sessional'),
        const _LegendItem(
          color: AppColors.info,
          label: 'Joint / Co-Taught',
        ),
        const _LegendItem(
          color: AppColors.error,
          label: 'Cancelled Today',
        ),
        Text(
          'Click any scheduled cell to inspect full course details',
          style: AppTextStyles.caption,
        ),
      ],
    );
  }

  Widget _buildMatrixDayRow(
    BuildContext context, {
    required String day,
    required bool isToday,
    required bool isLastRow,
    required double dayColWidth,
    required double slotWidth,
    required List<String> slotKeys,
    required Map<String, (String start, String end, String label)> slotMap,
    required DateTime now,
  }) {
    final dayEntries = _entriesFor(day);

    return Container(
      decoration: BoxDecoration(
        color: isToday
            ? AppColors.primary.withValues(alpha: 0.05)
            : AppColors.bgCard,
        border: Border(
          bottom: isLastRow
              ? BorderSide.none
              : const BorderSide(color: AppColors.border),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Day Header Cell
            Container(
              width: dayColWidth,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: isToday ? AppColors.primarySoft : AppColors.bgSubtle,
                border: const Border(
                  right: BorderSide(color: AppColors.border),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    day,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isToday
                          ? AppColors.primary
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (isToday)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: AppSpacing.radiusSm,
                      ),
                      child: Text(
                        'TODAY',
                        style: AppTextStyles.badge.copyWith(
                          color: AppColors.textOnPrimary,
                          fontSize: 9,
                        ),
                      ),
                    )
                  else
                    Text(
                      '${dayEntries.length} ${dayEntries.length == 1 ? "slot" : "slots"}',
                      style: AppTextStyles.caption,
                    ),
                ],
              ),
            ),
            // Time Slot Cells
            for (var s = 0; s < slotKeys.length; s++)
              Container(
                width: slotWidth,
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  border: Border(
                    right: s == slotKeys.length - 1
                        ? BorderSide.none
                        : const BorderSide(color: AppColors.border),
                  ),
                ),
                child: _buildMatrixSlotCell(
                  context,
                  day: day,
                  isToday: isToday,
                  slotKey: slotKeys[s],
                  slotLabel: slotMap[slotKeys[s]]!.$3,
                  cellEntries: dayEntries
                      .where((e) => '${e.timeStart}-${e.timeEnd}' == slotKeys[s])
                      .toList(),
                  now: now,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatrixSlotCell(
    BuildContext context, {
    required String day,
    required bool isToday,
    required String slotKey,
    required String slotLabel,
    required List<RoutineEntry> cellEntries,
    required DateTime now,
  }) {
    if (cellEntries.isEmpty) {
      final isFridayJummah = RoutineBreakDivider.slotOverlapsFridayJummah(
        day,
        slotKey,
        slotLabel,
      );
      if (isFridayJummah) {
        return Container(
          constraints: const BoxConstraints(minHeight: 84),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primarySoft.withValues(alpha: 0.35),
            borderRadius: AppSpacing.radiusSm,
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(PhosphorIconsRegular.lock, size: 14, color: AppColors.primary),
              const SizedBox(height: 4),
              Text(
                'Jummah Prayer\n(No classes)',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }

      return Semantics(
        label: '$day, $slotLabel: Unscheduled slot',
        child: Container(
          constraints: const BoxConstraints(minHeight: 84),
          alignment: Alignment.center,
          child: Text(
            '—',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textDisabled,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < cellEntries.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.xs),
          _MatrixCellMiniCard(
            entry: cellEntries[i],
            isToday: isToday,
            isTeacherView: widget.isTeacherView,
            isCancelledToday:
                isToday && widget.cancelledEntryIdsToday.contains(cellEntries[i].id),
            now: now,
          ),
        ],
      ],
    );
  }
}

class _MatrixCellMiniCard extends StatelessWidget {
  final RoutineEntry entry;
  final bool isToday;
  final bool isTeacherView;
  final bool isCancelledToday;
  final DateTime now;

  const _MatrixCellMiniCard({
    required this.entry,
    required this.isToday,
    required this.isTeacherView,
    required this.isCancelledToday,
    required this.now,
  });

  bool get _isLab {
    final lower = entry.subject.toLowerCase();
    final roomLower = entry.room.toLowerCase();
    return lower.contains('lab') ||
        lower.contains('sessional') ||
        roomLower.contains('lab');
  }

  bool get _isJoint =>
      entry.section.contains('+') || entry.teacherCodes.length > 1;

  Color get _accentColor {
    if (isCancelledToday) return AppColors.error;
    if (_isLab) return AppColors.success;
    if (_isJoint) return AppColors.info;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final status = isCancelledToday
        ? ClassStatus.cancelled
        : entry.statusOn(now, isToday: isToday);
    final codeOrSubject = entry.subjectCode.trim().isNotEmpty
        ? entry.subjectCode.trim()
        : entry.subject;
    final tagLabel = isTeacherView
        ? 'Batch ${entry.batch} · ${entry.section}'
        : (entry.section.contains('+')
            ? 'Sec ${entry.section} · ${entry.teacherDisplay}'
            : entry.teacherDisplay);

    return Semantics(
      button: true,
      label:
          '${entry.day} ${entry.timeLabel}: ${entry.subject}, Room ${entry.room}, $tagLabel',
      child: Material(
        color: AppColors.bgElevated,
        borderRadius: AppSpacing.radiusSm,
        child: InkWell(
          borderRadius: AppSpacing.radiusSm,
          onTap: () => showRoutineEntryDetailOverlay(
            context: context,
            entry: entry,
            status: status,
            isCancelledToday: isCancelledToday,
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: AppSpacing.radiusSm,
              border: Border.all(
                color: isCancelledToday
                    ? AppColors.error.withValues(alpha: 0.45)
                    : AppColors.border,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 3,
                  child: ColoredBox(color: _accentColor),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              codeOrSubject,
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w700,
                                color: isCancelledToday
                                    ? AppColors.textMuted
                                    : AppColors.textPrimary,
                                decoration: isCancelledToday
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.bgCard,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              entry.room,
                              style: AppTextStyles.roomCode.copyWith(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        entry.subject,
                        style: AppTextStyles.caption.copyWith(
                          color: isCancelledToday
                              ? AppColors.textDisabled
                              : AppColors.textSecondary,
                          decoration: isCancelledToday
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              tagLabel,
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 11,
                                color: _isJoint
                                    ? AppColors.info
                                    : AppColors.textMuted,
                                fontWeight: _isJoint
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isCancelledToday)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.errorSoft,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'CANCELLED',
                                style: AppTextStyles.badge.copyWith(
                                  color: AppColors.error,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
