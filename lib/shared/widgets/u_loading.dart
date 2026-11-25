import 'package:flutter/material.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';

// PHASE 2: Cohesive loading presenters (spinner and skeleton shimmer),
// aligned to Obsidian Orbit surface tokens and respecting reduced motion.
class ULoading extends StatefulWidget {
  final bool _isSkeleton;
  final Color? color;
  final double? skeletonWidth;
  final double? skeletonHeight;
  final BorderRadius? skeletonRadius;

  const ULoading.spinner({super.key, this.color})
      : _isSkeleton = false,
        skeletonWidth = null,
        skeletonHeight = null,
        skeletonRadius = null;

  const ULoading.skeleton({
    super.key,
    this.skeletonWidth,
    this.skeletonHeight,
    this.skeletonRadius,
  })  : _isSkeleton = true,
        color = null;

  @override
  State<ULoading> createState() => _ULoadingState();
}

class _ULoadingState extends State<ULoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _colorAnim = ColorTween(
      begin: AppColors.surface,
      end: AppColors.surfaceElevated,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool disableAnims =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disableAnims) {
      if (_controller.isAnimating) {
        _controller.stop();
      }
      _controller.value = 1.0;
    } else if (widget._isSkeleton && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget._isSkeleton) {
      return Center(
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(
            widget.color ?? AppColors.primary,
          ),
        ),
      );
    }

    final bool disableAnims =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (disableAnims) {
      return Container(
        width: widget.skeletonWidth ?? double.infinity,
        height: widget.skeletonHeight ?? AppSpacing.cardMinHeight,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: widget.skeletonRadius ?? AppSpacing.radiusMd,
        ),
      );
    }

    return AnimatedBuilder(
      animation: _colorAnim,
      builder: (_, __) => Container(
        width: widget.skeletonWidth ?? double.infinity,
        height: widget.skeletonHeight ?? AppSpacing.cardMinHeight,
        decoration: BoxDecoration(
          color: _colorAnim.value,
          borderRadius: widget.skeletonRadius ?? AppSpacing.radiusMd,
        ),
      ),
    );
  }
}
