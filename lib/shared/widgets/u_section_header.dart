import 'package:flutter/material.dart';
import 'package:universe/core/theme/app_text_styles.dart';

class USectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;
  final String seeAllLabel;

  const USectionHeader({
    super.key,
    required this.title,
    this.onSeeAll,
    this.seeAllLabel = 'See all',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: AppTextStyles.h3),
        if (onSeeAll != null) ...[
          const Spacer(),
          GestureDetector(
            onTap: onSeeAll,
            child: Text(seeAllLabel, style: AppTextStyles.link),
          ),
        ],
      ],
    );
  }
}
