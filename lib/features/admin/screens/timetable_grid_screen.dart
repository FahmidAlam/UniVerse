import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/models/routine_model.dart';
import 'package:universe/core/utils/room_identity.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/core/router/route_names.dart';
import 'package:universe/features/admin/controllers/routine_admin_controller.dart';
import 'package:universe/features/admin/scheduling/fixtures/scheduling_preview_fixtures.dart';
import 'package:universe/features/admin/widgets/admin_schedule_slot.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/shared/widgets/u_app_bar.dart';
import 'package:universe/shared/widgets/u_button.dart';
import 'package:universe/shared/widgets/u_loading.dart';
import 'package:universe/shared/widgets/u_text_field.dart';
import 'package:universe/shared/widgets/desktop_shell_scope.dart';
import 'package:universe/features/routine/services/routine_service.dart';
import 'package:universe/shared/widgets/u_card.dart';
import 'package:universe/shared/widgets/u_empty_state.dart';
import 'package:universe/shared/widgets/u_segmented_control.dart';
import 'package:universe/shared/widgets/u_adaptive_overlay.dart';

class TimetablePreview {
  final List<RoutineEntry> rows;
  final Map<String, String> roomAliases;
  const TimetablePreview({required this.rows, this.roomAliases = const {}});
}

class TimetableGridScreen extends StatefulWidget {
  final List<RoutineEntry>? rows;
  final Map<String, String> roomAliases;
  final bool embedded;
  final RoutineAdminController? adminController;

  const TimetableGridScreen({
    super.key,
    this.rows,
    this.roomAliases = const {},
    this.embedded = false,
    this.adminController,
  });

  @override
  State<TimetableGridScreen> createState() => _TimetableGridScreenState();
}

