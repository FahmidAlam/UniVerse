import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/models/profile_model.dart';
import 'package:universe/core/router/route_names.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/admin/controllers/admin_dashboard_controller.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/shared/widgets/desktop_shell_scope.dart';
import 'package:universe/shared/widgets/u_app_bar.dart';
import 'package:universe/shared/widgets/u_card.dart';

// PHASE 5: Executive Command Center with Mural-Style Readiness Checklist,
// Axis-Labeled Load Breakdown Chart, Dual-Track Scheduling Launchpad, and Dissolved Edge Alignment.
class AdminDashboardScreen extends StatefulWidget {
  final AuthController? authController;
  final AdminDashboardController? controller;

  const AdminDashboardScreen({
    super.key,
    this.authController,
    this.controller,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late final AdminDashboardController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? AdminDashboardController();
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

  Profile? get _me {
    final map = widget.authController?.profile;
    return map == null ? null : Profile.fromMap(map);
  }

  @override
  Widget build(BuildContext context) {
    final me = _me;
    // PHASE 5: Suppress duplicate inner UAppBar when rendered inside AdminDesktopShell.
    final isDesktopShell = DesktopShellScope.isDesktopOf(context);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: isDesktopShell
          ? null
          : UAppBar(
              title: me?.displayName ?? 'Admin',
              subtitle: 'Administrator · ${AppConstants.appName}',
              showBackButton: false,
            ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return LayoutBuilder(
            builder: (context, constraints) {
              // PHASE 5: Content-aware usable width post-sidebar.
              final usableWidth = constraints.maxWidth;
              final isExpandedDesktop = usableWidth >= 880;
              final isCompact = usableWidth < 600;

              return RefreshIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.bgCard,
                onRefresh: _controller.load,
                child: ListView(
                  padding: EdgeInsets.all(
                    isCompact ? AppSpacing.md : AppSpacing.xl,
                  ),
                  children: [
                    _buildTelemetryStrip(isCompact),
                    const SizedBox(height: AppSpacing.lg),
                    if (_controller.errorMessage != null) ...[
                      _buildErrorRecoveryCard(),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    if (isExpandedDesktop)
                      // PHASE 5: Asymmetric 60% / 40% 2-Column Command Center (24px gap).
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 60,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildReadinessChecklistCard(usableWidth),
                                const SizedBox(height: AppSpacing.xxl),
                                _buildLoadBreakdownCard(usableWidth),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xxl),
                          Expanded(
                            flex: 40,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildDualTrackLaunchpadCard(usableWidth),
                                const SizedBox(height: AppSpacing.xxl),
                                _buildQuickDirectoryCard(usableWidth),
                              ],
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildReadinessChecklistCard(usableWidth),
                          const SizedBox(height: AppSpacing.lg),
                          _buildDualTrackLaunchpadCard(usableWidth),
                          const SizedBox(height: AppSpacing.lg),
                          _buildLoadBreakdownCard(usableWidth),
                          const SizedBox(height: AppSpacing.lg),
                          _buildQuickDirectoryCard(usableWidth),
                        ],
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildErrorRecoveryCard() {
    return UCard(
      color: AppColors.warningSoft,
      border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      child: Row(
        children: [
          const Icon(
            PhosphorIconsRegular.warningCircle,
            color: AppColors.warning,
            size: 18,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              _controller.errorMessage!,
              style: AppTextStyles.bodySm.copyWith(color: AppColors.textPrimary),
            ),
          ),
          TextButton.icon(
            onPressed: _controller.load,
            icon: const Icon(PhosphorIconsRegular.arrowsClockwise, size: 14),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // PHASE 5: Compact 4-pill telemetry strip with tabular numerals.
  Widget _buildTelemetryStrip(bool isCompact) {
    final c = _controller.counts;
    String n(int v) => _controller.isLoading ? '—' : '$v';

    final pills = [
      _telemetryPill(
        label: 'Students',
        value: n(c.students),
        icon: PhosphorIconsRegular.graduationCap,
        accent: AppColors.roleStudent,
      ),
      _telemetryPill(
        label: 'Teachers',
        value: n(c.teachers),
        icon: PhosphorIconsRegular.chalkboardTeacher,
        accent: AppColors.roleTeacher,
      ),
      _telemetryPill(
        label: 'Routine Slots',
        value: n(c.routines),
        icon: PhosphorIconsRegular.calendarBlank,
        accent: AppColors.info,
      ),
      _telemetryPill(
        label: 'Broadcasts',
        value: n(c.broadcasts),
        icon: PhosphorIconsRegular.bell,
        accent: AppColors.primary,
      ),
    ];

    if (isCompact) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: pills[0]),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: pills[1]),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(child: pills[2]),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: pills[3]),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: pills[0]),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: pills[1]),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: pills[2]),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: pills[3]),
      ],
    );
  }

  Widget _telemetryPill({
    required String label,
    required String value,
    required IconData icon,
    required Color accent,
  }) {
    return UCard(
      isTopLit: true,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: AppSpacing.radiusSm,
            ),
            child: Icon(icon, size: 17, color: accent),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: AppTextStyles.numeric.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // PHASE 5: Mural-Style 4-Stage Routine Lifecycle Readiness Checklist with "Walmart receipt" edge alignment.
  Widget _buildReadinessChecklistCard(double usableWidth) {
    final c = _controller.counts;
    final roomsReady = c.rooms > 0;
    final facultyReady = c.teachers > 0;
    final eligibilityReady = c.courseEligibilities > 0;
    final routineReady = c.routines > 0;
    final completedStages = [
      roomsReady,
      facultyReady,
      eligibilityReady,
      routineReady,
    ].where((ok) => ok).length;

    return UCard(
      isTopLit: true,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
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
                      PhosphorIconsRegular.checkSquare,
                      color: AppColors.primary,
                      size: 18,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        'ROUTINE LIFECYCLE READINESS CHECKLIST',
                        style: AppTextStyles.labelCaps.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: completedStages == 4
                        ? AppColors.successSoft
                        : AppColors.bgElevated,
                    borderRadius: AppSpacing.radiusSm,
                    border: Border.all(
                      color: completedStages == 4
                          ? AppColors.success.withValues(alpha: 0.4)
                          : AppColors.border,
                    ),
                  ),
                  child: Text(
                    '$completedStages / 4 STAGES READY',
                    style: AppTextStyles.numeric.copyWith(
                      fontSize: 10,
                      color: completedStages == 4
                          ? AppColors.success
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.border, height: 1),
          _buildChecklistRow(
            stageNumber: '01',
            title: '01 · Room Pools',
            subtitle:
                'Configure lecture halls, specialized labs, and seat capacities.',
            countLabel: roomsReady ? '${c.rooms} Active' : 'Setup Required',
            isReady: roomsReady,
            actionLabel: 'Manage Rooms',
            onTap: () => context.go(RouteNames.manageRooms),
          ),
          const Divider(color: AppColors.border, height: 1),
          _buildChecklistRow(
            stageNumber: '02',
            title: '02 · Faculty & Off-Days',
            subtitle:
                'Verify teacher acronyms, weekly off-days, and department rosters.',
            countLabel:
                facultyReady ? '${c.teachers} Faculty' : 'Setup Required',
            isReady: facultyReady,
            actionLabel: 'Manage Faculty',
            onTap: () => context.go(RouteNames.manageFaculty),
          ),
          const Divider(color: AppColors.border, height: 1),
          _buildChecklistRow(
            stageNumber: '03',
            title: '03 · Course Eligibility & Time Grid',
            subtitle:
                'Bind teacher course eligibility priorities and daily period clocks.',
            countLabel: eligibilityReady
                ? '${c.courseEligibilities} Bound'
                : 'Default Grid',
            isReady: eligibilityReady,
            actionLabel: 'Course Eligibility',
            onTap: () => context.go(RouteNames.manageCourseEligibility),
            secondaryActionLabel: 'Timetable Settings',
            onSecondaryTap: () => context.go(RouteNames.timetableSettings),
          ),
          const Divider(color: AppColors.border, height: 1),
          _buildChecklistRow(
            stageNumber: '04',
            title: '04 · Active Routine & Engine',
            subtitle:
                'Run OR-Tools CP-SAT solver or publish verified routine workbooks.',
            countLabel:
                routineReady ? '${c.routines} Slots Live' : 'Unpublished',
            isReady: routineReady,
            actionLabel: 'Generate Timetable',
            onTap: () =>
                context.go('${RouteNames.routineManagement}?tab=generate'),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistRow({
    required String stageNumber,
    required String title,
    required String subtitle,
    required String countLabel,
    required bool isReady,
    required String actionLabel,
    required VoidCallback onTap,
    String? secondaryActionLabel,
    VoidCallback? onSecondaryTap,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 520;
        final statusPill = Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isReady ? AppColors.bgElevated : AppColors.warningSoft,
            borderRadius: AppSpacing.radiusSm,
            border: Border.all(
              color: isReady
                  ? AppColors.border
                  : AppColors.warning.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isReady
                    ? PhosphorIconsRegular.checkCircle
                    : PhosphorIconsRegular.warningCircle,
                size: 12,
                color: isReady ? AppColors.success : AppColors.warning,
              ),
              const SizedBox(width: 4),
              Text(
                countLabel,
                style: AppTextStyles.numeric.copyWith(
                  fontSize: 11,
                  color: isReady ? AppColors.textSecondary : AppColors.warning,
                ),
              ),
            ],
          ),
        );

        final actionButtons = Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            statusPill,
            if (secondaryActionLabel != null && onSecondaryTap != null)
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  minimumSize: const Size(40, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: onSecondaryTap,
                child: Text(
                  secondaryActionLabel,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor:
                    isReady ? AppColors.textPrimary : AppColors.primary,
                side: BorderSide(
                  color: isReady
                      ? AppColors.border
                      : AppColors.primary.withValues(alpha: 0.45),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                minimumSize: const Size(40, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: onTap,
              icon: const Icon(PhosphorIconsRegular.arrowRight, size: 12),
              label: Text(actionLabel, style: const TextStyle(fontSize: 11)),
            ),
          ],
        );

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    actionButtons,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    actionButtons,
                  ],
                ),
        );
      },
    );
  }

