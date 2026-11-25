// PHASE A: ManageBatchesScreen — Cohort Batches & Sections with Joint Sections and R1/R2 Verification (55/45 Master-Detail)
import 'package:flutter/material.dart';
import 'package:universe/core/models/admin_catalog_models.dart';
import 'package:universe/core/models/timetable_config_model.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/admin/controllers/batches_controller.dart';
import 'package:universe/features/admin/services/timetable_config_service.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/shared/widgets/desktop_shell_scope.dart';
import 'package:universe/shared/widgets/u_adaptive_overlay.dart';
import 'package:universe/shared/widgets/u_app_bar.dart';
import 'package:universe/shared/widgets/u_button.dart';
import 'package:universe/shared/widgets/u_card.dart';
import 'package:universe/shared/widgets/u_chip.dart';
import 'package:universe/shared/widgets/u_empty_state.dart';
import 'package:universe/shared/widgets/u_loading.dart';
import 'package:universe/shared/widgets/u_text_field.dart';
import 'package:universe/shared/widgets/u_combobox.dart';

class ManageBatchesScreen extends StatefulWidget {
  final BatchesController? controller;
  final TimetableConfigService? configService;

  const ManageBatchesScreen({super.key, this.controller, this.configService});

  @override
  State<ManageBatchesScreen> createState() => _ManageBatchesScreenState();
}

class _ManageBatchesScreenState extends State<ManageBatchesScreen> {
  late final BatchesController _controller;
  late final TimetableConfigService _configService;
  late final bool _ownsController;

  // Catalog courses & faculty for curriculum assignment
  List<CatalogCourse> _availableCourses = [];
  List<TimetableFaculty> _availableFaculty = [];

  // Selected batch draft state
  CohortBatch? _selectedBatch;
  bool _isCreatingNew = false;
  bool _isDirty = false;

  late TextEditingController _batchNameController;
  late TextEditingController _semesterController;
  final TextEditingController _searchController = TextEditingController();
  List<String> _sections = ['A'];
  List<String> _combinedSections = [];
  Map<String, List<String>> _sectionWeekends = {};
  Map<String, int> _sectionDaysOff = {};
  List<BatchCourseOffering> _offerings = [];

