import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universe/core/router/route_names.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';

class NotWhitelistedScreen extends StatelessWidget {
  final AuthController authController;

  const NotWhitelistedScreen({super.key, required this.authController});

  @override
  Widget build(BuildContext context) {
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.errorSoft,
                  borderRadius: AppSpacing.radiusXl,
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.3),
                  ),
                ),
                child: const Icon(
                  PhosphorIconsRegular.lockSimple,
                  color: AppColors.error,
                  size: 40,
                ),
              ),

              const SizedBox(height: AppSpacing.x3l),

              Text('Access Required', style: AppTextStyles.h2),

              AppSpacing.lgGap,

              Text(
                'This account has not been added as a teacher or admin.',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),

              AppSpacing.smGap,

              if (email.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.bgElevated,
                    borderRadius: AppSpacing.radiusMd,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    email,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ),

              AppSpacing.lgGap,

              Text(
                'Teacher and admin accounts are added by your department '
                'admin. Ask them to add this email, then sign in again.',
                style: AppTextStyles.bodySm,
                textAlign: TextAlign.center,
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: AppSpacing.buttonHeight,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await authController.signOut();
                    if (context.mounted) context.go(RouteNames.login);
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.border),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppSpacing.radiusMd,
                    ),
                  ),
                  icon: const Icon(
                    PhosphorIconsRegular.signOut,
                    size: AppSpacing.iconMd,
                  ),
                  label: Text(
                    'Sign out and try another account',
                    style: AppTextStyles.button,
                  ),
                ),
              ),

              AppSpacing.lgGap,
            ],
          ),
        ),
      ),
    );
  }
}