class _TimetableGridScreenState extends State<TimetableGridScreen> {
  String _day = '', _student = '', _teacher = '', _room = '';
  String _view = 'Section';
  RoutineEntry? _selected;
  final PageController _agenda = PageController();
  final ScrollController _horizontalScrollController = ScrollController();
  List<RoutineEntry>? _loadedRows;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.rows == null || widget.rows!.isEmpty) {
      _loadRoutine();
    } else {
      _applySmartDefaultDay();
    }
  }

  Future<void> _loadRoutine() async {
    if (widget.adminController != null && widget.adminController!.totalCount > 0) {
      if (mounted) {
        setState(() {
          _loadedRows = widget.adminController!.allRows;
          _loading = false;
          _applySmartDefaultDay();
        });
      }
      return;
    }
    setState(() => _loading = true);
    try {
      final entries = await RoutineService()
          .fetchAll()
          .timeout(const Duration(seconds: 4));
      if (entries.isNotEmpty) {
        _loadedRows = entries;
      } else {
        _loadedRows = SchedulingPreviewFixtures.candidateRoutineRows;
      }
    } catch (_) {
      _loadedRows = SchedulingPreviewFixtures.candidateRoutineRows;
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _applySmartDefaultDay();
        });
      }
    }
  }

  void _applySmartDefaultDay() {
    if (allRows.length > 120 && _day.isEmpty) {
      _day = 'Sunday';
    }
  }

  List<RoutineEntry> get allRows {
    if (widget.rows != null && widget.rows!.isNotEmpty) {
      return widget.rows!;
    }
    if (widget.adminController != null && widget.adminController!.totalCount > 0) {
      return widget.adminController!.allRows;
    }
    return _loadedRows ?? const [];
  }

  String roomKey(String room) =>
      RoomIdentity.key(room, aliases: widget.roomAliases);
  bool get _filtered =>
      [_day, _student, _teacher, _room].any((s) => s.isNotEmpty);

  List<RoutineEntry> get visibleRows => allRows
      .where((r) =>
          (_day.isEmpty || r.day == _day) &&
          (_student.isEmpty ||
              r.matchesStudent(
                  _student.split('|')[0], _student.split('|')[1])) &&
          (_teacher.isEmpty || r.matchesTeacher(_teacher)) &&
          (_room.isEmpty || roomKey(r.room) == _room))
      .toList();
  @override
  void dispose() {
    _agenda.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  void _reset() => setState(() {
        _day = '';
        _student = '';
        _teacher = '';
        _room = '';
        _selected = null;
      });
  void _chooseDay(String value) {
    setState(() {
      _day = value;
      _selected = null;
    });
    if (_agenda.hasClients) _agenda.jumpToPage(0);
  }

  void _inspect(RoutineEntry entry, bool dock) {
    setState(() => _selected = entry);
    if (!dock) {
      showUAdaptiveModal<void>(
          context: context,
          title: 'Slot Provenance & Resource Inspector',
          subtitle: 'Generated preview · not publication evidence',
          maxDesktopWidth: 520,
          builder: (_) => SingleChildScrollView(child: _details(entry)));
    }
  }

  Widget _selector(String label, String value, Set<String> choices,
          ValueChanged<String> change, double width) =>
      SizedBox(
        width: width,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: AppTextStyles.labelCaps
                  .copyWith(color: AppColors.textMuted, fontSize: 10)),
          const SizedBox(height: AppSpacing.sm),
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
                color: AppColors.bgPrimary,
                borderRadius: AppSpacing.radiusSm,
                border: Border.all(color: AppColors.border)),
            child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: AppColors.bgElevated,
              style: AppTextStyles.bodySm.copyWith(
                  fontFamily:
                      Theme.of(context).textTheme.bodyMedium?.fontFamily),
              items: [
                DropdownMenuItem(
                    value: '', child: Text('All', style: AppTextStyles.bodySm)),
                for (final c in choices.toList()..sort())
                  DropdownMenuItem(
                      value: c,
                      child: Text(c.replaceAll('|', ' · '),
                          overflow: TextOverflow.ellipsis))
              ],
              onChanged: (v) => setState(() {
                change(v ?? '');
                _selected = null;
              }),
            )),
          ),
        ]),
      );
  Widget _pill(String text) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
            color: AppColors.bgElevated,
            borderRadius: AppSpacing.radiusSm,
            border: Border.all(color: AppColors.border)),
        child: Text(text, style: AppTextStyles.captionMedium),
      );
  Widget _toolbar(double width) {
    final fieldWidth = width < 600 ? (width - 64) / 2 : 180.0;
    final rows = visibleRows;
    return UCard(
        isTopLit: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.md, children: [
            _selector(
                'COHORT / SECTION',
                _student,
                {
                  for (final r in allRows)
                    for (final s in r.section.split('+'))
                      '${r.batch}|${s.trim()}'
                },
                (v) => _student = v,
                fieldWidth),
            _selector(
                'FACULTY MEMBER',
                _teacher,
                {for (final r in allRows) ...r.teacherCodes},
                (v) => _teacher = v,
                fieldWidth),
            _selector(
                'ROOM POOL',
                _room,
                {for (final r in allRows) roomKey(r.room)},
                (v) => _room = v,
                fieldWidth),
            SizedBox(
                width: math.max(280.0, fieldWidth),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('OPERATIONAL LENS',
                          style: AppTextStyles.labelCaps.copyWith(
                              color: AppColors.textMuted, fontSize: 10)),
                      const SizedBox(height: AppSpacing.sm),
                      USegmentedControl<String>(
                          compact: true,
                          selected: _view,
                          segments: const [
                            USegment(value: 'Section', label: 'Section'),
                            USegment(value: 'Faculty', label: 'Faculty'),
                            USegment(value: 'Room', label: 'Room')
                          ],
                          onChanged: (v) => setState(() => _view = v)),
                    ])),
          ]),
          const SizedBox(height: AppSpacing.md),
          Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _pill('Showing ${rows.length} of ${allRows.length} slots'),
                _pill(
                    '${rows.map((r) => '${r.batch}|${r.section}').toSet().length} Cohorts'),
                _pill(
                    '${rows.map((r) => roomKey(r.room)).toSet().length} Rooms Active'),
                if (_filtered)
                  TextButton.icon(
                      onPressed: _reset,
                      icon: const Icon(Icons.restart_alt, size: 16),
                      label: const Text('Reset Filters')),
              ]),
        ]));
  }

  Widget _dayBar() => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
          width: 660,
          child: USegmentedControl<String>(
              compact: true,
              selected: _day,
              onChanged: _chooseDay,
              segments: [
                const USegment(value: '', label: 'All Days'),
                for (final d in AppConstants.weekDays)
                  USegment(value: d, label: d.substring(0, 3)),
              ])));

  @override
  Widget build(BuildContext context) {
    final hideAppBar = widget.embedded || DesktopShellScope.isDesktopOf(context);
    return Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: hideAppBar
            ? null
            : const UAppBar(
                title: 'Timetable Grid', subtitle: 'Operational 2D view'),
        body: _loading
            ? const Center(child: ULoading.spinner())
            : allRows.isEmpty
                ? UEmptyState(
                    icon: PhosphorIconsRegular.gridFour,
                    title: 'No Timetable Slots Found',
                    message:
                        'Generate a routine or quick-add slots to view scheduled classes.',
                    action: Column(mainAxisSize: MainAxisSize.min, children: [
                      UButton(
                          label: 'Open Routine Generator',
                          fullWidth: false,
                          onPressed: () => context
                              .go('${RouteNames.routineManagement}?tab=generate')),
                      const SizedBox(height: AppSpacing.sm),
                      UButton(
                          label: 'View Slot List & CRUD',
                          fullWidth: false,
                          variant: UButtonVariant.secondary,
                          onPressed: () =>
                              context.go('${RouteNames.routineManagement}?tab=manage')),
                    ]))
                : LayoutBuilder(builder: (context, constraints) {
                    final dock = constraints.maxWidth >= 1100;
                    final matrix = constraints.maxWidth >= 860;
                    final rows = visibleRows;
                    final selected = _selected != null && rows.contains(_selected)
                        ? _selected
                        : null;
                    return Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _toolbar(constraints.maxWidth - AppSpacing.lg * 2),
                              const SizedBox(height: AppSpacing.md),
                              _dayBar(),
                              const SizedBox(height: AppSpacing.md),
                              Expanded(
                                  child: rows.isEmpty
                                      ? UEmptyState(
                                          icon: PhosphorIconsRegular.calendarX,
                                          title: 'No matching slots',
                                          message:
                                              'Try another day, cohort, faculty member or room.',
                                          action: TextButton(
                                              onPressed: _reset,
                                              child: const Text('Reset Filters')))
                                      : Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                              Expanded(
                                                  child: RepaintBoundary(
                                                      child: matrix
                                                          ? _matrix(rows, dock)
                                                          : _mobileAgenda(rows))),
                                              if (dock && selected != null) ...[
                                                const SizedBox(
                                                    width: AppSpacing.lg),
                                                SizedBox(
                                                    width: 340,
                                                    child: UCard(
                                                        isTopLit: true,
                                                        child:
                                                            SingleChildScrollView(
                                                            child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                          Row(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .spaceBetween,
                                                            children: [
                                                              Expanded(
                                                                child: Text(
                                                                  'Slot Provenance & Resource Inspector',
                                                                  style:
                                                                      AppTextStyles
                                                                          .h4,
                                                                ),
                                                              ),
                                                              IconButton(
                                                                icon: const Icon(
                                                                    Icons.close,
                                                                    size: 18),
                                                                tooltip:
                                                                    'Close Inspector',
                                                                onPressed: () =>
                                                                    setState(() =>
                                                                        _selected =
                                                                            null),
                                                              ),
                                                            ],
                                                          ),
                                                          const SizedBox(
                                                              height: AppSpacing
                                                                  .sm),
                                                          Text(
                                                              'Generated preview',
                                                              style:
                                                                  AppTextStyles
                                                                      .caption),
                                                          const Divider(
                                                              height: AppSpacing
                                                                  .xxl),
                                                          _details(selected),
                                                        ])))),
                                          ],
                                        ])),
                        ]));
              }),
      );
  }

  String _group(RoutineEntry e) {
    if (_view == 'Room') return roomKey(e.room);
    if (_view == 'Faculty') return e.teacherCode ?? e.teacherName ?? 'TBA';
    return '${e.batch}|${e.section}';
  }

  Widget _matrix(List<RoutineEntry> rows, bool dock) =>
      LayoutBuilder(builder: (context, constraints) {
        final slots = rows
            .map((r) => '${r.timeStart}|${r.timeEnd}')
            .toSet()
            .toList()
          ..sort();
        final groups = rows.map(_group).toSet().toList()..sort();
        final totalWidth =
            math.max(constraints.maxWidth, 164 + slots.length * 220.0);
        final slotWidth =
            slots.isNotEmpty ? (totalWidth - 164) / slots.length : 220.0;

        // Fast O(1) cell lookup map
        final cellLookup = <String, List<RoutineEntry>>{};
        for (final r in rows) {
          final k = '${r.day}|${_group(r)}|${r.timeStart}|${r.timeEnd}';
          (cellLookup[k] ??= []).add(r);
        }

        // Virtualized matrix items list
        final items = <_MatrixItem>[];
        for (final day in AppConstants.weekDays) {
          final dayGroups = groups
              .where((g) => rows.any((r) => r.day == day && _group(r) == g))
              .toList();
          if (dayGroups.isNotEmpty) {
            items.add(_MatrixDayHeaderItem(day));
            for (final group in dayGroups) {
              items.add(_MatrixGroupRowItem(day, group));
            }
          }
        }

        return Scrollbar(
          controller: _horizontalScrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _horizontalScrollController,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: totalWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    _header(
                        _view == 'Room'
                            ? 'ROOM POOL'
                            : _view == 'Faculty'
                                ? 'FACULTY'
                                : 'COHORT / SECTION',
                        164),
                    for (final slot in slots)
                      _header(slot.replaceAll('|', '–'), slotWidth,
                          clock: true)
                  ]),
                  Expanded(
                    child: ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        if (item is _MatrixDayHeaderItem) {
                          return Container(
                            width: totalWidth,
                            padding: const EdgeInsets.all(AppSpacing.md),
                            color: AppColors.bgElevated,
                            child: Text(item.day, style: AppTextStyles.h4),
                          );
                        } else if (item is _MatrixGroupRowItem) {
                          return _matrixRow(
                            item.day,
                            item.group,
                            slots,
                            cellLookup,
                            slotWidth,
                            dock,
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      });
  Widget _header(String label, double width, {bool clock = false}) => Container(
      width: width,
      height: 56,
      padding: const EdgeInsets.all(AppSpacing.md),
      color: AppColors.bgElevated,
      child: Row(children: [
        if (clock) ...[
          const Icon(Icons.schedule, size: 16, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.sm)
        ],
        Expanded(
            child: Text(label,
                style:
                    clock ? AppTextStyles.timeCode : AppTextStyles.labelCaps))
      ]));
  Widget _matrixRow(String day, String group, List<String> slots,
      Map<String, List<RoutineEntry>> cellLookup, double slotWidth, bool dock) {
    final cells = [
      for (final slot in slots)
        cellLookup['$day|$group|$slot'] ?? const <RoutineEntry>[]
    ];
    final count = cells.fold<int>(1, (n, c) => math.max(n, c.length));
    final height = 180.0 * count;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
          width: 164,
          height: height,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
              color: AppColors.bgCard,
              border: Border(
                  left: BorderSide(color: AppColors.info, width: 3),
                  bottom: BorderSide(color: AppColors.border))),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                _view == 'Room'
                    ? group
                    : _view == 'Faculty'
                        ? 'Faculty $group'
                        : 'Batch ${group.split('|')[0]}',
                style: AppTextStyles.h4),
            if (_view == 'Section')
              Text('Sec ${group.contains('|') ? group.split('|')[1] : ''}', style: AppTextStyles.bodySm),
            const SizedBox(height: AppSpacing.sm),
            Text(
                '${allRows.where((r) => _group(r) == group).length} weekly slots',
                style: AppTextStyles.caption),
          ])),
      for (var i = 0; i < slots.length; i++)
        Container(
            width: slotWidth,
            height: height,
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
                color: AppColors.bgPrimary.withValues(alpha: 0.4),
                border: Border.all(color: AppColors.border)),
            child: cells[i].isEmpty
                ? ((day == 'Friday' || day.startsWith('Fri')) &&
                        (slots[i].contains('12:50') ||
                            slots[i].contains('12:45') ||
                            slots[i].contains('13:10') ||
                            slots[i].contains('13:00') ||
                            slots[i].contains('01:10') ||
                            i == 3))
                    ? Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: AppColors.error.withValues(alpha: 0.4)),
                        ),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(PhosphorIconsRegular.lock,
                                size: 14, color: AppColors.error),
                            const SizedBox(height: 2),
                            Text(
                              'JUMMAH PRAYER BLOCK\n(NO CLASSES)',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.error,
                                fontWeight: FontWeight.bold,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      )
                    : InkWell(
                        onTap: () => _openQuickAddModal(day, slots[i], group),
                        borderRadius: BorderRadius.circular(4),
                        child: Semantics(
                          label: '$day $group ${slots[i]}: Unscheduled slot. Tap to quick-add class.',
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(PhosphorIconsRegular.plus, size: 12, color: AppColors.textMuted),
                                const SizedBox(width: 2),
                                Text('Add', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted, fontSize: 10)),
                              ],
                            ),
                          ),
                        ),
                      )
                : SingleChildScrollView(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                        if (cells[i].length > 1)
                          Text('${cells[i].length} overlapping entries',
                              style: AppTextStyles.bodyError),
                        for (final entry in cells[i])
                          Padding(
                              padding:
                                  const EdgeInsets.only(bottom: AppSpacing.xs),
                              child: AdminScheduleSlot(
                                  entry: entry,
                                  roomAliases: widget.roomAliases,
                                  selected: identical(_selected, entry),
                                  onTap: () => _inspect(entry, dock))),
                      ]))),
    ]);
  }

  Widget _mobileAgenda(List<RoutineEntry> rows) {
    final days = AppConstants.weekDays
        .where((d) => rows.any((r) => r.day == d))
        .toList();
    return PageView.builder(
        controller: _agenda,
        itemCount: days.length,
        itemBuilder: (context, index) {
          final dayRows = rows.where((r) => r.day == days[index]).toList()
            ..sort((a, b) => a.timeStart.compareTo(b.timeStart));
          return ListView(children: [
            Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Text(
                    '${days[index]} · ${index + 1}/${days.length} · Swipe for next day',
                    style: AppTextStyles.captionMedium)),
            for (var i = 0; i < dayRows.length; i++) ...[
              if (i == 0 || dayRows[i].timeStart != dayRows[i - 1].timeStart)
                Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: Text(dayRows[i].timeLabel,
                        style: AppTextStyles.timeCode)),
              Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AdminScheduleSlot(
                      entry: dayRows[i],
                      roomAliases: widget.roomAliases,
                      onTap: () => _inspect(dayRows[i], false))),
            ],
          ]);
        });
  }

  Widget _details(RoutineEntry e) {
    final resolved = roomKey(e.room);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(e.subjectCode, style: AppTextStyles.h3),
      const SizedBox(height: AppSpacing.sm),
      Text(e.subject, style: AppTextStyles.bodyMedium),
      const SizedBox(height: AppSpacing.xxl),
      for (final detail in <String, String>{
        'Cohort': 'Batch ${e.batch} · Section ${e.section}',
        'Primary faculty': e.teacherCode ?? e.teacherName ?? 'Unassigned',
        'Co-teachers':
            e.teacherCodes.where((t) => t != e.teacherCode).join(', ').isEmpty
                ? 'None declared'
                : e.teacherCodes.where((t) => t != e.teacherCode).join(', '),
        'Assigned room': resolved,
        if (resolved != e.room) 'Source room alias': '${e.room} → $resolved',
        'Time window': '${e.day} · ${e.timeLabel}',
      }.entries)
        Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(detail.key, style: AppTextStyles.caption),
              const SizedBox(height: AppSpacing.xs),
              Text(detail.value, style: AppTextStyles.bodySmMedium),
            ])),
      UButton(
          label: 'Copy Slot Summary',
          variant: UButtonVariant.secondary,
          icon: Icons.copy,
          onPressed: () async {
            await Clipboard.setData(ClipboardData(
                text:
                    '${e.subjectCode} · ${e.subject}\nBatch ${e.batch} · Section ${e.section}\n${e.teacherDisplay}\n${e.day} · ${e.timeLabel}\nRoom $resolved${resolved != e.room ? ' (source: ${e.room})' : ''}'));
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Slot summary copied')));
            }
          }),
      const SizedBox(height: AppSpacing.sm),
      UButton(
          label: 'Delete Slot',
          variant: UButtonVariant.secondary,
          icon: PhosphorIconsRegular.trash,
          onPressed: () {
            setState(() {
              if (_loadedRows != null) {
                _loadedRows!.removeWhere((r) => r.id == e.id);
              }
              _selected = null;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Removed slot ${e.subjectCode} (${e.day})'),
                backgroundColor: AppColors.error,
              ),
            );
          }),
    ]);
  }

  void _openQuickAddModal(String day, String slotTime, String group) {
    final parts = slotTime.split('|');
    final start = parts.isNotEmpty ? parts[0] : '09:00';
    final end = parts.length > 1 ? parts[1] : '09:50';
    String batch = _view == 'Section' && group.contains('|') ? group.split('|')[0] : '58';
    String section = _view == 'Section' && group.contains('|') ? group.split('|')[1] : 'A';
    String teacher = _view == 'Faculty' ? group : 'MSA';
    String room = _view == 'Room' ? group : '302';
    String subjectCode = 'CSE-3101';
    String subjectTitle = 'Database Systems';

    final batchCtrl = TextEditingController(text: batch);
    final sectionCtrl = TextEditingController(text: section);
    final subjectCodeCtrl = TextEditingController(text: subjectCode);
    final roomCtrl = TextEditingController(text: room);
    final teacherCtrl = TextEditingController(text: teacher);

    showUAdaptiveModal<void>(
      context: context,
      title: 'Quick Add Routine Slot',
      subtitle: '$day · $start–$end',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: UTextField(
                        label: 'Batch',
                        hint: 'e.g., 58',
                        controller: batchCtrl,
                        onChanged: (v) => batch = v.trim(),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: UTextField(
                        label: 'Section',
                        hint: 'e.g., A',
                        controller: sectionCtrl,
                        onChanged: (v) => section = v.trim(),
                      ),
                    ),
                  ],
                ),
                AppSpacing.smGap,
                Row(
                  children: [
                    Expanded(
                      child: UTextField(
                        label: 'Course Code',
                        hint: 'e.g., CSE-3101',
                        controller: subjectCodeCtrl,
                        onChanged: (v) => subjectCode = v.trim(),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: UTextField(
                        label: 'Room',
                        hint: 'e.g., 302',
                        controller: roomCtrl,
                        onChanged: (v) => room = v.trim(),
                      ),
                    ),
                  ],
                ),
                AppSpacing.smGap,
                UTextField(
                  label: 'Teacher Acronym',
                  hint: 'e.g., MSA',
                  controller: teacherCtrl,
                  onChanged: (v) => teacher = v.trim(),
                ),
                AppSpacing.mdGap,
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    UButton(
                      label: 'Cancel',
                      variant: UButtonVariant.secondary,
                      fullWidth: false,
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                    AppSpacing.smGap,
                    UButton(
                      label: 'Add Slot to Routine',
                      fullWidth: false,
                      onPressed: () {
                        final newEntry = RoutineEntry(
                          id: 'slot-',
                          day: day,
                          timeStart: start,
                          timeEnd: end,
                          subject: subjectTitle,
                          subjectCode: subjectCodeCtrl.text.trim().isNotEmpty ? subjectCodeCtrl.text.trim() : subjectCode,
                          teacherCode: teacherCtrl.text.trim().isNotEmpty ? teacherCtrl.text.trim() : teacher,
                          room: roomCtrl.text.trim().isNotEmpty ? roomCtrl.text.trim() : room,
                          batch: batchCtrl.text.trim().isNotEmpty ? batchCtrl.text.trim() : batch,
                          section: sectionCtrl.text.trim().isNotEmpty ? sectionCtrl.text.trim() : section,
                          semester: 5,
                        );
                        setState(() {
                          if (_loadedRows != null) {
                            _loadedRows!.add(newEntry);
                          } else {
                            _loadedRows = [...widget.rows ?? [], newEntry];
                          }
                        });
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Added slot for ${newEntry.subjectCode} on $day $start-$end'),
                            backgroundColor: AppColors.roleTeacher,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );  }
}


sealed class _MatrixItem {}

class _MatrixDayHeaderItem extends _MatrixItem {
  final String day;
  _MatrixDayHeaderItem(this.day);
}

class _MatrixGroupRowItem extends _MatrixItem {
  final String day;
  final String group;
  _MatrixGroupRowItem(this.day, this.group);
}
