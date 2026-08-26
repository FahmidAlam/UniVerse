// ============================================================
// FILE: lib/features/rooms/screens/room_detail_screen.dart
// PURPOSE: "More details" for one room — its full day-by-day schedule.
// Opens on today; the day strip switches which day is listed.
//
// Fetches its own rows rather than taking them from the list screen, so
// the route survives a deep link or a back-stack restore with only the
// room name in `extra`.
// ============================================================

import 'package:flutter/material.dart';
import 'package:universe/core/models/routine_model.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/features/rooms/services/room_status_service.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/shared/widgets/class_card.dart';
import 'package:universe/shared/widgets/u_app_bar.dart';
import 'package:universe/shared/widgets/u_button.dart';
import 'package:universe/shared/widgets/u_empty_state.dart';
import 'package:universe/shared/widgets/u_loading.dart';
import 'package:universe/shared/widgets/weekly_schedule_view.dart';

class RoomDetailScreen extends StatefulWidget {
  final String room;

  const RoomDetailScreen({super.key, required this.room});

  @override
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> {
  final RoomStatusService _service = RoomStatusService();

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
        _entries = all.where((e) => e.room == widget.room).toList();
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
        title: widget.room,
        subtitle: 'Weekly schedule',
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
        icon: PhosphorIconsRegular.door,
        title: 'No classes in this room',
        message: '${widget.room} has nothing on the published routine.',
      );
    }

    return WeeklyScheduleView(
      entries: entries,
      emptyMessage: '${widget.room} is free all day.',
      rowBuilder: (context, entry, status) => ClassCard(
        subject: entry.subject,
        teacher: entry.teacherDisplay,
        room: entry.room,
        timeSlot: entry.timeLabel,
        status: status,
        batch: entry.batch,
        section: entry.section,
      ),
    );
  }
}
