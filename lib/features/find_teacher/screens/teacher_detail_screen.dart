// ============================================================
// FILE: lib/features/find_teacher/screens/teacher_detail_screen.dart
// PURPOSE: "More details" for one teacher — their full day-by-day
// teaching schedule. Opens on today; the day strip switches the day.
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:universe/core/models/routine_model.dart';
import 'package:universe/core/router/route_names.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/features/find_teacher/services/teacher_location_service.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/shared/widgets/class_card.dart';
import 'package:universe/shared/widgets/u_app_bar.dart';
import 'package:universe/shared/widgets/u_button.dart';
import 'package:universe/shared/widgets/u_empty_state.dart';
import 'package:universe/shared/widgets/u_loading.dart';
import 'package:universe/shared/widgets/weekly_schedule_view.dart';

/// Route payload for [RouteNames.teacherDetail] — passed as GoRouter `extra`.
class TeacherDetailArgs {
  final String code;
  final String name;
  final String dept;
  final String desig;

  const TeacherDetailArgs({
    required this.code,
    required this.name,
    this.dept = '',
    this.desig = '',
  });

  static TeacherDetailArgs resolve(Object? extra, Uri uri) {
    if (extra is TeacherDetailArgs && extra.code.trim().isNotEmpty) {
      return extra;
    }
    final query = uri.queryParameters;
    final code = query['code']?.trim() ?? '';
    final name = query['name']?.trim() ?? '';
    return TeacherDetailArgs(
      code: code,
      name: name.isEmpty ? code : name,
      dept: query['dept'] ?? '',
      desig: query['desig'] ?? '',
    );
  }
}

class TeacherDetailScreen extends StatelessWidget {
  final String teacherCode;
  final Future<List<RoutineEntry>> Function()? routineLoader;
  final String teacherName;
  final String department;
  final String designation;

  const TeacherDetailScreen({
    super.key,
    required this.teacherCode,
    this.routineLoader,
    required this.teacherName,
    this.department = '',
    this.designation = '',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: UAppBar(
        title: teacherName,
        subtitle: teacherCode,
      ),
      body: TeacherDetailView(
        teacherCode: teacherCode,
        teacherName: teacherName,
        routineLoader: routineLoader,
      ),
    );
  }
}

class TeacherDetailView extends StatefulWidget {
  final String teacherCode;
  final String teacherName;
  final Future<List<RoutineEntry>> Function()? routineLoader;

  const TeacherDetailView({
    super.key,
    required this.teacherCode,
    required this.teacherName,
    this.routineLoader,
  });

  @override
  State<TeacherDetailView> createState() => _TeacherDetailViewState();
}

class _TeacherDetailViewState extends State<TeacherDetailView> {
  int _loadEpoch = 0;
  List<RoutineEntry>? _entries;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.teacherCode.trim().isNotEmpty) _load();
  }

  @override
  void didUpdateWidget(covariant TeacherDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.teacherCode != widget.teacherCode) {
      _loadEpoch++;
      _entries = null;
      _error = null;
      if (widget.teacherCode.trim().isNotEmpty) _load();
    }
  }

  Future<void> _load() async {
    final epoch = ++_loadEpoch;
    setState(() {
      _error = null;
      _entries = null;
    });
    try {
      final all = await (widget.routineLoader?.call() ??
          TeacherLocationService().fetchAllRoutines());
      if (!mounted || epoch != _loadEpoch) return;
      setState(() {
        _entries =
            all.where((e) => e.matchesTeacher(widget.teacherCode)).toList();
      });
    } catch (e) {
      if (!mounted || epoch != _loadEpoch) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.teacherCode.trim().isEmpty) {
      return UEmptyState(
        icon: PhosphorIconsRegular.magnifyingGlass,
        title: 'No faculty member selected',
        message: 'Choose a faculty member from Campus Lookup.',
        action: UButton(
          label: 'Back to Faculty',
          fullWidth: false,
          onPressed: () => context.go(RouteNames.findTeacher),
        ),
      );
    }
    if (_error != null) {
      return UEmptyState(
        icon: PhosphorIconsRegular.warningCircle,
        title: 'Could not load schedule',
        message: _error,
        action: UButton(
          label: 'Retry',
          icon: PhosphorIconsRegular.arrowClockwise,
          variant: UButtonVariant.secondary,
          fullWidth: false,
          onPressed: _load,
        ),
      );
    }

    final entries = _entries;
    if (entries == null) return const ULoading.spinner();

    if (entries.isEmpty) {
      return UEmptyState(
        icon: PhosphorIconsRegular.chalkboardTeacher,
        title: 'No classes assigned',
        message: '${widget.teacherName} has nothing on the published routine.',
      );
    }

    return WeeklyScheduleView(
      entries: entries,
      emptyMessage: '${widget.teacherName} has no classes this day.',
      rowBuilder: (context, entry, status) => ClassCard(
        subject: entry.subject,
        teacher: entry.subjectCode,
        room: entry.room,
        timeSlot: entry.timeLabel,
        status: status,
        batch: entry.batch,
        section: entry.section,
      ),
    );
  }
}
