import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/models/profile_model.dart';
import 'package:universe/core/models/routine_model.dart';
import 'package:universe/core/router/route_names.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/core/utils/date_utils.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/features/notifications/controllers/notification_controller.dart';
import 'package:universe/features/teacher/controllers/teacher_dashboard_controller.dart';
import 'package:universe/shared/widgets/class_card.dart';
import 'package:universe/shared/widgets/live_class_card.dart';
import 'package:universe/shared/widgets/message_hero_card.dart';
import 'package:universe/shared/widgets/next_class_card.dart';
import 'package:universe/shared/widgets/notification_tile.dart';
import 'package:universe/shared/widgets/scrollable_empty.dart';
import 'package:universe/shared/widgets/u_animated_swap.dart';
import 'package:universe/shared/widgets/u_app_bar.dart';
import 'package:universe/shared/widgets/u_card.dart';
import 'package:universe/shared/widgets/u_empty_state.dart';
import 'package:universe/shared/widgets/u_loading.dart';
import 'package:universe/shared/widgets/u_section_header.dart';
import 'package:universe/shared/widgets/u_staggered_list_row.dart';
import 'package:universe/shared/widgets/u_weekly_load_bar_card.dart';

// PHASE 4: Teaching-first Faculty Command Center (62/38 desktop split >=860px, bounded medium 600..859px,
// single-axis mobile <600px) with Teacher Code badge and inline Manage Occurrence actions.
class TeacherDashboardScreen extends StatefulWidget {
  final AuthController authController;
  final NotificationController notificationController;
  final TeacherDashboardController? controller;
  final Future<List<RoutineEntry>> Function(String teacherCode)? routineLoader;
  final DateTime Function()? clock;

  const TeacherDashboardScreen({
    super.key,
    required this.authController,
    required this.notificationController,
    this.controller,
    this.routineLoader,
    this.clock,
  });

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  late final TeacherDashboardController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        TeacherDashboardController(
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

  String _cohort(RoutineEntry e) => 'Batch ${e.batch} · Sec ${e.section}';

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
        final firstName = (me?.displayName ?? 'Teacher').split(' ').first;
        final subtitle = [me?.designation, me?.department]
            .where((s) => s != null && s.trim().isNotEmpty)
            .join(' · ');

        return Scaffold(
          backgroundColor: AppColors.bgPrimary,
          appBar: UAppBar(
            title: '${AppDateUtils.greeting()}, $firstName',
            subtitle:
                subtitle.isEmpty ? (me?.roleLabel ?? 'Teacher') : subtitle,
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
          title: 'Could not load teaching schedule',
          message: _controller.errorMessage!,
          onRetry: _controller.load,
        ),
      );
    }

