import 'dart:async';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/core/utils/date_utils.dart';

class NextClassCard extends StatefulWidget {
  final String subject;
  final String subtitle;
  final String room;
  final DateTime startTime;
  final String timeLabel;

  const NextClassCard({
    super.key,
    required this.subject,
    required this.subtitle,
    required this.room,
    required this.startTime,
    required this.timeLabel,
  });

  @override
  State<NextClassCard> createState() => _NextClassCardState();
}

class _NextClassCardState extends State<NextClassCard> {
  late Duration _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateRemaining(),
    );
  }

  void _updateRemaining() {
    final remaining = widget.startTime.difference(DateTime.now());
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
      padding: AppSpacing.cardPaddingLg,
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppSpacing.radiusLg,
        border: Border.all(
          color: AppColors.info.withValues(alpha: 0.35),
          width: AppSpacing.borderNormal,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _UpNextPill(),
              const Spacer(),
              Icon(
                PhosphorIconsRegular.mapPin,
                size: AppSpacing.iconSm,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(widget.room, style: AppTextStyles.bodySm),
            ],
          ),
          const Spacer(),
          Text(
            widget.subject,
            style: AppTextStyles.h2,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          AppSpacing.smGap,
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          PhosphorIconsRegular.userCircle,
                          size: AppSpacing.iconSm,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            widget.subtitle,
                            style: AppTextStyles.bodySm,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Icon(
                          PhosphorIconsRegular.clock,
                          size: AppSpacing.iconSm,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(widget.timeLabel, style: AppTextStyles.caption),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'starts in',
                    style: AppTextStyles.caption,
                  ),
                  Text(
                    AppDateUtils.formatCountdown(_remaining),
                    style: AppTextStyles.countdown.copyWith(
                      color: AppColors.info,
                      fontSize: 26,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UpNextPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.15),
        borderRadius: AppSpacing.radiusSm,
        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
      ),
      child: Text(
        'UP NEXT',
        style: AppTextStyles.badge.copyWith(color: AppColors.info),
      ),
    );
  }
}
