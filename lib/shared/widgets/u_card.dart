import 'package:flutter/material.dart';
import 'package:universe/core/theme/app_motion.dart';
import 'package:universe/shared/widgets/u_pressable_scale.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';

// PHASE 2: Cohesive UCard with selective top-lit highlight and Obsidian Orbit surface depth.
class UCard extends StatefulWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final Color? color;
  final Border? border;
  // PHASE 2 (PROVISIONAL): Optional top-lit specular highlight (~7% white top edge)
  final bool isTopLit;
  // PHASE 2 (PROVISIONAL): Elevated surface variant (#1F2229)
  final bool elevated;

  const UCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.onTap,
    this.color,
    this.border,
    this.isTopLit = false,
    this.elevated = false,
  });

  @override
  State<UCard> createState() => _UCardState();
}

class _UCardState extends State<UCard> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? AppSpacing.radiusMd;
    final pad = widget.padding ?? AppSpacing.cardPadding;
    final lit = widget.isTopLit || widget.onTap != null;
    final interactive = widget.onTap != null;
    final bg = widget.color ??
        (widget.elevated ? AppColors.surfaceElevated : AppColors.surface);
    final content = Padding(padding: pad, child: widget.child);
    final inner = interactive
        ? Material(
            color: Colors.transparent,
            child: InkWell(
                onTap: widget.onTap, borderRadius: radius, child: content),
          )
        : content;
    return Padding(
      padding: widget.margin ?? EdgeInsets.zero,
      child: MouseRegion(
        onEnter: (_) {
          if (interactive) setState(() => _hovered = true);
        },
        onExit: (_) {
          if (_hovered) setState(() => _hovered = false);
        },
        child: UPressableScale(
          enabled: interactive,
          child: AnimatedContainer(
            duration: AppMotion.duration(context, AppMotion.micro),
            curve: AppMotion.snappy,
            decoration: BoxDecoration(
              color: bg,
              gradient: lit && widget.color == null && !widget.elevated
                  ? (_hovered
                      ? AppColors.cardHoverGradient
                      : AppColors.cardIdleGradient)
                  : null,
              borderRadius: radius,
              border: widget.border ?? Border.all(color: AppColors.border),
              boxShadow: lit ? AppColors.dualElevationShadow : null,
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: lit
                  ? Stack(children: [
                      inner,
                      Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: 1,
                          child: IgnorePointer(
                              child: AnimatedContainer(
                            duration:
                                AppMotion.duration(context, AppMotion.micro),
                            color: _hovered
                                ? AppColors.specularHover
                                : AppColors.specular,
                          ))),
                    ])
                  : inner,
            ),
          ),
        ),
      ),
    );
  }
}
