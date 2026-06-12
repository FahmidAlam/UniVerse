// ============================================================
// FILE: lib/features/admin/screens/manage_users_screen.dart
// PURPOSE: Admin view of all user profiles. Search + role filter,
// and tap a user to change their role. No hard delete (removing an
// auth user needs a service-role Edge Function — out of scope).
// Owns its ManageUsersController lifecycle.
// ============================================================

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:universe_v1/core/constants/app_constants.dart';
import 'package:universe_v1/core/models/profile_model.dart';
import 'package:universe_v1/core/theme/app_colors.dart';
import 'package:universe_v1/core/theme/app_spacing.dart';
import 'package:universe_v1/core/theme/app_text_styles.dart';
import 'package:universe_v1/features/admin/controllers/manage_users_controller.dart';
import 'package:universe_v1/shared/widgets/u_app_bar.dart';
import 'package:universe_v1/shared/widgets/u_avatar.dart';
import 'package:universe_v1/shared/widgets/u_card.dart';
import 'package:universe_v1/shared/widgets/u_chip.dart';
import 'package:universe_v1/shared/widgets/u_empty_state.dart';
import 'package:universe_v1/shared/widgets/u_loading.dart';
import 'package:universe_v1/shared/widgets/u_text_field.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  late final ManageUsersController _controller;
  final _searchCtrl = TextEditingController();

  static const List<({String? role, String label})> _filters = [
    (role: null, label: 'All'),
    (role: AppConstants.roleStudent, label: 'Students'),
    (role: AppConstants.roleTeacher, label: 'Teachers'),
    (role: AppConstants.roleAdmin, label: 'Admins'),
  ];

  @override
  void initState() {
    super.initState();
    _controller = ManageUsersController();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Color _roleColor(String role) {
    switch (role) {
      case AppConstants.roleTeacher:
        return AppColors.roleTeacher;
      case AppConstants.roleAdmin:
        return AppColors.roleAdmin;
      default:
        return AppColors.roleStudent;
    }
  }

  Future<void> _changeRoleSheet(Profile p) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXlD)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: AppSpacing.screenPadding,
              child: Text('Change role · ${p.displayName}',
                  style: AppTextStyles.h3),
            ),
            for (final r in const [
              AppConstants.roleStudent,
              AppConstants.roleTeacher,
              AppConstants.roleAdmin,
            ])
              ListTile(
                leading: Icon(
                  p.role == r
                      ? PhosphorIconsRegular.checkCircle
                      : PhosphorIconsRegular.circle,
                  color: p.role == r ? AppColors.primary : AppColors.textMuted,
                ),
                title: Text(_roleLabel(r), style: AppTextStyles.bodyMedium),
                onTap: () => Navigator.pop(ctx, r),
              ),
            AppSpacing.smGap,
          ],
        ),
      ),
    );

    if (selected == null) return;
    final ok = await _controller.changeRole(p, selected);
    if (!mounted) return;
    _snack(ok
        ? '${p.displayName} is now ${_roleLabel(selected)}.'
        : (_controller.errorMessage ?? 'Could not change role.'));
  }

  String _roleLabel(String role) {
    switch (role) {
      case AppConstants.roleTeacher:
        return 'Teacher';
      case AppConstants.roleAdmin:
        return 'Admin';
      default:
        return 'Student';
    }
  }

  void _snack(String msg) {
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
      appBar: const UAppBar(title: 'Manage Users', showBackButton: false),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screenH,
                    AppSpacing.sm, AppSpacing.screenH, 0),
                child: UTextField(
                  controller: _searchCtrl,
                  label: '',
                  hint: 'Search by name, email or ID',
                  prefixIcon: PhosphorIconsRegular.magnifyingGlass,
                  onChanged: _controller.setQuery,
                ),
              ),
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
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) {
          final f = _filters[i];
          return UChip(
            label: f.label,
            isActive: _controller.roleFilter == f.role,
            onTap: () => _controller.setRoleFilter(f.role),
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
        itemBuilder: (_, __) => const ULoading.skeleton(skeletonHeight: 72),
      );
    }

    final items = _controller.filtered;
    if (items.isEmpty) {
      return const UEmptyState(
        icon: PhosphorIconsRegular.usersThree,
        title: 'No users found',
        message: 'Try a different search or filter.',
      );
    }

    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: items.length,
      separatorBuilder: (_, __) => AppSpacing.cardGap,
      itemBuilder: (context, i) => _userTile(items[i]),
    );
  }

  Widget _userTile(Profile p) {
    return UCard(
      onTap: () => _changeRoleSheet(p),
      child: Row(
        children: [
          UAvatar(
            name: p.displayName,
            imageUrl: p.avatarUrl,
            size: AppSpacing.avatarMd,
          ),
          AppSpacing.mdGap,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.displayName,
                  style: AppTextStyles.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                AppSpacing.xsGap,
                Text(
                  p.email,
                  style: AppTextStyles.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          AppSpacing.smHGap,
          _rolePill(p.role),
        ],
      ),
    );
  }

  Widget _rolePill(String role) {
    final color = _roleColor(role);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: AppSpacing.radiusFull,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        _roleLabel(role).toUpperCase(),
        style: AppTextStyles.badge.copyWith(color: color),
      ),
    );
  }
}
