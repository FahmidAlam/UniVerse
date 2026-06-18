// ============================================================
// FILE: lib/features/admin/screens/generate_timetable_screen.dart
// PURPOSE: The advisor-required differentiator's front door.
// Admin picks the Main Distribution .xlsx → the FastAPI/OR-Tools engine
// ingests it, solves a conflict-free routine, and renders a workbook →
// this screen shows the ingest report, validation, stats and a grid
// preview → Download saves the .xlsx, Publish writes it to `routines`
// where the existing student/teacher viewers pick it up.
// Owns its TimetableGenController lifecycle.
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:universe_v1/core/router/route_names.dart';
import 'package:universe_v1/core/theme/app_colors.dart';
import 'package:universe_v1/core/theme/app_spacing.dart';
import 'package:universe_v1/core/theme/app_text_styles.dart';
import 'package:universe_v1/features/admin/controllers/timetable_gen_controller.dart';
import 'package:universe_v1/features/admin/services/timetable_engine_service.dart';
import 'package:universe_v1/shared/widgets/stat_card.dart';
import 'package:universe_v1/shared/widgets/u_app_bar.dart';
import 'package:universe_v1/shared/widgets/u_button.dart';
import 'package:universe_v1/shared/widgets/u_card.dart';
import 'package:universe_v1/shared/widgets/u_loading.dart';

class GenerateTimetableScreen extends StatefulWidget {
  /// When hosted inside the admin Routine hub, drop the Scaffold/app bar.
  final bool embedded;

  const GenerateTimetableScreen({super.key, this.embedded = false});

  @override
  State<GenerateTimetableScreen> createState() =>
      _GenerateTimetableScreenState();
}

