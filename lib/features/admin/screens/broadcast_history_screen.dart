import 'dart:async';
import 'package:universe/features/admin/widgets/admin_route_tabs.dart';
import 'package:universe/shared/widgets/u_card.dart';
import 'package:universe/shared/widgets/u_chip.dart';
import 'package:universe/shared/widgets/u_adaptive_overlay.dart';
import 'package:universe/shared/widgets/desktop_shell_scope.dart';
import 'package:flutter/material.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/admin/controllers/broadcast_controller.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/shared/widgets/notification_tile.dart';
import 'package:universe/shared/widgets/u_app_bar.dart';
import 'package:universe/shared/widgets/u_empty_state.dart';
import 'package:universe/shared/widgets/u_loading.dart';

class BroadcastHistoryScreen extends StatefulWidget {
  final BroadcastController? controller;
  final AuthController authController;

  const BroadcastHistoryScreen(
      {super.key, required this.authController, this.controller});

  @override
  State<BroadcastHistoryScreen> createState() => _BroadcastHistoryScreenState();
}

class _BroadcastHistoryScreenState extends State<BroadcastHistoryScreen> {
  late final BroadcastController _controller;
  String _query = '';
  final _search = TextEditingController();
  String? _audience;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ??
        BroadcastController(authController: widget.authController);
    _controller.loadRecent();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete(String id, String title) async {
    final confirmed = await showUAdaptiveModal<bool>(
      context: context,
      title: 'Delete broadcast?',
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
        Text('"$title" will be removed for everyone.',
            style: AppTextStyles.bodySm),
        AppSpacing.mdGap,
        Wrap(spacing: 12, children: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ]),
      ]),
    );
    if (confirmed == true) await _controller.deleteBroadcast(id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: DesktopShellScope.isDesktopOf(context)
          ? null
          : const UAppBar(title: 'Sent Broadcasts'),
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
    final items = _controller.recent
        .where((n) =>
            (_audience == null || n.targetRole == _audience) &&
            '${n.title} ${n.body}'.toLowerCase().contains(_query))
        .toList();
    return Center(
        child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1160),
            child: Column(children: [
              Padding(
                  padding: AppSpacing.screenPadding,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AdminRouteTabs(
                            selected: '/admin/broadcast/history',
                            destinations: {
                              '/admin/broadcast': 'Compose Broadcast',
                              '/admin/broadcast/history': 'Sent History'
                            }),
                        AppSpacing.mdGap,
                        TextField(
                            controller: _search,
                            decoration: const InputDecoration(
                                labelText: 'Search broadcasts',
                                prefixIcon: Icon(Icons.search)),
                            onChanged: (value) {
                              _debounce?.cancel();
                              _debounce =
                                  Timer(const Duration(milliseconds: 300), () {
                                if (mounted) {
                                  setState(() =>
                                      _query = value.trim().toLowerCase());
                                }
                              });
                            }),
                        AppSpacing.smGap,
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          for (final entry in <String?, String>{
                            null: 'All audiences',
                            'student': 'Students',
                            'teacher': 'Teachers',
                            'admin': 'Admins'
                          }.entries)
                            UChip(
                                label: entry.value,
                                isActive: _audience == entry.key,
                                onTap: () =>
                                    setState(() => _audience = entry.key)),
                        ]),
                        AppSpacing.smGap,
                        AdminMatchCount(
                            label: 'Showing ${items.length} broadcasts'),
                      ])),
              Expanded(
                  child: _controller.isLoadingRecent
                      ? const ULoading.spinner()
                      : _controller.errorMessage != null
                          ? UEmptyState.error(
                              message: _controller.errorMessage!,
                              onRetry: _controller.loadRecent)
                          : items.isEmpty
                              ? UEmptyState.noMatches(
                                  title: _controller.recent.isEmpty
                                      ? 'No broadcasts yet'
                                      : 'No matching broadcasts',
                                  onClearFilters: () {
                                    _debounce?.cancel();
                                    _search.clear();
                                    setState(() {
                                      _query = '';
                                      _audience = null;
                                    });
                                  })
                              : Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.screenH),
                                  child: UCard(
                                      isTopLit: true,
                                      padding: EdgeInsets.zero,
                                      child: ListView.separated(
                                        itemCount: items.length,
                                        separatorBuilder: (_, __) =>
                                            const Divider(
                                                height: 1,
                                                thickness: 1,
                                                color: AppColors.border),
                                        itemBuilder: (context, i) {
                                          final n = items[i];
                                          return NotificationTile(
                                              title: n.title,
                                              body: n.body,
                                              type: n.type,
                                              time: n.time,
                                              onTap: () => _confirmDelete(
                                                  n.id, n.title));
                                        },
                                      )))),
            ])));
  }
}
