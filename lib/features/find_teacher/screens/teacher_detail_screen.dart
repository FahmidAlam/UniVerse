// ============================================================
// FILE: lib/features/find_teacher/screens/teacher_detail_screen.dart
// PURPOSE: "More details" for one teacher — their full day-by-day
// teaching schedule. Opens on today; the day strip switches the day.
//
// Fetches its own rows rather than taking them from the list screen, so
// the route survives a deep link or a back-stack restore with only the
// teacher code in `extra`.
// ============================================================

import 'package:flutter/material.dart';
import 'package:universe/core/models/routine_model.dart';
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

  const TeacherDetailArgs({required this.code, required this.name});
}

class TeacherDetailScreen extends StatefulWidget {
  final String teacherCode;
  final String teacherName;

  const TeacherDetailScreen({
    super.key,
    required this.teacherCode,
    required this.teacherName,
  });

  @override
  State<TeacherDetailScreen> createState() => _TeacherDetailScreenState();
}

class _TeacherDetailScreenState extends State<TeacherDetailScreen> {
  final TeacherLocationService _service = TeacherLocationService();

  List<RoutineEntry>? _entries;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final all = await _service.fetchAllRoutines();
      if (!mounted) return;
      setState(() {
        _entries =
            all.where((e) => e.teacherCode == widget.teacherCode).toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: UAppBar(
        title: widget.teacherName,
        subtitle: widget.teacherCode,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
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
    if (entries == null) return ULoading.spinner();

    if (entries.isEmpty) {
      return UEmptyState(
        icon: PhosphorIconsRegular.chalkboardTeacher,
        title: 'No classes assigned',
        message:
            '${widget.teacherName} has nothing on the published routine.',
      );
    }

    return WeeklyScheduleView(
      entries: entries,
      emptyMessage: '${widget.teacherName} has no classes this day.',
      // On a teacher's own page the teacher name is redundant, so that slot
      // carries the course code instead.
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
