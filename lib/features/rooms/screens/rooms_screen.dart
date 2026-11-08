// PHASE 1: Campus shares navigation and shell-aware account/page chrome.
import 'package:universe/shared/widgets/campus_lookup_switcher.dart';
import 'package:universe/shared/widgets/u_app_bar.dart';
import 'package:universe/shared/widgets/u_responsive_workspace.dart';
import 'package:flutter/material.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/rooms/controllers/rooms_controller.dart';
import 'package:universe/features/rooms/services/room_status_service.dart';
import 'package:universe/features/rooms/widgets/room_status_card.dart';

class RoomsScreen extends StatefulWidget {
  final RoomsController? controller;

  const RoomsScreen({super.key, this.controller});

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  late final RoomsController _controller;
  late final bool _ownsController;

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

  void _onControllerChange() {
    setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChange);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      // PHASE 1: UAppBar removes implicit drawer chrome and exposes account access.
      appBar: UAppBar(
        title: 'Rooms',
        showBackButton: false,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(
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
      // PHASE 1: Keep the Campus switcher available in all asynchronous states.
      body: Column(children: [
        const CampusLookupSwitcher(faculty: false),
        Expanded(child: _buildContent())
      ]),
    );
  }

  Widget _buildContent() {
    if (_controller.isLoading) {
      return Center(
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
            Icon(
              PhosphorIconsRegular.warningCircle,
              color: AppColors.error,
              size: AppSpacing.iconXl,
            ),
            SizedBox(height: AppSpacing.md),
            Text(
              'Error loading rooms',
              style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              _controller.error ?? 'Unknown error',
              style: AppTextStyles.bodySm.copyWith(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: () {
                _controller.fetchRoomStatuses();
              },
              icon: Icon(PhosphorIconsRegular.arrowClockwise),
              label: Text('Retry'),
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
            Icon(
              PhosphorIconsRegular.door,
              color: AppColors.textMuted,
              size: AppSpacing.iconXl,
            ),
            SizedBox(height: AppSpacing.md),
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
          final isDesktopGrid = constraints.maxWidth >= 700;
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
                    return RoomStatusCard(roomStatus: roomStatus);
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
