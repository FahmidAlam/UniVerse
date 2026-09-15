import 'package:flutter/material.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/models/whitelist_model.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/admin/controllers/whitelist_controller.dart';
import 'package:universe/shared/widgets/u_app_bar.dart';
import 'package:universe/shared/widgets/u_button.dart';
import 'package:universe/shared/widgets/u_card.dart';
import 'package:universe/shared/widgets/u_empty_state.dart';
import 'package:universe/shared/widgets/u_loading.dart';
import 'package:universe/shared/widgets/u_text_field.dart';

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

  final _teacherFormKey = GlobalKey<FormState>();
  final _teacherEmailCtrl = TextEditingController();
  final _teacherNameCtrl = TextEditingController();
  final _teacherCodeCtrl = TextEditingController();
  String? _teacherDepartment;
  String? _teacherDesignation;
  // Bumped after a teacher is added so the dropdowns rebuild empty.
  int _teacherFormVersion = 0;

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
    _teacherEmailCtrl.dispose();
    _teacherNameCtrl.dispose();
    _teacherCodeCtrl.dispose();
    super.dispose();
  }

  String? _emailValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email';
    return null;
  }

  String? _requiredValidator(String? v) =>
      v == null || v.trim().isEmpty ? 'Required' : null;

  Future<void> _addTeacher() async {
    if (!_teacherFormKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final email = _teacherEmailCtrl.text.trim().toLowerCase();
    final ok = await _controller.addTeacher(
      email: email,
      name: _teacherNameCtrl.text.trim(),
      teacherCode: _teacherCodeCtrl.text.trim().toUpperCase(),
      department: _teacherDepartment,
      designation: _teacherDesignation,
    );
    if (!mounted) return;

    if (ok) {
      _teacherEmailCtrl.clear();
      _teacherNameCtrl.clear();
      _teacherCodeCtrl.clear();
      setState(() {
        _teacherDepartment = null;
        _teacherDesignation = null;
        _teacherFormVersion++;
      });
      _snack('$email can now sign in as a teacher.');
    } else {
      _snack(_controller.errorMessage ?? 'Could not add the teacher.');
    }
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
                _buildTeacherForm(),
                AppSpacing.xxlGap,
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

  Widget _buildTeacherForm() {
    return Form(
      key: _teacherFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ADD A TEACHER', style: AppTextStyles.labelCaps),
          AppSpacing.smGap,
          Text(
            'A teacher can only register once their email is listed here. '
            'They then sign in with Google or email and land on the teacher '
            'dashboard.',
            style: AppTextStyles.caption,
          ),
          AppSpacing.mdGap,
          UTextField(
            controller: _teacherEmailCtrl,
            label: 'Email',
            hint: 'name@example.com',
            keyboardType: TextInputType.emailAddress,
            validator: _emailValidator,
          ),
          AppSpacing.mdGap,
          UTextField(
            controller: _teacherNameCtrl,
            label: 'Name',
            hint: 'Full name',
            validator: _requiredValidator,
          ),
          AppSpacing.mdGap,
          UTextField(
            controller: _teacherCodeCtrl,
            label: 'Teacher code',
            hint: 'e.g. JR — as shown on the routine',
            validator: _requiredValidator,
          ),
          AppSpacing.mdGap,
          _buildDropdown(
            label: 'Department',
            value: _teacherDepartment,
            items: AppConstants.departments,
            onChanged: (v) => setState(() => _teacherDepartment = v),
          ),
          AppSpacing.mdGap,
          _buildDropdown(
            label: 'Designation',
            value: _teacherDesignation,
            items: AppConstants.designations,
            onChanged: (v) => setState(() => _teacherDesignation = v),
          ),
          AppSpacing.lgGap,
          UButton(
            label: 'Add teacher',
            icon: PhosphorIconsRegular.chalkboardTeacher,
            isLoading: _controller.isSaving,
            onPressed: _addTeacher,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppTextStyles.label),
        AppSpacing.smGap,
        DropdownButtonFormField<String>(
          key: ValueKey('$label-$_teacherFormVersion'),
          initialValue: value,
          style: AppTextStyles.input,
          dropdownColor: AppColors.bgElevated,
          hint: Text('Optional', style: AppTextStyles.placeholder),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.bgElevated,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            border: OutlineInputBorder(
              borderRadius: AppSpacing.radiusMd,
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppSpacing.radiusMd,
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppSpacing.radiusMd,
              borderSide: const BorderSide(
                color: AppColors.borderFocus,
                width: AppSpacing.borderThick,
              ),
            ),
          ),
          icon: const Icon(PhosphorIconsRegular.caretDown,
              color: AppColors.textMuted, size: AppSpacing.iconMd),
          items: [
            for (final s in items) DropdownMenuItem(value: s, child: Text(s)),
          ],
          onChanged: onChanged,
        ),
      ],
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

  String _subtitle(WhitelistEntry e) => [
        e.roleLabel,
        if (e.name != null && e.name!.isNotEmpty) e.name!,
        if (e.teacherCode != null && e.teacherCode!.isNotEmpty) e.teacherCode!,
      ].join('  ·  ');

  Widget _buildList() {
    if (_controller.isLoading) {
      return const ULoading.skeleton(skeletonHeight: 64);
    }
    if (_controller.entries.isEmpty) {
      return const UEmptyState(
        icon: PhosphorIconsRegular.identificationBadge,
        title: 'No whitelist entries',
        message: 'Add a teacher or invite an admin above to pre-authorize '
            'their account.',
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
                      Text(_subtitle(e), style: AppTextStyles.caption),
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
