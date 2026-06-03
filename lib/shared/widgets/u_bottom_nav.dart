import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:universe_v1/core/theme/app_colors.dart';
import 'package:universe_v1/core/theme/app_spacing.dart';
import 'package:universe_v1/core/theme/app_text_styles.dart';

class UBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final int unreadNotifCount;

  const UBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.unreadNotifCount = 0,
  });

  static const List<_NavItem> _items = [
    _NavItem(icon: PhosphorIconsRegular.house, label: 'Home'),
    _NavItem(icon: PhosphorIconsRegular.calendarBlank, label: 'Routine'),
    _NavItem(icon: PhosphorIconsRegular.sparkle, label: 'AI'),
    _NavItem(icon: PhosphorIconsRegular.bell, label: 'Alerts'),
    _NavItem(icon: PhosphorIconsRegular.user, label: 'Profile'),
  ];

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
        children: List.generate(_items.length, (i) {
          final isActive = currentIndex == i;
          final item = _items[i];
          final showBadge = i == 3 && unreadNotifCount > 0;

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

class _NavItem {
  final IconData icon;
  final String label;

  const _NavItem({required this.icon, required this.label});
}
