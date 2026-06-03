import 'package:flutter/material.dart';
import 'package:universe_v1/core/constants/app_enums.dart';
import 'package:universe_v1/core/theme/app_colors.dart';
import 'package:universe_v1/core/theme/app_spacing.dart';
import 'package:universe_v1/core/theme/app_text_styles.dart';

class UBadge extends StatefulWidget {
  final ClassStatus status;
  final String? customLabel;

  const UBadge({super.key, required this.status, this.customLabel});

  @override
  State<UBadge> createState() => _UBadgeState();
}

class _UBadgeState extends State<UBadge> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (widget.status == ClassStatus.live) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(UBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status == ClassStatus.live) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color get _color {
    switch (widget.status) {
      case ClassStatus.live:
        return AppColors.primary;
      case ClassStatus.next:
        return AppColors.info;
      case ClassStatus.done:
        return AppColors.done;
      case ClassStatus.cancelled:
        return AppColors.error;
      case ClassStatus.upcoming:
        return AppColors.success;
    }
  }

  String get _label {
    if (widget.customLabel != null) return widget.customLabel!.toUpperCase();
    switch (widget.status) {
      case ClassStatus.live:
        return 'LIVE';
      case ClassStatus.next:
        return 'NEXT';
      case ClassStatus.done:
        return 'DONE';
      case ClassStatus.cancelled:
        return 'CANCELLED';
      case ClassStatus.upcoming:
        return 'UPCOMING';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: AppSpacing.radiusSm,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.status == ClassStatus.live) ...[
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Opacity(
                opacity: _pulseAnim.value,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            _label,
            style: AppTextStyles.badge.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
