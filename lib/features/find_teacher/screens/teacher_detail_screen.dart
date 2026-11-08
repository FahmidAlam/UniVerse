// ============================================================
// FILE: lib/features/find_teacher/screens/teacher_detail_screen.dart
// PURPOSE: "More details" for one teacher — their full day-by-day
// teaching schedule. Opens on today; the day strip switches the day.
//
// Fetches its own rows rather than taking them from the list screen, so
// the route survives a deep link or a back-stack restore with only the
// teacher code in `extra`.
// ============================================================

// PHASE 1: Missing detail identifiers recover to the Campus directory.
import 'package:go_router/go_router.dart';
import 'package:universe/core/router/route_names.dart';
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
  // PHASE 1: Optional URL metadata survives refresh without becoming an identity key.
  final String dept;
  final String desig;

  const TeacherDetailArgs(
      {required this.code,
      required this.name,
      this.dept = '',
      this.desig = ''});

  // PHASE 1: Typed extra is optional; the URL is sufficient for a fresh route build.
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
        desig: query['desig'] ?? '');
  }
}

class TeacherDetailScreen extends StatefulWidget {
  final String teacherCode;
  // PHASE 1: An injectable reader keeps identity/reload behavior independent of transport.
  final Future<List<RoutineEntry>> Function()? routineLoader;
  final String teacherName;
  // PHASE 1: Retain optional directory context across a URL-only refresh.
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
  State<TeacherDetailScreen> createState() => _TeacherDetailScreenState();
}

class _TeacherDetailScreenState extends State<TeacherDetailScreen> {
  // PHASE 1: Older asynchronous reads cannot overwrite a newer URL identity.
  int _loadEpoch = 0;
  List<RoutineEntry>? _entries;
  String? _error;

  @override
  void initState() {
    super.initState();
    // PHASE 1: Empty deep links must not query all published routines.
    if (widget.teacherCode.trim().isNotEmpty) _load();
  }

  // PHASE 1: GoRouter reuses detail state when only the query identifier changes.
  @override
  void didUpdateWidget(covariant TeacherDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.teacherCode != widget.teacherCode) {
      _loadEpoch++;
      _entries = null;
      _error = null;
      if (widget.teacherCode.trim().isNotEmpty) _load();
    }
  }

  Future<void> _load() async {
    // PHASE 1: Each identity change or retry supersedes every prior read.
    final epoch = ++_loadEpoch;
    setState(() {
      _error = null;
      _entries = null;
    });
    try {
      // PHASE 1: Service creation stays inside the recoverable load boundary.
      final all = await (widget.routineLoader?.call() ??
          TeacherLocationService().fetchAllRoutines());
      // PHASE 1: Ignore a response for an identity the user has already left.
      if (!mounted || epoch != _loadEpoch) return;
      setState(() {
        _entries =
            all.where((e) => e.teacherCode == widget.teacherCode).toList();
      });
    } catch (e) {
      // PHASE 1: Ignore a response for an identity the user has already left.
      if (!mounted || epoch != _loadEpoch) return;
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
    // PHASE 1: A refresh with no identifier is an explicit recoverable empty state.
    if (widget.teacherCode.trim().isEmpty) {
      return UEmptyState(
        icon: PhosphorIconsRegular.magnifyingGlass,
        title: 'No faculty member selected',
        message: 'Choose a faculty member from Campus Lookup.',
        action: UButton(
            label: 'Back to Faculty',
            fullWidth: false,
            onPressed: () => context.go(RouteNames.findTeacher)),
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
    if (entries == null) return ULoading.spinner();

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
