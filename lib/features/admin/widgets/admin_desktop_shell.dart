import 'package:universe/shared/widgets/u_avatar.dart';
// PHASE 1: Admin shell owns account chrome; embedded pages use compact action strips.
import 'package:universe/shared/widgets/desktop_shell_scope.dart';
import 'package:flutter/material.dart';
import 'package:universe/features/admin/services/engine_connectivity_service.dart';
import 'package:go_router/go_router.dart';
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/models/profile_model.dart';
import 'package:universe/core/router/route_names.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/features/notifications/controllers/notification_controller.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';

class AdminDesktopShell extends StatefulWidget {
  final AuthController authController;
  final NotificationController notificationController;
  final String currentLocation;
  final Widget child;
  final EngineConnectivityService? connectivityService;
  final bool compactNavigation;

  const AdminDesktopShell({
    super.key,
    required this.authController,
    required this.notificationController,
    required this.currentLocation,
    required this.child,
    this.connectivityService,
    this.compactNavigation = false,
  });

  @override
  State<AdminDesktopShell> createState() => _AdminDesktopShellState();
}

class _AdminDesktopShellState extends State<AdminDesktopShell> {
  late final EngineConnectivityService _connectivity;
  EngineConnectivity _health = EngineConnectivity.checking;

  @override
  void initState() {
    super.initState();
    _connectivity = widget.connectivityService ?? EngineConnectivityService();
    _checkHealth();
  }

  Future<void> _checkHealth() async {
    setState(() => _health = EngineConnectivity.checking);
    final result = await _connectivity.check();
    if (mounted) setState(() => _health = result);
  }

  @override
  void dispose() {
    if (widget.connectivityService == null) _connectivity.dispose();
    super.dispose();
  }

  Uri get _uri => Uri.parse(widget.currentLocation);
  bool _tabActive(String tab) =>
      _uri.path == RouteNames.routineManagement &&
      // PHASE 1: Match the routine screen's Manage default, including unknown tabs.
      RouteNames.routineTab(_uri) == tab;

  Profile? get _me {
    final map = widget.authController.profile;
    return map == null ? null : Profile.fromMap(map);
  }

  String _pageTitleFor(String location) {
    if (location.startsWith(RouteNames.adminDashboard)) {
      return 'Admin Dashboard';
    }
    if (location.startsWith(RouteNames.routineManagement)) {
      // PHASE 1 RECONCILE: This remains the live operational workflow.
      return 'Routine Operations';
    }
    if (location.startsWith(RouteNames.schedulingWorkspace)) {
      // PHASE 1 RECONCILE: The preview label is persistent, not a mode implied by styling.
      return 'Scheduling Workbench · Preview';
    }
    if (location.startsWith(RouteNames.manageFaculty)) {
      return 'Faculty Management';
    }
    if (location.startsWith(RouteNames.manageRooms)) {
      return 'Room Management';
    }
    if (location.startsWith(RouteNames.timetableSettings)) {
      return 'Timetable Settings';
    }
    if (location.startsWith(RouteNames.manageCourseEligibility)) {
      return 'Course Eligibility';
    }
    if (location.startsWith(RouteNames.timetableGrid)) {
      return 'Timetable Grid Preview';
    }
    if (location.startsWith(RouteNames.manageUsers)) {
      return 'User Management';
    }
    if (location.startsWith(RouteNames.campusBroadcast)) {
      return 'Campus Broadcast';
    }
    if (location.startsWith(RouteNames.broadcastHistory)) {
      return 'Broadcast History';
    }
    if (location.startsWith(RouteNames.manageResources)) {
      return 'Resource Management';
    }
    if (location.startsWith(RouteNames.resourceLibrary)) {
      return 'Resource Library';
    }
    if (location.startsWith(RouteNames.adminRegistration)) {
      return 'Admin Registration';
    }
    if (location.startsWith(RouteNames.profile)) {
      return 'Administrator Profile';
    }
    return 'Administration';
  }

