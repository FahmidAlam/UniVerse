import 'package:flutter/material.dart';
import 'package:universe_v1/core/theme/app_colors.dart';
import 'package:universe_v1/core/theme/app_spacing.dart';
import 'package:universe_v1/core/theme/app_text_styles.dart';

class UDivider extends StatelessWidget {
  final bool vertical;
  final double? indent;
  final String? label;

  const UDivider({
    super.key,
    this.vertical = false,
    this.indent,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    if (vertical) {
      return Container(
        width: AppSpacing.borderThin,
        color: AppColors.border,
        margin: EdgeInsets.symmetric(horizontal: indent ?? 0),
      );
    }

    if (label != null) {
      return Row(
        children: [
          const Expanded(
            child: Divider(
              color: AppColors.border,
              thickness: AppSpacing.borderThin,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(label!, style: AppTextStyles.caption),
          ),
          const Expanded(
            child: Divider(
              color: AppColors.border,
              thickness: AppSpacing.borderThin,
            ),
          ),
        ],
      );
    }

    return Divider(
      color: AppColors.border,
      thickness: AppSpacing.borderThin,
      indent: indent,
      endIndent: indent,
    );
  }
}
