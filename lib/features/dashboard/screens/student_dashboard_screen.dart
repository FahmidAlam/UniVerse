import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/constants/app_enums.dart';
import 'package:universe/core/models/profile_model.dart';
import 'package:universe/core/models/routine_model.dart';
import 'package:universe/core/router/route_names.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/core/utils/date_utils.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/features/dashboard/controllers/student_dashboard_controller.dart';
import 'package:universe/features/notifications/controllers/notification_controller.dart';
import 'package:universe/shared/widgets/class_card.dart';
import 'package:universe/shared/widgets/live_class_card.dart';
import 'package:universe/shared/widgets/message_hero_card.dart';
import 'package:universe/shared/widgets/next_class_card.dart';
import 'package:universe/shared/widgets/notification_tile.dart';
import 'package:universe/shared/widgets/quick_action_card.dart';
import 'package:universe/shared/widgets/scrollable_empty.dart';
import 'package:universe/shared/widgets/u_animated_swap.dart';
import 'package:universe/shared/widgets/u_app_bar.dart';
import 'package:universe/shared/widgets/u_card.dart';
import 'package:universe/shared/widgets/u_empty_state.dart';
import 'package:universe/shared/widgets/u_loading.dart';
import 'package:universe/shared/widgets/u_section_header.dart';
import 'package:universe/shared/widgets/u_staggered_list_row.dart';
import 'package:universe/shared/widgets/u_weekly_load_bar_card.dart';

// PHASE 4: Adaptive Student Dashboard with 62/38 2-Column Desktop Academic Workspace (>=860px),
// Medium bounded workspace (600..859px), and Compact single-axis mobile companion (<600px).
class StudentDashboardScreen extends StatefulWidget {
  final AuthController authController;
  final NotificationController notificationController;
  final StudentDashboardController? controller;
  final Future<List<RoutineEntry>> Function(String batch, String section)?
      routineLoader;
  final DateTime Function()? clock;

  const StudentDashboardScreen({
    super.key,
    required this.authController,
    required this.notificationController,
    this.controller,
    this.routineLoader,
    this.clock,
  });

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  late final StudentDashboardController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        StudentDashboardController(
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

  Profile? get _me => _controller.me;

  Future<void> _refresh() async {
    await Future.wait([
      _controller.load(),
      widget.notificationController.load(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        _controller,
        widget.notificationController,
      ]),
      builder: (context, _) {
        final me = _me;
        final firstName = (me?.displayName ?? 'Student').split(' ').first;
        final subtitle = (me?.batch != null && me?.section != null)
            ? 'Batch ${me!.batch} · Section ${me.section}'
            : me?.roleLabel ?? 'Student';

        return Scaffold(
          backgroundColor: AppColors.bgPrimary,
          appBar: UAppBar(
            title: '${AppDateUtils.greeting()}, $firstName',
            subtitle: subtitle,
            showBackButton: false,
          ),
          body: RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.bgCard,
            onRefresh: _refresh,
            child: _buildBody(),
          ),
        );
      },
    );
  }

  Widget _buildBody() {
    if (_controller.isLoading && !_controller.hasLoaded) {
      return _buildSkeleton();
    }

    if (_controller.errorMessage != null && _controller.weeklyCount == 0) {
      return ScrollableEmpty(
        child: UEmptyState.error(
          title: 'Could not load your schedule',
          message: _controller.errorMessage!,
          onRetry: _controller.load,
        ),
      );
    }

    // PHASE 4: Measure post-rail/sidebar usable width via LayoutBuilder (never raw MediaQuery).
    return LayoutBuilder(
      builder: (context, constraints) {
        final usableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;

        if (usableWidth >= 860) {
          return _buildExpandedDesktopWorkspace();
        }
        if (usableWidth >= 600) {
          return _buildMediumWorkspace();
        }
        return _buildCompactMobileFlow();
      },
    );
  }

