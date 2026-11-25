import 'package:universe/features/admin/screens/timetable_grid_screen.dart';
import 'package:universe/features/admin/widgets/admin_card_grid.dart';
// ============================================================
// FILE: lib/features/admin/screens/upload_routine_screen.dart
// PURPOSE: Admin-only workbook import for already generated UniVerse
// routine files. Parses the rendered .xlsx, previews the extracted rows,
// then publishes them into `routines`.
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/core/router/route_names.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/admin/controllers/routine_upload_controller.dart';
import 'package:universe/features/admin/services/routine_workbook_parser.dart';
import 'package:universe/shared/widgets/stat_card.dart';
import 'package:universe/shared/widgets/u_app_bar.dart';
import 'package:universe/shared/widgets/u_button.dart';
import 'package:universe/shared/widgets/u_card.dart';
import 'package:universe/shared/widgets/u_loading.dart';

class UploadRoutineScreen extends StatefulWidget {
  final bool embedded;
  final RoutineUploadController? controller;

  const UploadRoutineScreen({
    super.key,
    this.embedded = false,
    this.controller,
  });

  @override
  State<UploadRoutineScreen> createState() => _UploadRoutineScreenState();
}

class _UploadRoutineScreenState extends State<UploadRoutineScreen> {
  late final RoutineUploadController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? RoutineUploadController();
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: ListView(
              padding: AppSpacing.screenPadding,
              children: [
                _buildInputStageCard(),
                AppSpacing.sectionGap,
                ..._phaseContent(),
              ],
            ),
          ),
        );
      },
    );

    if (widget.embedded) {
      return Material(color: AppColors.bgPrimary, child: body);
    }

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: const UAppBar(
        title: 'Upload Routine',
        subtitle: 'Publish an existing workbook',
      ),
      body: body,
    );
  }

  List<Widget> _phaseContent() {
    switch (_controller.phase) {
      case RoutineUploadPhase.idle:
        return [_parseButton()];
      case RoutineUploadPhase.parsing:
        return [
          _loadingCard('Reading workbook', 'Extracting routine cells...'),
        ];
      case RoutineUploadPhase.ready:
        return _readyContent(_controller.result!);
      case RoutineUploadPhase.publishing:
        return [
          _loadingCard('Publishing routine', 'Writing rows to the database...'),
          AppSpacing.mdGap,
          _buildPublicationPipelineCard(),
        ];
      case RoutineUploadPhase.published:
        return _publishedContent(_controller.result!);
      case RoutineUploadPhase.error:
        return [
          _messageCard(
            icon: PhosphorIconsRegular.warningCircle,
            color: AppColors.error,
            soft: AppColors.errorSoft,
            title: 'Upload failed',
            body: _controller.errorMessage ??
                'Could not read this workbook. Check the column names and try again.',
          ),
          AppSpacing.lgGap,
          _parseButton(label: 'Try Again'),
        ];
    }
  }

  // PHASE 5: Unified Top-Lit Input Stage Card ("Walmart receipt" edge alignment)
  Widget _buildInputStageCard() {
    final name = _controller.fileName;
    return UCard(
      isTopLit: true,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.infoSoft,
                    borderRadius: AppSpacing.radiusSm,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    PhosphorIconsRegular.uploadSimple,
                    color: AppColors.info,
                    size: 18,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Upload Routine', style: AppTextStyles.h4),
                      const SizedBox(height: 2),
                      Text(
                        'Import a rendered routine workbook (.xlsx), inspect the parsed day sheets and conflict report, then publish atomically.',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.border),
          InkWell(
            onTap: _controller.pickFile,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  Icon(
                    name == null
                        ? PhosphorIconsRegular.filePlus
                        : PhosphorIconsRegular.fileXls,
                    color:
                        name == null ? AppColors.textMuted : AppColors.success,
                    size: AppSpacing.iconMd,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name ?? 'Choose routine workbook',
                          style: AppTextStyles.bodyMedium,
                        ),
                        Text(
                          name == null
                              ? 'Routine .xlsx workbook'
                              : 'Loaded · Tap to change file',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: name != null
                          ? AppColors.successSoft
                          : AppColors.bgElevated,
                      borderRadius: AppSpacing.radiusSm,
                      border: Border.all(
                        color: name != null
                            ? AppColors.success.withValues(alpha: 0.4)
                            : AppColors.border,
                      ),
                    ),
                    child: Text(
                      name != null ? 'Workbook Loaded' : 'Select .xlsx',
                      style: AppTextStyles.captionMedium.copyWith(
                        color: name != null
                            ? AppColors.success
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // PHASE 5: 3-Step Post-Parse Publication Pipeline
  Widget _buildPublicationPipelineCard() {
    final isPublished = _controller.phase == RoutineUploadPhase.published;
    return UCard(
      isTopLit: true,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Text(
              'POST-PARSE PUBLICATION PIPELINE',
              style: AppTextStyles.labelCaps.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.border),
          _buildPipelineStepRow(
            step: '1. Storage Archive',
            subtitle: 'Archive source .xlsx to routine-workbooks bucket',
            done: _controller.storageUploaded,
            warning: isPublished && !_controller.storageUploaded,
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.border),
          _buildPipelineStepRow(
            step: '2. Atomic publish_routine RPC',
            subtitle:
                'Replace active campus routine slots in a single transaction',
            done: _controller.routinePublished,
            warning: false,
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.border),
          _buildPipelineStepRow(
            step: '3. Run History & Notification',
            subtitle: 'Record audit trail in timetable_runs',
            done: _controller.historyRecorded,
            warning: _controller.secondaryWarning != null,
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineStepRow({
    required String step,
    required String subtitle,
    required bool done,
    required bool warning,
  }) {
    final color = done
        ? AppColors.success
        : (warning ? AppColors.warning : AppColors.textMuted);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(
            done
                ? PhosphorIconsRegular.checkCircle
                : (warning
                    ? PhosphorIconsRegular.warningCircle
                    : PhosphorIconsRegular.circle),
            size: 16,
            color: color,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step, style: AppTextStyles.bodyMedium),
                Text(subtitle, style: AppTextStyles.caption),
              ],
            ),
          ),
          Text(
            done ? 'Complete' : (warning ? 'Notice' : 'Pending'),
            style: AppTextStyles.captionMedium.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  Widget _parseButton({String label = 'Review Workbook'}) {
    return UButton(
      label: label,
      icon: PhosphorIconsRegular.magnifyingGlass,
      onPressed: _controller.hasFile ? _controller.parse : null,
    );
  }

  Widget _loadingCard(String title, String body) {
    return UCard(
      child: Column(
        children: [
          const SizedBox(height: 36, child: ULoading.spinner()),
          AppSpacing.mdGap,
          Text(title, style: AppTextStyles.h4, textAlign: TextAlign.center),
          AppSpacing.xsGap,
          Text(body, style: AppTextStyles.caption, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  List<Widget> _readyContent(RoutineWorkbookParseResult result) {
    final ok = result.validation['ok'] == true;
    return [
      _messageCard(
        icon: ok
            ? PhosphorIconsRegular.checkCircle
            : PhosphorIconsRegular.warningCircle,
        color: ok ? AppColors.success : AppColors.warning,
        soft: ok ? AppColors.successSoft : AppColors.warningSoft,
        title: ok ? 'Workbook ready' : 'Review warnings',
        body: ok
            ? '${result.rows.length} routine slots from ${result.sourceFormat} are ready to publish.'
            : 'Publication is blocked. Resolve the invalid times or resource conflicts in the source workbook and review it again.',
      ),
      AppSpacing.sectionGap,
      _statsGrid(result),
      AppSpacing.lgGap,
      _parsedSummary(result),
      if (_controller.errorMessage != null) ...[
        AppSpacing.mdGap,
        Text(_controller.errorMessage!, style: AppTextStyles.bodyError),
      ],
      if (result.warnings.isNotEmpty) ...[
        AppSpacing.sectionGap,
        _warningsCard(result.warnings),
      ],
      AppSpacing.sectionGap,
      _buildPublicationPipelineCard(),
      AppSpacing.sectionGap,
      UButton(
        label: 'Preview in Timetable Grid',
        variant: UButtonVariant.secondary,
        icon: PhosphorIconsRegular.gridFour,
        onPressed: () => context.push(RouteNames.timetableGrid,
            extra: TimetablePreview(rows: result.rows)),
      ),
      AppSpacing.smGap,
      UButton(
        label: 'Publish to App',
        icon: PhosphorIconsRegular.uploadSimple,
        onPressed: ok ? _controller.publish : null,
      ),
      AppSpacing.smGap,
      UButton(
        label: 'Choose Another File',
        variant: UButtonVariant.secondary,
        icon: PhosphorIconsRegular.arrowClockwise,
        onPressed: _controller.reset,
      ),
      const SizedBox(height: AppSpacing.x4l),
    ];
  }

  List<Widget> _publishedContent(RoutineWorkbookParseResult result) {
    return [
      _messageCard(
        icon: PhosphorIconsRegular.checkCircle,
        color: AppColors.success,
        soft: AppColors.successSoft,
        title: 'Published to the app',
        body: '${_controller.publishedCount ?? result.rows.length} classes are '
            'now live. Students and teachers can see the uploaded routine.',
      ),
      if (_controller.secondaryWarning != null) ...[
        AppSpacing.smGap,
        _messageCard(
          icon: PhosphorIconsRegular.info,
          color: AppColors.warning,
          soft: AppColors.warningSoft,
          title: 'Routine is live · Secondary log notice',
          body: _controller.secondaryWarning!,
        ),
      ],
      AppSpacing.sectionGap,
      _buildPublicationPipelineCard(),
      AppSpacing.sectionGap,
      _statsGrid(result),
      AppSpacing.sectionGap,
      UButton(
        label: 'Upload Another Routine',
        variant: UButtonVariant.secondary,
        icon: PhosphorIconsRegular.arrowClockwise,
        onPressed: _controller.reset,
      ),
      const SizedBox(height: AppSpacing.x4l),
    ];
  }

  Widget _parsedSummary(RoutineWorkbookParseResult result) => UCard(
        isTopLit: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Parsed workbook summary', style: AppTextStyles.h4),
          AppSpacing.smGap,
          for (final row in [
            ('Source format', result.sourceFormat),
            ('Scheduled slots', '${result.rows.length}'),
            (
              'Days represented',
              '${result.rows.map((r) => r.day).toSet().length}'
            ),
            (
              'Rooms assigned',
              '${result.rows.map((r) => r.room).toSet().length}'
            ),
            (
              'Validation',
              result.validation['ok'] == true
                  ? 'Passed workbook checks'
                  : 'Publication blocked'
            ),
          ]) ...[
            Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(children: [
                  Expanded(child: Text(row.$1, style: AppTextStyles.bodySm)),
                  Flexible(
                      child: Text(row.$2,
                          style: AppTextStyles.captionMedium,
                          textAlign: TextAlign.end)),
                ])),
            const Divider(height: 1, color: AppColors.border),
          ],
        ]),
      );

  Widget _statsGrid(RoutineWorkbookParseResult result) {
    String f(String key) => '${result.stats[key] ?? 0}';
    final v = result.validation;
    final clashCount = ((v['teacher_clashes'] as num?) ?? 0) +
        ((v['cohort_clashes'] as num?) ?? 0) +
        ((v['room_clashes'] as num?) ?? 0);

    return AdminCardGrid(
      children: [
        StatCard(
          number: f('meetings'),
          label: 'Classes',
          icon: PhosphorIconsRegular.calendarBlank,
          color: AppColors.info,
        ),
        StatCard(
          number: f('cohorts'),
          label: 'Cohorts',
          icon: PhosphorIconsRegular.usersThree,
          color: AppColors.roleStudent,
        ),
        StatCard(
          number: f('teachers'),
          label: 'Teachers',
          icon: PhosphorIconsRegular.chalkboardTeacher,
          color: AppColors.roleTeacher,
        ),
        StatCard(
          number: '$clashCount',
          label: 'Clashes',
          icon: PhosphorIconsRegular.warning,
          color: clashCount == 0 ? AppColors.success : AppColors.warning,
        ),
      ],
    );
  }

  Widget _warningsCard(List<String> warnings) {
    final shown = warnings.take(5).toList();
    final remaining = warnings.length - shown.length;
    return UCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('WARNINGS', style: AppTextStyles.labelCaps),
          AppSpacing.smGap,
          for (final warning in shown)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    PhosphorIconsRegular.warning,
                    size: AppSpacing.iconSm,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(warning, style: AppTextStyles.bodySm)),
                ],
              ),
            ),
          if (remaining > 0)
            Text(
              '$remaining more warning${remaining == 1 ? '' : 's'}',
              style: AppTextStyles.caption,
            ),
        ],
      ),
    );
  }

  Widget _messageCard({
    required IconData icon,
    required Color color,
    required Color soft,
    required String title,
    required String body,
  }) {
    return UCard(
      color: soft,
      border: Border.all(color: color, width: AppSpacing.borderThin),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: AppSpacing.iconLg),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.h4.copyWith(color: color)),
                AppSpacing.xsGap,
                Text(body, style: AppTextStyles.bodySm),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
