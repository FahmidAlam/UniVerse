// ============================================================
// FILE: lib/features/resources/screens/resources_screen.dart
// PURPOSE: Resource Hub. Secondary screen (reached from the
// dashboard, not a bottom-nav tab) — so it shows a back button
// and no bottom nav. Category filter chips + resource cards.
// Tapping a card copies its link (url_launcher not yet a dep;
// see note) so it can be opened/shared.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:universe_v1/core/constants/app_constants.dart';
import 'package:universe_v1/core/models/resource_model.dart';
import 'package:universe_v1/core/theme/app_colors.dart';
import 'package:universe_v1/core/theme/app_spacing.dart';
import 'package:universe_v1/core/theme/app_text_styles.dart';
import 'package:universe_v1/features/auth/controllers/auth_controller.dart';
import 'package:universe_v1/features/resources/controllers/resource_controller.dart';
import 'package:universe_v1/shared/widgets/resource_card.dart';
import 'package:universe_v1/shared/widgets/u_app_bar.dart';
import 'package:universe_v1/shared/widgets/u_chip.dart';
import 'package:universe_v1/shared/widgets/u_empty_state.dart';
import 'package:universe_v1/shared/widgets/u_loading.dart';

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
    // url_launcher isn't a dependency yet; copy the link so it can be
    // opened/shared. Swap for launchUrl() once url_launcher is added.
    await Clipboard.setData(ClipboardData(text: link));
    _snack('Link copied — ${r.title}');
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
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: const UAppBar(title: 'Resources'),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return Column(
            children: [
              _buildFilterBar(),
              Expanded(child: _buildBody()),
            ],
          );
        },
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
    if (items.isEmpty) {
      return const UEmptyState(
        icon: PhosphorIconsRegular.folderOpen,
        title: 'No resources',
        message: 'Nothing here yet for this filter. Check back later.',
      );
    }

    return ListView.separated(
      padding: AppSpacing.screenPadding,
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
    );
  }
}
