import 'package:universe/features/admin/widgets/admin_schedule_slot.dart';
import 'package:flutter/material.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/models/routine_model.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/admin/controllers/routine_admin_controller.dart';
import 'package:universe/shared/widgets/u_adaptive_overlay.dart';
import 'package:universe/shared/widgets/u_app_bar.dart';
import 'package:universe/shared/widgets/u_button.dart';
import 'package:universe/shared/widgets/u_card.dart';
import 'package:universe/shared/widgets/u_empty_state.dart';
import 'package:universe/shared/widgets/u_loading.dart';
import 'package:universe/shared/widgets/u_text_field.dart';

class RoutineManagementScreen extends StatefulWidget {
  final bool embedded;
  // PHASE 5: Optional DI seam for deterministic offline widget testing.
  final RoutineAdminController? controller;

  const RoutineManagementScreen({
    super.key,
    this.embedded = false,
    this.controller,
  });

  @override
  State<RoutineManagementScreen> createState() =>
      _RoutineManagementScreenState();
}

class _RoutineManagementScreenState extends State<RoutineManagementScreen> {
  late final RoutineAdminController _controller;
  late final bool _ownsController;
  String _cohort = '';
  String _query = '';
  final _searchController = TextEditingController();
  List<RoutineEntry> get _visible => _controller.filtered
      .where((e) =>
          (_cohort.isEmpty || '${e.batch}|${e.section}' == _cohort) &&
          (_query.isEmpty ||
              '${e.subjectCode} ${e.subject} ${e.teacherDisplay} ${e.room}'
                  .toLowerCase()
                  .contains(_query.toLowerCase())))
      .toList();

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? RoutineAdminController();
    if (!_controller.hasLoaded) {
      _controller.load();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  // PHASE 5: Adaptive modal dialog on desktop (>= 768px) and floating bottom sheet on mobile (< 768px).
  Future<void> _openForm({RoutineEntry? existing}) async {
    final isEdit = existing != null;
    final data = await showUAdaptiveModal<Map<String, dynamic>>(
      context: context,
      title: isEdit ? 'Edit Routine Entry' : 'Add Routine Entry',
      subtitle: 'Configure scheduled class slot, cohort, faculty, and room.',
      badge: 'LIVE ROUTINE TABLE',
      icon: PhosphorIconsRegular.calendarCheck,
      maxDesktopWidth: 520,
      builder: (_) => _RoutineFormSheet(initial: existing),
    );
    if (data == null) return;

    final ok = await _controller.save(existing: existing, data: data);
    if (!mounted) return;
    _snack(ok
        ? (existing == null ? 'Routine entry added.' : 'Routine entry updated.')
        : (_controller.errorMessage ?? 'Could not save entry.'));
  }

  Future<void> _confirmDelete(RoutineEntry e) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: AppSpacing.radiusLg),
        title: Text('Delete entry?', style: AppTextStyles.h3),
        content: Text(
          '${e.subject} (${e.day}, ${e.timeLabel}) will be removed.',
          style: AppTextStyles.bodySm.copyWith(
              fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: AppTextStyles.danger),
          ),
        ],
      ),
    );
    if (confirmed == true) await _controller.delete(e.id);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: AppTextStyles.bodySm),
        backgroundColor: AppColors.bgElevated,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fab = FloatingActionButton(
      backgroundColor: AppColors.primary,
      onPressed: () => _openForm(),
      child:
          const Icon(PhosphorIconsRegular.plus, color: AppColors.textPrimary),
    );

    final content = ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return Column(
          children: [
            _buildDayFilter(),
            Expanded(child: _buildBody()),
          ],
        );
      },
    );

    if (widget.embedded) {
      return Stack(
        children: [
          Positioned.fill(child: content),
          Positioned(right: AppSpacing.lg, bottom: AppSpacing.lg, child: fab),
        ],
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: const UAppBar(title: 'Routine Management', showBackButton: false),
      floatingActionButton: fab,
      body: content,
    );
  }

  // PHASE 5: Labels live outside controls, preserving their baseline at every width.
  Widget _buildDayFilter() => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: UCard(
            isTopLit: true,
            child: LayoutBuilder(builder: (context, constraints) {
              final width =
                  constraints.maxWidth < 600 ? constraints.maxWidth : 184.0;
              final cohorts = _controller.filtered
                  .map((e) => '${e.batch}|${e.section}')
                  .toSet()
                  .toList()
                ..sort();
              return Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    _filterControl(
                        'COHORT',
                        width,
                        DropdownButton<String>(
                          value: cohorts.contains(_cohort) ? _cohort : '',
                          isExpanded: true,
                          dropdownColor: AppColors.bgElevated,
                          style: AppTextStyles.bodySm.copyWith(
                              fontFamily: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.fontFamily),
                          items: [
                            const DropdownMenuItem(
                                value: '', child: Text('All cohorts')),
                            for (final c in cohorts)
                              DropdownMenuItem(
                                  value: c,
                                  child: Text(
                                      'Batch ${c.replaceAll('|', ' \u00b7 Sec ')}',
                                      overflow: TextOverflow.ellipsis))
                          ],
                          onChanged: (v) => setState(() => _cohort = v ?? ''),
                        )),
                    _filterControl(
                        'DAY',
                        width,
                        DropdownButton<String>(
                          value: _controller.dayFilter ?? '',
                          isExpanded: true,
                          dropdownColor: AppColors.bgElevated,
                          style: AppTextStyles.bodySm.copyWith(
                              fontFamily: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.fontFamily),
                          items: [
                            const DropdownMenuItem(
                                value: '', child: Text('All days')),
                            for (final d in AppConstants.weekDays)
                              DropdownMenuItem(value: d, child: Text(d))
                          ],
                          onChanged: (v) {
                            setState(() => _cohort = '');
                            _controller.setDayFilter(v == '' ? null : v);
                          },
                        )),
                    _filterControl(
                        'SEARCH',
                        width,
                        TextField(
                          controller: _searchController,
                          style: AppTextStyles.bodySm.copyWith(
                              fontFamily: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.fontFamily),
                          decoration: InputDecoration(
                              hintStyle: AppTextStyles.bodySm.copyWith(
                                  fontFamily: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.fontFamily,
                                  color: AppColors.textMuted),
                              hintText: 'Course, faculty or room',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero),
                          onChanged: (v) => setState(() => _query = v),
                        )),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                          color: AppColors.bgElevated,
                          borderRadius: AppSpacing.radiusSm,
                          border: Border.all(color: AppColors.border)),
                      child: Text(
                          'Showing ${_visible.length} of ${_controller.totalCount} published slots',
                          style: AppTextStyles.captionMedium),
                    ),
                  ]);
            })),
      );

  Widget _filterControl(String label, double width, Widget control) => SizedBox(
      width: width,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppTextStyles.labelCaps),
        AppSpacing.smGap,
        Container(
            height: 40,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
                color: AppColors.bgPrimary,
                borderRadius: AppSpacing.radiusSm,
                border: Border.all(color: AppColors.border)),
            child: DropdownButtonHideUnderline(child: control)),
      ]));

  Widget _buildBody() {
    if (_controller.isLoading) {
      return ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        itemCount: 6,
        separatorBuilder: (_, __) => AppSpacing.cardGap,
        itemBuilder: (_, __) => const ULoading.skeleton(skeletonHeight: 84),
      );
    }

    final items = _visible;
    if (items.isEmpty) {
      return UEmptyState(
        icon: PhosphorIconsRegular.calendarBlank,
        title: _controller.totalCount > 0
            ? 'No matching published slots'
            : 'No routine entries',
        message: _controller.totalCount > 0
            ? 'Try another cohort, day or search.'
            : 'Tap + to add a class to the schedule.',
        action: _controller.totalCount > 0
            ? TextButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _query = '';
                    _cohort = '';
                  });
                  _controller.setDayFilter(null);
                },
                child: const Text('Clear filters'))
            : null,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 960;
        if (isDesktop) {
          return GridView.builder(
            padding: AppSpacing.screenPadding,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: constraints.maxWidth >= 1400 ? 3 : 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: AppSpacing.md,
              mainAxisExtent: 240,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final e = items[i];
              return _RoutineTile(
                entry: e,
                onEdit: () => _openForm(existing: e),
                onDelete: () => _confirmDelete(e),
              );
            },
          );
        }
        return ListView.separated(
          padding: AppSpacing.screenPadding,
          itemCount: items.length,
          separatorBuilder: (_, __) => AppSpacing.cardGap,
          itemBuilder: (context, i) {
            final e = items[i];
            return _RoutineTile(
              entry: e,
              onEdit: () => _openForm(existing: e),
              onDelete: () => _confirmDelete(e),
            );
          },
        );
      },
    );
  }
}

