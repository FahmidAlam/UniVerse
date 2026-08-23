import 'package:flutter/material.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/core/constants/app_enums.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/shared/widgets/u_badge.dart';
import 'package:universe/shared/widgets/u_card.dart';

class ClassCard extends StatelessWidget {
  final String subject;
  final String teacher;
  final String room;
  final String timeSlot;
  final ClassStatus status;
  final String? batch;
  final String? section;
  final VoidCallback? onTap;

  const ClassCard({
    super.key,
    required this.subject,
    required this.teacher,
    required this.room,
    required this.timeSlot,
    required this.status,
    this.batch,
    this.section,
    this.onTap,
  });

  bool get _isCancelled => status == ClassStatus.cancelled;
  bool get _isDone => status == ClassStatus.done;

  @override
  Widget build(BuildContext context) {
    return UCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  subject,
                  style: AppTextStyles.h3.copyWith(
                    color: _isCancelled || _isDone
                        ? AppColors.textMuted
                        : AppColors.textPrimary,
                    decoration:
                        _isCancelled ? TextDecoration.lineThrough : null,
                    decorationColor: AppColors.textMuted,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              UBadge(status: status),
            ],
          ),

          AppSpacing.smGap,

          Row(
            children: [
              Icon(
                PhosphorIconsRegular.userCircle,
                size: AppSpacing.iconSm,
                color: _isCancelled
                    ? AppColors.textDisabled
                    : AppColors.textMuted,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  teacher,
                  style: AppTextStyles.bodySm.copyWith(
                    color: _isCancelled
                        ? AppColors.textDisabled
                        : AppColors.textSecondary,
                    decoration:
                        _isCancelled ? TextDecoration.lineThrough : null,
                    decorationColor: AppColors.textDisabled,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                PhosphorIconsRegular.mapPin,
                size: AppSpacing.iconSm,
                color: _isCancelled
                    ? AppColors.textDisabled
                    : AppColors.textMuted,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                room,
                style: AppTextStyles.bodySm.copyWith(
                  color: _isCancelled
                      ? AppColors.textDisabled
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),

          AppSpacing.smGap,

          Row(
            children: [
              Icon(
                PhosphorIconsRegular.clock,
                size: AppSpacing.iconSm,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(timeSlot, style: AppTextStyles.caption),
              if (batch != null && section != null) ...[
                const Spacer(),
                Text(
                  'Batch $batch · $section',
                  style: AppTextStyles.caption,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
