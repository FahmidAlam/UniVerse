import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:universe/core/theme/app_colors.dart';

// PHASE 3: Shared ambient mark; no auth timers or initialization delays.
class OrbitStatus extends StatefulWidget {
  const OrbitStatus(
      {super.key,
      required this.child,
      this.color = AppColors.primary,
      this.size = 88});
  final Widget child;
  final Color color;
  final double size;
  @override
  State<OrbitStatus> createState() => _OrbitStatusState();
}

class _OrbitStatusState extends State<OrbitStatus>
    with SingleTickerProviderStateMixin {
  late final motion =
      AnimationController(vsync: this, duration: const Duration(seconds: 10));
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      motion.stop();
      motion.value = .35;
    } else if (!motion.isAnimating) {
      motion.repeat();
    }
  }

  @override
  void dispose() {
    motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
      child: CustomPaint(
          painter: _Radar(motion, widget.color),
          child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: Center(child: widget.child))));
}

class _Radar extends CustomPainter {
  _Radar(this.motion, this.color) : super(repaint: motion);
  final Animation<double> motion;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
                  colors: [color.withValues(alpha: .10), Colors.transparent])
              .createShader(Offset.zero & size));
    for (var i = 0; i < 2; i++) {
      final r = radius * (.72 + i * .22);
      final angle = motion.value * math.pi * 2 * (i == 0 ? 1 : -1);
      canvas.drawCircle(
          center,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = AppColors.border);
      canvas.drawArc(
          Rect.fromCircle(center: center, radius: r),
          angle,
          math.pi * .9,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = color.withValues(alpha: .65));
      canvas.drawCircle(
          center + Offset(math.cos(angle) * r, math.sin(angle) * r),
          2.5,
          Paint()..color = i == 0 ? color : AppColors.info);
    }
  }

  @override
  bool shouldRepaint(_Radar oldDelegate) =>
      oldDelegate.color != color || oldDelegate.motion != motion;
}
