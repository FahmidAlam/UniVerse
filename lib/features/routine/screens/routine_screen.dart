// ============================================================
// FILE: lib/features/routine/screens/routine_screen.dart
// PURPOSE: Weekly routine view, shared by students and teachers.
// Reads the role from AuthController: students see their section's
// schedule, teachers see the classes they teach. Day pills switch
// the day; class cards show live/next/done status for today.
// Wired to both /student/routine and /teacher/routine.
// ============================================================

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:universe_v1/core/router/route_names.dart';
import 'package:universe_v1/core/theme/app_colors.dart';
import 'package:universe_v1/core/theme/app_spacing.dart';
import 'package:universe_v1/features/auth/controllers/auth_controller.dart';
import 'package:universe_v1/features/routine/controllers/routine_controller.dart';
import 'package:universe_v1/shared/widgets/app_bottom_nav.dart';
import 'package:universe_v1/shared/widgets/class_card.dart';
import 'package:universe_v1/shared/widgets/day_selector.dart';
import 'package:universe_v1/shared/widgets/u_app_bar.dart';
import 'package:universe_v1/shared/widgets/u_empty_state.dart';
import 'package:universe_v1/shared/widgets/u_loading.dart';

class RoutineScreen extends StatefulWidget {
  final AuthController authController;

  const RoutineScreen({super.key, required this.authController});

  @override
  State<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends State<RoutineScreen> {
  late final RoutineController _controller;

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
          bottomNavigationBar: AppBottomNav(
            role: widget.authController.role,
            currentRoute: _controller.isTeacherView
                ? RouteNames.teacherRoutine
                : RouteNames.studentRoutine,
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  AppSpacing.md,
                  AppSpacing.screenH,
                  AppSpacing.md,
                ),
                child: DaySelector(
                  selectedDay: _controller.selectedDay,
                  onSelect: _controller.setDay,
                ),
              ),
              Expanded(child: _buildBody()),
            ],
          ),
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
}
