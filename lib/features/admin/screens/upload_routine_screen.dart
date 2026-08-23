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

  const UploadRoutineScreen({super.key, this.embedded = false});

  @override
  State<UploadRoutineScreen> createState() => _UploadRoutineScreenState();
}

class _UploadRoutineScreenState extends State<UploadRoutineScreen> {
  late final RoutineUploadController _controller;

  @override
  void initState() {
    super.initState();
    _controller = RoutineUploadController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return ListView(
          padding: AppSpacing.screenPadding,
          children: [_introCard(), AppSpacing.sectionGap, ..._phaseContent()],
        );
      },
    );

    if (widget.embedded) return body;

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
        return [_filePicker(), AppSpacing.lgGap, _parseButton()];
      case RoutineUploadPhase.parsing:
        return [
          _loadingCard('Reading workbook', 'Extracting routine cells...'),
        ];
      case RoutineUploadPhase.ready:
        return _readyContent(_controller.result!);
      case RoutineUploadPhase.publishing:
        return [
          _loadingCard('Publishing routine', 'Writing rows to the database...'),
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
          _filePicker(),
          AppSpacing.lgGap,
          _parseButton(label: 'Try Again'),
        ];
    }
  }

  Widget _introCard() {
    return UCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.infoSoft,
              borderRadius: AppSpacing.radiusMd,
            ),
            child: const Icon(
              PhosphorIconsRegular.uploadSimple,
              color: AppColors.info,
              size: AppSpacing.iconLg,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Upload Routine', style: AppTextStyles.h3),
                AppSpacing.xsGap,
                Text(
                  'Choose a routine workbook. UniVerse can read its generated '
                  'day sheets or a table with routine columns, preview the '
                  'slots, then publish them directly to the database.',
                  style: AppTextStyles.bodySm,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filePicker() {
    final name = _controller.fileName;
    return UCard(
      onTap: _controller.pickFile,
      child: Row(
        children: [
          Icon(
            name == null
                ? PhosphorIconsRegular.filePlus
                : PhosphorIconsRegular.fileXls,
            color: name == null ? AppColors.textMuted : AppColors.success,
            size: AppSpacing.iconLg,
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
                  name == null ? 'Routine .xlsx workbook' : 'Tap to change',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          const Icon(
            PhosphorIconsRegular.folderOpen,
            size: AppSpacing.iconMd,
            color: AppColors.textMuted,
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
            : 'The workbook can still be published, but check the summary first.',
      ),
      AppSpacing.sectionGap,
      _statsGrid(result),
      if (_controller.errorMessage != null) ...[
        AppSpacing.mdGap,
        Text(_controller.errorMessage!, style: AppTextStyles.bodyError),
      ],
      if (result.warnings.isNotEmpty) ...[
        AppSpacing.sectionGap,
        _warningsCard(result.warnings),
      ],
      AppSpacing.sectionGap,
      UButton(
        label: 'View Full Grid',
        variant: UButtonVariant.secondary,
        icon: PhosphorIconsRegular.gridFour,
        onPressed: () =>
            context.push(RouteNames.timetableGrid, extra: result.rows),
      ),
      AppSpacing.smGap,
      UButton(
        label: 'Publish to App',
        icon: PhosphorIconsRegular.uploadSimple,
        onPressed: _controller.publish,
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

  Widget _statsGrid(RoutineWorkbookParseResult result) {
    String f(String key) => '${result.stats[key] ?? 0}';
    final v = result.validation;
    final clashCount = ((v['teacher_clashes'] as num?) ?? 0) +
        ((v['cohort_clashes'] as num?) ?? 0) +
        ((v['room_clashes'] as num?) ?? 0);

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: 1.7,
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