  // Joint section picker draft
  String? _jointSec1;
  String? _jointSec2;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _configService = widget.configService ?? TimetableConfigService();
    _controller = widget.controller ?? BatchesController(service: _configService);
    _batchNameController = TextEditingController();
    _semesterController = TextEditingController();
    _controller.addListener(_onControllerUpdated);
    _controller.load();
    _loadCatalogCourses();
  }

  @override
  void dispose() {
    _batchNameController.dispose();
    _semesterController.dispose();
    _searchController.dispose();
    _controller.removeListener(_onControllerUpdated);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCatalogCourses() async {
    try {
      final results = await Future.wait([
        _configService.fetchCatalogCourses(),
        _configService.fetchFaculty(),
      ]);
      if (mounted) {
        setState(() {
          _availableCourses = results[0] as List<CatalogCourse>;
          _availableFaculty = results[1] as List<TimetableFaculty>;
        });
      }
    } catch (_) {}
  }

  void _onControllerUpdated() {
    if (!mounted) return;
    if (_searchController.text != _controller.searchQuery) {
      _searchController.text = _controller.searchQuery;
    }
    if (_selectedBatch == null && _controller.allBatches.isNotEmpty && !_isCreatingNew) {
      _initDraftWithBatch(_controller.allBatches.first);
    }
    setState(() {});
  }

  void _initDraftWithBatch(CohortBatch batch) {
    _selectedBatch = batch;
    _isCreatingNew = false;
    _isDirty = false;
    _batchNameController.text = batch.batchName;
    _semesterController.text = batch.semesterLabel;
    _sections = List<String>.from(batch.sections);
    _combinedSections = List<String>.from(batch.combinedSections);
    _sectionWeekends = {
      for (final e in batch.sectionWeekends.entries) e.key: List<String>.from(e.value),
    };
    _sectionDaysOff = Map<String, int>.from(batch.sectionWeeklyDaysOffCount);
    _offerings = List<BatchCourseOffering>.from(batch.offerings);
  }

  void _initNewBatchDraft() {
    _selectedBatch = null;
    _isCreatingNew = true;
    _isDirty = true;
    _batchNameController.text = 'Batch ${_controller.totalBatches + 58}';
    _semesterController.text = '1st Semester';
    _sections = ['A', 'B'];
    _combinedSections = [];
    _sectionWeekends = {
      'A': ['Thu', 'Fri'],
      'B': ['Thu', 'Fri'],
    };
    _sectionDaysOff = {
      'A': 2,
      'B': 2,
    };
    _offerings = [];
  }

  void _markDirty() {
    if (!_isDirty) {
      setState(() => _isDirty = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktopShell = DesktopShellScope.isDesktopOf(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: isDesktopShell
          ? null
          : const UAppBar(
              title: 'Batches & Sections',
              showBackButton: true,
            ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (_controller.isLoading) {
            return const Center(child: ULoading.spinner());
          }

          final batches = _controller.filteredBatches;

          return LayoutBuilder(
            builder: (context, constraints) {
              final usableWidth = constraints.maxWidth;
              final isMasterDetail = usableWidth >= 900;

              return Column(
                children: [
                  _buildTopFilterStrip(usableWidth),
                  Expanded(
                    child: batches.isEmpty
                        ? UEmptyState(
                            icon: PhosphorIconsRegular.users,
                            title: 'No batches found',
                            message: 'Try clearing your search query or semester filter.',
                            action: UButton(
                              label: 'Reset Filters',
                              fullWidth: false,
                              onPressed: () {
                                _controller.setQuery('');
                                _controller.setSemesterFilter('All');
                              },
                            ),
                          )
                        : isMasterDetail
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Left 55% Master List
                                  Expanded(
                                    flex: 55,
                                    child: _buildMasterList(batches, isMasterDetail: true),
                                  ),
                                  const VerticalDivider(
                                    color: AppColors.border,
                                    width: 1,
                                  ),
                                  // Right 45% Docked Detail Inspector
                                  Expanded(
                                    flex: 45,
                                    child: _buildInspectorCard(isSheet: false),
                                  ),
                                ],
                              )
                            : _buildMasterList(batches, isMasterDetail: false),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTopFilterStrip(double usableWidth) {
    final isCompact = usableWidth < 768;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgSubtle,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: UTextField(
                  label: 'Search Batches',
                  hint: 'Search batches or semesters...',
                  controller: _searchController,
                  prefixIcon: PhosphorIconsRegular.magnifyingGlass,
                  onChanged: (q) => _controller.setQuery(q),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              UButton(
                label: isCompact ? 'Add' : 'New Batch',
                icon: PhosphorIconsRegular.plus,
                fullWidth: false,
                onPressed: () {
                  setState(() {
                    _initNewBatchDraft();
                  });
                  if (usableWidth < 900) {
                    _openAdaptiveInspectorModal(context);
                  }
                },
              ),
            ],
          ),
          AppSpacing.xsGap,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Upfront count pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: AppSpacing.radiusSm,
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  'Showing ${_controller.filteredCount} batches · ${_controller.totalSections} total sections',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ...['All', '1st', '2nd', '3rd', '4th', '5th', '6th', '7th', '8th'].map((sem) {
                final label = sem == 'All' ? 'All' : '$sem Sem';
                final isSel = _controller.semesterFilter == (sem == 'All' ? 'All' : sem);
                return UChip(
                  label: label,
                  isActive: isSel,
                  onTap: () => _controller.setSemesterFilter(sem == 'All' ? 'All' : sem),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMasterList(List<CohortBatch> batches, {required bool isMasterDetail}) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: UCard(
        isTopLit: true,
        padding: EdgeInsets.zero,
        child: ListView.separated(
          itemCount: batches.length,
          separatorBuilder: (_, __) => const Divider(
            color: AppColors.border,
            height: 1,
            thickness: 1,
          ),
          itemBuilder: (context, index) {
            final batch = batches[index];
            final isSelected = isMasterDetail && _selectedBatch?.id == batch.id && !_isCreatingNew;
            final isR1Compliant = batch.satisfiesAllR1Weekends;
            final isR2Compliant = batch.satisfiesR2Parity;
            final isR1R2Verified = isR1Compliant && isR2Compliant;

            return InkWell(
              onTap: () {
                setState(() {
                  _initDraftWithBatch(batch);
                });
                if (!isMasterDetail) {
                  _openAdaptiveInspectorModal(context);
                }
              },
              child: Container(
                color: isSelected ? AppColors.surfaceInteractive : Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    // 3px semantic left bar on selected row only (Unslop #1, #13)
                    Container(
                      width: 3.5,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Batch Name & Semester
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Text(
                                batch.batchName,
                                style: AppTextStyles.h4.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceElevated,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Text(
                                  batch.semesterLabel,
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Sections and Combined Section Pills
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              ...batch.sections.map((sec) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppColors.bgSubtle,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: Text(
                                      'Sec $sec',
                                      style: AppTextStyles.caption.copyWith(
                                        fontSize: 10,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  )),
                              ...batch.combinedSections.map((joint) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppColors.info.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(3),
                                      border: Border.all(color: AppColors.info.withValues(alpha: 0.5)),
                                    ),
                                    child: Text(
                                      'Joint $joint',
                                      style: AppTextStyles.caption.copyWith(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.info,
                                      ),
                                    ),
                                  )),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // Total Credits and R1/R2 Status
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${batch.totalCreditsOffered.toStringAsFixed(1)} Cr · ${batch.offerings.length} Courses',
                          style: AppTextStyles.numeric.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        // Semantic exception badge only (Unslop #1: Checkbox Off = Gray / No filler badges)
                        if (!isR1R2Verified) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.error),
                            ),
                            child: Text(
                              !isR1Compliant
                                  ? 'R1 Non-Consecutive'
                                  : 'R2 Variance > 1d',
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _openAdaptiveInspectorModal(BuildContext context) {
    showUAdaptiveModal<void>(
      context: context,
      title: _isCreatingNew ? 'Create New Batch' : 'Batch Inspector · ${_batchNameController.text}',
      builder: (ctx) => _buildInspectorCard(isSheet: true),
    );
  }

  Widget _buildInspectorCard({required bool isSheet}) {
    // Current draft R1 & R2 metrics
    final testBatch = CohortBatch(
      id: _selectedBatch?.id ?? 'temp',
      batchName: _batchNameController.text,
      semesterLabel: _semesterController.text,
      sections: _sections,
      combinedSections: _combinedSections,
      sectionWeekends: _sectionWeekends,
      sectionWeeklyDaysOffCount: _sectionDaysOff,
      offerings: _offerings,
    );
    final variance = testBatch.daysOffVariance;
    final r2Compliant = testBatch.satisfiesR2Parity;

    return Container(
      padding: EdgeInsets.all(isSheet ? AppSpacing.md : AppSpacing.lg),
      child: UCard(
        isTopLit: true,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isCreatingNew
                              ? 'New Cohort Batch'
                              : 'Cohort & Offerings Inspector (${_batchNameController.text})',
                          style: AppTextStyles.h4,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.info,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Saved in Catalog Store · Staged for Phase D',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_isDirty) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.warning),
                      ),
                      child: Text(
                        'Unsaved Changes',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const Divider(color: AppColors.border, height: 24),

              // Section 1 — Cohort & Section Structure
              Text('SECTION 1 — COHORT & SECTION STRUCTURE', style: AppTextStyles.labelCaps),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: UTextField(
                      controller: _batchNameController,
                      label: 'Batch Name',
                      hint: 'e.g. Batch 58',
                      onChanged: (_) => _markDirty(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: UTextField(
                      controller: _semesterController,
                      label: 'Semester Label',
                      hint: 'e.g. 5th Semester',
                      onChanged: (_) => _markDirty(),
                    ),
                  ),
                ],
              ),
              AppSpacing.smGap,
              // Sections Chip Generator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Sections (${_sections.length} Active)', style: AppTextStyles.label),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(PhosphorIconsRegular.plusCircle, size: 18),
                        tooltip: 'Add Section',
                        onPressed: () {
                          final nextLetter = String.fromCharCode(65 + _sections.length);
                          setState(() {
                            _sections.add(nextLetter);
                            _sectionWeekends[nextLetter] = ['Thu', 'Fri'];
                            _sectionDaysOff[nextLetter] = 2;
                            _markDirty();
                          });
                        },
                      ),
                      if (_sections.length > 1)
                        IconButton(
                          icon: const Icon(PhosphorIconsRegular.minusCircle, size: 18),
                          tooltip: 'Remove Last Section',
                          onPressed: () {
                            setState(() {
                              final removed = _sections.removeLast();
                              _sectionWeekends.remove(removed);
                              _sectionDaysOff.remove(removed);
                              _markDirty();
                            });
                          },
                        ),
                    ],
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _sections.map((sec) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: AppSpacing.radiusSm,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text('Section $sec', style: AppTextStyles.bodySm),
                  );
                }).toList(),
              ),
              AppSpacing.smGap,
              // Combined / Joint Section Builder
              Text('Combined / Joint Sections (Atomic Cohorts)', style: AppTextStyles.label),
              const SizedBox(height: 4),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Pick Sec 1
                  DropdownButton<String>(
                    value: _jointSec1,
                    hint: const Text('Sec 1', style: TextStyle(color: AppColors.textMuted)),
                    dropdownColor: AppColors.bgCard,
                    items: _sections.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setState(() => _jointSec1 = v),
                  ),
                  const Text('+', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  // Pick Sec 2
                  DropdownButton<String>(
                    value: _jointSec2,
                    hint: const Text('Sec 2', style: TextStyle(color: AppColors.textMuted)),
                    dropdownColor: AppColors.bgCard,
                    items: _sections.where((s) => s != _jointSec1).map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setState(() => _jointSec2 = v),
                  ),
                  UButton(
                    label: 'Create Joint Section',
                    icon: PhosphorIconsRegular.link,
                    variant: UButtonVariant.secondary,
                    fullWidth: false,
                    onPressed: (_jointSec1 != null && _jointSec2 != null)
                        ? () {
                            final jointTag = '$_jointSec1+$_jointSec2';
                            if (!_combinedSections.contains(jointTag)) {
                              setState(() {
                                _combinedSections.add(jointTag);
                                _jointSec1 = null;
                                _jointSec2 = null;
                                _markDirty();
                              });
                            }
                          }
                        : null,
                  ),
                ],
              ),
              if (_combinedSections.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: _combinedSections.map((joint) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.info),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Joint $joint',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.info,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () {
                              setState(() {
                                _combinedSections.remove(joint);
                                _markDirty();
                              });
                            },
                            child: const Icon(PhosphorIconsRegular.x, size: 14, color: AppColors.info),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
              const Divider(color: AppColors.border, height: 28),

              // Section 2 — Committee Rules R1 & R2
              Text('SECTION 2 — RULES R1 & R2 (WEEKENDS & DAYS-OFF PARITY)', style: AppTextStyles.labelCaps),
              const SizedBox(height: 8),
              // Per-section 2-Day Consecutive Weekend Selector (Rule R1)
              ..._sections.map((sec) {
                final currentWeekend = _sectionWeekends[sec] ?? ['Thu', 'Fri'];
                final weekendTag = currentWeekend.join('+');
                final isR1Valid = testBatch.satisfiesR1ConsecutiveWeekend(sec);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 70,
                        child: Text('Sec $sec R1:', style: AppTextStyles.bodySm),
                      ),
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            'Sun+Mon',
                            'Mon+Tue',
                            'Tue+Wed',
                            'Wed+Thu',
                            'Thu+Fri',
                            'Fri+Sat',
                            'Sat+Sun'
                          ].map((pair) {
                            final isSel = weekendTag == pair;
                            return UChip(
                              label: pair,
                              isActive: isSel,
                              onTap: () {
                                setState(() {
                                  _sectionWeekends[sec] = pair.split('+');
                                  _markDirty();
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                      if (!isR1Valid)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(PhosphorIconsRegular.warning, size: 16, color: AppColors.error),
                        ),
                    ],
                  ),
                );
              }),
              AppSpacing.xsGap,
              // Visual R2 Days-Off Balance Bar
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.bgSubtle,
                  borderRadius: AppSpacing.radiusSm,
                  border: Border.all(color: r2Compliant ? AppColors.border : AppColors.error),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text('R2 Batch Days-Off Balance',
                              style: AppTextStyles.label),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: r2Compliant
                                  ? AppColors.roleTeacher.withValues(alpha: 0.12)
                                  : AppColors.error.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              r2Compliant
                                  ? 'Δ = $variance day · R2 Compliant'
                                  : 'Δ = $variance days · R2 Imbalance Violation',
                              style: AppTextStyles.caption.copyWith(
                                fontWeight: FontWeight.bold,
                                color: r2Compliant
                                    ? AppColors.roleTeacher
                                    : AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    ..._sections.map((sec) {
                      final daysOff = _sectionDaysOff[sec] ?? 2;
                      final summaryLabel =
                          '$daysOff days off (${7 - daysOff} teaching days)';
                      final progressBar = ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: daysOff / 7.0,
                          backgroundColor: AppColors.surfaceElevated,
                          color: r2Compliant ? AppColors.info : AppColors.error,
                          minHeight: 8,
                        ),
                      );
                      final decBtn = IconButton(
                        icon: const Icon(PhosphorIconsRegular.minus, size: 12),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: daysOff > 1
                            ? () {
                                setState(() {
                                  _sectionDaysOff[sec] = daysOff - 1;
                                  _markDirty();
                                });
                              }
                            : null,
                      );
                      final incBtn = IconButton(
                        icon: const Icon(PhosphorIconsRegular.plus, size: 12),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: daysOff < 5
                            ? () {
                                setState(() {
                                  _sectionDaysOff[sec] = daysOff + 1;
                                  _markDirty();
                                });
                              }
                            : null,
                      );
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth < 440) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      SizedBox(
                                        width: 48,
                                        child: Text('Sec $sec:',
                                            style: AppTextStyles.caption),
                                      ),
                                      Expanded(child: progressBar),
                                      const SizedBox(width: 8),
                                      decBtn,
                                      const SizedBox(width: 4),
                                      incBtn,
                                    ],
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        left: 48, top: 2, bottom: 2),
                                    child: Text(
                                      summaryLabel,
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }
                            return Row(
                              children: [
                                SizedBox(
                                  width: 48,
                                  child: Text('Sec $sec:',
                                      style: AppTextStyles.caption),
                                ),
                                Expanded(child: progressBar),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    summaryLabel,
                                    style: AppTextStyles.caption,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                decBtn,
                                const SizedBox(width: 4),
                                incBtn,
                              ],
                            );
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const Divider(color: AppColors.border, height: 28),

              // Section 3 — Batch Course Offerings
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'SECTION 3 — COURSE OFFERINGS',
                      style: AppTextStyles.labelCaps,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${testBatch.totalCreditsOffered.toStringAsFixed(1)} Total Cr',
                    style: AppTextStyles.numeric.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_offerings.isEmpty)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.bgSubtle,
                    borderRadius: AppSpacing.radiusSm,
                  ),
                  child: Text(
                    'No courses assigned to this cohort yet.',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _offerings.length,
                  separatorBuilder: (_, __) => const Divider(color: AppColors.border, height: 1),
                  itemBuilder: (context, idx) {
                    final o = _offerings[idx];
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceElevated,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    o.courseCode,
                                    style: AppTextStyles.bodySm
                                        .copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color:
                                        AppColors.info.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text(
                                    'Sec ${o.targetSection}',
                                    style: AppTextStyles.caption
                                        .copyWith(color: AppColors.info),
                                  ),
                                ),
                                if (o.primaryTeacherAcronym != null)
                                  Text(
                                    'Teacher: ${o.primaryTeacherAcronym}',
                                    style: AppTextStyles.caption.copyWith(
                                        color: AppColors.textSecondary),
                                  ),
                                if (o.coTeacherAcronyms.isNotEmpty)
                                  Text(
                                    ' / ${o.coTeacherAcronyms.join(', ')}',
                                    style: AppTextStyles.caption
                                        .copyWith(color: AppColors.textMuted),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (o.credits != null)
                            Text(
                              '${o.credits!.toStringAsFixed(1)} Cr',
                              style: AppTextStyles.numeric,
                            ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () {
                              setState(() {
                                _offerings.removeAt(idx);
                                _markDirty();
                              });
                            },
                            child: const Icon(PhosphorIconsRegular.trash,
                                size: 16, color: AppColors.error),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              AppSpacing.smGap,
              // Assign Course from Catalog
              UButton(
                label: 'Assign Course from Catalog',
                icon: PhosphorIconsRegular.plus,
                variant: UButtonVariant.secondary,
                fullWidth: false,
                onPressed: () => _openAssignCourseModal(context),
              ),
              // Action Footer: Visible only when isDirty or creating new (Unslop #2)
              if (_isDirty || _isCreatingNew) ...[
                const Divider(color: AppColors.border, height: 28),
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      if (!_isCreatingNew && _selectedBatch != null)
                        IconButton(
                          icon: const Icon(PhosphorIconsRegular.trash,
                              color: AppColors.error),
                          tooltip: 'Delete Batch',
                          onPressed: () => _confirmDelete(context),
                        )
                      else
                        const SizedBox.shrink(),
                      Wrap(
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          UButton(
                            label: 'Discard',
                            variant: UButtonVariant.secondary,
                            fullWidth: false,
                            onPressed: () {
                              setState(() {
                                if (_selectedBatch != null) {
                                  _initDraftWithBatch(_selectedBatch!);
                                } else {
                                  _initNewBatchDraft();
                                }
                              });
                            },
                          ),
                          UButton(
                            label: 'Save Batch',
                            fullWidth: false,
                            onPressed: _saveBatch,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openAssignCourseModal(BuildContext context) {
    String? selectedCode =
        _availableCourses.isNotEmpty ? _availableCourses.first.code : null;
    String targetSec = _sections.isNotEmpty ? _sections.first : 'A';
    const customFacultySentinel = '__CUSTOM__';
    String selectedTeacherOption = _availableFaculty.isNotEmpty
        ? _availableFaculty.first.acronym
        : customFacultySentinel;
    final teacherCtrl = TextEditingController(
      text: _availableFaculty.isNotEmpty ? '' : 'MSA',
    );
    String? modalError;

    showUAdaptiveModal<void>(
      context: context,
      title: 'Assign Course from Catalog',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final allTargets = [
            ..._sections,
            ..._combinedSections,
            if (_sections.length > 1) 'All',
          ];
          final isCustomTeacher =
              selectedTeacherOption == customFacultySentinel ||
                  _availableFaculty.isEmpty;

          return Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UCombobox<String>(
                  label: 'Catalog Course',
                  hint: 'Search course code or title…',
                  value: selectedCode,
                  items: [
                    for (final c in _availableCourses)
                      UComboboxItem<String>(
                        value: c.code,
                        label: '${c.code} · ${c.title}',
                        subtitle:
                            '${c.credits} Cr · ${c.courseType.toUpperCase()}',
                        icon: PhosphorIconsRegular.graduationCap,
                      ),
                  ],
                  allowClear: false,
                  onChanged: (v) => setModalState(() {
                    selectedCode = v;
                    modalError = null;
                  }),
                ),
                AppSpacing.mdGap,
                UCombobox<String>(
                  label: 'Target Section or Joint Section',
                  hint: 'Select section…',
                  value: targetSec,
                  items: [
                    for (final t in allTargets)
                      UComboboxItem<String>(
                        value: t,
                        label: t == 'All' ? 'All Sections' : 'Section $t',
                        subtitle: t.contains('+') ? 'Joint Section' : null,
                        icon: t.contains('+')
                            ? PhosphorIconsRegular.usersThree
                            : PhosphorIconsRegular.user,
                        color: t.contains('+') ? AppColors.info : null,
                      ),
                  ],
                  allowClear: false,
                  onChanged: (v) => setModalState(() {
                    targetSec = v ?? (_sections.isNotEmpty ? _sections.first : 'A');
                    modalError = null;
                  }),
                ),
                AppSpacing.mdGap,
                if (_availableFaculty.isNotEmpty) ...[
                  UCombobox<String>(
                    label: 'Primary Faculty',
                    hint: 'Search faculty acronym or name…',
                    value: selectedTeacherOption,
                    items: [
                      for (final f in _availableFaculty)
                        UComboboxItem<String>(
                          value: f.acronym,
                          label: '${f.acronym} · ${f.displayName}',
                          subtitle: f.designation ?? f.dept,
                          icon: PhosphorIconsRegular.chalkboardTeacher,
                        ),
                      const UComboboxItem<String>(
                        value: customFacultySentinel,
                        label: 'Enter Custom Acronym…',
                        subtitle: 'Use an unlisted faculty code',
                        icon: PhosphorIconsRegular.pencilSimple,
                      ),
                    ],
                    allowClear: false,
                    onChanged: (v) => setModalState(() {
                      selectedTeacherOption = v ?? customFacultySentinel;
                      modalError = null;
                    }),
                  ),
                ],
                if (isCustomTeacher) ...[
                  if (_availableFaculty.isNotEmpty) AppSpacing.smGap,
                  UTextField(
                    label: 'Primary Teacher Acronym',
                    hint: 'e.g. MSA',
                    controller: teacherCtrl,
                    onChanged: (_) {
                      if (modalError != null) {
                        setModalState(() => modalError = null);
                      }
                    },
                  ),
                ],
                if (modalError != null) ...[
                  AppSpacing.smGap,
                  Text(
                    modalError!,
                    style:
                        AppTextStyles.caption.copyWith(color: AppColors.error),
                  ),
                ],
                AppSpacing.lgGap,
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      UButton(
                        label: 'Cancel',
                        variant: UButtonVariant.secondary,
                        fullWidth: false,
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                      UButton(
                        label: 'Assign Offering',
                        fullWidth: false,
                        onPressed: () {
                          final teacherAcronym = isCustomTeacher
                              ? teacherCtrl.text.trim().toUpperCase()
                              : selectedTeacherOption.trim().toUpperCase();
                          CatalogCourse? matchedCourse;
                          if (selectedCode != null) {
                            for (final c in _availableCourses) {
                              if (c.code == selectedCode) {
                                matchedCourse = c;
                                break;
                              }
                            }
                          }
                          if (matchedCourse == null) {
                            setModalState(() =>
                                modalError = 'Please choose a catalog course.');
                            return;
                          }
                          if (teacherAcronym.isEmpty) {
                            setModalState(() => modalError =
                                'Please enter or select a faculty acronym.');
                            return;
                          }
                          final targets =
                              targetSec == 'All' ? _sections : [targetSec];
                          var updatedCount = 0;
                          setState(() {
                            for (final sec in targets) {
                              final next = BatchCourseOffering(
                                courseCode: matchedCourse!.code,
                                targetSection: sec,
                                primaryTeacherAcronym: teacherAcronym,
                                credits: matchedCourse.credits,
                              );
                              final existingIdx = _offerings.indexWhere(
                                (o) =>
                                    o.courseCode == next.courseCode &&
                                    o.targetSection == next.targetSection,
                              );
                              if (existingIdx != -1) {
                                _offerings[existingIdx] =
                                    _offerings[existingIdx].copyWith(
                                  primaryTeacherAcronym: teacherAcronym,
                                  credits: matchedCourse.credits,
                                );
                                updatedCount++;
                              } else {
                                _offerings.add(next);
                              }
                            }
                            _markDirty();
                          });
                          Navigator.of(ctx).pop();
                          if (updatedCount > 0 && mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Updated existing teacher assignment for $updatedCount offering${updatedCount == 1 ? '' : 's'} ($teacherAcronym).',
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ).whenComplete(teacherCtrl.dispose);
  }

  Future<void> _saveBatch() async {
    final name = _batchNameController.text.trim();
    final sem = _semesterController.text.trim();
    if (name.isEmpty || sem.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Batch name and semester label are required.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final batch = CohortBatch(
      id: _selectedBatch?.id ?? name.toLowerCase().replaceAll(' ', '-'),
      batchName: name,
      semesterLabel: sem,
      sections: _sections,
      combinedSections: _combinedSections,
      sectionWeekends: _sectionWeekends,
      sectionWeeklyDaysOffCount: _sectionDaysOff,
      offerings: _offerings,
    );

    final success = await _controller.saveBatch(batch);
    if (!mounted) return;
    if (success) {
      setState(() {
        _selectedBatch = batch;
        _isCreatingNew = false;
        _isDirty = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Batch $name saved in Catalog Store.'),
          backgroundColor: AppColors.roleTeacher,
        ),
      );
    }
  }

  void _confirmDelete(BuildContext context) {
    final name = _batchNameController.text.trim();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: Text('Delete Batch', style: AppTextStyles.h4),
        content: Text(
          'Are you sure you want to delete batch $name and all its sections?',
          style: AppTextStyles.bodySm,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.of(ctx).pop();
              if (_selectedBatch != null) {
                await _controller.deleteBatch(_selectedBatch!.id);
                if (mounted && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Batch $name deleted.'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
