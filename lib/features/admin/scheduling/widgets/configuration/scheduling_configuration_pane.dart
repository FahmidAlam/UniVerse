import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:universe/core/router/route_names.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/admin/scheduling/controllers/scheduling_workspace_controller.dart';
import 'package:universe/features/admin/scheduling/models/scheduling_workspace_models.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/shared/widgets/u_card.dart';
import 'package:universe/shared/widgets/u_segmented_control.dart';

/// Configuration experience representing the 5 revision-bound academic scheduling pillars:
/// 1. Term Grid & Section Calendar (R1, R2, R3, R15)
/// 2. Faculty Workload, Categories & Compactness (R4, R5, R6, R7, R8, R9)
/// 3. Shared Laboratories & Dynamic Classroom Pools (R10, R11, R14)
/// 4. Credit-Based Course Distribution Rules (R12, R13)
/// 5. UI Governance & Impact Warnings (R16)
///
/// Features the 3-step resolution chain: Default -> Override -> Effective Policy,
/// prominent R15 6/7-slot control with visual period strip preview,
/// and "Checkbox Off = Gray" baseline signaling with 1-tap reset to committee baseline.
class SchedulingConfigurationPane extends StatelessWidget {
  final SchedulingWorkspaceController controller;

  const SchedulingConfigurationPane({super.key, required this.controller});

  static bool _hasActiveOverride(PolicyConfigItem item) {
    final trimmed = item.overrideValue.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.toLowerCase().startsWith('none')) return false;
    if (trimmed == item.defaultValue.trim()) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final items = controller.policyItems;
        const categories = [
          'Term Grid & Section Calendar',
          'Faculty Workload, Categories & Compactness',
          'Shared Laboratories & Dynamic Classroom Pools',
          'Credit-Based Course Distribution Rules',
          'UI Governance & Impact Warnings',
        ];

        List<PolicyConfigItem> getItemsForCategory(String cat) {
          return items.where((i) {
            if (i.category == cat) return true;
            if (cat == 'Term Grid & Section Calendar' &&
                (i.category == 'Section Calendar' ||
                    (i.category == 'Time Grid' && i.ruleId.contains('R15')))) {
              return true;
            }
            if (cat == 'Faculty Workload, Categories & Compactness' &&
                i.category == 'Faculty Workload') {
              return true;
            }
            if (cat == 'Shared Laboratories & Dynamic Classroom Pools' &&
                i.category == 'Room Pools') {
              return true;
            }
            if (cat == 'Credit-Based Course Distribution Rules' &&
                i.category == 'Time Grid' &&
                (i.ruleId.contains('R12') || i.ruleId.contains('R13'))) {
              return true;
            }
            if (cat == 'UI Governance & Impact Warnings' &&
                i.category == 'Time Grid' &&
                i.ruleId.contains('R16')) {
              return true;
            }
            return false;
          }).toList();
        }

