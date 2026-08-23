// ============================================================
// FILE: lib/features/auth/screens/reset_password_screen.dart
// PURPOSE: Shown when the user taps the password reset link
// in their email. The deep link brings them here with
// an active Supabase session. They enter a new password
// and confirm it. Calls authController.updatePassword().
//
// DEEP LINK ENTRY:
// com.example.universe://reset-callback/
// Supabase handles the token exchange automatically.
// GoRouter must handle this route when the app is opened
// via that scheme. Add to AndroidManifest.xml:
//   <data android:scheme="com.example.universe"
//         android:host="reset-callback" />
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/core/router/route_names.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/features/auth/services/auth_service.dart';

class ResetPasswordScreen extends StatefulWidget {
  final AuthController authController;
  const ResetPasswordScreen({super.key, required this.authController});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey        = GlobalKey<FormState>();
  final _passwordCtrl   = TextEditingController();
  final _confirmCtrl    = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm  = true;
  bool _isUpdating      = false;
  bool _resetSuccess    = false;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  int _passwordStrength(String password) {
    if (password.isEmpty) return 0;
    int score = 0;
    if (password.length >= 8) score++;
    if (password.contains(RegExp(r'[A-Z]'))) score++;
    if (password.contains(RegExp(r'[0-9]'))) score++;
    if (password.contains(RegExp(r'[!@#\$%^&*]'))) score++;
    return score;
  }

  Future<void> _signOutAndLogin() async {
    await widget.authController.signOut();
    if (!mounted) return;
    context.go(RouteNames.emailLogin);
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() => _isUpdating = true);

    final result =
        await AuthService().updatePassword(_passwordCtrl.text);

    if (!mounted) return;
    setState(() => _isUpdating = false);

