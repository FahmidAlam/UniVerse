import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/core/router/route_names.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/rooms/controllers/rooms_controller.dart';

class RoomStatusCard extends StatelessWidget {
  final RoomStatus roomStatus;

  const RoomStatusCard({super.key, required this.roomStatus});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        border: Border.all(
          color: roomStatus.isOccupied
              ? AppColors.borderError
              : AppColors.border,
          width: AppSpacing.borderThin,
        ),
        borderRadius: AppSpacing.radiusMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    PhosphorIconsRegular.door,
                    color: AppColors.primary,
                    size: AppSpacing.iconMd,
                  ),
                  SizedBox(width: AppSpacing.md),
                  Text(
                    roomStatus.room,
                    style: AppTextStyles.h3.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: roomStatus.isOccupied
                      ? AppColors.errorSoft
                      : AppColors.success.withValues(alpha: 0.1),
                  borderRadius: AppSpacing.radiusSm,
                ),
                child: Text(
                  roomStatus.isOccupied ? 'OCCUPIED' : 'AVAILABLE',
                  style: AppTextStyles.chip.copyWith(
                    color: roomStatus.isOccupied
                        ? AppColors.error
                        : AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.md),

          if (roomStatus.isOccupied) ...[
            _InfoRow(
              label: 'Teacher',
              value: roomStatus.currentTeacher ?? 'N/A',
            ),
            SizedBox(height: AppSpacing.sm),
            _InfoRow(
              label: 'Subject',
              value: roomStatus.currentSubject ?? 'N/A',
            ),
            SizedBox(height: AppSpacing.sm),
            _InfoRow(label: 'Class', value: roomStatus.currentClass ?? 'N/A'),
            SizedBox(height: AppSpacing.sm),
            _InfoRow(
              label: 'Time',
              value: '${roomStatus.timeStart} - ${roomStatus.timeEnd}',
              valueColor: AppColors.warning,
            ),
            SizedBox(height: AppSpacing.sm),
            _InfoRow(
              label: 'Remaining',
              value: roomStatus.remainingTime ?? 'TBD',
              valueColor: AppColors.primary,
            ),
          ] else ...[
            if (roomStatus.nextTeacher != null) ...[
              _InfoRow(
                label: 'Next Teacher',
                value: roomStatus.nextTeacher ?? 'N/A',
              ),
              SizedBox(height: AppSpacing.sm),
              _InfoRow(
                label: 'Subject',
                value: roomStatus.nextSubject ?? 'N/A',
              ),
              SizedBox(height: AppSpacing.sm),
              _InfoRow(label: 'Time', value: roomStatus.nextTime ?? 'N/A'),
            ] else ...[
              Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Text(
                  'No more classes today',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ],
          const _MoreDetailsDivider(),
          _MoreDetailsLink(
            onTap: () =>
                context.push(RouteNames.roomDetail, extra: roomStatus.room),
          ),
        ],
      ),
    );
  }
}

// ─── "More details" affordance ──────────────────────────────

class _MoreDetailsDivider extends StatelessWidget {
  const _MoreDetailsDivider();

  @override
  Widget build(BuildContext context) => const Divider(
        color: AppColors.border,
        height: AppSpacing.lg,
        thickness: AppSpacing.borderThin,
      );
}

/// Opens the full day-by-day schedule for this room / teacher.
class _MoreDetailsLink extends StatelessWidget {
  final VoidCallback onTap;

  const _MoreDetailsLink({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: AppSpacing.radiusSm,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.radiusSm,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'More details',
                style: AppTextStyles.link.copyWith(color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(
                PhosphorIconsRegular.caretRight,
                size: AppSpacing.iconSm,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.bodySm.copyWith(color: AppColors.textMuted),
        ),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
