// ============================================================
// FILE: lib/core/theme/app_spacing.dart
// PURPOSE: Every spacing value, border radius, and dimension
//          constant lives here. Widgets never use raw numbers
//          like SizedBox(height: 16) — they use AppSpacing.lg.
//
// HOW TO USE IN OTHER FILES:
//   import 'package:universe/core/theme/app_spacing.dart';
//
//   // Padding
//   Padding(padding: AppSpacing.screenPadding, child: ...)
//   Padding(padding: EdgeInsets.all(AppSpacing.lg), child: ...)
//
//   // Gap between widgets
//   Column(children: [
//     Text('Hello'),
//     AppSpacing.cardGap,   // SizedBox(height: 10)
//     Text('World'),
//   ])
//
//   // Border radius
//   Container(
//     decoration: BoxDecoration(
//       borderRadius: AppSpacing.radiusMd,
//     ),
//   )
//
// WHY THIS MATTERS:
//   Consistent spacing is what makes the app look "designed"
//   vs "built by a programmer". Every card, every gap, every
//   padding follows the same 4px base grid.
//
// FUTURE INTEGRATION:
//   - shared/widgets/* use these for all padding and sizing
//   - If the design changes (e.g., denser layout for tablets),
//     change the values here once — everything updates.
// ============================================================

import 'package:flutter/material.dart';

abstract class AppSpacing {

  // ──────────────────────────────────────────────────────────
  // SPACING SCALE (4px base grid)
  // xs=4, sm=8, md=12, lg=16, xl=20, xxl=24, x3l=32, x4l=48
  //
  // Rule of thumb:
  //   xs  → icon padding, chip internal spacing
  //   sm  → between an icon and its label
  //   md  → card internal sub-sections
  //   lg  → standard card padding, between list items
  //   xl  → screen horizontal padding, top of screen
  //   xxl → between major sections on a screen
  //   x3l → large separators, onboarding spacing
  // ──────────────────────────────────────────────────────────

  static const double xs  = 4.0;
  static const double sm  = 8.0;
  static const double md  = 12.0;
  static const double lg  = 16.0;
  static const double xl  = 20.0;
  static const double xxl = 24.0;
  static const double x3l = 32.0;
  static const double x4l = 40.0;
  static const double x5l = 48.0;

  // ──────────────────────────────────────────────────────────
  // SCREEN PADDING
  // Consistent outer margin for every screen.
  // All screens use horizontal: 20 and vertical: 16.
  //
  // Usage:
  //   Padding(padding: AppSpacing.screenPadding, child: content)
  //   SingleChildScrollView(padding: AppSpacing.screenPadding, ...)
  // ──────────────────────────────────────────────────────────

  static const double screenH = 20.0; // left and right margin
  static const double screenV = 16.0; // top and bottom margin

  static const EdgeInsets screenPadding = EdgeInsets.symmetric(
    horizontal: screenH,
    vertical: screenV,
  );

  /// For screens that scroll — adds bottom padding so content
  /// isn't hidden behind the bottom nav bar.
  static const EdgeInsets screenPaddingScrollable = EdgeInsets.fromLTRB(
    screenH, screenV, screenH, 88.0, // 72 nav + 16 extra
  );

  /// Horizontal-only screen padding — for items that fill width
  /// but don't need vertical padding managed here.
  static const EdgeInsets screenPaddingH = EdgeInsets.symmetric(
    horizontal: screenH,
  );

  // ──────────────────────────────────────────────────────────
  // CARD PADDING VARIANTS
  // Cards use 16px by default. Hero cards use 20px.
  // Compact cards (notification tiles, setting rows) use 12px.
  //
  // Usage:
  //   Container(padding: AppSpacing.cardPadding, ...)
  // ──────────────────────────────────────────────────────────

  /// Standard card padding — used by UCard, ClassCard, etc.
  static const EdgeInsets cardPadding = EdgeInsets.all(16.0);

  /// Hero card padding — used by LiveClassCard (the big one).
  static const EdgeInsets cardPaddingLg = EdgeInsets.all(20.0);

  /// Compact card padding — notification tiles, setting rows.
  static const EdgeInsets cardPaddingSm = EdgeInsets.all(12.0);

  /// Card padding with more horizontal room — resource cards.
  static const EdgeInsets cardPaddingH = EdgeInsets.symmetric(
    horizontal: 16.0,
    vertical: 12.0,
  );

