import 'package:flutter/material.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/shared/widgets/u_button.dart';

// PHASE 2: Upgraded state presenters (First-Use, No Matches, Recoverable Error, and Truthful Locked Capability).
class UEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final Color? iconColor;
  final Widget? badge;

  const UEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.iconColor,
    this.badge,
  });

  // PHASE 2 (PROVISIONAL): Calm guidance for empty / unscheduled data
  factory UEmptyState.firstUse({
    Key? key,
    IconData icon = PhosphorIconsRegular.calendarBlank,
    String title = 'No routine scheduled yet',
    String? message =
        'Your semester timetable will appear here once the department publishes an approved routine.',
    Widget? action,
    Color? iconColor,
  }) =>
      UEmptyState(
        key: key,
        icon: icon,
        title: title,
        message: message,
        action: action,
        iconColor: iconColor ?? AppColors.primary,
      );

  // PHASE 2 (PROVISIONAL): Acknowledges active filters/query with a 1-tap clear action
  factory UEmptyState.noMatches({
    Key? key,
    IconData icon = PhosphorIconsRegular.magnifyingGlass,
    String? query,
    String? title,
    String? message,
    VoidCallback? onClearFilters,
    String clearFiltersLabel = 'Clear filters',
    Widget? action,
  }) {
    final effectiveTitle = title ??
        (query != null && query.trim().isNotEmpty
            ? 'No matches for "$query"'
            : 'No matching results');
    final effectiveMessage = message ??
        'Try adjusting your search query or removing active filters to see more results.';
    final effectiveAction = action ??
        (onClearFilters != null
            ? UButton(
                label: clearFiltersLabel,
                variant: UButtonVariant.secondary,
                fullWidth: false,
                height: AppSpacing.buttonHeightSm,
                onPressed: onClearFilters,
              )
            : null);

    return UEmptyState(
      key: key,
      icon: icon,
      title: effectiveTitle,
      message: effectiveMessage,
      action: effectiveAction,
      iconColor: AppColors.textMuted,
    );
  }

  // PHASE 2 (PROVISIONAL): Human-readable error explanation with prominent retry action
  factory UEmptyState.error({
    Key? key,
    IconData icon = PhosphorIconsRegular.warningCircle,
    String title = 'Unable to load data',
    String? message =
        'Something went wrong while retrieving timetable information. Please check your connection and retry.',
    VoidCallback? onRetry,
    String retryLabel = 'Retry',
    Widget? action,
  }) {
    final effectiveAction = action ??
        (onRetry != null
            ? UButton(
                label: retryLabel,
                variant: UButtonVariant.primary,
                fullWidth: false,
                height: AppSpacing.buttonHeightSm,
                onPressed: onRetry,
              )
            : null);

    return UEmptyState(
      key: key,
      icon: icon,
      title: title,
      message: message,
      action: effectiveAction,
      iconColor: AppColors.error,
    );
  }

  // PHASE 2 (PROVISIONAL): Truthfully communicates unintegrated backend capabilities
  factory UEmptyState.lockedCapability({
    Key? key,
    IconData icon = PhosphorIconsRegular.lockKey,
    String title = 'Capability Pending Server Integration',
    required String message,
    String badgeLabel = 'PREVIEW ONLY',
    Widget? action,
  }) {
    return UEmptyState(
      key: key,
      icon: icon,
      title: title,
      message: message,
      action: action,
      iconColor: AppColors.warning,
      badge: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 3,
        ),
        decoration: BoxDecoration(
          color: AppColors.warningSoft,
          borderRadius: AppSpacing.radiusSm,
          border: Border.all(
            color: AppColors.warning.withValues(alpha: 0.4),
            width: AppSpacing.borderThin,
          ),
        ),
        child: Text(
          badgeLabel,
          style: AppTextStyles.badge.copyWith(color: AppColors.warning),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? AppColors.textMuted;

    return Center(
      child: Padding(
        padding: AppSpacing.screenPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badge != null) badge!,
            Container(
              width: AppSpacing.x5l,
              height: AppSpacing.x5l,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: AppSpacing.radiusLg,
                border: Border.all(
                  color: color.withValues(alpha: 0.25),
                  width: AppSpacing.borderThin,
                ),
              ),
              child: Icon(icon, size: AppSpacing.iconXl, color: color),
            ),
            AppSpacing.lgGap,
            Text(
              title,
              style: AppTextStyles.h3,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              AppSpacing.smGap,
              Text(
                message!,
                style: AppTextStyles.bodySm.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              AppSpacing.lgGap,
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
