import 'package:flutter/material.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';

class UTextField extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppTextStyles.label),
        AppSpacing.smGap,
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          enabled: enabled,
          maxLines: obscureText ? 1 : maxLines,
          maxLength: maxLength,
          style: AppTextStyles.input,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted != null ? (_) => onSubmitted!() : null,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.placeholder,
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, size: AppSpacing.iconMd)
                : null,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: enabled ? AppColors.bgElevated : AppColors.bgSubtle,
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            border: OutlineInputBorder(
              borderRadius: AppSpacing.radiusMd,
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppSpacing.radiusMd,
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppSpacing.radiusMd,
              borderSide: const BorderSide(
                color: AppColors.borderFocus,
                width: AppSpacing.borderThick,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: AppSpacing.radiusMd,
              borderSide: const BorderSide(color: AppColors.border),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: AppSpacing.radiusMd,
              borderSide: const BorderSide(color: AppColors.borderError),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: AppSpacing.radiusMd,
              borderSide: const BorderSide(
                color: AppColors.borderError,
                width: AppSpacing.borderThick,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