        return ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          children: [
            _buildBoundaryDisclaimer(context),
            const SizedBox(height: AppSpacing.lg),
            ...categories.map(
              (cat) => _buildCategorySection(
                context,
                cat,
                getItemsForCategory(cat),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBoundaryDisclaimer(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: AppSpacing.radiusMd,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            PhosphorIconsRegular.shieldCheck,
            color: AppColors.warning,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Revision-Bound Policy Configuration (Academic Resolutions R1–R16)',
                  style: AppTextStyles.bodySmMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Scheduling policies are version-bound snapshots tied to Accepted Revision #${controller.revision.revisionNumber}. '
                  'Baseline rules render calm slate-gray; modified policies highlight with 3px amber borders and provide 1-tap reset.',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(
    BuildContext context,
    String category,
    List<PolicyConfigItem> items,
  ) {
    IconData icon;
    switch (category) {
      case 'Term Grid & Section Calendar':
        icon = PhosphorIconsRegular.calendar;
        break;
      case 'Faculty Workload, Categories & Compactness':
        icon = PhosphorIconsRegular.usersThree;
        break;
      case 'Shared Laboratories & Dynamic Classroom Pools':
        icon = PhosphorIconsRegular.door;
        break;
      case 'Credit-Based Course Distribution Rules':
        icon = PhosphorIconsRegular.bookOpen;
        break;
      case 'UI Governance & Impact Warnings':
        icon = PhosphorIconsRegular.lockKey;
        break;
      default:
        icon = PhosphorIconsRegular.gear;
    }

    final isTermGrid = category.startsWith('Term Grid');

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: UCard(
        isTopLit: true,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(icon, size: 16, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      category.toUpperCase(),
                      style: AppTextStyles.labelCaps.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.bgElevated,
                      borderRadius: AppSpacing.radiusSm,
                    ),
                    child: Text(
                      '${items.length} Rules',
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.border, height: 1),

            // R15 Prominent Flexible Daily Slot Configuration at the top of Category 1
            if (isTermGrid) ...[
              _buildR15ProminentSlotControl(context, items),
              const Divider(color: AppColors.border, height: 1),
            ],

            // Rule Items dissolved into 1px divider rows
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (context, index) =>
                  const Divider(color: AppColors.border, height: 1),
              itemBuilder: (context, index) {
                return _buildRuleCard(context, items[index]);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Prominent R15 Flexible Daily Slot Configuration with Period-Strip Preview
  Widget _buildR15ProminentSlotControl(
    BuildContext context,
    List<PolicyConfigItem> items,
  ) {
    final r15Item = items.firstWhere(
      (i) => i.ruleId.contains('R15'),
      orElse: () => const PolicyConfigItem(
        category: 'Term Grid & Section Calendar',
        ruleId: 'R15',
        label: 'Flexible Daily Slot Configuration',
        description: '6 vs 7 daily slots',
        defaultValue: '7 daily slots',
        overrideValue: 'None',
        effectiveValue: '7 slots',
        isLocked: true,
        snapshotRequirement: '',
      ),
    );

    int currentSlotCount = 7;
    final payloadSlots = r15Item.typedPayload['slot_count'] as int?;
    if (payloadSlots != null) {
      currentSlotCount = payloadSlots;
    } else if (r15Item.effectiveValue.contains('6 slots') ||
        r15Item.overrideValue.contains('6-Slot') ||
        r15Item.overrideValue.contains('6 slots')) {
      currentSlotCount = 6;
    }

    return Container(
      color: AppColors.bgElevated.withValues(alpha: 0.5),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: AppSpacing.radiusSm,
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.4)),
                ),
                child: Text(
                  'R15 CORE GRID',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Flexible Daily Slot Grid Dimension',
                  style: AppTextStyles.bodySmMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: currentSlotCount == 6
                      ? AppColors.warningSoft
                      : AppColors.bgPrimary,
                  borderRadius: AppSpacing.radiusSm,
                  border: Border.all(
                    color: currentSlotCount == 6
                        ? AppColors.warning.withValues(alpha: 0.45)
                        : AppColors.border,
                  ),
                ),
                child: Text(
                  currentSlotCount == 6 ? '6 SLOTS ACTIVE' : '7 SLOTS ACTIVE',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: currentSlotCount == 6
                        ? AppColors.warning
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Switch between the standard 7-period university schedule and the compact 6-period daily grid. '
            'Period 4 is permanently reserved for lunch and prayer break across all batches.',
            style:
                AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          // Prominent USegmentedControl for R15 switching
          USegmentedControl<int>(
            selected: currentSlotCount,
            compact: true,
            segments: const [
              USegment(
                value: 6,
                label: '6-Slot Daily Grid (Compressed)',
                icon: PhosphorIconsRegular.clock,
              ),
              USegment(
                value: 7,
                label: '7-Slot Daily Grid (Standard Full)',
                icon: PhosphorIconsRegular.clock,
              ),
            ],
            onChanged: (newSlots) {
              if (newSlots == currentSlotCount) return;
              controller.updatePolicyOverride(
                ruleId: r15Item.ruleId,
                newOverride: newSlots == 6
                    ? '6-Slot Daily Grid (Compressed)'
                    : 'None (Default 7-Slot Grid)',
                newEffective: newSlots == 6
                    ? '6 slots (Continuous teaching sessions)'
                    : '7 slots (Period 4 reserved for Lunch/Prayer)',
                typedPayload: {'slot_count': newSlots, 'break_period': 4},
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'PERIOD STRIP VISUAL PREVIEW',
            style: AppTextStyles.labelCaps.copyWith(fontSize: 10),
          ),
          const SizedBox(height: AppSpacing.xs),
          // Dynamic visual period strip preview
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPeriodSlotBadge(1, '09:00 - 09:50', isBreak: false),
                _buildPeriodSlotBadge(2, '10:00 - 10:50', isBreak: false),
                _buildPeriodSlotBadge(3, '11:00 - 11:50', isBreak: false),
                _buildPeriodSlotBadge(4, '12:00 - 13:00', isBreak: true),
                _buildPeriodSlotBadge(5, '13:00 - 13:50', isBreak: false),
                _buildPeriodSlotBadge(6, '14:00 - 14:50', isBreak: false),
                if (currentSlotCount >= 7)
                  _buildPeriodSlotBadge(7, '15:00 - 15:50', isBreak: false),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: AppSpacing.radiusSm,
              border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(PhosphorIconsRegular.lock, size: 13, color: AppColors.error),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Hard Constraint: Friday Jummah Prayer Block (friday_no_p4 — No classes during Friday Jummah slot)',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.bold,
                      fontSize: 10.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSlotBadge(int periodNumber, String timeRange,
      {required bool isBreak}) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isBreak
            ? AppColors.primarySoft.withValues(alpha: 0.6)
            : AppColors.bgPrimary,
        borderRadius: AppSpacing.radiusSm,
        border: Border.all(
          color: isBreak
              ? AppColors.primary.withValues(alpha: 0.4)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isBreak
                    ? PhosphorIconsRegular.coffee
                    : PhosphorIconsRegular.chalkboardTeacher,
                size: 11,
                color: isBreak ? AppColors.primary : AppColors.textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                isBreak ? 'BREAK' : 'SLOT $periodNumber',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isBreak ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            timeRange,
            style: AppTextStyles.caption.copyWith(
              fontSize: 9,
              color: AppColors.textSecondary,
              fontFamilyFallback: AppTextStyles.monospaceFontFallback,
            ),
          ),
        ],
      ),
    );
  }

  // PHASE 5 & 6: "Checkbox Off = Gray" signaling discipline + 390px clip-free layout.
  // Untouched default rules use calm slate-gray; active overrides light up with 3px amber warning accent.
  Widget _buildRuleCard(BuildContext context, PolicyConfigItem item) {
    final hasOverride = _hasActiveOverride(item);

    return Container(
      decoration: BoxDecoration(
        color: hasOverride
            ? AppColors.warningSoft.withValues(alpha: 0.18)
            : Colors.transparent,
        border: hasOverride
            ? const Border(
                left: BorderSide(color: AppColors.warning, width: 3),
              )
            : null,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 640;

          final ruleBadge = Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: hasOverride ? AppColors.warningSoft : AppColors.bgElevated,
              borderRadius: AppSpacing.radiusSm,
              border: Border.all(
                color: hasOverride
                    ? AppColors.warning.withValues(alpha: 0.45)
                    : AppColors.border,
              ),
            ),
            child: Text(
              item.ruleId,
              style: AppTextStyles.caption.copyWith(
                fontFamilyFallback: AppTextStyles.monospaceFontFallback,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color:
                    hasOverride ? AppColors.warning : AppColors.textSecondary,
              ),
            ),
          );

          final signalBadge = Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: hasOverride ? AppColors.warningSoft : AppColors.bgElevated,
              borderRadius: AppSpacing.radiusSm,
              border: Border.all(
                color: hasOverride
                    ? AppColors.warning.withValues(alpha: 0.4)
                    : AppColors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hasOverride
                      ? PhosphorIconsRegular.sliders
                      : PhosphorIconsRegular.lock,
                  size: 10,
                  color: hasOverride ? AppColors.warning : AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  hasOverride ? 'OVERRIDDEN' : 'DEFAULT BASELINE',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color:
                        hasOverride ? AppColors.warning : AppColors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          );

          final editButton = OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor:
                  hasOverride ? AppColors.primary : AppColors.textSecondary,
              side: BorderSide(
                color: hasOverride
                    ? AppColors.primary.withValues(alpha: 0.45)
                    : AppColors.border,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => _showEditOverrideDialog(context, item),
            icon: const Icon(PhosphorIconsRegular.pencil, size: 11),
            label: Text(
              'Edit Override',
              style: AppTextStyles.caption.copyWith(fontSize: 10),
            ),
          );

          final resetButton = hasOverride
              ? OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.warning,
                    side: BorderSide(
                      color: AppColors.warning.withValues(alpha: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => controller.resetPolicyOverride(item.ruleId),
                  icon: const Icon(PhosphorIconsRegular.arrowCounterClockwise,
                      size: 11),
                  label: Text(
                    'Reset to Baseline',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : null;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isNarrow) ...[
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ruleBadge,
                    signalBadge,
                    editButton,
                    if (resetButton != null) resetButton,
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  item.label,
                  style: AppTextStyles.bodySmMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    ruleBadge,
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        item.label,
                        style: AppTextStyles.bodySmMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    signalBadge,
                    const SizedBox(width: AppSpacing.sm),
                    editButton,
                    if (resetButton != null) ...[
                      const SizedBox(width: AppSpacing.xs),
                      resetButton,
                    ],
                  ],
                ),
              ],
              const SizedBox(height: 6),
              Text(
                item.description,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),

              // Specialized Rule Insets
              _buildRuleSpecificInsight(context, item),

              const SizedBox(height: AppSpacing.md),
              // 3-Part Resolution Chain
              _buildResolutionChain(item, hasOverride: hasOverride),
              const SizedBox(height: AppSpacing.sm),
              // Snapshot requirement chip
              Row(
                children: [
                  const Icon(
                    PhosphorIconsRegular.info,
                    size: 11,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item.snapshotRequirement,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  /// Rule-specific visual callouts for R1–R16 committee policies
  Widget _buildRuleSpecificInsight(
      BuildContext context, PolicyConfigItem item) {
    if (item.ruleId.contains('R6')) {
      return Container(
        margin: const EdgeInsets.only(top: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: AppSpacing.radiusSm,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.table_chart_outlined,
                    size: 12, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  'R6 CATEGORY WORKLOAD TABLE',
                  style: AppTextStyles.labelCaps.copyWith(fontSize: 9),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '• Adjunct Faculty: 2 courses -> 2 days | 3 courses -> 3–4 days | >=4 courses -> 4–5 days\n'
              '• Permanent Faculty: 4–5 working days (Min 2 / Max 3 weekly days off [R7])',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    if (item.ruleId.contains('R14')) {
      return Container(
        margin: const EdgeInsets.only(top: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: AppSpacing.radiusSm,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(PhosphorIconsRegular.door,
                size: 14, color: AppColors.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Dynamic Theory Pool: 7 Active Lecture Halls in current semester pool.',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton.icon(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => context.go(RouteNames.manageRooms),
              icon: const Icon(PhosphorIconsRegular.arrowSquareOut, size: 12),
              label: Text(
                'Manage Rooms',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (item.ruleId.contains('R8') || item.ruleId.contains('R9')) {
      return Container(
        margin: const EdgeInsets.only(top: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: AppSpacing.radiusSm,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(PhosphorIconsRegular.slidersHorizontal,
                size: 12, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              'SUST Adjunct Mode: Single side of break preferred Â· Max daily gap â‰¤ 2 slots',
              style: AppTextStyles.caption.copyWith(
                fontSize: 10,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildResolutionChain(
    PolicyConfigItem item, {
    required bool hasOverride,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: AppSpacing.radiusSm,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildChainRow(
            label: 'DEFAULT BASELINE',
            value: item.defaultValue,
            icon: PhosphorIconsRegular.lock,
            color: AppColors.textMuted,
            isEffective: !hasOverride,
          ),
          const SizedBox(height: 6),
          _buildChainRow(
            label: 'REVISION OVERRIDE',
            value: item.overrideValue,
            icon: PhosphorIconsRegular.sliders,
            color: hasOverride ? AppColors.warning : AppColors.textMuted,
            isEffective: false,
          ),
          const SizedBox(height: 6),
          _buildChainRow(
            label: 'EFFECTIVE SOLVER POLICY',
            value: item.effectiveValue,
            icon: PhosphorIconsRegular.checkCircle,
            color: hasOverride ? AppColors.warning : AppColors.primary,
            isEffective: true,
          ),
        ],
      ),
    );
  }

  Widget _buildChainRow({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isEffective,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 6),
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.bodySm.copyWith(
              fontSize: 11,
              fontWeight: isEffective ? FontWeight.bold : FontWeight.normal,
              color:
                  isEffective ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  void _showEditOverrideDialog(BuildContext context, PolicyConfigItem item) {
    final overrideCtrl = TextEditingController(
      text: item.overrideValue.startsWith('None') ? '' : item.overrideValue,
    );
    final effectiveCtrl = TextEditingController(text: item.effectiveValue);

    final currentPayload = Map<String, dynamic>.from(item.typedPayload);
    String weekendChoice = (currentPayload['weekend'] as String?) ?? 'Fri-Sat';
    int stepperValue = (currentPayload['max_days_off_diff'] as int?) ??
        (currentPayload['max_internal_gap'] as int?) ??
        (currentPayload['off_days_count'] as int?) ??
        (currentPayload['max_gap'] as int?) ??
        2;
    int slotGridValue = (currentPayload['slot_count'] as int?) ?? 7;
    bool toggleValue = (currentPayload['allow_break_crossing'] as bool?) ??
        (currentPayload['term_scoped_room_pool'] as bool?) ??
        false;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          Widget? typedControlWidget;
          if (item.valueType == PolicyValueType.weekendPairSelector) {
            typedControlWidget = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('WEEKEND OVERRIDE PAIR', style: AppTextStyles.labelCaps),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    ChoiceChip(
                      label: const Text('Fri–Sat (Default Weekend)'),
                      selected: weekendChoice == 'Fri-Sat',
                      onSelected: (sel) {
                        if (sel) {
                          setDialogState(() {
                            weekendChoice = 'Fri-Sat';
                            currentPayload['weekend'] = 'Fri-Sat';
                            overrideCtrl.text = 'Default Fri-Sat pair';
                            effectiveCtrl.text =
                                '5 Active Teaching Days across 7-Day Cycle';
                          });
                        }
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Thu–Fri (Section Stagger)'),
                      selected: weekendChoice == 'Thu-Fri',
                      onSelected: (sel) {
                        if (sel) {
                          setDialogState(() {
                            weekendChoice = 'Thu-Fri';
                            currentPayload['weekend'] = 'Thu-Fri';
                            overrideCtrl.text =
                                'Section Stagger: Thu-Fri pair';
                            effectiveCtrl.text =
                                '5 Active Teaching Days across 7-Day Cycle';
                          });
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            );
          } else if (item.valueType == PolicyValueType.intStepper) {
            typedControlWidget = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NUMERIC BOUND / GAP THRESHOLD',
                    style: AppTextStyles.labelCaps),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(PhosphorIconsRegular.minusCircle),
                      onPressed: stepperValue > 1
                          ? () {
                              setDialogState(() {
                                stepperValue--;
                                currentPayload['value'] = stepperValue;
                                overrideCtrl.text =
                                    'Configured bound: $stepperValue';
                                effectiveCtrl.text =
                                    '<= $stepperValue enforced';
                              });
                            }
                          : null,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.bgPrimary,
                        borderRadius: AppSpacing.radiusSm,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        '$stepperValue',
                        style:
                            AppTextStyles.h3.copyWith(color: AppColors.primary),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(PhosphorIconsRegular.plusCircle),
                      onPressed: stepperValue < 5
                          ? () {
                              setDialogState(() {
                                stepperValue++;
                                currentPayload['value'] = stepperValue;
                                overrideCtrl.text =
                                    'Configured bound: $stepperValue';
                                effectiveCtrl.text =
                                    '<= $stepperValue enforced';
                              });
                            }
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            );
          } else if (item.valueType == PolicyValueType.slotGridSelector) {
            typedControlWidget = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DAILY SLOT GRID STRUCTURE',
                    style: AppTextStyles.labelCaps),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    ChoiceChip(
                      label: const Text('7 Slots (Standard Period 4 Break)'),
                      selected: slotGridValue == 7,
                      onSelected: (sel) {
                        if (sel) {
                          setDialogState(() {
                            slotGridValue = 7;
                            currentPayload['slot_count'] = 7;
                            overrideCtrl.text =
                                '7 daily slots with 12:00 lunch/prayer break';
                            effectiveCtrl.text =
                                '7 slots (Period 4 reserved for Lunch/Prayer)';
                          });
                        }
                      },
                    ),
                    ChoiceChip(
                      label: const Text('6 Slots (Compact Afternoon)'),
                      selected: slotGridValue == 6,
                      onSelected: (sel) {
                        if (sel) {
                          setDialogState(() {
                            slotGridValue = 6;
                            currentPayload['slot_count'] = 6;
                            overrideCtrl.text = '6 daily slots compact clock';
                            effectiveCtrl.text =
                                '6 slots (Continuous teaching sessions)';
                          });
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            );
          } else if (item.valueType == PolicyValueType.booleanToggle) {
            typedControlWidget = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    item.ruleId.contains('R12')
                        ? 'Allow Break Crossing'
                        : 'Enable Term-Scoped Room Pool',
                    style: AppTextStyles.bodySmMedium,
                  ),
                  subtitle: Text(
                    item.ruleId.contains('R12')
                        ? 'Allows 100-min lab sessions to cross university break'
                        : 'Restricts allocation to term-activated classrooms',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textMuted),
                  ),
                  value: toggleValue,
                  onChanged: (val) {
                    setDialogState(() {
                      toggleValue = val;
                      currentPayload['enabled'] = val;
                      overrideCtrl.text =
                          val ? 'Explicitly Allowed' : 'Strictly Disallowed';
                      effectiveCtrl.text = val
                          ? 'Permission Granted'
                          : 'Disallowed (Strict boundary)';
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            );
          }

          return AlertDialog(
            backgroundColor: AppColors.bgCard,
            title: Row(
              children: [
                const Icon(
                  PhosphorIconsRegular.pencil,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Edit Policy Override Â· ${item.ruleId}',
                    style: AppTextStyles.h4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.infoSoft,
                        borderRadius: AppSpacing.radiusSm,
                        border: Border.all(
                            color: AppColors.info.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        'SIMULATED PREVIEW Â· NO DATABASE WRITES',
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: AppColors.info,
                        ),
                      ),
                    ),
                    Text(item.label, style: AppTextStyles.bodySmMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Default baseline: ${item.defaultValue}',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (typedControlWidget != null) typedControlWidget,
                    Text('OVERRIDE RULE SPECIFICATION',
                        style: AppTextStyles.labelCaps),
                    const SizedBox(height: AppSpacing.xs),
                    TextField(
                      controller: overrideCtrl,
                      style: AppTextStyles.bodySm
                          .copyWith(color: AppColors.textPrimary),
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Approved committee adjustment...',
                        contentPadding: EdgeInsets.all(AppSpacing.md),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text('EFFECTIVE POLICY FOR SOLVER',
                        style: AppTextStyles.labelCaps),
                    const SizedBox(height: AppSpacing.xs),
                    TextField(
                      controller: effectiveCtrl,
                      style: AppTextStyles.bodySm
                          .copyWith(color: AppColors.textPrimary),
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'e.g. 5 days active per batch...',
                        contentPadding: EdgeInsets.all(AppSpacing.md),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  controller.resetPolicyOverride(item.ruleId);
                },
                child: Text('Reset to Baseline',
                    style: AppTextStyles.captionMedium
                        .copyWith(color: AppColors.error)),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnPrimary,
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  controller.updatePolicyOverride(
                    ruleId: item.ruleId,
                    newOverride: overrideCtrl.text.trim(),
                    newEffective: effectiveCtrl.text.trim(),
                    typedPayload: currentPayload,
                  );
                },
                child: const Text('Save Snapshot Override'),
              ),
            ],
          );
        },
      ),
    );
  }
}
