import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/core/utils/extensions.dart';

class UAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double size;
  final VoidCallback? onTap;

  const UAvatar({
    super.key,
    this.imageUrl,
    required this.name,
    this.size = AppSpacing.avatarMd,
    this.onTap,
  });

  Color _avatarColor() {
    const colors = [
      AppColors.roleStudent,
      AppColors.roleTeacher,
      AppColors.roleAdmin,
      AppColors.info,
      AppColors.warning,
      AppColors.success,
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final color = _avatarColor();
    final initials = name.initials;

    Widget avatar;

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      avatar = ClipOval(
        child: CachedNetworkImage(
          imageUrl: imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, __) => _buildInitials(color, initials),
          errorWidget: (_, __, ___) => _buildInitials(color, initials),
        ),
      );
    } else {
      avatar = _buildInitials(color, initials);
    }

    avatar = OrbitalAvatarBezel(size: size, child: avatar);
    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
            customBorder: const CircleBorder(), onTap: onTap, child: avatar),
      );
    }
    return avatar;
  }

  Widget _buildInitials(Color color, String initials) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Center(
        child: Text(
          initials,
          style: AppTextStyles.badge.copyWith(
            color: color,
            fontSize: size * 0.32,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

/// Shared orbital double ring. The bezel stays inside the requested diameter.
class OrbitalAvatarBezel extends StatelessWidget {
  final double size;
  final Widget child;
  const OrbitalAvatarBezel(
      {super.key, required this.size, required this.child});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.bgPrimary,
          border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.45), width: 1.5),
        ),
        child: ClipOval(child: child),
      );
}
