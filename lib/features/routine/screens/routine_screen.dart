import 'package:flutter/material.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/core/models/routine_model.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_motion.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/features/routine/controllers/routine_controller.dart';
import 'package:universe/shared/widgets/class_card.dart';
import 'package:universe/shared/widgets/day_selector.dart';
import 'package:universe/shared/widgets/u_animated_swap.dart';
import 'package:universe/shared/widgets/u_app_bar.dart';
import 'package:universe/shared/widgets/u_empty_state.dart';
import 'package:universe/shared/widgets/u_loading.dart';
import 'package:universe/shared/widgets/u_segmented_control.dart';
import 'package:universe/shared/widgets/u_staggered_list_row.dart';
import 'package:universe/shared/widgets/weekly_schedule_view.dart';

// PHASE 1 RECONCILE & PHASE 4: A manual Day List choice wins over the width-based default (>=860px Weekly Matrix).
enum RoutineView { weeklyMatrix, dayList }

// PHASE 4: Published Routine Experience with Connected Filter & View Context Bar,
// High-Craft Weekly Matrix, Swipeable Day Agenda, and >=40 min Break / Free Window dividers.
class RoutineScreen extends StatefulWidget {
  final AuthController authController;
  final RoutineController? controller;
  final Future<List<RoutineEntry>> Function()? routineLoader;
  final DateTime Function()? clock;

  const RoutineScreen({
    super.key,
    required this.authController,
    this.controller,
    this.routineLoader,
    this.clock,
  });

  @override
  State<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends State<RoutineScreen> {
  late final RoutineController _controller;
  late final bool _ownsController;
  RoutineView? _selectedView;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        RoutineController(
          authController: widget.authController,
          routineLoader: widget.routineLoader,
          clock: widget.clock,
        );
    if (_ownsController || !_controller.hasLoaded) {
      _controller.load();
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
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
          // PHASE 1 RECONCILE & PHASE 4: LayoutBuilder sees post-rail/sidebar usable content width.
          body: LayoutBuilder(
            builder: (context, constraints) {
              final usableWidth = constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : MediaQuery.sizeOf(context).width;
              final view = _selectedView ??
                  (usableWidth >= 860
                      ? RoutineView.weeklyMatrix
                      : RoutineView.dayList);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildConnectedContextBar(
                    view: view,
                    isWide: usableWidth >= 720,
                  ),
                  if (view == RoutineView.dayList)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenH,
                        AppSpacing.sm,
                        AppSpacing.screenH,
                        AppSpacing.sm,
                      ),
                      child: DaySelector(
                        selectedDay: _controller.selectedDay,
                        onSelect: _controller.setDay,
                      ),
                    ),
                  Expanded(
                    child: UAnimatedSwap(
                      child: KeyedSubtree(
                        key: ValueKey(view),
                        child: view == RoutineView.weeklyMatrix
                            ? _buildWeeklyMatrix()
                            : _buildDayListBody(),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  // PHASE 4: Connected Filter & View Context Bar showing active routine lens, live slot counter, and view toggle.
  Widget _buildConnectedContextBar({
    required RoutineView view,
    required bool isWide,
  }) {
    final totalWeek = _controller.entries.length;
    final dayCount = _controller.entriesForSelectedDay.length;
    final slotCounterText =
        '$totalWeek ${totalWeek == 1 ? "class" : "classes"} this week · $dayCount on ${_controller.selectedDay}';

    final lensAndBadge = Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: AppColors.bgSubtle,
            borderRadius: AppSpacing.radiusSm,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _controller.isTeacherView
                    ? PhosphorIconsRegular.chalkboardTeacher
                    : PhosphorIconsRegular.graduationCap,
                size: 14,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  _controller.activeLensLabel,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: AppColors.infoSoft,
            borderRadius: AppSpacing.radiusFull,
            border: Border.all(color: AppColors.info.withValues(alpha: 0.35)),
          ),
          child: Text(
            slotCounterText,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.info,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );

    final segmented = SizedBox(
      width: isWide ? 280 : double.infinity,
      child: USegmentedControl<RoutineView>(
        compact: isWide,
        segments: const [
          USegment(value: RoutineView.weeklyMatrix, label: 'Weekly Matrix'),
          USegment(value: RoutineView.dayList, label: 'Day List'),
        ],
        selected: view,
        onChanged: (selection) => setState(() => _selectedView = selection),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.md,
        AppSpacing.screenH,
        AppSpacing.xs,
      ),
      child: isWide
          ? Row(
              children: [
                Expanded(child: lensAndBadge),
                const SizedBox(width: AppSpacing.md),
                segmented,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                lensAndBadge,
                const SizedBox(height: AppSpacing.sm),
                segmented,
              ],
            ),
    );
  }

  Widget _buildDayListBody() {
    if (_controller.isLoading && !_controller.hasLoaded) {
      return ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        itemCount: 4,
        separatorBuilder: (_, __) => AppSpacing.cardGap,
        itemBuilder: (_, __) => const ULoading.skeleton(skeletonHeight: 110),
      );
    }

    if (_controller.errorMessage != null && _controller.entries.isEmpty) {
      return UEmptyState.error(
        title: 'Could not load routine',
        message: _controller.errorMessage!,
        onRetry: _controller.load,
      );
    }

    final entries = _controller.entriesForSelectedDay;
    final now = _controller.now;
    final isToday = _controller.isSelectedDayToday;
    final isTeacher = _controller.isTeacherView;

    // PHASE 4: Swipeable Day Agenda on Mobile/Day List synced with DaySelector and selectionHaptic.
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() < 200) return;
        final stepped = _controller.stepDay(velocity < 0 ? 1 : -1);
        if (stepped) {
          AppMotion.selectionHaptic(context);
        }
      },
      child: UAnimatedSwap(
        child: KeyedSubtree(
          key: ValueKey<String>('day-agenda:${_controller.selectedDay}'),
          child: entries.isEmpty
              ? const UEmptyState(
                  icon: PhosphorIconsRegular.calendarBlank,
                  title: 'No classes',
                  message: 'Nothing scheduled for this day. Enjoy the break!',
                )
              : ListView(
                  padding: AppSpacing.screenPaddingScrollable,
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: _buildAgendaItemsWithBreakDividers(
                    entries,
                    now: now,
                    isToday: isToday,
                    isTeacher: isTeacher,
                  ),
                ),
        ),
      ),
    );
  }

