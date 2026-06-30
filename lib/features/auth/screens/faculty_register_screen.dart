import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/router/route_names.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/features/auth/widgets/google_sign_in_button.dart';

class FacultyRegisterScreen extends StatefulWidget {
  final AuthController authController;
  const FacultyRegisterScreen({super.key, required this.authController});

  @override
  State<FacultyRegisterScreen> createState() => _FacultyRegisterScreenState();
}

class _FacultyRegisterScreenState extends State<FacultyRegisterScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  String? _selectedDepartment;
  String? _selectedDesignation;

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
    _codeCtrl.dispose();
    super.dispose();
  }

  void _onAuthChange() async {
    if (!mounted) return;
    final status = widget.authController.status;

    if (status == AuthStatus.registering) {
      if (_nameCtrl.text.trim().isEmpty ||
          _selectedDepartment == null ||
          _selectedDesignation == null) {
        _showError('Please fill in all fields before registering.');
        return;
      }

      final success = await widget.authController.completeFacultyRegistration(
        name: _nameCtrl.text.trim(),
        teacherCode: _codeCtrl.text.trim().toUpperCase(),
        department: _selectedDepartment!,
        designation: _selectedDesignation!,
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
    if (_selectedDepartment == null) {
      _showError('Please select your department.');
      return;
    }
    if (_selectedDesignation == null) {
      _showError('Please select your designation.');
      return;
    }
    await widget.authController.signInWithGoogle();
  }

  void _registerWithEmail() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDepartment == null) {
      _showError('Please select your department.');
      return;
    }
    if (_selectedDesignation == null) {
      _showError('Please select your designation.');
      return;
    }
    widget.authController.storePendingFacultyData(
      name: _nameCtrl.text.trim(),
      teacherCode: _codeCtrl.text.trim().toUpperCase(),
      department: _selectedDepartment!,
      designation: _selectedDesignation!,
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
                        color: AppColors.roleTeacher.withValues(alpha: 0.12),
                        borderRadius: AppSpacing.radiusFull,
                        border: Border.all(
                          color: AppColors.roleTeacher.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            PhosphorIconsRegular.chalkboardTeacher,
                            color: AppColors.roleTeacher,
                            size: AppSpacing.iconSm,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            'Faculty',
                            style: AppTextStyles.chip.copyWith(
                              color: AppColors.roleTeacher,
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
                      hint: 'e.g. Dr. Aminul Islam',
                      icon: PhosphorIconsRegular.user,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Name is required'
                          : null,
                    ),

                    AppSpacing.lgGap,

                    _buildLabel('Teacher Code'),
                    AppSpacing.smGap,
                    _buildField(
                      controller: _codeCtrl,
                      hint: 'e.g. JR — as shown on the routine',
                      icon: PhosphorIconsRegular.identificationBadge,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Teacher code is required'
                          : null,
                    ),
                    AppSpacing.xsGap,
                    Text(
                      'Use the code that appears beside your name on the '
                      'published routine — it links you to your classes.',
                      style: AppTextStyles.caption,
                    ),

                    AppSpacing.lgGap,

                    _buildLabel('Department'),
                    AppSpacing.smGap,
                    _buildDropdown(
                      hint: 'Select department',
                      icon: PhosphorIconsRegular.buildings,
                      value: _selectedDepartment,
                      items: AppConstants.departments,
                      onChanged: (v) =>
                          setState(() => _selectedDepartment = v),
                    ),

                    AppSpacing.lgGap,

                    _buildLabel('Designation'),
                    AppSpacing.smGap,
                    _buildDropdown(
                      hint: 'Select designation',
                      icon: PhosphorIconsRegular.medal,
                      value: _selectedDesignation,
                      items: AppConstants.designations,
                      onChanged: (v) =>
                          setState(() => _selectedDesignation = v),
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
                        'Your information must match university HR records.',
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
  }) {
    return TextFormField(
      controller: controller,
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

  Widget _buildDropdown({
    required String hint,
    required IconData icon,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      style: AppTextStyles.input,
      dropdownColor: AppColors.bgElevated,
      hint: Text(hint, style: AppTextStyles.placeholder),
      decoration: InputDecoration(
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
      ),
      icon: const Icon(PhosphorIconsRegular.caretDown,
          color: AppColors.textMuted, size: AppSpacing.iconMd),
      items: items
          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
          .toList(),
      onChanged: onChanged,
    );
  }
}