  void _confirmSignOut(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: Text('Sign Out', style: AppTextStyles.h4),
        content: Text(
          'Are you sure you want to sign out of the administrative console?',
          style: AppTextStyles.bodySm,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: AppTextStyles.bodySm),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.textPrimary,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.authController.signOut();
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _pageTitleFor(widget.currentLocation);
    final me = _me;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Row(
        children: [
          // Persistent Sidebar
          _buildSidebar(context, me),
          // Content Area + Top Administrative Header
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context, title, me),
                Expanded(
                  child: Container(
                    color: AppColors.bgPrimary,
                    // PHASE 1: Embedded UAppBars suppress duplicate desktop chrome.
                    child: DesktopShellScope(
                        isDesktop: true,
                        tier: widget.compactNavigation
                            ? ShellLayoutTier.medium
                            : ShellLayoutTier.expanded,
                        child: widget.child),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, Profile? me) {
    return Container(
      // PHASE 1 RECONCILE: Admin medium widths reserve 220px, leaving the remainder for workspace content.
      width: widget.compactNavigation ? 220 : 250,
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        border: Border(
          right: BorderSide(
            color: AppColors.border,
            width: AppSpacing.borderThin,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Logo & Branding
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: AppSpacing.radiusMd,
                  ),
                  child: const Icon(
                    PhosphorIconsRegular.sparkle,
                    color: AppColors.primary,
                    size: AppSpacing.iconMd,
                  ),
                ),
                AppSpacing.smHGap,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppConstants.appName,
                        style: AppTextStyles.h4.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: AppSpacing.radiusSm,
                        ),
                        child: Text(
                          'ADMIN PORTAL',
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.border, height: 1),
          // Nav items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.sm,
                horizontal: AppSpacing.sm,
              ),
              children: [
                _sectionLabel('TIMETABLE ENGINE'),
                _navItem(
                  icon: PhosphorIconsRegular.house,
                  label: 'Dashboard',
                  route: RouteNames.adminDashboard,
                ),
                _navItem(
                  icon: PhosphorIconsRegular.calendarCheck,
                  // PHASE 1: The live generator/uploader is distinct from the preview workbench.
                  label: 'Routine Operations',
                  route: RouteNames.routineManagement,
                ),
                _navItem(
                  icon: PhosphorIconsRegular.stack,
                  // PHASE 1: Do not imply the revision-bound workbench is operational.
                  label: 'Scheduling Workbench · Preview',
                  route: RouteNames.schedulingWorkspace,
                ),
                _subNavItem(
                  label: '• Generate Timetable',
                  route: '${RouteNames.routineManagement}?tab=generate',
                  isActive: _tabActive('generate'),
                ),
                _subNavItem(
                  label: '• Upload Routine',
                  route: '${RouteNames.routineManagement}?tab=upload',
                  isActive: _tabActive('upload'),
                ),
                _navItem(
                  icon: PhosphorIconsRegular.gridFour,
                  label: 'Routine Preview',
                  route: RouteNames.timetableGrid,
                ),
                AppSpacing.smGap,
                _sectionLabel('CONFIGURATION'),
                _navItem(
                  icon: PhosphorIconsRegular.usersThree,
                  label: 'Faculty & Day-offs',
                  route: RouteNames.manageFaculty,
                ),
                _navItem(
                  icon: PhosphorIconsRegular.door,
                  label: 'Room Pools',
                  route: RouteNames.manageRooms,
                ),
                _navItem(
                  icon: PhosphorIconsRegular.gear,
                  label: 'Timetable Settings',
                  route: RouteNames.timetableSettings,
                ),
                _navItem(
                  icon: PhosphorIconsRegular.chalkboardTeacher,
                  label: 'Course Eligibility',
                  route: RouteNames.manageCourseEligibility,
                ),
                AppSpacing.smGap,
                _sectionLabel('COMMUNICATION & USERS'),
                _navItem(
                  icon: PhosphorIconsRegular.bellRinging,
                  label: 'Campus Broadcast',
                  route: RouteNames.campusBroadcast,
                ),
                _navItem(
                  icon: PhosphorIconsRegular.users,
                  label: 'User Whitelist',
                  route: RouteNames.manageUsers,
                ),
                _navItem(
                  icon: PhosphorIconsRegular.folderOpen,
                  label: 'Academic Resources',
                  route: RouteNames.manageResources,
                ),
                _navItem(
                  icon: PhosphorIconsRegular.user,
                  label: 'Admin Profile',
                  route: RouteNames.profile,
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.border, height: 1),
          // User card and sign out
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            color: AppColors.bgElevated,
            child: Row(
              children: [
                UAvatar(
                    name: me?.displayName ?? 'Administrator',
                    imageUrl: me?.avatarUrl,
                    size: 36),
                AppSpacing.smHGap,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        me?.displayName ?? 'Administrator',
                        style: AppTextStyles.bodySmMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        me?.email ?? 'admin@universe',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Sign Out',
                  icon: const Icon(
                    PhosphorIconsRegular.signOut,
                    size: AppSpacing.iconSm,
                    color: AppColors.textMuted,
                  ),
                  onPressed: () => _confirmSignOut(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Text(
        text,
        style: AppTextStyles.labelCaps.copyWith(
          color: AppColors.textMuted,
          fontSize: 10,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required String label,
    required String route,
  }) {
    // PHASE 1: Manage is selected only for its exact query/default, not every routine tab.
    final active = route == RouteNames.routineManagement
        ? _tabActive('manage')
        : _uri.path == route || _uri.path.startsWith('$route/');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      // PHASE 1: Selection is semantic as well as visual.
      child: Semantics(
          key: ValueKey('admin-nav:$route'),
          selected: active,
          child: Material(
            color: active ? AppColors.primarySoft : Colors.transparent,
            borderRadius: AppSpacing.radiusMd,
            child: InkWell(
              borderRadius: AppSpacing.radiusMd,
              onTap: () {
                if (widget.currentLocation == route) return;
                context.go(route);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      size: AppSpacing.iconSm,
                      color:
                          active ? AppColors.primary : AppColors.textSecondary,
                    ),
                    AppSpacing.smHGap,
                    Expanded(
                      child: Text(
                        label,
                        style: AppTextStyles.bodySmMedium.copyWith(
                          color: active
                              ? AppColors.primary
                              : AppColors.textPrimary,
                          fontWeight:
                              active ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )),
    );
  }

  Widget _subNavItem({
    required String label,
    required String route,
    required bool isActive,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.lg, top: 1, bottom: 1),
      // PHASE 1: Query-tab links expose their own exact selected state.
      child: Semantics(
          key: ValueKey('admin-nav:$route'),
          selected: isActive,
          child: Material(
            color: isActive ? AppColors.primarySoft : Colors.transparent,
            borderRadius: AppSpacing.radiusSm,
            child: InkWell(
              borderRadius: AppSpacing.radiusSm,
              onTap: () => context.go(route),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 6,
                ),
                child: Text(
                  label,
                  style: AppTextStyles.caption.copyWith(
                    color:
                        isActive ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          )),
    );
  }

  Widget _buildHeader(BuildContext context, String title, Profile? me) {
    final label = switch (_health) {
      EngineConnectivity.checking => 'Checking engine...',
      EngineConnectivity.connected => 'Engine Connected',
      EngineConnectivity.unavailable => 'Engine Unavailable',
      EngineConnectivity.unknown => 'Engine Status Unknown',
    };
    final color = _health == EngineConnectivity.connected
        ? AppColors.success
        : AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      decoration: const BoxDecoration(
          color: AppColors.bgElevated,
          border: Border(bottom: BorderSide(color: AppColors.border))),
      child: LayoutBuilder(builder: (context, constraints) {
        final titleWidget = // PHASE 1: The shell heading is global; the embedded page owns its title.
            Text('Administrative console',
                style: AppTextStyles.h4,
                maxLines: 2,
                overflow: TextOverflow.ellipsis);
        final actions = Wrap(
            spacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // PHASE 1: Account remains reachable without a duplicate page avatar.
              ProfileAccountAction(
                  accountName: me?.displayName ?? 'Administrator',
                  imageUrl: me?.avatarUrl,
                  role: 'admin',
                  onSignOut: () => _confirmSignOut(context)),
              Tooltip(
                  message:
                      'HTTP health only; does not guarantee solver availability. Tap to check again.',
                  child: TextButton(
                      onPressed: _health == EngineConnectivity.checking
                          ? null
                          : _checkHealth,
                      child: Text(label,
                          style:
                              AppTextStyles.caption.copyWith(color: color)))),
              FilledButton.icon(
                  icon: const Icon(PhosphorIconsRegular.magicWand, size: 16),
                  label: const Text('Generate Routine'),
                  onPressed: () => context
                      .go('${RouteNames.routineManagement}?tab=generate')),
            ]);
        // PHASE 1 RECONCILE: Header composition follows post-sidebar usable width.
        if (constraints.maxWidth < 860 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.3) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleWidget,
                const SizedBox(height: AppSpacing.xs),
                actions
              ]);
        }
        return Row(children: [Expanded(child: titleWidget), actions]);
      }),
    );
  }
}
