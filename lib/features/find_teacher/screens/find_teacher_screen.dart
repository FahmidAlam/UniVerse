// PHASE 1: Campus shares navigation and shell-aware account/page chrome.
import 'package:universe/shared/widgets/campus_lookup_switcher.dart';
import 'package:universe/shared/widgets/u_app_bar.dart';
import 'package:universe/shared/widgets/u_responsive_workspace.dart';
import 'package:flutter/material.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/find_teacher/controllers/find_teacher_controller.dart';
import 'package:universe/features/find_teacher/services/teacher_location_service.dart';
import 'package:universe/features/find_teacher/widgets/teacher_location_card.dart';

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

  void _onControllerChange() {
    setState(() {});
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      // PHASE 1: UAppBar removes implicit drawer chrome and exposes account access.
      appBar: UAppBar(
        title: 'Faculty',
        showBackButton: false,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(
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
      // PHASE 1: Keep the Campus switcher available in all asynchronous states.
      body: Column(children: [
        const CampusLookupSwitcher(faculty: true),
        Expanded(child: _buildContent())
      ]),
    );
  }

  Widget _buildContent() {
    if (_controller.isLoading) {
      return Center(
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
            Icon(
              PhosphorIconsRegular.warningCircle,
              color: AppColors.error,
              size: AppSpacing.iconXl,
            ),
            SizedBox(height: AppSpacing.md),
            Text(
              'Error loading teachers',
              style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              _controller.error ?? 'Unknown error',
              style: AppTextStyles.bodySm.copyWith(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: () {
                _controller.initialize();
              },
              icon: Icon(PhosphorIconsRegular.arrowClockwise),
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
          final isDesktopGrid = constraints.maxWidth >= 700;
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
                      return TeacherLocationCard(teacherInfo: teacherInfo);
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
