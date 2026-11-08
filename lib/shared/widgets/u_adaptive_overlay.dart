import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_motion.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';

/// Opens a centered top-lit modal dialog on Desktop/Tablet (`>= 768px`)
/// and a single-handle floating bottom sheet on Mobile (`< 768px`).
Future<T?> showUAdaptiveModal<T>({
  required BuildContext context,
  required String title,
  String? subtitle,
  String? badge,
  IconData? icon,
  Color? accentColor,
  required WidgetBuilder builder,
  List<Widget>? actions,
  double maxDesktopWidth = 480,
}) {
  final isDesktop = MediaQuery.sizeOf(context).width >= 768;
  final reduced = AppMotion.reduced(context);

  if (isDesktop) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: title,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      transitionDuration:
          reduced ? Duration.zero : const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, _, __) => CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              Navigator.of(dialogContext).maybePop(),
        },
        child: Focus(
          autofocus: true,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxDesktopWidth),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Material(
                  color: Colors.transparent,
                  child: UAdaptiveSheetDialog(
                    title: title,
                    subtitle: subtitle,
                    badge: badge,
                    icon: icon,
                    accentColor: accentColor,
                    isDesktopModal: true,
                    onClose: () => Navigator.of(dialogContext).maybePop(),
                    actions: actions,
                    child: Builder(builder: builder),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      transitionBuilder: (ctx, anim, _, child) {
        if (AppMotion.reduced(ctx) || reduced) return child;
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: anim.drive(CurveTween(curve: Curves.easeOutCubic)),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        12,
        12,
        12 + MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: UAdaptiveSheetDialog(
        title: title,
        subtitle: subtitle,
        badge: badge,
        icon: icon,
        accentColor: accentColor,
        isDesktopModal: false,
        onClose: () => Navigator.of(sheetContext).maybePop(),
        actions: actions,
        child: Builder(builder: builder),
      ),
    ),
  );
}

/// Alias matching platform-separation naming conventions.
Future<T?> showUAdaptiveOverlay<T>({
  required BuildContext context,
  required String title,
  String? subtitle,
  String? badge,
  IconData? icon,
  Color? accentColor,
  required WidgetBuilder builder,
  List<Widget>? actions,
  double maxDesktopWidth = 480,
}) =>
    showUAdaptiveModal<T>(
      context: context,
      title: title,
      subtitle: subtitle,
      badge: badge,
      icon: icon,
      accentColor: accentColor,
      builder: builder,
      actions: actions,
      maxDesktopWidth: maxDesktopWidth,
    );

/// Shared top-lit surface container for adaptive desktop modals and mobile floating sheets.
class UAdaptiveSheetDialog extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? badge;
  final IconData? icon;
  final Color? accentColor;
  final bool isDesktopModal;
  final VoidCallback onClose;
  final Widget child;
  final List<Widget>? actions;

  const UAdaptiveSheetDialog({
    super.key,
    required this.title,
    this.subtitle,
    this.badge,
    this.icon,
    this.accentColor,
    required this.isDesktopModal,
    required this.onClose,
    required this.child,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? AppColors.primary;
    final radius = BorderRadius.circular(16);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: AppColors.cardIdleGradient,
        border: Border.all(
          color: accentColor != null
              ? accent.withValues(alpha: 0.35)
              : AppColors.border,
        ),
        boxShadow: AppColors.dualElevationShadow,
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: const Border(top: BorderSide(color: AppColors.specular)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isDesktopModal) ...[
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: AppSpacing.radiusFull,
                ),
              ),
            ),
            AppSpacing.lgGap,
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: AppSpacing.radiusMd,
                    border: Border.all(color: accent.withValues(alpha: 0.35)),
                  ),
                  child: Icon(icon, color: accent, size: AppSpacing.iconLg),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (badge != null && badge!.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: AppSpacing.radiusSm,
                        ),
                        child: Text(
                          badge!,
                          style: AppTextStyles.caption.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text(title, style: AppTextStyles.h3),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isDesktopModal) ...[
                Container(
                  margin: const EdgeInsets.only(top: 6, right: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.bgSubtle,
                    borderRadius: AppSpacing.radiusSm,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    'Esc',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              IconButton(
                onPressed: onClose,
                tooltip: 'Close',
                icon: const Icon(
                  Icons.close,
                  size: 20,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          AppSpacing.lgGap,
          Flexible(child: child),
          if (actions != null && actions!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                for (var i = 0; i < actions!.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.sm),
                  Expanded(child: actions![i]),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
