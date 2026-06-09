// ============================================================
// FILE: lib/features/admin/screens/campus_broadcast_screen.dart
// PURPOSE: Admin Campus Broadcast composer. Pick a type + audience,
// write a title/body, and send — inserting a notifications row that
// the student Alerts feed receives live via Realtime. Below the
// form, recent broadcasts can be reviewed and deleted (tap to delete).
// Owns its BroadcastController lifecycle.
// ============================================================

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:universe_v1/core/constants/app_enums.dart';
import 'package:universe_v1/core/router/route_names.dart';
import 'package:universe_v1/core/theme/app_colors.dart';
import 'package:universe_v1/core/theme/app_spacing.dart';
import 'package:universe_v1/core/theme/app_text_styles.dart';
import 'package:universe_v1/features/admin/controllers/broadcast_controller.dart';
import 'package:universe_v1/features/auth/controllers/auth_controller.dart';
import 'package:universe_v1/shared/widgets/app_bottom_nav.dart';
import 'package:universe_v1/shared/widgets/notification_tile.dart';
import 'package:universe_v1/shared/widgets/u_app_bar.dart';
import 'package:universe_v1/shared/widgets/u_button.dart';
import 'package:universe_v1/shared/widgets/u_chip.dart';
import 'package:universe_v1/shared/widgets/u_loading.dart';
import 'package:universe_v1/shared/widgets/u_text_field.dart';

class CampusBroadcastScreen extends StatefulWidget {
  final AuthController authController;

  const CampusBroadcastScreen({super.key, required this.authController});

  @override
  State<CampusBroadcastScreen> createState() => _CampusBroadcastScreenState();
}

class _CampusBroadcastScreenState extends State<CampusBroadcastScreen> {
  late final BroadcastController _controller;
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _batchCtrl = TextEditingController();
  final _sectionCtrl = TextEditingController();

  // Admin-only broadcast types. Class cancellation, room change and test
  // reminder belong to teachers (raised from their own flows), so they're
  // intentionally excluded here.
  static const List<NotifType> _broadcastTypes = [
    NotifType.university,
    NotifType.assignment,
    NotifType.exam,
  ];

  // null == Everyone
  static const List<({String? role, String label})> _audiences = [
    (role: null, label: 'Everyone'),
    (role: 'student', label: 'Students'),
    (role: 'teacher', label: 'Teachers'),
    (role: 'admin', label: 'Admins'),
  ];

  @override
  void initState() {
    super.initState();
    _controller = BroadcastController(authController: widget.authController);
    _controller.loadRecent();
  }

  @override
  void dispose() {
    _controller.dispose();
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _batchCtrl.dispose();
    _sectionCtrl.dispose();
    super.dispose();
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final ok = await _controller.submit(
      title: _titleCtrl.text,
      body: _bodyCtrl.text,
      targetBatch: _batchCtrl.text,
      targetSection: _sectionCtrl.text,
    );
    if (!mounted) return;

    if (ok) {
      _titleCtrl.clear();
      _bodyCtrl.clear();
      _snack('Broadcast sent.');
    } else {
      _snack(_controller.errorMessage ?? 'Failed to send broadcast.');
    }
  }

  Future<void> _confirmDelete(String id, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: AppSpacing.radiusLg),
        title: Text('Delete broadcast?', style: AppTextStyles.h3),
        content: Text(
          '"$title" will be removed for everyone.',
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
      await _controller.deleteBroadcast(id);
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
      appBar: const UAppBar(title: 'Campus Broadcast', showBackButton: false),
      bottomNavigationBar: AppBottomNav(
        role: widget.authController.role,
        currentRoute: RouteNames.campusBroadcast,
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return SingleChildScrollView(
            padding: AppSpacing.screenPadding,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('TYPE'),
                  AppSpacing.smGap,
                  _typeChips(),
                  AppSpacing.sectionGap,
                  _label('AUDIENCE'),
                  AppSpacing.smGap,
                  _audienceChips(),
                  AppSpacing.smGap,
                  Text(
                    'Batch & section are optional and narrow a Students broadcast further.',
                    style: AppTextStyles.caption,
                  ),
                  AppSpacing.mdGap,
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          controller: _batchCtrl,
                          label: 'Batch',
                          hint: 'e.g. 62',
                        ),
                      ),
                      AppSpacing.smHGap,
                      Expanded(
                        child: _field(
                          controller: _sectionCtrl,
                          label: 'Section',
                          hint: 'e.g. G',
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.sectionGap,
                  _label('MESSAGE'),
                  AppSpacing.smGap,
                  _field(
                    controller: _titleCtrl,
                    label: 'Title',
                    hint: 'Short headline',
                    validator: _required,
                  ),
                  AppSpacing.mdGap,
                  _field(
                    controller: _bodyCtrl,
                    label: 'Body',
                    hint: 'What do you want to announce?',
                    validator: _required,
                    maxLines: 4,
                  ),
                  AppSpacing.sectionGap,
                  UButton(
                    label: 'Send broadcast',
                    icon: PhosphorIconsRegular.paperPlaneTilt,
                    isLoading: _controller.isSending,
                    onPressed: _send,
                  ),
                  AppSpacing.xxlGap,
                  _label('RECENT BROADCASTS'),
                  AppSpacing.smGap,
                  _recentList(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return UTextField(
      controller: controller,
      label: label,
      hint: hint,
      validator: validator,
      maxLines: maxLines,
    );
  }

  Widget _label(String text) => Text(text, style: AppTextStyles.labelCaps);

  Widget _typeChips() {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final t in _broadcastTypes)
          UChip(
            label: t.label,
            isActive: _controller.type == t,
            onTap: () => _controller.setType(t),
          ),
      ],
    );
  }

  Widget _audienceChips() {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final a in _audiences)
          UChip(
            label: a.label,
            isActive: _controller.targetRole == a.role,
            onTap: () => _controller.setTargetRole(a.role),
          ),
      ],
    );
  }

  Widget _recentList() {
    if (_controller.isLoadingRecent && _controller.recent.isEmpty) {
      return const ULoading.skeleton(skeletonHeight: 72);
    }
    if (_controller.recent.isEmpty) {
      return Text(
        'No broadcasts yet.',
        style: AppTextStyles.bodySm,
      );
    }
    return ClipRRect(
      borderRadius: AppSpacing.radiusLg,
      child: Column(
        children: [
          for (final n in _controller.recent)
            NotificationTile(
              title: n.title,
              body: n.body,
              type: n.type,
              time: n.time,
              onTap: () => _confirmDelete(n.id, n.title),
            ),
        ],
      ),
    );
  }
}