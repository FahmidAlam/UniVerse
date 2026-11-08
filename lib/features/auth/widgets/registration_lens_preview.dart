import 'package:flutter/material.dart';
import 'package:universe/core/theme/app_motion.dart';
import 'package:universe/shared/widgets/u_animated_swap.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_text_styles.dart';

// PHASE 3: Input-derived lens explanation; no schedule lookup is performed.
class RegistrationLensPreview extends StatelessWidget {
  const RegistrationLensPreview(
      {super.key, required this.child, this.faculty = false, this.identity});
  final Widget child;
  final bool faculty;
  final Object? identity;
  @override
  Widget build(BuildContext context) {
    final accent = faculty ? AppColors.info : AppColors.primary;
    final card = Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.instrumentTop,
                  AppColors.instrumentBottom
                ]),
            borderRadius: BorderRadius.circular(12),
            border: Border(left: BorderSide(color: accent, width: 3))),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(
                faculty
                    ? Icons.badge_outlined
                    : Icons.calendar_month_outlined,
                color: accent,
                size: 20),
            const SizedBox(width: 12),
            Expanded(
                child: UAnimatedSwap(
                    child: KeyedSubtree(
                        key: ValueKey(identity ?? faculty), child: child)))
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final label in [
              faculty ? 'TEACHING SLOTS' : 'SECTION SCHEDULE',
              'LIVE ALERTS & ROOMS'
            ])
              Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: accent.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(label,
                      style:
                          AppTextStyles.caption.copyWith(color: accent))),
          ])
        ]));
    if (AppMotion.reduced(context)) return card;
    return AnimatedSize(
        duration: AppMotion.medium,
        curve: AppMotion.snappy,
        alignment: Alignment.topCenter,
        child: card);
  }
}
