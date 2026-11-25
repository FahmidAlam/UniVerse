// PHASE 1: Shell context determines account access and duplicate chrome suppression.
import 'package:universe/shared/widgets/desktop_shell_scope.dart';
import 'package:flutter/material.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';

class UAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget>? actions;
  final bool showBackButton;
  final Color? backgroundColor;

  const UAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions,
    this.showBackButton = true,
    this.backgroundColor,
  });

  @override
  Size get preferredSize => const Size.fromHeight(AppSpacing.appBarHeight);

  @override
  Widget build(BuildContext context) {
    // PHASE 1: Desktop shells own brand chrome; contextual back/selection controls remain.
    final shell = DesktopShellScope.maybeOf(context);
    final desktop = shell?.isDesktop ?? false;
    Widget? leadingWidget = leading;

    if (leadingWidget == null && showBackButton && Navigator.canPop(context)) {
      leadingWidget = IconButton(
        icon: const Icon(
          PhosphorIconsRegular.arrowLeft,
          color: AppColors.textPrimary,
        ),
        onPressed: () => Navigator.pop(context),
      );
    }

    return AppBar(
      backgroundColor: backgroundColor ?? AppColors.bgPrimary,
      elevation: 0,
      leading: leadingWidget,
      automaticallyImplyLeading: false,
      // PHASE 1: Desktop page strips omit repeated subtitles and drawer affordances.
      title: desktop
          ? Text(title, style: AppTextStyles.bodySmMedium)
          : subtitle != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: AppTextStyles.h2),
                    Text(
                      subtitle!,
                      style: AppTextStyles.bodySm
                          .copyWith(color: AppColors.textMuted),
                    ),
                  ],
                )
              : Text(title, style: AppTextStyles.h2),
      // PHASE 1: Mobile account access replaces Profile as a primary tab.
      actions: [
        if (actions != null) ...actions!,
        if (shell != null && !desktop) const ProfileAccountAction()
      ],
    );
  }
}
