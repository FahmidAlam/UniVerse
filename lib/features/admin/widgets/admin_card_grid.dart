import 'package:flutter/material.dart';
import 'package:universe/core/theme/app_spacing.dart';

// PHASE 5: Uses the width remaining after sidebar and page padding, including at zoom.
class AdminCardGrid extends StatelessWidget {
  final List<Widget> children;
  const AdminCardGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
        final columns = (constraints.maxWidth / (210 * scale.clamp(1, 2)))
            .floor()
            .clamp(1, 4);
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          mainAxisExtent: 160 * scale.clamp(1, 3),
          children: children,
        );
      });
}
