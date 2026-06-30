import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/rooms/controllers/rooms_controller.dart';
import 'package:universe/features/rooms/services/room_status_service.dart';
import 'package:universe/features/rooms/widgets/room_status_card.dart';

class RoomsScreen extends StatefulWidget {
  const RoomsScreen({super.key});

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  late final RoomsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = RoomsController(service: RoomStatusService());
    _controller.fetchRoomStatuses();
    _controller.subscribeToRealTimeUpdates();
    _controller.addListener(_onControllerChange);
  }

  void _onControllerChange() {
    setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChange);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        title: Text(
          'Rooms',
          style: AppTextStyles.h2.copyWith(color: AppColors.textPrimary),
        ),
        actions: [
          IconButton(
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
      body: _buildContent(),
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
      child: ListView.builder(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        itemCount: _controller.roomStatuses.length,
        itemBuilder: (context, index) {
          final roomStatus = _controller.roomStatuses[index];
          return RoomStatusCard(roomStatus: roomStatus);
        },
      ),
    );
  }
}
