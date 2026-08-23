// ============================================================
// FILE: lib/features/auth/screens/email_login_screen.dart
// PURPOSE: Email + password sign-in form.
// - Validates fields before calling controller
// - Shows inline field errors
// - "Forgot password?" link → ForgotPasswordScreen
// - "Don't have an account?" → EmailSignupScreen
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/core/router/route_names.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';

class EmailLoginScreen extends StatefulWidget {
  final AuthController authController;
  const EmailLoginScreen({super.key, required this.authController});

  @override
  State<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends State<EmailLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

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
    super.dispose();
  }

  void _onAuthChange() {
    if (!mounted) return;
    final status = widget.authController.status;

    if (status == AuthStatus.awaitingVerification) {
      context.go(RouteNames.verifyEmail);
    } else if (status == AuthStatus.notWhitelisted) {
      context.go(RouteNames.notWhitelisted);
    } else if (status == AuthStatus.error) {
      _showError(widget.authController.errorMessage ?? 'Sign-in failed.');
    }
    // authenticated → GoRouter redirect handles dashboard navigation
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    await widget.authController.signInWithEmail(
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

  @override
  Widget build(BuildContext context) {
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
            title: Text('Sign in', style: AppTextStyles.h2),
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

                    Text('Welcome back', style: AppTextStyles.h1),
                    AppSpacing.smGap,
                    Text(
                      'Sign in with your registered email address.',
                      style: AppTextStyles.bodySm,
                    ),

                    const SizedBox(height: AppSpacing.x3l),

                    // ── Email field ──────────────────────────
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

                    // ── Password field ───────────────────────
                    _buildLabel('Password'),
                    AppSpacing.smGap,
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      style: AppTextStyles.input,
                      onFieldSubmitted: (_) => _signIn(),
                      decoration: _fieldDecoration(
                        hint: '••••••••',
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
                        if (v == null || v.isEmpty) {
                          return 'Password is required';
                        }
                        return null;
                      },
                    ),

                    AppSpacing.smGap,

                    // ── Forgot password link ──────────────────
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () =>
                            context.push(RouteNames.forgotPassword),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child:
                            Text('Forgot password?', style: AppTextStyles.link),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.x3l),

                    // ── Sign in button ────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: AppSpacing.buttonHeight,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _signIn,
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
                            : Text('Sign in', style: AppTextStyles.button),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.x3l),

                    // ── Sign up link ──────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Don't have an account? ",
                            style: AppTextStyles.bodySm),
                        TextButton(
                          onPressed: () => context.push(RouteNames.emailSignup),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text('Sign up', style: AppTextStyles.link),
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
