// Wrapper around UAvatar that automatically shows the locally-stored
// avatar preset (chosen in ProfileScreen) when one is set for this user.
// Reads from SharedPreferences using the same key the profile screen writes.

import 'package:flutter/material.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/shared/widgets/u_avatar.dart';

// Must stay in sync with _presets in profile_screen.dart (same index = same icon).
const _presets = [
  _P(color: AppColors.primary,  icon: PhosphorIconsRegular.graduationCap),
  _P(color: AppColors.info,     icon: PhosphorIconsRegular.books),
  _P(color: AppColors.success,  icon: PhosphorIconsRegular.atom),
  _P(color: AppColors.warning,  icon: PhosphorIconsRegular.flask),
  _P(color: AppColors.error,    icon: PhosphorIconsRegular.lightbulb),
  _P(color: AppColors.primary,  icon: PhosphorIconsRegular.globe),
  _P(color: AppColors.info,     icon: PhosphorIconsRegular.brain),
  _P(color: AppColors.success,  icon: PhosphorIconsRegular.pencilSimple),
];

class _P {
  final Color color;
  final IconData icon;
  const _P({required this.color, required this.icon});
}

class ULocalAvatar extends StatefulWidget {
  final String? userId;
  final String name;
  final String? imageUrl;
  final double size;
  final VoidCallback? onTap;

  const ULocalAvatar({
    super.key,
    required this.userId,
    required this.name,
    this.imageUrl,
    this.size = AppSpacing.avatarMd,
    this.onTap,
  });

  @override
  State<ULocalAvatar> createState() => _ULocalAvatarState();
}

class _ULocalAvatarState extends State<ULocalAvatar> {
  int? _index;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt('avatar_preset_${widget.userId}');
    if (mounted) setState(() => _index = idx);
  }

  @override
  Widget build(BuildContext context) {
    Widget avatar;

    if (_index != null && _index! < _presets.length) {
      final p = _presets[_index!];
      avatar = Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: p.color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(color: p.color.withValues(alpha: 0.4)),
        ),
        child: Center(
          child: Icon(p.icon, color: p.color, size: widget.size * 0.44),
        ),
      );
    } else {
      avatar = UAvatar(
        name: widget.name,
        imageUrl: widget.imageUrl,
        size: widget.size,
      );
    }

    if (widget.onTap != null) {
      return GestureDetector(onTap: widget.onTap, child: avatar);
    }
    return avatar;
  }
}
