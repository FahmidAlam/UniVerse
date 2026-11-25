import 'package:universe/features/admin/widgets/admin_route_tabs.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/core/constants/app_enums.dart';
import 'package:universe/core/router/route_names.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/admin/controllers/broadcast_controller.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/shared/widgets/desktop_shell_scope.dart';
import 'package:universe/shared/widgets/u_app_bar.dart';
import 'package:universe/shared/widgets/u_button.dart';
import 'package:universe/shared/widgets/u_card.dart';
import 'package:universe/shared/widgets/u_chip.dart';
import 'package:universe/shared/widgets/u_text_field.dart';

class CampusBroadcastScreen extends StatefulWidget {
  final AuthController authController;
  final BroadcastController? controller;

  const CampusBroadcastScreen(
      {super.key, required this.authController, this.controller});

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

  static const List<NotifType> _broadcastTypes = [
    NotifType.university,
    NotifType.assignment,
    NotifType.exam,
  ];

  static const List<({String? role, String label})> _audiences = [
    (role: null, label: 'Everyone'),
    (role: 'student', label: 'Students'),
    (role: 'teacher', label: 'Teachers'),
    (role: 'admin', label: 'Admins'),
  ];

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ??
        BroadcastController(authController: widget.authController);
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
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
    final isDesktopShell = DesktopShellScope.isDesktopOf(context);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: isDesktopShell
          ? null
          : UAppBar(
              title: 'Campus Broadcast',
              showBackButton: false,
              actions: [
                IconButton(
                  tooltip: 'Sent broadcasts',
                  icon: const Icon(
                    PhosphorIconsRegular.clockCounterClockwise,
                    color: AppColors.textPrimary,
                  ),
                  onPressed: () => context.push(RouteNames.broadcastHistory),
                ),
              ],
            ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 780),
              child: SingleChildScrollView(
                padding: AppSpacing.screenPadding,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          child: AdminRouteTabs(
                              selected: '/admin/broadcast',
                              destinations: {
                                '/admin/broadcast': 'Compose Broadcast',
                                '/admin/broadcast/history': 'Sent History'
                              })),
                      if (isDesktopShell) ...[
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Campus Broadcast',
                                      style: AppTextStyles.h2),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Send real-time alerts & announcements to students and faculty',
                                    style: AppTextStyles.caption.copyWith(
                                        color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  context.push(RouteNames.broadcastHistory),
                              icon: const Icon(
                                PhosphorIconsRegular.clockCounterClockwise,
                                size: 16,
                              ),
                              label: const Text('Sent History'),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      UCard(
                        isTopLit: true,
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('BROADCAST TYPE'),
                            AppSpacing.smGap,
                            _typeChips(),
                            const Divider(
                              color: AppColors.border,
                              height: AppSpacing.xl,
                              thickness: 1,
                            ),
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
                            const Divider(
                              color: AppColors.border,
                              height: AppSpacing.xl,
                              thickness: 1,
                            ),
                            _label('ANNOUNCEMENT MESSAGE'),
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
                            AppSpacing.lgGap,
                            UButton(
                              label: 'Send broadcast',
                              icon: PhosphorIconsRegular.paperPlaneTilt,
                              isLoading: _controller.isSending,
                              onPressed: _send,
                            ),
                          ],
                        ),
                      ),
                      AppSpacing.lgGap,
                      Center(
                        child: Text(
                          'Broadcast notifications are delivered immediately via Realtime channel.',
                          style: AppTextStyles.caption,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
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
            label: _typeLabel(t),
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

  String _typeLabel(NotifType t) {
    switch (t) {
      case NotifType.university:
        return 'General announcement';
      case NotifType.assignment:
        return 'Assignment notice';
      case NotifType.exam:
        return 'Exam notice';
      default:
        return 'Notice';
    }
  }
}
