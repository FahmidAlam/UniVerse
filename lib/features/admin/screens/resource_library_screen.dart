import 'package:universe/features/admin/widgets/admin_route_tabs.dart';
import 'package:universe/shared/widgets/desktop_shell_scope.dart';
import 'package:flutter/material.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/models/resource_model.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/admin/controllers/resource_admin_controller.dart';
import 'package:universe/shared/widgets/u_app_bar.dart';
import 'package:universe/shared/widgets/u_card.dart';
import 'package:universe/shared/widgets/u_empty_state.dart';
import 'package:universe/shared/widgets/u_loading.dart';

import 'package:universe/shared/widgets/u_chip.dart';
import 'package:universe/shared/widgets/u_adaptive_overlay.dart';

class ResourceLibraryScreen extends StatefulWidget {
  final ResourceAdminController? controller;
  const ResourceLibraryScreen({super.key, this.controller});
  @override
  State<ResourceLibraryScreen> createState() => _ResourceLibraryScreenState();
}

class _ResourceLibraryScreenState extends State<ResourceLibraryScreen> {
  late final ResourceAdminController _controller;
  int? _semester;
  String? _type;
  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? ResourceAdminController();
    _controller.load();
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete(Resource r) async {
    final confirmed = await showUAdaptiveModal<bool>(
        context: context,
        title: 'Delete resource?',
        builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
              Text('"${r.title}" will be removed for everyone.',
                  style: AppTextStyles.bodySm),
              Wrap(spacing: 12, children: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel')),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Delete'))
              ]),
            ]));
    if (confirmed == true) {
      final ok = await _controller.delete(r.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok ? 'Resource deleted.' : 'Could not delete.')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: DesktopShellScope.isDesktopOf(context)
            ? null
            : const UAppBar(title: 'Resource Library'),
        body: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              final items = _controller.all
                  .where((r) =>
                      (_semester == null || r.semester == _semester) &&
                      (_type == null || r.category == _type))
                  .toList();
              return Center(
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1160),
                      child: Column(children: [
                        Padding(
                            padding: AppSpacing.screenPadding,
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const AdminRouteTabs(
                                      selected: '/admin/resources/library',
                                      destinations: {
                                        '/admin/resources': 'Manage & Upload',
                                        '/admin/resources/library':
                                            'Resource Library'
                                      }),
                                  AppSpacing.mdGap,
                                  Wrap(spacing: 8, runSpacing: 8, children: [
                                    UChip(
                                        label: 'All semesters',
                                        isActive: _semester == null,
                                        onTap: () =>
                                            setState(() => _semester = null)),
                                    for (final sem in AppConstants.semesters)
                                      UChip(
                                          label: 'Sem $sem',
                                          isActive: _semester == sem,
                                          onTap: () =>
                                              setState(() => _semester = sem)),
                                  ]),
                                  AppSpacing.smGap,
                                  Wrap(spacing: 8, runSpacing: 8, children: [
                                    UChip(
                                        label: 'All types',
                                        isActive: _type == null,
                                        onTap: () =>
                                            setState(() => _type = null)),
                                    for (final type
                                        in ResourceAdminController.categories)
                                      UChip(
                                          label: type,
                                          isActive: _type == type,
                                          onTap: () =>
                                              setState(() => _type = type)),
                                  ]),
                                  AppSpacing.smGap,
                                  AdminMatchCount(
                                      label:
                                          'Showing ${items.length} resources'),
                                ])),
                        Expanded(
                            child: _controller.isLoading
                                ? const ULoading.spinner()
                                : _controller.errorMessage != null
                                    ? UEmptyState.error(
                                        message: _controller.errorMessage!,
                                        onRetry: _controller.load)
                                    : items.isEmpty
                                        ? UEmptyState.noMatches(
                                            title: _controller.all.isEmpty
                                                ? 'No resources yet'
                                                : 'No matching resources',
                                            onClearFilters: () => setState(() {
                                                  _semester = null;
                                                  _type = null;
                                                }))
                                        : Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: AppSpacing.screenH),
                                            child: UCard(
                                                isTopLit: true,
                                                padding: EdgeInsets.zero,
                                                child: RefreshIndicator(
                                                    onRefresh: _controller.load,
                                                    child: ListView.separated(
                                                        physics:
                                                            const AlwaysScrollableScrollPhysics(),
                                                        itemCount: items.length,
                                                        separatorBuilder: (_,
                                                                __) =>
                                                            const Divider(
                                                                height: 1,
                                                                thickness: 1,
                                                                color: AppColors
                                                                    .border),
                                                        itemBuilder: (context,
                                                                i) =>
                                                            _AdminResourceTile(
                                                                resource:
                                                                    items[i],
                                                                onDelete: () =>
                                                                    _confirmDelete(items[i]))))))),
                      ])));
            }),
      );
}

class _AdminResourceTile extends StatelessWidget {
  final Resource resource;
  final VoidCallback onDelete;

  const _AdminResourceTile({required this.resource, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isPdf = resource.isPdf;
    final color = isPdf ? AppColors.error : AppColors.info;
    return Padding(
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
            tooltip: 'Delete resource',
            icon: const Icon(PhosphorIconsRegular.trash,
                size: AppSpacing.iconMd, color: AppColors.error),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
