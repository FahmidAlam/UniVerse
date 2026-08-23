import 'package:flutter/material.dart';

abstract class AppColors {


  static const Color bgPrimary = Color(0xFF0F0F10);

  static const Color bgCard = Color(0xFF1A1A1C);

  static const Color bgElevated = Color(0xFF222325);

  static const Color bgSubtle = Color(0xFF1C1C1E);


  static const Color primary = Color(0xFFFF7A00);

  static const Color primaryDark = Color(0xFFE66A00);

  static const Color primarySoft = Color(0xFF2A1A0A);

  static const Color primaryMuted = Color(0xFF3D2000);


  static const Color textPrimary = Color(0xFFFFFFFF);

  static const Color textSecondary = Color(0xFFB0B3B8);

  static const Color textMuted = Color(0xFF6E7278);

  static const Color textDisabled = Color(0xFF4A4D52);


  static const Color border = Color(0xFF2A2C30);

  static const Color borderFocus = Color(0xFFFF7A00);

  static const Color borderError = Color(0xFFEF4444);


  static const Color success = Color(0xFF22C55E);

  static const Color successSoft = Color(0xFF0D2E1A);

  static const Color info = Color(0xFF3B82F6);

  static const Color infoSoft = Color(0xFF0D1F3C);

  static const Color warning = Color(0xFFF59E0B);

  static const Color warningSoft = Color(0xFF2D1E00);

  static const Color error = Color(0xFFEF4444);

  static const Color errorSoft = Color(0xFF2D0D0D);

  static const Color done = Color(0xFF6E7278);

  static const Color doneSoft = Color(0xFF1A1C1F);


  static const Color notifCancel  = Color(0xFFEF4444);
  static const Color notifTest    = Color(0xFFF59E0B);
  static const Color notifExam    = Color(0xFFFF7A00);
  static const Color notifRoom    = Color(0xFF3B82F6);
  static const Color notifHoliday = Color(0xFF6E7278);
  static const Color notifAssign  = Color(0xFF22C55E);


  static const Color roleStudent = Color(0xFF22C55E);
  static const Color roleTeacher = Color(0xFF3B82F6);
  static const Color roleAdmin   = Color(0xFFFF7A00);


  static const Color navBg         = Color(0xFF111113);

  static const Color navActive      = Color(0xFFFF7A00);

  static const Color navInactive    = Color(0xFF6E7278);

  static const Color navBadge       = Color(0xFFEF4444);


  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFF7A00), Color(0xFFE64D00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardOverlay = LinearGradient(
    colors: [Color(0x001A1A1C), Color(0x801A1A1C)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );


  static Color withOpacity(Color color, double opacity) =>
      color.withValues(alpha: opacity);
}
