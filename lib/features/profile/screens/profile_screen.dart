import 'package:flutter/material.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/models/profile_model.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/features/profile/controllers/profile_controller.dart';
import 'package:universe/shared/widgets/info_row.dart';
import 'package:universe/shared/widgets/settings_tile.dart';
import 'package:universe/shared/widgets/stat_card.dart';
import 'package:universe/shared/widgets/u_app_bar.dart';
import 'package:universe/shared/widgets/u_avatar.dart';
import 'package:universe/shared/widgets/u_button.dart';
import 'package:universe/shared/widgets/u_card.dart';
import 'package:universe/shared/widgets/u_loading.dart';

class ProfileScreen extends StatefulWidget {
  final AuthController authController;

  const ProfileScreen({super.key, required this.authController});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileController _controller;
  int? _localAvatarIndex;

  static const _presets = [
    _AvatarPreset(
        color: AppColors.primary,
        icon: PhosphorIconsRegular.graduationCap,
        label: 'Graduate'),
    _AvatarPreset(
        color: AppColors.info,
        icon: PhosphorIconsRegular.books,
        label: 'Scholar'),
    _AvatarPreset(
        color: AppColors.success,
        icon: PhosphorIconsRegular.atom,
        label: 'Science'),
    _AvatarPreset(
        color: AppColors.warning,
        icon: PhosphorIconsRegular.flask,
        label: 'Lab'),
    _AvatarPreset(
        color: AppColors.error,
        icon: PhosphorIconsRegular.lightbulb,
        label: 'Idea'),
    _AvatarPreset(
        color: AppColors.primary,
        icon: PhosphorIconsRegular.globe,
        label: 'Global'),
    _AvatarPreset(
        color: AppColors.info,
        icon: PhosphorIconsRegular.brain,
        label: 'Think'),
    _AvatarPreset(
        color: AppColors.success,
        icon: PhosphorIconsRegular.pencilSimple,
        label: 'Create'),
  ];

