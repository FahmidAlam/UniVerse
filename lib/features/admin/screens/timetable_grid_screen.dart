import 'package:flutter/material.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/models/routine_model.dart';
import 'package:universe/core/utils/room_identity.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/shared/widgets/u_app_bar.dart';
import 'package:universe/shared/widgets/u_chip.dart';
import 'package:universe/shared/widgets/u_empty_state.dart';

class TimetablePreview {
  final List<RoutineEntry> rows;
  final Map<String, String> roomAliases;
  const TimetablePreview({required this.rows, this.roomAliases = const {}});
}

class TimetableGridScreen extends StatefulWidget {
  final List<RoutineEntry> rows;
  final Map<String, String> roomAliases;

  const TimetableGridScreen(
      {super.key, required this.rows, this.roomAliases = const {}});

  @override
  State<TimetableGridScreen> createState() => _TimetableGridScreenState();
}

class _TimetableGridScreenState extends State<TimetableGridScreen> {
  late String _day;
  String _student = '', _teacher = '', _room = '';
  String roomKey(String room) =>
      RoomIdentity.key(room, aliases: widget.roomAliases);
  List<RoutineEntry> get visibleRows => widget.rows
      .where((r) =>
          (_student.isEmpty ||
              r.matchesStudent(
                  _student.split('|')[0], _student.split('|')[1])) &&
          (_teacher.isEmpty || r.matchesTeacher(_teacher)) &&
          (_room.isEmpty || roomKey(r.room) == _room))
      .toList();

  Widget filter(String label, String value, Set<String> choices,
          ValueChanged<String> update) =>
      SizedBox(
          width: 175,
          child: DropdownButtonFormField<String>(
              initialValue: value,
              decoration: InputDecoration(labelText: label),
              isExpanded: true,
              items: [
                DropdownMenuItem(value: '', child: Text('All $label')),
                for (final c in choices.toList()..sort())
                  DropdownMenuItem(
                      value: c,
                      child: Text(c.replaceAll('|', '-'),
                          overflow: TextOverflow.ellipsis))
              ],
              onChanged: (v) => setState(() => update(v ?? ''))));

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
      appBar:
          const UAppBar(title: 'Timetable Grid', subtitle: 'Generated preview'),
      body: widget.rows.isEmpty
          ? const UEmptyState(
              icon: PhosphorIconsRegular.gridFour,
              title: 'Nothing to show',
              message: 'Generate a timetable first.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                    padding: AppSpacing.screenPaddingH,
                    child: Wrap(spacing: 8, children: [
                      filter(
                          'Student section',
                          _student,
                          {
                            for (final r in widget.rows)
                              for (final s in r.section.split('+'))
                                '${r.batch}|${s.trim()}'
                          },
                          (v) => _student = v),
                      filter(
                          'Faculty',
                          _teacher,
                          {for (final r in widget.rows) ...r.teacherCodes},
                          (v) => _teacher = v),
                      filter(
                          'Room',
                          _room,
                          {for (final r in widget.rows) roomKey(r.room)},
                          (v) => _room = v),
                    ])),
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
    final dayRows = visibleRows.where((r) => r.day == _day).toList();
    if (dayRows.isEmpty) {
      return const UEmptyState(
        icon: PhosphorIconsRegular.calendarX,
        title: 'No classes this day',
      );
    }

    final slots = dayRows.map((r) => r.timeStart).toSet().toList()..sort();
    // Distinct cohorts (rows), canonical order.
    final cohorts = dayRows
        .map((r) => '${r.batch}|${r.section}')
        .toSet()
        .toList()
      ..sort(_cohortCompare);

    final cell = <String, List<RoutineEntry>>{};
    for (final r in dayRows) {
      cell
          .putIfAbsent('${r.batch}|${r.section}@${r.timeStart}', () => [])
          .add(r);
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
            Row(children: [
              _headCell('Batch·Sec', cohortW),
              for (final s in slots) _headCell(_slotLabel(dayRows, s), slotW),
            ]),
            for (final c in cohorts)
              Row(children: [
                _cohortCell(c, cohortW),
                for (final s in slots) _bodyCell(cell['$c@$s'], slotW),
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
          border:
              Border.all(color: AppColors.border, width: AppSpacing.borderThin),
        ),
        child: Text(text,
            style:
                AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
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
        border:
            Border.all(color: AppColors.border, width: AppSpacing.borderThin),
      ),
      child: Text('${parts[0]}-${parts[1]}',
          style: AppTextStyles.chip.copyWith(color: AppColors.primary)),
    );
  }

  Widget _bodyCell(List<RoutineEntry>? entries, double w) {
    return Container(
      width: w,
      height: AppSpacing.heroCardHeight * 0.45,
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: entries == null ? AppColors.bgPrimary : AppColors.bgCard,
        border:
            Border.all(color: AppColors.border, width: AppSpacing.borderThin),
      ),
      child: entries == null
          ? const SizedBox.shrink()
          : SingleChildScrollView(
              child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (entries.length > 1)
                  Text('${entries.length} overlapping entries',
                      style: AppTextStyles.bodyError),
                for (final e in entries) ...[
                  Text(e.subjectCode,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textPrimary)),
                  Text(e.teacherDisplay,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary)),
                  Text(e.room,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.roleTeacher)),
                ],
              ],
            )),
    );
  }

  int _cohortCompare(String a, String b) {
    final pa = a.split('|'), pb = b.split('|');
    final ba = int.tryParse(pa[0]) ?? -1, bb = int.tryParse(pb[0]) ?? -1;
    if (ba != bb) return bb.compareTo(ba);
    return pa[1].compareTo(pb[1]);
  }
}
