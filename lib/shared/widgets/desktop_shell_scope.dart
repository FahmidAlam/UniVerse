import 'package:universe/shared/widgets/u_avatar.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:universe/core/router/route_names.dart';
import 'package:universe/core/theme/app_colors.dart';

// PHASE 1 RECONCILE: Shell tiers are based on the width available to each shell.
enum ShellLayoutTier { compact, medium, expanded }

ShellLayoutTier shellLayoutTierFor(double availableWidth) {
  if (availableWidth < 768) return ShellLayoutTier.compact;
  if (availableWidth < 1100) return ShellLayoutTier.medium;
  return ShellLayoutTier.expanded;
}

// PHASE 1: Shell-owned chrome is explicit so embedded pages retain only page actions.
class DesktopShellScope extends InheritedWidget {
  final bool isDesktop;
  final ShellLayoutTier tier;
  const DesktopShellScope(
      {super.key,
      required this.isDesktop,
      this.tier = ShellLayoutTier.compact,
      required super.child});
  static DesktopShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DesktopShellScope>();
  static bool isDesktopOf(BuildContext context) =>
      maybeOf(context)?.isDesktop ?? false;
  @override
  bool updateShouldNotify(DesktopShellScope oldWidget) =>
      isDesktop != oldWidget.isDesktop || tier != oldWidget.tier;
}

// Shared compact account chrome. Callers retain their existing sign-out policy.
class ProfileAccountAction extends StatelessWidget {
  final String accountName;
  final String? imageUrl;
  final String? role;
  final VoidCallback? onSignOut;
  const ProfileAccountAction(
      {super.key,
      this.accountName = 'Account',
      this.imageUrl,
      this.role,
      this.onSignOut});

  @override
  Widget build(BuildContext context) {
    final isMobileViewport = MediaQuery.sizeOf(context).width < 768;
    final compact =
        isMobileViewport || DesktopShellScope.maybeOf(context)?.isDesktop == false;
    if (compact && onSignOut == null) {
      return IconButton(
        tooltip: 'Profile / Account',
        onPressed: () => context.go(RouteNames.profile),
        icon: UAvatar(name: accountName, imageUrl: imageUrl, size: 32),
      );
    }
    final roleBadge = role == null
        ? 'MEMBER'
        : role == 'teacher'
            ? 'FACULTY'
            : role!.toUpperCase();
    return PopupMenuButton<String>(
      tooltip: 'Profile / Account',
      offset: const Offset(0, 48),
      color: AppColors.bgElevated,
      surfaceTintColor: Colors.transparent,
      elevation: 10,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.radiusLg,
        side: const BorderSide(color: AppColors.border),
      ),
      onSelected: (value) {
        if (value == 'profile') context.go(RouteNames.profile);
        if (value == 'signout') {
          if (onSignOut != null) {
            onSignOut!.call();
          } else {
            context.go(RouteNames.profile);
          }
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                accountName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                roleBadge,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(height: 8),
        const PopupMenuItem(
          value: 'profile',
          child: Row(
            children: [
              Icon(Icons.person_outline, size: 18, color: AppColors.textSecondary),
              SizedBox(width: 10),
              Text('Profile & Settings'),
            ],
          ),
        ),
        if (onSignOut != null)
          const PopupMenuItem(
            value: 'signout',
            child: Row(
              children: [
                Icon(Icons.logout, size: 18, color: AppColors.error),
                SizedBox(width: 10),
                Text('Sign Out'),
              ],
            ),
          ),
      ],
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48, maxWidth: 220),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
          decoration: BoxDecoration(
              gradient: AppColors.cardIdleGradient,
              border: Border.all(color: AppColors.border),
              borderRadius: AppSpacing.radiusFull),
          foregroundDecoration: const BoxDecoration(
            borderRadius: AppSpacing.radiusFull,
            border: Border(top: BorderSide(color: AppColors.specular)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            UAvatar(name: accountName, imageUrl: imageUrl, size: 32),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(accountName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption),
                  if (role != null)
                    Text(roleBadge,
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.primary)),
                ])),
            const SizedBox(width: AppSpacing.xs),
            const Icon(Icons.expand_more,
                size: 16, color: AppColors.textSecondary),
          ]),
        ),
      ),
    );
  }
}
