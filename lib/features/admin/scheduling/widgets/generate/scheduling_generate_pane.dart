import 'package:flutter/material.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/admin/scheduling/controllers/scheduling_workspace_controller.dart';
import 'package:universe/features/admin/scheduling/models/scheduling_workspace_models.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';

/// CP-SAT Generation Workflow pane.
/// Presents solver configuration, parameters, objective weights, and diagnostic
/// outputs in understandable academic administrative terminology.
class SchedulingGeneratePane extends StatelessWidget {
  final SchedulingWorkspaceController controller;

  const SchedulingGeneratePane({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final cfg = controller.solverConfig;
        final res = controller.solverResult;
        final isSolving = controller.isSolving;

        return ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          children: [
            _buildPreflightSummary(context),
            const SizedBox(height: AppSpacing.lg),
            _buildSolverParametersCard(context, cfg, isSolving),
            const SizedBox(height: AppSpacing.lg),
            _buildExecutionCard(context, res, isSolving),
            if (res.state == SolverRunState.optimal ||
                res.state == SolverRunState.feasible) ...[
              const SizedBox(height: AppSpacing.lg),
              _buildDiagnosticsCard(context, res),
            ],
          ],
        );
      },
    );
  }

  Widget _buildPreflightSummary(BuildContext context) {
    final rev = controller.revision;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: AppSpacing.radiusMd,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: AppSpacing.radiusSm,
            ),
            child: const Icon(
              PhosphorIconsRegular.cpu,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'OR-Tools CP-SAT Solver Engine · Binding Summary',
                  style: AppTextStyles.bodySmMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Target: ${rev.department} (${rev.semester}) · Input: Accepted Revision #${rev.revisionNumber} (v${rev.revisionVersion}) · Engine Profile: Standard Academic Balance',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSolverParametersCard(
    BuildContext context,
    SolverParameterConfig cfg,
    bool isSolving,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppSpacing.radiusMd,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                PhosphorIconsRegular.sliders,
                color: AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.sm),
              const Text(
                'MULTI-OBJECTIVE OPTIMIZATION PARAMETERS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.bgElevated,
                  borderRadius: AppSpacing.radiusSm,
                ),
                child: const Text(
                  'Policy Bound (R8 / R9 / R15)',
                  style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Adjust soft penalty weights. Hard academic constraints (no room collisions, no teacher overlap, lab requirements) are non-negotiable and always enforced with infinite priority.',
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Sliders
          _weightSlider(
            label: 'Faculty Compactness & Idle Time Minimization (R8/R9)',
            description:
                'Penalizes gaps > 1 period between teaching sessions for full-time faculty.',
            value: cfg.teacherIdleWeight,
            enabled: !isSolving,
            onChanged: (v) =>
                controller.updateSolverConfig(cfg.copyWith(teacherIdleWeight: v)),
          ),
          const SizedBox(height: AppSpacing.md),
          _weightSlider(
            label: 'Campus Room Travel Distance Minimization',
            description:
                'Encourages assigning consecutive classes in the same building or floor.',
            value: cfg.roomTravelWeight,
            enabled: !isSolving,
            onChanged: (v) =>
                controller.updateSolverConfig(cfg.copyWith(roomTravelWeight: v)),
          ),
          const SizedBox(height: AppSpacing.md),
          _weightSlider(
            label: 'Weekly Distribution Spread Balance (R13/D2)',
            description:
                'Maximizes day intervals for 3-credit theory courses across Sunday-Thursday.',
            value: cfg.distributionSpreadWeight,
            enabled: !isSolving,
            onChanged: (v) => controller
                .updateSolverConfig(cfg.copyWith(distributionSpreadWeight: v)),
          ),
          const SizedBox(height: AppSpacing.md),
          _weightSlider(
            label: 'Teacher Stated Preferences Satisfaction',
            description:
                'Rewards assigning classes within each faculty member\'s preferred morning/afternoon window.',
            value: cfg.teacherPreferenceWeight,
            enabled: !isSolving,
            onChanged: (v) => controller
                .updateSolverConfig(cfg.copyWith(teacherPreferenceWeight: v)),
          ),
          const SizedBox(height: AppSpacing.md),
          // Time Budget
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Search Time Budget Limit',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Maximum exploration time before returning best feasible candidate.',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 6,
                children: [60.0, 120.0, 300.0].map((t) {
                  final isSelected = cfg.timeLimitSeconds == t;
                  return ChoiceChip(
                    label: Text('${t.toInt()}s'),
                    selected: isSelected,
                    onSelected: isSolving
                        ? null
                        : (_) => controller.updateSolverConfig(
                              cfg.copyWith(timeLimitSeconds: t),
                            ),
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.bgElevated,
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _weightSlider({
    required String label,
    required String description,
    required double value,
    required bool enabled,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              '${(value * 100).toInt()}%',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        Text(
          description,
          style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: AppColors.bgElevated,
            thumbColor: AppColors.primary,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          ),
          child: Slider(
            value: value,
            min: 0.1,
            max: 1.0,
            divisions: 9,
            onChanged: enabled ? onChanged : null,
          ),
        ),
      ],
    );
  }

  Widget _buildExecutionCard(
    BuildContext context,
    SolverExecutionResult res,
    bool isSolving,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppSpacing.radiusMd,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CP-SAT Search Engine Control', style: AppTextStyles.h4),
                    const SizedBox(height: 2),
                    Text(
                      'Runs OR-Tools CP-SAT with multi-threaded constraint satisfaction search.',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onPressed: isSolving ? null : controller.runSolverPreview,
                icon: isSolving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textPrimary,
                        ),
                      )
                    : const Icon(PhosphorIconsRegular.play, size: 16),
                label: Text(isSolving ? 'Solving Routine…' : 'Run CP-SAT Solver'),
              ),
            ],
          ),
          if (isSolving) ...[
            const SizedBox(height: AppSpacing.md),
            LinearProgressIndicator(
              value: controller.solvingProgress,
              backgroundColor: AppColors.bgElevated,
              color: AppColors.primary,
              minHeight: 6,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              controller.solvingStepMessage,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: AppColors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDiagnosticsCard(
    BuildContext context,
    SolverExecutionResult res,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppSpacing.radiusMd,
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.successSoft,
                  borderRadius: AppSpacing.radiusSm,
                ),
                child: const Icon(
                  PhosphorIconsRegular.checkCircle,
                  color: AppColors.success,
                  size: 18,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      res.outcomeLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: AppColors.success,
                      ),
                    ),
                    Text(
                      'Explored ${res.variablesExplored} decision variables in ${res.elapsedSeconds.toStringAsFixed(2)}s. Zero hard conflicts.',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.successSoft,
                  foregroundColor: AppColors.success,
                ),
                onPressed: () => controller.setTabIndex(4),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Review Routine'),
                    SizedBox(width: 4),
                    Icon(PhosphorIconsRegular.arrowRight, size: 14),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: AppSpacing.md),
          // Diagnostic Grid
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.md,
            children: res.diagnostics.entries.map((entry) {
              return SizedBox(
                width: 180,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.value.toString(),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
