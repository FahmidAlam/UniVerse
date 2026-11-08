import 'package:flutter/material.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_motion.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/shared/widgets/u_animated_swap.dart';

/// Presents the signup/recovery forms' existing rules; adds no password policy.
class PasswordRequirements extends StatelessWidget {
  const PasswordRequirements(
      {super.key, required this.password, required this.confirmation});
  final String password;
  final String confirmation;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          _requirement(context, 'At least 6 characters', password.length >= 6),
          _requirement(context, 'Passwords match',
              confirmation.isNotEmpty && confirmation == password),
        ],
      );

  Widget _requirement(BuildContext context, String label, bool satisfied) {
    final pill = Row(mainAxisSize: MainAxisSize.min, children: [
      UAnimatedSwap(
          child: Icon(
        satisfied
            ? Icons.check_circle_outline
            : Icons.radio_button_unchecked,
        key: ValueKey(satisfied),
        size: AppSpacing.iconSm,
        color: satisfied ? AppColors.success : AppColors.textMuted,
      )),
      const SizedBox(width: AppSpacing.xs),
      Text(label,
          style: AppTextStyles.caption.copyWith(
              color: satisfied ? AppColors.success : AppColors.textMuted)),
    ]);
    final decoration = BoxDecoration(
      color: satisfied ? AppColors.successSoft : AppColors.bgElevated,
      borderRadius: AppSpacing.radiusSm,
    );
    const padding = EdgeInsets.symmetric(
        horizontal: AppSpacing.sm, vertical: AppSpacing.xs);
    return Semantics(
      label: '$label: ${satisfied ? 'satisfied' : 'not yet satisfied'}',
      child: ExcludeSemantics(
        child: AppMotion.reduced(context)
            ? Container(padding: padding, decoration: decoration, child: pill)
            : AnimatedContainer(
                duration: AppMotion.fast,
                curve: AppMotion.snappy,
                padding: padding,
                decoration: decoration,
                child: pill,
              ),
      ),
    );
  }
}
