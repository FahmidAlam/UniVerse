import 'package:flutter/material.dart';
import 'package:universe_v1/core/theme/app_colors.dart';
import 'package:universe_v1/core/theme/app_spacing.dart';
import 'package:universe_v1/core/theme/app_text_styles.dart';

enum UButtonVariant { primary, secondary, danger }

class UButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final UButtonVariant variant;
  final bool isLoading;
  final IconData? icon;
  final bool fullWidth;
  final double? height;

  const UButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = UButtonVariant.primary,
    this.isLoading = false,
    this.icon,
    this.fullWidth = true,
    this.height,
  });

  bool get _isDisabled => onPressed == null || isLoading;

  Decoration _buildDecoration() {
    switch (variant) {
      case UButtonVariant.primary:
        return BoxDecoration(
          gradient: _isDisabled ? null : AppColors.primaryGradient,
          color: _isDisabled ? AppColors.bgElevated : null,
          borderRadius: AppSpacing.radiusMd,
        );
      case UButtonVariant.secondary:
        return BoxDecoration(
          color: Colors.transparent,
          borderRadius: AppSpacing.radiusMd,
          border: Border.all(
            color: _isDisabled ? AppColors.textDisabled : AppColors.border,
          ),
        );
      case UButtonVariant.danger:
        return BoxDecoration(
          color: _isDisabled ? AppColors.bgElevated : AppColors.error,
          borderRadius: AppSpacing.radiusMd,
        );
    }
  }

  Color get _contentColor {
    if (_isDisabled) return AppColors.textDisabled;
    return AppColors.textPrimary;
  }

  @override
  Widget build(BuildContext context) {
    final double btnHeight = height ?? AppSpacing.buttonHeight;

    final Widget content = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(_contentColor),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: AppSpacing.iconMd, color: _contentColor),
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(
                label,
                style: AppTextStyles.button.copyWith(color: _contentColor),
              ),
            ],
          );

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: btnHeight,
      child: DecoratedBox(
        decoration: _buildDecoration(),
        child: Material(
          color: Colors.transparent,
          borderRadius: AppSpacing.radiusMd,
          child: InkWell(
            onTap: _isDisabled ? null : onPressed,
            borderRadius: AppSpacing.radiusMd,
            splashColor: AppColors.withOpacity(AppColors.textPrimary, 0.08),
            highlightColor: AppColors.withOpacity(AppColors.textPrimary, 0.04),
            child: Center(child: content),
          ),
        ),
      ),
    );
  }
}
