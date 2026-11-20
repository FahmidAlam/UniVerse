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
            if (res.isNonFeasible || res.conflictDiagnostics.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              _buildConflictDiagnosticsCard(context, res),
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
          // PHASE 5: Responsive header that wraps cleanly at 390px without clipping.
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    PhosphorIconsRegular.sliders,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      'MULTI-OBJECTIVE OPTIMIZATION PARAMETERS',
                      style: AppTextStyles.h4.copyWith(
                        fontSize: 12,
                        letterSpacing: 0.8,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.bgElevated,
                  borderRadius: AppSpacing.radiusSm,
                ),
                child: Text(
                  'Policy Bound (R3 / R8 / R9 / R13 / R15)',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Adjust soft penalty weights across four priority tiers. Hard academic constraints (no room collisions, no teacher overlap, lab requirements) are non-negotiable and always enforced with infinite priority.',
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Sliders across R1-R16 priority tiers
          _weightSlider(
            label: 'Tier 1: Cohort Compactness & Idle Gap Minimization (R3/R9)',
            description:
                'Penalizes internal section gaps >= 2 consecutive empty slots and ensures SUST adjunct compact clustering.',
            value: cfg.cohortCompactnessWeight,
            enabled: !isSolving,
            onChanged: (v) => controller.updateSolverConfig(
              cfg.copyWith(cohortCompactnessWeight: v, teacherIdleWeight: v),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _weightSlider(
            label: 'Tier 2: Faculty Stated Preferences Satisfaction (R8/R9)',
            description:
                'Rewards assigning classes within faculty preferred morning/afternoon windows and SUST adjunct side-of-break clusters.',
            value: cfg.facultyPreferenceWeight,
            enabled: !isSolving,
            onChanged: (v) => controller.updateSolverConfig(
              cfg.copyWith(facultyPreferenceWeight: v, teacherPreferenceWeight: v),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _weightSlider(
            label: 'Tier 3: Weekly Theory Distribution Spread Balance (R13/D2)',
            description:
                'Maximizes day intervals for 3-credit theory courses across the section\'s active working days in the 7-day week (Sunday–Saturday) to avoid same-day cramming.',
            value: cfg.theorySpreadWeight,
            enabled: !isSolving,
            onChanged: (v) => controller.updateSolverConfig(
              cfg.copyWith(theorySpreadWeight: v, distributionSpreadWeight: v),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _weightSlider(
            label: 'Tier 4: Late Afternoon Slot Avoidance (R15)',
            description:
                'Penalizes assigning sessions to late afternoon periods when morning/midday slots are available.',
            value: cfg.latePeriodAvoidanceWeight,
            enabled: !isSolving,
            onChanged: (v) => controller.updateSolverConfig(
              cfg.copyWith(latePeriodAvoidanceWeight: v),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _weightSlider(
            label: 'Secondary: Campus Room Travel Distance Minimization',
            description:
                'Encourages assigning consecutive classes in the same building or floor.',
            value: cfg.roomTravelWeight,
            enabled: !isSolving,
            onChanged: (v) => controller.updateSolverConfig(
              cfg.copyWith(roomTravelWeight: v),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Time Budget (Responsive layout at 390px)
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 540;
              final chips = Wrap(
                spacing: 6,
                runSpacing: 4,
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
                    labelStyle: AppTextStyles.captionMedium.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  );
                }).toList(),
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Search Time Budget Limit',
                      style: AppTextStyles.bodySmMedium.copyWith(
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
                    const SizedBox(height: AppSpacing.xs),
                    chips,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Search Time Budget Limit',
                          style: AppTextStyles.bodySmMedium.copyWith(
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
                  chips,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // PHASE 5: Axis-labeled multi-objective weight control with priority tier indicator and tabular numerals.
  Widget _weightSlider({
    required String label,
    required String description,
    required double value,
    required bool enabled,
    required ValueChanged<double> onChanged,
  }) {
    final tierLabel = value >= 0.75
        ? 'Strict Priority'
        : (value >= 0.45 ? 'Balanced' : 'Low');
    final tierColor = value >= 0.75
        ? AppColors.primary
        : (value >= 0.45 ? AppColors.info : AppColors.textMuted);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodySmMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.bgElevated,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                tierLabel,
                style: AppTextStyles.captionMedium.copyWith(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: tierColor,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${(value * 100).toInt()}%',
              style: AppTextStyles.numeric.copyWith(
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
          data: const SliderThemeData(
            trackHeight: 4,
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: AppColors.bgElevated,
            thumbColor: AppColors.primary,
            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: RoundSliderOverlayShape(overlayRadius: 12),
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
    final runBtn = FilledButton.icon(
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
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppSpacing.radiusMd,
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: 4,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.infoSoft,
                      borderRadius: AppSpacing.radiusSm,
                      border: Border.all(
                        color: AppColors.info.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      'SIMULATED PREVIEW · NO ENGINE CALL',
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: AppColors.info,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (isNarrow) ...[
                Text('CP-SAT Search Engine Control', style: AppTextStyles.h4),
                const SizedBox(height: 2),
                Text(
                  'Runs OR-Tools CP-SAT with multi-threaded constraint satisfaction search.',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(width: double.infinity, child: runBtn),
                const SizedBox(height: AppSpacing.xs),
                Center(
                  child: TextButton.icon(
                    onPressed: isSolving ? null : controller.simulateInfeasibleSolverRun,
                    icon: const Icon(PhosphorIconsRegular.bug, size: 14),
                    label: Text(
                      'Simulate Infeasible Core',
                      style: AppTextStyles.captionMedium.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CP-SAT Search Engine Control',
                            style: AppTextStyles.h4,
                          ),
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
                    const SizedBox(width: AppSpacing.md),
                    TextButton.icon(
                      onPressed: isSolving ? null : controller.simulateInfeasibleSolverRun,
                      icon: const Icon(PhosphorIconsRegular.bug, size: 14),
                      label: Text(
                        'Simulate Infeasible Core',
                        style: AppTextStyles.captionMedium.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    runBtn,
                  ],
                ),
              ],
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
                  style: AppTextStyles.timeCode.copyWith(
                    fontSize: 11,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildDiagnosticsCard(
    BuildContext context,
    SolverExecutionResult res,
  ) {
    final reviewBtn = FilledButton.tonal(
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
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppSpacing.radiusMd,
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.4),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                          style: AppTextStyles.h4.copyWith(
                            fontSize: 13,
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
                  if (!isNarrow) ...[
                    const SizedBox(width: AppSpacing.sm),
                    reviewBtn,
                  ],
                ],
              ),
              if (isNarrow) ...[
                const SizedBox(height: AppSpacing.sm),
                SizedBox(width: double.infinity, child: reviewBtn),
              ],
              const SizedBox(height: AppSpacing.md),
              const Divider(color: AppColors.border, height: 1),
              const SizedBox(height: AppSpacing.md),
              // Diagnostic Grid
              Wrap(
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.md,
                children: res.diagnostics.entries.map((entry) {
                  return SizedBox(
                    width: 150,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.key.toUpperCase(),
                          style: AppTextStyles.labelCaps.copyWith(
                            fontSize: 10,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          entry.value.toString(),
                          style: AppTextStyles.numeric.copyWith(
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
          );
        },
      ),
    );
  }

  Widget _buildConflictDiagnosticsCard(
    BuildContext context,
    SolverExecutionResult res,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppSpacing.radiusMd,
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.errorSoft,
                  borderRadius: AppSpacing.radiusSm,
                ),
                child: const Icon(
                  PhosphorIconsRegular.warningCircle,
                  color: AppColors.error,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CP-SAT SOLVER INFEASIBLE · CONFLICT DIAGNOSTICS',
                      style: AppTextStyles.h4.copyWith(
                        fontSize: 13,
                        letterSpacing: 0.6,
                        color: AppColors.error,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'The CP-SAT constraint engine proved no feasible schedule exists satisfying all active hard constraints. Review the Minimal Unsatisfiable Core (MUC) below:',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: AppSpacing.md),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: res.conflictDiagnostics.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final diag = res.conflictDiagnostics[index];
              return Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.bgElevated,
                  borderRadius: AppSpacing.radiusSm,
                  border: const Border(
                    left: BorderSide(color: AppColors.error, width: 3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.errorSoft,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            diag.ruleCode,
                            style: AppTextStyles.labelCaps.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            diag.title,
                            style: AppTextStyles.bodySmMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side: BorderSide(
                              color: AppColors.primary.withValues(alpha: 0.5),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => controller.setTabIndex(diag.targetTab),
                          icon: const Icon(
                            PhosphorIconsRegular.arrowSquareOut,
                            size: 12,
                          ),
                          label: Text(
                            diag.targetTab == 0
                                ? 'Fix in Distribution'
                                : 'Fix in Config',
                            style: AppTextStyles.captionMedium.copyWith(
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      diag.summary,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (diag.suggestedAction.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Recommendation: ${diag.suggestedAction}',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.warning,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    if (diag.involvedEntities.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: diag.involvedEntities.map((e) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.bgPrimary,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              e,
                              style: AppTextStyles.timeCode.copyWith(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
