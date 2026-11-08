// ============================================================
// FILE: lib/features/rooms/screens/room_detail_screen.dart
// PURPOSE: "More details" for one room — its full day-by-day schedule.
// Opens on today; the day strip switches which day is listed.
//
// Fetches its own rows rather than taking them from the list screen, so
// the route survives a deep link or a back-stack restore with only the
// room name in `extra`.
// ============================================================

// PHASE 1: Missing detail identifiers recover to the Campus directory.
import 'package:go_router/go_router.dart';
import 'package:universe/core/router/route_names.dart';
import 'package:flutter/material.dart';
import 'package:universe/core/models/routine_model.dart';
import 'package:universe/core/utils/room_identity.dart';
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
  // PHASE 1: An injectable reader keeps identity/reload behavior independent of transport.
  final Future<List<RoutineEntry>> Function()? routineLoader;

  const RoomDetailScreen({super.key, required this.room, this.routineLoader});

  @override
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> {
  // PHASE 1: Older asynchronous reads cannot overwrite a newer URL identity.
  int _loadEpoch = 0;
  List<RoutineEntry>? _entries;
  String? _error;

  @override
  void initState() {
    super.initState();
    // PHASE 1: Empty deep links must not query all published routines.
    if (widget.room.trim().isNotEmpty) _load();
  }

  // PHASE 1: GoRouter reuses detail state when only the query identifier changes.
  @override
  void didUpdateWidget(covariant RoomDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.room != widget.room) {
      _loadEpoch++;
      _entries = null;
      _error = null;
      if (widget.room.trim().isNotEmpty) _load();
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
          RoomStatusService().fetchAllRoutines());
      // PHASE 1: Ignore a response for an identity the user has already left.
      if (!mounted || epoch != _loadEpoch) return;
      setState(() {
        _entries = all
            .where((e) =>
                RoomIdentity.currentKey(e.room) ==
                RoomIdentity.currentKey(widget.room))
            .toList();
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
        title: widget.room,
        subtitle: 'Weekly schedule',
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // PHASE 1: A refresh with no identifier is an explicit recoverable empty state.
    if (widget.room.trim().isEmpty) {
      return UEmptyState(
        icon: PhosphorIconsRegular.magnifyingGlass,
        title: 'No room selected',
        message: 'Choose a room from Campus Lookup.',
        action: UButton(
            label: 'Back to Rooms',
            fullWidth: false,
            onPressed: () => context.go(RouteNames.rooms)),
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
