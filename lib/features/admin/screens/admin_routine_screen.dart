import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:universe/core/router/route_names.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/admin/controllers/routine_admin_controller.dart';
import 'package:universe/features/admin/controllers/routine_upload_controller.dart';
import 'package:universe/features/admin/controllers/timetable_gen_controller.dart';
import 'package:universe/features/admin/screens/generate_timetable_screen.dart';
import 'package:universe/features/admin/screens/routine_management_screen.dart';
import 'package:universe/features/admin/screens/timetable_grid_screen.dart';
import 'package:universe/features/admin/screens/upload_routine_screen.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/shared/widgets/desktop_shell_scope.dart';
import 'package:universe/shared/widgets/u_app_bar.dart';
import 'package:universe/shared/widgets/u_segmented_control.dart';

class AdminRoutineScreen extends StatefulWidget {
  final RoutineAdminController? manageController;
  final TimetableGenController? generateController;
  final RoutineUploadController? uploadController;
  final int initialTabIndex;

  const AdminRoutineScreen({
    super.key,
    this.manageController,
    this.generateController,
    this.uploadController,
    this.initialTabIndex = 0,
  });

  @override
  State<AdminRoutineScreen> createState() => _AdminRoutineScreenState();
}

class _AdminRoutineScreenState extends State<AdminRoutineScreen> {
  late int _index;
  String? _lastTabQuery;
  bool _hasReadInitialTab = false;

  late final RoutineAdminController _manageController;
  late final TimetableGenController _generateController;
  late final RoutineUploadController _uploadController;
  late final bool _ownsManage;
  late final bool _ownsGenerate;
  late final bool _ownsUpload;

  @override
  void initState() {
    super.initState();
    _index = widget.initialTabIndex.clamp(0, 3);
    _ownsManage = widget.manageController == null;
    _manageController = widget.manageController ?? RoutineAdminController();
    _ownsGenerate = widget.generateController == null;
    _generateController = widget.generateController ?? TimetableGenController();
    _ownsUpload = widget.uploadController == null;
    _uploadController = widget.uploadController ?? RoutineUploadController();
  }

  @override
  void dispose() {
    if (_ownsManage) _manageController.dispose();
    if (_ownsGenerate) _generateController.dispose();
    if (_ownsUpload) _uploadController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    GoRouterState? routerState;
    try {
      routerState = GoRouterState.of(context);
    } catch (_) {
      routerState = null;
    }
    if (routerState != null) {
      final tab = routerState.uri.queryParameters['tab'];
      if (!_hasReadInitialTab || tab != _lastTabQuery) {
        _hasReadInitialTab = true;
        _lastTabQuery = tab;
        _index = switch (RouteNames.routineTab(routerState.uri)) {
          'grid' => 0,
          'manage' => 1,
          'generate' => 2,
          'upload' => 3,
          _ => 1,
        };
      }
    }
  }

  void _selectTab(int idx) {
    final clamped = idx.clamp(0, 3);
    setState(() => _index = clamped);
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.go(
        '${RouteNames.routineManagement}?tab=${['grid', 'manage', 'generate', 'upload'][clamped]}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // PHASE 5: Suppress duplicate inner UAppBar when rendered inside AdminDesktopShell.
    final isInDesktopShell = DesktopShellScope.isDesktopOf(context);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: isInDesktopShell
          ? null
          : const UAppBar(
              title: 'Routine Operations',
              showBackButton: false,
            ),
      body: SafeArea(
        top: !isInDesktopShell,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.md,
                AppSpacing.screenH,
                0,
              ),
              child: _buildSchedulingWorkspaceBanner(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.md,
                AppSpacing.screenH,
                AppSpacing.sm,
              ),
              child: _segmented(),
            ),
            // Lazy active tab switching with state maintained in controller instances
            Expanded(
              child: _buildActiveTab(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTab() {
    switch (_index) {
      case 0:
        return TimetableGridScreen(
          embedded: true,
          adminController: _manageController,
        );
      case 1:
        return RoutineManagementScreen(
          embedded: true,
          controller: _manageController,
        );
      case 2:
        return GenerateTimetableScreen(
          embedded: true,
          controller: _generateController,
        );
      case 3:
        return UploadRoutineScreen(
          embedded: true,
          controller: _uploadController,
        );
      default:
        return RoutineManagementScreen(
          embedded: true,
          controller: _manageController,
        );
    }
  }

  // PHASE 5: Compact 1-line instrument strip linking to Scheduling Workbench · Preview.
  Widget _buildSchedulingWorkspaceBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: AppSpacing.radiusMd,
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: 4,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                PhosphorIconsRegular.stack,
                color: AppColors.info,
                size: 15,
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  'Need revision-bound provenance preview?',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          InkWell(
            onTap: () {
              final router = GoRouter.maybeOf(context);
              if (router != null) {
                router.go(RouteNames.schedulingWorkspace);
              }
            },
            borderRadius: AppSpacing.radiusSm,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Scheduling Workbench · Preview',
                    style: AppTextStyles.captionMedium.copyWith(
                      color: AppColors.info,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    PhosphorIconsRegular.arrowRight,
                    size: 12,
                    color: AppColors.info,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Unified USegmentedControl<int> for 4 integrated live routine operations.
  Widget _segmented() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 640;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: USegmentedControl<int>(
              compact: isCompact,
              selected: _index,
              onChanged: _selectTab,
              segments: [
                USegment(
                  value: 0,
                  label: isCompact ? '2D Grid' : 'Operational 2D Grid',
                  icon: PhosphorIconsRegular.gridFour,
                ),
                USegment(
                  value: 1,
                  label: isCompact ? 'Manage' : 'Manage Published',
                  icon: PhosphorIconsRegular.calendarCheck,
                ),
                USegment(
                  value: 2,
                  label: isCompact ? 'Generate' : 'Generate via Engine',
                  icon: PhosphorIconsRegular.magicWand,
                ),
                USegment(
                  value: 3,
                  label: isCompact ? 'Upload' : 'Upload Workbook',
                  icon: PhosphorIconsRegular.uploadSimple,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
