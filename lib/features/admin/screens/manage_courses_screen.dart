// PHASE A: ManageCoursesScreen — Relational Admin Core Course Catalog CRUD with Master-Detail (55/45)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:universe/core/models/admin_catalog_models.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/admin/controllers/courses_controller.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/shared/widgets/desktop_shell_scope.dart';
import 'package:universe/shared/widgets/u_adaptive_overlay.dart';
import 'package:universe/shared/widgets/u_app_bar.dart';
import 'package:universe/shared/widgets/u_button.dart';
import 'package:universe/shared/widgets/u_card.dart';
import 'package:universe/shared/widgets/u_chip.dart';
import 'package:universe/shared/widgets/u_empty_state.dart';
import 'package:universe/shared/widgets/u_loading.dart';
import 'package:universe/shared/widgets/u_segmented_control.dart';
import 'package:universe/shared/widgets/u_text_field.dart';
import 'package:universe/shared/widgets/u_combobox.dart';

class ManageCoursesScreen extends StatefulWidget {
  final CoursesController? controller;

  const ManageCoursesScreen({super.key, this.controller});

  @override
  State<ManageCoursesScreen> createState() => _ManageCoursesScreenState();
}

class _ManageCoursesScreenState extends State<ManageCoursesScreen> {
  late final CoursesController _controller;
  late final bool _ownsController;
  final FocusNode _searchFocusNode = FocusNode();

  // Selected course draft state
  CatalogCourse? _selectedCourse;
  bool _isCreatingNew = false;
  bool _isDirty = false;

  late TextEditingController _codeController;
  late TextEditingController _titleController;
  final TextEditingController _searchController = TextEditingController();
  double _credits = 3.0;
  String _courseType = 'theory'; // 'theory' | 'sessional'
  String _category = 'CSE';
  String? _companionCode;
  List<String> _prereqCodes = [];
  int? _weeklyMeetingsOverride;
  RoomClassification _roomClassification = RoomClassification.generalClassroom;
  bool _isRetake = false;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? CoursesController();
    _codeController = TextEditingController();
    _titleController = TextEditingController();
    _controller.addListener(_onControllerUpdated);
    _controller.load();
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _codeController.dispose();
    _titleController.dispose();
    _searchController.dispose();
    _controller.removeListener(_onControllerUpdated);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onControllerUpdated() {
    if (!mounted) return;
    if (_searchController.text != _controller.searchQuery) {
      _searchController.text = _controller.searchQuery;
    }
    if (_selectedCourse == null && _controller.allCourses.isNotEmpty && !_isCreatingNew) {
      _initDraftWithCourse(_controller.allCourses.first);
    }
    setState(() {});
  }

  void _initDraftWithCourse(CatalogCourse course) {
    _selectedCourse = course;
    _isCreatingNew = false;
    _isDirty = false;
    _codeController.text = course.code;
    _titleController.text = course.title;
    _credits = course.credits;
    _courseType = course.courseType;
    _category = course.category;
    _companionCode = course.companionCourseCode;
    _prereqCodes = List<String>.from(course.prerequisiteCodes);
    _weeklyMeetingsOverride = course.weeklyMeetingsOverride;
    _roomClassification = course.preferredRoomClassification;
    _isRetake = course.isRetake;
    _isActive = course.isActive;
  }

