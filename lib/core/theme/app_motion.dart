import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

/// Shared motion policy. Content and controls remain usable without movement.
abstract final class AppMotion {
  static const micro = Duration(milliseconds: 140);
  static const fast = Duration(milliseconds: 220);
  static const medium = Duration(milliseconds: 340);
  static const slow = Duration(milliseconds: 520);
  static const snappy = Curves.easeOutCubic;
  static const magnetic = Curves.easeOutBack;
  static const fluid = Curves.easeInOutCubic;

  static bool reduced(BuildContext context) {
    final media = MediaQuery.maybeOf(context);
    return (media?.disableAnimations ?? false) ||
        (media?.accessibleNavigation ?? false) ||
        !TickerMode.valuesOf(context).enabled;
  }

  static Duration duration(BuildContext context, Duration normal) =>
      reduced(context) ? Duration.zero : normal;

  static void selectionHaptic(BuildContext context) {
    if (!kIsWeb && !reduced(context)) {
      HapticFeedback.selectionClick();
    }
  }

  static void lightImpactHaptic(BuildContext context) {
    if (!kIsWeb && !reduced(context)) {
      HapticFeedback.lightImpact();
    }
  }
}
