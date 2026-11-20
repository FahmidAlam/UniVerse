import 'dart:async';
import 'package:flutter/material.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/core/constants/app_enums.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/core/utils/date_utils.dart';
import 'package:universe/shared/widgets/u_badge.dart';

// PHASE 4: Live session hero card with real startTime/endTime progress bar and room/cohort pills.
class LiveClassCard extends StatefulWidget {
  final String subject;
  final String teacher;
  final String room;
  final DateTime endTime;
  final DateTime? startTime;
  final String? cohortPill;

  /// Optional clock for deterministic previews/tests; defaults to wall time.
  final DateTime Function()? clock;

  const LiveClassCard({
    super.key,
    required this.subject,
    required this.teacher,
    required this.room,
    required this.endTime,
    this.startTime,
    this.cohortPill,
    this.clock,
  });

  @override
  State<LiveClassCard> createState() => _LiveClassCardState();
}

class _LiveClassCardState extends State<LiveClassCard> {
  late Duration _remaining;
  Timer? _timer;

  DateTime get _now => widget.clock?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _remaining = _remainingAt(_now);
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateRemaining(),
    );
  }

  Duration _remainingAt(DateTime now) {
    final remaining = widget.endTime.difference(now);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool get _active =>
      _remaining > Duration.zero &&
      (widget.startTime == null || !_now.isBefore(widget.startTime!));

  @override
  void didUpdateWidget(covariant LiveClassCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _remaining = _remainingAt(_now);
  }

  void _updateRemaining() {
    final remaining = widget.endTime.difference(_now);
    if (mounted) {
      setState(() {
        _remaining = remaining.isNegative ? Duration.zero : remaining;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: AppSpacing.heroCardHeight),
      decoration: BoxDecoration(
        gradient: AppColors.cardIdleGradient,
        boxShadow: AppColors.dualElevationShadow,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.45)),
        borderRadius: AppSpacing.radiusLg,
      ),
      child: ClipRRect(
        borderRadius: AppSpacing.radiusLg,
        child: Stack(
          children: [
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 1,
              child: ColoredBox(color: AppColors.specular),
            ),
            const Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 3,
              child: ColoredBox(color: AppColors.primary),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: AppColors.cardOverlay,
                ),
              ),
            ),
            Padding(
              padding: AppSpacing.cardPaddingLg,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      UBadge(status: ClassStatus.live, animate: _active),
                      if (widget.cohortPill != null &&
                          widget.cohortPill!.isNotEmpty) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.bgElevated,
                              borderRadius: AppSpacing.radiusSm,
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              widget.cohortPill!,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ] else
                        const Spacer(),
                      if (widget.cohortPill != null &&
                          widget.cohortPill!.isNotEmpty)
                        const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: AppSpacing.radiusSm,
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              PhosphorIconsRegular.mapPin,
                              size: AppSpacing.iconSm,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              widget.room,
                              style: AppTextStyles.roomCode.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    widget.subject,
                    style: AppTextStyles.h2.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  AppSpacing.smGap,
                  Row(
                    children: [
                      Icon(
                        PhosphorIconsRegular.userCircle,
                        size: AppSpacing.iconSm,
                        color: AppColors.textPrimary.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          widget.teacher,
                          style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.textPrimary.withValues(alpha: 0.8),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            AppDateUtils.formatCountdown(_remaining),
                            style: AppTextStyles.countdown.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            'left',
                            style: AppTextStyles.countdownUnit.copyWith(
                              color:
                                  AppColors.textPrimary.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (widget.startTime != null &&
                widget.endTime.isAfter(widget.startTime!))
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: LinearProgressIndicator(
                  minHeight: 3,
                  value: (_now.difference(widget.startTime!).inMilliseconds /
                          widget.endTime
                              .difference(widget.startTime!)
                              .inMilliseconds)
                      .clamp(0.0, 1.0),
                  color: AppColors.primary,
                  backgroundColor: AppColors.bgElevated,
                  semanticsLabel: 'Class elapsed',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
