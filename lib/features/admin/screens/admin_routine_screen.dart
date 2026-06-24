import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/admin/screens/generate_timetable_screen.dart';
import 'package:universe/features/admin/screens/routine_management_screen.dart';
import 'package:universe/shared/widgets/u_app_bar.dart';

class AdminRoutineScreen extends StatefulWidget {
  const AdminRoutineScreen({super.key});

  @override
  State<AdminRoutineScreen> createState() => _AdminRoutineScreenState();
}

class _AdminRoutineScreenState extends State<AdminRoutineScreen> {
  int _index = 0;
  bool _readInitialTab = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_readInitialTab) {
      _readInitialTab = true;
      final tab = GoRouterState.of(context).uri.queryParameters['tab'];
      if (tab == 'generate') _index = 1;
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _segmented() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: AppSpacing.radiusFull,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _seg('Manage', 0),
          _seg('Generate', 1),
        ],
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