  // PHASE 4: Expanded Desktop (>=860px usable width) -> Asymmetric 62% / 38% 2-Column Academic Workspace.
  Widget _buildExpandedDesktopWorkspace() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      physics: const AlwaysScrollableScrollPhysics(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 62,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCohortHeaderStrip(),
                AppSpacing.mdGap,
                _buildAnimatedHero(),
                AppSpacing.sectionGap,
                _buildTimelineSection(showConnectors: true),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xxl),
          Expanded(
            flex: 38,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('TODAY AT A GLANCE', style: AppTextStyles.labelCaps),
                AppSpacing.smGap,
                _buildTelemetryStrip(),
                AppSpacing.sectionGap,
                USectionHeader(
                  title: 'Recent Cohort Alerts',
                  onSeeAll: () => context.go(RouteNames.notifications),
                ),
                AppSpacing.smGap,
                _buildRecentAlerts(wrapInContainer: true),
                AppSpacing.sectionGap,
                Text('CAMPUS QUICK LOOKUP', style: AppTextStyles.labelCaps),
                AppSpacing.smGap,
                _buildCampusQuickLookupCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // PHASE 4: Medium (600px <= usableWidth < 860px) -> Centered bounded workspace (maxWidth: 760px).
  Widget _buildMediumWorkspace() {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCohortHeaderStrip(),
              AppSpacing.mdGap,
              _buildTelemetryStrip(),
              AppSpacing.mdGap,
              _buildAnimatedHero(),
              AppSpacing.sectionGap,
              _buildTimelineSection(showConnectors: true),
              AppSpacing.sectionGap,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        USectionHeader(
                          title: 'Recent Cohort Alerts',
                          onSeeAll: () => context.go(RouteNames.notifications),
                        ),
                        AppSpacing.smGap,
                        _buildRecentAlerts(wrapInContainer: true),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'CAMPUS QUICK LOOKUP',
                          style: AppTextStyles.labelCaps,
                        ),
                        AppSpacing.smGap,
                        _buildCampusQuickLookupCard(),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // PHASE 4: Compact Mobile (<600px usable width) -> Single-axis vertical flow with zero double-nested cards.
  Widget _buildCompactMobileFlow() {
    return ListView(
      padding: AppSpacing.screenPaddingScrollable,
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _buildCohortHeaderStrip(),
        AppSpacing.smGap,
        _buildAnimatedHero(),
        AppSpacing.mdGap,
        _buildTelemetryStrip(),
        AppSpacing.sectionGap,
        _buildTimelineSection(showConnectors: false),
        AppSpacing.sectionGap,
        Text('CAMPUS QUICK LOOKUP', style: AppTextStyles.labelCaps),
        AppSpacing.smGap,
        _buildMobileQuickActions(),
        AppSpacing.sectionGap,
        USectionHeader(
          title: 'Recent Cohort Alerts',
          onSeeAll: () => context.go(RouteNames.notifications),
        ),
        AppSpacing.smGap,
        _buildRecentAlerts(wrapInContainer: false),
      ],
    );
  }

