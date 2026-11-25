import 'package:flutter/material.dart';
import 'package:universe/core/theme/app_colors.dart';

// PHASE 2: Obsidian Orbit typography hierarchy and tracking tokens (Provisional).
abstract class AppTextStyles {
  /// Robust platform font fallbacks to eliminate missing-glyph tofu blocks (■■■■)
  /// in offline, containerized, test, and desktop environments.
  static const List<String> primaryFontFallback = [
    'Inter',
    'Segoe UI',
    'Roboto',
    'Helvetica Neue',
    'Arial',
    'sans-serif',
  ];

  static const List<String> monospaceFontFallback = [
    'Consolas',
    'Courier New',
    'monospace',
  ];

  // PHASE 2 (PROVISIONAL): Large Display & Onboarding Headings (tightened tracking, 1.15 line height)
  static const TextStyle displayLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.15,
    letterSpacing: -0.8,
    fontFamilyFallback: primaryFontFallback,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.15,
    letterSpacing: -0.6,
    fontFamilyFallback: primaryFontFallback,
  );

  // PHASE 2 (PROVISIONAL): Operational Headings (capped cleanly at 24px so dense workspaces are not overwhelmed)
  static const TextStyle h1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.25,
    letterSpacing: -0.4,
    fontFamilyFallback: primaryFontFallback,
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.3,
    letterSpacing: -0.3,
    fontFamilyFallback: primaryFontFallback,
  );

  static const TextStyle h3 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.35,
    letterSpacing: -0.2,
    fontFamilyFallback: primaryFontFallback,
  );

  static const TextStyle h4 = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.4,
    fontFamilyFallback: primaryFontFallback,
  );

  // Body text
  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.55,
    fontFamilyFallback: primaryFontFallback,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.5,
    fontFamilyFallback: primaryFontFallback,
  );

  static const TextStyle bodySm = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.5,
    fontFamilyFallback: primaryFontFallback,
  );

  static const TextStyle bodySmMedium = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    height: 1.5,
    fontFamilyFallback: primaryFontFallback,
  );

  // Component styles
  static const TextStyle chip = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    height: 1.3,
    fontFamilyFallback: primaryFontFallback,
  );

  static const TextStyle badge = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.2,
    letterSpacing: 0.8,
    fontFamilyFallback: primaryFontFallback,
  );

  static const TextStyle label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    height: 1.3,
    letterSpacing: 0.3,
    fontFamilyFallback: primaryFontFallback,
  );

  static const TextStyle labelCaps = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.textMuted,
    height: 1.3,
    letterSpacing: 0.8,
    fontFamilyFallback: primaryFontFallback,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
    height: 1.4,
    fontFamilyFallback: primaryFontFallback,
  );

  static const TextStyle captionMedium = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
    height: 1.4,
    fontFamilyFallback: primaryFontFallback,
  );

  static const TextStyle button = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.3,
    letterSpacing: 0.1,
    fontFamilyFallback: primaryFontFallback,
  );

  static const TextStyle link = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.primary,
    height: 1.3,
    fontFamilyFallback: primaryFontFallback,
  );

  static const TextStyle danger = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.error,
    height: 1.3,
    fontFamilyFallback: primaryFontFallback,
  );

  static const TextStyle input = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.5,
    fontFamilyFallback: primaryFontFallback,
  );

  static const TextStyle placeholder = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
    height: 1.5,
    fontFamilyFallback: primaryFontFallback,
  );

  // Tabular / Monospace Numeric Styles (times, room codes, counts)
  static const TextStyle numeric = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
    color: AppColors.textPrimary,
    height: 1.4,
    fontFamilyFallback: primaryFontFallback,
  );

  static const TextStyle timeCode = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
    color: AppColors.textPrimary,
    height: 1.3,
    fontFamilyFallback: primaryFontFallback,
  );

  static const TextStyle roomCode = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
    letterSpacing: 0.5,
    color: AppColors.textPrimary,
    height: 1.3,
    fontFamilyFallback: primaryFontFallback,
  );

  static const TextStyle countdown = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
    color: AppColors.primary,
    height: 1.0,
    letterSpacing: -1.0,
    fontFamilyFallback: primaryFontFallback,
  );

  static const TextStyle countdownUnit = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.0,
    fontFamilyFallback: primaryFontFallback,
  );

  static const TextStyle statNumber = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
    color: AppColors.primary,
    height: 1.1,
    letterSpacing: -0.4,
    fontFamilyFallback: primaryFontFallback,
  );

  static const TextStyle statLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
    height: 1.3,
    fontFamilyFallback: primaryFontFallback,
  );

  static const TextStyle onboardTitle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.15,
    letterSpacing: -0.6,
    fontFamilyFallback: primaryFontFallback,
  );

  static const TextStyle onboardBody = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.65,
    fontFamilyFallback: primaryFontFallback,
  );

  static TextStyle get h1Orange =>
      h1.copyWith(color: AppColors.primary);

  static TextStyle get h3Muted =>
      h3.copyWith(color: AppColors.textSecondary);

  static TextStyle get bodyError =>
      body.copyWith(color: AppColors.error, fontSize: 12);

  static TextStyle get bodySuccess =>
      body.copyWith(color: AppColors.success, fontSize: 12);
}
