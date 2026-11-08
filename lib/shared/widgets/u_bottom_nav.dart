import 'package:universe/core/theme/app_motion.dart';
import 'package:flutter/material.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';

class UNavItem {
  final IconData icon;
  final String label;

  const UNavItem({required this.icon, required this.label});
}

// PHASE 2: Bottom navigation with dual visual cues (active pill container + w700 text color),
// crisp 1px top border, high-contrast inactive items, and touch target accessibility.
class UBottomNav extends StatelessWidget {
  final List<UNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

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
            // PHASE 1: Expose selected role tab and unread state without relying on color.
            child: Semantics(
              selected: isActive,
              button: true,
              label: showBadge
                  ? '${item.label}, $unreadNotifCount unread'
                  : item.label,
              child: InkWell(
                onTap: () {
                  AppMotion.selectionHaptic(context);
                  onTap(i);
                },
                splashColor: AppColors.withOpacity(AppColors.primary, 0.08),
                highlightColor: AppColors.withOpacity(AppColors.primary, 0.04),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration: AppMotion.duration(context, AppMotion.fast),
                      curve: AppMotion.snappy,
                      height: 2,
                      width: isActive ? 28 : 0,
                      decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: AppSpacing.radiusFull),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    // PHASE 2 (PROVISIONAL): Dual cue 1: Active pill container behind icon
                    AnimatedContainer(
                      duration: AppMotion.duration(context, AppMotion.fast),
                      curve: AppMotion.snappy,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.primarySoft
                            : Colors.transparent,
                        borderRadius: AppSpacing.radiusFull,
                      ),
                      child: AnimatedScale(
                          scale: isActive && !AppMotion.reduced(context)
                              ? 1.04
                              : 1,
                          duration:
                              AppMotion.duration(context, AppMotion.micro),
                          curve: AppMotion.snappy,
                          child: Stack(
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
                          )),
                    ),
                    const SizedBox(height: 2),
                    // PHASE 2 (PROVISIONAL): Dual cue 2: Label color + w700 active weight
                    SizedBox(
                      width: double.infinity,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            item.label,
                            maxLines: 1,
                            style: AppTextStyles.caption.copyWith(
                              color: isActive
                                  ? AppColors.navActive
                                  : AppColors.navInactive,
                              fontWeight:
                                  isActive ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
