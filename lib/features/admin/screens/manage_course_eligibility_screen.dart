import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:universe/core/router/route_names.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/admin/controllers/course_eligibility_controller.dart';
import 'package:universe/features/admin/scheduling/fixtures/scheduling_preview_fixtures.dart';
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

class CourseDescriptor {
  final String code;
  final String title;
  final double credit;
  final bool isLab;

  const CourseDescriptor({
    required this.code,
    required this.title,
    required this.credit,
    required this.isLab,
  });

  String get ruleBadge {
    if (code.startsWith('PHY') && isLab) {
      return 'Physics Lab Exclusive [R11]';
    }
    if (isLab) {
      if (credit >= 2.0) {
        return '2 Cr Lab: 3 Slots/Wk · 2 Consecutive Preferred [R12]';
      }
      return '1–1.5 Cr Lab: 2 Slots/Wk [R12]';
    }
    if (credit <= 2.0) {
      return '1–2 Cr Theory: 2 Consecutive Slots / 1 Day [R13]';
    }
    return '3 Cr Theory: 2 Meetings/Wk with ≥1 Day Gap [R13]';
  }

  Color get badgeColor {
    if (code.startsWith('PHY') && isLab) return Colors.indigoAccent;
    if (isLab) return AppColors.roleTeacher;
    if (credit <= 2.0) return AppColors.warning;
    return AppColors.info;
  }
}

class ManageCourseEligibilityScreen extends StatefulWidget {
  final CourseEligibilityController? controller;

  const ManageCourseEligibilityScreen({super.key, this.controller});

  @override
  State<ManageCourseEligibilityScreen> createState() =>
      _ManageCourseEligibilityScreenState();
}

