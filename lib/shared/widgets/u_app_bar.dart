import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:universe_v1/core/theme/app_colors.dart';
import 'package:universe_v1/core/theme/app_spacing.dart';
import 'package:universe_v1/core/theme/app_text_styles.dart';

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
      title: subtitle != null
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
      actions: actions,
    );
  }
}
