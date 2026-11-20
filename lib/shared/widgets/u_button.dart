import 'package:flutter/material.dart';
import 'package:universe/core/theme/app_motion.dart';
import 'package:universe/shared/widgets/u_pressable_scale.dart';
import 'package:universe/shared/widgets/u_animated_swap.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';

// PHASE 2: Shared button variants aligned to Obsidian Orbit design tokens.
enum UButtonVariant { primary, secondary, danger }

// PHASE 2: Unified UButton with high-contrast Obsidian Orbit surface treatment,
// explicit hover/focus/pressed/disabled states, top specular highlight, and reduced motion respect.
class UButton extends StatefulWidget {
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

  @override
  State<UButton> createState() => _UButtonState();
}

class _UButtonState extends State<UButton> {
  bool _isHovered = false;
  bool _isPressed = false;
  bool _isFocused = false;

  bool get _isDisabled => widget.onPressed == null || widget.isLoading;

  Color get _backgroundColor {
    if (_isDisabled) return AppColors.surfaceElevated;

    switch (widget.variant) {
      case UButtonVariant.primary:
        if (_isPressed) return AppColors.primaryPressed;
        if (_isHovered) return AppColors.primaryHover;
        return AppColors.primary;
      case UButtonVariant.secondary:
        if (_isPressed) return AppColors.surfaceInteractive;
        if (_isHovered) return AppColors.surfaceElevated;
        return Colors.transparent;
      case UButtonVariant.danger:
        if (_isPressed) return const Color(0xFFDC2626);
        if (_isHovered) return const Color(0xFFF87171);
        return AppColors.error;
    }
  }

  Color get _contentColor {
    if (_isDisabled) return AppColors.textDisabled;

    switch (widget.variant) {
      case UButtonVariant.primary:
        // PHASE 2 (PROVISIONAL): High contrast dark foreground on primary orange (7.5:1 contrast).
        return AppColors.textOnPrimary;
      case UButtonVariant.secondary:
        return AppColors.textPrimary;
      case UButtonVariant.danger:
        return AppColors.textPrimary;
    }
  }

  Border? get _border {
    if (_isFocused) {
      return Border.all(color: AppColors.borderFocus, width: 2.0);
    }
    if (widget.variant == UButtonVariant.secondary) {
      return Border.all(
        color: _isDisabled ? AppColors.textDisabled : AppColors.border,
        width: AppSpacing.borderThin,
      );
    }
    if (_isDisabled) {
      return Border.all(
        color: AppColors.border,
        width: AppSpacing.borderThin,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final double btnHeight = widget.height ?? AppSpacing.buttonHeight;
    final bool isCompact = btnHeight <= 40;
    // Optical horizontal padding >= 2x vertical padding
    final double hPadding = isCompact ? AppSpacing.lg : AppSpacing.xxl;
    final double vPadding = isCompact ? AppSpacing.sm : AppSpacing.md;

    final Widget labelWidget = Flexible(
      child: Text(
        widget.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.button.copyWith(
          color: _contentColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    final Widget content = widget.isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(_contentColor),
              value: AppMotion.reduced(context) ? 0.75 : null,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon,
                    size: AppSpacing.iconMd, color: _contentColor),
                const SizedBox(width: AppSpacing.sm),
              ],
              labelWidget,
            ],
          );

    final bool showTopHighlight =
        widget.variant != UButtonVariant.danger && !_isDisabled;

    return FocusableActionDetector(
      onShowFocusHighlight: (v) => setState(() => _isFocused = v),
      onShowHoverHighlight: (v) => setState(() => _isHovered = v),
      child: UPressableScale(
        enabled: !_isDisabled,
        child: AnimatedContainer(
          duration: AppMotion.duration(context, AppMotion.micro),
          curve: AppMotion.snappy,
          width: widget.fullWidth ? double.infinity : null,
          height: btnHeight,
          decoration: BoxDecoration(
            color: _backgroundColor,
            borderRadius: AppSpacing.radiusMd,
            border: _border,
          ),
          child: ClipRRect(
            borderRadius: AppSpacing.radiusMd,
            child: Stack(
              children: [
                // PHASE 2 (PROVISIONAL): Subtle top-edge specular highlight on primary buttons
                if (showTopHighlight)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 1,
                    child: Container(
                      color: AppColors.specular,
                    ),
                  ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isDisabled ? null : widget.onPressed,
                    onHighlightChanged: (v) => setState(() => _isPressed = v),
                    borderRadius: AppSpacing.radiusMd,
                    splashColor: AppColors.withOpacity(
                      widget.variant == UButtonVariant.primary
                          ? AppColors.textOnPrimary
                          : AppColors.textPrimary,
                      0.08,
                    ),
                    highlightColor: AppColors.withOpacity(
                      widget.variant == UButtonVariant.primary
                          ? AppColors.textOnPrimary
                          : AppColors.textPrimary,
                      0.04,
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: hPadding,
                        vertical: vPadding,
                      ),
                      child: Center(
                          child: UAnimatedSwap(
                              duration: AppMotion.fast,
                              child: KeyedSubtree(
                                  key: ValueKey((
                                    widget.isLoading,
                                    widget.label,
                                    widget.icon
                                  )),
                                  child: content))),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
