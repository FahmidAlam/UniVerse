// ============================================================
// FILE: lib/shared/widgets/weekly_schedule_view.dart
// PURPOSE: Day-by-day schedule body shared by the Room Detail and
// Teacher Detail screens. Both answer the same question — "what is on
// this room's / this teacher's timetable, day by day?" — so they share
// one implementation and differ only in what each row emphasises.
//
// Opens on today (falling back to the first day that actually has
// classes, so a Friday with nothing scheduled does not look broken),
// and the day strip switches which day is listed.
//
// Reads the plain weekly timetable: cancellations are NOT applied here,
// so a cancelled occurrence still appears as a normal class.
// ============================================================

import 'package:flutter/material.dart';
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/constants/app_enums.dart';
import 'package:universe/core/models/routine_model.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/shared/widgets/day_selector.dart';
import 'package:universe/shared/widgets/u_empty_state.dart';

/// Builds the card for one entry — lets Rooms show the teacher while
/// Find Teacher shows the room, from the same list machinery.
typedef ScheduleRowBuilder = Widget Function(
  BuildContext context,
  RoutineEntry entry,
  ClassStatus status,
);

class WeeklyScheduleView extends StatefulWidget {
  /// Every entry for this room / teacher, any day.
  final List<RoutineEntry> entries;

  /// Optional summary card pinned above the day strip.
  final Widget? header;

  final ScheduleRowBuilder rowBuilder;

  /// Shown when the selected day has nothing scheduled.
  final String emptyMessage;

  const WeeklyScheduleView({
    super.key,
    required this.entries,
    required this.rowBuilder,
    this.header,
    this.emptyMessage = 'Nothing scheduled for this day.',
  });

  @override
  State<WeeklyScheduleView> createState() => _WeeklyScheduleViewState();
}

class _WeeklyScheduleViewState extends State<WeeklyScheduleView> {
  late String _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _initialDay();
  }

  /// Today, unless today is empty and some other day is not — landing on a
  /// blank day would read as "this room has no schedule at all".
  String _initialDay() {
    final today = AppConstants.weekDays[DateTime.now().weekday % 7];
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

  @override
  Widget build(BuildContext context) {
    final dayIndex = AppConstants.weekDays.indexOf(_selectedDay);
    final shortDay = dayIndex < 0
        ? AppConstants.weekDaysShort.first
        : AppConstants.weekDaysShort[dayIndex];

    final rows = _entriesFor(_selectedDay);
    final isToday =
        _selectedDay == AppConstants.weekDays[DateTime.now().weekday % 7];
    final now = DateTime.now();

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
          child: rows.isEmpty
              ? UEmptyState(
                  icon: PhosphorIconsRegular.calendarBlank,
                  title: 'Free all day',
                  message: widget.emptyMessage,
                )
              : ListView.separated(
                  padding: AppSpacing.screenPaddingScrollable,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => AppSpacing.cardGap,
                  itemBuilder: (context, i) => widget.rowBuilder(
                    context,
                    rows[i],
                    rows[i].statusOn(now, isToday: isToday),
                  ),
                ),
        ),
      ],
    );
  }
}
