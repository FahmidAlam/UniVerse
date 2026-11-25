import 'package:flutter/material.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/core/constants/app_enums.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/features/notifications/controllers/notification_controller.dart';
import 'package:universe/shared/widgets/desktop_shell_scope.dart';
import 'package:universe/shared/widgets/notification_tile.dart';
import 'package:universe/shared/widgets/scrollable_empty.dart';
import 'package:universe/shared/widgets/shell_back_scope.dart';
import 'package:universe/shared/widgets/u_app_bar.dart';
import 'package:universe/shared/widgets/u_card.dart';
import 'package:universe/shared/widgets/u_chip.dart';
import 'package:universe/shared/widgets/u_empty_state.dart';
import 'package:universe/shared/widgets/u_loading.dart';

class NotificationsScreen extends StatefulWidget {
  final AuthController authController;
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

  String _formatLastChecked(DateTime? dt) {
    if (dt == null) return 'Checking...';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 45) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hour:$min $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final isDesktopShell = DesktopShellScope.isDesktopOf(context);

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final selecting = _controller.selectionMode;
        return ShellBackScope(
          onBack: selecting ? _controller.exitSelection : null,
          child: Scaffold(
            backgroundColor: AppColors.bgPrimary,
            appBar: isDesktopShell
                ? null
                : (selecting ? _selectionAppBar() : _defaultAppBar()),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isDesktopShell) _buildDesktopHeader(selecting),
                    _buildStatusBar(),
                    if (!selecting) _buildFilterBar(),
                    Expanded(child: _buildBody()),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopHeader(bool selecting) {
    if (selecting) {
      final count = _controller.selectedCount;
      return Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        color: AppColors.bgElevated,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(PhosphorIconsRegular.x, color: AppColors.textPrimary),
              onPressed: _controller.exitSelection,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              count == 0 ? 'Select items' : '$count selected',
              style: AppTextStyles.h3,
            ),
            const Spacer(),
            TextButton.icon(
              icon: Icon(
                PhosphorIconsRegular.trash,
                color: count == 0 ? AppColors.textMuted : AppColors.error,
              ),
              label: Text(
                'Remove selected',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: count == 0 ? AppColors.textMuted : AppColors.error,
                ),
              ),
              onPressed: count == 0 ? null : _confirmDismiss,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Notifications & Alerts', style: AppTextStyles.h2),
              const SizedBox(height: 2),
              Text(
                'Realtime cancellation updates & academic broadcasts',
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          const Spacer(),
          if (_controller.unreadCount > 0) ...[
            TextButton(
              onPressed: _controller.markAllRead,
              child: Text('Mark all read', style: AppTextStyles.link),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          if (_controller.filtered.isNotEmpty) ...[
            OutlinedButton.icon(
              onPressed: _controller.enterSelection,
              icon: const Icon(PhosphorIconsRegular.checkSquare, size: 16),
              label: const Text('Select'),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          ElevatedButton.icon(
            onPressed: _controller.isLoading ? null : () => _controller.load(),
            icon: _controller.isLoading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.textPrimary,
                    ),
                  )
                : const Icon(PhosphorIconsRegular.arrowClockwise, size: 16),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    final lastCheckedStr = _formatLastChecked(_controller.lastChecked);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Live updates active',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.success,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '•',
            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(width: 12),
          Icon(
            PhosphorIconsRegular.clock,
            size: 14,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 4),
          Text(
            'Last checked: $lastCheckedStr',
            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
          ),
          const Spacer(),
          if (_controller.unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: AppSpacing.radiusFull,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                '${_controller.unreadCount} Unread',
                style: AppTextStyles.badge.copyWith(color: AppColors.primary),
              ),
            ),
        ],
      ),
    );
  }

  UAppBar _defaultAppBar() {
    return UAppBar(
      title: 'Notifications',
      showBackButton: false,
      actions: [
        IconButton(
          tooltip: 'Refresh alerts',
          icon: _controller.isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
              : const Icon(
                  PhosphorIconsRegular.arrowClockwise,
                  color: AppColors.textPrimary,
                ),
          onPressed: _controller.isLoading ? null : () => _controller.load(),
        ),
        if (_controller.unreadCount > 0)
          TextButton(
            onPressed: _controller.markAllRead,
            child: Text('Mark all read', style: AppTextStyles.link),
          ),
        if (_controller.filtered.isNotEmpty)
          IconButton(
            tooltip: 'Select',
            icon: const Icon(
              PhosphorIconsRegular.checkSquare,
              color: AppColors.textPrimary,
            ),
            onPressed: _controller.enterSelection,
          ),
      ],
    );
  }

  UAppBar _selectionAppBar() {
    final count = _controller.selectedCount;
    return UAppBar(
      title: count == 0 ? 'Select items' : '$count selected',
      showBackButton: false,
      leading: IconButton(
        icon: const Icon(PhosphorIconsRegular.x, color: AppColors.textPrimary),
        onPressed: _controller.exitSelection,
      ),
      actions: [
        IconButton(
          tooltip: 'Remove from my list',
          icon: Icon(
            PhosphorIconsRegular.trash,
            color: count == 0 ? AppColors.textMuted : AppColors.error,
          ),
          onPressed: count == 0 ? null : _confirmDismiss,
        ),
      ],
    );
  }

  Future<void> _confirmDismiss() async {
    final count = _controller.selectedCount;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: AppSpacing.radiusLg),
        title: Text(
          'Remove $count notification${count == 1 ? '' : 's'}?',
          style: AppTextStyles.h3,
        ),
        content: Text(
          'They’ll be hidden from your list only — nothing is deleted for '
          'anyone else.',
          style: AppTextStyles.bodySm,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Remove', style: AppTextStyles.danger),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _controller.dismissSelected();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed from your list.', style: AppTextStyles.bodySm),
        backgroundColor: AppColors.bgElevated,
        behavior: SnackBarBehavior.floating,
      ),
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
      return RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.bgCard,
        onRefresh: _controller.load,
        child: const ScrollableEmpty(
          child: UEmptyState(
            icon: PhosphorIconsRegular.bellSlash,
            title: 'No notifications',
            message: 'You\'re all caught up. New alerts will show up here.',
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.bgCard,
      onRefresh: _controller.load,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: UCard(
          isTopLit: true,
          padding: EdgeInsets.zero,
          child: ClipRRect(
            borderRadius: AppSpacing.radiusMd,
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(
                height: 1,
                thickness: 1,
                color: AppColors.border,
              ),
              itemBuilder: (context, i) {
                final n = items[i];

                if (_controller.selectionMode) {
                  final selected = _controller.isSelected(n.id);
                  return Material(
                    color: selected ? AppColors.primarySoft : Colors.transparent,
                    child: InkWell(
                      onTap: () => _controller.toggleSelected(n.id),
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: AppSpacing.md),
                            child: Icon(
                              selected
                                  ? PhosphorIconsRegular.checkCircle
                                  : PhosphorIconsRegular.circle,
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.textMuted,
                              size: AppSpacing.iconLg,
                            ),
                          ),
                          Expanded(
                            child: IgnorePointer(
                              child: NotificationTile(
                                title: n.title,
                                body: n.body,
                                type: n.type,
                                time: n.time,
                                isRead: n.isRead,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return GestureDetector(
                  onLongPress: () => _controller.selectFromLongPress(n.id),
                  child: NotificationTile(
                    title: n.title,
                    body: n.body,
                    type: n.type,
                    time: n.time,
                    isRead: n.isRead,
                    onTap: () => _controller.markRead(n.id),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
