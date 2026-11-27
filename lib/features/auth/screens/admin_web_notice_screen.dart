import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:universe/core/router/route_names.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/features/auth/widgets/auth_responsive_shell.dart';
import 'package:universe/features/auth/widgets/orbit_status.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/shared/widgets/u_button.dart';
import 'package:universe/shared/widgets/u_card.dart';

class AdminWebNoticeScreen extends StatelessWidget {
  static const String webConsoleUrl = 'https://universe-admin-exi.pages.dev';

  final AuthController authController;

  const AdminWebNoticeScreen({super.key, required this.authController});

  @override
  Widget build(BuildContext context) {
    final email = authController.profile?['email'] as String? ?? '';

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: AuthResponsiveShell(
        child: SafeArea(
          child: UCard(
            isTopLit: true,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: AppSpacing.xl),
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: AppSpacing.radiusXl,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: const OrbitStatus(
                    color: AppColors.primary,
                    child: Icon(
                      PhosphorIconsRegular.globe,
                      color: AppColors.primary,
                      size: 38,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                Text(
                  'Admin Operations Moved to Web',
                  style: AppTextStyles.h2,
                  textAlign: TextAlign.center,
                ),
                AppSpacing.mdGap,
                Text(
                  'Timetable generation, Course Distribution, Policy Studio, '
                  'and version rollback now run exclusively in the UniVerse '
                  'React Web Admin Console.',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                AppSpacing.lgGap,
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.bgElevated,
                    borderRadius: AppSpacing.radiusMd,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      SelectableText(
                        webConsoleUrl,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (email.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Signed in as $email',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                UButton(
                  label: 'Copy Console URL',
                  icon: PhosphorIconsRegular.copy,
                  variant: UButtonVariant.secondary,
                  onPressed: () async {
                    await Clipboard.setData(
                      const ClipboardData(text: webConsoleUrl),
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Copied Admin Console URL'),
                      ),
                    );
                  },
                ),
                AppSpacing.mdGap,
                SizedBox(
                  width: double.infinity,
                  height: AppSpacing.buttonHeight,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await authController.signOut();
                      if (context.mounted) {
                        context.go(RouteNames.login);
                      }
                    },
                    icon: const Icon(PhosphorIconsRegular.signOut),
                    label: const Text('Sign Out'),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
