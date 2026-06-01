// ============================================================
// FILE: lib/features/auth/screens/splash_screen.dart
// PURPOSE: The very first screen the user sees.
// - Shows the UniVerse logo and loading dots
// - Calls authController.initialize() to check session
// - GoRouter redirect logic then sends user to the right place
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:universe_v1/core/constants/app_constants.dart';
import 'package:universe_v1/core/router/route_names.dart';
import 'package:universe_v1/core/app_colors.dart';
import 'package:universe_v1/core/app_spacing.dart';
import 'package:universe_v1/core/app_text_styles.dart';
import 'package:universe_v1/features/auth/controllers/auth_controller.dart';

class SplashScreen extends StatefulWidget {
  final AuthController authController;

  const SplashScreen({super.key, required this.authController});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _dotsController;
  late Animation<double> _logoFade;
  late Animation<double> _logoScale;
  late Animation<double> _subtitleFade;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeApp();
  }

  void _setupAnimations() {
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _logoFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _logoScale = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
      ),
    );

    _subtitleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );

    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _dotsController.repeat();
    });
  }

  Future<void> _initializeApp() async {
    await widget.authController.initialize();

    if (!mounted) return;

    final status = widget.authController.status;

    if (status == AuthStatus.authenticated) {
      // GoRouter redirect will handle sending to dashboard
      return;
    }

    // Check if onboarding has been seen
    final seenOnboarding = await widget.authController.hasSeenOnboarding();
    if (!mounted) return;

    if (!seenOnboarding) {
      context.go(RouteNames.onboarding);
    } else {
      context.go(RouteNames.login);
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),

            // ── Logo ──────────────────────────────────────────
            AnimatedBuilder(
              animation: _logoController,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _logoFade,
                  child: ScaleTransition(
                    scale: _logoScale,
                    child: child,
                  ),
                );
              },
              child: Column(
                children: [
                  // App icon
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: AppSpacing.radiusXl,
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        width: AppSpacing.borderNormal,
                      ),
                    ),
                    child: const Center(
                      child: _OrbitIcon(),
                    ),
                  ),

                  AppSpacing.lgGap,

                  // App name
                  Text(
                    AppConstants.appName,
                    style: AppTextStyles.h1.copyWith(
                      fontSize: 36,
                      letterSpacing: -1.5,
                      color: AppColors.textPrimary,
                    ),
                  ),

                  AppSpacing.smGap,

                  // Subtitle
                  AnimatedBuilder(
                    animation: _logoController,
                    builder: (context, child) => FadeTransition(
                      opacity: _subtitleFade,
                      child: child,
                    ),
                    child: Text(
                      AppConstants.appSubtitle,
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(flex: 2),

            // ── Loading dots ──────────────────────────────────
            AnimatedBuilder(
              animation: _dotsController,
              builder: (context, _) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) {
                    final delay = i * 0.33;
                    final phase = (_dotsController.value - delay) % 1.0;
                    final scale = phase < 0.5
                        ? 1.0 + phase * 0.8
                        : 1.8 - (phase - 0.5) * 0.8;
                    final opacity = 0.3 + (phase < 0.5 ? phase : 1.0 - phase) * 1.4;

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      width: 6 * scale.clamp(1.0, 1.8),
                      height: 6 * scale.clamp(1.0, 1.8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(
                          alpha: opacity.clamp(0.3, 1.0),
                        ),
                        shape: BoxShape.circle,
                      ),
                    );
                  }),
                );
              },
            ),

            const SizedBox(height: AppSpacing.x5l),
          ],
        ),
      ),
    );
  }
}

// Simple orbit / planet icon drawn with Canvas
class _OrbitIcon extends StatelessWidget {
  const _OrbitIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(44, 44),
      painter: _OrbitPainter(),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Center planet
    final planetPaint = Paint()..color = AppColors.primary;
    canvas.drawCircle(Offset(cx, cy), 8, planetPaint);

    // Orbit ring
    final orbitPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy),
        width: size.width * 0.9,
        height: size.height * 0.45,
      ),
      orbitPaint,
    );

    // Small orbiting dot
    final dotPaint = Paint()..color = AppColors.primary;
    canvas.drawCircle(Offset(cx + size.width * 0.42, cy), 3.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}