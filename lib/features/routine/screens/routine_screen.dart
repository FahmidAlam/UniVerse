import 'package:universe/shared/widgets/u_animated_swap.dart';
import 'package:universe/shared/widgets/u_segmented_control.dart';
import 'package:flutter/material.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/features/routine/controllers/routine_controller.dart';
import 'package:universe/shared/widgets/class_card.dart';
import 'package:universe/shared/widgets/day_selector.dart';
import 'package:universe/shared/widgets/u_app_bar.dart';
import 'package:universe/shared/widgets/u_empty_state.dart';
import 'package:universe/shared/widgets/u_loading.dart';

// PHASE 1 RECONCILE: A manual Day List choice wins over the width-based default.
enum RoutineView { weeklyMatrix, dayList }

class RoutineScreen extends StatefulWidget {
  final AuthController authController;

  const RoutineScreen({super.key, required this.authController});

  @override
  State<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends State<RoutineScreen> {
  late final RoutineController _controller;
  RoutineView? _selectedView;

  @override
  void initState() {
    super.initState();
    _controller = RoutineController(authController: widget.authController);
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.bgPrimary,
          appBar: UAppBar(
            title: _controller.isTeacherView ? 'My Classes' : 'My Routine',
            showBackButton: false,
          ),
          // PHASE 1 RECONCILE: LayoutBuilder sees post-rail/sidebar usable content width.
          body: LayoutBuilder(builder: (context, constraints) {
            final view = _selectedView ??
                (constraints.maxWidth >= 860
                    ? RoutineView.weeklyMatrix
                    : RoutineView.dayList);
            return Column(children: [
              Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenH, AppSpacing.md, AppSpacing.screenH, 0),
                  child: USegmentedControl<RoutineView>(
                      segments: const [
                        USegment(
                            value: RoutineView.weeklyMatrix,
                            label: 'Weekly Matrix'),
                        USegment(value: RoutineView.dayList, label: 'Day List'),
                      ],
                      selected: view,
                      onChanged: (selection) =>
                          setState(() => _selectedView = selection))),
              if (view == RoutineView.dayList)
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.screenH,
                      AppSpacing.md, AppSpacing.screenH, AppSpacing.md),
                  child: DaySelector(
                      selectedDay: _controller.selectedDay,
                      onSelect: _controller.setDay),
                ),
              Expanded(
                  child: UAnimatedSwap(
                      child: KeyedSubtree(
                          key: ValueKey(view),
                          child: view == RoutineView.weeklyMatrix
                              ? _buildWeeklyMatrix()
                              : _buildBody()))),
            ]);
          }),
        );
      },
    );
  }

  Widget _buildBody() {
    if (_controller.isLoading) {
      return ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        itemCount: 4,
        separatorBuilder: (_, __) => AppSpacing.cardGap,
        itemBuilder: (_, __) => const ULoading.skeleton(skeletonHeight: 110),
      );
    }

    final entries = _controller.entriesForSelectedDay;
    if (entries.isEmpty) {
      return const UEmptyState(
        icon: PhosphorIconsRegular.calendarBlank,
        title: 'No classes',
        message: 'Nothing scheduled for this day. Enjoy the break!',
      );
    }

    final today = DateTime.now();
    final isToday = _controller.isSelectedDayToday;
    final isTeacher = _controller.isTeacherView;

    return ListView.separated(
      padding: AppSpacing.screenPaddingScrollable,
      itemCount: entries.length,
      separatorBuilder: (_, __) => AppSpacing.cardGap,
      itemBuilder: (context, i) {
        final e = entries[i];
        return ClassCard(
          subject: e.subject,
          teacher: e.teacherDisplay,
          room: e.room,
          timeSlot: e.timeLabel,
          status: e.statusOn(today, isToday: isToday),
          batch: isTeacher ? e.batch : null,
          section: isTeacher ? e.section : null,
        );
      },
    );
  }

  // PHASE 1 RECONCILE: Matrix presentation never re-queries or broadens B+C/co-teacher matches.
  Widget _buildWeeklyMatrix() {
    if (_controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_controller.entries.isEmpty) {
      return const UEmptyState(
          icon: PhosphorIconsRegular.calendarBlank,
          title: 'No classes',
          message: 'No routine entries are available yet.');
    }
    const days = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday'
    ];
    return SingleChildScrollView(
        padding: AppSpacing.screenPaddingScrollable,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final day in days)
            Expanded(
                child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(day,
                              style: Theme.of(context).textTheme.labelLarge),
                          const SizedBox(height: 8),
                          for (final entry
                              in _controller.entries.where((e) => e.day == day))
                            Card(
                                child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Text(
                                        '${entry.timeLabel}\n${entry.subject}\n${entry.room}'))),
                        ])))
        ]));
  }
}
