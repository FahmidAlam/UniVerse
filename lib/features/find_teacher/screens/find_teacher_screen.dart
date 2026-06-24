import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/find_teacher/controllers/find_teacher_controller.dart';
import 'package:universe/features/find_teacher/services/teacher_location_service.dart';
import 'package:universe/features/find_teacher/widgets/teacher_location_card.dart';
import 'package:universe/shared/widgets/u_text_field.dart';

class FindTeacherScreen extends StatefulWidget {
  const FindTeacherScreen({super.key});

  @override
  State<FindTeacherScreen> createState() => _FindTeacherScreenState();
}

class _FindTeacherScreenState extends State<FindTeacherScreen> {
  late final FindTeacherController _controller;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _controller = FindTeacherController(service: TeacherLocationService());
    _controller.initialize();
    _controller.subscribeToRealTimeUpdates();
    _controller.addListener(_onControllerChange);
  }

  void _onControllerChange() {
    setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChange);
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        title: Text(
          'Find Teacher',
          style: AppTextStyles.h2.copyWith(color: AppColors.textPrimary),
        ),
        actions: [
          IconButton(
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
      body: _buildContent(),
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
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: UTextField(
              label: '',
              hint: 'Search by name or code...',
              controller: _searchController,
              prefixIcon: PhosphorIconsRegular.magnifyingGlass,
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
                    Icon(
                      PhosphorIconsRegular.person,
                      color: AppColors.textMuted,
                      size: AppSpacing.iconXl,
                    ),
                    SizedBox(height: AppSpacing.md),
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
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                itemCount: _controller.filteredTeachers.length,
                itemBuilder: (context, index) {
                  final teacherInfo = _controller.filteredTeachers[index];
                  return TeacherLocationCard(teacherInfo: teacherInfo);
                },
              ),
            ),
        ],
      ),
    );
  }
}
