import 'package:flutter/material.dart';
import 'package:universe_v1/core/theme/app_colors.dart';
import 'package:universe_v1/core/theme/app_spacing.dart';

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
    )..repeat(reverse: true);

    _colorAnim = ColorTween(
      begin: AppColors.bgCard,
      end: AppColors.bgElevated,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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
          valueColor: AlwaysStoppedAnimation(
            widget.color ?? AppColors.primary,
          ),
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