class _RoutineTile extends StatefulWidget {
  final RoutineEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _RoutineTile(
      {required this.entry, required this.onEdit, required this.onDelete});
  @override
  State<_RoutineTile> createState() => _RoutineTileState();
}

class _RoutineTileState extends State<_RoutineTile> {
  bool _active = false;
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final showActions = _active || MediaQuery.sizeOf(context).width < 960;
        return Focus(
            onFocusChange: (v) => setState(() => _active = v),
            child: MouseRegion(
              onEnter: (_) => setState(() => _active = true),
              onExit: (_) => setState(() => _active = false),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AdminScheduleSlot(
                        entry: widget.entry, onTap: widget.onEdit),
                    SizedBox(
                        height: 40,
                        child: Row(children: [
                          Expanded(
                              child: Text(
                                  '${widget.entry.day} ? ${widget.entry.timeLabel}',
                                  style: AppTextStyles.caption)),
                          Opacity(
                              opacity: showActions ? 1 : 0,
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                        tooltip: 'Edit slot',
                                        onPressed: widget.onEdit,
                                        icon: const Icon(Icons.edit_outlined,
                                            size: AppSpacing.iconSm)),
                                    IconButton(
                                        tooltip: 'Delete slot',
                                        onPressed: widget.onDelete,
                                        icon: const Icon(Icons.delete_outline,
                                            size: AppSpacing.iconSm,
                                            color: AppColors.error)),
                                  ])),
                        ])),
                  ]),
            ));
      });
}

