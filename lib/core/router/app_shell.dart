// ============================================================
// FILE: lib/core/router/app_shell.dart
// PURPOSE: Single Scaffold around all top-level tab screens.
// The bottom nav lives HERE — wrapped routes render only their
// content. Active tab is derived from the router location, so
// screens no longer declare (or duplicate) nav placement.
//
// Also hosts the app-scoped NotificationController: one Realtime
// subscription for the whole session, and the unread badge is
// visible on every tab instead of only the Alerts screen.
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/features/notifications/controllers/notification_controller.dart';
import 'package:universe/shared/widgets/app_bottom_nav.dart';
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

  // Different user signed in (sign-out → sign-in remounts the shell,
  // but profile swaps without remount are possible too) — refetch so
  // the previous user's items/badge never leak across accounts.
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
          floatingActionButton: (location == '/student/dashboard' ||
                  location == '/teacher/dashboard' ||
                  location == '/admin/dashboard')
              ? const ExploreFabMenu()
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
}
