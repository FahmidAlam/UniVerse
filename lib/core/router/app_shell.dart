import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/features/notifications/controllers/notification_controller.dart';
import 'package:universe/shared/widgets/app_bottom_nav.dart';
import 'package:universe/shared/widgets/app_drawer.dart';
import 'package:universe/shared/widgets/explore_fab_menu.dart';
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
    _location = GoRouterState.of(context).matchedLocation;
    // Each role's first tab is its dashboard, so this doubles as the "is this
    // a dashboard" test the Explore FAB needs.
    _home = AppBottomNav.destinationsFor(widget.authController.role).first.route;

    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.authController,
        widget.notificationController,
      ]),
      builder: (context, _) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _onBackPressed();
          },
          child: ShellBackRegistryScope(
            registry: _backRegistry,
            child: Scaffold(
              backgroundColor: AppColors.bgPrimary,
              body: widget.child,
              floatingActionButton:
                  _location == _home ? const _ExploreFab() : null,
              floatingActionButtonLocation:
                  FloatingActionButtonLocation.endFloat,
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
  }
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
