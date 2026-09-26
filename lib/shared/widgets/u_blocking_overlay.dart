import 'package:flutter/material.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';

/// Full-screen, non-dismissible progress overlay with a short [message].
///
/// Sits above the router (see `UniVerseApp.builder`), so it has no
/// [Material] ancestor of its own and provides one.
class UBlockingOverlay extends StatelessWidget {
  final String message;

  const UBlockingOverlay({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          ModalBarrier(
            dismissible: false,
            color: AppColors.bgPrimary.withValues(alpha: 0.75),
          ),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xxl,
                vertical: AppSpacing.xl,
              ),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: AppSpacing.radiusLg,
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: AppSpacing.iconMd,
                    height: AppSpacing.iconMd,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(message, style: AppTextStyles.bodyMedium),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
