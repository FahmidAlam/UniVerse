// PHASE A: ManageFacultyScreen — Full Faculty Profile CRUD & R4-R9/R15 Rules (55/45 Master-Detail)
import 'package:flutter/material.dart';
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/models/timetable_config_model.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/admin/controllers/timetable_faculty_controller.dart';
import 'package:universe/features/admin/widgets/r15_slot_selector.dart';
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

enum FacultyFilter {
  all,
  permanent,
  adjunct,
  sustAdjunct,
  externalGuest,
  hasExternalBlock,
}

class ManageFacultyScreen extends StatefulWidget {
  final TimetableFacultyController? controller;

  const ManageFacultyScreen({super.key, this.controller});

  @override
  State<ManageFacultyScreen> createState() => _ManageFacultyScreenState();
}

class _ManageFacultyScreenState extends State<ManageFacultyScreen> {
  late final TimetableFacultyController _controller;
  late final bool _ownsController;
  FacultyFilter _activeFilter = FacultyFilter.all;
  TimetableFaculty? _selectedFaculty;
  bool _isCreatingNew = false;

  // In-memory matrix overrides per teacher acronym for Day x Slot interactive matrix (R4, R5, R8)
  final Map<String, Map<String, int>> _slotMatrixState = {};
  // In-memory SUST compactness break preference per teacher acronym (R9)
  final Map<String, String> _sustBreakPreference = {};

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? TimetableFacultyController();
    _controller.load();
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  List<TimetableFaculty> _applyFilter(List<TimetableFaculty> list) {
    switch (_activeFilter) {
      case FacultyFilter.all:
        return list;
      case FacultyFilter.permanent:
        return list.where((f) => f.isPermanent).toList();
      case FacultyFilter.adjunct:
        return list.where((f) => f.isAdjunct).toList();
      case FacultyFilter.sustAdjunct:
        return list.where((f) => f.isSustAdjunct).toList();
      case FacultyFilter.externalGuest:
        return list.where((f) => f.isExternalGuest).toList();
      case FacultyFilter.hasExternalBlock:
        return list.where((f) => f.hasExternalBlock).toList();
    }
  }

