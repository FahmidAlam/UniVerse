import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/router/route_names.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/features/auth/widgets/google_sign_in_button.dart';

class LoginScreen extends StatefulWidget {
  final AuthController authController;

  const LoginScreen({super.key, required this.authController});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  @override
  void initState() {
    super.initState();
    widget.authController.addListener(_onAuthChange);
  }

  @override
  void dispose() {
    widget.authController.removeListener(_onAuthChange);
    super.dispose();
  }

  void _onAuthChange() {
    if (!mounted) return;

    final status = widget.authController.status;

    if (status == AuthStatus.error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.authController.errorMessage ?? 'Something went wrong.',
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

  }

  Future<void> _handleGoogleSignIn() async {
    await widget.authController.signInWithGoogle();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.authController,
      builder: (context, _) {
        final isLoading = widget.authController.isLoading;

        return Scaffold(
          backgroundColor: AppColors.bgPrimary,
          body: SafeArea(
            child: Padding(
              padding: AppSpacing.screenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(flex: 2),

                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: AppSpacing.radiusLg,
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Center(
                            child: _MiniOrbit(),
                          ),
                        ),

                        AppSpacing.lgGap,

                        Text(
                          AppConstants.appName,
                          style: AppTextStyles.h1.copyWith(
                            fontSize: 28,
                            letterSpacing: -1.0,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  Text(
                    'Welcome back',
                    style: AppTextStyles.h1,
                  ),

                  AppSpacing.smGap,

                  Text(
                    'Sign in with your university Google account to continue.',
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.x3l),

                  GoogleSignInButton(
                    onTap: isLoading ? null : _handleGoogleSignIn,
                    isLoading: isLoading,
                  ),

                  const SizedBox(height: AppSpacing.md),

                  SizedBox(
                    width: double.infinity,
                    height: AppSpacing.buttonHeight,
                    child: OutlinedButton(
                      onPressed: isLoading
                          ? null
                          : () => context.go(RouteNames.emailLogin),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.border),
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppSpacing.radiusMd,
                        ),
                      ),
                      child: Text(
                        'Continue with email',
                        style: AppTextStyles.button,
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  Row(
                    children: [
                      const Expanded(
                        child: Divider(color: AppColors.border),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        child: Text(
                          'new here?',
                          style: AppTextStyles.caption,
                        ),
                      ),
                      const Expanded(
                        child: Divider(color: AppColors.border),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  SizedBox(
                    width: double.infinity,
                    height: AppSpacing.buttonHeight,
                    child: OutlinedButton(
                      onPressed: isLoading
                          ? null
                          : () => context.go(RouteNames.roleSelection),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.border),
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppSpacing.radiusMd,
                        ),
                      ),
                      child: Text(
                        'Create an account',
                        style: AppTextStyles.button,
                      ),
                    ),
                  ),

                  const Spacer(),

                  Center(
                    child: Text(
                      'Admin access is granted by your department head.',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textMuted,
                      ),
                      textAlign: TextAlign.center,
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

class _MiniOrbit extends StatelessWidget {
  const _MiniOrbit();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(30, 30),
      painter: _MiniOrbitPainter(),
    );
  }
}

class _MiniOrbitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final planetPaint = Paint()..color = AppColors.primary;
    canvas.drawCircle(Offset(cx, cy), 5.5, planetPaint);

    final orbitPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy),
        width: size.width * 0.9,
        height: size.height * 0.45,
      ),
      orbitPaint,
    );

    canvas.drawCircle(
      Offset(cx + size.width * 0.41, cy),
      2.5,
      planetPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
