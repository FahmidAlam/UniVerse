import 'package:flutter/material.dart';
import 'package:universe/shared/widgets/u_card.dart';
import 'package:universe/shared/widgets/u_pressable_scale.dart';
import 'package:go_router/go_router.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/core/router/route_names.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/find_teacher/controllers/find_teacher_controller.dart';
import 'package:universe/features/find_teacher/screens/teacher_detail_screen.dart';

class TeacherLocationCard extends StatelessWidget {
  final TeacherInfo teacherInfo;
  final VoidCallback? onSelect;
  final bool isSelected;

  const TeacherLocationCard({
    super.key,
    required this.teacherInfo,
    this.onSelect,
    this.isSelected = false,
  });

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
                      color: _getStatusColor(teacherInfo.status ?? ''),
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
                            PhosphorIconsRegular.person,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            size: AppSpacing.iconMd,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  teacherInfo.name,
                                  style: AppTextStyles.h4.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w600,
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
                    const SizedBox(width: AppSpacing.md),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
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
                  _InfoRow(
                      label: 'Class', value: teacherInfo.currentClass ?? 'N/A'),
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
                    _InfoRow(
                        label: 'Time', value: teacherInfo.nextTime ?? 'N/A'),
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
                const Divider(
                  color: AppColors.border,
                  height: AppSpacing.lg,
                  thickness: AppSpacing.borderThin,
                ),
                // PHASE 1: Persist faculty identity in the URL alongside the typed payload.
                _MoreDetailsLink(
                  onTap: () {
                    if (onSelect != null) {
                      onSelect!();
                    } else {
                      context.push(
                        RouteNames.teacherDetailLocation(
                            code: teacherInfo.code, name: teacherInfo.name),
                        extra: TeacherDetailArgs(
                          code: teacherInfo.code,
                          name: teacherInfo.name,
                        ),
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

/// Opens this teacher's full day-by-day schedule.
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
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (icon != null) ...[
                Icon(icon, color: AppColors.primary, size: AppSpacing.iconSm),
                const SizedBox(width: 4),
              ],
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
          ),
        ),
      ],
    );
  }
}