class _RoutineFormSheet extends StatefulWidget {
  final RoutineEntry? initial;

  const _RoutineFormSheet({this.initial});

  @override
  State<_RoutineFormSheet> createState() => _RoutineFormSheetState();
}

class _RoutineFormSheetState extends State<_RoutineFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _subjectCtrl;
  late final TextEditingController _codeCtrl;
  late final TextEditingController _teacherNameCtrl;
  late final TextEditingController _teacherCodeCtrl;
  late final TextEditingController _roomCtrl;
  late final TextEditingController _batchCtrl;
  late final TextEditingController _sectionCtrl;

  String? _day;
  int? _semester;
  TimeOfDay? _start;
  TimeOfDay? _end;

  @override
  void initState() {
    super.initState();
    final e = widget.initial;
    _subjectCtrl = TextEditingController(text: e?.subject ?? '');
    _codeCtrl = TextEditingController(text: e?.subjectCode ?? '');
    _teacherNameCtrl = TextEditingController(text: e?.teacherName ?? '');
    _teacherCodeCtrl = TextEditingController(text: e?.teacherCode ?? '');
    _roomCtrl = TextEditingController(text: e?.room ?? '');
    _batchCtrl = TextEditingController(text: e?.batch ?? '');
    _sectionCtrl = TextEditingController(text: e?.section ?? '');
    _day = e?.day;
    _semester = e?.semester;
    _start = e == null ? null : _parse(e.timeStart);
    _end = e == null ? null : _parse(e.timeEnd);
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _codeCtrl.dispose();
    _teacherNameCtrl.dispose();
    _teacherCodeCtrl.dispose();
    _roomCtrl.dispose();
    _batchCtrl.dispose();
    _sectionCtrl.dispose();
    super.dispose();
  }

  TimeOfDay? _parse(String s) {
    final p = s.split(':');
    final h = int.tryParse(p.isNotEmpty ? p[0] : '');
    if (h == null) return null;
    final m = p.length > 1 ? (int.tryParse(p[1]) ?? 0) : 0;
    return TimeOfDay(hour: h, minute: m);
  }

  String _dbTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  String _displayTime(TimeOfDay? t) {
    if (t == null) return 'Select time';
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:${t.minute.toString().padLeft(2, '0')} $period';
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
          (isStart ? _start : _end) ?? const TimeOfDay(hour: 9, minute: 30),
    );
    if (picked != null) {
      setState(() => isStart ? _start = picked : _end = picked);
    }
  }

  void _submit() {
    final formOk = _formKey.currentState!.validate();
    final fieldsOk =
        _day != null && _semester != null && _start != null && _end != null;
    if (!formOk || !fieldsOk) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Please complete every field.', style: AppTextStyles.bodySm),
          backgroundColor: AppColors.bgElevated,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    String? clean(String v) => v.trim().isEmpty ? null : v.trim();

    Navigator.pop(context, <String, dynamic>{
      'day': _day,
      'time_start': _dbTime(_start!),
      'time_end': _dbTime(_end!),
      'subject': _subjectCtrl.text.trim(),
      'subject_code': _codeCtrl.text.trim(),
      'teacher_name': clean(_teacherNameCtrl.text),
      'teacher_code': clean(_teacherCodeCtrl.text),
      'room': _roomCtrl.text.trim(),
      'batch': _batchCtrl.text.trim(),
      'section': _sectionCtrl.text.trim(),
      'semester': _semester,
      'is_active': true,
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dropdownLabel('Day'),
            AppSpacing.smGap,
            _dayDropdown(),
            AppSpacing.mdGap,
            Row(
              children: [
                Expanded(child: _timeField('Start', true, _start)),
                AppSpacing.smHGap,
                Expanded(child: _timeField('End', false, _end)),
              ],
            ),
            AppSpacing.mdGap,
            UTextField(
              controller: _subjectCtrl,
              label: 'Subject',
              hint: 'e.g. Operating Systems',
              validator: _required,
            ),
            AppSpacing.mdGap,
            UTextField(
              controller: _codeCtrl,
              label: 'Subject code',
              hint: 'e.g. CSE-3201',
              validator: _required,
            ),
            AppSpacing.mdGap,
            Row(
              children: [
                Expanded(
                  child: UTextField(
                    controller: _teacherNameCtrl,
                    label: 'Teacher name',
                    hint: 'e.g. Dr. Aminul',
                  ),
                ),
                AppSpacing.smHGap,
                Expanded(
                  child: UTextField(
                    controller: _teacherCodeCtrl,
                    label: 'Teacher code',
                    hint: 'e.g. JIM',
                  ),
                ),
              ],
            ),
            AppSpacing.mdGap,
            UTextField(
              controller: _roomCtrl,
              label: 'Room',
              hint: 'e.g. 401',
              validator: _required,
            ),
            AppSpacing.mdGap,
            Row(
              children: [
                Expanded(
                  child: UTextField(
                    controller: _batchCtrl,
                    label: 'Batch',
                    hint: 'e.g. 62',
                    validator: _required,
                  ),
                ),
                AppSpacing.smHGap,
                Expanded(
                  child: UTextField(
                    controller: _sectionCtrl,
                    label: 'Section',
                    hint: 'e.g. G',
                    validator: _required,
                  ),
                ),
              ],
            ),
            AppSpacing.mdGap,
            _dropdownLabel('Semester'),
            AppSpacing.smGap,
            _semesterDropdown(),
            AppSpacing.sectionGap,
            UButton(
              label: isEdit ? 'Save changes' : 'Add entry',
              icon: PhosphorIconsRegular.check,
              onPressed: _submit,
            ),
            AppSpacing.smGap,
            UButton(
              label: 'Cancel',
              variant: UButtonVariant.secondary,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dropdownLabel(String text) => Text(text, style: AppTextStyles.label);

  InputDecoration _decoration(IconData icon) => InputDecoration(
        prefixIcon: Icon(icon, size: AppSpacing.iconMd),
        filled: true,
        fillColor: AppColors.bgElevated,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: AppSpacing.radiusMd,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppSpacing.radiusMd,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppSpacing.radiusMd,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      );

  Widget _dayDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _day,
      style: AppTextStyles.input,
      dropdownColor: AppColors.bgElevated,
      hint: Text('Select day', style: AppTextStyles.placeholder),
      decoration: _decoration(PhosphorIconsRegular.calendarBlank),
      icon: const Icon(PhosphorIconsRegular.caretDown,
          color: AppColors.textMuted, size: AppSpacing.iconMd),
      items: AppConstants.weekDays
          .map((d) => DropdownMenuItem(value: d, child: Text(d)))
          .toList(),
      onChanged: (v) => setState(() => _day = v),
    );
  }

  Widget _semesterDropdown() {
    return DropdownButtonFormField<int>(
      initialValue: _semester,
      style: AppTextStyles.input,
      dropdownColor: AppColors.bgElevated,
      hint: Text('Select semester', style: AppTextStyles.placeholder),
      decoration: _decoration(PhosphorIconsRegular.bookOpen),
      icon: const Icon(PhosphorIconsRegular.caretDown,
          color: AppColors.textMuted, size: AppSpacing.iconMd),
      items: AppConstants.semesters
          .map((s) => DropdownMenuItem(value: s, child: Text('Semester $s')))
          .toList(),
      onChanged: (v) => setState(() => _semester = v),
    );
  }

  Widget _timeField(String label, bool isStart, TimeOfDay? value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label),
        AppSpacing.smGap,
        InkWell(
          onTap: () => _pickTime(isStart),
          borderRadius: AppSpacing.radiusMd,
          child: Container(
            height: AppSpacing.inputHeight,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.bgElevated,
              borderRadius: AppSpacing.radiusMd,
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(PhosphorIconsRegular.clock,
                    size: AppSpacing.iconMd, color: AppColors.textMuted),
                AppSpacing.smHGap,
                Text(
                  _displayTime(value),
                  style: value == null
                      ? AppTextStyles.placeholder
                      : AppTextStyles.input,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
