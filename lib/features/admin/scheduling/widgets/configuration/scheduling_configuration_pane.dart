import 'package:flutter/material.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/admin/scheduling/controllers/scheduling_workspace_controller.dart';
import 'package:universe/features/admin/scheduling/models/scheduling_workspace_models.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';

/// Configuration experience representing the 4 revision-bound academic scheduling pillars:
/// 1. Section Calendar & Working Days (R1/D1, R2)
/// 2. Faculty Availability & Workload (R7/D3, R6/D4, R4/R5, R8/R9)
/// 3. Room Pools & Facilities (R10/R11, R14)
/// 4. Time Grid & Meeting Patterns (R15, R12/D5, R13/D2)
///
/// Features the 3-step resolution chain: Default -> Override -> Effective Policy,
/// and preserves honest capability boundaries pending policy snapshot contracts.
class SchedulingConfigurationPane extends StatelessWidget {
  final SchedulingWorkspaceController controller;

  const SchedulingConfigurationPane({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final items = controller.policyItems;
        final categories = [
          'Section Calendar',
          'Faculty Workload',
          'Room Pools',
          'Time Grid',
        ];

        return ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          children: [
            _buildBoundaryDisclaimer(context),
            const SizedBox(height: AppSpacing.lg),
            ...categories.map(
              (cat) => _buildCategorySection(
                context,
                cat,
                items.where((i) => i.category == cat).toList(),
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
                  'Revision-Bound Policy Configuration (Academic Resolutions R1–R15)',
                  style: AppTextStyles.bodySmMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Scheduling policies are version-bound snapshots tied to Accepted Revision #${controller.revision.revisionNumber}. '
                  'Existing mutable management tables (Faculty, Rooms, Timetable Settings) serve as baseline templates; '
                  'the CP-SAT solver consumes only this authoritative, frozen policy snapshot.',
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
      case 'Section Calendar':
        icon = PhosphorIconsRegular.calendar;
        break;
      case 'Faculty Workload':
        icon = PhosphorIconsRegular.usersThree;
        break;
      case 'Room Pools':
        icon = PhosphorIconsRegular.door;
        break;
      case 'Time Grid':
        icon = PhosphorIconsRegular.clock;
        break;
      default:
        icon = PhosphorIconsRegular.gear;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        border: Border.all(color: AppColors.border),
        borderRadius: AppSpacing.radiusMd,
      ),
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
                Text(
                  category.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
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
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.border, height: 1),
          // Rule Items
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
    );
  }

  Widget _buildRuleCard(BuildContext context, PolicyConfigItem item) {
    return Padding(
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
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  item.ruleId,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.bgElevated,
                  borderRadius: AppSpacing.radiusSm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      PhosphorIconsRegular.lock,
                      size: 10,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'SNAPSHOT BOUND',
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.4),
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
                label: const Text(
                  'Edit Override',
                  style: TextStyle(fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.description,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // 3-Part Resolution Chain
          _buildResolutionChain(item),
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
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResolutionChain(PolicyConfigItem item) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.bgPrimary,
        borderRadius: AppSpacing.radiusSm,
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _chainStep('Default', item.defaultValue, AppColors.textMuted),
                const SizedBox(height: 4),
                _chainStep('Override', item.overrideValue, AppColors.warning),
                const SizedBox(height: 4),
                _chainStep(
                  'Effective Policy',
                  item.effectiveValue,
                  AppColors.success,
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                child: _chainStep(
                  'Default',
                  item.defaultValue,
                  AppColors.textMuted,
                ),
              ),
              const Icon(
                PhosphorIconsRegular.arrowRight,
                size: 12,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _chainStep(
                  'Override',
                  item.overrideValue,
                  AppColors.warning,
                ),
              ),
              const Icon(
                PhosphorIconsRegular.arrowRight,
                size: 12,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                flex: 2,
                child: _chainStep(
                  'Effective Policy',
                  item.effectiveValue,
                  AppColors.success,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _chainStep(String stage, String value, Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          stage.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.6,
            color: accentColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  void _showEditOverrideDialog(BuildContext context, PolicyConfigItem item) {
    final overrideCtrl = TextEditingController(text: item.overrideValue);
    final effectiveCtrl = TextEditingController(text: item.effectiveValue);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
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
                'Edit Policy Override · ${item.ruleId}',
                style: AppTextStyles.h4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.label, style: AppTextStyles.bodySmMedium),
              const SizedBox(height: 4),
              Text(
                'Default baseline: ${item.defaultValue}',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: overrideCtrl,
                decoration: const InputDecoration(
                  labelText: 'Override Rule Specification',
                  hintText: 'e.g. Approved committee adjustment...',
                  isDense: true,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: effectiveCtrl,
                decoration: const InputDecoration(
                  labelText: 'Effective Policy String for Solver',
                  hintText: 'e.g. 5 days active per batch...',
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textPrimary,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              controller.updatePolicyOverride(
                ruleId: item.ruleId,
                newOverride: overrideCtrl.text.trim(),
                newEffective: effectiveCtrl.text.trim(),
              );
            },
            child: const Text('Save Snapshot Override'),
          ),
        ],
      ),
    );
  }
}
