import 'dart:async';
import 'package:flutter/material.dart';
import 'package:universe/shared/widgets/u_card.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/core/utils/date_utils.dart';

// PHASE 4: Up-next session hero card with cyan analytical accent, countdown, and deterministic clock seam.
class NextClassCard extends StatefulWidget {
  final String subject;
  final String subtitle;
  final String room;
  final DateTime startTime;
  final String timeLabel;
  final String? cohortPill;
  final DateTime Function()? clock;

  const NextClassCard({
    super.key,
    required this.subject,
    required this.subtitle,
    required this.room,
    required this.startTime,
    required this.timeLabel,
    this.cohortPill,
    this.clock,
  });

  @override
  State<NextClassCard> createState() => _NextClassCardState();
}

class _NextClassCardState extends State<NextClassCard> {
  late Duration _remaining;
  Timer? _timer;

  DateTime get _now => widget.clock?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateRemaining(),
    );
  }

  @override
  void didUpdateWidget(covariant NextClassCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateRemaining();
  }

  void _updateRemaining() {
    final remaining = widget.startTime.difference(_now);
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
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSpacing.heroCardHeight),
      child: UCard(
        isTopLit: true,
        padding: EdgeInsets.zero,
        borderRadius: AppSpacing.radiusLg,
        child: Stack(
          children: [
            const Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 3,
              child: ColoredBox(color: AppColors.info),
            ),
            Padding(
              padding: AppSpacing.cardPaddingLg,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _UpNextPill(),
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
                          color: AppColors.infoSoft,
                          borderRadius: AppSpacing.radiusSm,
                          border: Border.all(
                            color: AppColors.info.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              PhosphorIconsRegular.mapPin,
                              size: AppSpacing.iconSm,
                              color: AppColors.info,
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
                                const Icon(
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
                                const Icon(
                                  PhosphorIconsRegular.clock,
                                  size: AppSpacing.iconSm,
                                  color: AppColors.textMuted,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Expanded(
                                  child: Text(
                                    widget.timeLabel,
                                    style: AppTextStyles.caption,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
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
            ),
          ],
        ),
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