  // ──────────────────────────────────────────────────────────
  // GAP WIDGETS
  // Pre-built SizedBox instances — use directly in Column/Row.
  // Eliminates SizedBox(height: 16) noise throughout the code.
  //
  // Usage in Column:
  //   Text('Section Title'),
  //   AppSpacing.smGap,
  //   ClassCard(...),
  //   AppSpacing.cardGap,
  //   ClassCard(...),
  // ──────────────────────────────────────────────────────────

  /// 4px gap — between very close elements (icon + label).
  static const SizedBox xsGap = SizedBox(height: 4, width: 4);

  /// 8px gap — between related elements inside a card.
  static const SizedBox smGap = SizedBox(height: 8);

  /// 8px horizontal gap — between items in a Row.
  static const SizedBox smHGap = SizedBox(width: 8);

  /// 10px gap — between cards in a list.
  static const SizedBox cardGap = SizedBox(height: 10);

  /// 10px horizontal gap — between items in a horizontal list.
  static const SizedBox cardHGap = SizedBox(width: 10);

  /// 12px gap — between sub-sections inside a card.
  static const SizedBox mdGap = SizedBox(height: 12);

  /// 16px gap — standard vertical gap between elements.
  static const SizedBox lgGap = SizedBox(height: 16);

  /// 20px gap — between named sections on a screen.
  static const SizedBox sectionGap = SizedBox(height: 20);

  /// 24px gap — between major blocks (e.g., quick actions → recent).
  static const SizedBox xxlGap = SizedBox(height: 24);

  /// 32px gap — onboarding and auth screen spacing.
  static const SizedBox x3lGap = SizedBox(height: 32);

  // ──────────────────────────────────────────────────────────
  // BORDER RADIUS
  // All surfaces in the app use rounded corners.
  // The scale matches the surface hierarchy:
  //   sm   → chips, badges, small tags
  //   md   → text fields, buttons, compact cards
  //   lg   → standard cards
  //   xl   → hero cards (live class, onboarding)
  //   full → pills (day selector, category tabs)
  // ──────────────────────────────────────────────────────────

  static const BorderRadius radiusSm   = BorderRadius.all(Radius.circular(8));
  static const BorderRadius radiusMd   = BorderRadius.all(Radius.circular(12));
  static const BorderRadius radiusLg   = BorderRadius.all(Radius.circular(16));
  static const BorderRadius radiusXl   = BorderRadius.all(Radius.circular(20));
  static const BorderRadius radiusXxl  = BorderRadius.all(Radius.circular(24));
  static const BorderRadius radiusFull = BorderRadius.all(Radius.circular(100));

  // Double values for when BorderRadius object isn't needed
  static const double radiusSmD  = 8.0;
  static const double radiusMdD  = 12.0;
  static const double radiusLgD  = 16.0;
  static const double radiusXlD  = 20.0;
  static const double radiusFullD= 100.0;

  // ──────────────────────────────────────────────────────────
  // COMPONENT DIMENSIONS
  // Fixed heights and sizes for reusable components.
  // Having these here means every button is the same height
  // regardless of which screen it's on.
  // ──────────────────────────────────────────────────────────

  // Buttons
  static const double buttonHeight   = 52.0; // primary & secondary buttons
  static const double buttonHeightSm = 40.0; // smaller action buttons

  // Inputs
  static const double inputHeight = 52.0; // text field height

  // Chips / filter pills
  static const double chipHeight    = 34.0;
  static const double chipPaddingH  = 14.0; // horizontal padding inside chip

  // Navigation
  static const double bottomNavHeight = 72.0; // includes home indicator area
  static const double appBarHeight    = 56.0;

  // Avatars
  static const double avatarXs = 28.0;
  static const double avatarSm = 36.0;
  static const double avatarMd = 44.0;
  static const double avatarLg = 64.0;
  static const double avatarXl = 80.0;

  // Icons
  static const double iconSm = 16.0;
  static const double iconMd = 20.0;
  static const double iconLg = 24.0;
  static const double iconXl = 32.0;

  // Cards
  static const double cardMinHeight    = 72.0;
  static const double heroCardHeight   = 160.0; // live class card
  static const double resourceCardH    = 68.0;
  static const double notifTileH       = 72.0;
  static const double settingTileH     = 52.0;

  // ──────────────────────────────────────────────────────────
  // BORDER WIDTHS
  // ──────────────────────────────────────────────────────────

  static const double borderThin   = 0.5; // dividers, subtle card borders
  static const double borderNormal = 1.0; // card borders, input borders
  static const double borderThick  = 2.0; // focused inputs
  static const double borderAccent = 3.0; // notification tile left border
}