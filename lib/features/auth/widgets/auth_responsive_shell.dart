import 'package:flutter/material.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'routine_convergence_showcase.dart';

// PHASE 3: Full-bleed presentation; screens retain auth and navigation ownership.
class AuthResponsiveShell extends StatelessWidget {
  const AuthResponsiveShell(
      {super.key,
      required this.child,
      this.stage,
      this.onStageChanged,
      this.scrollContent = true,
      this.title,
      this.onBack,
      this.headerTrailing,
      this.previewBatch,
      this.previewSection,
      this.previewTeacherCode});
  final Widget child;
  final int? stage;
  final ValueChanged<int>? onStageChanged;
  final bool scrollContent;
  final String? title, previewBatch, previewSection, previewTeacherCode;
  final VoidCallback? onBack;
  final Widget? headerTrailing;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, bounds) {
        final split = bounds.maxWidth >= 920;
        final expanded = bounds.maxWidth >= 1100;
        final header = Row(children: [
          if (onBack != null)
            IconButton.outlined(
                onPressed: onBack,
                tooltip: 'Back',
                style: IconButton.styleFrom(minimumSize: const Size(88, 48)),
                icon: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.arrow_back),
                  SizedBox(width: 8),
                  Text('Back')
                ])),
          if (onBack != null) const SizedBox(width: 12),
          if (title != null)
            Expanded(
                child: Text(title!,
                    style: Theme.of(context).textTheme.labelLarge)),
          if (headerTrailing != null) headerTrailing!,
        ]);
        final card = Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.authCardTop, AppColors.authCardBottom]),
                border: Border.all(color: AppColors.border),
                boxShadow: AppColors.dualElevationShadow),
            foregroundDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border:
                    const Border(top: BorderSide(color: AppColors.specular))),
            child: child);
        final showcase = RoutineConvergenceShowcase(
            stage: stage,
            onStageChanged: onStageChanged,
            compact: !split,
            interactive: stage == null || onStageChanged != null,
            previewBatch: previewBatch,
            previewSection: previewSection,
            previewTeacherCode: previewTeacherCode);
        Widget panel = Column(mainAxisSize: MainAxisSize.min, children: [
          if (title != null || onBack != null || headerTrailing != null) ...[
            header,
            const SizedBox(height: 24)
          ],
          card
        ]);
        panel = Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: panel));
        if (split) {
          return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
                flex: expanded ? 58 : 50,
                child: Center(
                    child: SingleChildScrollView(
                        padding: const EdgeInsets.all(28),
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 760),
                            child: showcase)))),
            Container(
                width: 1,
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                      AppColors.border,
                      AppColors.primary.withValues(alpha: .22),
                      AppColors.border
                    ]))),
            Expanded(
                flex: expanded ? 42 : 50,
                child: SingleChildScrollView(
                    padding: const EdgeInsets.all(28),
                    child: ConstrainedBox(
                        constraints: BoxConstraints(
                            minHeight: (bounds.maxHeight - 56)
                                .clamp(0, double.infinity)),
                        child: panel))),
          ]);
        }
        return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              if (bounds.maxWidth >= 768) ...[
                showcase,
                const SizedBox(height: 24)
              ],
              panel
            ]));
      });
}
