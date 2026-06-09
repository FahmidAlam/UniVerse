// ============================================================
// FILE: lib/features/admin/screens/generate_timetable_screen.dart
// PURPOSE: The advisor-required differentiator's front door.
// Admin taps Generate → the FastAPI/OR-Tools engine solves a
// conflict-free weekly routine → this screen shows the validation
// summary, stats, and a per-section preview → Publish writes it to
// `routines`, where the existing student/teacher viewers pick it up.
// Owns its TimetableGenController lifecycle. No new widgets.
// ============================================================

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:universe_v1/core/constants/app_enums.dart';
import 'package:universe_v1/core/theme/app_colors.dart';
import 'package:universe_v1/core/theme/app_spacing.dart';
import 'package:universe_v1/core/theme/app_text_styles.dart';
import 'package:universe_v1/features/admin/controllers/timetable_gen_controller.dart';
import 'package:universe_v1/features/admin/services/timetable_engine_service.dart';
import 'package:universe_v1/shared/widgets/class_card.dart';
import 'package:universe_v1/shared/widgets/stat_card.dart';
import 'package:universe_v1/shared/widgets/u_app_bar.dart';
import 'package:universe_v1/shared/widgets/u_button.dart';
import 'package:universe_v1/shared/widgets/u_card.dart';
import 'package:universe_v1/shared/widgets/u_loading.dart';

