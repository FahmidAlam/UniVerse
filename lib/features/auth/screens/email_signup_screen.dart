// ============================================================
// FILE: lib/features/auth/screens/email_signup_screen.dart
// PURPOSE: Email + password sign-up form.
// - Validates email against whitelist (in controller)
// - Password strength check + confirm password field
// - On success → VerifyEmailScreen
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:universe/core/router/route_names.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';

class EmailSignupScreen extends StatefulWidget {
  final AuthController authController;
  const EmailSignupScreen({super.key, required this.authController});

  @override
  State<EmailSignupScreen> createState() => _EmailSignupScreenState();
}

class _EmailSignupScreenState extends State<EmailSignupScreen> {
  final _formKey         = GlobalKey<FormState>();
  final _emailCtrl       = TextEditingController();
  final _passwordCtrl    = TextEditingController();
  final _confirmCtrl     = TextEditingController();
  bool _obscurePassword  = true;
  bool _obscureConfirm   = true;

  @override
  void initState() {
    super.initState();
    widget.authController.addListener(_onAuthChange);
  }

  @override
  void dispose() {
    widget.authController.removeListener(_onAuthChange);
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _onAuthChange() {
    if (!mounted) return;
    final status = widget.authController.status;

    if (status == AuthStatus.awaitingVerification) {
      context.go(RouteNames.verifyEmail);
    } else if (status == AuthStatus.notWhitelisted) {
      context.go(RouteNames.notWhitelisted);
    } else if (status == AuthStatus.authenticated) {
      // email confirmation disabled — went straight to dashboard
    } else if (status == AuthStatus.error) {
      _showError(widget.authController.errorMessage ?? 'Sign-up failed.');
    }
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    await widget.authController.signUpWithEmail(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: AppTextStyles.bodySm.copyWith(color: AppColors.textPrimary)),
      backgroundColor: AppColors.bgElevated,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.radiusMd,
        side: const BorderSide(color: AppColors.error),
      ),
    ));
  }

  // Simple password strength indicator
  int _passwordStrength(String password) {
    if (password.isEmpty) return 0;
    int score = 0;
    if (password.length >= 8) score++;
    if (password.contains(RegExp(r'[A-Z]'))) score++;
    if (password.contains(RegExp(r'[0-9]'))) score++;
    if (password.contains(RegExp(r'[!@#\$%^&*]'))) score++;
    return score; // 0-4
  }

  @override
  Widget build(BuildContext context) {
    final passwordStrength = _passwordStrength(_passwordCtrl.text);

    return ListenableBuilder(
      listenable: widget.authController,
      builder: (context, _) {
        final isLoading = widget.authController.isLoading;

        return Scaffold(
          backgroundColor: AppColors.bgPrimary,
          appBar: AppBar(
            backgroundColor: AppColors.bgPrimary,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(PhosphorIconsRegular.arrowLeft),
              onPressed: () => context.go(RouteNames.login),
            ),
            title: Text('Create account', style: AppTextStyles.h2),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: AppSpacing.screenPaddingScrollable,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSpacing.lgGap,

                    Text('Sign up', style: AppTextStyles.h1),
                    AppSpacing.smGap,
                    Text(
                      'Your email must be pre-registered by your department admin.',
                      style: AppTextStyles.bodySm,
                    ),

                    const SizedBox(height: AppSpacing.x3l),

                    // ── Email ────────────────────────────────
                    _buildLabel('Email address'),
                    AppSpacing.smGap,
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      style: AppTextStyles.input,
                      autocorrect: false,
                      decoration: _fieldDecoration(
                        hint: 'you@university.edu',
                        icon: PhosphorIconsRegular.envelope,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Email is required';
                        }
                        if (!v.contains('@') || !v.contains('.')) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),

                    AppSpacing.lgGap,

                    // ── Password ─────────────────────────────
                    _buildLabel('Password'),
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
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Password is required';
                        if (v.length < 6) return 'Minimum 6 characters';
                        return null;
                      },
                    ),

                    // ── Strength indicator ────────────────────
                    if (_passwordCtrl.text.isNotEmpty) ...[
                      AppSpacing.smGap,
                      _PasswordStrengthBar(strength: passwordStrength),
                    ],

                    AppSpacing.lgGap,

                    // ── Confirm password ──────────────────────
                    _buildLabel('Confirm password'),
                    AppSpacing.smGap,
                    TextFormField(
                      controller: _confirmCtrl,
                      obscureText: _obscureConfirm,
                      textInputAction: TextInputAction.done,
                      style: AppTextStyles.input,
                      onFieldSubmitted: (_) => _signUp(),
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
                          onPressed: () => setState(
                              () => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (v != _passwordCtrl.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: AppSpacing.x3l),

                    // ── Sign up button ────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: AppSpacing.buttonHeight,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _signUp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          disabledBackgroundColor: AppColors.bgElevated,
                          shape: const RoundedRectangleBorder(
                              borderRadius: AppSpacing.radiusMd),
                          elevation: 0,
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                      AppColors.textPrimary),
                                ),
                              )
                            : Text('Create account',
                                style: AppTextStyles.button),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.x3l),

                    // ── Already have account ──────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Already have an account? ',
                            style: AppTextStyles.bodySm),
                        TextButton(
                          onPressed: () =>
                              context.go(RouteNames.emailLogin),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child:
                              Text('Sign in', style: AppTextStyles.link),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLabel(String text) => Text(text, style: AppTextStyles.label);

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
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      border: OutlineInputBorder(
          borderRadius: AppSpacing.radiusMd,
          borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: AppSpacing.radiusMd,
          borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: AppSpacing.radiusMd,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: AppSpacing.radiusMd,
          borderSide: const BorderSide(color: AppColors.error)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppSpacing.radiusMd,
          borderSide: const BorderSide(color: AppColors.error, width: 1.5)),
    );
  }
}

class _PasswordStrengthBar extends StatelessWidget {
  final int strength; // 0-4
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
        Text(
          label,
          style: AppTextStyles.caption.copyWith(color: color),
        ),
      ],
    );
  }
}
