import 'package:flutter/material.dart';
import 'package:universe/core/theme/app_motion.dart';

/// Observes pointers without competing with the child's gesture recognizers.
class UPressableScale extends StatefulWidget {
  final Widget child;
  final bool enabled;
  const UPressableScale({super.key, required this.child, this.enabled = true});
  @override
  State<UPressableScale> createState() => _UPressableScaleState();
}

class _UPressableScaleState extends State<UPressableScale> {
  final Set<int> _pointers = {};
  bool _hovered = false;
  void _release(int pointer) => setState(() => _pointers.remove(pointer));
  @override
  void didUpdateWidget(UPressableScale oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      _pointers.clear();
      _hovered = false;
    }
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
        onEnter: (_) {
          if (widget.enabled) setState(() => _hovered = true);
        },
        onExit: (_) => setState(() {
          _hovered = false;
          _pointers.clear();
        }),
        child: Listener(
          onPointerDown: (event) {
            if (widget.enabled) setState(() => _pointers.add(event.pointer));
          },
          onPointerUp: (event) => _release(event.pointer),
          onPointerCancel: (event) => _release(event.pointer),
          child: AnimatedScale(
            scale: !widget.enabled || AppMotion.reduced(context)
                ? 1
                : _pointers.isNotEmpty
                    ? .975
                    : _hovered
                        ? 1.012
                        : 1,
            duration: AppMotion.duration(context, AppMotion.micro),
            curve: AppMotion.snappy,
            child: widget.child,
          ),
        ),
      );
}
