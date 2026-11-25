import 'package:flutter/material.dart';
import 'package:universe/core/theme/app_motion.dart';

/// Key the child by content identity; stateful descendants keep their own state.
class UAnimatedSwap extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Duration? reverseDuration;
  final Axis axis;

  const UAnimatedSwap({
    super.key,
    required this.child,
    this.duration = AppMotion.medium,
    this.reverseDuration,
    this.axis = Axis.vertical,
  });

  @override
  Widget build(BuildContext context) {
    // Bypass the switcher entirely so outgoing content/tickers disappear now.
    if (AppMotion.reduced(context)) return child;
    final effectiveReverse = reverseDuration ??
        Duration(milliseconds: (duration.inMilliseconds * 0.8).round());

    return RepaintBoundary(
      child: AnimatedSwitcher(
        duration: duration,
        reverseDuration: effectiveReverse,
        switchInCurve: AppMotion.snappy,
        switchOutCurve: AppMotion.snappy,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: axis == Axis.vertical
                  ? const Offset(0, .035)
                  : const Offset(.04, 0),
              end: Offset.zero,
            ).animate(animation),
            child: ScaleTransition(
              scale: Tween<double>(begin: .985, end: 1).animate(animation),
              child: child,
            ),
          ),
        ),
        child: child,
      ),
    );
  }
}
