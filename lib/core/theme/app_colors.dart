// ============================================================
// FILE: lib/core/theme/app_colors.dart
// PURPOSE: Every color used in UniVerse lives here as a named
//          constant. No screen or widget ever hardcodes a hex
//          value — they always import and use these tokens.
//
// HOW TO USE IN OTHER FILES:
//   import 'package:universe/core/theme/app_colors.dart';
//   Container(color: AppColors.bgCard)
//   Text('Hello', style: TextStyle(color: AppColors.textPrimary))
//
// WHY THIS MATTERS:
//   If the advisor asks to change the orange to blue, you change
//   ONE line here (AppColors.primary) and the whole app updates.
//   No hunting through 30 files for hardcoded hex values.
//
// FUTURE INTEGRATION:
//   - app_theme.dart imports this to wire into Flutter's ThemeData
//   - shared/widgets/* import this for every widget color
//   - If dark/light mode is ever added, this file gets a light
//     variant and app_theme.dart switches between them.
// ============================================================

import 'package:flutter/material.dart';

abstract class AppColors {

  // ──────────────────────────────────────────────────────────
  // BACKGROUND LAYERS
  // Think of these as a stack from darkest (bottom) to lightest.
  // bgPrimary is the screen itself. bgCard sits on top of that.
  // bgElevated sits on top of cards (inputs, chips).
  // ──────────────────────────────────────────────────────────

  /// The main screen background — almost pure black with a
  /// very slight warm tint. Used as Scaffold backgroundColor.
  static const Color bgPrimary = Color(0xFF0F0F10);

  /// Card surfaces that float on the screen background.
  /// Used by UCard, ClassCard, NotificationTile, ResourceCard.
  static const Color bgCard = Color(0xFF1A1A1C);

  /// Elevated surfaces — sit visually above cards.
  /// Used by text fields, chips, filter bars, dropdown menus.
  static const Color bgElevated = Color(0xFF222325);

  /// The subtlest surface — used for pressed states,
  /// skeleton loaders, and very light section backgrounds.
  static const Color bgSubtle = Color(0xFF1C1C1E);

  // ──────────────────────────────────────────────────────────
  // BRAND / ACCENT (Warm Orange)
  // This is the single personality color of the app.
  // Used for: active states, CTAs, progress bars, live badges,
  // bottom nav active icon, countdown timer text.
  // ──────────────────────────────────────────────────────────

  /// The primary brand orange — main CTA buttons, active nav
  /// icon, live class badge dot, countdown timer color.
  static const Color primary = Color(0xFFFF7A00);

  /// Slightly darker — used for button pressed/hover state.
  /// In Flutter: use for InkWell splash or AnimatedContainer.
  static const Color primaryDark = Color(0xFFE66A00);

  /// Semi-transparent orange background for badges and chips
  /// that need the orange personality without being too loud.
  /// Example: "LIVE NOW" badge background, role selection border.
  static const Color primarySoft = Color(0xFF2A1A0A);

  /// Even darker orange tint — used for pressed chip states
  /// and selected filter pill backgrounds.
  static const Color primaryMuted = Color(0xFF3D2000);

  // ──────────────────────────────────────────────────────────
  // TEXT HIERARCHY
  // There are exactly 4 text shades. Never use any other shade.
  //   Primary   → headings, card titles, important values
  //   Secondary → body text, descriptions, subtitles
  //   Muted     → metadata, timestamps, placeholders, labels
  //   Disabled  → unavailable / placeholder text in inputs
  // ──────────────────────────────────────────────────────────

  /// Pure white — for all important text (headings, card titles,
  /// class names, teacher names, button labels).
  static const Color textPrimary = Color(0xFFFFFFFF);

  /// Soft grey — body text, descriptions, secondary info.
  /// Example: "Room 401 · Dr. Aminul Islam" under a class name.
  static const Color textSecondary = Color(0xFFB0B3B8);

  /// Muted grey — timestamps, metadata, form field labels,
  /// inactive tab text, placeholder text in search bars.
  static const Color textMuted = Color(0xFF6E7278);

  /// Very dark grey — disabled inputs and non-interactive text.
  static const Color textDisabled = Color(0xFF4A4D52);

  // ──────────────────────────────────────────────────────────
  // BORDERS AND DIVIDERS
  // Keep borders subtle — they define structure without
  // creating visual noise on a dark background.
  // ──────────────────────────────────────────────────────────

  /// Default border for cards, dividers, input fields (unfocused).
  /// Barely visible — just enough to separate surfaces.
  static const Color border = Color(0xFF2A2C30);

  /// Input field border when focused / active.
  /// Matches primary to show "the system is listening".
  static const Color borderFocus = Color(0xFFFF7A00);

  /// Error state border for invalid input fields.
  static const Color borderError = Color(0xFFEF4444);