  Widget _buildCohortHeaderStrip() {
    final now = _controller.now;
    final joints = _controller.jointSections;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgSubtle,
        borderRadius: AppSpacing.radiusMd,
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                PhosphorIconsRegular.graduationCap,
                size: AppSpacing.iconSm,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  _controller.cohortHeaderLabel,
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (joints.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.infoSoft,
                borderRadius: AppSpacing.radiusSm,
                border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                'Joint ${joints.join(", ")}',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.info,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Text(
            'TODAY · ${AppDateUtils.shortDate(now)}',
            style: AppTextStyles.labelCaps,
          ),
        ],
      ),
    );
  }

  // PHASE 4 / C: High-craft 7-Day Weekly Load Mini-Bar Card replacing generic 3-box KPI slop.
  Widget _buildTelemetryStrip() {
    final todayShort =
        AppConstants.weekDaysShort[_controller.now.weekday % 7];
    return UWeeklyLoadBarCard(
      title: 'Weekly Schedule Load',
      dailyCounts: _controller.classesCountPerDay,
      todayShort: todayShort,
      onTap: () => context.go(RouteNames.studentRoutine),
    );
  }

  Widget _buildAnimatedHero() {
    return UAnimatedSwap(
      child: KeyedSubtree(
        key: ValueKey<String>(_heroStateKey()),
        child: _buildHero(),
      ),
    );
  }

  String _heroStateKey() {
    final live = _controller.liveClass;
    if (live != null) return 'live:${live.id}';
    final next = _controller.nextClass;
    if (next != null) return 'next:${next.id}';
    if (!_controller.isClassDayToday) return 'weekend';
    if (_controller.todaysClasses.isNotEmpty) return 'done';
    return 'empty';
  }

  Widget _buildHero() {
    final now = _controller.now;
    final live = _controller.liveClass;
    if (live != null) {
      return LiveClassCard(
        subject: live.subject,
        teacher: live.teacherDisplay,
        room: live.room,
        cohortPill: live.section.contains('+')
            ? 'Joint Sec ${live.section}'
            : 'Batch ${live.batch} · ${live.section}',
        startTime: live.startOn(now),
        endTime: live.endOn(now),
        clock: () => _controller.now,
      );
    }

    final next = _controller.nextClass;
    if (next != null) {
      return NextClassCard(
        subject: next.subject,
        subtitle: next.teacherDisplay,
        room: next.room,
        cohortPill: next.section.contains('+')
            ? 'Joint Sec ${next.section}'
            : 'Batch ${next.batch} · ${next.section}',
        startTime: next.startOn(now),
        timeLabel: next.timeLabel,
        clock: () => _controller.now,
      );
    }

    return _restHero();
  }

  Widget _restHero() {
    final upcoming = _controller.nextUpcomingClass;
    final upcomingPreview = upcoming != null
        ? (upcoming.daysAhead == 1
            ? 'Tomorrow starts at ${upcoming.entry.startLabel} · ${upcoming.entry.subject} (Rm ${upcoming.entry.room})'
            : 'Next class on ${upcoming.dayName} starts at ${upcoming.entry.startLabel} · ${upcoming.entry.subject} (Rm ${upcoming.entry.room})')
        : null;
    final tomorrowPreview = upcomingPreview;

    if (!_controller.isClassDayToday) {
      return MessageHeroCard(
        icon: PhosphorIconsRegular.coffee,
        badge: 'SECTION OFF-DAY',
        title: 'No classes today',
        message: upcoming != null
            ? "No classes scheduled today. Next class is on ${upcoming.dayName}."
            : "It's an off-day — enjoy the break!",
        accent: AppColors.info,
        secondaryText: upcomingPreview,
      );
    }
    if (_controller.todaysClasses.isNotEmpty) {
      final doneCount = _controller.completedTodayCount;
      final totalCount = _controller.todayCount;
      return MessageHeroCard(
        icon: PhosphorIconsRegular.checkCircle,
        badge: 'DONE FOR TODAY',
        title: "You're done for today",
        message:
            'Completed $doneCount of $totalCount scheduled ${totalCount == 1 ? "class" : "classes"} today.',
        accent: AppColors.success,
        secondaryText: tomorrowPreview,
      );
    }
    return MessageHeroCard(
      icon: PhosphorIconsRegular.calendarBlank,
      badge: 'FREE DAY',
      title: 'No classes scheduled',
      message: 'Nothing on your routine today.',
      accent: AppColors.info,
      secondaryText: tomorrowPreview,
    );
  }

  Widget _buildTimelineSection({required bool showConnectors}) {
    final todays = _controller.todaysClasses;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            Text("Today's Classes", style: AppTextStyles.h3),
            TextButton.icon(
              onPressed: () => context.go(RouteNames.studentRoutine),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(
                PhosphorIconsRegular.gridFour,
                size: AppSpacing.iconSm,
                color: AppColors.primary,
              ),
              label: Text(
                'View Full Weekly Matrix ->',
                style: AppTextStyles.bodySm.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        AppSpacing.smGap,
        if (todays.isEmpty)
          UCard(
            isTopLit: true,
            child: Row(
              children: [
                const Icon(
                  PhosphorIconsRegular.calendarBlank,
                  color: AppColors.textMuted,
                  size: AppSpacing.iconMd,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'No classes scheduled for ${_controller.todayFullName}. Open the Weekly Matrix to inspect upcoming days.',
                    style: AppTextStyles.bodySm,
                  ),
                ),
              ],
            ),
          )
        else
          for (var i = 0; i < todays.length; i++) ...[
            if (i > 0) AppSpacing.cardGap,
            UStaggeredListRow(
              index: i,
              child: showConnectors
                  ? _TimelineConnectorRow(
                      entry: todays[i],
                      status: _controller.statusForToday(todays[i]),
                      isLast: i == todays.length - 1,
                      child: _buildStudentClassCard(todays[i]),
                    )
                  : _buildStudentClassCard(todays[i]),
            ),
          ],
      ],
    );
  }

  Widget _buildStudentClassCard(RoutineEntry e) {
    final status = _controller.statusForToday(e);
    return ClassCard(
      subject: e.subject,
      subjectCode: e.subjectCode,
      teacher: e.teacherDisplay,
      room: e.room,
      timeSlot: e.timeLabel,
      status: status,
      batch: e.batch,
      section: e.section,
      hideDefaultCohortPill: true,
      onTap: () => context.go(RouteNames.studentRoutine),
    );
  }

  Widget _buildCampusQuickLookupCard() {
    return UCard(
      isTopLit: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _QuickLookupTile(
            icon: PhosphorIconsRegular.door,
            color: AppColors.success,
            title: 'Room Availability',
            subtitle: 'Schedule-derived free & occupied rooms',
            onTap: () => context.go(RouteNames.rooms),
          ),
          const Divider(height: AppSpacing.lg, color: AppColors.border),
          _QuickLookupTile(
            icon: PhosphorIconsRegular.chalkboardTeacher,
            color: AppColors.info,
            title: 'Find Teacher',
            subtitle: 'Check faculty teaching slots & rooms',
            onTap: () => context.go(RouteNames.findTeacher),
          ),
          const Divider(height: AppSpacing.lg, color: AppColors.border),
          _QuickLookupTile(
            icon: PhosphorIconsRegular.folderOpen,
            color: AppColors.primary,
            title: 'Semester Resources',
            subtitle: 'Course notes, slides & references',
            onTap: () => context.go(RouteNames.resources),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileQuickActions() {
    return Row(
      children: [
        Expanded(
          child: QuickActionCard(
            label: 'Room Availability',
            icon: PhosphorIconsRegular.door,
            color: AppColors.success,
            onTap: () => context.go(RouteNames.rooms),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: QuickActionCard(
            label: 'Find Teacher',
            icon: PhosphorIconsRegular.chalkboardTeacher,
            color: AppColors.info,
            onTap: () => context.go(RouteNames.findTeacher),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentAlerts({required bool wrapInContainer}) {
    final items = widget.notificationController.items.take(3).toList();

    if (items.isEmpty) {
      return UCard(
        isTopLit: true,
        child: Row(
          children: [
            const Icon(
              PhosphorIconsRegular.bellSlash,
              size: AppSpacing.iconMd,
              color: AppColors.textMuted,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'No alerts yet. Campus notices will show up here.',
                style: AppTextStyles.bodySm,
              ),
            ),
          ],
        ),
      );
    }

    final tiles = [
      for (final n in items)
        NotificationTile(
          title: n.title,
          body: n.body,
          type: n.type,
          time: n.time,
          isRead: n.isRead,
          onTap: () => context.go(RouteNames.notifications),
        ),
    ];

    if (!wrapInContainer) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: tiles,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppSpacing.radiusMd,
        border: Border.all(
          color: AppColors.border,
          width: AppSpacing.borderThin,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: tiles),
    );
  }

  Widget _buildSkeleton() {
    return ListView(
      padding: AppSpacing.screenPaddingScrollable,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        const ULoading.skeleton(skeletonHeight: 36),
        AppSpacing.smGap,
        const ULoading.skeleton(skeletonHeight: AppSpacing.heroCardHeight),
        AppSpacing.mdGap,
        const ULoading.skeleton(skeletonHeight: 134),
        AppSpacing.sectionGap,
        const ULoading.skeleton(skeletonHeight: 110),
        AppSpacing.cardGap,
        const ULoading.skeleton(skeletonHeight: 110),
      ],
    );
  }
}

class _TimelineConnectorRow extends StatelessWidget {
  final RoutineEntry entry;
  final ClassStatus status;
  final bool isLast;
  final Widget child;

  const _TimelineConnectorRow({
    required this.entry,
    required this.status,
    required this.isLast,
    required this.child,
  });

  Color get _dotColor {
    switch (status) {
      case ClassStatus.live:
        return AppColors.primary;
      case ClassStatus.next:
      case ClassStatus.upcoming:
        return AppColors.info;
      case ClassStatus.cancelled:
        return AppColors.error;
      case ClassStatus.done:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 68,
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.startLabel,
                  style: AppTextStyles.timeCode.copyWith(
                    color: status == ClassStatus.live
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _dotColor,
                        shape: BoxShape.circle,
                        boxShadow: status == ClassStatus.live
                            ? [
                                BoxShadow(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                ),
                              ]
                            : null,
                      ),
                    ),
                    if (!isLast) ...[
                      const SizedBox(width: 4),
                      Expanded(
                        child: Container(
                          height: 1,
                          color: AppColors.border,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: child),
      ],
    );
  }
}

class _QuickLookupTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickLookupTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppSpacing.radiusSm,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: AppSpacing.radiusSm,
                border: Border.all(color: color.withValues(alpha: 0.35)),
              ),
              child: Icon(icon, size: AppSpacing.iconMd, color: color),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(subtitle, style: AppTextStyles.caption),
                ],
              ),
            ),
            const Icon(
              PhosphorIconsRegular.caretRight,
              size: AppSpacing.iconSm,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
