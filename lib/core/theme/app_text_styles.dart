// ============================================================
// FILE: lib/core/theme/app_text_styles.dart
// PURPOSE: Every TextStyle used in UniVerse is defined here.
//          Widgets never write raw TextStyle() inline —
//          they always use a named style from this file.
//
// HOW TO USE IN OTHER FILES:
//   import 'package:universe/core/theme/app_text_styles.dart';
//
//   // Basic usage
//   Text('Dashboard', style: AppTextStyles.h1)
//
//   // With color override
//   Text('See all', style: AppTextStyles.link)
//   Text('Cancelled', style: AppTextStyles.bodySm.copyWith(
//     color: AppColors.error))
//
// FONT SETUP (pubspec.yaml):
//   google_fonts: ^6.x
//   Then in app_theme.dart: textTheme: GoogleFonts.interTextTheme()
//   All AppTextStyles below will inherit Inter automatically
//   because app_theme.dart sets it as the default font family.
//
// FUTURE INTEGRATION:
//   - app_theme.dart maps these styles into Flutter's TextTheme
//     so that default Text() widgets also follow the design.
//   - shared/widgets/* use these styles directly.
//   - If the font changes (Inter → SF Pro), change it ONLY in
//     app_theme.dart — all styles update automatically.
// ============================================================

import 'package:flutter/material.dart';
import 'package:universe/core/theme/app_colors.dart';

abstract class AppTextStyles {

  // ──────────────────────────────────────────────────────────
  // HEADING SCALE
  // Used for screen titles and section headers.
  // Rule: one H1 per screen (the screen name), H2 for sections.
  // ──────────────────────────────────────────────────────────