class GenerateTimetableScreen extends StatefulWidget {
  const GenerateTimetableScreen({super.key});

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
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: const UAppBar(
        title: 'Generate Timetable',
        subtitle: 'OR-Tools CP-SAT engine',
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return ListView(
            padding: AppSpacing.screenPadding,
            children: [
              _introCard(),
              AppSpacing.sectionGap,
              ..._phaseContent(),
            ],
          );
        },
      ),
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
            child: const Icon(
              PhosphorIconsRegular.magicWand,
              color: AppColors.primary,
              size: AppSpacing.iconLg,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Automatic Timetable', style: AppTextStyles.h3),
                AppSpacing.xsGap,
                Text(
                  'Builds a conflict-free weekly routine with Google '
                  'OR-Tools (CP-SAT). No teacher or section is double-booked, '
                  'day-offs are respected, and each section’s load is '
                  'spread across the week.',
                  style: AppTextStyles.bodySm,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Phase router ─────────────────────────────────────────
  List<Widget> _phaseContent() {
    switch (_controller.phase) {
      case GenPhase.idle:
        return [_generateButton('Generate Timetable')];
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
          _generateButton('Try Again'),
        ];
      case GenPhase.done:
        return _doneContent(_controller.result!);
    }
  }

  Widget _generateButton(String label) {
    return UButton(
      label: label,
      icon: PhosphorIconsRegular.sparkle,
      onPressed: _controller.generate,
    );
  }

  // ─── Solving ──────────────────────────────────────────────
  Widget _progressCard() {
    final determinate = _controller.progress > 0 && _controller.progress < 1;
    return UCard(
      child: Column(
        children: [
          const SizedBox(height: 36, child: ULoading.spinner()),
          AppSpacing.mdGap,
          Text(
            _controller.phase == GenPhase.generating
                ? 'Starting the engine…'
                : 'Solving with CP-SAT…',
            style: AppTextStyles.h4,
          ),
          AppSpacing.xsGap,
          Text(
            'This usually takes a few seconds.',
            style: AppTextStyles.caption,
          ),
          AppSpacing.lgGap,
          ClipRRect(
            borderRadius: AppSpacing.radiusFull,
            child: LinearProgressIndicator(
              value: determinate ? _controller.progress : null,
              minHeight: 6,
              color: AppColors.primary,
              backgroundColor: AppColors.bgElevated,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Done ─────────────────────────────────────────────────
  List<Widget> _doneContent(TimetableResult result) {
    final ok = result.validation['ok'] == true;
    final published = _controller.publishedCount != null;

    return [
      _messageCard(
        icon: ok
            ? PhosphorIconsRegular.checkCircle
            : PhosphorIconsRegular.warningCircle,
        color: ok ? AppColors.success : AppColors.warning,
        soft: ok ? AppColors.successSoft : AppColors.warningSoft,
        title: ok ? 'Conflict-free timetable' : 'Generated with warnings',
        body: ok
            ? 'No teacher clashes · no section clashes · day-offs respected.'
            : 'Teacher clashes: ${result.validation['teacher_clashes']} · '
                'Section clashes: ${result.validation['section_clashes']} · '
                'Day-off issues: ${result.validation['dayoff_violations']}',
      ),
      AppSpacing.sectionGap,
      _statsGrid(result),
      AppSpacing.sectionGap,
      if (published)
        _messageCard(
          icon: PhosphorIconsRegular.checkCircle,
          color: AppColors.success,
          soft: AppColors.successSoft,
          title: 'Published to the app',
          body: '${_controller.publishedCount} classes are now live. '
              'Students and teachers in this cohort can see the routine.',
        )
      else ...[
        if (_controller.publishError != null) ...[
          Text(
            _controller.publishError!,
            style: AppTextStyles.bodyError,
          ),
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
        label: 'Generate Again',
        variant: UButtonVariant.secondary,
        icon: PhosphorIconsRegular.arrowClockwise,
        onPressed: _controller.reset,
      ),
      AppSpacing.sectionGap,
      Text('PREVIEW', style: AppTextStyles.labelCaps),
      ..._buildPreview(result),
    ];
  }

  Widget _statsGrid(TimetableResult result) {
    final s = result.stats;
    final meetings = '${s['meetings'] ?? result.rows.length}';
    final sections = '${(s['sections'] as List?)?.length ?? _sectionCount(result)}';
    final teachers = '${s['teachers'] ?? '—'}';
    final solveMs = s['solve_ms'] == null ? '—' : '${s['solve_ms']} ms';

    final cards = <Widget>[
      StatCard(
        number: meetings,
        label: 'Classes',
        icon: PhosphorIconsRegular.calendarBlank,
        color: AppColors.info,
      ),
      StatCard(
        number: sections,
        label: 'Sections',
        icon: PhosphorIconsRegular.usersThree,
        color: AppColors.roleStudent,
      ),
      StatCard(
        number: teachers,
        label: 'Teachers',
        icon: PhosphorIconsRegular.chalkboardTeacher,
        color: AppColors.roleTeacher,
      ),
      StatCard(
        number: solveMs,
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

  int _sectionCount(TimetableResult result) =>
      result.rows.map((r) => r.section).toSet().length;

  // ─── Per-section, per-day preview (reuses ClassCard) ──────
  List<Widget> _buildPreview(TimetableResult result) {
    final widgets = <Widget>[];
    String? curSection;
    String? curDay;

    for (final r in result.rows) {
      if (r.section != curSection) {
        curSection = r.section;
        curDay = null;
        widgets.add(AppSpacing.lgGap);
        widgets.add(Text(
          'SECTION ${r.section} · Batch ${r.batch}',
          style: AppTextStyles.labelCaps.copyWith(color: AppColors.primary),
        ));
      }
      if (r.day != curDay) {
        curDay = r.day;
        widgets.add(AppSpacing.smGap);
        widgets.add(Text(r.day, style: AppTextStyles.bodySmMedium));
        widgets.add(AppSpacing.xsGap);
      }
      widgets.add(ClassCard(
        subject: r.subject,
        teacher: r.teacherDisplay,
        room: r.room,
        timeSlot: r.timeLabel,
        status: ClassStatus.upcoming,
      ));
      widgets.add(AppSpacing.cardGap);
    }
    return widgets;
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
                Text(title,
                    style: AppTextStyles.h4.copyWith(color: color)),
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