  void _initNewCourseDraft() {
    _selectedCourse = null;
    _isCreatingNew = true;
    _isDirty = true;
    _codeController.text = '';
    _titleController.text = '';
    _credits = 3.0;
    _courseType = 'theory';
    _category = 'CSE';
    _companionCode = null;
    _prereqCodes = [];
    _weeklyMeetingsOverride = null;
    _roomClassification = RoomClassification.generalClassroom;
    _isRetake = false;
    _isActive = true;
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
              title: 'Course Catalog',
              showBackButton: true,
            ),
      body: Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.slash &&
              !_searchFocusNode.hasFocus) {
            _searchFocusNode.requestFocus();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            if (_controller.isLoading) {
              return const Center(child: ULoading.spinner());
            }

            final courses = _controller.filteredCourses;

            return LayoutBuilder(
              builder: (context, constraints) {
                final usableWidth = constraints.maxWidth;
                final isMasterDetail = usableWidth >= 900;

                return Column(
                  children: [
                    _buildTopFilterStrip(usableWidth),
                    Expanded(
                      child: courses.isEmpty
                          ? UEmptyState(
                              icon: PhosphorIconsRegular.bookOpen,
                              title: 'No courses match query',
                              message: 'Try clearing your search query or category filters.',
                              action: UButton(
                                label: 'Reset Filters',
                                fullWidth: false,
                                onPressed: () {
                                  _controller.setQuery('');
                                  _controller.setCategoryFilter('All');
                                  _controller.setTypeFilter('All');
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
                                      child: _buildMasterList(courses, isMasterDetail: true),
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
                              : _buildMasterList(courses, isMasterDetail: false),
                    ),
                  ],
                );
              },
            );
          },
        ),
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
                  label: 'Search Courses',
                  hint: 'Search by code or title... (Press / to search)',
                  controller: _searchController,
                  prefixIcon: PhosphorIconsRegular.magnifyingGlass,
                  onChanged: (q) => _controller.setQuery(q),
                ),
              ),
              AppSpacing.smGap,
              UButton(
                label: isCompact ? 'Add' : 'New Course',
                icon: PhosphorIconsRegular.plus,
                fullWidth: false,
                onPressed: () {
                  setState(() {
                    _initNewCourseDraft();
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
              // Live match count pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: AppSpacing.radiusSm,
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  'Showing ${_controller.filteredCount} of ${_controller.totalCount} courses',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Category Filter Chips
              ...['All', 'CSE', 'GED', 'ENG', 'PHY', 'CHE', 'EEE', 'MAT'].map((cat) {
                final isSel = _controller.categoryFilter == cat;
                return UChip(
                  label: cat,
                  isActive: isSel,
                  onTap: () => _controller.setCategoryFilter(cat),
                );
              }),
              // Type filter chips
              ...['All', 'Theory', 'Sessional'].map((t) {
                final isSel = _controller.typeFilter == t;
                return UChip(
                  label: t,
                  isActive: isSel,
                  onTap: () => _controller.setTypeFilter(t),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMasterList(List<CatalogCourse> courses, {required bool isMasterDetail}) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: UCard(
        isTopLit: true,
        padding: EdgeInsets.zero,
        child: ListView.separated(
          itemCount: courses.length,
          separatorBuilder: (_, __) => const Divider(
            color: AppColors.border,
            height: 1,
            thickness: 1,
          ),
          itemBuilder: (context, index) {
            final course = courses[index];
            final isSelected = isMasterDetail && _selectedCourse?.code == course.code && !_isCreatingNew;
            final isTheory = course.courseType == 'theory';

            return InkWell(
              onTap: () {
                setState(() {
                  _initDraftWithCourse(course);
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
                        color: isSelected ? (isTheory ? AppColors.primary : AppColors.roleTeacher) : Colors.transparent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Course Code & Category
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceElevated,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Text(
                                  course.code,
                                  style: AppTextStyles.labelCaps.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.bgSubtle,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  course.category,
                                  style: AppTextStyles.caption.copyWith(
                                    fontSize: 10,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),
                              if (course.isRetake)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: AppColors.warning),
                                  ),
                                  child: Text(
                                    'RETAKE',
                                    style: AppTextStyles.caption.copyWith(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.warning,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            course.title,
                            style: AppTextStyles.bodySm.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // Badges, Companion and Tabular Credits
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (course.companionCourseCode != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.info.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppColors.info.withValues(alpha: 0.4)),
                                ),
                                child: Text(
                                  '↔ ${course.companionCourseCode}',
                                  style: AppTextStyles.caption.copyWith(
                                    fontSize: 10,
                                    color: AppColors.info,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            // Right-aligned Tabular Credits
                            Text(
                              '${course.credits.toStringAsFixed(1)} Cr',
                              style: AppTextStyles.numeric.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Rule badge: R13 in cyan, R12 in emerald, default in slate-gray
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: course.ruleBadgeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: course.isR13SingleDayBlock || course.isSessional
                                  ? course.ruleBadgeColor
                                  : AppColors.border,
                            ),
                          ),
                          child: Text(
                            course.r12OrR13BadgeLabel,
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: course.isR13SingleDayBlock || course.isSessional
                                  ? course.ruleBadgeColor
                                  : AppColors.textMuted,
                            ),
                          ),
                        ),
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
      title: _isCreatingNew ? 'Create New Course' : 'Course Inspector · ${_codeController.text}',
      builder: (ctx) => _buildInspectorCard(isSheet: true),
    );
  }

  Widget _buildInspectorCard({required bool isSheet}) {
    return Container(
      padding: EdgeInsets.all(isSheet ? AppSpacing.md : AppSpacing.lg),
      child: UCard(
        isTopLit: true,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & Truthful Persistence Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isCreatingNew
                            ? 'New Course Registration'
                            : 'Course Inspector (${_codeController.text})',
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
                          Text(
                            'Saved in Catalog Store · Staged for Phase D',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (_isDirty)
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
              ),
              const Divider(color: AppColors.border, height: 24),

              // Section 1: Course Identity
              Text('COURSE IDENTITY', style: AppTextStyles.labelCaps),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: UTextField(
                      controller: _codeController,
                      label: 'Course Code',
                      hint: 'e.g. CSE-3101',
                      onChanged: (_) => _markDirty(),
                    ),
                  ),
                  AppSpacing.smGap,
                  Expanded(
                    flex: 6,
                    child: UTextField(
                      controller: _titleController,
                      label: 'Course Title',
                      hint: 'e.g. Database Systems',
                      onChanged: (_) => _markDirty(),
                    ),
                  ),
                ],
              ),
              AppSpacing.smGap,
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Course Type', style: AppTextStyles.label),
                        const SizedBox(height: 4),
                        USegmentedControl<String>(
                          selected: _courseType,
                          segments: const [
                            USegment(value: 'theory', label: 'Theory'),
                            USegment(value: 'sessional', label: 'Sessional/Lab'),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _courseType = val;
                              _markDirty();
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.mdGap,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Credits', style: AppTextStyles.label),
                        const SizedBox(height: 4),
                        USegmentedControl<double>(
                          selected: _credits,
                          segments: const [
                            USegment(value: 1.0, label: '1.0'),
                            USegment(value: 1.5, label: '1.5'),
                            USegment(value: 2.0, label: '2.0'),
                            USegment(value: 3.0, label: '3.0'),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _credits = val;
                              _markDirty();
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              AppSpacing.smGap,
              Text('Category', style: AppTextStyles.label),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['CSE', 'GED', 'ENG', 'PHY', 'CHE', 'EEE', 'MAT'].map((cat) {
                  final isSel = _category == cat;
                  return UChip(
                    label: cat,
                    isActive: isSel,
                    onTap: () {
                      setState(() {
                        _category = cat;
                        _markDirty();
                      });
                    },
                  );
                }).toList(),
              ),
              const Divider(color: AppColors.border, height: 28),

              // Section 2: Relational Links
              Text('RELATIONAL LINKS', style: AppTextStyles.labelCaps),
              const SizedBox(height: 8),
              // Companion Course (Searchable Combobox)
              Text('Companion Course (Theory ↔ Lab Link)', style: AppTextStyles.label),
              const SizedBox(height: 4),
              _buildCompanionCourseCombobox(),
              AppSpacing.smGap,
              // Prerequisites (Searchable Selector)
              Text('Prerequisites', style: AppTextStyles.label),
              const SizedBox(height: 4),
              _buildPrerequisitesPicker(),
              AppSpacing.smGap,
              // Preferred Room Classification
              Text('Preferred Room Classification', style: AppTextStyles.label),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: RoomClassification.values.map((cls) {
                  final isSel = _roomClassification == cls;
                  return UChip(
                    label: cls.displayName,
                    isActive: isSel,
                    onTap: () {
                      setState(() {
                        _roomClassification = cls;
                        _markDirty();
                      });
                    },
                  );
                }).toList(),
              ),
              const Divider(color: AppColors.border, height: 28),

              // Section 3: Scheduling & Rule Behavior ("Show, Don't Tell")
              Text('SCHEDULING & RULE BEHAVIOR', style: AppTextStyles.labelCaps),
              const SizedBox(height: 8),
              // Slot Block Mini-Diagram
              _buildSlotBlockMiniDiagram(),
              AppSpacing.smGap,
              // Retake Switch
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Retake / Special Section Offering', style: AppTextStyles.h4),
                        Text(
                          'Flags course as irregular for off-cycle batch students',
                          style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Switch(
                    value: _isRetake,
                    activeThumbColor: AppColors.warning,
                    onChanged: (v) {
                      setState(() {
                        _isRetake = v;
                        _markDirty();
                      });
                    },
                  ),
                ],
              ),
              const Divider(color: AppColors.border, height: 28),

              // Action Footer: Visible only when isDirty or creating new (Unslop #2)
              if (_isDirty || _isCreatingNew) ...[
                const Divider(color: AppColors.border, height: 28),
                Row(
                  children: [
                    if (!_isCreatingNew && _selectedCourse != null)
                      IconButton(
                        icon: const Icon(PhosphorIconsRegular.trash, color: AppColors.error),
                        tooltip: 'Delete Course',
                        onPressed: () => _confirmDelete(context),
                      ),
                    const Spacer(),
                    UButton(
                      label: 'Discard',
                      variant: UButtonVariant.secondary,
                      fullWidth: false,
                      onPressed: () {
                        setState(() {
                          if (_selectedCourse != null) {
                            _initDraftWithCourse(_selectedCourse!);
                          } else {
                            _initNewCourseDraft();
                          }
                        });
                      },
                    ),
                    AppSpacing.smGap,
                    UButton(
                      label: 'Save Course',
                      fullWidth: false,
                      onPressed: _saveCourse,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompanionCourseCombobox() {
    final otherCourses = _controller.allCourses.where((c) => c.code != _codeController.text.trim()).toList();
    final items = [
      for (final c in otherCourses)
        UComboboxItem<String>(
          value: c.code,
          label: '${c.code} · ${c.title}',
          subtitle: '${c.courseType.toUpperCase()} · ${c.credits} Cr · ${c.category}',
          icon: PhosphorIconsRegular.repeat,
          color: AppColors.info,
        ),
    ];

    return UCombobox<String>(
      hint: 'Select companion course (e.g. Theory ↔ Lab)…',
      value: _companionCode,
      items: items,
      allowClear: true,
      prefixIcon: PhosphorIconsRegular.repeat,
      onChanged: (code) {
        setState(() {
          _companionCode = code;
          _markDirty();
        });
      },
    );
  }

  Widget _buildPrerequisitesPicker() {
    final otherCourses = _controller.allCourses.where((c) => c.code != _codeController.text.trim()).toList();
    final availableCourses = otherCourses.where((c) => !_prereqCodes.contains(c.code)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_prereqCodes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: _prereqCodes.map((code) {
                return Chip(
                  backgroundColor: AppColors.surfaceElevated,
                  deleteIconColor: AppColors.textMuted,
                  label: Text(code, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
                  onDeleted: () {
                    setState(() {
                      _prereqCodes.remove(code);
                      _markDirty();
                    });
                  },
                );
              }).toList(),
            ),
          ),
        UCombobox<String>(
          hint: '+ Add Prerequisite Course…',
          value: null,
          items: [
            for (final c in availableCourses)
              UComboboxItem<String>(
                value: c.code,
                label: '${c.code} · ${c.title}',
                subtitle: '${c.courseType.toUpperCase()} · ${c.credits} Cr',
                icon: PhosphorIconsRegular.graduationCap,
                color: AppColors.primary,
              ),
          ],
          allowClear: false,
          prefixIcon: PhosphorIconsRegular.plus,
          onChanged: (code) {
            if (code != null && !_prereqCodes.contains(code)) {
              setState(() {
                _prereqCodes.add(code);
                _markDirty();
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildSlotBlockMiniDiagram() {
    final isSessional = _courseType == 'sessional';
    final isR13 = _courseType == 'theory' && _category == 'CSE' && _credits <= 2.0;

    String description;
    Color borderHighlight;
    Widget diagramRow;

    if (isSessional) {
      borderHighlight = AppColors.roleTeacher;
      description = _credits <= 1.5
          ? 'Rule R12: 1–1.5 Cr Sessional meets 2 class slots per week in the designated lab.'
          : 'Rule R12: 2 Cr Sessional meets 3 class slots per week (preferred 2 consecutive slots in the same lab).';
      diagramRow = Row(
        children: [
          _diagramSlot('Slot 1\n(Lab)', AppColors.roleTeacher),
          const SizedBox(width: 4),
          _diagramSlot('Slot 2\n(Lab)', AppColors.roleTeacher),
          if (_credits > 1.5) ...[
            const SizedBox(width: 4),
            _diagramSlot('Slot 3\n(Optional)', AppColors.surfaceElevated),
          ],
        ],
      );
    } else if (isR13) {
      borderHighlight = AppColors.info;
      description =
          'Rule R13: 1–2 Cr CSE Theory must be completed in 1 single day across 2 consecutive slots in the same classroom.';
      diagramRow = Row(
        children: [
          _diagramSlot('Slot 1\n(Theory)', AppColors.info),
          const SizedBox(width: 4),
          _diagramSlot('Slot 2\n(Theory)', AppColors.info),
          const SizedBox(width: 8),
          Text(
            'Same Day · Same Room',
            style: AppTextStyles.caption.copyWith(color: AppColors.info),
          ),
        ],
      );
    } else {
      borderHighlight = AppColors.border;
      description =
          'Standard Theory: 3 Cr Theory scheduled across distinct days with >=1 day separation.';
      diagramRow = Row(
        children: [
          _diagramSlot('Day A\n(Slot)', AppColors.primary),
          const SizedBox(width: 6),
          const Icon(PhosphorIconsRegular.arrowRight, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 6),
          _diagramSlot('Day B\n(Slot)', AppColors.primary),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.bgSubtle,
        borderRadius: AppSpacing.radiusSm,
        border: Border.all(color: borderHighlight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          diagramRow,
          const SizedBox(height: 6),
          Text(
            description,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _diagramSlot(String label, Color color) {
    return Container(
      width: 64,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: AppTextStyles.caption.copyWith(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Future<void> _saveCourse() async {
    final code = _codeController.text.trim();
    final title = _titleController.text.trim();
    if (code.isEmpty || title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Course code and title are required.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final course = CatalogCourse(
      id: _selectedCourse?.id ?? code.toLowerCase(),
      code: code,
      title: title,
      credits: _credits,
      courseType: _courseType,
      category: _category,
      companionCourseCode: _companionCode,
      prerequisiteCodes: _prereqCodes,
      weeklyMeetingsOverride: _weeklyMeetingsOverride,
      preferredRoomClassification: _roomClassification,
      isRetake: _isRetake,
      isActive: _isActive,
    );

    final success = await _controller.saveCourse(course);
    if (!mounted) return;
    if (success) {
      setState(() {
        _selectedCourse = course;
        _isCreatingNew = false;
        _isDirty = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Course $code saved in Catalog Store.'),
          backgroundColor: AppColors.roleTeacher,
        ),
      );
    }
  }

  void _confirmDelete(BuildContext context) {
    final code = _codeController.text.trim();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: Text('Delete Course', style: AppTextStyles.h4),
        content: Text(
          'Are you sure you want to delete course $code? This will remove its relations.',
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
              if (_selectedCourse != null) {
                await _controller.deleteCourse(_selectedCourse!.id);
                if (mounted && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Course $code deleted.'),
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
