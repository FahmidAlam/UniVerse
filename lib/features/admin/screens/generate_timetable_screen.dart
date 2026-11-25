import 'package:flutter/services.dart';
import 'package:universe/features/admin/widgets/admin_card_grid.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/core/router/route_names.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/admin/controllers/timetable_gen_controller.dart';
import 'package:universe/features/admin/services/timetable_engine_service.dart';
import 'package:universe/features/admin/services/timetable_config_service.dart';
import 'package:universe/features/admin/screens/timetable_grid_screen.dart';
import 'package:universe/shared/widgets/stat_card.dart';
import 'package:universe/shared/widgets/u_app_bar.dart';
import 'package:universe/shared/widgets/u_button.dart';
import 'package:universe/shared/widgets/u_card.dart';
import 'package:universe/shared/widgets/u_loading.dart';
import 'package:universe/shared/widgets/u_segmented_control.dart';

class GenerateTimetableScreen extends StatefulWidget {
  final bool embedded;
  final TimetableGenController? controller;
  final bool showConfigurationLinks;

  const GenerateTimetableScreen(
      {super.key,
      this.embedded = false,
      this.controller,
      this.showConfigurationLinks = true});

  @override
  State<GenerateTimetableScreen> createState() =>
      _GenerateTimetableScreenState();
}

