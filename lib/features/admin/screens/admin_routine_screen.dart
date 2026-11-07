import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:universe/core/router/route_names.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/admin/screens/generate_timetable_screen.dart';
import 'package:universe/features/admin/screens/routine_management_screen.dart';
import 'package:universe/features/admin/screens/upload_routine_screen.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/shared/widgets/u_app_bar.dart';

class AdminRoutineScreen extends StatefulWidget {
  const AdminRoutineScreen({super.key});

  @override
  State<AdminRoutineScreen> createState() => _AdminRoutineScreenState();
}

class _AdminRoutineScreenState extends State<AdminRoutineScreen> {
  int _index = 0;
  String? _lastTabQuery;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tab = GoRouterState.of(context).uri.queryParameters['tab'];
    if (tab != _lastTabQuery) {
      _lastTabQuery = tab;
      if (tab == 'generate') {
        _index = 1;
      } else if (tab == 'upload') {
        _index = 2;
      } else if (tab == 'manage') {
        _index = 0;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: const UAppBar(title: 'Routine', showBackButton: false),
      body: Column(
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
          Expanded(
            child: IndexedStack(
              index: _index,
              sizing: StackFit.expand,
              children: const [
                RoutineManagementScreen(embedded: true),
                GenerateTimetableScreen(embedded: true),
                UploadRoutineScreen(embedded: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchedulingWorkspaceBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
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
                  'Phase 2B Scheduling Workspace',
                  style: AppTextStyles.bodySmMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Manage revision-bound Course Distribution, academic policy configuration, and CP-SAT generation.',
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

  Widget _segmented() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            color: AppColors.bgElevated,
            borderRadius: AppSpacing.radiusFull,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [_seg('Manage', 0), _seg('Generate', 1), _seg('Upload', 2)],
          ),
        ),
      ),
    );
  }

  Widget _seg(String label, int idx) {
    final active = _index == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _index = idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: AppSpacing.chipHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Colors.transparent,
            borderRadius: AppSpacing.radiusFull,
          ),
          child: Text(
            label,
            style: AppTextStyles.bodySmMedium.copyWith(
              color: active ? AppColors.textPrimary : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