  // PHASE 5: Axis-Labeled Departmental Schedule & Resource Load Breakdown Card.
  Widget _buildLoadBreakdownCard(double usableWidth) {
    final c = _controller.counts;
    return UCard(
      isTopLit: true,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      PhosphorIconsRegular.chartBar,
                      color: AppColors.info,
                      size: 18,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'DEPARTMENTAL SCHEDULE & RESOURCE LOAD BREAKDOWN',
                        style: AppTextStyles.labelCaps.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Explicit capacity comparison against typical CSE semester benchmarks.',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.border, height: 1),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                _buildLoadBarRow(
                  label: 'Active Room Pools',
                  axisNote: 'Target: 12 halls & labs',
                  value: c.rooms,
                  benchmarkMax: 16,
                  color: AppColors.info,
                ),
                const SizedBox(height: AppSpacing.md),
                _buildLoadBarRow(
                  label: 'Registered Faculty',
                  axisNote: 'Target: 18 instructors',
                  value: c.teachers,
                  benchmarkMax: 24,
                  color: AppColors.roleTeacher,
                ),
                const SizedBox(height: AppSpacing.md),
                _buildLoadBarRow(
                  label: 'Active Routine Slots',
                  axisNote: 'Target: 120 weekly sessions',
                  value: c.routines,
                  benchmarkMax: 160,
                  color: AppColors.primary,
                ),
                const SizedBox(height: AppSpacing.md),
                _buildLoadBarRow(
                  label: 'Registered Portal Users',
                  axisNote: 'Students, faculty & admins',
                  value: c.totalUsers,
                  benchmarkMax: 400,
                  color: AppColors.success,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadBarRow({
    required String label,
    required String axisNote,
    required int value,
    required int benchmarkMax,
    required Color color,
  }) {
    final ratio =
        benchmarkMax <= 0 ? 0.0 : (value / benchmarkMax).clamp(0.04, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                label,
                style: AppTextStyles.bodySmMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '$value / $benchmarkMax cap',
              style: AppTextStyles.numeric.copyWith(
                fontSize: 12,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _controller.isLoading ? 0.0 : ratio,
            minHeight: 8,
            backgroundColor: AppColors.bgElevated,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                axisNote,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 10,
                  color: AppColors.textMuted,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${((value / (benchmarkMax <= 0 ? 1 : benchmarkMax)) * 100).clamp(0, 100).round()}%',
              style: AppTextStyles.numeric.copyWith(
                fontSize: 10,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // PHASE 5: Dual-Track Scheduling Launchpad contrasting Live Routine Operations vs Preview Workbench.
  Widget _buildDualTrackLaunchpadCard(double usableWidth) {
    return UCard(
      isTopLit: true,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                const Icon(
                  PhosphorIconsRegular.rocketLaunch,
                  color: AppColors.primary,
                  size: 18,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'DUAL-TRACK SCHEDULING LAUNCHPAD',
                    style: AppTextStyles.labelCaps.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.border, height: 1),
          // Track 1: Live Operational Pipeline
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.successSoft,
                        borderRadius: AppSpacing.radiusSm,
                        border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        'LIVE PIPELINE',
                        style: AppTextStyles.badge.copyWith(
                          color: AppColors.success,
                          fontSize: 9,
                        ),
                      ),
                    ),
                    Text(
                      'Routine Operations · Live Engine',
                      style: AppTextStyles.h4,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Execute the FastAPI + OR-Tools CP-SAT solver, import rendered .xlsx workbooks, or manage published class slots.',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      onPressed: () => context
                          .go('${RouteNames.routineManagement}?tab=generate'),
                      icon: const Icon(
                        PhosphorIconsRegular.magicWand,
                        size: 15,
                      ),
                      label: const Text(
                        'Open Live Generator',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      onPressed: () =>
                          context.go('${RouteNames.routineManagement}?tab=upload'),
                      icon: const Icon(
                        PhosphorIconsRegular.uploadSimple,
                        size: 14,
                      ),
                      label: const Text(
                        'Upload Routine',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      onPressed: () => context.go(RouteNames.routineManagement),
                      icon: const Icon(
                        PhosphorIconsRegular.calendarCheck,
                        size: 14,
                      ),
                      label: const Text(
                        'Routine Management',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.border, height: 1),
          // Track 2: Revision-Bound Preview Workbench
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
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
                        'DESIGN PREVIEW',
                        style: AppTextStyles.badge.copyWith(
                          color: AppColors.info,
                          fontSize: 9,
                        ),
                      ),
                    ),
                    Text(
                      'Scheduling Workbench · Preview',
                      style: AppTextStyles.h4,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Inspect 5-part A–L workbook provenance, R1–R15 policy snapshots, and preflight readiness checks.',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.info,
                    side: BorderSide(
                      color: AppColors.info.withValues(alpha: 0.45),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  onPressed: () => context.go(RouteNames.schedulingWorkspace),
                  icon: const Icon(PhosphorIconsRegular.stack, size: 15),
                  label: const Text(
                    'Scheduling Workspace',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // PHASE 5: Campus Operations Quick Directory with "Walmart receipt" 1px edge dividers.
  Widget _buildQuickDirectoryCard(double usableWidth) {
    final items = [
      (
        title: 'Campus Broadcast',
        subtitle: 'Send university or cohort announcements',
        icon: PhosphorIconsRegular.bellRinging,
        color: AppColors.primary,
        route: RouteNames.campusBroadcast,
      ),
      (
        title: 'User Whitelist',
        subtitle: 'Manage pre-authorized faculty and user roles',
        icon: PhosphorIconsRegular.users,
        color: AppColors.roleTeacher,
        route: RouteNames.manageUsers,
      ),
      (
        title: 'Admin Registration',
        subtitle: 'Provision new departmental administrators',
        icon: PhosphorIconsRegular.identificationBadge,
        color: AppColors.success,
        route: RouteNames.adminRegistration,
      ),
      (
        title: 'Academic Resources',
        subtitle: 'Curate course materials and syllabus links',
        icon: PhosphorIconsRegular.folderOpen,
        color: AppColors.info,
        route: RouteNames.manageResources,
      ),
    ];

    return UCard(
      isTopLit: true,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                const Icon(
                  PhosphorIconsRegular.globe,
                  color: AppColors.textSecondary,
                  size: 18,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'CAMPUS OPERATIONS QUICK DIRECTORY',
                    style: AppTextStyles.labelCaps.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < items.length; i++) ...[
            const Divider(color: AppColors.border, height: 1),
            InkWell(
              onTap: () => context.go(items[i].route),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: items[i].color.withValues(alpha: 0.14),
                        borderRadius: AppSpacing.radiusSm,
                      ),
                      child: Icon(
                        items[i].icon,
                        size: 16,
                        color: items[i].color,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            items[i].title,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            items[i].subtitle,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      PhosphorIconsRegular.caretRight,
                      size: 15,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
