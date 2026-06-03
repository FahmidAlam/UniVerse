import 'dart:async';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:universe_v1/core/constants/app_enums.dart';
import 'package:universe_v1/core/theme/app_colors.dart';
import 'package:universe_v1/core/theme/app_spacing.dart';
import 'package:universe_v1/core/theme/app_text_styles.dart';
import 'package:universe_v1/core/utils/date_utils.dart';
import 'package:universe_v1/shared/widgets/u_badge.dart';

class LiveClassCard extends StatefulWidget {
  final String subject;
  final String teacher;
  final String room;
  final DateTime endTime;

  const LiveClassCard({
    super.key,
    required this.subject,
    required this.teacher,
    required this.room,
    required this.endTime,
  });

  @override
  State<LiveClassCard> createState() => _LiveClassCardState();
}

class _LiveClassCardState extends State<LiveClassCard> {
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
    final remaining = widget.endTime.difference(DateTime.now());
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
        gradient: AppColors.primaryGradient,
        borderRadius: AppSpacing.radiusLg,
      ),
      child: ClipRRect(
        borderRadius: AppSpacing.radiusLg,
        child: Stack(
          children: [
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
                      const UBadge(status: ClassStatus.live),
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
                            color:
                                AppColors.textPrimary.withValues(alpha: 0.8),
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
          ],
        ),
      ),
    );
  }
}