  @override
  void initState() {
    super.initState();
    _controller = ProfileController(authController: widget.authController);
    _controller.load();
    _loadLocalAvatar();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadLocalAvatar() async {
    final userId = widget.authController.profile?['id'] as String?;
    if (userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt('avatar_preset_$userId');
    if (mounted) setState(() => _localAvatarIndex = idx);
  }

  Future<void> _saveLocalAvatar(int? index) async {
    final userId = widget.authController.profile?['id'] as String?;
    if (userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (index == null) {
      await prefs.remove('avatar_preset_$userId');
    } else {
      await prefs.setInt('avatar_preset_$userId', index);
    }
    if (mounted) setState(() => _localAvatarIndex = index);
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: AppSpacing.radiusLg),
        title: Text('Sign out?', style: AppTextStyles.h3),
        content: Text(
          'You\'ll need to sign in again to access your account.',
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
            child: Text('Sign out', style: AppTextStyles.danger),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _controller.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: const UAppBar(title: 'Profile', showBackButton: false),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final p = _controller.profile;
          if (p == null) {
            return const Center(child: ULoading.spinner());
          }
          return SingleChildScrollView(
            padding: AppSpacing.screenPaddingScrollable,
            child: Column(
              children: [
                _buildHeader(p),
                AppSpacing.sectionGap,
                _buildStats(p),
                AppSpacing.sectionGap,
                _buildInfo(p),
                AppSpacing.sectionGap,
                _buildSettings(),
                AppSpacing.sectionGap,
                UButton(
                  label: 'Sign out',
                  variant: UButtonVariant.danger,
                  icon: PhosphorIconsRegular.signOut,
                  onPressed: _confirmSignOut,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(Profile p) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomRight,
          children: [
            _localAvatarIndex != null
                ? _buildPresetCircle(_presets[_localAvatarIndex!], AppSpacing.avatarXl)
                : UAvatar(
                    name: p.displayName,
                    imageUrl: p.avatarUrl,
                    size: AppSpacing.avatarXl,
                  ),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: () => _showAvatarPicker(p),
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.bgPrimary, width: 2),
                  ),
                  child: const Icon(
                    PhosphorIconsRegular.pencilSimple,
                    size: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
        AppSpacing.mdGap,
        Text(p.displayName, style: AppTextStyles.h2),
        AppSpacing.xsGap,
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: AppSpacing.radiusFull,
          ),
          child: Text(
            p.roleLabel.toUpperCase(),
            style: AppTextStyles.labelCaps.copyWith(color: AppColors.primary),
          ),
        ),
        AppSpacing.smGap,
        Text(p.email, style: AppTextStyles.bodySm),
      ],
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
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.x3l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: AppSpacing.radiusFull,
                  ),
                ),
              ),
              Text('Choose Avatar', style: AppTextStyles.h3),
              const SizedBox(height: 4),
              Text(
                'Saved on this device only',
                style:
                    AppTextStyles.caption.copyWith(color: AppColors.textMuted),
              ),
              AppSpacing.lgGap,
              Wrap(
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
                        p.displayName.isNotEmpty
                            ? p.displayName[0].toUpperCase()
                            : '?',
                        style: AppTextStyles.h3
                            .copyWith(color: AppColors.textSecondary),
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
            ],
          ),
        );
      },
    );
  }

  Widget _buildStats(Profile p) {
    final List<Widget> cards;
    if (p.isTeacher) {
      cards = [
        StatCard(number: p.department ?? '—', label: 'Department'),
        StatCard(number: '${p.courses.length}', label: 'Courses'),
      ];
    } else if (p.isStudent) {
      cards = [
        StatCard(number: p.batch ?? '—', label: 'Batch'),
        StatCard(number: p.section ?? '—', label: 'Section'),
      ];
    } else {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) AppSpacing.smHGap,
          Expanded(child: cards[i]),
        ],
      ],
    );
  }

  Widget _buildInfo(Profile p) {
    final rows = <Widget>[
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
      if (p.department != null)
        InfoRow(
          label: 'Department',
          value: p.department!,
          icon: PhosphorIconsRegular.buildings,
          showDivider: false,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('INFORMATION', style: AppTextStyles.labelCaps),
        AppSpacing.smGap,
        UCard(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(children: rows),
        ),
      ],
    );
  }

  Widget _buildSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SETTINGS', style: AppTextStyles.labelCaps),
        AppSpacing.smGap,
        UCard(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: SettingsTile(
            title: 'About ${AppConstants.appName}',
            icon: PhosphorIconsRegular.info,
            onTap: _showAbout,
          ),
        ),
      ],
    );
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: AppConstants.appName,
      applicationVersion: AppConstants.appSubtitle,
      children: [
        Text(
          '${AppConstants.university} · ${AppConstants.department}\n'
          '${AppConstants.course}',
          style: AppTextStyles.bodySm,
        ),
        AppSpacing.lgGap,
        _creditsGroup(AppConstants.supervisorTitle.toUpperCase(), [
          _creditRow(
            AppConstants.supervisorName,
            null,
            subtitle: AppConstants.supervisorRole,
          ),
        ]),
        AppSpacing.cardGap,
        _creditsGroup('DEVELOPMENT TEAM · ${AppConstants.teamName}', [
          for (final dev in AppConstants.developers)
            _creditRow(dev.name, dev.id),
        ]),
      ],
    );
  }

  // ─── About: credit blocks ─────────────────────────────────
  Widget _creditsGroup(String label, List<Widget> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.labelCaps),
        AppSpacing.smGap,
        ...rows,
      ],
    );
  }

  Widget _creditRow(String name, String? id, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTextStyles.bodySmMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (id != null) ...[
            const SizedBox(width: AppSpacing.md),
            Text(
              id,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}


class _AvatarPreset {
  final Color color;
  final IconData icon;
  final String label;
  const _AvatarPreset(
      {required this.color, required this.icon, required this.label});
}


class _AvatarPickerTile extends StatelessWidget {
  final bool isSelected;
  final String label;
  final VoidCallback onTap;
  final Widget child;
  final Color borderColor;
  final Color bgColor;

  const _AvatarPickerTile({
    required this.isSelected,
    required this.label,
    required this.onTap,
    required this.child,
    required this.borderColor,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppColors.primary : borderColor,
                    width: isSelected ? 2.5 : 1.5,
                  ),
                ),
                child: child,
              ),
              if (isSelected)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      PhosphorIconsRegular.check,
                      size: 11,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(label,
              style:
                  AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
