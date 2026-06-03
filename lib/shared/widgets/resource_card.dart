import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:universe_v1/core/theme/app_colors.dart';
import 'package:universe_v1/core/theme/app_spacing.dart';
import 'package:universe_v1/core/theme/app_text_styles.dart';
import 'package:universe_v1/shared/widgets/u_card.dart';

enum ResourceType { pdf, drive }

class ResourceCard extends StatelessWidget {
  final String title;
  final String subject;
  final String category;
  final ResourceType type;
  final VoidCallback onTap;

  const ResourceCard({
    super.key,
    required this.title,
    required this.subject,
    required this.category,
    required this.type,
    required this.onTap,
  });

  IconData get _icon => type == ResourceType.pdf
      ? PhosphorIconsRegular.filePdf
      : PhosphorIconsRegular.link;

  Color get _iconColor =>
      type == ResourceType.pdf ? AppColors.error : AppColors.info;

  @override
  Widget build(BuildContext context) {
    return UCard(
      padding: AppSpacing.cardPaddingH,
      onTap: onTap,
      child: SizedBox(
        height: AppSpacing.resourceCardH - AppSpacing.md * 2,
        child: Row(
          children: [
            Container(
              width: AppSpacing.avatarMd,
              height: AppSpacing.avatarMd,
              decoration: BoxDecoration(
                color: _iconColor.withValues(alpha: 0.12),
                borderRadius: AppSpacing.radiusSm,
              ),
              child: Icon(_icon, size: AppSpacing.iconMd, color: _iconColor),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '$subject · $category',
                    style: AppTextStyles.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Icon(
              PhosphorIconsRegular.caretRight,
              size: AppSpacing.iconSm,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
