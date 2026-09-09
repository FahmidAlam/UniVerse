import 'package:flutter/material.dart';
import 'package:universe/core/models/timetable_config_model.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/admin/controllers/course_eligibility_controller.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/shared/widgets/u_app_bar.dart';
import 'package:universe/shared/widgets/u_button.dart';
import 'package:universe/shared/widgets/u_card.dart';
import 'package:universe/shared/widgets/u_empty_state.dart';
import 'package:universe/shared/widgets/u_loading.dart';
import 'package:universe/shared/widgets/u_text_field.dart';

/// Admin screen: which courses each teacher is qualified to take, and which of
/// those they prefer.
///
/// Read this as a data-quality gate on the Course Distribution workbook. The
/// workbook decides who teaches what; the engine only schedules. What this
/// screen configures is the check that refuses to publish a routine in which
/// the workbook handed a course to someone not eligible for it.
class ManageCourseEligibilityScreen extends StatefulWidget {
  const ManageCourseEligibilityScreen({super.key});

  @override
  State<ManageCourseEligibilityScreen> createState() =>
      _ManageCourseEligibilityScreenState();
}

class _ManageCourseEligibilityScreenState
    extends State<ManageCourseEligibilityScreen> {
  late final CourseEligibilityController _controller;

  @override
  void initState() {
    super.initState();
    _controller = CourseEligibilityController()..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: const UAppBar(
        title: 'Course Assignments',
        subtitle: 'Who may teach what',
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.isLoading) return const ULoading.spinner();
          if (_controller.selectedAcronym != null) return _courseList();
          return _facultyList();
        },
      ),
    );
  }

  // Step 1: pick a teacher.
  Widget _facultyList() {
    final list = _controller.faculty;
    return Column(
      children: [
        Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_controller.errorMessage != null) ...[
                _banner(_controller.errorMessage!, AppColors.error,
                    AppColors.errorSoft),
                AppSpacing.smGap,
              ],
              _banner(
                'A teacher with no courses set is treated as unconfigured, not '
                'as unqualified, so you can fill this in a few at a time '
                'without failing a routine.',
                AppColors.info,
                AppColors.infoSoft,
              ),
              AppSpacing.smGap,
              UTextField(
                label: 'Search',
                hint: 'Acronym or name (e.g. EBH)',
                prefixIcon: PhosphorIconsRegular.magnifyingGlass,
                onChanged: _controller.setFacultyQuery,
              ),
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const UEmptyState(
                  icon: PhosphorIconsRegular.usersThree,
                  title: 'No teachers found',
                  message: 'Try a different search.',
                )
              : ListView.builder(
                  padding: AppSpacing.screenPaddingH,
                  itemCount: list.length,
                  itemBuilder: (_, i) => _facultyTile(list[i]),
                ),
        ),
      ],
    );
  }

  Widget _facultyTile(TimetableFaculty f) {
    final n = _controller.configuredCountFor(f.acronym);
    return UCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      onTap: () => _controller.select(f.acronym),
      child: Row(
        children: [
          Container(
            width: AppSpacing.avatarSm,
            height: AppSpacing.avatarSm,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: AppSpacing.radiusSm,
            ),
            child: Text(f.acronym,
                style: AppTextStyles.chip.copyWith(color: AppColors.primary)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f.displayName, style: AppTextStyles.bodyMedium),
                Text(
                  n == 0 ? 'Not configured' : '$n course(s) allowed',
                  style: AppTextStyles.caption.copyWith(
                    color: n == 0 ? AppColors.textMuted : AppColors.success,
                  ),
                ),
              ],
            ),
          ),
          const Icon(PhosphorIconsRegular.caretRight,
              size: AppSpacing.iconSm, color: AppColors.textMuted),
        ],
      ),
    );
  }

  // Step 2: tick courses and rank them.
  Widget _courseList() {
    final list = _controller.courses;
    return Column(
      children: [
        Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  UButton(
                    label: 'Back',
                    icon: PhosphorIconsRegular.caretLeft,
                    variant: UButtonVariant.secondary,
                    onPressed: () => _controller.select(null),
                  ),
                  const Spacer(),
                  Text('${_controller.selectedCount} selected',
                      style: AppTextStyles.caption),
                ],
              ),
              AppSpacing.smGap,
              Text(_controller.selectedAcronym ?? '', style: AppTextStyles.h2),
              Text(
                'Tick every course this teacher is qualified to take. '
                'Priority 1 is the most preferred.',
                style: AppTextStyles.caption,
              ),
              if (_controller.errorMessage != null) ...[
                AppSpacing.smGap,
                _banner(_controller.errorMessage!, AppColors.error,
                    AppColors.errorSoft),
              ],
              AppSpacing.smGap,
              UTextField(
                label: 'Search',
                hint: 'Code or title (e.g. CSE-1101)',
                prefixIcon: PhosphorIconsRegular.magnifyingGlass,
                onChanged: _controller.setCourseQuery,
              ),
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const UEmptyState(
                  icon: PhosphorIconsRegular.bookOpen,
                  title: 'No courses found',
                  message: 'Courses come from the published routine. Publish '
                      'a routine first, or try a different search.',
                )
              : ListView.builder(
                  padding: AppSpacing.screenPaddingH,
                  itemCount: list.length,
                  itemBuilder: (_, i) => _courseTile(list[i]),
                ),
        ),
        Padding(
          padding: AppSpacing.screenPadding,
          child: UButton(
            label: _controller.isSaving ? 'Saving' : 'Save',
            icon: PhosphorIconsRegular.floppyDisk,
            fullWidth: true,
            isLoading: _controller.isSaving,
            onPressed: _controller.hasUnsavedChanges ? _save : null,
          ),
        ),
      ],
    );
  }

  Widget _courseTile(({String code, String title}) c) {
    final on = _controller.isEligible(c.code);
    final priority = _controller.priorityOf(c.code);
    return UCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      onTap: () => _controller.toggle(c.code),
      child: Row(
        children: [
          Icon(
            on ? PhosphorIconsRegular.checkSquare : PhosphorIconsRegular.square,
            size: AppSpacing.iconMd,
            color: on ? AppColors.primary : AppColors.textMuted,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.code, style: AppTextStyles.bodyMedium),
                Text(c.title,
                    style: AppTextStyles.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (on)
            SizedBox(
              width: 96,
              child: DropdownButtonFormField<int?>(
                initialValue: priority,
                isDense: true,
                decoration: const InputDecoration(
                  labelText: 'Priority',
                  isDense: true,
                ),
                style: AppTextStyles.bodySm,
                dropdownColor: AppColors.bgElevated,
                items: <DropdownMenuItem<int?>>[
                  const DropdownMenuItem(value: null, child: Text('-')),
                  for (var i = 1; i <= 5; i++)
                    DropdownMenuItem(value: i, child: Text('$i')),
                ],
                onChanged: (v) => _controller.setPriority(c.code, v),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final ok = await _controller.save();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Saved.' : 'Could not save.'),
        backgroundColor: ok ? AppColors.success : AppColors.error,
      ),
    );
  }

  Widget _banner(String text, Color color, Color soft) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: AppSpacing.radiusMd,
        border: Border.all(color: color),
      ),
      child: Text(text, style: AppTextStyles.bodySm.copyWith(color: color)),
    );
  }
}
