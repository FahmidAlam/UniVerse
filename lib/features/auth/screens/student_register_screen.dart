// ============================================================
// FILE: lib/features/auth/screens/student_register_screen.dart
// PURPOSE: Form for new students.
// Fields: Full name, Student ID, Batch, Section (two cols),
// Semester (dropdown). Then "Register with Google" which
// triggers OAuth + profile creation in one flow.
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:universe_v1/core/constants/app_constants.dart';
import 'package:universe_v1/core/router/route_names.dart';
import 'package:universe_v1/core/app_colors.dart';
import 'package:universe_v1/core/app_spacing.dart';
import 'package:universe_v1/core/app_text_styles.dart';
import 'package:universe_v1/features/auth/controllers/auth_controller.dart';
import 'package:universe_v1/features/auth/widgets/google_sign_in_button.dart';

class StudentRegisterScreen extends StatefulWidget {
  final AuthController authController;

  const StudentRegisterScreen({super.key, required this.authController});

  @override
  State<StudentRegisterScreen> createState() => _StudentRegisterScreenState();
}

class _StudentRegisterScreenState extends State<StudentRegisterScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _nameCtrl   = TextEditingController();
  final _idCtrl     = TextEditingController();
  final _batchCtrl  = TextEditingController();
  final _sectionCtrl = TextEditingController();
  int? _selectedSemester;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _idCtrl.dispose();
    _batchCtrl.dispose();
    _sectionCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSemester == null) {
      _showError('Please select your semester.');
      return;
    }

    // Step 1: Trigger Google OAuth (session created by Supabase)
    await widget.authController.signInWithGoogle();

    // Step 2: After OAuth callback fires (handled by GoRouter →
    // authController.handleOAuthCallback), we update the profile.
    // But we still need the form data — so we listen to auth
    // state and complete registration when session is ready.
    // 
    // The flow: Google sign-in → Supabase session → 
    // handleOAuthCallback → if success, completeStudentRegistration
    // We handle this by watching authController in _onAuthChange.
  }

  void _onAuthChange() async {
    if (!mounted) return;
    final status = widget.authController.status;

    if (status == AuthStatus.authenticated) {
      // OAuth done, now fill in the student-specific profile data
      final success = await widget.authController.completeStudentRegistration(
        name: _nameCtrl.text.trim(),
        studentId: _idCtrl.text.trim(),
        batch: _batchCtrl.text.trim(),
        section: _sectionCtrl.text.trim().toUpperCase(),
        semester: _selectedSemester!,
      );

      if (!success && mounted) {
        _showError(
          widget.authController.errorMessage ?? 'Registration failed.',
        );
      }
      // GoRouter redirect handles navigation to dashboard
    } else if (status == AuthStatus.notWhitelisted) {
      if (mounted) context.go(RouteNames.notWhitelisted);
    } else if (status == AuthStatus.error) {
      if (mounted) {
        _showError(
          widget.authController.errorMessage ?? 'Something went wrong.',
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    widget.authController.addListener(_onAuthChange);
  }

  @override
  void deactivate() {
    widget.authController.removeListener(_onAuthChange);
    super.deactivate();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: AppTextStyles.bodySm.copyWith(color: AppColors.textPrimary)),
        backgroundColor: AppColors.bgElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.radiusMd,
          side: const BorderSide(color: AppColors.error),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.authController,
      builder: (context, _) {
        final isLoading = widget.authController.isLoading;

        return Scaffold(
          backgroundColor: AppColors.bgPrimary,
          appBar: AppBar(
            backgroundColor: AppColors.bgPrimary,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(PhosphorIconsRegular.arrowLeft),
              onPressed: () => context.go(RouteNames.roleSelection),
            ),
            title: Text('Create account', style: AppTextStyles.h2),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: AppSpacing.screenPaddingScrollable,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Student role badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.roleStudent.withValues(alpha: 0.12),
                        borderRadius: AppSpacing.radiusFull,
                        border: Border.all(
                          color: AppColors.roleStudent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            PhosphorIconsRegular.graduationCap,
                            color: AppColors.roleStudent,
                            size: AppSpacing.iconSm,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            'Student',
                            style: AppTextStyles.chip.copyWith(
                              color: AppColors.roleStudent,
                            ),
                          ),
                        ],
                      ),
                    ),

                    AppSpacing.lgGap,

                    // ── Full name ────────────────────────────
                    _buildLabel('Full name'),
                    AppSpacing.smGap,
                    _buildField(
                      controller: _nameCtrl,
                      hint: 'e.g. Fahmid Alam',
                      icon: PhosphorIconsRegular.user,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Name is required' : null,
                    ),

                    AppSpacing.lgGap,

                    // ── Student ID ───────────────────────────
                    _buildLabel('Student ID'),
                    AppSpacing.smGap,
                    _buildField(
                      controller: _idCtrl,
                      hint: 'e.g. 0182320012101309',
                      icon: PhosphorIconsRegular.identificationCard,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Student ID is required' : null,
                    ),

                    AppSpacing.lgGap,

                    // ── Batch & Section (side by side) ────────
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Batch'),
                              AppSpacing.smGap,
                              _buildField(
                                controller: _batchCtrl,
                                hint: 'e.g. 62',
                                icon: PhosphorIconsRegular.users,
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'Required'
                                    : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Section'),
                              AppSpacing.smGap,
                              _buildField(
                                controller: _sectionCtrl,
                                hint: 'e.g. G',
                                icon: PhosphorIconsRegular.tag,
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'Required'
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    AppSpacing.lgGap,

                    // ── Semester dropdown ─────────────────────
                    _buildLabel('Semester'),
                    AppSpacing.smGap,
                    _buildSemesterDropdown(),

                    const SizedBox(height: AppSpacing.x3l),

                    // ── Register button ───────────────────────
                    GoogleSignInButton(
                      onTap: isLoading ? null : _register,
                      isLoading: isLoading,
                      label: 'Register with Google',
                    ),

                    AppSpacing.lgGap,

                    Center(
                      child: Text(
                        'Your academic info must match your university records.',
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
    );
  }

  Widget _buildLabel(String text) {
    return Text(text, style: AppTextStyles.label);
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: AppTextStyles.input,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.placeholder,
        prefixIcon: Icon(icon, size: AppSpacing.iconMd),
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
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppSpacing.radiusMd,
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppSpacing.radiusMd,
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildSemesterDropdown() {
    return DropdownButtonFormField<int>(
      initialValue: _selectedSemester,
      style: AppTextStyles.input,
      dropdownColor: AppColors.bgElevated,
      hint: Text('Select semester', style: AppTextStyles.placeholder),
      decoration: InputDecoration(
        prefixIcon: const Icon(
          PhosphorIconsRegular.bookOpen,
          size: AppSpacing.iconMd,
        ),
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
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      icon: const Icon(
        PhosphorIconsRegular.caretDown,
        color: AppColors.textMuted,
        size: AppSpacing.iconMd,
      ),
      items: AppConstants.semesters
          .map((s) => DropdownMenuItem(
                value: s,
                child: Text('Semester $s'),
              ))
          .toList(),
      onChanged: (v) => setState(() => _selectedSemester = v),
    );
  }
}