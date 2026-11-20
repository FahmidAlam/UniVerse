// PHASE 1 & 6: Campus shares navigation and shell-aware account/page chrome.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:universe/core/router/route_names.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/find_teacher/controllers/find_teacher_controller.dart';
import 'package:universe/features/find_teacher/screens/teacher_detail_screen.dart';
import 'package:universe/features/find_teacher/services/teacher_location_service.dart';
import 'package:universe/features/find_teacher/widgets/teacher_location_card.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/shared/widgets/campus_lookup_switcher.dart';
import 'package:universe/shared/widgets/desktop_shell_scope.dart';
import 'package:universe/shared/widgets/u_app_bar.dart';
import 'package:universe/shared/widgets/u_card.dart';
import 'package:universe/shared/widgets/u_responsive_workspace.dart';

class FindTeacherScreen extends StatefulWidget {
  final FindTeacherController? controller;

  const FindTeacherScreen({super.key, this.controller});

  @override
  State<FindTeacherScreen> createState() => _FindTeacherScreenState();
}

class _FindTeacherScreenState extends State<FindTeacherScreen> {
  late final FindTeacherController _controller;
  late final bool _ownsController;
  late final TextEditingController _searchController;
  String? _selectedTeacherCode;
  String? _selectedTeacherName;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        FindTeacherController(service: TeacherLocationService());
    if (_ownsController) {
      _controller.initialize();
      _controller.subscribeToRealTimeUpdates();
    }
    _controller.addListener(_onControllerChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      final query = GoRouterState.of(context).uri.queryParameters;
      final queryTeacher = query['teacher'] ?? query['code'];
      if (queryTeacher != null &&
          queryTeacher.isNotEmpty &&
          _selectedTeacherCode == null) {
        _selectedTeacherCode = queryTeacher;
        _selectedTeacherName = query['name'] ?? queryTeacher;
      }
    } catch (_) {
      // Ignored when outside GoRouter tree (e.g. tests)
    }
  }

  void _onControllerChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChange);
    _searchController.dispose();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _selectTeacher(TeacherInfo teacher, bool isDesktop) {
    setState(() {
      _selectedTeacherCode = teacher.code;
      _selectedTeacherName = teacher.name;
    });
    if (isDesktop) {
      try {
        final uri = GoRouterState.of(context).uri;
        final newParams = Map<String, String>.from(uri.queryParameters);
        newParams['teacher'] = teacher.code;
        final newUri = uri.replace(queryParameters: newParams);
        GoRouter.of(context).replace(newUri.toString());
      } catch (_) {}
    } else {
      context.push(
        RouteNames.teacherDetailLocation(
          code: teacher.code,
          name: teacher.name,
        ),
        extra: TeacherDetailArgs(
          code: teacher.code,
          name: teacher.name,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktopShell = DesktopShellScope.isDesktopOf(context);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: isDesktopShell
          ? null
          : UAppBar(
              title: 'Faculty',
              showBackButton: false,
              actions: [
                IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(
                    PhosphorIconsRegular.arrowClockwise,
                    color: AppColors.primary,
                    size: AppSpacing.iconMd,
                  ),
                  onPressed: () async {
                    await _controller.refresh();
                  },
                ),
              ],
            ),
      body: Column(
        children: [
          const CampusLookupSwitcher(faculty: true),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_controller.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      );
    }

    if (_controller.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              PhosphorIconsRegular.warningCircle,
              color: AppColors.error,
              size: AppSpacing.iconXl,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Error loading teachers',
              style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _controller.error ?? 'Unknown error',
              style: AppTextStyles.bodySm.copyWith(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: () {
                _controller.initialize();
              },
              icon: const Icon(PhosphorIconsRegular.arrowClockwise),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _controller.refresh(),
      color: AppColors.primary,
      backgroundColor: AppColors.bgCard,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final usableWidth = constraints.maxWidth;
          final isMasterDetail = usableWidth >= 900;

          if (isMasterDetail) {
            final activeTeacher = (_selectedTeacherCode != null
                    ? _controller.filteredTeachers.cast<TeacherInfo?>().firstWhere(
                          (t) => t?.code == _selectedTeacherCode,
                          orElse: () => null,
                        )
                    : null) ??
                (_controller.filteredTeachers.isNotEmpty
                    ? _controller.filteredTeachers.first
                    : null);

            final activeCode = activeTeacher?.code ?? _selectedTeacherCode ?? '';
            final activeName = activeTeacher?.name ?? _selectedTeacherName ?? activeCode;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left 55% Master List
                Expanded(
                  flex: 55,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.sm,
                          AppSpacing.lg,
                          AppSpacing.xs,
                        ),
                        child: USearchFilterBar(
                          controller: _searchController,
                          hint: 'Search by name or code...',
                          statusPillLabel:
                              'Showing ${_controller.filteredTeachers.length} faculty',
                          onChanged: (value) {
                            _controller.search(value);
                          },
                        ),
                      ),
                      if (_controller.filteredTeachers.isEmpty)
                        Expanded(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  PhosphorIconsRegular.person,
                                  color: AppColors.textMuted,
                                  size: AppSpacing.iconXl,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Text(
                                  _controller.searchQuery.isEmpty
                                      ? 'No teachers found'
                                      : 'No matching teachers',
                                  style: AppTextStyles.body.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.builder(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.xl),
                            itemCount: _controller.filteredTeachers.length,
                            itemBuilder: (context, index) {
                              final teacherInfo =
                                  _controller.filteredTeachers[index];
                              final isSelected =
                                  teacherInfo.code == activeCode;
                              return TeacherLocationCard(
                                teacherInfo: teacherInfo,
                                isSelected: isSelected,
                                onSelect: () =>
                                    _selectTeacher(teacherInfo, true),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                const VerticalDivider(color: AppColors.border, width: 1),
                // Right 45% Inline Weekly Schedule Detail Pane
                Expanded(
                  flex: 45,
                  child: Container(
                    color: AppColors.bgPrimary,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: activeCode.isEmpty
                        ? Center(
                            child: Text(
                              'Select a faculty member to view schedule',
                              style: AppTextStyles.body
                                  .copyWith(color: AppColors.textMuted),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    PhosphorIconsRegular.calendarCheck,
                                    color: AppColors.primary,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'WEEKLY SCHEDULE · $activeName ($activeCode)',
                                      style: AppTextStyles.labelCaps.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'Teaching schedule derived from published routine. Tap any day to inspect class meetings.',
                                style: AppTextStyles.caption
                                    .copyWith(color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Expanded(
                                child: UCard(
                                  isTopLit: true,
                                  padding: const EdgeInsets.all(AppSpacing.sm),
                                  child: TeacherDetailView(
                                    teacherCode: activeCode,
                                    teacherName: activeName,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            );
          }

          // Mobile / Tablet single column adaptive card grid
          final isDesktopGrid = usableWidth >= 700;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: USearchFilterBar(
                  controller: _searchController,
                  hint: 'Search by name or code...',
                  statusPillLabel:
                      'Showing ${_controller.filteredTeachers.length} faculty',
                  onChanged: (value) {
                    _controller.search(value);
                  },
                ),
              ),
              if (_controller.filteredTeachers.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          PhosphorIconsRegular.person,
                          color: AppColors.textMuted,
                          size: AppSpacing.iconXl,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          _controller.searchQuery.isEmpty
                              ? 'No teachers found'
                              : 'No matching teachers',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: UAdaptiveCardGrid(
                    singleColumnBreakpoint: 700,
                    mainAxisExtent: 312,
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktopGrid ? AppSpacing.sm : 0,
                      vertical: AppSpacing.md,
                    ),
                    itemCount: _controller.filteredTeachers.length,
                    itemBuilder: (context, index) {
                      final teacherInfo = _controller.filteredTeachers[index];
                      return TeacherLocationCard(
                        teacherInfo: teacherInfo,
                        onSelect: () => _selectTeacher(teacherInfo, false),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
