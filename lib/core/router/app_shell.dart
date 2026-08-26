import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/features/notifications/controllers/notification_controller.dart';
import 'package:universe/core/router/route_names.dart';
import 'package:universe/shared/widgets/app_bottom_nav.dart';
import 'package:universe/shared/widgets/app_drawer.dart';
import 'package:universe/shared/widgets/explore_fab_menu.dart';

class AppShell extends StatefulWidget {
  final AuthController authController;
  final NotificationController notificationController;
  final Widget child;

  const AppShell({
    super.key,
    required this.authController,
    required this.notificationController,
    required this.child,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = widget.authController.profile?['id'] as String?;
    widget.notificationController.load();
    widget.notificationController.startRealtime();
    widget.authController.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    widget.authController.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    final id = widget.authController.profile?['id'] as String?;
    if (id != _userId) {
      _userId = id;
      if (id != null) widget.notificationController.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.authController,
        widget.notificationController,
      ]),
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.bgPrimary,
          body: widget.child,
          floatingActionButton: _isDashboard(location)
              ? const _ExploreFab()
              : null,
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          bottomNavigationBar: AppBottomNav(
            role: widget.authController.role,
            currentRoute: location,
            unreadNotifCount: widget.notificationController.unreadCount,
          ),
        );
      },
    );
  }

  /// The Explore FAB only belongs on the three role dashboards.
  bool _isDashboard(String location) =>
      location == RouteNames.studentDashboard ||
      location == RouteNames.teacherDashboard ||
      location == RouteNames.adminDashboard;
}

/// The Explore FAB, folded away while the drawer is open.
///
/// The drawer slides in over this corner, so leaving the FAB up would float
/// it on top of the menu. `drawerOpenNotifier` is set by each dashboard's
/// `onEndDrawerChanged`; the scale animation makes it drop out and pop back
/// rather than blink.
class _ExploreFab extends StatelessWidget {
  const _ExploreFab();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: drawerOpenNotifier,
      builder: (context, isDrawerOpen, child) => AnimatedScale(
        scale: isDrawerOpen ? 0 : 1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        child: AnimatedOpacity(
          opacity: isDrawerOpen ? 0 : 1,
          duration: const Duration(milliseconds: 140),
          child: child,
        ),
      ),
      child: const ExploreFabMenu(),
    );
  }
}
