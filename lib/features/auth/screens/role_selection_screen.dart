import 'package:universe/features/auth/widgets/auth_responsive_shell.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/core/router/route_names.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/shared/utils/nav_utils.dart';
import 'package:universe/shared/widgets/u_adaptive_overlay.dart';

class RoleSelectionScreen extends StatefulWidget {
  final AuthController authController;

  const RoleSelectionScreen({super.key, required this.authController});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String? _selectedRole;

  // PHASE 0: Role copy reflects implemented capabilities, without AI or assignments.
  static const _roles = [
    (
      id: 'student',
      label: 'Student',
      subtitle: 'View routines, find rooms and faculty, receive cohort alerts',
      icon: PhosphorIconsRegular.graduationCap,
      color: AppColors.roleStudent,
    ),
    (
      id: 'teacher',
      label: 'Teacher',
      subtitle:
          'View teaching routines, post class cancellations and broadcasts',
      icon: PhosphorIconsRegular.chalkboardTeacher,
      color: AppColors.roleTeacher,
    ),
    (
      id: 'admin',
      label: 'Admin',
      subtitle: 'Generate departmental timetables, manage users and resources',
      icon: PhosphorIconsRegular.star,
      color: AppColors.roleAdmin,
    ),
  ];

  // The router keeps a signed-in user with no profile on the registration
  // screens, so "back" has to end that session. Otherwise there is no way out,
  // e.g. to pick a different Google account.
  Future<void> _back() async {
    if (widget.authController.status == AuthStatus.registering) {
      await widget.authController.signOut();
    }
    if (mounted) context.backOr(RouteNames.login);
  }

  Future<void> _proceed() async {
    if (_selectedRole == null) return;

    if (_selectedRole == 'student') {
      context.push(RouteNames.studentRegister);
    } else if (_selectedRole == 'teacher') {
      await _proceedAsTeacher();
    } else {
      _showAccessInfo(
        title: 'Admin Access Required',
        badge: 'GOVERNANCE & ENGINE',
        accent: AppColors.roleAdmin,
        icon: PhosphorIconsRegular.shieldCheck,
        message: 'Administrative accounts are provisioned directly by your '
            'department head. Contact your department administrator to have '
            'your university email added to the admin whitelist.',
      );
    }
  }

  // Teacher accounts need a whitelist entry (migration 016). A signed-in user
  // who is still here has no profile, so they were not whitelisted when they
  // signed in. Check again in case the admin has added them since; otherwise
  // say so now, not after a form they cannot submit.
  Future<void> _proceedAsTeacher() async {
    final auth = widget.authController;
    if (!auth.hasSession) {
      context.push(RouteNames.facultyRegister);
      return;
    }
    await auth.handleOAuthCallback();
    if (!mounted || auth.status != AuthStatus.registering) return;
    _showAccessInfo(
      title: 'Faculty Whitelist Required',
      badge: 'TEACHING & CLASS TOOLS',
      accent: AppColors.roleTeacher,
      icon: PhosphorIconsRegular.chalkboardTeacher,
      message: 'Teacher accounts must be pre-registered by the department '
          'administrator. Ask them to add the email you signed in with, '
          'then select Teacher again.',
    );
  }

  void _showAccessInfo({
    required String title,
    required String badge,
    required Color accent,
    required IconData icon,
    required String message,
  }) {
    showUAdaptiveModal<void>(
      context: context,
      title: title,
      badge: badge,
      accentColor: accent,
      icon: icon,
      maxDesktopWidth: 460,
      builder: (overlayContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.bgSubtle,
              borderRadius: AppSpacing.radiusMd,
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  PhosphorIconsRegular.info,
                  color: accent,
                  size: AppSpacing.iconMd,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    message,
                    style: AppTextStyles.bodySm.copyWith(height: 1.45),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            height: AppSpacing.buttonHeight,
            child: ElevatedButton(
              onPressed: () => Navigator.of(overlayContext).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnPrimary,
                shape: const RoundedRectangleBorder(
                  borderRadius: AppSpacing.radiusMd,
                ),
                elevation: 0,
              ),
              child: Text(
                'Understood',
                style: AppTextStyles.button.copyWith(
                  color: AppColors.textOnPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: // PHASE 3: Adaptive auth presentation preserves existing form and callback ownership.
          AuthResponsiveShell(
              title: 'Create account',
              onBack: _back,
              stage: _selectedRole == 'admin'
                  ? 0
                  : _selectedRole != null
                      ? 1
                      : 2,
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppSpacing.lgGap,
                      Text('I am a', style: AppTextStyles.label),
                      AppSpacing.smGap,
                      Text(
                        'Choose your role intent. Faculty and Admin access is governed by the department whitelist.',
                        style: AppTextStyles.bodySm,
                      ),
                      const SizedBox(height: AppSpacing.x3l),
                      ...List.generate(_roles.length, (i) {
                        final role = _roles[i];
                        final isSelected = _selectedRole == role.id;

                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: i < _roles.length - 1 ? AppSpacing.md : 0,
                          ),
                          child: _RoleCard(
                            label: role.label,
                            subtitle: role.subtitle,
                            icon: role.icon,
                            color: role.color,
                            isSelected: isSelected,
                            onTap: () =>
                                setState(() => _selectedRole = role.id),
                          ),
                        );
                      }),
                      const SizedBox(height: AppSpacing.xxl),
                      SizedBox(
                        width: double.infinity,
                        height: AppSpacing.buttonHeight,
                        child: ElevatedButton(
                          onPressed: _selectedRole != null ? _proceed : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            disabledBackgroundColor: AppColors.bgElevated,
                            shape: const RoundedRectangleBorder(
                              borderRadius: AppSpacing.radiusMd,
                            ),
                            elevation: 0,
                          ),
                          child: Text('Continue', style: AppTextStyles.button),
                        ),
                      ),
                      AppSpacing.lgGap,
                    ],
                  ),
                ),
              )),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // PHASE 3: Role intent selection remains available with motion disabled.
    return RepaintBoundary(
        child: AnimatedContainer(
      duration: (MediaQuery.maybeOf(context)?.disableAnimations ?? false)
          ? Duration.zero
          : const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isSelected ? color.withValues(alpha: 0.08) : AppColors.bgCard,
        borderRadius: AppSpacing.radiusLg,
        border: Border.all(
          color: isSelected ? color : AppColors.border,
          width: isSelected ? AppSpacing.borderThick : AppSpacing.borderNormal,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          hoverColor: color.withValues(alpha: .08),
          focusColor: color.withValues(alpha: .14),
          borderRadius: AppSpacing.radiusLg,
          child: Padding(
            padding: AppSpacing.cardPadding,
            child: Row(
              children: [
                Container(width: 3, height: 56, color: color),
                const SizedBox(width: 12),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: AppSpacing.radiusMd,
                  ),
                  child: Icon(icon, color: color, size: AppSpacing.iconLg),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: AppTextStyles.h4),
                      const SizedBox(height: 6),
                      Text(
                          label == 'Student'
                              ? 'COHORT ROUTINE'
                              : label == 'Teacher'
                                  ? 'TEACHING & CLASS TOOLS'
                                  : 'ENGINE & GOVERNANCE',
                          style: AppTextStyles.caption.copyWith(color: color)),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTextStyles.bodySm.copyWith(
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedOpacity(
                  opacity: isSelected ? 1.0 : 0.0,
                  duration:
                      (MediaQuery.maybeOf(context)?.disableAnimations ?? false)
                          ? Duration.zero
                          : const Duration(milliseconds: 200),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ));
  }
}
