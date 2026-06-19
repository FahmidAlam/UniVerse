import 'package:flutter/material.dart';
import 'package:universe/core/constants/app_enums.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/core/utils/date_utils.dart';

class NotificationTile extends StatelessWidget {
  final String title;
  final String body;
  final NotifType type;
  final DateTime time;
  final bool isRead;
  final VoidCallback? onTap;

  const NotificationTile({
    super.key,
    required this.title,
    required this.body,
    required this.type,
    required this.time,
    this.isRead = false,
    this.onTap,
  });

  Color get _borderColor {
    switch (type) {
      case NotifType.classCancel:
        return AppColors.notifCancel;
      case NotifType.testReminder:
        return AppColors.notifTest;
      case NotifType.exam:
        return AppColors.notifExam;
      case NotifType.roomChange:
        return AppColors.notifRoom;
      case NotifType.university:
        return AppColors.notifHoliday;
      case NotifType.assignment:
        return AppColors.notifAssign;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isRead ? AppColors.bgSubtle : AppColors.bgCard,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: AppSpacing.notifTileH),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: _borderColor,
                width: AppSpacing.borderAccent,
              ),
              bottom: const BorderSide(
                color: AppColors.border,
                width: AppSpacing.borderThin,
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: isRead
                          ? AppTextStyles.bodyMedium
                              .copyWith(color: AppColors.textSecondary)
                          : AppTextStyles.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      body,
                      style: AppTextStyles.bodySm,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                AppDateUtils.formatRelativeTime(time),
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
