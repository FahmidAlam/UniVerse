// ============================================================
// FILE: lib/features/auth/widgets/google_sign_in_button.dart
// PURPOSE: The "Continue with Google" button.
// White background, Google logo, dark text — matches
// Google's brand guidelines for OAuth buttons.
// Used in LoginScreen and register screens.
// ============================================================

import 'package:flutter/material.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';

class GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool isLoading;
  final String label;

  const GoogleSignInButton({
    super.key,
    required this.onTap,
    this.isLoading = false,
    this.label = 'Continue with Google',
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSpacing.buttonHeight,
      width: double.infinity,
      child: Material(
        color: Colors.white,
        borderRadius: AppSpacing.radiusMd,
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: AppSpacing.radiusMd,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  )
                else ...[
                  // Google "G" logo using colored squares
                  _GoogleLogo(),
                  const SizedBox(width: AppSpacing.md),
                ],
                if (!isLoading)
                  Text(
                    label,
                    style: AppTextStyles.button.copyWith(
                      color: const Color(0xFF1F1F1F),
                      fontSize: 15,
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

class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width / 2;

    // Draw the Google G shape using arcs and fills
    // Simplified but recognizable Google color palette

    final bluePaint   = Paint()..color = const Color(0xFF4285F4);
    final redPaint    = Paint()..color = const Color(0xFFEA4335);
    final yellowPaint = Paint()..color = const Color(0xFFFBBC05);
    final greenPaint  = Paint()..color = const Color(0xFF34A853);

    // Blue arc (right side)
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -0.52, 1.05, false,
      bluePaint..style = PaintingStyle.stroke..strokeWidth = size.width * 0.28,
    );

    // Red arc (top-left)
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -2.62, 1.05, false,
      redPaint..style = PaintingStyle.stroke..strokeWidth = size.width * 0.28,
    );

    // Yellow arc (bottom-left)
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      2.09, 0.57, false,
      yellowPaint..style = PaintingStyle.stroke..strokeWidth = size.width * 0.28,
    );

    // Green arc (bottom)
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      1.57, 0.57, false,
      greenPaint..style = PaintingStyle.stroke..strokeWidth = size.width * 0.28,
    );

    // White center cutout for the horizontal bar of G
    final whitePaint = Paint()..color = Colors.white;
    canvas.drawRect(
      Rect.fromLTWH(cx - 0.5, cy - size.height * 0.14,
          r + 1.5, size.height * 0.28),
      whitePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
