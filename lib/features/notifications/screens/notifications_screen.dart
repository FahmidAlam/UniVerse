// ============================================================
// FILE: lib/features/notifications/screens/notifications_screen.dart
// PURPOSE: Alerts tab. Audience-filtered broadcast feed with
// type filter chips, unread badge, tap-to-read, mark-all-read,
// and live updates via Supabase Realtime.
// Uses the app-scoped NotificationController owned by AppRouter —
// the same instance drives the shell's nav badge, so marking
// items read here updates the badge everywhere instantly.
// ============================================================

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:universe_v1/core/constants/app_enums.dart';
import 'package:universe_v1/core/theme/app_colors.dart';
import 'package:universe_v1/core/theme/app_spacing.dart';
import 'package:universe_v1/core/theme/app_text_styles.dart';
import 'package:universe_v1/features/auth/controllers/auth_controller.dart';
import 'package:universe_v1/features/notifications/controllers/notification_controller.dart';
import 'package:universe_v1/shared/widgets/notification_tile.dart';
import 'package:universe_v1/shared/widgets/u_app_bar.dart';
import 'package:universe_v1/shared/widgets/u_chip.dart';
import 'package:universe_v1/shared/widgets/u_empty_state.dart';
import 'package:universe_v1/shared/widgets/u_loading.dart';

class NotificationsScreen extends StatefulWidget {
  final AuthController authController;

  /// App-scoped controller shared with the shell's nav badge.
  /// Owned by AppRouter — never disposed here.
  final NotificationController controller;

  const NotificationsScreen({
    super.key,
    required this.authController,
    required this.controller,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  NotificationController get _controller => widget.controller;

  // Filter chips: null == All, then one per NotifType.
  static const List<NotifType?> _filters = [
    null,
    NotifType.university,
    NotifType.classCancel,
    NotifType.roomChange,
    NotifType.testReminder,
    NotifType.assignment,
    NotifType.exam,
  ];

  String _filterLabel(NotifType? type) {
    switch (type) {
      case null:
        return 'All';
      case NotifType.university:
        return 'University';
      case NotifType.classCancel:
        return 'Cancellations';
      case NotifType.roomChange:
        return 'Room Change';
      case NotifType.testReminder:
        return 'Tests';
      case NotifType.assignment:
        return 'Assignments';
      case NotifType.exam:
        return 'Exams';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.bgPrimary,
          appBar: UAppBar(
            title: 'Notifications',
            showBackButton: false,
            actions: [
              if (_controller.unreadCount > 0)
                TextButton(
                  onPressed: _controller.markAllRead,
                  child: Text('Mark all read', style: AppTextStyles.link),
                ),
            ],
          ),
          body: Column(
            children: [
              _buildFilterBar(),
              Expanded(child: _buildBody()),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterBar() {
    return SizedBox(
      height: AppSpacing.chipHeight + AppSpacing.lg,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenH,
          vertical: AppSpacing.sm,
        ),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) {
          final type = _filters[i];
          return UChip(
            label: _filterLabel(type),
            isActive: _controller.activeFilter == type,
            onTap: () => _controller.setFilter(type),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    final items = _controller.filtered;

    if (_controller.isLoading && items.isEmpty) {
      return ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (_, __) => const ULoading.skeleton(skeletonHeight: 72),
      );
    }

    if (items.isEmpty) {
      return const UEmptyState(
        icon: PhosphorIconsRegular.bellSlash,
        title: 'No notifications',
        message: 'You\'re all caught up. New alerts will show up here.',
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.bgCard,
      onRefresh: _controller.load,
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: items.length,
        itemBuilder: (context, i) {
          final n = items[i];
          return NotificationTile(
            title: n.title,
            body: n.body,
            type: n.type,
            time: n.time,
            isRead: n.isRead,
            onTap: () => _controller.markRead(n.id),
          );
        },
      ),
    );
  }
}
