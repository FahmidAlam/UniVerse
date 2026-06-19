// ============================================================
// FILE: lib/features/admin/screens/timetable_grid_screen.dart
// PURPOSE: Admin grid viewer for a generated timetable — a day-sheet
// style grid (cohorts × time slots) mirroring the output workbook, so
// the admin can scan the whole department schedule before publishing.
// Stateless over the rows handed in via GoRouter `extra`.
// ============================================================

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/models/routine_model.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/shared/widgets/u_app_bar.dart';
import 'package:universe/shared/widgets/u_chip.dart';
import 'package:universe/shared/widgets/u_empty_state.dart';

class TimetableGridScreen extends StatefulWidget {
  final List<RoutineEntry> rows;

  const TimetableGridScreen({super.key, required this.rows});

  @override
  State<TimetableGridScreen> createState() => _TimetableGridScreenState();
}

class _TimetableGridScreenState extends State<TimetableGridScreen> {
  late String _day;

  List<String> get _daysPresent {
    final present = widget.rows.map((r) => r.day).toSet();
    return AppConstants.weekDays.where(present.contains).toList();
  }

  @override
  void initState() {
    super.initState();
    final days = _daysPresent;
    _day = days.isEmpty ? 'Sunday' : days.first;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: const UAppBar(title: 'Timetable Grid', subtitle: 'Generated preview'),
      body: widget.rows.isEmpty
          ? const UEmptyState(
              icon: PhosphorIconsRegular.gridFour,
              title: 'Nothing to show',
              message: 'Generate a timetable first.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: AppSpacing.chipHeight + AppSpacing.xl,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: AppSpacing.screenPaddingH,
                    children: [
                      for (final d in _daysPresent) ...[
                        UChip(
                          label: d.substring(0, 3),
                          isActive: d == _day,
                          onTap: () => setState(() => _day = d),
                        ),
                        AppSpacing.smHGap,
                      ],
                    ],
                  ),
                ),
                Expanded(child: _grid()),
              ],
            ),
    );
  }

  Widget _grid() {
    final dayRows = widget.rows.where((r) => r.day == _day).toList();
    if (dayRows.isEmpty) {
      return const UEmptyState(
        icon: PhosphorIconsRegular.calendarX,
        title: 'No classes this day',
      );
    }

    // Distinct time slots (columns), sorted by start.
    final slots = dayRows.map((r) => r.timeStart).toSet().toList()..sort();
    // Distinct cohorts (rows), canonical order.
    final cohorts = dayRows.map((r) => '${r.batch}|${r.section}').toSet().toList()
      ..sort(_cohortCompare);

    // (cohort,slot) -> entry
    final cell = <String, RoutineEntry>{};
    for (final r in dayRows) {
      cell['${r.batch}|${r.section}@${r.timeStart}'] = r;
    }

    const cohortW = 64.0;
    const slotW = 118.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: AppSpacing.x4l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(children: [
              _headCell('Batch·Sec', cohortW),
              for (final s in slots) _headCell(_slotLabel(dayRows, s), slotW),
            ]),
            for (final c in cohorts)
              Row(children: [
                _cohortCell(c, cohortW),
                for (final s in slots)
                  _bodyCell(cell['$c@$s'], slotW),
              ]),
          ],
        ),
      ),
    );
  }

  String _slotLabel(List<RoutineEntry> rows, String start) {
    final r = rows.firstWhere((e) => e.timeStart == start);
    return '${r.timeStart}–${r.timeEnd}';
  }

  Widget _headCell(String text, double w) => Container(
        width: w,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          border: Border.all(color: AppColors.border, width: AppSpacing.borderThin),
        ),
        child: Text(text,
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center),
      );

  Widget _cohortCell(String cohort, double w) {
    final parts = cohort.split('|');
    return Container(
      width: w,
      height: AppSpacing.heroCardHeight * 0.45,
      padding: const EdgeInsets.all(AppSpacing.sm),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        border: Border.all(color: AppColors.border, width: AppSpacing.borderThin),
      ),
      child: Text('${parts[0]}-${parts[1]}',
          style: AppTextStyles.chip.copyWith(color: AppColors.primary)),
    );
  }

  Widget _bodyCell(RoutineEntry? e, double w) {
    return Container(
      width: w,
      height: AppSpacing.heroCardHeight * 0.45,
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: e == null ? AppColors.bgPrimary : AppColors.bgCard,
        border: Border.all(color: AppColors.border, width: AppSpacing.borderThin),
      ),
      child: e == null
          ? const SizedBox.shrink()
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.subjectCode,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textPrimary)),
                Text(e.teacherCode ?? '',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary)),
                Text(e.room,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.roleTeacher)),
              ],
            ),
    );
  }

  // Canonical cohort sort: batch descending, then section ascending.
  int _cohortCompare(String a, String b) {
    final pa = a.split('|'), pb = b.split('|');
    final ba = int.tryParse(pa[0]) ?? -1, bb = int.tryParse(pb[0]) ?? -1;
    if (ba != bb) return bb.compareTo(ba);
    return pa[1].compareTo(pb[1]);
  }
}
