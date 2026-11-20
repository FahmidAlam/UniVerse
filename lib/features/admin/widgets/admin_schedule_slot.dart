import 'package:flutter/material.dart';
import 'package:universe/core/models/routine_model.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/core/utils/room_identity.dart';
import 'package:universe/shared/widgets/u_pressable_scale.dart';

/// Phase 5: one academic slot vocabulary for operational and preview workbenches.
class AdminScheduleSlot extends StatelessWidget {
  final RoutineEntry entry;
  final VoidCallback? onTap;
  final Map<String, String> roomAliases;
  final bool selected;
  const AdminScheduleSlot(
      {super.key,
      required this.entry,
      this.onTap,
      this.roomAliases = const {},
      this.selected = false});

  static Color accentFor(RoutineEntry entry) => entry.teacherCodes.length > 1 ||
          entry.section.contains('+')
      ? AppColors.info
      : RegExp(r'lab|sessional', caseSensitive: false).hasMatch(entry.subject)
          ? AppColors.success
          : AppColors.primary;

  @override
  Widget build(BuildContext context) {
    final accent = accentFor(entry);
    final room = RoomIdentity.key(entry.room, aliases: roomAliases);
    return UPressableScale(
      enabled: onTap != null,
      child: Material(
        color: selected ? AppColors.surfaceInteractive : AppColors.bgCard,
        shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.radiusSm,
            side: BorderSide(color: selected ? accent : AppColors.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
                border: Border(left: BorderSide(color: accent, width: 3))),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(entry.subjectCode,
                      style: AppTextStyles.h4,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: AppSpacing.xs),
                  Text('${entry.day} · ${entry.timeLabel}',
                      style: AppTextStyles.timeCode, maxLines: 2),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        _tag('Batch ${entry.batch} · ${entry.section}',
                            AppColors.textSecondary),
                        for (final teacher in entry.teacherCodes)
                          _tag(teacher, AppColors.info),
                        if (entry.teacherCodes.isEmpty)
                          _tag(entry.teacherDisplay, AppColors.textMuted),
                        Tooltip(
                            message: room == entry.room
                                ? 'Assigned room'
                                : '${entry.room} → $room',
                            child: _tag(room == entry.room ? room : '$room ↗',
                                AppColors.success)),
                      ]),
                ]),
          ),
        ),
      ),
    );
  }

  Widget _tag(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: AppSpacing.radiusSm),
        child: Text(label,
            style: AppTextStyles.captionMedium.copyWith(color: color)),
      );
}