  /// H1 — Screen title.
  /// Examples: "Dashboard", "My Routine", "Notifications"
  /// Used in: UAppBar title, top of every screen.
  static const TextStyle h1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.25,
    letterSpacing: -0.5,
  );

  /// H2 — Section header inside a screen.
  /// Examples: "Quick Actions", "Recent Updates", "Academic Info"
  /// Used in: USectionHeader widget.
  static const TextStyle h2 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.3,
    letterSpacing: -0.3,
  );

  /// H3 — Card title or prominent label.
  /// Examples: "Data Structures & Algorithms", "Good morning, Fahmid"
  /// Used in: ClassCard title, LiveClassCard subject name.
  static const TextStyle h3 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.35,
    letterSpacing: -0.2,
  );

  /// H4 — Sub-card title or emphasized body.
  /// Examples: Role selection card labels, form section titles.
  /// Used in: RoleCard label, settings section headers.
  static const TextStyle h4 = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  // ──────────────────────────────────────────────────────────
  // BODY SCALE
  // Three variants: full, medium weight, and small.
  // "body" is for main content. "bodySm" is for metadata.
  // ──────────────────────────────────────────────────────────

  /// Body — Standard readable text.
  /// Examples: AI chat response text, resource descriptions,
  ///           notification body text.
  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.55,
  );

  /// Body Medium — Slightly more emphasized than body.
  /// Examples: Setting tile labels, info row values,
  ///           teacher name in a class card.
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  /// Body Small — Secondary descriptive text.
  /// Examples: "Room 401 · Dr. Aminul" under class name,
  ///           "3 days ago" timestamps, notification sub-text.
  /// Default color is textSecondary — always pass color if needed.
  static const TextStyle bodySm = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  /// Body Small Medium — bodySm with more weight.
  /// Examples: Day labels "Monday", slot times "9:30 AM".
  static const TextStyle bodySmMedium = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  // ──────────────────────────────────────────────────────────
  // LABEL / CHIP / BADGE SCALE
  // Small text with purpose — always has a defined role.
  // ──────────────────────────────────────────────────────────

  /// Chip — Text inside filter pills and day selector.
  /// Examples: "Monday", "Sem 5", "PYQ", "All", "Notes"
  /// Used in: UChip, DaySelector, semester filter row.
  static const TextStyle chip = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    height: 1.3,
  );

  /// Badge — Status badge text. ALWAYS uppercase in the widget.
  /// Examples: "LIVE", "NEXT", "DONE", "CANCELLED", "LATE"
  /// Used in: UBadge widget.
  static const TextStyle badge = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.2,
    letterSpacing: 0.8,
  );

  /// Label — Form field labels and section micro-labels.
  /// Examples: "Full name", "Student ID", "ACADEMIC INFO"
  /// Used in: UTextField label param, profile section headers.
  static const TextStyle label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
    height: 1.3,
    letterSpacing: 0.3,
  );

  /// Label uppercase — Section divider labels in profile/admin.
  /// Example: "SETTINGS", "ACADEMIC INFO", "QUICK STATS"
  static const TextStyle labelCaps = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.textMuted,
    height: 1.3,
    letterSpacing: 0.8,
  );

  // ──────────────────────────────────────────────────────────
  // CAPTION SCALE
  // Smallest visible text — always uses textMuted.
  // ──────────────────────────────────────────────────────────

  /// Caption — Timestamps, helper text, hints.
  /// Examples: "2 hours ago", "Just now", form validation hints.
  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
    height: 1.4,
  );

  /// Caption Medium — Slightly emphasized caption.
  /// Examples: "Day Off", "Unavailable" labels.
  static const TextStyle captionMedium = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
    height: 1.4,
  );

  // ──────────────────────────────────────────────────────────
  // INTERACTIVE / ACTION STYLES
  // Text that the user can tap or that is part of a control.
  // ──────────────────────────────────────────────────────────

  /// Button — Label inside primary and secondary buttons.
  /// Used in: UButton widget (all variants).
  static const TextStyle button = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.3,
    letterSpacing: 0.1,
  );

  /// Link — Inline tappable text like "See all" or "Sign in".
  /// Always orange. Used in: USectionHeader trailing, auth links.
  static const TextStyle link = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.primary,
    height: 1.3,
  );

  /// Danger — Destructive actions like "Sign Out", "Delete".
  /// Red so users know to pause before tapping.
  static const TextStyle danger = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.error,
    height: 1.3,
  );

  // ──────────────────────────────────────────────────────────
  // INPUT FIELD STYLES
  // ──────────────────────────────────────────────────────────

  /// Input — Text the user types inside a UTextField.
  static const TextStyle input = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  /// Placeholder — Hint text inside empty UTextField.
  static const TextStyle placeholder = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
    height: 1.5,
  );

  // ──────────────────────────────────────────────────────────
  // SPECIAL / DISPLAY STYLES
  // For visually prominent numbers and hero content.
  // ──────────────────────────────────────────────────────────

  /// Countdown — The large "32 min" number on the live class card.
  /// Orange and very bold — the most important number on screen.
  static const TextStyle countdown = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w700,
    color: AppColors.primary,
    height: 1.0,
    letterSpacing: -1.5,
  );

  /// Countdown unit — the "min" suffix next to countdown number.
  static const TextStyle countdownUnit = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.0,
  );

  /// Stat Number — Large number on Profile and Admin dashboard.
  /// Examples: "78%", "24", "12" in the stats row.
  static const TextStyle statNumber = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.primary,
    height: 1.1,
  );

  /// Stat Label — The text below a stat number.
  /// Examples: "Attendance", "Resources", "AI Queries"
  static const TextStyle statLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
    height: 1.3,
  );

  /// Onboard title — Large text on onboarding slides.
  static const TextStyle onboardTitle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.3,
    letterSpacing: -0.5,
  );

  /// Onboard body — Description text on onboarding slides.
  static const TextStyle onboardBody = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.65,
  );

  // ──────────────────────────────────────────────────────────
  // UTILITY HELPERS
  // Call .copyWith() on any style above to get a variant.
  //
  // Example — secondary text body:
  //   AppTextStyles.body.copyWith(color: AppColors.textSecondary)
  //
  // Example — orange h2:
  //   AppTextStyles.h2.copyWith(color: AppColors.primary)
  //
  // These helpers are shortcuts for the most common overrides.
  // ──────────────────────────────────────────────────────────

  /// h1 in primary orange — used for app name on splash screen.
  static TextStyle get h1Orange =>
      h1.copyWith(color: AppColors.primary);

  /// h3 in textSecondary — for less prominent card titles.
  static TextStyle get h3Muted =>
      h3.copyWith(color: AppColors.textSecondary);

  /// body in error red — inline error messages below inputs.
  static TextStyle get bodyError =>
      body.copyWith(color: AppColors.error, fontSize: 12);

  /// body in success green — inline success messages.
  static TextStyle get bodySuccess =>
      body.copyWith(color: AppColors.success, fontSize: 12);
}