    if (result.success) {
      setState(() => _resetSuccess = true);
    } else {
      _showError(result.errorMessage ?? 'Failed to update password.');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: AppTextStyles.bodySm.copyWith(color: AppColors.textPrimary),
        ),
        backgroundColor: AppColors.bgElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.radiusMd,
          side: const BorderSide(color: AppColors.error),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final passwordStrength = _passwordStrength(_passwordCtrl.text);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        automaticallyImplyLeading: false, // no back — came from email link
        title: Text('New password', style: AppTextStyles.h2),
      ),
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: _resetSuccess
              ? _buildSuccessState()
              : _buildFormState(passwordStrength),
        ),
      ),
    );
  }

  // ── Password form ──────────────────────────────────────────
  Widget _buildFormState(int passwordStrength) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(flex: 2),

          // Icon
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: AppSpacing.radiusXl,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25),
              ),
            ),
            child: const Icon(
              PhosphorIconsRegular.lockKey,
              color: AppColors.primary,
              size: 32,
            ),
          ),

          const SizedBox(height: AppSpacing.x3l),

          Text('Set a new password', style: AppTextStyles.h1),

          AppSpacing.lgGap,

          Text(
            'Choose a strong password for your UniVerse account.',
            style: AppTextStyles.bodySm,
          ),

          const SizedBox(height: AppSpacing.x3l),

          // New password
          Text('New password', style: AppTextStyles.label),
          AppSpacing.smGap,
          TextFormField(
            controller: _passwordCtrl,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            style: AppTextStyles.input,
            onChanged: (_) => setState(() {}),
            decoration: _fieldDecoration(
              hint: 'Min. 8 characters',
              icon: PhosphorIconsRegular.lock,
              suffix: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? PhosphorIconsRegular.eye
                      : PhosphorIconsRegular.eyeSlash,
                  size: AppSpacing.iconMd,
                  color: AppColors.textMuted,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password is required';
              if (v.length < 6) return 'Minimum 6 characters';
              return null;
            },
          ),

          // Strength bar
          if (_passwordCtrl.text.isNotEmpty) ...[
            AppSpacing.smGap,
            _PasswordStrengthBar(strength: passwordStrength),
          ],

          AppSpacing.lgGap,

          // Confirm password
          Text('Confirm password', style: AppTextStyles.label),
          AppSpacing.smGap,
          TextFormField(
            controller: _confirmCtrl,
            obscureText: _obscureConfirm,
            textInputAction: TextInputAction.done,
            style: AppTextStyles.input,
            onFieldSubmitted: (_) => _isUpdating ? null : _updatePassword(),
            decoration: _fieldDecoration(
              hint: 'Repeat your password',
              icon: PhosphorIconsRegular.lockKey,
              suffix: IconButton(
                icon: Icon(
                  _obscureConfirm
                      ? PhosphorIconsRegular.eye
                      : PhosphorIconsRegular.eyeSlash,
                  size: AppSpacing.iconMd,
                  color: AppColors.textMuted,
                ),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please confirm your password';
              if (v != _passwordCtrl.text) return 'Passwords do not match';
              return null;
            },
          ),

          const Spacer(flex: 3),

          // Update button
          SizedBox(
            width: double.infinity,
            height: AppSpacing.buttonHeight,
            child: ElevatedButton(
              onPressed: _isUpdating ? null : _updatePassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.bgElevated,
                shape: const RoundedRectangleBorder(
                  borderRadius: AppSpacing.radiusMd,
                ),
                elevation: 0,
              ),
              child: _isUpdating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation(AppColors.textPrimary),
                      ),
                    )
                  : Text('Update password', style: AppTextStyles.button),
            ),
          ),

          AppSpacing.lgGap,
        ],
      ),
    );
  }

  // ── Success state ──────────────────────────────────────────
  Widget _buildSuccessState() {
    return Column(
      children: [
        const Spacer(flex: 2),

        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: AppColors.successSoft,
            borderRadius: AppSpacing.radiusXl,
            border: Border.all(
              color: AppColors.success.withValues(alpha: 0.25),
            ),
          ),
          child: const Icon(
            PhosphorIconsRegular.checkCircle,
            color: AppColors.success,
            size: 44,
          ),
        ),

        const SizedBox(height: AppSpacing.x3l),

        Text(
          'Password updated!',
          style: AppTextStyles.h1,
          textAlign: TextAlign.center,
        ),

        AppSpacing.lgGap,

        Text(
          'Your password has been changed successfully. '
          'Sign in with your new password.',
          style: AppTextStyles.bodySm,
          textAlign: TextAlign.center,
        ),

        const Spacer(flex: 2),

        SizedBox(
          width: double.infinity,
          height: AppSpacing.buttonHeight,
          child: ElevatedButton(
            onPressed: _signOutAndLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: const RoundedRectangleBorder(
                borderRadius: AppSpacing.radiusMd,
              ),
              elevation: 0,
            ),
            child: Text('Sign in now', style: AppTextStyles.button),
          ),
        ),

        AppSpacing.lgGap,
      ],
    );
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTextStyles.placeholder,
      prefixIcon: Icon(icon, size: AppSpacing.iconMd),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.bgElevated,
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
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppSpacing.radiusMd,
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppSpacing.radiusMd,
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
    );
  }
}

// ── Password strength bar (same as signup screen) ──────────
class _PasswordStrengthBar extends StatelessWidget {
  final int strength;
  const _PasswordStrengthBar({required this.strength});

  @override
  Widget build(BuildContext context) {
    final labels = ['Weak', 'Fair', 'Good', 'Strong'];
    final colors = [
      AppColors.error,
      AppColors.warning,
      AppColors.info,
      AppColors.success,
    ];
    final index = (strength - 1).clamp(0, 3);
    final color = strength == 0 ? AppColors.border : colors[index];
    final label = strength == 0 ? '' : labels[index];

    return Row(
      children: [
        Expanded(
          child: Row(
            children: List.generate(4, (i) {
              return Expanded(
                child: Container(
                  height: 3,
                  margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                  decoration: BoxDecoration(
                    color: i < strength ? color : AppColors.bgElevated,
                    borderRadius: AppSpacing.radiusFull,
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(label, style: AppTextStyles.caption.copyWith(color: color)),
      ],
    );
  }
}
