import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/core/router/route_names.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/features/auth/widgets/google_sign_in_button.dart';

class StudentRegisterScreen extends StatefulWidget {
  final AuthController authController;
  const StudentRegisterScreen({super.key, required this.authController});

  @override
  State<StudentRegisterScreen> createState() => _StudentRegisterScreenState();
}

class _StudentRegisterScreenState extends State<StudentRegisterScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _nameCtrl    = TextEditingController();
  final _idCtrl      = TextEditingController();
  final _batchCtrl   = TextEditingController();
  final _sectionCtrl = TextEditingController();

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

  @override
  void dispose() {
    _nameCtrl.dispose();
    _idCtrl.dispose();
    _batchCtrl.dispose();
    _sectionCtrl.dispose();
    super.dispose();
  }

  void _onAuthChange() async {
    if (!mounted) return;
    final status = widget.authController.status;

    if (status == AuthStatus.registering) {
      if (_nameCtrl.text.trim().isEmpty) {
        _showError('Please fill in all fields before registering.');
        return;
      }

      final success = await widget.authController.completeStudentRegistration(
        name: _nameCtrl.text.trim(),
        studentId: _idCtrl.text.trim(),
        batch: _batchCtrl.text.trim(),
        section: _sectionCtrl.text.trim().toUpperCase(),
      );

      if (!success && mounted) {
        _showError(
          widget.authController.errorMessage ?? 'Registration failed.',
        );
      }
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

  Future<void> _registerWithGoogle() async {
    if (!_formKey.currentState!.validate()) return;
    await widget.authController.signInWithGoogle();
  }

  void _registerWithEmail() {
    if (!_formKey.currentState!.validate()) return;
    widget.authController.storePendingStudentData(
      name: _nameCtrl.text.trim(),
      studentId: _idCtrl.text.trim(),
      batch: _batchCtrl.text.trim(),
      section: _sectionCtrl.text.trim().toUpperCase(),
    );
    context.go(RouteNames.emailSignup);
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

                    _buildLabel('Full name'),
                    AppSpacing.smGap,
                    _buildField(
                      controller: _nameCtrl,
                      hint: 'e.g. Fahmid Alam',
                      icon: PhosphorIconsRegular.user,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Name is required'
                          : null,
                    ),

                    AppSpacing.lgGap,

                    _buildLabel('Student ID'),
                    AppSpacing.smGap,
                    _buildField(
                      controller: _idCtrl,
                      hint: 'e.g. 0182320012101309',
                      icon: PhosphorIconsRegular.identificationCard,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Student ID is required'
                          : null,
                    ),

                    AppSpacing.lgGap,

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
                                validator: (v) =>
                                    v == null || v.trim().isEmpty
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
                                validator: (v) =>
                                    v == null || v.trim().isEmpty
                                        ? 'Required'
                                        : null,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.x3l),

                    SizedBox(
                      width: double.infinity,
                      height: AppSpacing.buttonHeight,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _registerWithEmail,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          disabledBackgroundColor: AppColors.bgElevated,
                          shape: const RoundedRectangleBorder(
                              borderRadius: AppSpacing.radiusMd),
                          elevation: 0,
                        ),
                        child: Text('Register with Email',
                            style: AppTextStyles.button),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    GoogleSignInButton(
                      onTap: isLoading ? null : _registerWithGoogle,
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

  Widget _buildLabel(String text) => Text(text, style: AppTextStyles.label);

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
            borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: AppSpacing.radiusMd,
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: AppSpacing.radiusMd,
            borderSide:
                const BorderSide(color: AppColors.primary, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: AppSpacing.radiusMd,
            borderSide: const BorderSide(color: AppColors.error)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: AppSpacing.radiusMd,
            borderSide:
                const BorderSide(color: AppColors.error, width: 1.5)),
      ),
    );
  }
}