  String _filterLabel(FacultyFilter filter) {
    switch (filter) {
      case FacultyFilter.all:
        return 'All';
      case FacultyFilter.permanent:
        return 'Permanent';
      case FacultyFilter.adjunct:
        return 'Adjunct';
      case FacultyFilter.sustAdjunct:
        return 'SUST Adjunct';
      case FacultyFilter.externalGuest:
        return 'External/Guest [R5]';
      case FacultyFilter.hasExternalBlock:
        return 'Has External Block [R4]';
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
              title: 'Faculty',
              subtitle: 'Profiles, designations, off-days & R4–R9 availability',
              showBackButton: true,
            ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.isLoading) {
            return const Center(child: ULoading.spinner());
          }
          final filteredList = _applyFilter(_controller.filtered);

          if (_selectedFaculty != null &&
              !filteredList.any((f) => f.id == _selectedFaculty!.id) &&
              !_isCreatingNew) {
            _selectedFaculty = filteredList.isNotEmpty ? filteredList.first : null;
          } else if (_selectedFaculty == null && filteredList.isNotEmpty && !_isCreatingNew) {
            _selectedFaculty = filteredList.first;
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final usableWidth = constraints.maxWidth;
              final isMasterDetail = usableWidth >= 900;

              return Column(
                children: [
                  _buildPolicyHeader(context),
                  _buildFilterBar(filteredList.length, _controller.total, usableWidth),
                  Expanded(
                    child: filteredList.isEmpty && !_isCreatingNew
                        ? const UEmptyState(
                            icon: PhosphorIconsRegular.usersThree,
                            title: 'No teachers found',
                            message: 'Try adjusting your search or filter tags.',
                          )
                        : isMasterDetail
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Left 55% Master List
                                  Expanded(
                                    flex: 55,
                                    child: _buildMasterList(filteredList, isMasterDetail: true),
                                  ),
                                  const VerticalDivider(color: AppColors.border, width: 1),
                                  // Right 45% Docked Detail Inspector
                                  Expanded(
                                    flex: 45,
                                    child: _buildInspectorPane(_selectedFaculty, isSheet: false),
                                  ),
                                ],
                              )
                            : _buildMasterList(filteredList, isMasterDetail: false),
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
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgSubtle,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: AppSpacing.radiusSm,
            ),
            child: Text(
              'RULES R4–R9 & R15',
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                fontSize: 10,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Permanent off-day balance (R7: 2–3d) · Adjunct workload bounds (R6) · SUST single-half compactness (R9) · Slot windows (R4, R5, R8)',
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(int filteredCount, int totalCount, double usableWidth) {
    final isCompact = usableWidth < 768;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
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
                  label: 'Search Faculty',
                  hint: 'Search faculty by name or acronym...',
                  prefixIcon: PhosphorIconsRegular.magnifyingGlass,
                  onChanged: (val) => _controller.setQuery(val),
                ),
              ),
              AppSpacing.smGap,
              UButton(
                label: isCompact ? 'Add' : 'Add Faculty',
                icon: PhosphorIconsRegular.plus,
                fullWidth: false,
                onPressed: () {
                  setState(() {
                    _isCreatingNew = true;
                    _selectedFaculty = const TimetableFaculty(
                      id: '',
                      acronym: '',
                      fullName: '',
                      dept: 'CSE',
                      designation: 'Lecturer',
                      employmentType: 'permanent',
                      offDays: ['Fri', 'Sat'],
                    );
                  });
                  if (usableWidth < 900) {
                    _openAdaptiveSheet(_selectedFaculty!);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: AppSpacing.radiusSm,
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  'Showing $filteredCount of $totalCount faculty',
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              ...FacultyFilter.values.map((f) {
                final isSelected = _activeFilter == f;
                return UChip(
                  label: _filterLabel(f),
                  isActive: isSelected,
                  onTap: () => setState(() => _activeFilter = f),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMasterList(List<TimetableFaculty> list, {required bool isMasterDetail}) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: UCard(
        isTopLit: true,
        padding: EdgeInsets.zero,
        child: ListView.separated(
          itemCount: list.length,
          separatorBuilder: (context, index) =>
              const Divider(color: AppColors.border, height: 1),
          itemBuilder: (context, index) {
            final f = list[index];
            final isSelected = isMasterDetail && _selectedFaculty?.id == f.id && !_isCreatingNew;

            return InkWell(
              onTap: () {
                setState(() {
                  _isCreatingNew = false;
                  _selectedFaculty = f;
                });
                if (!isMasterDetail) {
                  _openAdaptiveSheet(f);
                }
              },
              child: Container(
                color: isSelected ? AppColors.surfaceInteractive : Colors.transparent,
                padding: const EdgeInsets.all(AppSpacing.md),
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
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: AppSpacing.radiusSm,
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.border,
                        ),
                      ),
                      child: Text(
                        f.acronym,
                        style: AppTextStyles.chip.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  f.displayName,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              _buildCategoryBadge(f),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                '${f.designation ?? 'Faculty'} · ${f.dept ?? 'CSE'}',
                                style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                              ),
                              Container(
                                width: 3,
                                height: 3,
                                decoration: const BoxDecoration(
                                  color: AppColors.textMuted,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.bgElevated,
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Text(
                                  'R6: ${f.assignedCoursesCount} Crs → ${f.r6TargetWorkingDays}',
                                  style: AppTextStyles.caption.copyWith(
                                    fontSize: 9,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              _buildOffDaysBadge(f),
                            ],
                          ),
                        ],
                      ),
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

  Widget _buildCategoryBadge(TimetableFaculty f) {
    Color bg;
    Color fg;
    String label;

    if (f.isSustAdjunct) {
      bg = AppColors.warningSoft;
      fg = AppColors.warning;
      label = 'SUST ADJUNCT';
    } else if (f.isAdjunct) {
      bg = AppColors.infoSoft;
      fg = AppColors.info;
      label = 'ADJUNCT';
    } else if (f.isExternalGuest) {
      bg = Colors.purple.withValues(alpha: 0.15);
      fg = Colors.purpleAccent;
      label = 'EXTERNAL DEPT [R5]';
    } else {
      bg = AppColors.primarySoft;
      fg = AppColors.primary;
      label = 'PERMANENT';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppSpacing.radiusSm,
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildOffDaysBadge(TimetableFaculty f) {
    final isViolation = f.isR7Violation;
    final color = isViolation
        ? AppColors.error
        : (f.isPermanent ? AppColors.roleTeacher : AppColors.info);
    final workingDays = (7 - f.offDays.length).clamp(0, 7);

    final String text;
    if (f.isPermanent) {
      if (isViolation) {
        text = 'R7 Violation (${f.offDays.length}d Off · Needs 2–3d)';
      } else {
        text = 'Perm: $workingDays Work + ${f.offDays.length} Off = 7d (R6/R7)';
      }
    } else {
      text = 'Adjunct: ${f.offDays.length}d Off (${workingDays}d Work)';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: AppTextStyles.caption.copyWith(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildInspectorPane(TimetableFaculty? f, {required bool isSheet}) {
    if (f == null) {
      return const Center(child: Text('Select a faculty member'));
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(isSheet ? AppSpacing.md : AppSpacing.lg),
      child: _FacultyDetailInspector(
        controller: _controller,
        faculty: f,
        isCreatingNew: _isCreatingNew,
        slotMatrix: _slotMatrixState[f.acronym] ?? {},
        onMatrixChange: (newMatrix) {
          setState(() {
            _slotMatrixState[f.acronym] = newMatrix;
          });
        },
        sustBreakSide: _sustBreakPreference[f.acronym] ?? f.sustCompactnessMode ?? 'Before Break',
        onSustBreakChange: (newSide) {
          setState(() {
            _sustBreakPreference[f.acronym] = newSide;
          });
        },
        onSaved: (savedFac) {
          setState(() {
            _selectedFaculty = savedFac;
            _isCreatingNew = false;
          });
        },
      ),
    );
  }

  void _openAdaptiveSheet(TimetableFaculty f) {
    showUAdaptiveModal<void>(
      context: context,
      title: _isCreatingNew ? 'Create New Faculty' : '${f.acronym} · ${f.displayName}',
      subtitle: 'Faculty Profile, Designations & Rules R4–R9/R15',
      builder: (ctx) => _buildInspectorPane(f, isSheet: true),
    );
  }
}

class _FacultyDetailInspector extends StatefulWidget {
  final TimetableFacultyController controller;
  final TimetableFaculty faculty;
  final bool isCreatingNew;
  final Map<String, int> slotMatrix;
  final ValueChanged<Map<String, int>> onMatrixChange;
  final String sustBreakSide;
  final ValueChanged<String> onSustBreakChange;
  final ValueChanged<TimetableFaculty> onSaved;

  const _FacultyDetailInspector({
    required this.controller,
    required this.faculty,
    this.isCreatingNew = false,
    required this.slotMatrix,
    required this.onMatrixChange,
    required this.sustBreakSide,
    required this.onSustBreakChange,
    required this.onSaved,
  });

  @override
  State<_FacultyDetailInspector> createState() => _FacultyDetailInspectorState();
}

class _FacultyDetailInspectorState extends State<_FacultyDetailInspector> {
  int _slotCount = 6;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _acronymController = TextEditingController();
  final ScrollController _matrixScrollCtrl = ScrollController();
  String _designation = 'Lecturer';
  String _dept = 'CSE';
  String _employmentType = 'permanent';
  bool _isExternalGuest = false;
  bool _hasExternalBlock = false;
  bool _isSustAdjunct = false;
  late Set<String> _offDays;
  late Map<String, int> _matrix;
  late String _sustSide;
  bool _saving = false;
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    _initDraft();
  }

  @override
  void didUpdateWidget(covariant _FacultyDetailInspector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.faculty.id != widget.faculty.id || oldWidget.isCreatingNew != widget.isCreatingNew) {
      _initDraft();
    }
  }

  void _initDraft() {
    _nameController.text = widget.faculty.fullName ?? '';
    _acronymController.text = widget.faculty.acronym;
    _designation = widget.faculty.designation ?? 'Lecturer';
    _dept = widget.faculty.dept ?? 'CSE';
    _employmentType = widget.faculty.isAdjunct ? 'adjunct' : 'permanent';
    _isExternalGuest = widget.faculty.isExternalGuest;
    _hasExternalBlock = widget.faculty.hasExternalBlock;
    _isSustAdjunct = widget.faculty.isSustAdjunct;
    _offDays = {...widget.faculty.offDays};
    _matrix = Map<String, int>.from(widget.slotMatrix);
    _sustSide = widget.sustBreakSide;
    _isDirty = widget.isCreatingNew;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _acronymController.dispose();
    _matrixScrollCtrl.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_isDirty) setState(() => _isDirty = true);
  }

  Future<void> _save() async {
    final acronym = _acronymController.text.trim().toUpperCase();
    final name = _nameController.text.trim();
    if (acronym.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Acronym and Full Name are required.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    // Convert slotMatrix integer states to string states
    final serializedMatrix = <String, String>{};
    for (final entry in _matrix.entries) {
      switch (entry.value) {
        case 1:
          serializedMatrix[entry.key] = 'preferred_r8';
          break;
        case 2:
          serializedMatrix[entry.key] = 'external_block_r4';
          break;
        case 3:
          serializedMatrix[entry.key] = 'guest_window_r5';
          break;
      }
    }

    final updated = TimetableFaculty(
      id: widget.faculty.id.isNotEmpty ? widget.faculty.id : 'fac-${acronym.toLowerCase()}',
      acronym: acronym,
      fullName: name,
      dept: _dept,
      designation: _designation,
      offDays: AppConstants.weekDays.where(_offDays.contains).toList(),
      employmentType: _employmentType,
      isExternalGuestExplicit: _isExternalGuest,
      hasExternalBlockExplicit: _hasExternalBlock,
      isSustAdjunctExplicit: _isSustAdjunct,
      sustCompactnessMode: _sustSide.toLowerCase().replaceAll(' ', '_'),
      slotMatrix: serializedMatrix,
      isActive: true,
    );

    final ok = await widget.controller.saveFaculty(updated);
    widget.onMatrixChange(_matrix);
    widget.onSustBreakChange(_sustSide);

    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) _isDirty = false;
    });

    if (ok) {
      widget.onSaved(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Faculty profile saved for $acronym.'),
          backgroundColor: AppColors.roleTeacher,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = AppConstants.weekDays;
    final slotCount = _slotCount;
    final acronym = _acronymController.text.trim();

    return UCard(
      isTopLit: true,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header & Truthful Storage Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.isCreatingNew ? 'Add New Faculty Member' : 'Faculty Profile ($acronym)',
                    style: AppTextStyles.h4,
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

          // Core Identity
          Text('CORE IDENTITY', style: AppTextStyles.labelCaps),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 4,
                child: UTextField(
                  label: 'Teacher Acronym',
                  hint: 'e.g. MSR',
                  controller: _acronymController,
                  onChanged: (_) => _markDirty(),
                ),
              ),
              AppSpacing.smGap,
              Expanded(
                flex: 6,
                child: UTextField(
                  label: 'Full Name',
                  hint: 'e.g. Prof. Dr. M. S. Rahman',
                  controller: _nameController,
                  prefixIcon: PhosphorIconsRegular.user,
                  onChanged: (_) => _markDirty(),
                ),
              ),
            ],
          ),
          AppSpacing.smGap,
          Text('Designation', style: AppTextStyles.label),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              'Professor',
              'Associate Professor',
              'Assistant Professor',
              'Senior Lecturer',
              'Lecturer',
            ].map((desig) {
              final isSel = _designation == desig;
              return UChip(
                label: desig,
                isActive: isSel,
                onTap: () {
                  setState(() {
                    _designation = desig;
                    _markDirty();
                  });
                },
              );
            }).toList(),
          ),
          AppSpacing.smGap,
          Text('Home Department', style: AppTextStyles.label),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['CSE', 'EEE', 'PHY', 'ENG', 'GED', 'MAT', 'CHE'].map((d) {
              final isSel = _dept == d;
              return UChip(
                label: d,
                isActive: isSel,
                onTap: () {
                  setState(() {
                    _dept = d;
                    _markDirty();
                  });
                },
              );
            }).toList(),
          ),
          const Divider(color: AppColors.border, height: 28),

          // Category & Cross-Dept Flags (R4–R9)
          Text('CATEGORY & CROSS-DEPT FLAGS (R4–R9)', style: AppTextStyles.labelCaps),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Employment Category', style: AppTextStyles.label),
                    const SizedBox(height: 4),
                    USegmentedControl<String>(
                      selected: _employmentType,
                      segments: const [
                        USegment(value: 'permanent', label: 'Permanent Faculty'),
                        USegment(value: 'adjunct', label: 'Adjunct / Visiting'),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _employmentType = val;
                          _markDirty();
                        });
                      },
                    ),
                  ],
                ),
              ),
              AppSpacing.mdGap,
              // R6 Target Working-Day Band
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.bgSubtle,
                    borderRadius: AppSpacing.radiusSm,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('R6 Target Working Days', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(
                        _employmentType == 'adjunct'
                            ? '2 Courses → 2d · 3 Courses → 3–4d'
                            : 'Standard Permanent: 4–5 working days/wk',
                        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.smGap,
          // R7 Off-Days Bounds Checklist (7-Day Institutional Week Math)
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text('WEEKLY OFF-DAYS (R7 BOUNDS: 2–3 DAYS)', style: AppTextStyles.labelCaps),
              Text(
                _employmentType == 'permanent'
                    ? '${_offDays.length}d Off (${7 - _offDays.length}d Work) · ${_offDays.length >= 2 && _offDays.length <= 3 ? "Valid" : "Violation"}'
                    : '${_offDays.length}d Off (${7 - _offDays.length}d Work)',
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _employmentType == 'permanent' && (_offDays.length < 2 || _offDays.length > 3)
                      ? AppColors.error
                      : AppColors.roleTeacher,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: AppConstants.weekDays.map((day) {
              final isOff = _offDays.contains(day);
              final short = AppConstants.weekDaysShort[AppConstants.weekDays.indexOf(day)];
              return UChip(
                label: short,
                isActive: isOff,
                onTap: () {
                  setState(() {
                    if (isOff) {
                      _offDays.remove(day);
                    } else {
                      _offDays.add(day);
                    }
                    _markDirty();
                  });
                },
              );
            }).toList(),
          ),
          AppSpacing.smGap,
          // Flags: External Guest [R5], Has External Block [R4], SUST Adjunct [R9]
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('External/Guest Faculty [R5]'),
                selected: _isExternalGuest,
                selectedColor: AppColors.warning.withValues(alpha: 0.2),
                checkmarkColor: AppColors.warning,
                onSelected: (v) => setState(() {
                  _isExternalGuest = v;
                  _markDirty();
                }),
              ),
              FilterChip(
                label: const Text('Has External Dept Block [R4]'),
                selected: _hasExternalBlock,
                selectedColor: AppColors.error.withValues(alpha: 0.2),
                checkmarkColor: AppColors.error,
                onSelected: (v) => setState(() {
                  _hasExternalBlock = v;
                  _markDirty();
                }),
              ),
              FilterChip(
                label: const Text('SUST Traveling Adjunct [R9]'),
                selected: _isSustAdjunct,
                selectedColor: AppColors.info.withValues(alpha: 0.2),
                checkmarkColor: AppColors.info,
                onSelected: (v) => setState(() {
                  _isSustAdjunct = v;
                  _markDirty();
                }),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('R9 SUST ADJUNCT COMPACTNESS', style: AppTextStyles.labelCaps),
          const SizedBox(height: 4),
          Text(
            'Classes grouped on single side of break with max gap <= 2 slots',
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          USegmentedControl<String>(
            selected: _sustSide,
            segments: const [
              USegment(value: 'Before Break', label: 'Before Break'),
              USegment(value: 'After Break', label: 'After Break'),
              USegment(value: 'Either', label: 'Either (Max Gap <= 2)'),
            ],
            onChanged: (val) => setState(() {
              _sustSide = val;
              _markDirty();
            }),
          ),
          const Divider(color: AppColors.border, height: 28),

          // R15-Synced Interactive 7-Day × N-Slot Matrix (R4, R5, R8)
          Text('DAY × SLOT AVAILABILITY MATRIX (R4, R5, R8)', style: AppTextStyles.labelCaps),
          const SizedBox(height: 6),
          R15SlotSelector(onChanged: (count) {
            if (mounted) setState(() => _slotCount = count);
          }),
          const SizedBox(height: 4),
          Text(
            'Tap cell to cycle: Available (Gray) → Preferred [R8] (Cyan) → Ext Block [R4] (Crimson) → Guest Window [R5] (Amber).',
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Scrollbar(
            controller: _matrixScrollCtrl,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _matrixScrollCtrl,
              scrollDirection: Axis.horizontal,
              child: Table(
              defaultColumnWidth: const FixedColumnWidth(52),
              border: TableBorder.all(color: AppColors.border),
              children: [
                TableRow(
                  decoration: const BoxDecoration(color: AppColors.bgElevated),
                  children: [
                    Container(
                      height: 28,
                      alignment: Alignment.center,
                      child: Text('Slot', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
                    ),
                    for (final d in days)
                      Container(
                        height: 28,
                        alignment: Alignment.center,
                        child: Text(d.substring(0, 3), style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                for (var slot = 1; slot <= slotCount; slot++)
                  TableRow(
                    children: [
                      Container(
                        height: 32,
                        alignment: Alignment.center,
                        child: Text(
                          'P$slot',
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      for (final d in days) _buildSlotMatrixCell(d, slot),
                    ],
                  ),
              ],
            ),
          ),
        ),
          // Action Bar: Visible only when isDirty or creating new (Unslop #2)
          if (_isDirty || widget.isCreatingNew) ...[
            const Divider(color: AppColors.border, height: 28),
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                if (!widget.isCreatingNew && widget.faculty.id.isNotEmpty)
                  IconButton(
                    icon: const Icon(PhosphorIconsRegular.trash, color: AppColors.error),
                    tooltip: 'Delete Faculty',
                    onPressed: () => _confirmDelete(context),
                  ),
                UButton(
                  label: 'Discard',
                  variant: UButtonVariant.secondary,
                  fullWidth: false,
                  onPressed: () => setState(() => _initDraft()),
                ),
                UButton(
                  label: 'Save Faculty Profile',
                  isLoading: _saving,
                  fullWidth: false,
                  onPressed: _save,
                ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
  }

  Widget _buildSlotMatrixCell(String day, int slot) {
    // Friday Jummah Prayer Window Hard Constraint (friday_no_p4): Non-negotiable hard block
    final isFridayJummah = (day == 'Friday' || day == 'Fri') && slot == 4;
    if (isFridayJummah) {
      return Tooltip(
        message: 'Hard Constraint: Friday Jummah Prayer Window (friday_no_p4) — No classes permitted',
        child: Container(
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.12),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.45)),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(PhosphorIconsRegular.lock, size: 10, color: AppColors.error),
              Text(
                'JUMMAH',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 7.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final key = '${day}_P$slot';
    final state = _matrix[key] ?? 0;

    Color bg;
    Color border;
    IconData? icon;

    switch (state) {
      case 1: // Preferred (R8 - Cyan)
        bg = AppColors.info.withValues(alpha: 0.18);
        border = AppColors.info;
        icon = PhosphorIconsRegular.star;
        break;
      case 2: // External Dept Block (R4 - Crimson)
        bg = AppColors.error.withValues(alpha: 0.18);
        border = AppColors.error;
        icon = PhosphorIconsRegular.prohibit;
        break;
      case 3: // Guest Window (R5 - Amber)
        bg = AppColors.warning.withValues(alpha: 0.18);
        border = AppColors.warning;
        icon = PhosphorIconsRegular.clock;
        break;
      default: // Available (Default Gray)
        bg = AppColors.background;
        border = AppColors.border;
        icon = null;
    }

    return InkWell(
      onTap: () {
        setState(() {
          final nextState = (state + 1) % 4;
          if (nextState == 0) {
            _matrix.remove(key);
          } else {
            _matrix[key] = nextState;
          }
          _markDirty();
        });
      },
      child: Container(
        height: 32,
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border),
        ),
        alignment: Alignment.center,
        child: icon != null
            ? Icon(icon, size: 12, color: border)
            : Text(
                '—',
                style: AppTextStyles.caption.copyWith(color: AppColors.textMuted, fontSize: 10),
              ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final acronym = _acronymController.text.trim();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: Text('Delete Faculty', style: AppTextStyles.h4),
        content: Text(
          'Are you sure you want to delete faculty member $acronym? This removes their availability and rule preferences.',
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
              await widget.controller.deleteFaculty(widget.faculty.id);
              if (mounted && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Faculty $acronym deleted.'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
