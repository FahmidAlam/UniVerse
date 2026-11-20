import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:universe/shared/widgets/u_segmented_control.dart';

/// URL-backed sibling destinations; selection follows the active route.
class AdminRouteTabs extends StatelessWidget {
  final String selected;
  final Map<String, String> destinations;
  const AdminRouteTabs(
      {super.key, required this.selected, required this.destinations});
  @override
  Widget build(BuildContext context) => USegmentedControl<String>(
        selected: selected,
        segments: [
          for (final entry in destinations.entries)
            USegment(value: entry.key, label: entry.value)
        ],
        onChanged: (route) {
          if (route != selected) context.go(route);
        },
      );
}

/// Shared non-interactive count, separate from selectable filter chips.
class AdminMatchCount extends StatelessWidget {
  final String label;
  const AdminMatchCount({super.key, required this.label});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
            color: AppColors.bgSubtle,
            border: Border.all(color: AppColors.border),
            borderRadius: AppSpacing.radiusFull),
        child: Text(label, style: AppTextStyles.caption),
      );
}
