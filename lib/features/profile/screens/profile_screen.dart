import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/models/profile_model.dart';
import 'package:universe/core/models/timetable_config_model.dart';
import 'package:universe/core/router/route_names.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_motion.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/features/auth/screens/admin_web_notice_screen.dart';
import 'package:universe/features/profile/controllers/profile_controller.dart';
import 'package:universe/features/profile/services/teacher_r8_preference_service.dart';
import 'package:universe/shared/widgets/desktop_shell_scope.dart';
import 'package:universe/shared/widgets/info_row.dart';
import 'package:universe/shared/widgets/u_adaptive_overlay.dart';
import 'package:universe/shared/widgets/u_app_bar.dart';
import 'package:universe/shared/widgets/u_avatar.dart';
import 'package:universe/shared/widgets/u_button.dart';
import 'package:universe/shared/widgets/u_card.dart';
import 'package:universe/shared/widgets/u_chip.dart';
import 'package:universe/shared/widgets/u_loading.dart';
import 'package:universe/shared/widgets/u_text_field.dart';

class ProfileScreen extends StatefulWidget {
  final AuthController authController;
  final TeacherR8PreferenceService? configService;

  const ProfileScreen({
    super.key,
    required this.authController,
    this.configService,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late final ProfileController _controller;
  late final TeacherR8PreferenceService _configService;
  final TextEditingController _nameController = TextEditingController();
  int? _localAvatarIndex;
  bool _isSigningOut = false;
  bool _isEditingName = false;
  bool _isSavingName = false;

  // Teacher R8 Preferred Days state & catalog faculty linkage
  final Set<String> _preferredTeachingDays = {};
  TimetableFaculty? _matchedFaculty;
  bool _savingR8 = false;
  String? _r8StatusMessage;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  static const _presets = [
    _AvatarPreset(
      color: AppColors.primary,
      icon: PhosphorIconsRegular.graduationCap,
      label: 'Graduate',
    ),
    _AvatarPreset(
      color: AppColors.info,
      icon: PhosphorIconsRegular.books,
      label: 'Scholar',
    ),
    _AvatarPreset(
      color: AppColors.success,
      icon: PhosphorIconsRegular.atom,
      label: 'Science',
    ),
    _AvatarPreset(
      color: AppColors.warning,
      icon: PhosphorIconsRegular.flask,
      label: 'Lab',
    ),
    _AvatarPreset(
      color: AppColors.error,
      icon: PhosphorIconsRegular.lightbulb,
      label: 'Idea',
    ),
    _AvatarPreset(
      color: AppColors.primary,
      icon: PhosphorIconsRegular.globe,
      label: 'Global',
    ),
    _AvatarPreset(
      color: AppColors.info,
      icon: PhosphorIconsRegular.brain,
      label: 'Think',
    ),
    _AvatarPreset(
      color: AppColors.success,
      icon: PhosphorIconsRegular.pencilSimple,
      label: 'Create',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _configService = widget.configService ?? TeacherR8PreferenceService();
    _controller = ProfileController(authController: widget.authController);
    _controller.load();
    _loadLocalAvatar();
    _loadRoleOperationalData();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _nameController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadRoleOperationalData() async {
    final role = widget.authController.profile?['role'] as String?;
    if (role == AppConstants.roleTeacher) {
      await _loadTeacherR8Preferences();
    }
  }

  Future<void> _loadTeacherR8Preferences() async {
    final profileMap = widget.authController.profile;
    final teacherCode =
        (profileMap?['teacher_code'] as String?)?.trim().toUpperCase();
    final userId = profileMap?['id'] as String?;

    if (mounted) {
      setState(() {
        _r8StatusMessage = null;
      });
    }

    try {
      final facultyList = await _configService.fetchFaculty();
      TimetableFaculty? matched;
      if (teacherCode != null && teacherCode.isNotEmpty) {
        for (final f in facultyList) {
          if (f.acronym.trim().toUpperCase() == teacherCode) {
            matched = f;
            break;
          }
        }
      }

      if (matched != null) {
        final daysFromMatrix = <String>{};
        for (final entry in matched.slotMatrix.entries) {
          if (entry.value == 'preferred_r8') {
            final dayPrefix = entry.key.split(':').first;
            for (final shortDay in AppConstants.weekDaysShort) {
              if (dayPrefix == shortDay ||
                  dayPrefix.startsWith(shortDay) ||
                  shortDay.startsWith(dayPrefix)) {
                daysFromMatrix.add(shortDay);
                break;
              }
            }
          }
        }
        if (!mounted) return;
        setState(() {
          _matchedFaculty = matched;
          _preferredTeachingDays
            ..clear()
            ..addAll(daysFromMatrix);
        });
        return;
      }

      // Fallback to device-local draft when faculty code is not linked in catalog
      List<String>? savedLocal;
      if (userId != null) {
        try {
          savedLocal = (await SharedPreferences.getInstance())
              .getStringList('preferred_teaching_days_$userId');
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _matchedFaculty = null;
        _preferredTeachingDays.clear();
        if (savedLocal != null) {
          _preferredTeachingDays.addAll(
            savedLocal.where(AppConstants.weekDaysShort.contains),
          );
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _r8StatusMessage = 'Could not load faculty scheduling preferences.';
      });
    }
  }

  Future<void> _togglePreferredTeachingDay(Profile p, String day) async {
    if (_savingR8) return;
    final nextDays = Set<String>.from(_preferredTeachingDays);
    if (nextDays.contains(day)) {
      nextDays.remove(day);
    } else {
      nextDays.add(day);
    }

    setState(() {
      _preferredTeachingDays
        ..clear()
        ..addAll(nextDays);
      _savingR8 = true;
      _r8StatusMessage = null;
    });

    final matched = _matchedFaculty;
    if (matched != null) {
      final updatedMatrix = Map<String, String>.from(matched.slotMatrix);
      // Remove existing R8 entries for deselected days while preserving R4/R5/adjunct rules.
      updatedMatrix.removeWhere(
        (k, v) => v == 'preferred_r8' && !nextDays.contains(k.split(':').first),
      );
      for (final d in nextDays) {
        for (var slotIdx = 0; slotIdx < 6; slotIdx++) {
          final key = '$d:$slotIdx';
          if (!updatedMatrix.containsKey(key) ||
              updatedMatrix[key] == 'available') {
            updatedMatrix[key] = 'preferred_r8';
          }
        }
      }
      try {
        await _configService.updateFacultySlotMatrix(
          matched.id,
          updatedMatrix,
        );
        if (!mounted) return;
        setState(() {
          _matchedFaculty = matched.copyWith(slotMatrix: updatedMatrix);
          _savingR8 = false;
          _r8StatusMessage =
              'Saved to catalog preference matrix for ${matched.acronym}.';
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _savingR8 = false;
          _r8StatusMessage = 'Could not save R8 preferences.';
        });
      }
    } else {
      var savedLocally = false;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(
          'preferred_teaching_days_${p.id}',
          nextDays.toList(),
        );
        savedLocally = true;
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _savingR8 = false;
        _r8StatusMessage = savedLocally
            ? 'Saved locally on this device.'
            : 'Updated for this session.';
      });
    }
  }

  Future<void> _loadLocalAvatar() async {
    final userId = widget.authController.profile?['id'] as String?;
    if (userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final idx = prefs.getInt('avatar_preset_$userId');
      if (mounted) setState(() => _localAvatarIndex = idx);
    } catch (_) {}
  }

  Future<void> _saveLocalAvatar(int? index) async {
    final userId = widget.authController.profile?['id'] as String?;
    if (userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (index == null) {
        await prefs.remove('avatar_preset_$userId');
      } else {
        await prefs.setInt('avatar_preset_$userId', index);
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _localAvatarIndex = index);
      _triggerAvatarPulse();
    }
  }

  void _triggerAvatarPulse() {
    if (AppMotion.reduced(context)) return;
    _pulseController.forward().then((_) {
      if (mounted) _pulseController.reverse();
    });
  }

  Future<void> _saveDisplayName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Display name cannot be empty.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() => _isSavingName = true);
    final ok = await _controller.updateDisplayName(newName);
    if (mounted) {
      setState(() {
        _isSavingName = false;
        if (ok) _isEditingName = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Profile name updated.'
                : (_controller.errorMessage ?? 'Could not update name.'),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.radiusLg,
          side: const BorderSide(color: AppColors.border),
        ),
        title: Text('Sign out?', style: AppTextStyles.h3),
        content: Text(
          'You\'ll need to sign in again to access your account.',
          style: AppTextStyles.bodySm,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Sign out', style: AppTextStyles.danger),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isSigningOut = true);
      try {
        await _controller.signOut();
      } finally {
        if (mounted) setState(() => _isSigningOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktopShell = DesktopShellScope.isDesktopOf(context);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: isDesktopShell
          ? null
          : const UAppBar(title: 'Profile', showBackButton: false),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final p = _controller.profile;
          if (p == null) {
            return const Center(child: ULoading.spinner());
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 860;
              final maxContentWidth = isWide ? 1080.0 : 640.0;

              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxContentWidth),
                  child: SingleChildScrollView(
                    padding: AppSpacing.screenPaddingScrollable,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (isDesktopShell) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Account & Operational Studio',
                                      style: AppTextStyles.h2,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Manage identity, security parameters, and role-governed scheduling preferences.',
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySoft,
                                  borderRadius: AppSpacing.radiusFull,
                                  border: Border.all(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Text(
                                  p.roleLabel.toUpperCase(),
                                  style: AppTextStyles.labelCaps.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          AppSpacing.sectionGap,
                        ],
                        if (isWide)
                          _buildWideTwoColumnStudio(p)
                        else
                          _buildCompactMobileStudio(p),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // PHASE C: 2-Column Desktop Command Studio (42% Left Rail / 58% Right Operational Studio)
  Widget _buildWideTwoColumnStudio(Profile p) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Rail (42%): Identity & Security
        Expanded(
          flex: 42,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildIdentityCard(p),
              AppSpacing.sectionGap,
              _buildSecurityAndPreferencesCard(p),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.xl),
        // Right Studio (58%): Role Operational Controls & System Info
        Expanded(
          flex: 58,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildRoleOperationalStudioCard(p),
              AppSpacing.sectionGap,
              _buildAboutAndCreditsCard(),
            ],
          ),
        ),
      ],
    );
  }

  // PHASE C: Compact Mobile Single-Axis Studio
  Widget _buildCompactMobileStudio(Profile p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildIdentityCard(p),
        AppSpacing.sectionGap,
        _buildRoleOperationalStudioCard(p),
        AppSpacing.sectionGap,
        _buildSecurityAndPreferencesCard(p),
        AppSpacing.sectionGap,
        _buildAboutAndCreditsCard(),
      ],
    );
  }

  // ==========================================
  // CARD 1: IDENTITY & PROFILE DETAILS
  // ==========================================
  Widget _buildIdentityCard(Profile p) {
    return UCard(
      isTopLit: true,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar with pulse animation and edit pencil
          ScaleTransition(
            scale: _pulseAnimation,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomRight,
              children: [
                _localAvatarIndex != null
                    ? _buildPresetCircle(
                        _presets[_localAvatarIndex!],
                        AppSpacing.avatarXl,
                      )
                    : UAvatar(
                        name: p.displayName,
                        imageUrl: p.avatarUrl,
                        size: AppSpacing.avatarXl,
                      ),
                Positioned(
                  bottom: -6,
                  right: -6,
                  child: Semantics(
                    button: true,
                    label: 'Change avatar preset',
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _showAvatarPicker(p),
                        customBorder: const CircleBorder(),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppColors.bgCard, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.35),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: const Icon(
                              PhosphorIconsRegular.pencilSimple,
                              size: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.mdGap,

          // Full Name with inline edit
          if (_isEditingName)
            Row(
              children: [
                Expanded(
                  child: UTextField(
                    label: 'Display Name',
                    hint: 'Enter your full name',
                    controller: _nameController,
                    textInputAction: TextInputAction.done,
                    onSubmitted: _isSavingName ? null : _saveDisplayName,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton(
                  tooltip: 'Save display name',
                  icon: _isSavingName
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          PhosphorIconsRegular.check,
                          color: AppColors.success,
                        ),
                  onPressed: _isSavingName ? null : _saveDisplayName,
                ),
                IconButton(
                  tooltip: 'Cancel editing',
                  icon: const Icon(
                    PhosphorIconsRegular.x,
                    color: AppColors.textMuted,
                  ),
                  onPressed: () => setState(() => _isEditingName = false),
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    p.displayName,
                    style: AppTextStyles.h2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(
                    PhosphorIconsRegular.pencilSimple,
                    size: 15,
                    color: AppColors.textMuted,
                  ),
                  tooltip: 'Edit name',
                  constraints:
                      const BoxConstraints(minWidth: 40, minHeight: 40),
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    _nameController.text = p.displayName;
                    setState(() => _isEditingName = true);
                  },
                ),
              ],
            ),
          AppSpacing.xsGap,

          // Role and Department pills
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            alignment: WrapAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: AppSpacing.radiusFull,
                ),
                child: Text(
                  p.roleLabel.toUpperCase(),
                  style: AppTextStyles.badge.copyWith(color: AppColors.primary),
                ),
              ),
              if (p.department != null && p.department!.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.bgElevated,
                    borderRadius: AppSpacing.radiusFull,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    p.department!,
                    style: AppTextStyles.badge.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
          AppSpacing.mdGap,
          const Divider(height: 1, color: AppColors.border),
          AppSpacing.mdGap,

          // Account Details Rows
          InfoRow(
            label: 'Email',
            value: p.email,
            icon: PhosphorIconsRegular.envelopeSimple,
          ),
          if (p.identifier != null)
            InfoRow(
              label: p.identifierLabel,
              value: p.identifier!,
              icon: PhosphorIconsRegular.identificationCard,
            ),
          if (p.isTeacher && p.designation != null)
            InfoRow(
              label: 'Designation',
              value: p.designation!,
              icon: PhosphorIconsRegular.briefcase,
            ),
          InfoRow(
            label: 'Authentication',
            value: 'Authenticated Session · ${p.roleLabel}',
            icon: PhosphorIconsRegular.shieldCheck,
            showDivider: false,
          ),
        ],
      ),
    );
  }

  // ==========================================
  // CARD 2: ROLE-SPECIFIC OPERATIONAL STUDIO
  // ==========================================
  Widget _buildRoleOperationalStudioCard(Profile p) {
    if (p.isTeacher) {
      return _buildTeacherOperationalStudio(p);
    } else if (p.isAdmin) {
      return _buildAdminOperationalStudio(p);
    } else {
      return _buildStudentOperationalStudio(p);
    }
  }

  // Teacher Operational Studio
  Widget _buildTeacherOperationalStudio(Profile p) {
    final days = AppConstants.weekDaysShort;
    final matched = _matchedFaculty;
    final workDaysCount =
        matched != null ? (7 - matched.offDays.length).clamp(0, 7) : null;

    return UCard(
      isTopLit: true,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'FACULTY SCHEDULING STUDIO',
                  style: AppTextStyles.labelCaps.copyWith(
                    color: AppColors.roleTeacher,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.infoSoft,
                  borderRadius: AppSpacing.radiusSm,
                  border: Border.all(
                    color: AppColors.info.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      PhosphorIconsRegular.chalkboardTeacher,
                      size: 13,
                      color: AppColors.info,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Code: ${p.teacherCode ?? "UNASSIGNED"}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.info,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          AppSpacing.mdGap,

          // R6 / R7 7-Day Faculty Load Policy Card
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.bgSubtle,
              borderRadius: AppSpacing.radiusMd,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      PhosphorIconsRegular.chartBar,
                      size: 15,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'R6 / R7 · Faculty Weekly Teaching Math',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  matched != null
                      ? 'Active Catalog Allocation: $workDaysCount working days + ${matched.offDays.length} off-days (${matched.offDays.isEmpty ? "none marked" : matched.offDays.join(", ")}) = 7-day cycle.'
                      : 'Operating across the institutional 7-day academic week (Sunday–Saturday). Permanent faculty work 4–5 days and receive 2–3 days off (4+3=7 or 5+2=7).',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.lgGap,

          // R8 Preferred Days Multi-Select
          Row(
            children: [
              Expanded(
                child: Text(
                  'R8 · PREFERRED TEACHING DAYS (7-DAY CYCLE)',
                  style: AppTextStyles.labelCaps,
                ),
              ),
              if (_savingR8)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final day in days)
                UChip(
                  label: day,
                  isActive: _preferredTeachingDays.contains(day),
                  onTap: () => _togglePreferredTeachingDay(p, day),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _r8StatusMessage ??
                (matched != null
                    ? 'Changes update your R8 preferred slots (${matched.acronym}) in the routine configuration matrix.'
                    : 'Faculty code "${p.teacherCode ?? "UNASSIGNED"}" is not linked to a timetable catalog record yet; selections save on this device.'),
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textMuted,
              fontSize: 11,
            ),
          ),
          AppSpacing.lgGap,

          // Direct Navigation Actions
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 340) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    UButton(
                      label: 'View Teaching Routine',
                      icon: PhosphorIconsRegular.calendar,
                      variant: UButtonVariant.secondary,
                      onPressed: () => context.go(RouteNames.teacherRoutine),
                    ),
                    AppSpacing.smGap,
                    UButton(
                      label: 'Manage Classes',
                      icon: PhosphorIconsRegular.chalkboard,
                      onPressed: () => context.go(RouteNames.manageClasses),
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: UButton(
                      label: 'View Teaching Routine',
                      icon: PhosphorIconsRegular.calendar,
                      variant: UButtonVariant.secondary,
                      onPressed: () => context.go(RouteNames.teacherRoutine),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: UButton(
                      label: 'Manage Classes',
                      icon: PhosphorIconsRegular.chalkboard,
                      onPressed: () => context.go(RouteNames.manageClasses),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // Admin Web Console Pointer
  Widget _buildAdminOperationalStudio(Profile p) {
    return UCard(
      isTopLit: true,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'ADMIN ROUTINE & ENGINE CONSOLE',
            style: AppTextStyles.labelCaps.copyWith(color: AppColors.primary),
          ),
          AppSpacing.mdGap,
          Text(
            'Administrator workflows (Course Distribution, Policy Studio, CP-SAT '
            'Solve, and Version Rollback) run in the dedicated UniVerse React Web '
            'Console.',
            style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
          ),
          AppSpacing.mdGap,
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.bgSubtle,
              borderRadius: AppSpacing.radiusMd,
              border: Border.all(color: AppColors.border),
            ),
            child: SelectableText(
              AdminWebNoticeScreen.webConsoleUrl,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Student Operational Studio
  Widget _buildStudentOperationalStudio(Profile p) {
    final cohortBatch =
        (p.batch != null && p.batch!.trim().isNotEmpty) ? 'Batch ${p.batch}' : 'Batch Unassigned';
    final cohortSection = (p.section != null && p.section!.trim().isNotEmpty)
        ? 'Section ${p.section}'
        : 'Section Unassigned';
    final deptLabel = (p.department != null && p.department!.trim().isNotEmpty)
        ? p.department!
        : AppConstants.department;
    final semesterSuffix =
        p.semester != null ? ' · Semester ${p.semester}' : '';

    return UCard(
      isTopLit: true,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'STUDENT ACADEMIC STATUS',
                  style: AppTextStyles.labelCaps.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: AppSpacing.radiusSm,
                ),
                child: Text(
                  '7-DAY WEEK ACTIVE',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.mdGap,

          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.bgSubtle,
              borderRadius: AppSpacing.radiusMd,
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(
                  PhosphorIconsRegular.graduationCap,
                  size: 24,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$cohortBatch · $cohortSection',
                        style: AppTextStyles.h3,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Enrolled in $deptLabel$semesterSuffix',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.lgGap,

          // Joint section & Weekend rule summary
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.bgElevated,
              borderRadius: AppSpacing.radiusSm,
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(
                  PhosphorIconsRegular.info,
                  size: 14,
                  color: AppColors.info,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'R1/R2 Staggered Weekend: 2 consecutive off-days scheduled within the 7-day operational cycle.',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.lgGap,

          UButton(
            label: 'View My Weekly Routine',
            icon: PhosphorIconsRegular.calendar,
            onPressed: () => context.go(RouteNames.studentRoutine),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // CARD 3: SECURITY, NOTIFICATIONS & PREFERENCES
  // ==========================================
  Widget _buildSecurityAndPreferencesCard(Profile p) {
    return UCard(
      isTopLit: true,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('SECURITY & DEVICE STATUS', style: AppTextStyles.labelCaps),
          AppSpacing.mdGap,

          Row(
            children: [
              Icon(
                PhosphorIconsRegular.bellRinging,
                size: 16,
                color: kIsWeb ? AppColors.textSecondary : AppColors.success,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'UniVerse High-Importance Push Alerts',
                  style: AppTextStyles.bodyMedium,
                ),
              ),
              Text(
                kIsWeb ? 'Web (In-App Feed)' : 'Mobile Ready',
                style: AppTextStyles.caption.copyWith(
                  color: kIsWeb ? AppColors.textSecondary : AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Divider(height: AppSpacing.lg, color: AppColors.border),

          Row(
            children: [
              const Icon(
                PhosphorIconsRegular.sparkle,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Reduced Motion Support',
                  style: AppTextStyles.bodyMedium,
                ),
              ),
              Text(
                AppMotion.reduced(context) ? 'Enabled' : 'Off (Smooth)',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const Divider(height: AppSpacing.lg, color: AppColors.border),

          // High-contrast Sign out
          UButton(
            label: _isSigningOut ? 'Signing out...' : 'Sign out',
            variant: UButtonVariant.danger,
            icon: _isSigningOut ? null : PhosphorIconsRegular.signOut,
            isLoading: _isSigningOut,
            onPressed: _isSigningOut ? null : _confirmSignOut,
          ),
        ],
      ),
    );
  }

  // ==========================================
  // CARD 4: ABOUT UNIVERSE & TEAM CREDITS
  // ==========================================
  Widget _buildAboutAndCreditsCard() {
    return UCard(
      isTopLit: true,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ABOUT UNIVERSE', style: AppTextStyles.labelCaps),
              Text(
                'v${AppConstants.appVersion}',
                style: AppTextStyles.numeric,
              ),
            ],
          ),
          AppSpacing.smGap,
          Text(
            '${AppConstants.appName} · ${AppConstants.appSubtitle}\n${AppConstants.university} · ${AppConstants.department}',
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
          AppSpacing.mdGap,
          InkWell(
            onTap: _showAbout,
            borderRadius: AppSpacing.radiusSm,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: AppColors.bgSubtle,
                borderRadius: AppSpacing.radiusSm,
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    PhosphorIconsRegular.info,
                    size: 15,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'View Supervisor & Development Team Credits',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(
                    PhosphorIconsRegular.caretRight,
                    size: 13,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetCircle(_AvatarPreset preset, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: preset.color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(color: preset.color.withValues(alpha: 0.4)),
      ),
      child: Center(
        child: Icon(preset.icon, color: preset.color, size: size * 0.44),
      ),
    );
  }

  void _showAvatarPicker(Profile p) {
    showUAdaptiveModal<void>(
      context: context,
      title: 'Choose Avatar Preset',
      subtitle: 'Saved locally with instant active ring feedback',
      icon: PhosphorIconsRegular.userCircle,
      accentColor: AppColors.primary,
      builder: (ctx) => Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        children: [
          _AvatarPickerTile(
            isSelected: _localAvatarIndex == null,
            label: 'Default',
            onTap: () {
              _saveLocalAvatar(null);
              Navigator.pop(ctx);
            },
            borderColor: AppColors.border,
            bgColor: AppColors.bgElevated,
            child: Center(
              child: Text(
                p.displayName.isNotEmpty ? p.displayName[0].toUpperCase() : '?',
                style: AppTextStyles.h3.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          for (var i = 0; i < _presets.length; i++)
            _AvatarPickerTile(
              isSelected: _localAvatarIndex == i,
              label: _presets[i].label,
              onTap: () {
                _saveLocalAvatar(i);
                Navigator.pop(ctx);
              },
              borderColor: _presets[i].color.withValues(alpha: 0.4),
              bgColor: _presets[i].color.withValues(alpha: 0.15),
              child: Icon(
                _presets[i].icon,
                color: _presets[i].color,
                size: 24,
              ),
            ),
        ],
      ),
    );
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: AppConstants.appName,
      applicationVersion: 'v${AppConstants.appVersion} · ${AppConstants.appSubtitle}',
      children: [
        Text(
          '${AppConstants.university} · ${AppConstants.department}\n${AppConstants.course}',
          style: AppTextStyles.bodySm,
        ),
        AppSpacing.lgGap,
        Text('Supervisor', style: AppTextStyles.labelCaps),
        const SizedBox(height: 4),
        Text(
          '${AppConstants.supervisorName}\n${AppConstants.supervisorRole}',
          style: AppTextStyles.bodySm,
        ),
        AppSpacing.lgGap,
        Text('Development Team', style: AppTextStyles.labelCaps),
        const SizedBox(height: 4),
        for (final dev in AppConstants.developers) ...[
          Text('${dev.name} (${dev.id})', style: AppTextStyles.bodySm),
          const SizedBox(height: 2),
        ],
      ],
    );
  }
}

class _AvatarPreset {
  final Color color;
  final IconData icon;
  final String label;

  const _AvatarPreset({
    required this.color,
    required this.icon,
    required this.label,
  });
}

class _AvatarPickerTile extends StatelessWidget {
  final bool isSelected;
  final String label;
  final VoidCallback onTap;
  final Color borderColor;
  final Color bgColor;
  final Widget child;

  const _AvatarPickerTile({
    required this.isSelected,
    required this.label,
    required this.onTap,
    required this.borderColor,
    required this.bgColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: '$label avatar preset',
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.radiusMd,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppColors.primary : borderColor,
                    width: isSelected ? 2.5 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
                child: child,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: isSelected ? AppColors.primary : AppColors.textMuted,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
