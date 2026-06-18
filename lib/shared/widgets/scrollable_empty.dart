// ============================================================
// FILE: lib/shared/widgets/scrollable_empty.dart
// PURPOSE: Wraps an empty/error state (typically a UEmptyState)
// so it sits vertically centered AND remains pull-to-refreshable.
// A RefreshIndicator needs a scrollable child; this fills the
// viewport height and centers its content without magic-number
// spacers. Use: RefreshIndicator(child: ScrollableEmpty(child: …)).
// ============================================================

import 'package:flutter/material.dart';

class ScrollableEmpty extends StatelessWidget {
  final Widget child;

  const ScrollableEmpty({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: child),
        ),
      ),
    );
  }
}
