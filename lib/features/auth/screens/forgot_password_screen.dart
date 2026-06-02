// ============================================================
// FILE: lib/features/auth/screens/forgot_password_screen.dart
// PURPOSE: User enters their email to receive a password reset
// link. Calls authController.sendPasswordReset().
// Shows success state after sending — no navigation needed.
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:universe_v1/core/router/route_names.dart';
import 'package:universe_v1/core/theme/app_colors.dart';
import 'package:universe_v1/core/theme/app_spacing.dart';
import 'package:universe_v1/core/theme/app_text_styles.dart';
import 'package:universe_v1/features/auth/controllers/auth_controller.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final AuthController authController;
  const ForgotPasswordScreen({super.key, required this.authController});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();

  bool _emailSent = false;

  // Resend cooldown
  int _cooldown = 0;
  bool _isSending = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() => _isSending = true);

    final success = await widget.authController.sendPasswordReset(
      _emailCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSending = false);

    if (success) {
      setState(() {
        _emailSent = true;
        _cooldown  = 60;
      });
      _startCooldown();
    } else {
      _showError(
        widget.authController.errorMessage ?? 'Failed to send reset email.',
      );
    }
  }

  void _startCooldown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _cooldown--);
      return _cooldown > 0;
    });
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
    return ListenableBuilder(
      listenable: widget.authController,
      builder: (context, _) {
        final isLoading = widget.authController.isLoading || _isSending;

        return Scaffold(
          backgroundColor: AppColors.bgPrimary,
          appBar: AppBar(
            backgroundColor: AppColors.bgPrimary,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(PhosphorIconsRegular.arrowLeft),
              onPressed: () => context.go(RouteNames.emailLogin),
            ),
            title: Text('Reset password', style: AppTextStyles.h2),
          ),
          body: SafeArea(
            child: Padding(
              padding: AppSpacing.screenPadding,
              child: _emailSent
                  ? _buildSuccessState()
                  : _buildFormState(isLoading),
            ),
          ),
        );
      },
    );
  }

  // ── Before sending ─────────────────────────────────────────
  Widget _buildFormState(bool isLoading) {
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
              PhosphorIconsRegular.lockKeyOpen,
              color: AppColors.primary,
              size: 32,
            ),
          ),

          const SizedBox(height: AppSpacing.x3l),

          Text('Forgot your password?', style: AppTextStyles.h1),

          AppSpacing.lgGap,

          Text(
            'Enter your registered email address and we\'ll send '
            'you a link to reset your password.',
            style: AppTextStyles.bodySm,
          ),

          const SizedBox(height: AppSpacing.x3l),

          // Email field
          Text('Email address', style: AppTextStyles.label),
          AppSpacing.smGap,
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            style: AppTextStyles.input,
            autocorrect: false,
            onFieldSubmitted: (_) => isLoading ? null : _sendReset(),
            decoration: InputDecoration(
              hintText: 'you@university.edu',
              hintStyle: AppTextStyles.placeholder,
              prefixIcon: const Icon(
                PhosphorIconsRegular.envelope,
                size: AppSpacing.iconMd,
              ),
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
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: AppSpacing.radiusMd,
                borderSide: const BorderSide(color: AppColors.error),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: AppSpacing.radiusMd,
                borderSide:
                    const BorderSide(color: AppColors.error, width: 1.5),
              ),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email is required';
              if (!v.contains('@') || !v.contains('.')) {
                return 'Enter a valid email address';
              }
              return null;
            },
          ),

          const Spacer(flex: 3),

          // Send button
          SizedBox(
            width: double.infinity,
            height: AppSpacing.buttonHeight,
            child: ElevatedButton(
              onPressed: isLoading ? null : _sendReset,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.bgElevated,
                shape: const RoundedRectangleBorder(
                  borderRadius: AppSpacing.radiusMd,
                ),
                elevation: 0,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation(AppColors.textPrimary),
                      ),
                    )
                  : Text('Send reset link', style: AppTextStyles.button),
            ),
          ),

          AppSpacing.lgGap,

          // Back to sign in
          Center(
            child: TextButton(
              onPressed: () => context.go(RouteNames.emailLogin),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Back to sign in',
                style: AppTextStyles.bodySm.copyWith(
                  color: AppColors.textMuted,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.textMuted,
                ),
              ),
            ),
          ),

          AppSpacing.lgGap,
        ],
      ),
    );
  }

  // ── After sending ──────────────────────────────────────────
  Widget _buildSuccessState() {
    return Column(
      children: [
        const Spacer(flex: 2),

        // Success icon
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
            PhosphorIconsRegular.paperPlaneTilt,
            color: AppColors.success,
            size: 44,
          ),
        ),

        const SizedBox(height: AppSpacing.x3l),

        Text(
          'Check your inbox',
          style: AppTextStyles.h1,
          textAlign: TextAlign.center,
        ),

        AppSpacing.lgGap,

        Text(
          'We sent a password reset link to',
          style: AppTextStyles.bodySm,
          textAlign: TextAlign.center,
        ),

        AppSpacing.smGap,

        // Email chip
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                PhosphorIconsRegular.envelope,
                size: AppSpacing.iconSm,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                _emailCtrl.text.trim(),
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),

        AppSpacing.lgGap,

        Text(
          'Click the link in that email to set a new password. '
          'The link expires in 1 hour.',
          style: AppTextStyles.bodySm,
          textAlign: TextAlign.center,
        ),

        const Spacer(flex: 2),

        // Resend button with cooldown
        SizedBox(
          width: double.infinity,
          height: AppSpacing.buttonHeight,
          child: OutlinedButton(
            onPressed: (_cooldown > 0 || _isSending) ? null : _sendReset,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.border),
              disabledForegroundColor: AppColors.textMuted,
              shape: const RoundedRectangleBorder(
                borderRadius: AppSpacing.radiusMd,
              ),
            ),
            child: Text(
              _cooldown > 0
                  ? 'Resend in ${_cooldown}s'
                  : 'Resend reset email',
              style: AppTextStyles.button.copyWith(
                color: _cooldown > 0
                    ? AppColors.textMuted
                    : AppColors.textPrimary,
              ),
            ),
          ),
        ),

        AppSpacing.lgGap,

        // Back to sign in
        SizedBox(
          width: double.infinity,
          height: AppSpacing.buttonHeight,
          child: ElevatedButton(
            onPressed: () => context.go(RouteNames.emailLogin),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: const RoundedRectangleBorder(
                borderRadius: AppSpacing.radiusMd,
              ),
              elevation: 0,
            ),
            child: Text('Back to sign in', style: AppTextStyles.button),
          ),
        ),

        AppSpacing.lgGap,
      ],
    );
  }
}