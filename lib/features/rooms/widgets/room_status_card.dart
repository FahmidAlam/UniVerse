import 'package:flutter/material.dart';
import 'package:universe/shared/widgets/u_card.dart';
import 'package:universe/shared/widgets/u_pressable_scale.dart';
import 'package:go_router/go_router.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/core/router/route_names.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/rooms/controllers/rooms_controller.dart';

class RoomStatusCard extends StatelessWidget {
  final RoomStatus roomStatus;
  final VoidCallback? onSelect;
  final bool isSelected;

  const RoomStatusCard({
    super.key,
    required this.roomStatus,
    this.onSelect,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelect,
      borderRadius: AppSpacing.radiusMd,
      child: UCard(
        isTopLit: true,
        margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        padding: EdgeInsets.zero,
        border:
            isSelected ? Border.all(color: AppColors.primary, width: 2) : null,
        child: DecoratedBox(
          decoration: BoxDecoration(
              border: Border(
                  left: BorderSide(
                      color: roomStatus.isOccupied
                          ? AppColors.error
                          : AppColors.success,
                      width: 3))),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                        child: Row(
                      children: [
                        Icon(
                          PhosphorIconsRegular.door,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          size: AppSpacing.iconMd,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                            child: Text(
                          roomStatus.room,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.h3.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w600,
                          ),
                        )),
                      ],
                    )),
                    const SizedBox(width: AppSpacing.sm),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
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
                        const SizedBox(height: 2),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text('Derived from published routine',
                    style: AppTextStyles.caption
                        .copyWith(fontSize: 9, color: AppColors.textMuted)),
                const SizedBox(height: AppSpacing.md),

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
                  _InfoRow(
                      label: 'Class', value: roomStatus.currentClass ?? 'N/A'),
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
                    _InfoRow(
                        label: 'Time', value: roomStatus.nextTime ?? 'N/A'),
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
                // PHASE 1: The room identifier is durable even when extra is lost on refresh.
                _MoreDetailsLink(
                  onTap: () {
                    if (onSelect != null) {
                      onSelect!();
                    } else {
                      context.push(
                        RouteNames.roomDetailLocation(roomStatus.room),
                        extra: roomStatus.room,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
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
    return UPressableScale(
        child: Material(
      color: Colors.transparent,
      borderRadius: AppSpacing.radiusSm,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.radiusSm,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
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
    ));
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
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyMedium.copyWith(
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
