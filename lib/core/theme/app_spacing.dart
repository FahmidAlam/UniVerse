import 'package:flutter/material.dart';

// PHASE 2: Obsidian Orbit 4px grid and layout tokens (Provisional).
abstract class AppSpacing {
  // PHASE 2 (PROVISIONAL): Strict 4px Scale Steps
  static const double xs   = 4.0;
  static const double sm   = 8.0;
  static const double md   = 12.0;
  static const double lg   = 16.0;
  static const double xl   = 20.0;
  static const double xxl  = 24.0;
  static const double xxxl = 32.0;
  static const double x3l  = 32.0;
  static const double x4l  = 40.0;
  static const double x5l  = 48.0;

  // PHASE 2 (PROVISIONAL): Explicit Semantic Spacing Constants
  /// Intra-group gap (8px) < Card inner padding (16px) < Section gap (24px).
  static const double gapIntraGroup = 8.0;
  static const double gapSection = 24.0;

  // Screen padding
  static const double screenH = 20.0;
  static const double screenV = 16.0;

  static const EdgeInsets screenPadding = EdgeInsets.symmetric(
    horizontal: screenH,
    vertical: screenV,
  );

  static const EdgeInsets screenPaddingScrollable = EdgeInsets.fromLTRB(
    screenH, screenV, screenH, 88.0,
  );

  static const EdgeInsets screenPaddingH = EdgeInsets.symmetric(
    horizontal: screenH,
  );

  // Card padding
  static const EdgeInsets cardPadding = EdgeInsets.all(16.0);
  static const EdgeInsets cardPaddingLg = EdgeInsets.all(20.0);
  static const EdgeInsets cardPaddingSm = EdgeInsets.all(12.0);
  static const EdgeInsets cardPaddingH = EdgeInsets.symmetric(
    horizontal: 16.0,
    vertical: 12.0,
  );

  // Gap widgets
  static const SizedBox xsGap = SizedBox(height: 4, width: 4);
  static const SizedBox smGap = SizedBox(height: 8);
  static const SizedBox smHGap = SizedBox(width: 8);
  static const SizedBox cardGap = SizedBox(height: 10);
  static const SizedBox cardHGap = SizedBox(width: 10);
  static const SizedBox mdGap = SizedBox(height: 12);
  static const SizedBox lgGap = SizedBox(height: 16);
  static const SizedBox sectionGap = SizedBox(height: 24);
  static const SizedBox xxlGap = SizedBox(height: 24);
  static const SizedBox x3lGap = SizedBox(height: 32);

  // PHASE 2 (PROVISIONAL): Consistent Border Radii (8px inner, 12px cards, 16px modals/sheets)
  static const BorderRadius radiusSm   = BorderRadius.all(Radius.circular(8));
  static const BorderRadius radiusMd   = BorderRadius.all(Radius.circular(12));
  static const BorderRadius radiusLg   = BorderRadius.all(Radius.circular(16));
  static const BorderRadius radiusXl   = BorderRadius.all(Radius.circular(20));
  static const BorderRadius radiusXxl  = BorderRadius.all(Radius.circular(24));
  static const BorderRadius radiusFull = BorderRadius.all(Radius.circular(100));

  static const double radiusSmD  = 8.0;
  static const double radiusMdD  = 12.0;
  static const double radiusLgD  = 16.0;
  static const double radiusXlD  = 20.0;
  static const double radiusFullD= 100.0;

  // PHASE 2 (PROVISIONAL): Control Heights
  /// Standard control height (48px default).
  static const double controlHeightDefault = 48.0;
  /// Primary auth / form inputs (52px).
  static const double controlHeightPrimary = 52.0;
  /// Compact filter bar controls with matched row heights (36px).
  static const double controlHeightCompact = 36.0;
  static const double controlHeightFilter  = 36.0;

  static const double buttonHeight   = 52.0;
  static const double buttonHeightSm = 36.0;
  static const double inputHeight    = 52.0;
  static const double chipHeight     = 36.0;
  static const double chipPaddingH   = 14.0;

  static const double bottomNavHeight = 72.0;
  static const double appBarHeight    = 56.0;

  static const double avatarXs = 28.0;
  static const double avatarSm = 36.0;
  static const double avatarMd = 44.0;
  static const double avatarLg = 64.0;
  static const double avatarXl = 80.0;

  static const double iconSm = 16.0;
  static const double iconMd = 20.0;
  static const double iconLg = 24.0;
  static const double iconXl = 32.0;

  static const double cardMinHeight    = 72.0;
  static const double heroCardHeight   = 160.0;
  static const double resourceCardH    = 68.0;
  static const double notifTileH       = 72.0;
  static const double settingTileH     = 52.0;

  static const double borderThin      = 1.0;
  static const double borderNormal    = 1.0;
  static const double borderThick     = 1.5;
  static const double borderFocus     = 1.5;
  static const double borderAccent    = 3.0;
  static const double borderHighlight = 1.0;
}
