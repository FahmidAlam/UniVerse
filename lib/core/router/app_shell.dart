import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/router/route_names.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/admin/widgets/admin_desktop_shell.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/features/notifications/controllers/notification_controller.dart';
import 'package:universe/shared/widgets/app_bottom_nav.dart';
import 'package:universe/shared/widgets/app_drawer.dart';
// PHASE 1: Desktop roles share shell chrome without changing mobile back semantics.
import 'package:universe/shared/widgets/desktop_shell_scope.dart';
import 'package:universe/shared/widgets/role_desktop_shell.dart';
import 'package:universe/shared/widgets/shell_back_scope.dart';

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
  /// How long the "press back again" offer stays open.
  static const Duration _exitWindow = Duration(seconds: 2);

  final ShellBackRegistry _backRegistry = ShellBackRegistry();

  String? _userId;
  String _location = '';
  String _home = '';
  DateTime? _lastBackPress;

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

  /// Tabs are entered with `go()`, which replaces the stack, so the shell never
  /// has anything to pop and a raw back press would quit the app. Resolve it
  /// the way Material specifies instead: unwind whatever is on top, then fall
  /// back to the role's start destination, then require a confirmed exit.
  void _onBackPressed() {
    // The drawer opens over everything else, so it unwinds first. It registers
    // a local history entry that would normally absorb the press on its own,
    // but our PopScope is consulted before that entry is, so close it by hand.
    if (drawerOpenNotifier.value) {
      Navigator.of(context).pop();
      return;
    }

    // Then any screen with internal state to shed (open folder, selection mode).
    if (_backRegistry.handleBack()) return;

    // PHASE 1: Pushed Campus details pop first; direct deep links recover to their directory.
    if (context.canPop()) {
      context.pop();
      return;
    }
    if (_location == RouteNames.roomDetail ||
        _location == RouteNames.teacherDetail) {
      context.go(_location == RouteNames.roomDetail
          ? RouteNames.rooms
          : RouteNames.findTeacher);
      return;
    }

    if (_location != _home) {
      context.go(_home);
      return;
    }

    final now = DateTime.now();
    if (_lastBackPress == null ||
        now.difference(_lastBackPress!) > _exitWindow) {
      _lastBackPress = now;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content:
                Text('Press back again to exit', style: AppTextStyles.bodySm),
            backgroundColor: AppColors.bgElevated,
            behavior: SnackBarBehavior.floating,
            duration: _exitWindow,
          ),
        );
      return;
    }

    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    try {
      _location = GoRouterState.of(context).matchedLocation;
    } catch (_) {
      _location = '';
    }
    final role = widget.authController.role;
    final destinations = AppBottomNav.destinationsFor(role);
    _home = destinations.isNotEmpty ? destinations.first.route : '';

    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.authController,
        widget.notificationController,
      ]),
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            // PHASE 1 RECONCILE: Navigation tier follows usable shell width, not the former 800px shortcut.
            final tier = shellLayoutTierFor(constraints.maxWidth);
            final isDesktop = tier != ShellLayoutTier.compact;
            final isAdmin =
                widget.authController.role == AppConstants.roleAdmin;

            // Desktop administrator workbench
            if (isAdmin && isDesktop) {
              return AdminDesktopShell(
                authController: widget.authController,
                notificationController: widget.notificationController,
                currentLocation: GoRouterState.of(context).uri.toString(),
                compactNavigation: tier == ShellLayoutTier.medium,
                child: widget.child,
              );
            }

            // PHASE 1: At 800px every authenticated role uses persistent desktop navigation.
            if (isDesktop) {
              return ShellBackRegistryScope(
                  registry: _backRegistry,
                  child: RoleDesktopShell(
                      role: role ?? 'student',
                      currentLocation: _location,
                      accountName:
                          widget.authController.profile?['name'] as String? ??
                              'Account',
                      accountImageUrl: widget
                          .authController.profile?['avatar_url'] as String?,
                      unreadCount: widget.notificationController.unreadCount,
                      onSignOut: widget.authController.signOut,
                      compactNavigation: tier == ShellLayoutTier.medium,
                      child: widget.child));
            }

            // Standard mobile / responsive app shell
            return PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop) _onBackPressed();
              },
              child: ShellBackRegistryScope(
                registry: _backRegistry,
                child: Scaffold(
                  backgroundColor: AppColors.bgPrimary,
                  // PHASE 1: Embedded UAppBars provide the mobile account action.
                  body: DesktopShellScope(
                      isDesktop: false, tier: tier, child: widget.child),
                  bottomNavigationBar: AppBottomNav(
                    role: widget.authController.role,
                    currentRoute: _location,
                    unreadNotifCount: widget.notificationController.unreadCount,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
