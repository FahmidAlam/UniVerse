import 'package:flutter/material.dart';

// PHASE 2: Obsidian Orbit visual design system tokens (Provisional).
// All exact tokens remain provisional until reviewed on representative screens.
abstract class AppColors {
  static const specularHover = Color(0x38FFFFFF);
  static const cardIdleGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1A1D24), Color(0xFF15171C)],
  );
  static const cardHoverGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF222630), Color(0xFF181B22)],
  );
  static const dualElevationShadow = <BoxShadow>[
    BoxShadow(color: Color(0x59000000), blurRadius: 8, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 12)),
  ];
  // PHASE 3: Approved top-lit instrument surfaces.
  static const instrumentTop = Color(0xFF1C1F26);
  static const instrumentBottom = Color(0xFF15171C);
  static const authCardTop = Color(0xFF15181F);
  static const authCardBottom = Color(0xFF12141A);
  static const specular = Color(0x1AFFFFFF);

  // PHASE 2 (PROVISIONAL): Obsidian Orbit Surface & Perceptual Depth Ramp
  /// Base background (#0B0C0E) - deepest canvas level.
  static const Color bgPrimary = Color(0xFF0B0C0E);
  static const Color background = bgPrimary;
  static const Color bgDark = bgPrimary;

  /// Subtle / navigation rail / secondary background (#121417).
  static const Color bgSubtle = Color(0xFF121417);
  static const Color surfaceSubtle = bgSubtle;

  /// Standard card surface (#17191E).
  static const Color bgCard = Color(0xFF17191E);
  static const Color surface = bgCard;
  static const Color cardBg = bgCard;

  /// Elevated / modal / sheet / popover surface (#1F2229).
  static const Color bgElevated = Color(0xFF1F2229);
  static const Color surfaceElevated = bgElevated;
  static const Color elevatedCard = bgElevated;

  /// Interactive hover / selected surface (#272B33).
  static const Color surfaceInteractive = Color(0xFF272B33);

  // PHASE 2 (PROVISIONAL): Signature Accent & Interaction States
  /// UniVerse primary orange (#FF7A00).
  static const Color primary = Color(0xFFFF7A00);

  /// Primary hover state (#FF8F26).
  static const Color primaryHover = Color(0xFFFF8F26);

  /// Primary pressed / active state (#E66A00).
  static const Color primaryPressed = Color(0xFFE66A00);

  /// Backward-compatibility alias for primary pressed.
  static const Color primaryDark = Color(0xFFE66A00);

  /// Dimmed primary container fill (#302007) for active chips, pills, and indicators.
  static const Color primarySoft = Color(0xFF302007);

  /// Deep primary container fill (#3D2000).
  static const Color primaryMuted = Color(0xFF3D2000);

  // PHASE 2 (PROVISIONAL): Text Hierarchy & WCAG Contrast Fixes
  /// Crisp off-white (#F3F4F6) to prevent pure-white halation on #0B0C0E (17.8:1 contrast).
  static const Color textPrimary = Color(0xFFF3F4F6);

  /// Secondary text (#B8BCC6) for supporting labels and metadata (10.3:1 contrast).
  static const Color textSecondary = Color(0xFFB8BCC6);

  /// Muted / caption text (#8A909E) boosted to comfortably exceed 4.5:1 (6.2:1 against bg, 5.6:1 against surface).
  static const Color textMuted = Color(0xFF8A909E);
  static const Color textTertiary = textMuted;

  /// Disabled text (#525866) on dark surfaces.
  static const Color textDisabled = Color(0xFF525866);

  /// High-contrast text/icon foreground on #FF7A00 primary orange (#0B0C0E, 7.5:1 contrast).
  static const Color textOnPrimary = Color(0xFF0B0C0E);

  // PHASE 2 (PROVISIONAL): Borders & Specular Highlight
  /// Standard 1px card and divider border (#262932).
  static const Color border = Color(0xFF262932);
  static const Color divider = border;

  /// Subtle top-edge specular highlight (~7% white, 0x12FFFFFF) for selective top-lit cards.
  static const Color borderHighlight = Color(0x12FFFFFF);
  static const Color topHighlight = borderHighlight;

  /// Accessible focus ring (#FF7A00).
  static const Color borderFocus = Color(0xFFFF7A00);
  static const Color focusRing = borderFocus;

  /// Form error border (#EF4444).
  static const Color borderError = Color(0xFFEF4444);

  // PHASE 2 (PROVISIONAL): Semantic Status Tokens (Foreground + Dimmed Containers)
  /// Success foreground (#10B981).
  static const Color success = Color(0xFF10B981);

  /// Success container fill (#062E22).
  static const Color successSoft = Color(0xFF062E22);
  static const Color successContainer = successSoft;

  /// Info / Analytical Accent foreground (#38BDF8).
  static const Color info = Color(0xFF38BDF8);

  /// Info container fill (#0F2342).
  static const Color infoSoft = Color(0xFF0F2342);
  static const Color infoContainer = infoSoft;

  /// Warning foreground (#F59E0B).
  static const Color warning = Color(0xFFF59E0B);

  /// Warning container fill (#302007).
  static const Color warningSoft = Color(0xFF302007);
  static const Color warningContainer = warningSoft;

  /// Error foreground (#EF4444).
  static const Color error = Color(0xFFEF4444);

  /// Error container fill (#331014).
  static const Color errorSoft = Color(0xFF331014);
  static const Color errorContainer = errorSoft;

  /// Completed state tokens.
  static const Color done = Color(0xFF8A909E);
  static const Color doneSoft = Color(0xFF1F2229);

  // Notifications category mapping
  static const Color notifCancel = Color(0xFFEF4444);
  static const Color notifTest = Color(0xFFF59E0B);
  static const Color notifExam = Color(0xFFFF7A00);
  static const Color notifRoom = Color(0xFF38BDF8);
  static const Color notifHoliday = Color(0xFF8A909E);
  static const Color notifAssign = Color(0xFF10B981);

  // Role accents
  static const Color roleStudent = Color(0xFF10B981);
  static const Color roleTeacher = Color(0xFF38BDF8);
  static const Color roleAdmin = Color(0xFFFF7A00);

  // Navigation tokens
  static const Color navBg = Color(0xFF121417);
  static const Color navActive = Color(0xFFFF7A00);
  static const Color navInactive = Color(0xFF8A909E);
  static const Color navBadge = Color(0xFFEF4444);

  // Retained gradient overlays
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFF7A00), Color(0xFFE66A00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardOverlay = LinearGradient(
    colors: [Color(0x0017191E), Color(0x8017191E)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static Color withOpacity(Color color, double opacity) =>
      color.withValues(alpha: opacity);
}
