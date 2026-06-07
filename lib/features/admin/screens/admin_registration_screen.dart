// ============================================================
// FILE: lib/features/admin/screens/admin_registration_screen.dart
// PURPOSE: Provision new ADMINS by email invite. Account creation needs
// the service-role key, so this calls the `invite-admin` Edge Function
// (via WhitelistController.invite): it whitelists the email as admin and
// emails an invite link that lands on the set-password screen. The new
// admin then signs in with the password they set. Lists existing
// whitelist entries with remove. Owns its WhitelistController lifecycle.
//
// NOTE: this is a top-level "secondary" screen (back button, no bottom
// nav) reached from the Admin Dashboard card — same pattern as Resources.
// ============================================================

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:universe_v1/core/models/whitelist_model.dart';
import 'package:universe_v1/core/theme/app_colors.dart';
import 'package:universe_v1/core/theme/app_spacing.dart';
import 'package:universe_v1/core/theme/app_text_styles.dart';
import 'package:universe_v1/features/admin/controllers/whitelist_controller.dart';
import 'package:universe_v1/shared/widgets/u_app_bar.dart';
import 'package:universe_v1/shared/widgets/u_button.dart';
import 'package:universe_v1/shared/widgets/u_card.dart';
import 'package:universe_v1/shared/widgets/u_empty_state.dart';
import 'package:universe_v1/shared/widgets/u_loading.dart';
import 'package:universe_v1/shared/widgets/u_text_field.dart';

class AdminRegistrationScreen extends StatefulWidget {
  const AdminRegistrationScreen({super.key});

  @override
  State<AdminRegistrationScreen> createState() =>
      _AdminRegistrationScreenState();
}

class _AdminRegistrationScreenState extends State<AdminRegistrationScreen> {
  late final WhitelistController _controller;
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = WhitelistController();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  String? _emailValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email';
    return null;
  }

  Future<void> _invite() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final email = _emailCtrl.text.trim().toLowerCase();
    final name = _nameCtrl.text.trim();
    final ok = await _controller.invite(
      email: email,
      name: name.isEmpty ? null : name,
    );
    if (!mounted) return;

    if (ok) {
      _emailCtrl.clear();
      _nameCtrl.clear();
      _snack('Invite sent to $email.');
    } else {
      _snack(_controller.errorMessage ?? 'Could not send invite.');
    }
  }

  Future<void> _confirmRemove(WhitelistEntry e) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: AppSpacing.radiusLg),
        title: Text('Remove from whitelist?', style: AppTextStyles.h3),
        content: Text(
          '${e.email} will no longer be pre-authorized. (This does not '
          'delete an account they already created.)',
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
            child: Text('Remove', style: AppTextStyles.danger),
          ),
        ],
      ),
    );
    if (confirmed == true) await _controller.remove(e.email);
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
      appBar: const UAppBar(title: 'Admin Registration'),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return SingleChildScrollView(
            padding: AppSpacing.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildForm(),
                AppSpacing.xxlGap,
                Text('WHITELISTED', style: AppTextStyles.labelCaps),
                AppSpacing.smGap,
                _buildList(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('INVITE A NEW ADMIN', style: AppTextStyles.labelCaps),
          AppSpacing.smGap,
          Text(
            'They get an email to set their own password, then sign in with '
            'this email. Only admins can invite admins.',
            style: AppTextStyles.caption,
          ),
          AppSpacing.mdGap,
          UTextField(
            controller: _emailCtrl,
            label: 'Email',
            hint: 'name@example.com',
            keyboardType: TextInputType.emailAddress,
            validator: _emailValidator,
          ),
          AppSpacing.mdGap,
          UTextField(
            controller: _nameCtrl,
            label: 'Name',
            hint: 'Full name (optional)',
          ),
          AppSpacing.lgGap,
          UButton(
            label: 'Send admin invite',
            icon: PhosphorIconsRegular.paperPlaneTilt,
            isLoading: _controller.isSaving,
            onPressed: _invite,
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_controller.isLoading) {
      return const ULoading.skeleton(skeletonHeight: 64);
    }
    if (_controller.entries.isEmpty) {
      return const UEmptyState(
        icon: PhosphorIconsRegular.identificationBadge,
        title: 'No whitelist entries',
        message: 'Invite an admin above to pre-authorize their account.',
      );
    }
    return Column(
      children: [
        for (final e in _controller.entries) ...[
          UCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.email,
                        style: AppTextStyles.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      AppSpacing.xsGap,
                      Text(
                        e.name == null
                            ? e.roleLabel
                            : '${e.roleLabel}  ·  ${e.name}',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(PhosphorIconsRegular.trash,
                      color: AppColors.error, size: AppSpacing.iconMd),
                  onPressed: () => _confirmRemove(e),
                ),
              ],
            ),
          ),
          AppSpacing.cardGap,
        ],
      ],
    );
  }
}
