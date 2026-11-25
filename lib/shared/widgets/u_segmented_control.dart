import 'package:flutter/material.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_motion.dart';
import 'package:universe/shared/widgets/u_pressable_scale.dart';

class USegment<T> {
  final T value;
  final String label;
  final IconData? icon;
  final bool enabled;
  const USegment(
      {required this.value,
      required this.label,
      this.icon,
      this.enabled = true});
}

/// Equal-width, keyboard-accessible destinations with a sliding selection thumb.
class USegmentedControl<T> extends StatelessWidget {
  final List<USegment<T>> segments;
  final T selected;
  final ValueChanged<T>? onChanged;
  final bool compact;
  final Color accentColor;
  const USegmentedControl(
      {super.key,
      required this.segments,
      required this.selected,
      required this.onChanged,
      this.compact = false,
      this.accentColor = AppColors.primary})
      : assert(segments.length > 0);

  @override
  Widget build(BuildContext context) {
    final selectedIndex =
        segments.indexWhere((segment) => segment.value == selected);
    final height = MediaQuery.sizeOf(context).width < 768
        ? 48.0
        : compact
            ? 40.0
            : 48.0;
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.hasBoundedWidth
          ? constraints.maxWidth
          : segments.length * 140.0;
      final slot = (width - 8) / segments.length;
      return Container(
        width: width,
        height: height + 8,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: AppColors.bgPrimary,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border)),
        child: Stack(children: [
          if (selectedIndex >= 0)
            AnimatedPositionedDirectional(
              duration: AppMotion.duration(context, AppMotion.fast),
              curve: AppMotion.snappy,
              start: slot * selectedIndex,
              top: 0,
              bottom: 0,
              width: slot,
              child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppColors.cardIdleGradient,
                    borderRadius: BorderRadius.circular(7),
                    border:
                        Border.all(color: accentColor.withValues(alpha: .45)),
                    boxShadow: AppColors.dualElevationShadow,
                  ),
                  child: const Align(
                      alignment: Alignment.topCenter,
                      child: Divider(
                          height: 1, thickness: 1, color: AppColors.specular))),
            ),
          Row(children: [
            for (final segment in segments)
              Expanded(
                child: UPressableScale(
                  enabled: onChanged != null && segment.enabled,
                  child: TextButton(
                    onPressed: onChanged == null || !segment.enabled
                        ? null
                        : () {
                            AppMotion.selectionHaptic(context);
                            onChanged!(segment.value);
                          },
                    style: TextButton.styleFrom(
                      foregroundColor: segment.value == selected
                          ? accentColor
                          : AppColors.textSecondary,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size(0, height),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(7)),
                    ),
                    child: Semantics(
                      selected: segment.value == selected,
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (segment.icon != null) ...[
                              Icon(segment.icon, size: 18),
                              const SizedBox(width: 6)
                            ],
                            Flexible(
                                child: Text(segment.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis)),
                          ]),
                    ),
                  ),
                ),
              )
          ]),
        ]),
      );
    });
  }
}