  // ──────────────────────────────────────────────────────────
  // STATUS / SEMANTIC COLORS
  // Each status has a FULL color (text, icons, borders) and
  // a SOFT color (background of the badge/card containing it).
  //
  // Pattern used across ClassCard and NotificationTile:
  //   Container(color: AppColors.successSoft,
  //     child: Text('LIVE', style: TextStyle(color: AppColors.success)))
  // ──────────────────────────────────────────────────────────

  // ── Live / On-time / Success ───────────────────────────────
  /// Green — ongoing class dot, on-time submission tag.
  static const Color success = Color(0xFF22C55E);

  /// Dark green background for success badges.
  static const Color successSoft = Color(0xFF0D2E1A);

  // ── Next / Info / Upcoming ────────────────────────────────
  /// Blue — "NEXT" class badge, info notifications.
  static const Color info = Color(0xFF3B82F6);

  /// Dark blue background for info badges.
  static const Color infoSoft = Color(0xFF0D1F3C);

  // ── Warning / Exam / Reminder ────────────────────────────
  /// Amber — "TEST REMINDER" notification, deadline warnings.
  static const Color warning = Color(0xFFF59E0B);

  /// Dark amber background for warning badges.
  static const Color warningSoft = Color(0xFF2D1E00);

  // ── Error / Cancelled / Late ─────────────────────────────
  /// Red — "CLASS CANCELLED", "LATE" submission tag,
  /// form validation errors, sign-out button text.
  static const Color error = Color(0xFFEF4444);

  /// Dark red background for error/cancelled badges.
  static const Color errorSoft = Color(0xFF2D0D0D);

  // ── Done / Completed / Past ──────────────────────────────
  /// Muted grey — "DONE" class badge (already over).
  static const Color done = Color(0xFF6E7278);

  /// Very dark surface for "done" state cards.
  static const Color doneSoft = Color(0xFF1A1C1F);

  // ──────────────────────────────────────────────────────────
  // NOTIFICATION TYPE COLORS
  // Every notification card has a 3px left border in one of
  // these colors, telling the user what type it is at a glance.
  //
  // INTEGRATION: NotificationTile widget reads notifType and
  // picks the border color from this group.
  // ──────────────────────────────────────────────────────────

  static const Color notifCancel  = Color(0xFFEF4444); // class cancelled
  static const Color notifTest    = Color(0xFFF59E0B); // test/viva reminder
  static const Color notifExam    = Color(0xFFFF7A00); // exam notice (brand)
  static const Color notifRoom    = Color(0xFF3B82F6); // room change
  static const Color notifHoliday = Color(0xFF6E7278); // holiday / general
  static const Color notifAssign  = Color(0xFF22C55E); // assignment reminder

  // ──────────────────────────────────────────────────────────
  // ACTOR ROLE COLORS
  // Each actor gets a distinct color used in badges and
  // role selection cards on the register screen.
  //
  // INTEGRATION: RoleCard widget uses these for its border
  // and icon color. ProfileHeader shows role badge with these.
  // ──────────────────────────────────────────────────────────

  static const Color roleStudent = Color(0xFF22C55E); // green
  static const Color roleTeacher = Color(0xFF3B82F6); // blue
  static const Color roleAdmin   = Color(0xFFFF7A00); // orange (brand)

  // ──────────────────────────────────────────────────────────
  // BOTTOM NAVIGATION
  // The nav bar is slightly different from bgPrimary to give
  // it visual separation from the screen below it.
  // ──────────────────────────────────────────────────────────

  /// Bottom nav bar background — one step lighter than screen bg.
  static const Color navBg         = Color(0xFF111113);

  /// Active tab icon and label — matches primary brand orange.
  static const Color navActive      = Color(0xFFFF7A00);

  /// Inactive tab icon and label — muted, doesn't compete.
  static const Color navInactive    = Color(0xFF6E7278);

  /// Notification red dot on the Alerts tab icon.
  static const Color navBadge       = Color(0xFFEF4444);

  // ──────────────────────────────────────────────────────────
  // GRADIENTS
  // Used sparingly — only for the primary CTA button and
  // the live class hero card left accent.
  //
  // INTEGRATION: UButton (primary variant) uses primaryGradient.
  // The live class card uses a subtle linear overlay.
  // ──────────────────────────────────────────────────────────

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFF7A00), Color(0xFFE64D00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Soft overlay for hero cards — adds depth without noise.
  static const LinearGradient cardOverlay = LinearGradient(
    colors: [Color(0x001A1A1C), Color(0x801A1A1C)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ──────────────────────────────────────────────────────────
  // UTILITY HELPERS
  // These static methods make it easier to work with opacity
  // variants of existing colors without magic numbers.
  // ──────────────────────────────────────────────────────────

  /// Returns any AppColor at a given opacity (0.0 → 1.0).
  /// Example: AppColors.withOpacity(AppColors.primary, 0.15)
  static Color withOpacity(Color color, double opacity) =>
      color.withValues(alpha: opacity);
}