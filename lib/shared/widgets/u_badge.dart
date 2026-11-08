import 'package:flutter/material.dart';
import 'package:universe/core/theme/app_motion.dart';
import 'package:universe/core/constants/app_enums.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';

// PHASE 2: Status badge with dimmed semantic container fills and high-contrast foreground,
// respecting reduced motion preferences.
class UBadge extends StatefulWidget {
  final ClassStatus status;
  final String? customLabel;
  final bool animate;

  const UBadge(
      {super.key, required this.status, this.customLabel, this.animate = true});

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
      duration: AppMotion.slow * 2,
    );
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: AppMotion.fluid),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool disableAnims = AppMotion.reduced(context);
    if (disableAnims || !widget.animate) {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
      }
      _pulseController.value = 1.0;
    } else if (widget.status == ClassStatus.live &&
        !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(UBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool disableAnims = AppMotion.reduced(context);
    if (disableAnims || !widget.animate) {
      _pulseController.stop();
      _pulseController.value = 1.0;
    } else if (widget.status == ClassStatus.live) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
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

  Color get _foregroundColor {
    switch (widget.status) {
      case ClassStatus.live:
        return AppColors.primary;
      case ClassStatus.next:
        return AppColors.info;
      case ClassStatus.done:
        return AppColors.textMuted;
      case ClassStatus.cancelled:
        return AppColors.error;
      case ClassStatus.upcoming:
        return AppColors.success;
    }
  }

  Color get _containerColor {
    switch (widget.status) {
      case ClassStatus.live:
        return AppColors.primarySoft;
      case ClassStatus.next:
        return AppColors.infoSoft;
      case ClassStatus.done:
        return AppColors.surfaceElevated;
      case ClassStatus.cancelled:
        return AppColors.errorSoft;
      case ClassStatus.upcoming:
        return AppColors.successSoft;
    }
  }

  Color get _borderColor {
    switch (widget.status) {
      case ClassStatus.live:
        return const Color(0x66FF7A00);
      case ClassStatus.next:
        return const Color(0x6638BDF8);
      case ClassStatus.done:
        return AppColors.border;
      case ClassStatus.cancelled:
        return const Color(0x66EF4444);
      case ClassStatus.upcoming:
        return const Color(0x6610B981);
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
    final fg = _foregroundColor;
    final bg = _containerColor;
    final border = _borderColor;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppSpacing.radiusSm,
        border: Border.all(color: border, width: AppSpacing.borderThin),
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
                    color: fg,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            _label,
            style: AppTextStyles.badge.copyWith(color: fg),
          ),
        ],
      ),
    );
  }
}
