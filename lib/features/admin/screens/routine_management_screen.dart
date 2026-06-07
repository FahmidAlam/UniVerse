// ============================================================
// FILE: lib/features/admin/screens/routine_management_screen.dart
// PURPOSE: Admin CRUD over the `routines` table. A day filter + a
// list of entries (tap to edit, trash to delete) and a FAB that
// opens the add/edit form sheet. These rows feed the already-built
// student (batch+section) and teacher (teacher_code) routine views.
// Owns its RoutineAdminController lifecycle.
// ============================================================

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:universe_v1/core/constants/app_constants.dart';
import 'package:universe_v1/core/models/routine_model.dart';
import 'package:universe_v1/core/router/route_names.dart';
import 'package:universe_v1/core/theme/app_colors.dart';
import 'package:universe_v1/core/theme/app_spacing.dart';
import 'package:universe_v1/core/theme/app_text_styles.dart';
import 'package:universe_v1/features/admin/controllers/routine_admin_controller.dart';
import 'package:universe_v1/shared/widgets/app_bottom_nav.dart';
import 'package:universe_v1/shared/widgets/u_app_bar.dart';
import 'package:universe_v1/shared/widgets/u_button.dart';
import 'package:universe_v1/shared/widgets/u_card.dart';
import 'package:universe_v1/shared/widgets/u_chip.dart';
import 'package:universe_v1/shared/widgets/u_empty_state.dart';
import 'package:universe_v1/shared/widgets/u_loading.dart';
import 'package:universe_v1/shared/widgets/u_text_field.dart';

class RoutineManagementScreen extends StatefulWidget {
  const RoutineManagementScreen({super.key});

  @override
  State<RoutineManagementScreen> createState() =>
      _RoutineManagementScreenState();
}

class _RoutineManagementScreenState extends State<RoutineManagementScreen> {
  late final RoutineAdminController _controller;

  @override
  void initState() {
    super.initState();
    _controller = RoutineAdminController();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openForm({RoutineEntry? existing}) async {
    final data = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
          style: AppTextStyles.bodySm,
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
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: const UAppBar(title: 'Routine Management', showBackButton: false),
      bottomNavigationBar: const AppBottomNav(
        role: AppConstants.roleAdmin,
        currentRoute: RouteNames.routineManagement,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _openForm(),
        child: const Icon(PhosphorIconsRegular.plus,
            color: AppColors.textPrimary),
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return Column(
            children: [
              _buildDayFilter(),
              Expanded(child: _buildBody()),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDayFilter() {
    // null filter = "All", then one chip per week day.
    final chips = <({String? day, String label})>[
      (day: null, label: 'All'),
      for (var i = 0; i < AppConstants.weekDays.length; i++)
        (day: AppConstants.weekDays[i], label: AppConstants.weekDaysShort[i]),
    ];

    return SizedBox(
      height: AppSpacing.chipHeight + AppSpacing.lg,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenH,
          vertical: AppSpacing.sm,
        ),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) {
          final c = chips[i];
          return UChip(
            label: c.label,
            isActive: _controller.dayFilter == c.day,
            onTap: () => _controller.setDayFilter(c.day),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_controller.isLoading) {
      return ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        itemCount: 6,
        separatorBuilder: (_, __) => AppSpacing.cardGap,
        itemBuilder: (_, __) => const ULoading.skeleton(skeletonHeight: 84),
      );
    }

    final items = _controller.filtered;
    if (items.isEmpty) {
      return const UEmptyState(
        icon: PhosphorIconsRegular.calendarBlank,
        title: 'No routine entries',
        message: 'Tap + to add a class to the schedule.',
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
  }
}

// ─── List tile ──────────────────────────────────────────────
class _RoutineTile extends StatelessWidget {
  final RoutineEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RoutineTile({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return UCard(
      onTap: onEdit,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.subject}  ·  ${entry.subjectCode}',
                  style: AppTextStyles.h4,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                AppSpacing.xsGap,
                Text(
                  '${entry.day}  ·  ${entry.timeLabel}',
                  style: AppTextStyles.bodySm,
                ),
                AppSpacing.xsGap,
                Text(
                  'Batch ${entry.batch}/${entry.section}  ·  Room ${entry.room}  ·  ${entry.teacherDisplay}',
                  style: AppTextStyles.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(PhosphorIconsRegular.trash,
                color: AppColors.error, size: AppSpacing.iconMd),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

// ─── Add / edit form sheet ──────────────────────────────────
// Returns the routine column map via Navigator.pop, or null on cancel.
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
      initialTime: (isStart ? _start : _end) ??
          const TimeOfDay(hour: 9, minute: 30),
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
          content: Text('Please complete every field.',
              style: AppTextStyles.bodySm),
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
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppSpacing.radiusXlD)),
        ),
        padding: AppSpacing.screenPadding,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(
                    isEdit ? 'Edit routine entry' : 'Add routine entry',
                    style: AppTextStyles.h3,
                  ),
                ),
                AppSpacing.lgGap,
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
                AppSpacing.smGap,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dropdownLabel(String text) =>
      Text(text, style: AppTextStyles.label);

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
          borderSide:
              const BorderSide(color: AppColors.primary, width: 1.5),
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
            padding:
                const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
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