class _GenerateTimetableScreenState extends State<GenerateTimetableScreen> {
  late final TimetableGenController _controller;
  int _inputMode = 0; // 0: Native UI Catalog, 1: Excel Workbook (.xlsx)
  final TimetableConfigService _configService = TimetableConfigService();
  int _courseCount = 8;
  int _batchCount = 4;
  int _sectionCount = 7;
  int _facultyCount = 6;
  int _roomCount = 6;
  bool _synthesizing = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TimetableGenController();
    _loadCatalogCounts();
  }

  Future<void> _loadCatalogCounts() async {
    try {
      final courses = await _configService.fetchCatalogCourses();
      final batches = await _configService.fetchBatches();
      final faculty = await _configService.fetchFaculty();
      final rooms = await _configService.fetchRooms();
      if (!mounted) return;
      setState(() {
        _courseCount = courses.length;
        _batchCount = batches.length;
        _sectionCount = batches.fold(0, (sum, b) => sum + b.sections.length);
        _facultyCount = faculty.length;
        _roomCount = rooms.where((r) => r.isActive).length;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return LayoutBuilder(builder: (context, constraints) {
          final setup = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStageOneCard(context),
              AppSpacing.lgGap,
              _baselineReadiness(),
            ],
          );
          final telemetry = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_controller.isBusy) ...[
                _progressCard(),
                AppSpacing.lgGap,
              ],
              ..._phaseContent(),
              if (_controller.phase != GenPhase.done) ...[
                AppSpacing.lgGap,
                _publicationGate(),
              ],
            ],
          );
          return ListView(
            padding: AppSpacing.screenPadding,
            children: [
              if (constraints.maxWidth >= 960)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 58, child: setup),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(flex: 42, child: telemetry),
                  ],
                )
              else ...[setup, AppSpacing.lgGap, telemetry],
            ],
          );
        });
      },
    );

    if (widget.embedded) {
      return Material(color: AppColors.bgPrimary, child: body);
    }

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: const UAppBar(
        title: 'Generate Timetable',
        subtitle: 'OR-Tools CP-SAT engine',
      ),
      body: body,
    );
  }

  Widget _buildStageOneCard(BuildContext context) {
    final name = _controller.fileName;
    return UCard(
      isTopLit: true,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: AppSpacing.radiusMd,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Icon(
                    PhosphorIconsRegular.magicWand,
                    color: AppColors.primary,
                    size: AppSpacing.iconMd,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'STAGE 1 · INPUT SOURCE & BASELINE READINESS',
                            style: AppTextStyles.labelCaps.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.successSoft,
                              borderRadius: AppSpacing.radiusSm,
                            ),
                            child: Text(
                              'ENGINE WORKFLOW',
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppColors.success,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Upload the semester’s Course Distribution workbook. The engine builds a conflict-free routine — no teacher, section or room double-booking, day-offs and Friday rules honoured.',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (widget.showConfigurationLinks) ...[
            const Divider(color: AppColors.border, height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: _configRow(),
            ),
          ],
          const Divider(color: AppColors.border, height: 1),
          // Co-existence Input Mode Switcher (Phase B1)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: USegmentedControl<int>(
              selected: _inputMode,
              onChanged: (v) => setState(() => _inputMode = v),
              segments: const [
                USegment(
                  value: 0,
                  label: 'UI Catalog & Batch Offerings (Native)',
                  icon: PhosphorIconsRegular.database,
                ),
                USegment(
                  value: 1,
                  label: 'Excel Workbook (.xlsx)',
                  icon: PhosphorIconsRegular.fileXls,
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.border, height: 1),
          if (_inputMode == 0) ...[
            // Native UI Catalog Readiness & Synthesis View
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.roleTeacher.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          PhosphorIconsRegular.checkCircle,
                          color: AppColors.roleTeacher,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Native UI Catalog Ready for Engine Synthesis',
                          style: AppTextStyles.bodySm.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.bgSubtle,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      '$_courseCount Courses · $_batchCount Batches ($_sectionCount Sections) · $_facultyCount Faculty · $_roomCount Active Pool Rooms · 7-Day Grid (Jummah Blocked)',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      UButton(
                        label: 'Synthesize & Generate Routine',
                        icon: PhosphorIconsRegular.lightning,
                        isLoading: _synthesizing,
                        fullWidth: false,
                        onPressed: () async {
                          setState(() => _synthesizing = true);
                          try {
                            final records = await _configService.synthesizeDistributionFromCatalog();
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Synthesized ${records.length} distribution records directly from UI Catalog.',
                                ),
                                backgroundColor: AppColors.roleTeacher,
                              ),
                            );
                            _controller.generate();
                          } finally {
                            if (mounted) setState(() => _synthesizing = false);
                          }
                        },
                      ),
                      UButton(
                        label: 'Export .xlsx Summary',
                        variant: UButtonVariant.secondary,
                        icon: PhosphorIconsRegular.downloadSimple,
                        fullWidth: false,
                        onPressed: () async {
                          final summary = await _configService.exportCatalogToWorkbookSummary();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Catalog exported: ${summary['totalRecords']} records across ${summary['totalBatches']} batches.',
                              ),
                              backgroundColor: AppColors.info,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            // Run Profile row
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: _profileSection(),
            ),
            const Divider(color: AppColors.border, height: 1),
            _sourceIdentity(),
            const Divider(color: AppColors.border, height: 1),
            // Distribution Workbook Picker row
            InkWell(
              onTap: _controller.isBusy ? null : _controller.pickFile,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    Icon(
                      name == null
                          ? PhosphorIconsRegular.filePlus
                          : PhosphorIconsRegular.fileXls,
                      color:
                          name == null ? AppColors.textMuted : AppColors.success,
                      size: AppSpacing.iconLg,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name ?? 'Choose distribution file',
                            style: AppTextStyles.bodyMedium,
                          ),
                          Text(
                            name == null
                                ? 'Main_Distribution_*.xlsx'
                                : 'Tap to change workbook',
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
              ),
            ),
          ],
        ],
      ),
    );
  }

  // PHASE 5: Provenance comes only from the accepted source contract.
  Widget _sourceIdentity() {
    final hash = _controller.sourceContract?['source_sha256']?.toString();
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('SOURCE SHA-256', style: AppTextStyles.labelCaps),
        AppSpacing.smGap,
        Row(children: [
          Expanded(
              child: SelectableText(hash ?? 'Available after source validation',
                  style: AppTextStyles.caption)),
          IconButton(
            tooltip: 'Copy source SHA-256',
            onPressed: hash == null
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(text: hash));
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Source hash copied')));
                    }
                  },
            icon: const Icon(Icons.copy, size: AppSpacing.iconSm),
          ),
        ]),
      ]),
    );
  }

  Widget _baselineReadiness() {
    final config = _controller.runProfile?.engineConfig;
    final resources = [
      ('Rooms', 'rooms'),
      ('Faculty', 'teachers'),
      ('Course Eligibility', 'eligibility')
    ];
    return UCard(
        isTopLit: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Baseline resource readiness', style: AppTextStyles.h4),
            AppSpacing.smGap,
            Text(
                config == null
                    ? 'Database resources are verified by the engine during ingest.'
                    : 'Counts from the bound private profile; hosted readiness is not implied.',
                style: AppTextStyles.caption),
            AppSpacing.mdGap,
            for (final resource in resources) ...[
              Builder(builder: (context) {
                final value = config?[resource.$2];
                final count = value is List
                    ? value.length
                    : value is Map
                        ? value.length
                        : null;
                return Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Row(children: [
                      Icon(
                          count == 0
                              ? Icons.warning_amber_rounded
                              : Icons.circle_outlined,
                          size: AppSpacing.iconSm,
                          color: count == 0
                              ? AppColors.warning
                              : AppColors.textMuted),
                      AppSpacing.smHGap,
                      Expanded(
                          child:
                              Text(resource.$1, style: AppTextStyles.bodySm)),
                      Text(
                          count == null ? 'Not inspected' : '$count in profile',
                          style: AppTextStyles.captionMedium.copyWith(
                              color: count == 0
                                  ? AppColors.warning
                                  : AppColors.textSecondary)),
                    ]));
              }),
              const Divider(height: 1, color: AppColors.border),
            ],
          ],
        ));
  }

  Widget _publicationGate() => UCard(
      isTopLit: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Validation & publication gate', style: AppTextStyles.h4),
          AppSpacing.smGap,
          Text(
              'A completed result and academic validation are required. Publication remains controlled by the existing server contract.',
              style: AppTextStyles.bodySm),
          AppSpacing.mdGap,
          Row(children: [
            const Icon(Icons.lock_outline,
                size: AppSpacing.iconSm, color: AppColors.textMuted),
            AppSpacing.smHGap,
            Expanded(
                child: Text('Waiting for validated candidate',
                    style: AppTextStyles.captionMedium)),
          ]),
        ],
      ));

  Widget _configRow() {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        _configBtn('Rooms', PhosphorIconsRegular.door, RouteNames.manageRooms),
        _configBtn(
          'Faculty',
          PhosphorIconsRegular.usersThree,
          RouteNames.manageFaculty,
        ),
        _configBtn(
          'Courses',
          PhosphorIconsRegular.checkSquare,
          RouteNames.manageCourseEligibility,
        ),
        _configBtn(
          'Settings',
          PhosphorIconsRegular.sliders,
          RouteNames.timetableSettings,
        ),
      ],
    );
  }

  Widget _profileSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _controller.runProfile?.label ?? 'Run profile (optional)',
                  style: AppTextStyles.bodySmMedium,
                ),
                Text(
                  _controller.runProfile?.provenance ??
                      'Use current settings, or import a source-matched profile for a private rehearsal.',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
            TextButton(
              onPressed: _controller.isBusy ? null : _controller.pickRunProfile,
              child: const Text('Import run profile (.json)'),
            ),
          ],
        ),
        if (_controller.runProfile != null) ...[
          const SizedBox(height: 4),
          Text(
            'Private preview • ${_controller.runProfile!.countPolicy == 'distribution' ? 'Meeting counts from source' : 'Explicit fixed meeting count'} • Database settings unchanged',
            style: AppTextStyles.caption.copyWith(color: AppColors.info),
          ),
          TextButton(
            onPressed: _controller.isBusy ? null : _controller.clearRunProfile,
            child: const Text('Use database settings instead'),
          ),
        ],
        if (_controller.profileError != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _controller.profileError!,
              style: AppTextStyles.bodyError,
            ),
          ),
      ],
    );
  }

  Widget _configBtn(String label, IconData icon, String route) {
    return InkWell(
      onTap: () => context.push(route),
      borderRadius: AppSpacing.radiusSm,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: AppSpacing.radiusSm,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 15),
            const SizedBox(width: 6),
            Text(label, style: AppTextStyles.captionMedium),
          ],
        ),
      ),
    );
  }

  List<Widget> _phaseContent() {
    switch (_controller.phase) {
      case GenPhase.idle:
        return [_generateButton()];
      case GenPhase.generating:
      case GenPhase.polling:
        return [_progressCard()];
      case GenPhase.error:
        return [
          _buildServiceRecoveryCard(),
          AppSpacing.lgGap,
          _generateButton(label: 'Try Again'),
        ];
      case GenPhase.done:
        return _doneContent(_controller.result!);
    }
  }

  Widget _generateButton({String label = 'Generate Timetable'}) {
    return UButton(
      label: label,
      icon: PhosphorIconsRegular.sparkle,
      onPressed: _controller.hasFile ? _controller.generate : null,
    );
  }

  // PHASE 5: Stage 2 — 4-Node Visual Timeline for Solver Execution
  Widget _progressCard() {
    final isUploading = _controller.phase == GenPhase.generating;
    final state = _controller.activeJobState;
    final busy = _controller.isBusy;
    final completed = _controller.phase == GenPhase.done;

    const stages = [
      ('queued', '1. Queued', 'Job registered with engine worker'),
      (
        'ingesting',
        '2. Ingesting & Validating',
        'Parsing Course Distribution & verifying teacher/room readiness'
      ),
      (
        'solving',
        '3. CP-SAT Session & Room Placement',
        'Running OR-Tools constraint solver across sections & labs'
      ),
      (
        'rendering',
        '4. Rendering Timetable',
        'Building workbook sheets & auditing academic constraints'
      ),
    ];

    int activeIdx = 0;
    for (int i = 0; i < stages.length; i++) {
      if (stages[i].$1 == state) {
        activeIdx = i;
        break;
      }
    }
    if (isUploading) activeIdx = 0;
    if (!busy) activeIdx = completed ? stages.length : -1;

    return UCard(
      isTopLit: true,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (busy)
                const SizedBox(width: 24, height: 24, child: ULoading.spinner())
              else
                Icon(completed ? Icons.check_circle_outline : Icons.timeline,
                    color: AppColors.textMuted),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'STAGE 2 · SOLVER EXECUTION TIMELINE',
                      style: AppTextStyles.labelCaps.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isUploading
                          ? 'Waking the engine & uploading…'
                          : 'Solving with CP-SAT…',
                      style: AppTextStyles.h4,
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
                  color: AppColors.bgElevated,
                  borderRadius: AppSpacing.radiusSm,
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  busy
                      ? '${(_controller.progress * 100).round()}%'
                      : (completed ? 'Result ready' : 'Not running'),
                  style: AppTextStyles.numeric.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.mdGap,
          if (busy)
            ClipRRect(
              borderRadius: AppSpacing.radiusFull,
              child: LinearProgressIndicator(
                value:
                    isUploading ? null : _controller.progress.clamp(0.0, 1.0),
                minHeight: 6,
                color: AppColors.primary,
                backgroundColor: AppColors.bgElevated,
              ),
            ),
          AppSpacing.lgGap,
          for (int i = 0; i < stages.length; i++) ...[
            _buildTimelineNode(
              title: stages[i].$2,
              subtitle: stages[i].$3,
              isCompleted: i < activeIdx,
              isActive: i == activeIdx,
              isLast: i == stages.length - 1,
            ),
          ],
          const Divider(height: 24, color: AppColors.border),
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

  Widget _buildTimelineNode({
    required String title,
    required String subtitle,
    required bool isCompleted,
    required bool isActive,
    required bool isLast,
  }) {
    final dotColor = isCompleted
        ? AppColors.success
        : (isActive ? AppColors.primary : AppColors.border);
    final textColor =
        isCompleted || isActive ? AppColors.textPrimary : AppColors.textMuted;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: isCompleted
                  ? AppColors.successSoft
                  : (isActive ? AppColors.primarySoft : AppColors.bgElevated),
              shape: BoxShape.circle,
              border: Border.all(color: dotColor, width: isActive ? 2 : 1),
            ),
            alignment: Alignment.center,
            child: Icon(
              isCompleted
                  ? PhosphorIconsRegular.check
                  : PhosphorIconsRegular.circle,
              size: isActive ? 8 : 12,
              color: isCompleted
                  ? AppColors.success
                  : (isActive ? AppColors.primary : AppColors.textMuted),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(color: textColor),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(
                    color: isActive
                        ? AppColors.textSecondary
                        : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // PHASE 5: Service Recovery Paradox Card when solver/network fails
  Widget _buildServiceRecoveryCard() {
    return UCard(
      isTopLit: true,
      border: Border.all(color: AppColors.error.withValues(alpha: 0.45)),
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
                    color: AppColors.errorSoft,
                    borderRadius: AppSpacing.radiusSm,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    PhosphorIconsRegular.warningCircle,
                    color: AppColors.error,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Generation could not complete',
                        style:
                            AppTextStyles.h4.copyWith(color: AppColors.error),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _controller.errorMessage ?? 'Unknown error',
                        style: AppTextStyles.bodySm,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      PhosphorIconsRegular.shieldCheck,
                      size: 16,
                      color: AppColors.info,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _controller.hasFile
                            ? 'Input preserved: "${_controller.fileName}" remains loaded in memory — no re-upload required.'
                            : 'Your baseline settings remain intact. Select a Course Distribution workbook to retry.',
                        style: AppTextStyles.captionMedium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _configBtn(
                      'Inspect Settings',
                      PhosphorIconsRegular.slidersHorizontal,
                      RouteNames.timetableSettings,
                    ),
                    _configBtn(
                      'Manage Rooms',
                      PhosphorIconsRegular.door,
                      RouteNames.manageRooms,
                    ),
                    _configBtn(
                      'Course Eligibility',
                      PhosphorIconsRegular.graduationCap,
                      RouteNames.manageCourseEligibility,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Names the courses behind a failed validation. "3 courses missing" is not
  /// actionable; "CSE-4116 for 60-A is missing" is.
  /// One line naming exactly what failed: the course, the cohort, the
  /// teacher, when, and — where the engine supplied one — why and what to
  /// change. The engine's detail entries are deliberately not uniform (a room
  /// clash has no `code`, a missing course has no `day`), so every field is
  /// optional and only the present ones are shown.
  String _describeFailure(Map<String, dynamic> m) {
    final parts = <String>[];
    if (m['code'] != null) parts.add('${m['code']}');
    if (m['cohort'] != null) parts.add('${m['cohort']}');
    if (m['teacher'] != null) parts.add('${m['teacher']}');
    if (m['room'] != null && m['code'] == null) parts.add('${m['room']}');

    final when = <String>[
      if (m['day'] != null) '${m['day']}',
      if (m['periods'] != null)
        'P${(m['periods'] as List).join(" + P")}'
      else if (m['period'] != null)
        'P${m['period']}',
    ].join(' ');
    if (when.isNotEmpty) parts.add(when);

    final courses = m['courses'];
    if (courses is List && courses.isNotEmpty) {
      parts.add(courses.join(' vs '));
    }

    final req = m['required'];
    final got = m['scheduled'];
    if (req != null && got != null) {
      parts.add('needs $req, has $got');
    } else if (req != null) {
      parts.add('needs $req');
    }
    if (m['reason'] != null) parts.add('${m['reason']}');

    return parts.isEmpty ? m.toString() : parts.join('  —  ');
  }

  Widget _validationDetails(Map<String, dynamic> v) {
    final details = (v['details'] as Map?)?.cast<String, dynamic>() ?? const {};
    const labels = {
      'missing_courses': 'Missing from the routine',
      'under_scheduled': 'Too few classes for the credit',
      'over_scheduled': 'Too many classes',
      'unexpected_courses': 'Not in the distribution',
      'same_day_sessions': 'Scheduled twice on the same day',
      'ineligible_assignments': 'Teacher not eligible for this course',
      'teacher_clashes': 'Teacher in two places at once',
      'cohort_clashes': 'Section double-booked',
      'room_clashes': 'Room double-booked',
      'dayoff_violations': "On the teacher's day off",
      'blocked_period_violations': 'In a period that is not taught',
      'lab_room_violations': 'Lab in a non-lab room',
      'unplaced_rooms': 'No room could be assigned',
      'invalid_time_slots': 'At an unconfigured time',
      'invalid_days': 'On a day that is not taught',
    };

    final blocks = <Widget>[];
    for (final entry in labels.entries) {
      final items = (details[entry.key] as List?) ?? const [];
      if (items.isEmpty) continue;
      blocks
        ..add(Text(entry.value, style: AppTextStyles.h4))
        ..add(AppSpacing.xsGap);
      for (final raw in items.take(12)) {
        blocks.add(Text(_describeFailure((raw as Map).cast<String, dynamic>()),
            style: AppTextStyles.bodySm));
      }
      if (items.length > 12) {
        blocks.add(
            Text('+ ${items.length - 12} more', style: AppTextStyles.caption));
      }
      blocks.add(AppSpacing.smGap);
    }
    if (blocks.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppSpacing.radiusMd,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: blocks,
      ),
    );
  }

  List<Widget> _doneContent(TimetableResult result) {
    final v = result.validation;
    final ok = blockingValidationErrorFor(v) == null;
    final published = _controller.publishedCount != null;

    int n(String k) => (v[k] as num?)?.toInt() ?? 0;

    return [
      _messageCard(
        icon: ok
            ? PhosphorIconsRegular.checkCircle
            : PhosphorIconsRegular.warningCircle,
        color: ok ? AppColors.success : AppColors.error,
        soft: ok ? AppColors.successSoft : AppColors.errorSoft,
        title: ok
            ? 'Valid against the distribution'
            : 'This routine is not academically valid',
        body: ok
            ? 'All ${n('required_offerings')} courses scheduled with the right '
                'number of classes · no teacher, section or room clashes · '
                'day-offs and blocked periods respected.'
            : 'Missing: ${n('missing_courses')} · Too few classes: '
                '${n('under_scheduled')} · Too many: ${n('over_scheduled')} · '
                'Not in distribution: ${n('unexpected_courses')} · '
                'Teacher: ${n('teacher_clashes')} · Section: '
                '${n('cohort_clashes')} · Room: ${n('room_clashes')} · '
                'Day-off: ${n('dayoff_violations')} · Lab-room: '
                '${n('lab_room_violations')}',
      ),
      if (!ok) ...[
        AppSpacing.smGap,
        _validationDetails(v),
      ],
      AppSpacing.sectionGap,
      _statsGrid(result),
      AppSpacing.sectionGap,
      _reportCard(result),
      AppSpacing.sectionGap,
      UButton(
        label: 'Open Full Grid Preview',
        variant: UButtonVariant.secondary,
        icon: PhosphorIconsRegular.gridFour,
        onPressed: () => context.push(RouteNames.timetableGrid,
            extra: TimetablePreview(
                rows: result.allRows,
                roomAliases: Map<String, String>.from(_controller
                        .runProfile?.engineConfig['room_aliases'] as Map? ??
                    {}))),
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
      if (result.allRows.any((r) => r.requiresSharedTeacherStorage))
        Text(
            'The workbook prints primary faculty. Save the private draft to retain every shared faculty assignment.',
            style: AppTextStyles.caption),
      AppSpacing.smGap,
      UButton(
          label: 'Save private draft (all faculty)',
          variant: UButtonVariant.secondary,
          onPressed: () async {
            try {
              final path = await _controller.saveDraft();
              if (mounted && path != null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text(
                        'Private draft saved with all faculty assignments.')));
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('$e')));
              }
            }
          }),
      AppSpacing.sectionGap,
      if (published) ...[
        _messageCard(
          icon: PhosphorIconsRegular.checkCircle,
          color: AppColors.success,
          soft: AppColors.successSoft,
          title: 'Published to the app',
          body: '${_controller.publishedCount} classes are now live across all '
              'cohorts. Students and teachers can see the routine.',
        ),
        if (_controller.publishSecondaryWarning != null) ...[
          AppSpacing.smGap,
          _messageCard(
            icon: PhosphorIconsRegular.info,
            color: AppColors.warning,
            soft: AppColors.warningSoft,
            title: 'Routine is live · Secondary log notice',
            body: _controller.publishSecondaryWarning!,
          ),
        ],
      ] else ...[
        if (_controller.publishError != null) ...[
          Text(_controller.publishError!, style: AppTextStyles.bodyError),
          AppSpacing.smGap,
        ],
        UButton(
          label: 'Publish to App',
          icon: PhosphorIconsRegular.uploadSimple,
          isLoading: _controller.isPublishing,
          // A routine that does not match the distribution must never reach
          // students. Fix the input or the settings and generate again.
          onPressed: _controller.blockingValidationError == null
              ? _controller.publish
              : null,
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
    return AdminCardGrid(
      children: cards,
    );
  }

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
            '$excluded source rows excluded — review the input report',
            color: AppColors.textSecondary,
          ),
          if (n('pending_faculty_offerings') > 0)
            _reportRow(PhosphorIconsRegular.usersThree,
                '${n('pending_faculty_offerings')} offerings have faculty pending; no substitute was assigned.'),
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
          Icon(icon,
              size: AppSpacing.iconSm, color: color ?? AppColors.textMuted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: AppTextStyles.bodySm)),
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
