import 'package:flutter/material.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';

class UCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final Color? color;
  final Border? border;

  const UCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.onTap,
    this.color,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = borderRadius ?? AppSpacing.radiusLg;
    final EdgeInsets pad = padding ?? AppSpacing.cardPadding;
    final Color bg = color ?? AppColors.bgCard;
    final BoxDecoration decoration = BoxDecoration(
      color: bg,
      borderRadius: radius,
      border: border ??
          Border.all(
            color: AppColors.border,
            width: AppSpacing.borderThin,
          ),
    );

    if (onTap != null) {
      return Container(
        margin: margin,
        decoration: decoration,
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            splashColor: AppColors.withOpacity(AppColors.textPrimary, 0.04),
            highlightColor: AppColors.withOpacity(AppColors.textPrimary, 0.02),
            child: Padding(padding: pad, child: child),
          ),
        ),
      );
    }

    return Container(
      margin: margin,
      padding: pad,
      decoration: decoration,
      child: child,
    );
  }
}
