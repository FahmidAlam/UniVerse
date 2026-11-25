import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/admin/scheduling/controllers/scheduling_workspace_controller.dart';
import 'package:universe/features/admin/scheduling/models/scheduling_workspace_models.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';

/// Contextual Record Inspector implementing the 5-part academic provenance model:
/// 1. Evidence (Original Workbook cells A–L)
/// 2. Effective Value (Accepted Overlays)
/// 3. Formula & Cached Values (Columns J & L)
/// 4. Impact Preview (Deterministic Scheduling Implication)
/// 5. Audit Trail & Audited Correction Form
class DistributionRecordInspector extends StatefulWidget {
  final SchedulingWorkspaceController controller;
  final ScrollController? scrollController;
  final bool isMobileModal;

  const DistributionRecordInspector({
    super.key,
    required this.controller,
    this.scrollController,
    this.isMobileModal = false,
  });

  @override
  State<DistributionRecordInspector> createState() =>
      _DistributionRecordInspectorState();
}

class _DistributionRecordInspectorState
    extends State<DistributionRecordInspector> {
  // Correction Form state
  bool _isEditing = false;
  String _targetColumn = 'I';
  final TextEditingController _valueController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  String? _formError;
  bool _isSaving = false;

  @override
  void dispose() {
    _valueController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _startEditing(String column, String currentValue) {
    setState(() {
      _isEditing = true;
      _targetColumn = column;
      _valueController.text = currentValue;
      _reasonController.clear();
      _formError = null;
    });
  }

  Future<void> _submitCorrection(DistributionSourceRecord record) async {
    final value = _valueController.text.trim();
    final reason = _reasonController.text.trim();

    if (value.isEmpty) {
      setState(() => _formError = 'Please provide an effective cell value.');
      return;
    }
    if (reason.isEmpty) {
      setState(
        () => _formError =
            'Audit reason is mandatory for all distribution corrections.',
      );
      return;
    }

    setState(() => _isSaving = true);

    final success = await widget.controller.saveAuditedCorrection(
      row: record.row,
      column: _targetColumn,
      effectiveValue: value,
      reason: reason,
      author: 'Admin (Academic Timetable Lead)',
    );

    if (mounted) {
      setState(() {
        _isSaving = false;
        if (success) {
          _isEditing = false;
          _formError = null;
        } else {
          _formError = widget.controller.concurrencyConflictMessage ??
              'Failed to record correction.';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final r = widget.controller.selectedRecord;
        if (r == null) {
          return _buildNoSelectionState();
        }

        return Container(
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            border: widget.isMobileModal
                ? null
                : const Border(left: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(r),
              const Divider(color: AppColors.border, height: 1),
              Expanded(
                child: ListView(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    if (widget.controller.hasConcurrencyConflict)
                      _buildConcurrencyConflictBanner(),
                    _buildIdentityBanner(r),
                    const SizedBox(height: AppSpacing.lg),
                    // 1. Evidence
                    _buildSectionCard(
                      title: '1. SOURCE WORKBOOK EVIDENCE (A–L)',
                      icon: PhosphorIconsRegular.fileXls,
                      child: _buildEvidenceTable(r),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // 2. Effective Value
                    _buildSectionCard(
                      title: '2. EFFECTIVE OVERLAY VALUES',
                      icon: PhosphorIconsRegular.layers,
                      child: _buildEffectiveValueSection(r),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // 3. Formula & Cached
                    _buildSectionCard(
                      title: '3. FORMULA & CACHED EVIDENCE (J & L)',
                      icon: PhosphorIconsRegular.function,
                      child: _buildFormulaSection(r),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // 4. Impact Preview
                    _buildSectionCard(
                      title: '4. DETERMINISTIC SCHEDULING IMPACT',
                      icon: PhosphorIconsRegular.lightning,
                      child: _buildImpactPreview(r),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // 5. Audit Trail & Form
                    _buildSectionCard(
                      title: '5. AUDIT TRAIL & CORRECTIONS',
                      icon: PhosphorIconsRegular.clockCounterClockwise,
                      child: _buildAuditSection(r),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNoSelectionState() {
    return Container(
      color: AppColors.bgCard,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              PhosphorIconsRegular.cursorClick,
              size: 36,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: AppSpacing.md),
            Text('No Record Selected', style: AppTextStyles.h4),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Select any course distribution row to inspect its 5-part academic evidence and audit trail.',
              style: AppTextStyles.bodySm.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(DistributionSourceRecord r) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: AppSpacing.radiusSm,
            ),
            child: const Icon(
              PhosphorIconsRegular.fileText,
              color: AppColors.primary,
              size: 16,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Record Inspector · Row ${r.row}',
                  style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${r.courseCode} (Batch ${r.batch} ${r.section})',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close Inspector',
            icon: const Icon(PhosphorIconsRegular.x, size: 16),
            onPressed: widget.isMobileModal
                ? () => Navigator.of(context).pop()
                : widget.controller.closeInspector,
          ),
        ],
      ),
    );
  }

  Widget _buildConcurrencyConflictBanner() {
    final msg = widget.controller.concurrencyConflictMessage ??
        'Revision v${widget.controller.revision.revisionVersion} was modified by another committee member.';
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: AppSpacing.radiusSm,
        border: Border.all(color: AppColors.warning),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                PhosphorIconsRegular.warningCircle,
                color: AppColors.warning,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'CONCURRENCY CONFLICT (SQLSTATE 40001)',
                  style: AppTextStyles.labelCaps.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$msg Your draft inputs are preserved. You can copy your reason/value below and reload the latest revision.',
            style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                ),
                icon: const Icon(PhosphorIconsRegular.copy, size: 14),
                label: Text('Copy Draft Edits', style: AppTextStyles.captionMedium),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(
                    text:
                        'Column $_targetColumn: ${_valueController.text}\nReason: ${_reasonController.text}',
                  ));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Draft correction copied to clipboard.')),
                    );
                  }
                },
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                ),
                icon: const Icon(PhosphorIconsRegular.arrowClockwise, size: 14),
                label:
                    Text('Reload Latest Revision', style: AppTextStyles.captionMedium),
                onPressed: () async {
                  await widget.controller.reloadLatestRevision();
                  setState(() {
                    _formError = null;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityBanner(DistributionSourceRecord r) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: AppSpacing.radiusMd,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: 4,
            children: [
              Text(
                r.courseCode,
                style: AppTextStyles.h3.copyWith(
                  color: AppColors.primary,
                  fontFamilyFallback: AppTextStyles.monospaceFontFallback,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.bgPrimary,
                  borderRadius: AppSpacing.radiusSm,
                ),
                child: Text(
                  'Batch ${r.batch} · Sec ${r.section}',
                  style: AppTextStyles.captionMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            r.courseTitle,
            style: AppTextStyles.bodySmMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          if (r.hasConflict) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.errorSoft,
                borderRadius: AppSpacing.radiusSm,
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    PhosphorIconsRegular.warningCircle,
                    size: 14,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      r.conflicts.first,
                      style: AppTextStyles.captionMedium.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // PHASE 5: Dissolve nested 4-sided inner cards inside the inspector into clean
  // top-bordered sections with hard-left title alignment.
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.labelCaps,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }

  // 1. Evidence
  Widget _buildEvidenceTable(DistributionSourceRecord r) {
    final cols = [
      {'col': 'A', 'name': 'Batch', 'val': r.originalValue('A')},
      {'col': 'B', 'name': 'Section', 'val': r.originalValue('B')},
      {'col': 'C', 'name': 'Code', 'val': r.originalValue('C')},
      {'col': 'D', 'name': 'Title', 'val': r.originalValue('D')},
      {'col': 'E', 'name': 'Credit', 'val': r.originalValue('E')},
      {'col': 'F', 'name': 'Prereq', 'val': r.originalValue('F')},
      {'col': 'G', 'name': 'Dept', 'val': r.originalValue('G')},
      {'col': 'H', 'name': 'Enrolled', 'val': r.originalValue('H')},
      {'col': 'I', 'name': 'Teacher', 'val': r.originalValue('I')},
      {'col': 'J', 'name': 'Classes', 'val': r.originalValue('J')},
      {'col': 'K', 'name': 'Duration', 'val': r.originalValue('K')},
      {'col': 'L', 'name': 'Cls/Wk', 'val': r.originalValue('L')},
    ];

    return Column(
      children: cols.map((c) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Container(
                width: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.bgElevated,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  c['col']!,
                  style: AppTextStyles.caption.copyWith(
                    fontFamilyFallback: AppTextStyles.monospaceFontFallback,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 70,
                child: Text(
                  c['name']!,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  c['val']!,
                  style: AppTextStyles.captionMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // 2. Effective Value
  Widget _buildEffectiveValueSection(DistributionSourceRecord r) {
    if (!r.hasCorrection) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: AppSpacing.radiusSm,
        ),
        child: Row(
          children: [
            const Icon(
              PhosphorIconsRegular.check,
              size: 14,
              color: AppColors.success,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Identical to source evidence (No corrections applied)',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: r.corrections.map((corr) {
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.warningSoft,
            borderRadius: AppSpacing.radiusSm,
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Column ${corr.column}:',
                    style: AppTextStyles.caption.copyWith(
                      fontFamilyFallback: AppTextStyles.monospaceFontFallback,
                      fontWeight: FontWeight.bold,
                      color: AppColors.warning,
                    ),
                  ),
                  Text(
                    corr.originalValue,
                    style: AppTextStyles.caption.copyWith(
                      decoration: TextDecoration.lineThrough,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const Icon(
                    PhosphorIconsRegular.arrowRight,
                    size: 11,
                    color: AppColors.warning,
                  ),
                  Text(
                    corr.effectiveValue,
                    style: AppTextStyles.bodySmMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Reason: ${corr.reason}',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // 3. Formula Section
  Widget _buildFormulaSection(DistributionSourceRecord r) {
    return Column(
      children: [
        _formulaTile(
          label: 'Classes (Col J)',
          formula: r.formulaJ,
          cached: r.cachedJ?.toString() ?? '${r.classes}',
        ),
        const SizedBox(height: 6),
        _formulaTile(
          label: 'Class/Week (Col L)',
          formula: r.formulaL,
          cached: r.cachedL?.toString() ?? '${r.classesPerWeek}',
        ),
      ],
    );
  }

  Widget _formulaTile({
    required String label,
    required String? formula,
    required String cached,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: AppSpacing.radiusSm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.captionMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  formula != null ? 'Formula: $formula' : 'Static literal value',
                  style: AppTextStyles.caption.copyWith(
                    fontFamilyFallback: AppTextStyles.monospaceFontFallback,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.bgPrimary,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              'Cached: $cached',
              style: AppTextStyles.caption.copyWith(
                fontFamilyFallback: AppTextStyles.monospaceFontFallback,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 4. Impact Preview
  Widget _buildImpactPreview(DistributionSourceRecord r) {
    String impactExplanation = '';
    if (r.conductingDept != 'CSE') {
      impactExplanation =
          '• Service Course: Scheduled into ${r.conductingDept} faculty availability window.\n• Room Pool: Allocated from general classroom pool (RAB-301) to prevent CSE lab lock.';
    } else if (r.section.contains('+')) {
      impactExplanation =
          '• Combined Cohort (${r.studentCount ?? 80} students): Requires large hall with >=90 seats.\n• Parallel scheduling: Prevents individual Section A and Section B overlap.';
    } else if (r.credit == 1.5) {
      impactExplanation =
          '• Sessional Lab (100 min): Assigned to specialized lab (SW-LAB).\n• Boundary Rule R12/D5: Disallows lunch break crossing (12:00-13:00).';
    } else {
      impactExplanation =
          '• 3-Credit Theory: Requires 2 sessions/week with >=1 day interval (R13/D2).\n• Period Duration: 50 minutes standard slot.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.infoSoft,
        borderRadius: AppSpacing.radiusSm,
        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
      ),
      child: Text(
        impactExplanation,
        style: const TextStyle(
          fontSize: 11,
          height: 1.45,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  // 5. Audit Trail & Form
  Widget _buildAuditSection(DistributionSourceRecord r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (r.corrections.isNotEmpty) ...[
          ...r.corrections.map((corr) {
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.bgElevated,
                borderRadius: AppSpacing.radiusSm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Version v${corr.revisionVersion} · Col ${corr.column}',
                        style: AppTextStyles.captionMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        '${corr.timestamp.day}/${corr.timestamp.month}/${corr.timestamp.year}',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Author: ${corr.author}',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    'Reason: ${corr.reason}',
                    style: AppTextStyles.captionMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (!_isEditing) ...[
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onPressed: () => _startEditing('I', r.teacher),
            icon: const Icon(PhosphorIconsRegular.pencilSimple, size: 14),
            label: const Text('Add Audited Correction'),
          ),
        ] else ...[
          _buildCorrectionForm(r),
        ],
      ],
    );
  }

  Widget _buildCorrectionForm(DistributionSourceRecord r) {
    final columns = ['B', 'C', 'D', 'E', 'G', 'H', 'I'];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: AppSpacing.radiusMd,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'New Audited Correction',
                style: AppTextStyles.bodySmMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              IconButton(
                icon: const Icon(PhosphorIconsRegular.x, size: 14),
                onPressed: () => setState(() => _isEditing = false),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Target Column dropdown
          DropdownButtonFormField<String>(
            initialValue: _targetColumn,
            decoration: const InputDecoration(
              labelText: 'Target Column (A–L)',
              isDense: true,
            ),
            items: columns
                .map(
                  (c) => DropdownMenuItem(
                    value: c,
                    child: Text('Column $c: (${r.originalValue(c)})'),
                  ),
                )
                .toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _targetColumn = val;
                  _valueController.text = r.originalValue(val);
                });
              }
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          // Effective Value Field
          TextField(
            controller: _valueController,
            decoration: const InputDecoration(
              labelText: 'Effective Value',
              hintText: 'Enter replacement cell value…',
              isDense: true,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Mandatory Reason Field
          TextField(
            controller: _reasonController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Mandatory Audit Reason',
              hintText: 'Why is this correction necessary? (Required for provenance)',
              isDense: true,
            ),
          ),
          if (_formError != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              _formError!,
              style: AppTextStyles.caption.copyWith(color: AppColors.error),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => setState(() => _isEditing = false),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: AppSpacing.xs),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textPrimary,
                ),
                onPressed: _isSaving ? null : () => _submitCorrection(r),
                child: _isSaving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Audited Correction'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
