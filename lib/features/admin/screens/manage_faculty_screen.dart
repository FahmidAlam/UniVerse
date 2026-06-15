// ============================================================
// FILE: lib/features/admin/screens/manage_faculty_screen.dart
// PURPOSE: Admin config — the teacher directory the engine uses for
// names + hard day-off constraints. Searchable list; tap a teacher to
// edit their display name and weekly day-offs. Owns its controller.
// ============================================================

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:universe_v1/core/models/timetable_config_model.dart';
import 'package:universe_v1/core/theme/app_colors.dart';
import 'package:universe_v1/core/theme/app_spacing.dart';
import 'package:universe_v1/core/theme/app_text_styles.dart';
import 'package:universe_v1/features/admin/controllers/timetable_faculty_controller.dart';
import 'package:universe_v1/shared/widgets/u_app_bar.dart';
import 'package:universe_v1/shared/widgets/u_button.dart';
import 'package:universe_v1/shared/widgets/u_card.dart';
import 'package:universe_v1/shared/widgets/u_chip.dart';
import 'package:universe_v1/shared/widgets/u_empty_state.dart';
import 'package:universe_v1/shared/widgets/u_loading.dart';
import 'package:universe_v1/shared/widgets/u_text_field.dart';

// Full 7-day week (the engine config spans Sun–Sat; off-days use these).
const List<String> _kDays = [
  'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
];
const List<String> _kDaysShort = [
  'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat',
];

class ManageFacultyScreen extends StatefulWidget {
  const ManageFacultyScreen({super.key});

  @override
  State<ManageFacultyScreen> createState() => _ManageFacultyScreenState();
}

class _ManageFacultyScreenState extends State<ManageFacultyScreen> {
  late final TimetableFacultyController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TimetableFacultyController()..load();
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
        title: 'Manage Faculty',
        subtitle: 'Names & day-offs',
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.isLoading) return const ULoading.spinner();
          final list = _controller.filtered;
          return Column(
            children: [
              Padding(
                padding: AppSpacing.screenPadding,
                child: Column(
                  children: [
                    UTextField(
                      label: 'Search',
                      hint: 'Acronym or name (e.g. EBH)',
                      prefixIcon: PhosphorIconsRegular.magnifyingGlass,
                      onChanged: _controller.setQuery,
                    ),
                    AppSpacing.smGap,
                    Row(children: [
                      Text('${_controller.total} teachers · ',
                          style: AppTextStyles.caption),
                      Text('${_controller.withOffDays} with day-offs',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.roleTeacher)),
                    ]),
                  ],
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? const UEmptyState(
                        icon: PhosphorIconsRegular.usersThree,
                        title: 'No teachers found',
                        message: 'Try a different search.',
                      )
                    : ListView.builder(
                        padding: AppSpacing.screenPaddingH,
                        itemCount: list.length,
                        itemBuilder: (_, i) => _facultyTile(list[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _facultyTile(TimetableFaculty f) {
    return UCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      onTap: () => _openEditor(f),
      child: Row(
        children: [
          Container(
            width: AppSpacing.avatarSm,
            height: AppSpacing.avatarSm,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: AppSpacing.radiusSm,
            ),
            child: Text(f.acronym,
                style: AppTextStyles.chip.copyWith(color: AppColors.primary)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f.displayName, style: AppTextStyles.bodyMedium),
                if (f.offDays.isEmpty)
                  Text('No day-offs', style: AppTextStyles.caption)
                else
                  Text(
                    'Off: ${f.offDays.map(_short).join(', ')}',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.roleTeacher),
                  ),
              ],
            ),
          ),
          const Icon(PhosphorIconsRegular.caretRight,
              size: AppSpacing.iconSm, color: AppColors.textMuted),
        ],
      ),
    );
  }

  String _short(String day) {
    final i = _kDays.indexOf(day);
    return i == -1 ? day : _kDaysShort[i];
  }

  Future<void> _openEditor(TimetableFaculty f) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FacultyEditorSheet(controller: _controller, faculty: f),
    );
  }
}

class _FacultyEditorSheet extends StatefulWidget {
  final TimetableFacultyController controller;
  final TimetableFaculty faculty;

  const _FacultyEditorSheet({required this.controller, required this.faculty});

  @override
  State<_FacultyEditorSheet> createState() => _FacultyEditorSheetState();
}

class _FacultyEditorSheetState extends State<_FacultyEditorSheet> {
  late final TextEditingController _name;
  late Set<String> _off;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.faculty.fullName ?? '');
    _off = {...widget.faculty.offDays};
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await widget.controller.save(
      widget.faculty,
      fullName: _name.text.trim().isEmpty ? null : _name.text.trim(),
      offDays: _kDays.where(_off.contains).toList(),
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.bgCard,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXlD)),
        ),
        padding: AppSpacing.screenPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSpacing.smGap,
            Row(children: [
              Text(widget.faculty.acronym, style: AppTextStyles.h2),
              AppSpacing.smHGap,
              if (widget.faculty.dept != null)
                Text(widget.faculty.dept!,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textMuted)),
            ]),
            AppSpacing.lgGap,
            UTextField(
              label: 'Full name',
              hint: 'e.g. Md. Ebrahim Hossain',
              controller: _name,
              prefixIcon: PhosphorIconsRegular.user,
            ),
            AppSpacing.lgGap,
            Text('Day-offs (unavailable days)', style: AppTextStyles.label),
            AppSpacing.smGap,
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (var i = 0; i < _kDays.length; i++)
                  UChip(
                    label: _kDaysShort[i],
                    isActive: _off.contains(_kDays[i]),
                    onTap: () => setState(() {
                      _off.contains(_kDays[i])
                          ? _off.remove(_kDays[i])
                          : _off.add(_kDays[i]);
                    }),
                  ),
              ],
            ),
            AppSpacing.lgGap,
            UButton(label: 'Save', isLoading: _saving, onPressed: _save),
            AppSpacing.lgGap,
          ],
        ),
      ),
    );
  }
}