  List<Widget> _buildAgendaItemsWithBreakDividers(
    List<RoutineEntry> entries, {
    required DateTime now,
    required bool isToday,
    required bool isTeacher,
  }) {
    final children = <Widget>[];
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      if (i > 0) {
        children.add(
          RoutineBreakDivider.buildGapOrJummahDivider(
            day: _controller.selectedDay,
            prev: entries[i - 1],
            next: e,
            now: now,
          ),
        );
      }
      final status = _controller.statusForEntry(e, isToday: isToday);
      children.add(
        UStaggeredListRow(
          index: i,
          child: ClassCard(
            subject: e.subject,
            subjectCode: e.subjectCode,
            teacher: e.teacherDisplay,
            room: e.room,
            timeSlot: e.timeLabel,
            status: status,
            batch: isTeacher || e.section.contains('+') ? e.batch : null,
            section: isTeacher || e.section.contains('+') ? e.section : null,
            hideDefaultCohortPill: !isTeacher,
            onTap: () => showRoutineEntryDetailOverlay(
              context: context,
              entry: e,
              status: status,
              isCancelledToday: isToday && _controller.isCancelledToday(e),
            ),
          ),
        ),
      );
    }
    return children;
  }

  // PHASE 1 RECONCILE & PHASE 4: Matrix presentation never re-queries or broadens B+C/co-teacher matches.
  Widget _buildWeeklyMatrix() {
    if (_controller.isLoading && !_controller.hasLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_controller.errorMessage != null && _controller.entries.isEmpty) {
      return UEmptyState.error(
        title: 'Could not load routine',
        message: _controller.errorMessage!,
        onRetry: _controller.load,
      );
    }

    return WeeklyScheduleView.matrix(
      entries: _controller.entries,
      isTeacherView: _controller.isTeacherView,
      cancelledEntryIdsToday: _controller.cancelledEntryIdsToday,
      clock: () => _controller.now,
    );
  }
}
