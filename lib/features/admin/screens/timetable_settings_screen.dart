import 'package:flutter/material.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/core/models/timetable_config_model.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/admin/controllers/timetable_settings_controller.dart';
import 'package:universe/shared/widgets/u_app_bar.dart';
import 'package:universe/shared/widgets/u_button.dart';
import 'package:universe/shared/widgets/u_card.dart';
import 'package:universe/shared/widgets/u_chip.dart';
import 'package:universe/shared/widgets/u_loading.dart';
import 'package:universe/shared/widgets/u_text_field.dart';

const Map<String, String> _kWeights = {
  'different_days': 'Spread a course across days',
  'compactness': 'Fewer class-days per section',
  'spread': 'Balance daily load',
  'late_slot': 'Avoid the last period',
};

class TimetableSettingsScreen extends StatefulWidget {
  const TimetableSettingsScreen({super.key});

  @override
  State<TimetableSettingsScreen> createState() =>
      _TimetableSettingsScreenState();
}

class _TimetableSettingsScreenState extends State<TimetableSettingsScreen> {
  late final TimetableSettingsController _controller;
  final _semester = TextEditingController();
  final Map<String, TextEditingController> _weightCtrls = {
    for (final k in _kWeights.keys) k: TextEditingController(),
  };
  bool _fridayNoP4 = true;
  String _serviceScope = 'resource_only';
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _controller = TimetableSettingsController();
    _controller.load().then((_) => _hydrate());
  }

  void _hydrate() {
    final s = _controller.settings;
    _semester.text = s.semesterLabel ?? '';
    _fridayNoP4 = s.fridayNoP4;
    _serviceScope = s.serviceScope;
    for (final k in _kWeights.keys) {
      _weightCtrls[k]!.text = s.weight(k, _defaultWeight(k)).toString();
    }
    setState(() => _loaded = true);
  }

  int _defaultWeight(String k) =>
      const {'different_days': 8, 'compactness': 3, 'spread': 2, 'late_slot': 1}[k] ?? 1;

  @override
  void dispose() {
    _controller.dispose();
    _semester.dispose();
    for (final c in _weightCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final weights = <String, dynamic>{
      for (final k in _kWeights.keys)
        k: int.tryParse(_weightCtrls[k]!.text.trim()) ?? _defaultWeight(k),
    };
    final updated = TimetableSettings(
      semesterLabel:
          _semester.text.trim().isEmpty ? null : _semester.text.trim(),
      periods: _controller.settings.periods,
      fridayNoP4: _fridayNoP4,
      serviceScope: _serviceScope,
      weights: weights,
    );
    final ok = await _controller.save(updated);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Settings saved' : 'Could not save settings'),
      backgroundColor: ok ? AppColors.success : AppColors.error,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: const UAppBar(
        title: 'Timetable Settings',
        subtitle: 'Solver rules & weights',
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.isLoading || !_loaded) {
            return const ULoading.spinner();
          }
          return ListView(
            padding: AppSpacing.screenPadding,
            children: [
              UTextField(
                label: 'Semester label',
                hint: 'e.g. Summer 2025',
                controller: _semester,
                prefixIcon: PhosphorIconsRegular.calendarBlank,
              ),
              AppSpacing.sectionGap,
              Text('RULES', style: AppTextStyles.labelCaps),
              AppSpacing.smGap,
              _ruleCard(
                title: 'Friday has no Period 4',
                subtitle: 'Skips the 1:10–2:25 slot on Fridays (Jummah).',
                value: _fridayNoP4,
                onChanged: (v) => setState(() => _fridayNoP4 = v),
              ),
              AppSpacing.mdGap,
              _serviceScopeCard(),
              AppSpacing.sectionGap,
              Text('SOFT-CONSTRAINT WEIGHTS', style: AppTextStyles.labelCaps),
              AppSpacing.smGap,
              Text(
                'Higher = the solver tries harder to satisfy it. 0 turns it off.',
                style: AppTextStyles.caption,
              ),
              AppSpacing.mdGap,
              ..._kWeights.entries.map(_weightField),
              AppSpacing.sectionGap,
              UButton(
                label: 'Save Settings',
                icon: PhosphorIconsRegular.floppyDisk,
                isLoading: _controller.isSaving,
                onPressed: _save,
              ),
              const SizedBox(height: AppSpacing.x4l),
            ],
          );
        },
      ),
    );
  }

  Widget _ruleCard({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return UCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.bodyMedium),
          AppSpacing.xsGap,
          Text(subtitle, style: AppTextStyles.caption),
          AppSpacing.smGap,
          Row(children: [
            UChip(label: 'On', isActive: value, onTap: () => onChanged(true)),
            AppSpacing.smHGap,
            UChip(label: 'Off', isActive: !value, onTap: () => onChanged(false)),
          ]),
        ],
      ),
    );
  }

  Widget _serviceScopeCard() {
    return UCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Service / non-CSE classes', style: AppTextStyles.bodyMedium),
          AppSpacing.xsGap,
          Text(
            'Resource-only blocks a CSE teacher’s time for their service '
            'classes (Law, BuA, EEE…) so CSE classes never clash with them.',
            style: AppTextStyles.caption,
          ),
          AppSpacing.smGap,
          Row(children: [
            UChip(
              label: 'Resource-only',
              isActive: _serviceScope == 'resource_only',
              onTap: () => setState(() => _serviceScope = 'resource_only'),
            ),
            AppSpacing.smHGap,
            UChip(
              label: 'Ignore',
              isActive: _serviceScope == 'ignore',
              onTap: () => setState(() => _serviceScope = 'ignore'),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _weightField(MapEntry<String, String> e) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: Text(e.value, style: AppTextStyles.bodySm)),
          AppSpacing.mdGap,
          SizedBox(
            width: AppSpacing.x4l + AppSpacing.x3l,
            child: UTextField(
              label: '',
              hint: '0',
              controller: _weightCtrls[e.key],
              keyboardType: TextInputType.number,
            ),
          ),
        ],
      ),
    );
  }
}
