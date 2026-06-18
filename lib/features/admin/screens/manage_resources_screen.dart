// ============================================================
// FILE: lib/features/admin/screens/manage_resources_screen.dart
// PURPOSE: Admin uploads study resources (any file type) or a
// Drive link → the public `resources` bucket + a row → students
// see it in the Resource Hub and (optionally) get alerted via the
// notifications pipeline (in-app + push). Lists existing resources
// with delete. Secondary screen (pushed, back button).
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:universe_v1/core/constants/app_constants.dart';
import 'package:universe_v1/core/router/route_names.dart';
import 'package:universe_v1/core/theme/app_colors.dart';
import 'package:universe_v1/core/theme/app_spacing.dart';
import 'package:universe_v1/core/theme/app_text_styles.dart';
import 'package:universe_v1/features/admin/controllers/resource_admin_controller.dart';
import 'package:universe_v1/shared/widgets/u_app_bar.dart';
import 'package:universe_v1/shared/widgets/u_button.dart';
import 'package:universe_v1/shared/widgets/u_card.dart';
import 'package:universe_v1/shared/widgets/u_chip.dart';
import 'package:universe_v1/shared/widgets/u_text_field.dart';

class ManageResourcesScreen extends StatefulWidget {
  const ManageResourcesScreen({super.key});

  @override
  State<ManageResourcesScreen> createState() => _ManageResourcesScreenState();
}

class _ManageResourcesScreenState extends State<ManageResourcesScreen> {
  late final ResourceAdminController _controller;
  final _titleCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _linkCtrl = TextEditingController();
  bool _notify = true;

  @override
  void initState() {
    super.initState();
    _controller = ResourceAdminController();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _titleCtrl.dispose();
    _subjectCtrl.dispose();
    _linkCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: AppTextStyles.bodySm),
        backgroundColor: AppColors.bgElevated,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final ok = await _controller.submit(
      title: _titleCtrl.text,
      subjectCode: _subjectCtrl.text,
      driveLink: _linkCtrl.text,
      notifyStudents: _notify,
    );
    if (!mounted) return;
    if (ok) {
      _titleCtrl.clear();
      _subjectCtrl.clear();
      _linkCtrl.clear();
      _snack(_notify
          ? 'Resource uploaded — students notified.'
          : 'Resource uploaded.');
    } else {
      _snack(_controller.errorMessage ?? 'Upload failed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: UAppBar(
        title: 'Manage Resources',
        actions: [
          IconButton(
            tooltip: 'Uploaded resources',
            icon: const Icon(PhosphorIconsRegular.listBullets,
                color: AppColors.textPrimary),
            onPressed: () => context.push(RouteNames.resourceLibrary),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return SingleChildScrollView(
            padding: AppSpacing.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DETAILS', style: AppTextStyles.labelCaps),
                AppSpacing.smGap,
                UTextField(
                  controller: _titleCtrl,
                  label: 'Title',
                  hint: 'e.g. OS — Process Scheduling Slides',
                ),
                AppSpacing.mdGap,
                UTextField(
                  controller: _subjectCtrl,
                  label: 'Subject code (optional)',
                  hint: 'e.g. CSE-3201',
                ),
                AppSpacing.sectionGap,

                Text('CATEGORY', style: AppTextStyles.labelCaps),
                AppSpacing.smGap,
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final c in ResourceAdminController.categories)
                      UChip(
                        label: c,
                        isActive: _controller.category == c,
                        onTap: () => _controller.setCategory(c),
                      ),
                  ],
                ),
                AppSpacing.sectionGap,

                Text('SEMESTER', style: AppTextStyles.labelCaps),
                AppSpacing.smGap,
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final s in AppConstants.semesters)
                      UChip(
                        label: 'Sem $s',
                        isActive: _controller.semester == s,
                        onTap: () => _controller.setSemester(s),
                      ),
                  ],
                ),
                AppSpacing.sectionGap,

                Text('FILE OR LINK', style: AppTextStyles.labelCaps),
                AppSpacing.smGap,
                _filePicker(),
                AppSpacing.smGap,
                Text(
                  'Pick a file (any type, e.g. PDF / slides / docs) — or paste '
                  'a Drive link below instead.',
                  style: AppTextStyles.caption,
                ),
                AppSpacing.mdGap,
                UTextField(
                  controller: _linkCtrl,
                  label: 'Drive link (if no file)',
                  hint: 'https://drive.google.com/…',
                  enabled: !_controller.hasFile,
                ),
                AppSpacing.sectionGap,

                _notifyToggle(),
                AppSpacing.lgGap,
                UButton(
                  label: 'Upload resource',
                  icon: PhosphorIconsRegular.uploadSimple,
                  isLoading: _controller.isUploading,
                  onPressed: _submit,
                ),
                AppSpacing.lgGap,
                Center(
                  child: Text(
                    'Tap the list icon (top-right) to view & manage uploads.',
                    style: AppTextStyles.caption,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _filePicker() {
    final name = _controller.fileName;
    return UCard(
      onTap: _controller.pickFile,
      child: Row(
        children: [
          Icon(
            name == null
                ? PhosphorIconsRegular.filePlus
                : PhosphorIconsRegular.file,
            color: name == null ? AppColors.textMuted : AppColors.success,
            size: AppSpacing.iconLg,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name ?? 'Choose a file',
                  style: AppTextStyles.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  name == null ? 'Any file type' : 'Tap to change',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          if (name != null)
            IconButton(
              icon: const Icon(PhosphorIconsRegular.x,
                  size: AppSpacing.iconMd, color: AppColors.textMuted),
              onPressed: _controller.clearFile,
            )
          else
            const Icon(PhosphorIconsRegular.folderOpen,
                size: AppSpacing.iconMd, color: AppColors.textMuted),
        ],
      ),
    );
  }

  Widget _notifyToggle() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Notify students', style: AppTextStyles.bodyMedium),
              Text(
                'Sends an in-app alert + push to all students.',
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
        Switch(
          value: _notify,
          activeThumbColor: AppColors.primary,
          onChanged: (v) => setState(() => _notify = v),
        ),
      ],
    );
  }

}
