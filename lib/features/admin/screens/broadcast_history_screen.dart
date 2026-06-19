// ============================================================
// FILE: lib/features/admin/screens/broadcast_history_screen.dart
// PURPOSE: The "Sent Broadcasts" list, split out of the Campus
// Broadcast composer so that page stays a clean compose form.
// Pushed (back button). Tap a broadcast to delete it (for everyone).
// ============================================================

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/admin/controllers/broadcast_controller.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/shared/widgets/notification_tile.dart';
import 'package:universe/shared/widgets/scrollable_empty.dart';
import 'package:universe/shared/widgets/u_app_bar.dart';
import 'package:universe/shared/widgets/u_empty_state.dart';
import 'package:universe/shared/widgets/u_loading.dart';

class BroadcastHistoryScreen extends StatefulWidget {
  final AuthController authController;

  const BroadcastHistoryScreen({super.key, required this.authController});

  @override
  State<BroadcastHistoryScreen> createState() => _BroadcastHistoryScreenState();
}

class _BroadcastHistoryScreenState extends State<BroadcastHistoryScreen> {
  late final BroadcastController _controller;

  @override
  void initState() {
    super.initState();
    _controller = BroadcastController(authController: widget.authController);
    _controller.loadRecent();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete(String id, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: AppSpacing.radiusLg),
        title: Text('Delete broadcast?', style: AppTextStyles.h3),
        content: Text(
          '"$title" will be removed for everyone.',
          style: AppTextStyles.bodySm,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: AppTextStyles.danger),
          ),
        ],
      ),
    );
    if (confirmed == true) await _controller.deleteBroadcast(id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: const UAppBar(title: 'Sent Broadcasts'),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.bgCard,
            onRefresh: _controller.loadRecent,
            child: _buildBody(),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_controller.isLoadingRecent && _controller.recent.isEmpty) {
      return ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (_, __) => const ULoading.skeleton(skeletonHeight: 72),
      );
    }

    final items = _controller.recent;
    if (items.isEmpty) {
      return const ScrollableEmpty(
        child: UEmptyState(
          icon: PhosphorIconsRegular.bellRinging,
          title: 'No broadcasts yet',
          message: 'Broadcasts you send will appear here.',
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: items.length,
      itemBuilder: (context, i) {
        final n = items[i];
        return NotificationTile(
          title: n.title,
          body: n.body,
          type: n.type,
          time: n.time,
          onTap: () => _confirmDelete(n.id, n.title),
        );
      },
    );
  }
}
