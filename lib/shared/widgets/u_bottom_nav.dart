import 'package:flutter/material.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';

/// One destination in the bottom nav. Presentational only — the icon
/// + label. Routing is decided by the caller (see AppBottomNav).
class UNavItem {
  final IconData icon;
  final String label;

  const UNavItem({required this.icon, required this.label});
}

/// Pure presentational bottom navigation bar. It renders whatever
/// [items] it is given and reports taps by index — it knows nothing
/// about roles or routes. AppBottomNav supplies the per-role items.
class UBottomNav extends StatelessWidget {
  final List<UNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Index that shows the unread dot (e.g. the Alerts tab). -1 = none.
  final int badgeIndex;
  final int unreadNotifCount;

  const UBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.badgeIndex = -1,
    this.unreadNotifCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSpacing.bottomNavHeight,
      decoration: const BoxDecoration(
        color: AppColors.navBg,
        border: Border(
          top: BorderSide(
            color: AppColors.border,
            width: AppSpacing.borderThin,
          ),
        ),
      ),
      child: Row(
        children: List.generate(items.length, (i) {
          final isActive = currentIndex == i;
          final item = items[i];
          final showBadge = i == badgeIndex && unreadNotifCount > 0;

          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(i),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        item.icon,
                        size: AppSpacing.iconLg,
                        color: isActive
                            ? AppColors.navActive
                            : AppColors.navInactive,
                      ),
                      if (showBadge)
                        Positioned(
                          right: -4,
                          top: -4,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.navBadge,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    item.label,
                    style: AppTextStyles.caption.copyWith(
                      color:
                          isActive ? AppColors.navActive : AppColors.navInactive,
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
