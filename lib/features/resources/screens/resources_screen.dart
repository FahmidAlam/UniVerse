// ============================================================
// FILE: lib/features/resources/screens/resources_screen.dart
// PURPOSE: Resource Hub. A top-level student tab (rendered inside
// AppShell, so the bottom nav shows). The folder grid is the tab
// root (no back button); opening a semester swaps to an in-screen
// back arrow that closes the folder. Category filter chips +
// resource cards. Tapping a card opens its link (PDF / Drive) in
// the device's default app; if that fails, the link is copied.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/models/resource_model.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/features/resources/controllers/resource_controller.dart';
import 'package:universe/shared/widgets/resource_card.dart';
import 'package:universe/shared/widgets/scrollable_empty.dart';
import 'package:universe/shared/widgets/u_app_bar.dart';
import 'package:universe/shared/widgets/u_card.dart';
import 'package:universe/shared/widgets/u_chip.dart';
import 'package:universe/shared/widgets/u_empty_state.dart';
import 'package:universe/shared/widgets/u_loading.dart';

class ResourcesScreen extends StatefulWidget {
  final AuthController authController;

  const ResourcesScreen({super.key, required this.authController});

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen> {
  late final ResourceController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ResourceController(authController: widget.authController);
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openResource(Resource r) async {
    final link = r.url;
    if (link == null || link.isEmpty) {
      _snack('No link available for this resource.');
      return;
    }
    final uri = Uri.tryParse(link);
    if (uri == null) {
      _snack('This resource has an invalid link.');
      return;
    }
    // Open in the device's browser / Drive / PDF viewer. If nothing can
    // handle it, fall back to copying the link so it's never a dead tap.
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (opened) return;
    } catch (_) {
      // fall through to the copy fallback
    }
    await Clipboard.setData(ClipboardData(text: link));
    _snack('Couldn\'t open it — link copied instead.');
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final open = _controller.openSemester;
        return PopScope(
          canPop: open == null,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _controller.closeFolder();
          },
          child: Scaffold(
            backgroundColor: AppColors.bgPrimary,
            appBar: open == null
                ? const UAppBar(title: 'Resources', showBackButton: false)
                : UAppBar(
                    title: 'Semester $open',
                    leading: IconButton(
                      icon: const Icon(PhosphorIconsRegular.arrowLeft,
                          color: AppColors.textPrimary),
                      onPressed: _controller.closeFolder,
                    ),
                  ),
            body: open == null
                ? _buildFolderGrid()
                : Column(
                    children: [
                      _buildFilterBar(),
                      Expanded(child: _buildBody()),
                    ],
                  ),
          ),
        );
      },
    );
  }

  // ─── Semester folders ─────────────────────────────────────
  Widget _buildFolderGrid() {
    if (_controller.isLoading) {
      return const Center(child: ULoading.spinner());
    }
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.bgCard,
      onRefresh: _controller.load,
      child: GridView.count(
        padding: AppSpacing.screenPadding,
        physics: const AlwaysScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 1.15,
        children: [
          for (final s in AppConstants.semesters) _folderCard(s),
        ],
      ),
    );
  }

  Widget _folderCard(int semester) {
    final count = _controller.countForSemester(semester);
    final isMine = _controller.mySemester == semester;
    return UCard(
      onTap: () => _controller.openFolder(semester),
      border: isMine
          ? Border.all(color: AppColors.primary.withValues(alpha: 0.5))
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
              if (isMine)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: AppSpacing.radiusSm,
                  ),
                  child: Text('YOURS',
                      style: AppTextStyles.badge
                          .copyWith(color: AppColors.primary)),
                ),
            ],
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

  Widget _buildFilterBar() {
    return SizedBox(
      height: AppSpacing.chipHeight + AppSpacing.lg,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenH,
          vertical: AppSpacing.sm,
        ),
        itemCount: AppConstants.resourceCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) {
          final cat = AppConstants.resourceCategories[i];
          return UChip(
            label: cat,
            isActive: _controller.activeCategory == cat,
            onTap: () => _controller.setCategory(cat),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_controller.isLoading) {
      return ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        itemCount: 6,
        separatorBuilder: (_, __) => AppSpacing.cardGap,
        itemBuilder: (_, __) => const ULoading.skeleton(skeletonHeight: 68),
      );
    }

    final items = _controller.filtered;

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.bgCard,
      onRefresh: _controller.load,
      child: items.isEmpty
          ? const ScrollableEmpty(
              child: UEmptyState(
                icon: PhosphorIconsRegular.folderOpen,
                title: 'No resources',
                message: 'Nothing here yet for this filter. Check back later.',
              ),
            )
          : ListView.separated(
              padding: AppSpacing.screenPadding,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => AppSpacing.cardGap,
              itemBuilder: (context, i) {
                final r = items[i];
                return ResourceCard(
                  title: r.title,
                  subject: r.subjectLabel,
                  category: r.category,
                  type: r.isPdf ? ResourceType.pdf : ResourceType.drive,
                  onTap: () => _openResource(r),
                );
              },
            ),
    );
  }
}
