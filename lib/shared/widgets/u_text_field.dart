import 'package:flutter/material.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_motion.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';

// PHASE 2: Obsidian Orbit form field with clear focus ring, error, and disabled states.
class UTextField extends StatefulWidget {
  final String label;
  final String hint;
  final TextEditingController? controller;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;
  final bool enabled;
  final int maxLines;
  final int? maxLength;

  const UTextField({
    super.key,
    required this.label,
    required this.hint,
    this.controller,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.maxLines = 1,
    this.maxLength,
  });

  @override
  State<UTextField> createState() => _UTextFieldState();
}

class _UTextFieldState extends State<UTextField> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.label,
          style: AppTextStyles.label.copyWith(color: AppColors.textSecondary),
        ),
        AppSpacing.smGap,
        Focus(
          onFocusChange: (focused) => setState(() => _isFocused = focused),
          child: AnimatedContainer(
            duration: AppMotion.duration(context, AppMotion.fast),
            curve: AppMotion.snappy,
            decoration: BoxDecoration(
              borderRadius: AppSpacing.radiusMd,
              boxShadow: _isFocused && widget.enabled
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.16),
                        blurRadius: 12,
                      ),
                    ]
                  : null,
            ),
            child: TextFormField(
              controller: widget.controller,
              obscureText: widget.obscureText,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              enabled: widget.enabled,
              maxLines: widget.obscureText ? 1 : widget.maxLines,
              maxLength: widget.maxLength,
              style: AppTextStyles.input.copyWith(
                color: widget.enabled
                    ? AppColors.textPrimary
                    : AppColors.textDisabled,
              ),
              onChanged: widget.onChanged,
              onFieldSubmitted: widget.onSubmitted != null
                  ? (_) => widget.onSubmitted!()
                  : null,
              validator: widget.validator,
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: AppTextStyles.placeholder
                    .copyWith(color: AppColors.textMuted),
                prefixIcon: widget.prefixIcon != null
                    ? Icon(widget.prefixIcon,
                        size: AppSpacing.iconMd, color: AppColors.textMuted)
                    : null,
                suffixIcon: widget.suffixIcon,
                filled: true,
                fillColor: AppColors.surfaceSubtle,
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                border: const OutlineInputBorder(
                  borderRadius: AppSpacing.radiusMd,
                  borderSide: BorderSide(
                    color: AppColors.border,
                    width: AppSpacing.borderThin,
                  ),
                ),
                enabledBorder: const OutlineInputBorder(
                  borderRadius: AppSpacing.radiusMd,
                  borderSide: BorderSide(
                    color: AppColors.border,
                    width: AppSpacing.borderThin,
                  ),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: AppSpacing.radiusMd,
                  borderSide: BorderSide(
                    color: AppColors.borderFocus,
                    width: AppSpacing.borderFocus,
                  ),
                ),
                disabledBorder: const OutlineInputBorder(
                  borderRadius: AppSpacing.radiusMd,
                  borderSide: BorderSide(
                    color: AppColors.surfaceSubtle,
                    width: AppSpacing.borderThin,
                  ),
                ),
                errorBorder: const OutlineInputBorder(
                  borderRadius: AppSpacing.radiusMd,
                  borderSide: BorderSide(
                    color: AppColors.borderError,
                    width: AppSpacing.borderThin,
                  ),
                ),
                focusedErrorBorder: const OutlineInputBorder(
                  borderRadius: AppSpacing.radiusMd,
                  borderSide: BorderSide(
                    color: AppColors.borderError,
                    width: AppSpacing.borderFocus,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
