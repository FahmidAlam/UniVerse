import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/models/resource_model.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/features/resources/controllers/resource_controller.dart';
import 'package:universe/shared/widgets/desktop_shell_scope.dart';
import 'package:universe/shared/widgets/resource_card.dart';
import 'package:universe/shared/widgets/scrollable_empty.dart';
import 'package:universe/shared/widgets/shell_back_scope.dart';
import 'package:universe/shared/widgets/u_app_bar.dart';
import 'package:universe/shared/widgets/u_card.dart';
import 'package:universe/shared/widgets/u_chip.dart';
import 'package:universe/shared/widgets/u_empty_state.dart';
import 'package:universe/shared/widgets/u_loading.dart';

class ResourcesScreen extends StatefulWidget {
  final AuthController authController;
  final ResourceController? controller;

  const ResourcesScreen({
    super.key,
    required this.authController,
    this.controller,
  });

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen> {
  late final ResourceController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        ResourceController(authController: widget.authController);
    _controller.load();
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
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
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (opened) return;
    } catch (_) {}
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
    final isDesktopShell = DesktopShellScope.isDesktopOf(context);

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final open = _controller.openSemester;
        return ShellBackScope(
          onBack: open == null ? null : _controller.closeFolder,
          child: Scaffold(
            backgroundColor: AppColors.bgPrimary,
            appBar: isDesktopShell
                ? null
                : (open == null
                    ? const UAppBar(title: 'Resources', showBackButton: false)
                    : UAppBar(
                        title: 'Semester $open',
                        leading: IconButton(
                          icon: const Icon(
                            PhosphorIconsRegular.arrowLeft,
                            color: AppColors.textPrimary,
                          ),
                          onPressed: _controller.closeFolder,
                        ),
                      )),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  children: [
                    if (isDesktopShell) _buildDesktopHeader(open),
                    Expanded(
                      child: open == null
                          ? _buildFolderGrid()
                          : Column(
                              children: [
                                _buildFilterBar(),
                                Expanded(child: _buildBody()),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopHeader(int? open) {
    if (open != null) {
      final count = _controller.countForSemester(open);
      return Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(
                PhosphorIconsRegular.arrowLeft,
                color: AppColors.textPrimary,
              ),
              onPressed: _controller.closeFolder,
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Semester $open Resources', style: AppTextStyles.h2),
                const SizedBox(height: 2),
                Text(
                  'Syllabi, course files & materials',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.bgSubtle,
                borderRadius: AppSpacing.radiusFull,
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                '$count ${count == 1 ? 'file' : 'files'}',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Academic Resources', style: AppTextStyles.h2),
              const SizedBox(height: 2),
              Text(
                'Department syllabus, handouts, question archives & references',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppColors.bgSubtle,
              borderRadius: AppSpacing.radiusFull,
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              '${AppConstants.semesters.length} Semesters Available',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderGrid() {
    if (_controller.isLoading) {
      return const Center(child: ULoading.spinner());
    }
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.bgCard,
      onRefresh: _controller.load,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final crossAxisCount = width >= 1000 ? 4 : (width >= 640 ? 3 : 2);

          return GridView.builder(
            padding: AppSpacing.screenPadding,
            physics: const AlwaysScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              childAspectRatio: 1.15,
            ),
            itemCount: AppConstants.semesters.length,
            itemBuilder: (context, index) {
              final s = AppConstants.semesters[index];
              return _folderCard(s);
            },
          );
        },
      ),
    );
  }

  Widget _folderCard(int semester) {
    final count = _controller.countForSemester(semester);
    final isMine = _controller.mySemester == semester;
    return UCard(
      isTopLit: true,
      onTap: () => _controller.openFolder(semester),
      border: isMine
          ? Border.all(color: AppColors.primary.withValues(alpha: 0.6), width: 1.5)
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
                child: const Icon(
                  PhosphorIconsRegular.folder,
                  color: AppColors.primary,
                  size: AppSpacing.iconLg,
                ),
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
                  child: Text(
                    'YOURS',
                    style: AppTextStyles.badge.copyWith(color: AppColors.primary),
                  ),
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
          : Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: UCard(
                isTopLit: true,
                padding: EdgeInsets.zero,
                child: ClipRRect(
                  borderRadius: AppSpacing.radiusMd,
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.border,
                    ),
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
                ),
              ),
            ),
    );
  }
}
