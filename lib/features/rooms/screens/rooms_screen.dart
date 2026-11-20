// PHASE 1 & 6: Campus shares navigation and shell-aware account/page chrome.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:universe/core/router/route_names.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/rooms/controllers/rooms_controller.dart';
import 'package:universe/features/rooms/screens/room_detail_screen.dart';
import 'package:universe/features/rooms/services/room_status_service.dart';
import 'package:universe/features/rooms/widgets/room_status_card.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/shared/widgets/campus_lookup_switcher.dart';
import 'package:universe/shared/widgets/desktop_shell_scope.dart';
import 'package:universe/shared/widgets/u_app_bar.dart';
import 'package:universe/shared/widgets/u_card.dart';
import 'package:universe/shared/widgets/u_responsive_workspace.dart';

class RoomsScreen extends StatefulWidget {
  final RoomsController? controller;

  const RoomsScreen({super.key, this.controller});

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  late final RoomsController _controller;
  late final bool _ownsController;
  String? _selectedRoom;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller =
        widget.controller ?? RoomsController(service: RoomStatusService());
    if (_ownsController) {
      _controller.fetchRoomStatuses();
      _controller.subscribeToRealTimeUpdates();
    }
    _controller.addListener(_onControllerChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      final queryRoom = GoRouterState.of(context).uri.queryParameters['room'];
      if (queryRoom != null && queryRoom.isNotEmpty && _selectedRoom == null) {
        _selectedRoom = queryRoom;
      }
    } catch (_) {
      // Ignored when outside GoRouter tree (e.g. tests)
    }
  }

  void _onControllerChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChange);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _selectRoom(String roomName, bool isDesktop) {
    setState(() => _selectedRoom = roomName);
    if (isDesktop) {
      try {
        final uri = GoRouterState.of(context).uri;
        final newParams = Map<String, String>.from(uri.queryParameters);
        newParams['room'] = roomName;
        final newUri = uri.replace(queryParameters: newParams);
        GoRouter.of(context).replace(newUri.toString());
      } catch (_) {}
    } else {
      context.push(
        RouteNames.roomDetailLocation(roomName),
        extra: roomName,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktopShell = DesktopShellScope.isDesktopOf(context);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: isDesktopShell
          ? null
          : UAppBar(
              title: 'Rooms',
              showBackButton: false,
              actions: [
                IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(
                    PhosphorIconsRegular.arrowClockwise,
                    color: AppColors.primary,
                    size: AppSpacing.iconMd,
                  ),
                  onPressed: () async {
                    await _controller.refresh();
                  },
                ),
              ],
            ),
      body: Column(
        children: [
          const CampusLookupSwitcher(faculty: false),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_controller.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      );
    }

    if (_controller.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              PhosphorIconsRegular.warningCircle,
              color: AppColors.error,
              size: AppSpacing.iconXl,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Error loading rooms',
              style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _controller.error ?? 'Unknown error',
              style: AppTextStyles.bodySm.copyWith(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: () {
                _controller.fetchRoomStatuses();
              },
              icon: const Icon(PhosphorIconsRegular.arrowClockwise),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_controller.roomStatuses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              PhosphorIconsRegular.door,
              color: AppColors.textMuted,
              size: AppSpacing.iconXl,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No rooms scheduled',
              style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _controller.refresh(),
      color: AppColors.primary,
      backgroundColor: AppColors.bgCard,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final usableWidth = constraints.maxWidth;
          final isMasterDetail = usableWidth >= 900;

          if (isMasterDetail) {
            final activeSelected = _selectedRoom ??
                (_controller.roomStatuses.isNotEmpty
                    ? _controller.roomStatuses.first.room
                    : '');

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left 55% Master List
                Expanded(
                  flex: 55,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.sm,
                          AppSpacing.lg,
                          AppSpacing.xs,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'ALL CAMPUS ROOMS',
                              style: AppTextStyles.labelCaps
                                  .copyWith(fontSize: 10),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.xs,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.bgSubtle,
                                borderRadius: AppSpacing.radiusFull,
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Text(
                                'Showing ${_controller.roomStatuses.length} rooms',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                          itemCount: _controller.roomStatuses.length,
                          itemBuilder: (context, index) {
                            final roomStatus =
                                _controller.roomStatuses[index];
                            final isSelected =
                                activeSelected == roomStatus.room;
                            return RoomStatusCard(
                              roomStatus: roomStatus,
                              isSelected: isSelected,
                              onSelect: () =>
                                  _selectRoom(roomStatus.room, true),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(color: AppColors.border, width: 1),
                // Right 45% Inline Weekly Schedule Detail Pane
                Expanded(
                  flex: 45,
                  child: Container(
                    color: AppColors.bgPrimary,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(PhosphorIconsRegular.calendarCheck,
                                color: AppColors.primary, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'WEEKLY SCHEDULE · $activeSelected',
                              style: AppTextStyles.labelCaps.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Occupancy derived from published routine. Tap any day to inspect class meetings.',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Expanded(
                          child: UCard(
                            isTopLit: true,
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            child: RoomDetailView(room: activeSelected),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          // Mobile / Tablet single column adaptive card grid
          final isDesktopGrid = usableWidth >= 700;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.bgSubtle,
                        borderRadius: AppSpacing.radiusFull,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        'Showing ${_controller.roomStatuses.length} rooms',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: UAdaptiveCardGrid(
                  singleColumnBreakpoint: 700,
                  mainAxisExtent: 332,
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktopGrid ? AppSpacing.sm : 0,
                    vertical: AppSpacing.md,
                  ),
                  itemCount: _controller.roomStatuses.length,
                  itemBuilder: (context, index) {
                    final roomStatus = _controller.roomStatuses[index];
                    return RoomStatusCard(
                      roomStatus: roomStatus,
                      onSelect: () => _selectRoom(roomStatus.room, false),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
