import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/core/router/route_names.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/shared/utils/nav_utils.dart';

class RoleSelectionScreen extends StatefulWidget {
  final AuthController authController;

  const RoleSelectionScreen({super.key, required this.authController});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String? _selectedRole;

  static const _roles = [
    (
      id: 'student',
      label: 'Student',
      subtitle: 'View routine, submit assignments, use AI assistant',
      icon: PhosphorIconsRegular.graduationCap,
      color: AppColors.roleStudent,
    ),
    (
      id: 'teacher',
      label: 'Teacher',
      subtitle: 'Manage your classes and send notifications',
      icon: PhosphorIconsRegular.chalkboardTeacher,
      color: AppColors.roleTeacher,
    ),
    (
      id: 'admin',
      label: 'Admin',
      subtitle: 'Manage users, resources, and timetables',
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
        title: 'Admin Access',
        message: 'Admin accounts are created directly by the department head. '
            'Contact your department admin to get access.',
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
      title: 'Teacher Access',
      message: 'Teacher accounts are added by the department admin. Ask them '
          'to add the email you signed in with, then choose Teacher again.',
    );
  }

  void _showAccessInfo({required String title, required String message}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXlD),
        ),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: AppSpacing.radiusFull,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const Icon(
              PhosphorIconsRegular.info,
              color: AppColors.primary,
              size: 36,
            ),
            AppSpacing.lgGap,
            Text(title, style: AppTextStyles.h3),
            AppSpacing.smGap,
            Text(
              message,
              style: AppTextStyles.bodySm,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.x3l),
            SizedBox(
              width: double.infinity,
              height: AppSpacing.buttonHeight,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppSpacing.radiusMd,
                  ),
                  elevation: 0,
                ),
                child: Text('Got it', style: AppTextStyles.button),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          onPressed: _back,
        ),
        title: Text('Create account', style: AppTextStyles.h2),
      ),
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSpacing.lgGap,

              Text('I am a', style: AppTextStyles.label),

              AppSpacing.smGap,

              Text(
                'Select your role to continue',
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
                    onTap: () => setState(() => _selectedRole = role.id),
                  ),
                );
              }),

              const Spacer(),

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
      ),
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isSelected
            ? color.withValues(alpha: 0.08)
            : AppColors.bgCard,
        borderRadius: AppSpacing.radiusLg,
        border: Border.all(
          color: isSelected ? color : AppColors.border,
          width: isSelected
              ? AppSpacing.borderThick
              : AppSpacing.borderNormal,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppSpacing.radiusLg,
          child: Padding(
            padding: AppSpacing.cardPadding,
            child: Row(
              children: [
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
                  duration: const Duration(milliseconds: 200),
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
    );
  }
}