class _ManageCourseEligibilityScreenState
    extends State<ManageCourseEligibilityScreen> {
  late final CourseEligibilityController _controller;
  late final bool _ownsController;
  CourseDescriptor? _selectedCourse;
  String _searchQuery = '';
  String _activeTypeFilter = 'All';

  // In-memory course qualified teacher mapping: courseCode -> Map<acronym, priority>
  final Map<String, Map<String, int?>> _courseQualifications = {};

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? CourseEligibilityController();
    _initDefaultQualifications();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.load();
      }
    });
  }

  void _initDefaultQualifications() {
    // Populate realistic default course qualification bindings from distribution records
    for (final rec in SchedulingPreviewFixtures.records) {
      final code = rec.courseCode;
      final teacher = rec.teacher.trim();
      if (teacher.isNotEmpty && !teacher.contains('Pending') && teacher != 'TBA') {
        final acronyms = teacher.split('/').map((s) => s.trim()).toList();
        _courseQualifications.putIfAbsent(code, () => {});
        for (var i = 0; i < acronyms.length; i++) {
          final acr = acronyms[i];
          if (acr.isNotEmpty && !acr.contains('STAFF')) {
            _courseQualifications[code]![acr] = 1;
          }
        }
      }
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  List<CourseDescriptor> _getCourseCatalog() {
    final catalog = <CourseDescriptor>[];
    final seen = <String>{};

    for (final rec in SchedulingPreviewFixtures.records) {
      if (!seen.contains(rec.courseCode)) {
        seen.add(rec.courseCode);
        final isLab = rec.courseTitle.toLowerCase().contains('lab') ||
            rec.courseCode.endsWith('2') ||
            rec.courseCode.endsWith('4') ||
            rec.courseCode.endsWith('6');
        catalog.add(
          CourseDescriptor(
            code: rec.courseCode,
            title: rec.courseTitle,
            credit: rec.credit,
            isLab: isLab,
          ),
        );
      }
    }

    // Also include any catalog items from controller not yet present
    for (final c in _controller.catalog) {
      if (!seen.contains(c.code)) {
        seen.add(c.code);
        final isLab = c.title.toLowerCase().contains('lab');
        catalog.add(
          CourseDescriptor(
            code: c.code,
            title: c.title,
            credit: isLab ? 1.5 : 3.0,
            isLab: isLab,
          ),
        );
      }
    }

    var list = catalog;
    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((c) =>
              c.code.toLowerCase().contains(q) ||
              c.title.toLowerCase().contains(q))
          .toList();
    }

    if (_activeTypeFilter == 'Theory') {
      list = list.where((c) => !c.isLab).toList();
    } else if (_activeTypeFilter == 'Sessional') {
      list = list.where((c) => c.isLab).toList();
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktopShell = DesktopShellScope.isDesktopOf(context);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: isDesktopShell
          ? null
          : const UAppBar(
              title: 'Course Eligibility & Assignments',
              subtitle: 'Solver constraints & meeting rules (R12, R13)',
            ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.isLoading) return const ULoading.spinner();
          final courses = _getCourseCatalog();

          if (_selectedCourse != null &&
              !courses.any((c) => c.code == _selectedCourse!.code)) {
            _selectedCourse = courses.isNotEmpty ? courses.first : null;
          } else if (_selectedCourse == null && courses.isNotEmpty) {
            _selectedCourse = courses.first;
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final usableWidth = constraints.maxWidth;
              final isMasterDetail = usableWidth >= 900;

              return Column(
                children: [
                  _buildPolicyHeader(context),
                  _buildFilterBar(courses.length),
                  Expanded(
                    child: courses.isEmpty
                        ? const UEmptyState(
                            icon: PhosphorIconsRegular.bookOpen,
                            title: 'No courses match filter',
                            message: 'Try a different search term or filter.',
                          )
                        : isMasterDetail
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Left 55% Master List
                                  Expanded(
                                    flex: 55,
                                    child: _buildCourseList(courses,
                                        isMasterDetail: true),
                                  ),
                                  const VerticalDivider(
                                      color: AppColors.border, width: 1),
                                  // Right 45% Qualified Faculty Inspector
                                  Expanded(
                                    flex: 45,
                                    child: _selectedCourse != null
                                        ? _buildFacultyInspector(
                                            _selectedCourse!)
                                        : const Center(
                                            child: Text('Select a course'),
                                          ),
                                  ),
                                ],
                              )
                            : _buildCourseList(courses, isMasterDetail: false),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPolicyHeader(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: AppSpacing.radiusMd,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: AppSpacing.radiusSm,
            ),
            child: const Icon(
              PhosphorIconsRegular.stack,
              color: AppColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Policy Baseline: Course Meeting Distribution & Eligibility (R12, R13)',
                  style: AppTextStyles.bodySmMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Enforces 1–2 Cr Theory single-day consecutive slots (R13), Sessional 2–3 slot patterns (R12), and qualified instructor gates.',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primarySoft,
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => context.go(RouteNames.schedulingWorkspace),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Open Workspace',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                SizedBox(width: 4),
                Icon(PhosphorIconsRegular.arrowRight, size: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(int filteredCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xs,
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
                  hint: 'Course code or title (e.g. CSE-1101, Compiler)',
                  prefixIcon: PhosphorIconsRegular.magnifyingGlass,
                  onChanged: (q) => setState(() => _searchQuery = q),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.bgElevated,
                  borderRadius: AppSpacing.radiusSm,
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  'Showing $filteredCount courses',
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: ['All', 'Theory', 'Sessional'].map((type) {
              final isSelected = _activeTypeFilter == type;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: UChip(
                  label: type,
                  isActive: isSelected,
                  onTap: () => setState(() => _activeTypeFilter = type),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseList(List<CourseDescriptor> courses,
      {required bool isMasterDetail}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: UCard(
        isTopLit: true,
        padding: EdgeInsets.zero,
        child: ListView.separated(
          itemCount: courses.length,
          separatorBuilder: (context, index) =>
              const Divider(color: AppColors.border, height: 1),
          itemBuilder: (context, index) {
            final c = courses[index];
            final isSelected =
                isMasterDetail && _selectedCourse?.code == c.code;
            final qualifiedTeachers =
                _courseQualifications[c.code]?.keys.toList() ?? [];

            return InkWell(
              onTap: () {
                setState(() => _selectedCourse = c);
                if (!isMasterDetail) {
                  _openAdaptiveModal(c);
                }
              },
              child: Container(
                color: isSelected
                    ? AppColors.primarySoft.withValues(alpha: 0.35)
                    : Colors.transparent,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.badgeColor.withValues(alpha: 0.15),
                        borderRadius: AppSpacing.radiusSm,
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : c.badgeColor.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Icon(
                        c.isLab
                            ? PhosphorIconsRegular.flask
                            : PhosphorIconsRegular.bookOpen,
                        color: c.badgeColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                c.code,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.bgElevated,
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Text(
                                  '${c.credit} Credits · ${c.isLab ? 'Sessional' : 'Theory'}',
                                  style: AppTextStyles.caption.copyWith(
                                    fontSize: 9,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            c.title,
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          // Automatic R12/R13 Rule Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: c.badgeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(
                                  color: c.badgeColor.withValues(alpha: 0.45)),
                            ),
                            child: Text(
                              c.ruleBadge,
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: c.badgeColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            qualifiedTeachers.isEmpty
                                ? 'No teachers assigned yet'
                                : 'Qualified: ${qualifiedTeachers.join(', ')}',
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 10,
                              color: qualifiedTeachers.isEmpty
                                  ? AppColors.warning
                                  : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Icon(
                      isSelected
                          ? Icons.keyboard_double_arrow_right
                          : PhosphorIconsRegular.caretRight,
                      size: AppSpacing.iconSm,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textMuted,
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

  Widget _buildFacultyInspector(CourseDescriptor course) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: _CourseQualificationEditor(
        controller: _controller,
        course: course,
        currentQualifications:
            _courseQualifications[course.code] ?? {},
        onSave: (updated) {
          setState(() {
            _courseQualifications[course.code] = updated;
          });
        },
      ),
    );
  }

  void _openAdaptiveModal(CourseDescriptor course) {
    showUAdaptiveModal<void>(
      context: context,
      title: '${course.code} · Qualified Faculty',
      subtitle: course.ruleBadge,
      builder: (ctx) => SingleChildScrollView(
        child: _CourseQualificationEditor(
          controller: _controller,
          course: course,
          currentQualifications:
              _courseQualifications[course.code] ?? {},
          onSave: (updated) {
            setState(() {
              _courseQualifications[course.code] = updated;
            });
          },
        ),
      ),
    );
  }
}

class _CourseQualificationEditor extends StatefulWidget {
  final CourseEligibilityController controller;
  final CourseDescriptor course;
  final Map<String, int?> currentQualifications;
  final ValueChanged<Map<String, int?>> onSave;

  const _CourseQualificationEditor({
    required this.controller,
    required this.course,
    required this.currentQualifications,
    required this.onSave,
  });

  @override
  State<_CourseQualificationEditor> createState() =>
      _CourseQualificationEditorState();
}

class _CourseQualificationEditorState
    extends State<_CourseQualificationEditor> {
  late Map<String, int?> _draft;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _draft = Map<String, int?>.from(widget.currentQualifications);
  }

  @override
  void didUpdateWidget(covariant _CourseQualificationEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.course.code != widget.course.code) {
      _draft = Map<String, int?>.from(widget.currentQualifications);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await Future.delayed(const Duration(milliseconds: 150));
    widget.onSave(_draft);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Saved qualified teachers for ${widget.course.code} (${_draft.length} assigned)',
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final facultyList = widget.controller.faculty;

    return UCard(
      isTopLit: true,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.course.badgeColor.withValues(alpha: 0.15),
                  borderRadius: AppSpacing.radiusSm,
                ),
                child: Text(
                  widget.course.code,
                  style: AppTextStyles.h3
                      .copyWith(color: widget.course.badgeColor),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.course.title,
                      style: AppTextStyles.bodyMedium
                          .copyWith(fontWeight: FontWeight.bold),
                      maxLines: 2,
                    ),
                    Text(
                      '${widget.course.credit} Credits · ${widget.course.isLab ? 'Sessional Laboratory' : 'Theory Course'}',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.bgElevated,
              borderRadius: AppSpacing.radiusSm,
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(Icons.balance_outlined,
                    size: 14, color: widget.course.badgeColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.course.ruleBadge,
                    style: AppTextStyles.caption.copyWith(
                      color: widget.course.badgeColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Text(
                'QUALIFIED TEACHERS (${_draft.length} ASSIGNED)',
                style: AppTextStyles.labelCaps.copyWith(fontSize: 10),
              ),
              const Spacer(),
              Text(
                'Priority 1 = Highest',
                style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Check every teacher qualified to teach this course. The CP-SAT solver verifies eligibility and balances workload.',
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Faculty List with Checkboxes & Priority Dropdowns
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: facultyList.length,
            separatorBuilder: (context, index) =>
                const Divider(color: AppColors.border, height: 1),
            itemBuilder: (context, index) {
              final f = facultyList[index];
              final isAssigned = _draft.containsKey(f.acronym);
              final priority = _draft[f.acronym] ?? 1;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Checkbox(
                      value: isAssigned,
                      activeColor: AppColors.primary,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _draft[f.acronym] = 1;
                          } else {
                            _draft.remove(f.acronym);
                          }
                        });
                      },
                    ),
                    Container(
                      width: 38,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        f.acronym,
                        style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(f.displayName,
                              style: AppTextStyles.bodySmMedium),
                          Text(
                            'R6 Workload: ${f.assignedCoursesCount} Crs → ${f.r6TargetWorkingDays}',
                            style: AppTextStyles.caption
                                .copyWith(fontSize: 10, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    if (isAssigned) ...[
                      const SizedBox(width: AppSpacing.sm),
                      SizedBox(
                        width: 72,
                        child: DropdownButtonFormField<int>(
                          initialValue: priority,
                          isDense: true,
                          decoration: const InputDecoration(
                            labelText: 'Prio',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 6, vertical: 4),
                          ),
                          style: AppTextStyles.captionMedium,
                          dropdownColor: AppColors.bgElevated,
                          items: [1, 2, 3, 4, 5]
                              .map((p) => DropdownMenuItem(
                                  value: p, child: Text('$p')))
                              .toList(),
                          onChanged: (newP) {
                            setState(() => _draft[f.acronym] = newP);
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),

          UButton(
            label: 'Save Course Eligibility',
            icon: PhosphorIconsRegular.floppyDisk,
            isLoading: _saving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