class _GenerateTimetableScreenState extends State<GenerateTimetableScreen> {
  late final TimetableGenController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TimetableGenController();
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
          children: [
            _introCard(),
            AppSpacing.mdGap,
            _configRow(),
            AppSpacing.sectionGap,
            ..._phaseContent(),
          ],
        );
      },
    );

    if (widget.embedded) return body;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: const UAppBar(
        title: 'Generate Timetable',
        subtitle: 'OR-Tools CP-SAT engine',
      ),
      body: body,
    );
  }

  // ─── Intro ────────────────────────────────────────────────
  Widget _introCard() {
    return UCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: AppSpacing.radiusMd,
            ),
            child: const Icon(PhosphorIconsRegular.magicWand,
                color: AppColors.primary, size: AppSpacing.iconLg),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Automatic Timetable', style: AppTextStyles.h3),
                AppSpacing.xsGap,
                Text(
                  'Upload the semester’s Course Distribution workbook. The '
                  'engine builds a conflict-free routine — no teacher, section '
                  'or room double-booking, day-offs and Friday rules honoured.',
                  style: AppTextStyles.bodySm,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Config shortcuts ─────────────────────────────────────
  Widget _configRow() {
    return Row(
      children: [
        _configBtn('Rooms', PhosphorIconsRegular.door, RouteNames.manageRooms),
        AppSpacing.smHGap,
        _configBtn('Faculty', PhosphorIconsRegular.usersThree,
            RouteNames.manageFaculty),
        AppSpacing.smHGap,
        _configBtn('Settings', PhosphorIconsRegular.sliders,
            RouteNames.timetableSettings),
      ],
    );
  }

  Widget _configBtn(String label, IconData icon, String route) {
    return Expanded(
      child: UCard(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        onTap: () => context.push(route),
        child: Column(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: AppSpacing.iconMd),
            AppSpacing.xsGap,
            Text(label, style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }

  // ─── Phase router ─────────────────────────────────────────
  List<Widget> _phaseContent() {
    switch (_controller.phase) {
      case GenPhase.idle:
        return [_filePicker(), AppSpacing.lgGap, _generateButton()];
      case GenPhase.generating:
      case GenPhase.polling:
        return [_progressCard()];
      case GenPhase.error:
        return [
          _messageCard(
            icon: PhosphorIconsRegular.warningCircle,
            color: AppColors.error,
            soft: AppColors.errorSoft,
            title: 'Generation failed',
            body: _controller.errorMessage ??
                'Something went wrong. Check that the engine is running.',
          ),
          AppSpacing.lgGap,
          _filePicker(),
          AppSpacing.lgGap,
          _generateButton(label: 'Try Again'),
        ];
      case GenPhase.done:
        return _doneContent(_controller.result!);
    }
  }

  // ─── File picker ──────────────────────────────────────────
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
                Text(name ?? 'Choose distribution file',
                    style: AppTextStyles.bodyMedium),
                Text(
                  name == null ? 'Main_Distribution_*.xlsx' : 'Tap to change',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          const Icon(PhosphorIconsRegular.folderOpen,
              size: AppSpacing.iconMd, color: AppColors.textMuted),
        ],
      ),
    );
  }

  Widget _generateButton({String label = 'Generate Timetable'}) {
    return UButton(
      label: label,
      icon: PhosphorIconsRegular.sparkle,
      onPressed: _controller.hasFile ? _controller.generate : null,
    );
  }

  // ─── Solving ──────────────────────────────────────────────
  Widget _progressCard() {
    final isUploading = _controller.phase == GenPhase.generating;
    return UCard(
      child: Column(
        children: [
          const SizedBox(height: 36, child: ULoading.spinner()),
          AppSpacing.mdGap,
          Text(
            isUploading
                ? 'Waking the engine & uploading…'
                : 'Solving with CP-SAT…',
            style: AppTextStyles.h4,
            textAlign: TextAlign.center,
          ),
          AppSpacing.xsGap,
          Text(
            'This can take up to ~60 seconds — hang tight, it isn’t stuck.',
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
          AppSpacing.lgGap,
          // Indeterminate on purpose: the engine reports coarse progress, so
          // an animating bar reads as "working" instead of parking mid-way.
          const ClipRRect(
            borderRadius: AppSpacing.radiusFull,
            child: LinearProgressIndicator(
              minHeight: 6,
              color: AppColors.primary,
              backgroundColor: AppColors.bgElevated,
            ),
          ),
          AppSpacing.mdGap,
          // Cold-start hint — Render's free tier sleeps after ~15 min idle.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                PhosphorIconsRegular.moon,
                size: AppSpacing.iconSm,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'First run after a while can take ~50s while the server wakes '
                  'up. That’s normal — later runs are much faster.',
                  style: AppTextStyles.caption,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Done ─────────────────────────────────────────────────
  List<Widget> _doneContent(TimetableResult result) {
    final v = result.validation;
    final ok = v['ok'] == true;
    final published = _controller.publishedCount != null;

    int n(String k) => (v[k] as num?)?.toInt() ?? 0;

    return [
      _messageCard(
        icon: ok
            ? PhosphorIconsRegular.checkCircle
            : PhosphorIconsRegular.warningCircle,
        color: ok ? AppColors.success : AppColors.warning,
        soft: ok ? AppColors.successSoft : AppColors.warningSoft,
        title: ok ? 'Conflict-free timetable' : 'Generated with warnings',
        body: ok
            ? 'No teacher, section or room clashes · day-offs & Friday rules respected.'
            : 'Teacher: ${n('teacher_clashes')} · Section: ${n('cohort_clashes')} · '
                'Room: ${n('room_clashes')} · Day-off: ${n('dayoff_violations')} · '
                'Lab-room: ${n('lab_room_violations')}',
      ),
      AppSpacing.sectionGap,
      _statsGrid(result),
      AppSpacing.sectionGap,
      _reportCard(result),
      AppSpacing.sectionGap,
      UButton(
        label: 'View Full Grid',
        variant: UButtonVariant.secondary,
        icon: PhosphorIconsRegular.gridFour,
        onPressed: () =>
            context.push(RouteNames.timetableGrid, extra: result.rows),
      ),
      AppSpacing.smGap,
      if (_controller.downloadError != null) ...[
        Text(_controller.downloadError!, style: AppTextStyles.bodyError),
        AppSpacing.smGap,
      ],
      UButton(
        label: 'Download Workbook (.xlsx)',
        variant: UButtonVariant.secondary,
        icon: PhosphorIconsRegular.downloadSimple,
        isLoading: _controller.isDownloading,
        onPressed: _controller.downloadAndOpen,
      ),
      AppSpacing.sectionGap,
      if (published)
        _messageCard(
          icon: PhosphorIconsRegular.checkCircle,
          color: AppColors.success,
          soft: AppColors.successSoft,
          title: 'Published to the app',
          body: '${_controller.publishedCount} classes are now live across all '
              'cohorts. Students and teachers can see the routine.',
        )
      else ...[
        if (_controller.publishError != null) ...[
          Text(_controller.publishError!, style: AppTextStyles.bodyError),
          AppSpacing.smGap,
        ],
        UButton(
          label: 'Publish to App',
          icon: PhosphorIconsRegular.uploadSimple,
          isLoading: _controller.isPublishing,
          onPressed: _controller.publish,
        ),
      ],
      AppSpacing.smGap,
      UButton(
        label: 'Start Over',
        variant: UButtonVariant.secondary,
        icon: PhosphorIconsRegular.arrowClockwise,
        onPressed: _controller.reset,
      ),
      const SizedBox(height: AppSpacing.x4l),
    ];
  }

  Widget _statsGrid(TimetableResult result) {
    final s = result.stats;
    String f(Object? v) => v == null ? '—' : '$v';
    final solveMs = s['solve_ms'];
    final cards = <Widget>[
      StatCard(
        number: f(s['meetings']),
        label: 'Classes',
        icon: PhosphorIconsRegular.calendarBlank,
        color: AppColors.info,
      ),
      StatCard(
        number: f(s['cohorts']),
        label: 'Cohorts',
        icon: PhosphorIconsRegular.usersThree,
        color: AppColors.roleStudent,
      ),
      StatCard(
        number: f(s['teachers']),
        label: 'Teachers',
        icon: PhosphorIconsRegular.chalkboardTeacher,
        color: AppColors.roleTeacher,
      ),
      StatCard(
        number: solveMs == null ? '—' : '$solveMs ms',
        label: 'Solve time',
        icon: PhosphorIconsRegular.timer,
        color: AppColors.primary,
      ),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: 1.7,
      children: cards,
    );
  }

  // ─── Ingest report ────────────────────────────────────────
  Widget _reportCard(TimetableResult result) {
    final m = result.report.meta;
    final excluded = result.report.excluded.length;
    final warnings = result.report.warnings.length;
    int n(String k) => (m[k] as num?)?.toInt() ?? 0;

    return UCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('INGEST REPORT', style: AppTextStyles.labelCaps),
          AppSpacing.smGap,
          _reportRow(PhosphorIconsRegular.stack,
              '${n('offerings')} offerings → ${n('sessions')} sessions'),
          _reportRow(PhosphorIconsRegular.usersThree,
              '${n('render_sessions')} CSE · ${n('service_sessions')} service (resource-only)'),
          _reportRow(
            excluded == 0
                ? PhosphorIconsRegular.checkCircle
                : PhosphorIconsRegular.minusCircle,
            '$excluded excluded (project/thesis · no batch)',
            color: AppColors.textSecondary,
          ),
          if (warnings > 0)
            _reportRow(PhosphorIconsRegular.warning,
                '$warnings data warning${warnings == 1 ? '' : 's'}',
                color: AppColors.warning),
        ],
      ),
    );
  }

  Widget _reportRow(IconData icon, String text, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: AppSpacing.iconSm,
              color: color ?? AppColors.textMuted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: AppTextStyles.bodySm)),
        ],
      ),
    );
  }

  // ─── Reusable message banner ──────────────────────────────
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
