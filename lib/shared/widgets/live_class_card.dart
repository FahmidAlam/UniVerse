import 'dart:async';
import 'package:flutter/material.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/core/constants/app_enums.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/core/utils/date_utils.dart';
import 'package:universe/shared/widgets/u_badge.dart';

class LiveClassCard extends StatefulWidget {
  final String subject;
  final String teacher;
  final String room;
  final DateTime endTime;
  final DateTime? startTime;

  /// Optional clock for deterministic previews/tests; defaults to wall time.
  final DateTime Function()? clock;

  const LiveClassCard({
    super.key,
    required this.subject,
    required this.teacher,
    required this.room,
    required this.endTime,
    this.startTime,
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
      height: AppSpacing.heroCardHeight,
      decoration: BoxDecoration(
        gradient: AppColors.cardIdleGradient,
        boxShadow: AppColors.dualElevationShadow,
        border: Border.all(color: AppColors.border),
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
                child: ColoredBox(color: AppColors.specular)),
            Container(
              decoration: const BoxDecoration(
                gradient: AppColors.cardOverlay,
              ),
            ),
            Padding(
              padding: AppSpacing.cardPaddingLg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      UBadge(status: ClassStatus.live, animate: _active),
                      const Spacer(),
                      Icon(
                        PhosphorIconsRegular.mapPin,
                        size: AppSpacing.iconSm,
                        color: AppColors.textPrimary.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        widget.room,
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.textPrimary.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
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