    // PHASE 4: Measure usable content width via LayoutBuilder after deducting sidebar/rail.
    return LayoutBuilder(
      builder: (context, constraints) {
        final usableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;

        if (usableWidth >= 860) {
          return _buildExpandedDesktopCommandCenter();
        }
        if (usableWidth >= 600) {
          return _buildMediumWorkspace();
        }
        return _buildCompactMobileAgenda();
      },
    );
  }

  // PHASE 4: Expanded Desktop (>=860px) -> 2-Column Teaching Command Center (62% / 38%).
  Widget _buildExpandedDesktopCommandCenter() {
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
                _buildFacultyHeaderStrip(),
                AppSpacing.mdGap,
                _buildAnimatedHero(),
                AppSpacing.sectionGap,
                _buildTeachingTimelineSection(),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xxl),
          Expanded(
            flex: 38,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTeachingLoadStrip(),
                AppSpacing.sectionGap,
                USectionHeader(
                  title: 'Recent Departmental Alerts',
                  onSeeAll: () => context.go(RouteNames.notifications),
                ),
                AppSpacing.smGap,
                _buildRecentAlerts(wrapInContainer: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // PHASE 4: Medium (600px <= usableWidth < 860px) -> Centered bounded teaching workspace.
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
              _buildFacultyHeaderStrip(),
              AppSpacing.mdGap,
              _buildTeachingLoadStrip(),
              AppSpacing.mdGap,
              _buildAnimatedHero(),
              AppSpacing.sectionGap,
              _buildTeachingTimelineSection(),
              AppSpacing.sectionGap,
              USectionHeader(
                title: 'Recent Departmental Alerts',
                onSeeAll: () => context.go(RouteNames.notifications),
              ),
              AppSpacing.smGap,
              _buildRecentAlerts(wrapInContainer: true),
            ],
          ),
        ),
      ),
    );
  }

  // PHASE 4: Compact Mobile (<600px) -> Single-axis vertical teaching agenda with thumb-friendly Manage pills.
  Widget _buildCompactMobileAgenda() {
    return ListView(
      padding: AppSpacing.screenPaddingScrollable,
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _buildFacultyHeaderStrip(),
        AppSpacing.smGap,
        _buildAnimatedHero(),
        AppSpacing.mdGap,
        _buildTeachingLoadStrip(),
        AppSpacing.sectionGap,
        _buildTeachingTimelineSection(),
        AppSpacing.sectionGap,
        USectionHeader(
          title: 'Recent Departmental Alerts',
          onSeeAll: () => context.go(RouteNames.notifications),
        ),
        AppSpacing.smGap,
        _buildRecentAlerts(wrapInContainer: false),
      ],
    );
  }

  // PHASE 4: Prominent Teacher Code badge + department strip showing the routine matching key.
  Widget _buildFacultyHeaderStrip() {
    final me = _me;
    final dept = (me?.department?.trim().isNotEmpty ?? false)
        ? me!.department!.trim()
        : 'Department of CSE';
    final desig = (me?.designation?.trim().isNotEmpty ?? false)
        ? '${me!.designation!.trim()} · '
        : '';

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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.infoSoft,
                  borderRadius: AppSpacing.radiusSm,
                  border: Border.all(
                    color: AppColors.info.withValues(alpha: 0.45),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      PhosphorIconsRegular.chalkboardTeacher,
                      size: 14,
                      color: AppColors.info,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Teacher Code: ${_controller.teacherCodeBadge}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.info,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  '$desig$dept',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text(
            'TODAY · ${AppDateUtils.shortDate(_controller.now)}',
            style: AppTextStyles.labelCaps,
          ),
        ],
      ),
    );
  }

  // PHASE 4 / C: High-craft 7-Day Weekly Load Mini-Bar Card replacing generic 3-box KPI slop.
  Widget _buildTeachingLoadStrip() {
    final todayShort =
        AppConstants.weekDaysShort[_controller.now.weekday % 7];
    return UWeeklyLoadBarCard(
      title: 'Weekly Teaching Load',
      dailyCounts: _controller.classesCountPerDay,
      todayShort: todayShort,
      onTap: () => context.go(RouteNames.teacherRoutine),
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
        teacher: _cohort(live),
        room: live.room,
        cohortPill: '${live.subjectCode} · ${_cohort(live)}',
        startTime: live.startOn(now),
        endTime: live.endOn(now),
        clock: () => _controller.now,
      );
    }

    final next = _controller.nextClass;
    if (next != null) {
      return NextClassCard(
        subject: next.subject,
        subtitle: _cohort(next),
        room: next.room,
        cohortPill: '${next.subjectCode} · ${_cohort(next)}',
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
            ? 'Tomorrow starts at ${upcoming.entry.startLabel} · ${upcoming.entry.subject} (${_cohort(upcoming.entry)}, Rm ${upcoming.entry.room})'
            : 'Next session on ${upcoming.dayName} starts at ${upcoming.entry.startLabel} · ${upcoming.entry.subject} (${_cohort(upcoming.entry)}, Rm ${upcoming.entry.room})')
        : null;
    final tomorrowPreview = upcomingPreview;

    if (!_controller.isClassDayToday) {
      return MessageHeroCard(
        icon: PhosphorIconsRegular.coffee,
        badge: 'FACULTY OFF-DAY',
        title: 'No classes today',
        message: upcoming != null
            ? "No teaching sessions scheduled today. Next class is on ${upcoming.dayName}."
            : "It's an off-day — enjoy the break!",
        accent: AppColors.info,
        secondaryText: upcomingPreview,
      );
    }
    if (_controller.todaysClasses.isNotEmpty) {
      return MessageHeroCard(
        icon: PhosphorIconsRegular.checkCircle,
        badge: 'SESSIONS COMPLETED',
        title: "Teaching's done for today",
        message: 'All your scheduled teaching sessions for today are complete.',
        accent: AppColors.success,
        secondaryText: tomorrowPreview,
      );
    }
    return MessageHeroCard(
      icon: PhosphorIconsRegular.calendarBlank,
      badge: 'NO SESSIONS TODAY',
      title: 'No classes to teach today',
      message: 'Nothing on your teaching schedule today.',
      accent: AppColors.info,
      secondaryText: tomorrowPreview,
    );
  }

  Widget _buildTeachingTimelineSection() {
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
            Text("Today's Teaching Timeline", style: AppTextStyles.h3),
            TextButton.icon(
              onPressed: () => context.go(RouteNames.teacherRoutine),
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
                'Full Teaching Matrix ->',
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
                  PhosphorIconsRegular.chalkboardTeacher,
                  color: AppColors.textMuted,
                  size: AppSpacing.iconMd,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'No teaching sessions scheduled for ${_controller.todayFullName}. Use Manage Classes to post updates for upcoming days.',
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
              child: _buildTeacherClassCard(todays[i]),
            ),
          ],
      ],
    );
  }

  Widget _buildTeacherClassCard(RoutineEntry e) {
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
      onTap: () => context.go(RouteNames.manageClasses),
      trailingAction: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: AppSpacing.radiusSm,
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.45),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              PhosphorIconsRegular.slidersHorizontal,
              size: 13,
              color: AppColors.primary,
            ),
            const SizedBox(width: 4),
            Text(
              'Manage Occurrence',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
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
                'No alerts yet. Departmental notices will show up here.',
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
