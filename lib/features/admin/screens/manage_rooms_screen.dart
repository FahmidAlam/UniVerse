// ============================================================
// FILE: lib/features/admin/screens/manage_rooms_screen.dart
// PURPOSE: Admin config — the room inventory the timetable engine
// assigns from. Lists rooms grouped into Lab vs Theory/Gallery,
// with add/edit/delete via a bottom sheet. Owns its controller.
// ============================================================

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:universe/core/models/timetable_config_model.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/admin/controllers/timetable_rooms_controller.dart';
import 'package:universe/shared/widgets/u_app_bar.dart';
import 'package:universe/shared/widgets/u_button.dart';
import 'package:universe/shared/widgets/u_card.dart';
import 'package:universe/shared/widgets/u_chip.dart';
import 'package:universe/shared/widgets/u_empty_state.dart';
import 'package:universe/shared/widgets/u_loading.dart';
import 'package:universe/shared/widgets/u_text_field.dart';

class ManageRoomsScreen extends StatefulWidget {
  const ManageRoomsScreen({super.key});

  @override
  State<ManageRoomsScreen> createState() => _ManageRoomsScreenState();
}

class _ManageRoomsScreenState extends State<ManageRoomsScreen> {
  late final TimetableRoomsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TimetableRoomsController()..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: const UAppBar(
        title: 'Manage Rooms',
        subtitle: 'Engine room pools',
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _openEditor(),
        child: const Icon(PhosphorIconsRegular.plus, color: AppColors.textPrimary),
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.isLoading) return const ULoading.spinner();
          if (_controller.rooms.isEmpty) {
            return UEmptyState(
              icon: PhosphorIconsRegular.door,
              title: 'No rooms yet',
              message: _controller.errorMessage ??
                  'Add the rooms the engine can schedule into.',
              action: UButton(
                label: 'Add Room',
                icon: PhosphorIconsRegular.plus,
                fullWidth: false,
                onPressed: () => _openEditor(),
              ),
            );
          }
          return ListView(
            padding: AppSpacing.screenPadding,
            children: [
              _group('LAB ROOMS', _controller.labRooms,
                  AppColors.roleTeacher, PhosphorIconsRegular.flask),
              AppSpacing.sectionGap,
              _group('THEORY & GALLERY', _controller.theoryRooms,
                  AppColors.info, PhosphorIconsRegular.chalkboard),
              const SizedBox(height: AppSpacing.x4l),
            ],
          );
        },
      ),
    );
  }

  Widget _group(String title, List<TimetableRoom> rooms, Color color, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(title, style: AppTextStyles.labelCaps),
          AppSpacing.smHGap,
          Text('${rooms.length}',
              style: AppTextStyles.labelCaps.copyWith(color: color)),
        ]),
        AppSpacing.smGap,
        if (rooms.isEmpty)
          Text('None', style: AppTextStyles.bodySm)
        else
          ...rooms.map((r) => _roomTile(r, color, icon)),
      ],
    );
  }

  Widget _roomTile(TimetableRoom r, Color color, IconData icon) {
    return UCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      onTap: () => _openEditor(existing: r),
      child: Row(
        children: [
          Icon(icon, color: color, size: AppSpacing.iconMd),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.name, style: AppTextStyles.bodyMedium),
                if (r.building != null && r.building!.isNotEmpty)
                  Text(r.building!, style: AppTextStyles.caption),
              ],
            ),
          ),
          if (!r.isActive)
            Text('inactive',
                style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
          AppSpacing.smHGap,
          Text(r.kind,
              style: AppTextStyles.chip.copyWith(color: color)),
        ],
      ),
    );
  }

  Future<void> _openEditor({TimetableRoom? existing}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RoomEditorSheet(controller: _controller, existing: existing),
    );
  }
}

class _RoomEditorSheet extends StatefulWidget {
  final TimetableRoomsController controller;
  final TimetableRoom? existing;

  const _RoomEditorSheet({required this.controller, this.existing});

  @override
  State<_RoomEditorSheet> createState() => _RoomEditorSheetState();
}

class _RoomEditorSheetState extends State<_RoomEditorSheet> {
  late final TextEditingController _name;
  late final TextEditingController _building;
  String _kind = 'Theory'; // Theory | Lab | Gallery
  bool _active = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _building = TextEditingController(text: e?.building ?? '');
    _kind = e == null ? 'Theory' : e.kind;
    _active = e?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _building.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final data = {
      'name': _name.text.trim(),
      'building': _building.text.trim().isEmpty ? null : _building.text.trim(),
      'is_lab': _kind == 'Lab',
      'is_gallery': _kind == 'Gallery',
      'is_active': _active,
    };
    final ok = await widget.controller.save(existing: widget.existing, data: data);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    setState(() => _saving = true);
    await widget.controller.delete(widget.existing!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXlD)),
        ),
        padding: AppSpacing.screenPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSpacing.smGap,
            Text(isEdit ? 'Edit Room' : 'Add Room', style: AppTextStyles.h2),
            AppSpacing.lgGap,
            UTextField(
              label: 'Room name',
              hint: 'e.g. RAB-302, ACL-1, G2',
              controller: _name,
              prefixIcon: PhosphorIconsRegular.door,
            ),
            AppSpacing.mdGap,
            UTextField(
              label: 'Building (optional)',
              hint: 'e.g. Ragib Ali Building',
              controller: _building,
              prefixIcon: PhosphorIconsRegular.buildings,
            ),
            AppSpacing.lgGap,
            Text('Type', style: AppTextStyles.label),
            AppSpacing.smGap,
            Wrap(
              spacing: AppSpacing.sm,
              children: ['Theory', 'Lab', 'Gallery']
                  .map((k) => UChip(
                        label: k,
                        isActive: _kind == k,
                        onTap: () => setState(() => _kind = k),
                      ))
                  .toList(),
            ),
            AppSpacing.lgGap,
            Text('Status', style: AppTextStyles.label),
            AppSpacing.smGap,
            Row(children: [
              UChip(
                label: 'Active',
                isActive: _active,
                onTap: () => setState(() => _active = true),
              ),
              AppSpacing.smHGap,
              UChip(
                label: 'Inactive',
                isActive: !_active,
                onTap: () => setState(() => _active = false),
              ),
            ]),
            AppSpacing.smGap,
            Text('Only active rooms are used by the engine',
                style: AppTextStyles.caption),
            AppSpacing.lgGap,
            UButton(
              label: isEdit ? 'Save Changes' : 'Add Room',
              isLoading: _saving,
              onPressed: _save,
            ),
            if (isEdit) ...[
              AppSpacing.smGap,
              UButton(
                label: 'Delete Room',
                variant: UButtonVariant.danger,
                onPressed: _saving ? null : _delete,
              ),
            ],
            AppSpacing.lgGap,
          ],
        ),
      ),
    );
  }
}
