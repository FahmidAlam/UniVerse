import 'package:flutter/material.dart';
import 'package:universe/core/theme/app_motion.dart';
import 'package:universe/shared/widgets/u_pressable_scale.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';

// PHASE 2: Interactive filter chip with >= 36px touch height, dimmed semantic container fills,
// and high-contrast foreground text/icons.
class UChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final IconData? icon;

  const UChip({
    super.key,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final Color bgColor =
        isActive ? AppColors.primarySoft : AppColors.surfaceElevated;
    final Color borderColor =
        isActive ? AppColors.primary.withValues(alpha: 0.6) : AppColors.border;
    final Color foregroundColor =
        isActive ? AppColors.primary : AppColors.textMuted;

    return Semantics(
      button: true,
      selected: isActive,
      label: label,
      child: UPressableScale(
          child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: AppSpacing.radiusFull,
                onTap: () {
                  AppMotion.selectionHaptic(context);
                  onTap();
                },
                child: AnimatedContainer(
                  duration: AppMotion.duration(context, AppMotion.fast),
                  curve: AppMotion.snappy,
                  height: MediaQuery.sizeOf(context).width < 768 ? 48 : 40,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.chipPaddingH),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: AppSpacing.radiusFull,
                    border: Border.all(
                      color: borderColor,
                      width: AppSpacing.borderThin,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(
                          icon,
                          size: AppSpacing.iconSm,
                          color: foregroundColor,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                      ],
                      Text(
                        label,
                        style: AppTextStyles.chip.copyWith(
                          color: foregroundColor,
                          fontWeight:
                              isActive ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ))),
    );
  }
}
