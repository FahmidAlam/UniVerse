// ============================================================
// FILE: lib/features/admin/screens/resource_library_screen.dart
// PURPOSE: The "Uploaded Resources" list, split out of the Manage
// Resources upload form so that page stays a clean upload form.
// Pushed (back button). Lists every resource with delete.
// ============================================================

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/models/resource_model.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/admin/controllers/resource_admin_controller.dart';
import 'package:universe/shared/widgets/scrollable_empty.dart';
import 'package:universe/shared/widgets/u_app_bar.dart';
import 'package:universe/shared/widgets/u_card.dart';
import 'package:universe/shared/widgets/u_empty_state.dart';
import 'package:universe/shared/widgets/u_loading.dart';

class ResourceLibraryScreen extends StatefulWidget {
  const ResourceLibraryScreen({super.key});

  @override
  State<ResourceLibraryScreen> createState() => _ResourceLibraryScreenState();
}

class _ResourceLibraryScreenState extends State<ResourceLibraryScreen> {
  late final ResourceAdminController _controller;
  int? _openSemester; // null = showing the semester folders

  @override
  void initState() {
    super.initState();
    _controller = ResourceAdminController();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
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

  Future<void> _confirmDelete(Resource r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: AppSpacing.radiusLg),
        title: Text('Delete resource?', style: AppTextStyles.h3),
        content: Text(
          '"${r.title}" will be removed for everyone.',
          style: AppTextStyles.bodySm,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: AppTextStyles.danger),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final ok = await _controller.delete(r.id);
      _snack(ok ? 'Resource deleted.' : 'Could not delete.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final open = _openSemester;
    return PopScope(
      canPop: open == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _openSemester = null);
      },
      child: Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: open == null
            ? const UAppBar(title: 'Uploaded Resources')
            : UAppBar(
                title: 'Semester $open',
                leading: IconButton(
                  icon: const Icon(PhosphorIconsRegular.arrowLeft,
                      color: AppColors.textPrimary),
                  onPressed: () => setState(() => _openSemester = null),
                ),
              ),
        body: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            return RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.bgCard,
              onRefresh: _controller.load,
              child:
                  open == null ? _buildFolderGrid() : _buildSemesterList(open),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFolderGrid() {
    if (_controller.isLoading && _controller.all.isEmpty) {
      return const Center(child: ULoading.spinner());
    }
    return GridView.count(
      padding: AppSpacing.screenPadding,
      physics: const AlwaysScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: 1.15,
      children: [
        for (final s in AppConstants.semesters) _folderCard(s),
      ],
    );
  }

  Widget _folderCard(int semester) {
    final count = _controller.all.where((r) => r.semester == semester).length;
    return UCard(
      onTap: () => setState(() => _openSemester = semester),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: AppSpacing.x4l,
            height: AppSpacing.x4l,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: AppSpacing.radiusMd,
            ),
            child: const Icon(PhosphorIconsRegular.folder,
                color: AppColors.primary, size: AppSpacing.iconLg),
          ),
          const Spacer(),
          Text('Semester $semester', style: AppTextStyles.h4),
          const SizedBox(height: AppSpacing.xs),
          Text(
            count == 0 ? 'No files yet' : '$count file${count == 1 ? '' : 's'}',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }

  Widget _buildSemesterList(int semester) {
    if (_controller.isLoading && _controller.all.isEmpty) {
      return ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        itemCount: 6,
        separatorBuilder: (_, __) => AppSpacing.cardGap,
        itemBuilder: (_, __) => const ULoading.skeleton(skeletonHeight: 64),
      );
    }

    final items =
        _controller.all.where((r) => r.semester == semester).toList();
    if (items.isEmpty) {
      return const ScrollableEmpty(
        child: UEmptyState(
          icon: PhosphorIconsRegular.folderOpen,
          title: 'No resources yet',
          message: 'Resources uploaded for this semester will appear here.',
        ),
      );
    }

    return ListView.separated(
      padding: AppSpacing.screenPadding,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) => AppSpacing.cardGap,
      itemBuilder: (context, i) {
        final r = items[i];
        return _AdminResourceTile(
            resource: r, onDelete: () => _confirmDelete(r));
      },
    );
  }
}

class _AdminResourceTile extends StatelessWidget {
  final Resource resource;
  final VoidCallback onDelete;

  const _AdminResourceTile({required this.resource, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isPdf = resource.isPdf;
    final color = isPdf ? AppColors.error : AppColors.info;
    return UCard(
      padding: AppSpacing.cardPaddingH,
      child: Row(
        children: [
          Container(
            width: AppSpacing.avatarMd,
            height: AppSpacing.avatarMd,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: AppSpacing.radiusSm,
            ),
            child: Icon(
              isPdf ? PhosphorIconsRegular.file : PhosphorIconsRegular.link,
              size: AppSpacing.iconMd,
              color: color,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resource.title,
                  style: AppTextStyles.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${resource.subjectLabel} · ${resource.category} · '
                  'Sem ${resource.semester}',
                  style: AppTextStyles.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(PhosphorIconsRegular.trash,
                size: AppSpacing.iconMd, color: AppColors.error),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
