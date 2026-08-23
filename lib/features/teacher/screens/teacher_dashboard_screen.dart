import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
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
import 'package:universe/shared/widgets/quick_action_card.dart';
import 'package:universe/shared/widgets/scrollable_empty.dart';
import 'package:universe/shared/widgets/stat_card.dart';
import 'package:universe/shared/widgets/u_app_bar.dart';
import 'package:universe/shared/widgets/u_local_avatar.dart';
import 'package:universe/shared/widgets/u_button.dart';
import 'package:universe/shared/widgets/u_card.dart';
import 'package:universe/shared/widgets/u_empty_state.dart';
import 'package:universe/shared/widgets/u_loading.dart';
import 'package:universe/shared/widgets/u_section_header.dart';

class TeacherDashboardScreen extends StatefulWidget {
  final AuthController authController;
  final NotificationController notificationController;

  const TeacherDashboardScreen({
    super.key,
    required this.authController,
    required this.notificationController,
  });

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  late final TeacherDashboardController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        TeacherDashboardController(authController: widget.authController);
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
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
    final me = _me;
    final firstName = (me?.displayName ?? 'Teacher').split(' ').first;
    final subtitle = [me?.designation, me?.department]
        .where((s) => s != null && s.trim().isNotEmpty)
        .join(' · ');

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: UAppBar(
        title: '${AppDateUtils.greeting()}, $firstName',
        subtitle: subtitle.isEmpty ? (me?.roleLabel ?? 'Teacher') : subtitle,
        showBackButton: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.screenH),
            child: Center(
              child: ULocalAvatar(
                userId: widget.authController.profile?['id'] as String?,
                name: me?.displayName ?? 'Teacher',
                imageUrl: me?.avatarUrl,
                size: AppSpacing.avatarSm,
                onTap: () => context.go(RouteNames.profile),
              ),
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          _controller,
          widget.notificationController,
        ]),
        builder: (context, _) {
          return RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.bgCard,
            onRefresh: _refresh,
            child: _buildBody(),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_controller.isLoading && !_controller.hasLoaded) {
      return _buildSkeleton();
    }

    if (_controller.errorMessage != null && _controller.weeklyCount == 0) {
      return ScrollableEmpty(
        child: UEmptyState(
          icon: PhosphorIconsRegular.warningCircle,
          title: 'Something went wrong',
          message: _controller.errorMessage,
          action: UButton(
            label: 'Retry',
            icon: PhosphorIconsRegular.arrowClockwise,
            variant: UButtonVariant.secondary,
            fullWidth: false,
            onPressed: _controller.load,
          ),
        ),
      );
    }

    final todays = _controller.todaysClasses;
    final today = DateTime.now();

    return ListView(
      padding: AppSpacing.screenPaddingScrollable,
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Text(
          'TODAY · ${AppDateUtils.shortDate()}',
          style: AppTextStyles.labelCaps,
        ),
        AppSpacing.smGap,
        _buildHero(),
        AppSpacing.sectionGap,

        Text('AT A GLANCE', style: AppTextStyles.labelCaps),
        AppSpacing.smGap,
        _buildStats(),

        if (todays.isNotEmpty) ...[
          AppSpacing.sectionGap,
          USectionHeader(
            title: "Today's Teaching",
            onSeeAll: () => context.go(RouteNames.teacherRoutine),
          ),
          AppSpacing.smGap,
          ..._withGaps(
            todays.map(
              (e) => ClassCard(
                subject: e.subject,
                teacher: e.teacherDisplay,
                room: e.room,
                timeSlot: e.timeLabel,
                status: e.statusOn(today, isToday: true),
                batch: e.batch,
                section: e.section,
              ),
            ),
          ),
        ],

        AppSpacing.sectionGap,
        Text('QUICK ACTIONS', style: AppTextStyles.labelCaps),
        AppSpacing.smGap,
        _buildQuickActions(),

        AppSpacing.sectionGap,
        USectionHeader(
          title: 'Recent Alerts',
          onSeeAll: () => context.go(RouteNames.notifications),
        ),
        AppSpacing.smGap,
        _buildRecentAlerts(),
      ],
    );
  }

  Widget _buildHero() {
    final live = _controller.liveClass;
    if (live != null) {
      return LiveClassCard(
        subject: live.subject,
        teacher: _cohort(live),
        room: live.room,
        endTime: live.endOn(DateTime.now()),
      );
    }

    final next = _controller.nextClass;
    if (next != null) {
      return NextClassCard(
        subject: next.subject,
        subtitle: _cohort(next),
        room: next.room,
        startTime: next.startOn(DateTime.now()),
        timeLabel: next.timeLabel,
      );
    }

    return _restHero();
  }

  Widget _restHero() {
    if (!_controller.isClassDayToday) {
      return const MessageHeroCard(
        icon: PhosphorIconsRegular.coffee,
        title: 'No classes today',
        message: "It's the weekend — enjoy the break!",
      );
    }
    if (_controller.todaysClasses.isNotEmpty) {
      return const MessageHeroCard(
        icon: PhosphorIconsRegular.checkCircle,
        title: "Teaching's done for today",
        message: 'All your classes are finished. Well done!',
      );
    }
    return const MessageHeroCard(
      icon: PhosphorIconsRegular.calendarBlank,
      title: 'No classes to teach today',
      message: 'Nothing on your schedule today.',
    );
  }

  Widget _buildStats() {
    final cards = <Widget>[
      StatCard(
        number: '${_controller.todayCount}',
        label: 'Classes Today',
        icon: PhosphorIconsRegular.chalkboardTeacher,
        color: AppColors.roleTeacher,
      ),
      StatCard(
        number: '${_controller.weeklyCount}',
        label: 'Weekly Classes',
        icon: PhosphorIconsRegular.calendarBlank,
        color: AppColors.info,
      ),
      StatCard(
        number: '${_controller.sectionsTaught}',
        label: 'Sections Taught',
        icon: PhosphorIconsRegular.usersThree,
        color: AppColors.success,
      ),
      StatCard(
        number: '${widget.notificationController.unreadCount}',
        label: 'Unread Alerts',
        icon: PhosphorIconsRegular.bell,
        color: AppColors.primary,
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: 1.7,
      children: cards,
    );
  }

  Widget _buildQuickActions() {
    final actions = <Widget>[
      QuickActionCard(
        label: 'My Routine',
        icon: PhosphorIconsRegular.calendarCheck,
        color: AppColors.info,
        onTap: () => context.go(RouteNames.teacherRoutine),
      ),
      QuickActionCard(
        label: 'Manage Classes',
        icon: PhosphorIconsRegular.slidersHorizontal,
        color: AppColors.roleTeacher,
        onTap: () => context.go(RouteNames.manageClasses),
      ),
      QuickActionCard(
        label: 'Alerts',
        icon: PhosphorIconsRegular.bell,
        color: AppColors.primary,
        showBadge: true,
        badgeCount: widget.notificationController.unreadCount,
        onTap: () => context.go(RouteNames.notifications),
      ),
      QuickActionCard(
        label: 'Profile',
        icon: PhosphorIconsRegular.userCircle,
        color: AppColors.success,
        onTap: () => context.go(RouteNames.profile),
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: 1.4,
      children: actions,
    );
  }

  Widget _buildRecentAlerts() {
    final items = widget.notificationController.items.take(3).toList();

    if (items.isEmpty) {
      return UCard(
        child: Row(
          children: [
            Icon(
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

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppSpacing.radiusLg,
        border: Border.all(
          color: AppColors.border,
          width: AppSpacing.borderThin,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final n in items)
            NotificationTile(
              title: n.title,
              body: n.body,
              type: n.type,
              time: n.time,
              isRead: n.isRead,
              onTap: () => context.go(RouteNames.notifications),
            ),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView(
      padding: AppSpacing.screenPaddingScrollable,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        const ULoading.skeleton(skeletonHeight: 14, skeletonWidth: 140),
        AppSpacing.smGap,
        const ULoading.skeleton(skeletonHeight: AppSpacing.heroCardHeight),
        AppSpacing.sectionGap,
        Row(
          children: const [
            Expanded(child: ULoading.skeleton(skeletonHeight: 84)),
            SizedBox(width: AppSpacing.md),
            Expanded(child: ULoading.skeleton(skeletonHeight: 84)),
          ],
        ),
        AppSpacing.mdGap,
        Row(
          children: const [
            Expanded(child: ULoading.skeleton(skeletonHeight: 84)),
            SizedBox(width: AppSpacing.md),
            Expanded(child: ULoading.skeleton(skeletonHeight: 84)),
          ],
        ),
        AppSpacing.sectionGap,
        const ULoading.skeleton(skeletonHeight: 110),
        AppSpacing.cardGap,
        const ULoading.skeleton(skeletonHeight: 110),
      ],
    );
  }

  List<Widget> _withGaps(Iterable<Widget> widgets) {
    final list = widgets.toList();
    final out = <Widget>[];
    for (var i = 0; i < list.length; i++) {
      out.add(list[i]);
      if (i != list.length - 1) out.add(AppSpacing.cardGap);
    }
    return out;
  }
}
