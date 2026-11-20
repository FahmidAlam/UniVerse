import 'package:flutter/material.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/core/constants/app_enums.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/shared/widgets/u_badge.dart';
import 'package:universe/shared/widgets/u_card.dart';

// PHASE 4: Academic class card with semantic left accent bar, joint-section pill, and inline action slot.
class ClassCard extends StatelessWidget {
  final String subject;
  final String? subjectCode;
  final String teacher;
  final String room;
  final String timeSlot;
  final ClassStatus status;
  final String? batch;
  final String? section;
  final VoidCallback? onTap;
  final Widget? trailingAction;
  final String? statusLabelOverride;
  final bool isSelected;
  final bool hideDefaultCohortPill;

  const ClassCard({
    super.key,
    required this.subject,
    this.subjectCode,
    required this.teacher,
    required this.room,
    required this.timeSlot,
    required this.status,
    this.batch,
    this.section,
    this.onTap,
    this.trailingAction,
    this.statusLabelOverride,
    this.isSelected = false,
    this.hideDefaultCohortPill = false,
  });

  bool get _isCancelled => status == ClassStatus.cancelled;
  bool get _isDone => status == ClassStatus.done;
  bool get _showAccentBar =>
      isSelected || _isCancelled || status == ClassStatus.live;

  bool get _isLab {
    final lower = subject.toLowerCase();
    final roomLower = room.toLowerCase();
    return lower.contains('lab') ||
        lower.contains('sessional') ||
        roomLower.contains('lab');
  }

  bool get _isJoint =>
      (section != null && section!.contains('+')) || teacher.contains('/');

  Color get _accentColor {
    if (_isCancelled) return AppColors.error;
    if (status == ClassStatus.live) return AppColors.primary;
    if (_isLab) return AppColors.success;
    if (_isJoint) return AppColors.info;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected
        ? AppColors.primary
        : (_isCancelled
            ? AppColors.error.withValues(alpha: 0.35)
            : AppColors.border);

    return UCard(
      isTopLit: true,
      onTap: onTap,
      border: Border.all(color: borderColor),
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          if (_showAccentBar)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 3,
              child: ColoredBox(color: _accentColor),
            ),
          Padding(
            padding: AppSpacing.cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (subjectCode != null &&
                              subjectCode!.trim().isNotEmpty) ...[
                            Text(
                              subjectCode!,
                              style: AppTextStyles.caption.copyWith(
                                color: _accentColor,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(height: 2),
                          ],
                          Text(
                            subject,
                            style: AppTextStyles.h3.copyWith(
                              color: _isCancelled || _isDone
                                  ? AppColors.textMuted
                                  : AppColors.textPrimary,
                              decoration: _isCancelled
                                  ? TextDecoration.lineThrough
                                  : null,
                              decorationColor: AppColors.textMuted,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    if (statusLabelOverride != null &&
                        statusLabelOverride!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _isCancelled
                              ? AppColors.errorSoft
                              : AppColors.bgElevated,
                          borderRadius: AppSpacing.radiusSm,
                          border: Border.all(
                            color: _isCancelled
                                ? AppColors.error.withValues(alpha: 0.45)
                                : AppColors.border,
                          ),
                        ),
                        child: Text(
                          statusLabelOverride!,
                          style: AppTextStyles.badge.copyWith(
                            color: _isCancelled
                                ? AppColors.error
                                : AppColors.textSecondary,
                          ),
                        ),
                      )
                    else
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.bgElevated,
                        borderRadius: AppSpacing.radiusSm,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            PhosphorIconsRegular.mapPin,
                            size: AppSpacing.iconSm,
                            color: _isCancelled
                                ? AppColors.textDisabled
                                : AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            room,
                            style: AppTextStyles.roomCode.copyWith(
                              fontSize: 12,
                              color: _isCancelled
                                  ? AppColors.textDisabled
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                AppSpacing.smGap,
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          PhosphorIconsRegular.clock,
                          size: AppSpacing.iconSm,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(timeSlot, style: AppTextStyles.timeCode),
                      ],
                    ),
                    if (batch != null &&
                        section != null &&
                        (!hideDefaultCohortPill || _isJoint || _isLab))
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _isJoint
                              ? AppColors.infoSoft
                              : (_isLab
                                  ? AppColors.successSoft
                                  : AppColors.bgSubtle),
                          borderRadius: AppSpacing.radiusSm,
                          border: Border.all(
                            color: _isJoint
                                ? AppColors.info.withValues(alpha: 0.4)
                                : (_isLab
                                    ? AppColors.success.withValues(alpha: 0.4)
                                    : AppColors.border),
                          ),
                        ),
                        child: Text(
                          _isJoint
                              ? (section!.contains('+')
                                  ? '$section Joint'
                                  : 'Joint $section')
                              : (_isLab
                                  ? 'Lab · Sec $section'
                                  : 'Batch $batch · $section'),
                          style: AppTextStyles.caption.copyWith(
                            color: _isJoint
                                ? AppColors.info
                                : (_isLab
                                    ? AppColors.success
                                    : AppColors.textSecondary),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (trailingAction != null) trailingAction!,
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
