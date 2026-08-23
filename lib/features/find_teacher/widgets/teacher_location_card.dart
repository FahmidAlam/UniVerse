import 'package:flutter/material.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/find_teacher/controllers/find_teacher_controller.dart';

class TeacherLocationCard extends StatelessWidget {
  final TeacherInfo teacherInfo;

  const TeacherLocationCard({super.key, required this.teacherInfo});

  Color _getStatusColor(String status) {
    switch (status) {
      case 'In Class':
        return AppColors.error;
      case 'Free':
        return AppColors.warning;
      default:
        return AppColors.textMuted;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'In Class':
        return PhosphorIconsRegular.chalkboardTeacher;
      case 'Free':
        return PhosphorIconsRegular.checkCircle;
      default:
        return PhosphorIconsRegular.clock;
    }
  }

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
          color: AppColors.border,
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
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      PhosphorIconsRegular.person,
                      color: AppColors.primary,
                      size: AppSpacing.iconMd,
                    ),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            teacherInfo.name,
                            style: AppTextStyles.h4.copyWith(
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            teacherInfo.code,
                            style: AppTextStyles.bodySm.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(
                    teacherInfo.status!,
                  ).withValues(alpha: 0.15),
                  borderRadius: AppSpacing.radiusSm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getStatusIcon(teacherInfo.status!),
                      color: _getStatusColor(teacherInfo.status!),
                      size: AppSpacing.iconSm,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      teacherInfo.status!,
                      style: AppTextStyles.chip.copyWith(
                        color: _getStatusColor(teacherInfo.status!),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.md),

          if (teacherInfo.status == 'In Class') ...[
            _InfoRow(
              label: 'Current Room',
              value: teacherInfo.currentRoom ?? 'N/A',
              icon: PhosphorIconsRegular.door,
            ),
            SizedBox(height: AppSpacing.sm),
            _InfoRow(
              label: 'Subject',
              value: teacherInfo.currentSubject ?? 'N/A',
            ),
            SizedBox(height: AppSpacing.sm),
            _InfoRow(label: 'Class', value: teacherInfo.currentClass ?? 'N/A'),
            SizedBox(height: AppSpacing.sm),
            _InfoRow(
              label: 'Remaining',
              value: teacherInfo.remainingTime ?? 'TBD',
              valueColor: AppColors.primary,
            ),
          ] else if (teacherInfo.status == 'Free') ...[
            if (teacherInfo.nextRoom != null) ...[
              _InfoRow(
                label: 'Next Room',
                value: teacherInfo.nextRoom ?? 'N/A',
                icon: PhosphorIconsRegular.door,
              ),
              SizedBox(height: AppSpacing.sm),
              _InfoRow(
                label: 'Subject',
                value: teacherInfo.nextSubject ?? 'N/A',
              ),
              SizedBox(height: AppSpacing.sm),
              _InfoRow(label: 'Time', value: teacherInfo.nextTime ?? 'N/A'),
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
          ] else ...[
            Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text(
                'No classes scheduled for today',
                style: AppTextStyles.bodySm.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final IconData? icon;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.bodySm.copyWith(color: AppColors.textMuted),
        ),
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: AppColors.primary, size: AppSpacing.iconSm),
              const SizedBox(width: 4),
            ],
            Text(
              value,
              style: AppTextStyles.bodyMedium.copyWith(
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
