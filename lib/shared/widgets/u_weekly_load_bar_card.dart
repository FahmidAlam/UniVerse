import 'package:flutter/material.dart';
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_motion.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/shared/widgets/u_card.dart';

/// PHASE 4 / C: High-craft, unslop 7-Day Weekly Load Mini-Bar Card.
/// Visualizes class distribution across all 7 operational days (Sun–Sat)
/// without generic 3-box KPI slop, highlighting Today in Primary Orange
/// and calmly indicating academic off-days.
class UWeeklyLoadBarCard extends StatelessWidget {
  final String title;
  final Map<String, int> dailyCounts;
  final String todayShort;
  final VoidCallback? onTap;

  const UWeeklyLoadBarCard({
    super.key,
    required this.title,
    required this.dailyCounts,
    required this.todayShort,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final days = AppConstants.weekDaysShort;
    final fullDays = AppConstants.weekDays;
    final totalClasses =
        dailyCounts.values.fold<int>(0, (sum, val) => sum + val);
    final rawMax = dailyCounts.values.isEmpty
        ? 1
        : dailyCounts.values.reduce((a, b) => a > b ? a : b);
    final maxVal = rawMax < 1 ? 1 : rawMax;
    final reduced = AppMotion.reduced(context);

    return Semantics(
      container: true,
      button: onTap != null,
      label: '$title: $totalClasses scheduled classes per week',
      child: UCard(
        isTopLit: true,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: AppTextStyles.labelCaps.copyWith(
                      color: AppColors.textSecondary,
                      letterSpacing: 0.6,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$totalClasses',
                      style: AppTextStyles.numeric.copyWith(
                        color: AppColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'classes / wk',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 76,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < days.length; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(
                      child: _buildDayColumn(
                        context,
                        day: days[i],
                        fullDay: i < fullDays.length ? fullDays[i] : days[i],
                        count: dailyCounts[days[i]] ?? 0,
                        isToday: days[i] == todayShort,
                        maxVal: maxVal,
                        reduced: reduced,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayColumn(
    BuildContext context, {
    required String day,
    required String fullDay,
    required int count,
    required bool isToday,
    required int maxVal,
    required bool reduced,
  }) {
    const maxBarHeight = 32.0;
    final barHeight = count > 0
        ? (count / maxVal * maxBarHeight).clamp(6.0, maxBarHeight)
        : 3.0;

    final barColor = isToday
        ? AppColors.primary
        : (count > 0 ? AppColors.surfaceInteractive : AppColors.border);

    final tooltipLabel =
        '$fullDay${isToday ? ' (Today)' : ''}: ${count == 0 ? 'Off / Free' : '$count ${count == 1 ? 'class' : 'classes'}'}';

    return Tooltip(
      message: tooltipLabel,
      child: Semantics(
        label: tooltipLabel,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              count > 0 ? '$count' : '—',
              style: AppTextStyles.numeric.copyWith(
                fontSize: 11,
                fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                color: isToday
                    ? AppColors.primary
                    : (count > 0 ? AppColors.textPrimary : AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration:
                  reduced ? Duration.zero : const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              height: barHeight,
              width: double.infinity,
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(2),
                boxShadow: isToday
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
              decoration: isToday
                  ? BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(3),
                    )
                  : null,
              child: Text(
                day,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 10,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                  color: isToday ? AppColors.primary : AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
