import 'dart:async' show Timer;

import 'package:flutter/material.dart';
import 'package:universe/core/theme/app_motion.dart';

/// PHASE C: Precision motion staggered entrance helper for lists.
/// Delays entrance by 30ms per row (capped at 6 rows) with a subtle vertical rise,
/// fully respecting reduced motion settings. Offscreen and index > 5 rows are
/// rendered immediately as a lightweight StatelessWidget without allocating AnimationControllers.
class UStaggeredListRow extends StatelessWidget {
  final int index;
  final Widget child;
  final Duration rowDuration;
  final int maxStaggerIndex;

  const UStaggeredListRow({
    super.key,
    required this.index,
    required this.child,
    this.rowDuration = const Duration(milliseconds: 240),
    this.maxStaggerIndex = 5,
  });

  @override
  Widget build(BuildContext context) {
    if (index > maxStaggerIndex || AppMotion.reduced(context)) {
      return child;
    }
    return _AnimatedStaggeredListRow(
      index: index,
      rowDuration: rowDuration,
      child: child,
    );
  }
}

class _AnimatedStaggeredListRow extends StatefulWidget {
  final int index;
  final Widget child;
  final Duration rowDuration;

  const _AnimatedStaggeredListRow({
    required this.index,
    required this.child,
    required this.rowDuration,
  });

  @override
  State<_AnimatedStaggeredListRow> createState() => _AnimatedStaggeredListRowState();
}

class _AnimatedStaggeredListRowState extends State<_AnimatedStaggeredListRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  Timer? _startTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.rowDuration,
    );

    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    final delayMs = widget.index * 30;
    if (delayMs <= 0) {
      _controller.forward();
    } else {
      _startTimer = Timer(Duration(milliseconds: delayMs), () {
        if (mounted) {
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: widget.child,
      ),
    );
  }
}
