// ============================================================
// FILE: lib/features/auth/screens/verify_email_screen.dart
// PURPOSE: Shown after email sign-up while waiting for the
// user to click the verification link in their inbox.
//
// WHAT IT DOES:
// - Shows the pending email address
// - "I've verified" button → refreshes session and checks
// - "Resend email" button with 60-second cooldown
// - Auto-polls every 5 seconds (Supabase session refresh)
// - Navigates to dashboard automatically on verification
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universe_v1/core/router/route_names.dart';
import 'package:universe_v1/core/theme/app_colors.dart';
import 'package:universe_v1/core/theme/app_spacing.dart';
import 'package:universe_v1/core/theme/app_text_styles.dart';
import 'package:universe_v1/features/auth/controllers/auth_controller.dart';

class VerifyEmailScreen extends StatefulWidget {
  final AuthController authController;
  const VerifyEmailScreen({super.key, required this.authController});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  // ── Resend cooldown ───────────────────────────────────────
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  // ── Auto-poll timer ───────────────────────────────────────
  Timer? _pollTimer;

  // ── Local state ───────────────────────────────────────────
  bool _checkingVerification = false;
  bool _resentSuccessfully   = false;

  @override
  void initState() {
    super.initState();
    widget.authController.addListener(_onAuthChange);
    _startPolling();
  }

  @override
  void dispose() {
    widget.authController.removeListener(_onAuthChange);
    _cooldownTimer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  // Listen to auth state — when verified, GoRouter redirects
  void _onAuthChange() {
    if (!mounted) return;
    if (widget.authController.status == AuthStatus.authenticated) {
      _pollTimer?.cancel();
    }
  }

  // Poll every 5 seconds by calling refreshSession via Supabase
  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted) return;
      // Refresh the session silently — Supabase updates emailConfirmedAt
      try {
        await Supabase.instance.client.auth.refreshSession();
        final user = Supabase.instance.client.auth.currentUser;
        if (user?.emailConfirmedAt != null) {
          _pollTimer?.cancel();
          if (mounted) await _handleVerified();
        }
      } catch (_) {
        // Ignore errors during background polling
      }
    });
  }

  Future<void> _handleVerified() async {
    setState(() => _checkingVerification = true);
    final result = await widget.authController.handleOAuthCallback();
    if (mounted) setState(() => _checkingVerification = false);
    // GoRouter redirect takes over once status → authenticated
  }

  Future<void> _checkManually() async {
    setState(() => _checkingVerification = true);
    try {
      await Supabase.instance.client.auth.refreshSession();
      final user = Supabase.instance.client.auth.currentUser;
      if (user?.emailConfirmedAt != null) {
        _pollTimer?.cancel();
        await _handleVerified();
        return;
      }
    } catch (_) {}

    setState(() => _checkingVerification = false);

    if (mounted) {
      _showSnackbar(
        'Email not verified yet. Check your inbox and click the link.',
        isError: true,
      );
    }
  }

  Future<void> _resendEmail() async {
    if (_resendCooldown > 0) return;

    final success = await widget.authController.resendVerificationEmail();

    if (!mounted) return;

    if (success) {
      setState(() {
        _resentSuccessfully = true;
        _resendCooldown = 60;
      });
      _showSnackbar('Verification email sent!');
      _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        setState(() => _resendCooldown--);
        if (_resendCooldown <= 0) t.cancel();
      });
    } else {
      _showSnackbar(
        widget.authController.errorMessage ?? 'Failed to resend email.',
        isError: true,
      );
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: AppTextStyles.bodySm.copyWith(color: AppColors.textPrimary),
        ),
        backgroundColor: AppColors.bgElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.radiusMd,
          side: BorderSide(
            color: isError ? AppColors.error : AppColors.success,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.authController.pendingEmail ?? 'your email';

    return ListenableBuilder(
      listenable: widget.authController,
      builder: (context, _) {
        final isLoading = widget.authController.isLoading || _checkingVerification;

        return Scaffold(
          backgroundColor: AppColors.bgPrimary,
          appBar: AppBar(
            backgroundColor: AppColors.bgPrimary,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(PhosphorIconsRegular.arrowLeft),
              onPressed: () async {
                _pollTimer?.cancel();
                await widget.authController.signOut();
                if (context.mounted) context.go(RouteNames.login);
              },
            ),
          ),
          body: SafeArea(
            child: Padding(
              padding: AppSpacing.screenPadding,
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // ── Icon ──────────────────────────────────
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: AppColors.infoSoft,
                      borderRadius: AppSpacing.radiusXl,
                      border: Border.all(
                        color: AppColors.info.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Icon(
                          PhosphorIconsRegular.envelope,
                          color: AppColors.info,
                          size: 44,
                        ),
                        // Animated pulsing dot
                        Positioned(
                          top: 18,
                          right: 18,
                          child: _PulsingDot(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.x3l),

                  // ── Headline ──────────────────────────────
                  Text(
                    'Check your inbox',
                    style: AppTextStyles.h1,
                    textAlign: TextAlign.center,
                  ),

                  AppSpacing.lgGap,

                  Text(
                    'We sent a verification link to',
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
                          email,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  AppSpacing.lgGap,

                  Text(
                    'Click the link in that email to activate your account. '
                    'Check your spam folder if you don\'t see it.',
                    style: AppTextStyles.bodySm,
                    textAlign: TextAlign.center,
                  ),

                  if (_resentSuccessfully) ...[
                    AppSpacing.lgGap,
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.successSoft,
                        borderRadius: AppSpacing.radiusMd,
                        border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            PhosphorIconsRegular.checkCircle,
                            size: AppSpacing.iconSm,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            'New email sent successfully',
                            style: AppTextStyles.bodySm.copyWith(
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const Spacer(flex: 2),

                  // ── I've verified button ──────────────────
                  SizedBox(
                    width: double.infinity,
                    height: AppSpacing.buttonHeight,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _checkManually,
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
                                valueColor: AlwaysStoppedAnimation(
                                  AppColors.textPrimary,
                                ),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  PhosphorIconsRegular.checkCircle,
                                  size: AppSpacing.iconMd,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  "I've verified my email",
                                  style: AppTextStyles.button,
                                ),
                              ],
                            ),
                    ),
                  ),

                  AppSpacing.lgGap,

                  // ── Resend button ─────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: AppSpacing.buttonHeight,
                    child: OutlinedButton(
                      onPressed: (_resendCooldown > 0 || isLoading)
                          ? null
                          : _resendEmail,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.border),
                        disabledForegroundColor: AppColors.textMuted,
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppSpacing.radiusMd,
                        ),
                      ),
                      child: Text(
                        _resendCooldown > 0
                            ? 'Resend in ${_resendCooldown}s'
                            : 'Resend verification email',
                        style: AppTextStyles.button.copyWith(
                          color: _resendCooldown > 0
                              ? AppColors.textMuted
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),

                  AppSpacing.lgGap,

                  // ── Wrong email note ──────────────────────
                  Center(
                    child: TextButton(
                      onPressed: () async {
                        _pollTimer?.cancel();
                        await widget.authController.signOut();
                        if (context.mounted) context.go(RouteNames.emailSignup);
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Wrong email? Sign up again',
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
            ),
          ),
        );
      },
    );
  }
}

// ── Animated pulsing green dot ─────────────────────────────
class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.8, end: 1.3).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _opacity = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Transform.scale(
        scale: _scale.value,
        child: Opacity(
          opacity: _opacity.value,
          child: Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}