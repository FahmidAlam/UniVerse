// Timetable Settings — the university's scheduling rules.
//
// Everything on this screen used to be a constant inside the Python engine: a
// fixed period grid, a 14-week term, a Friday-only period block, a 7:00pm slot
// that could never be used. The university changes all of them (summer vs
// winter timings, bi- vs tri-semester), so switching them must be an edit here,
// not a code change and a new APK.
//
//     Admin UI  ->  timetable_settings  ->  buildEngineConfig()  ->  solver
//
// Period boundaries are typed by hand from the department's workbook, so every
// one of them is pushed through `ClockTime` before it is stored — a bare "1:50"
// would otherwise reach Postgres as 01:50 and put an afternoon class at night.

import 'package:flutter/material.dart';
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/models/timetable_config_model.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/core/utils/clock_time.dart';
import 'package:universe/features/admin/controllers/timetable_settings_controller.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
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

const Map<String, int> _kWeightDefaults = {
  'different_days': 8,
  'compactness': 3,
  'spread': 2,
  'late_slot': 1,
};

/// Spreadsheet columns the printed template reserves for periods (G is the
/// break column). A period needs one so `render.py` knows where to draw it,
/// which is why the grid cannot grow past seven.
const List<String> _kPeriodColumns = ['D', 'E', 'F', 'H', 'I', 'J', 'K'];

/// One editable period row.
class _PeriodDraft {
  int idx;
  final TextEditingController start;
  final TextEditingController end;
  String col;

  /// Real period, but held back from the solver unless online periods are
  /// enabled — the department's 7:00pm "OL Class" slot.
  bool online;

  /// Days this period is not taught, e.g. Friday P4 for Jummah.
  final Set<String> blockedOn;

  _PeriodDraft({
    required this.idx,
    required String start,
    required String end,
    required this.col,
    this.online = false,
    Set<String>? blockedOn,
  })  : start = TextEditingController(text: start),
        end = TextEditingController(text: end),
        blockedOn = blockedOn ?? <String>{};

  void dispose() {
    start.dispose();
    end.dispose();
  }

  Map<String, dynamic> toMap() {
    final s = ClockTime.toHm(ClockTime.normalizeOr(start.text.trim()));
    final e = ClockTime.toHm(ClockTime.normalizeOr(end.text.trim()));
    return {'idx': idx, 'label': '$s-$e', 'start': s, 'end': e, 'col': col};
  }
}

class TimetableSettingsScreen extends StatefulWidget {
  const TimetableSettingsScreen({super.key});

  @override
  State<TimetableSettingsScreen> createState() =>
      _TimetableSettingsScreenState();
}

class _TimetableSettingsScreenState extends State<TimetableSettingsScreen> {
  late final TimetableSettingsController _controller;
  final _semester = TextEditingController();
  final _weeks = TextEditingController();
  final Map<String, TextEditingController> _weightCtrls = {
    for (final k in _kWeights.keys) k: TextEditingController(),
  };

  List<_PeriodDraft> _periods = [];
  Set<String> _workingDays = {};
  bool _allowOnline = false;
  String _serviceScope = 'resource_only';
  bool _loaded = false;
  String? _formError;

  @override
  void initState() {
    super.initState();
    _controller = TimetableSettingsController();
    _controller.load().then((_) => _hydrate());
  }

  void _hydrate() {
    final s = _controller.settings;
    _semester.text = s.semesterLabel ?? '';
    _weeks.text = s.weeksInTerm.toString();
    _serviceScope = s.serviceScope;
    _allowOnline = s.allowOnlinePeriods;
    _workingDays = s.workingDays.isEmpty
        ? AppConstants.weekDays.toSet()
        : s.workingDays.toSet();
    for (final k in _kWeights.keys) {
      _weightCtrls[k]!.text = s.weight(k, _kWeightDefaults[k] ?? 1).toString();
    }

    // Fold the stored rules back onto the period they belong to, so the admin
    // edits one row per period instead of three parallel lists.
    final blockedFor = <int, Set<String>>{};
    s.blockedPeriods.forEach((day, idxs) {
      for (final i in idxs) {
        blockedFor.putIfAbsent(i, () => <String>{}).add(day);
      }
    });
    // Legacy flag, kept working for rows written before migration 010.
    if (s.fridayNoP4 && s.blockedPeriods.isEmpty) {
      blockedFor.putIfAbsent(4, () => <String>{}).add('Friday');
    }
    final online = {...s.onlinePeriods, ...s.excludedPeriods};

    _periods = [
      for (var i = 0; i < s.periods.length; i++)
        if (s.periods[i] is Map)
          _buildDraft((s.periods[i] as Map).cast<String, dynamic>(), i,
              blockedFor, online),
    ];
    if (!mounted) return;
    setState(() => _loaded = true);
  }

  _PeriodDraft _buildDraft(Map<String, dynamic> p, int i,
      Map<int, Set<String>> blockedFor, Set<int> online) {
    final idx = (p['idx'] as num?)?.toInt() ?? (i + 1);
    return _PeriodDraft(
      idx: idx,
      start: ClockTime.toHm(ClockTime.normalizeOr(p['start']?.toString() ?? '')),
      end: ClockTime.toHm(ClockTime.normalizeOr(p['end']?.toString() ?? '')),
      col: (p['col'] as String?) ?? _nextColumn(i),
      online: online.contains(idx),
      blockedOn: blockedFor[idx] ?? <String>{},
    );
  }

  String _nextColumn(int position) => position < _kPeriodColumns.length
      ? _kPeriodColumns[position]
      : _kPeriodColumns.last;

  @override
  void dispose() {
    _controller.dispose();
    _semester.dispose();
    _weeks.dispose();
    for (final c in _weightCtrls.values) {
      c.dispose();
    }
    for (final p in _periods) {
      p.dispose();
    }
    super.dispose();
  }

  void _addPeriod() {
    if (_periods.length >= _kPeriodColumns.length) return;
    final last = _periods.isEmpty ? null : _periods.last;
    setState(() {
      _periods.add(_PeriodDraft(
        idx: (_periods.map((p) => p.idx).fold<int>(0, (a, b) => a > b ? a : b)) + 1,
        start: last?.end.text ?? '08:50',
        end: '',
        col: _nextColumn(_periods.length),
      ));
    });
  }

  void _removePeriod(int i) {
    setState(() {
      _periods.removeAt(i).dispose();
      // Keep numbering and template columns contiguous after a removal.
      for (var j = 0; j < _periods.length; j++) {
        _periods[j]
          ..idx = j + 1
          ..col = _nextColumn(j);
      }
    });
  }

  Future<void> _save() async {
    final periods = [for (final p in _periods) p.toMap()];

    final problem = TimetableSettings.validatePeriods(periods);
    if (problem != null) {
      setState(() => _formError = problem);
      return;
    }
    if (_workingDays.isEmpty) {
      setState(() => _formError = 'Pick at least one working day.');
      return;
    }
    final weeks = int.tryParse(_weeks.text.trim());
    if (weeks == null || weeks < 1 || weeks > 52) {
      setState(() => _formError = 'Term length must be between 1 and 52 weeks.');
      return;
    }
    setState(() => _formError = null);

    final blocked = <String, List<int>>{};
    for (final p in _periods) {
      for (final day in p.blockedOn) {
        blocked.putIfAbsent(day, () => <int>[]).add(p.idx);
      }
    }

    final updated = TimetableSettings(
      semesterLabel:
          _semester.text.trim().isEmpty ? null : _semester.text.trim(),
      periods: periods,
      // Persist in the canonical week order so the engine's day list and
      // AppConstants.weekDays stay aligned.
      workingDays: [
        for (final d in AppConstants.weekDays)
          if (_workingDays.contains(d)) d,
      ],
      weeksInTerm: weeks,
      blockedPeriods: blocked,
      onlinePeriods: [
        for (final p in _periods)
          if (p.online) p.idx,
      ],
      allowOnlinePeriods: _allowOnline,
      excludedPeriods: const [],
      semesterMap: _controller.settings.semesterMap,
      // Superseded by blockedPeriods; kept false so the two can't disagree.
      fridayNoP4: false,
      serviceScope: _serviceScope,
      weights: {
        for (final k in _kWeights.keys)
          k: int.tryParse(_weightCtrls[k]!.text.trim()) ??
              _kWeightDefaults[k] ??
              1,
      },
    );

    final ok = await _controller.save(updated);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? 'Saved. The next generated routine uses these settings.'
          : 'Could not save settings'),
      backgroundColor: ok ? AppColors.success : AppColors.error,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: const UAppBar(
        title: 'Timetable Settings',
        subtitle: 'Class times, term & solver rules',
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
              Text('TERM', style: AppTextStyles.labelCaps),
              AppSpacing.smGap,
              UTextField(
                label: 'Semester label',
                hint: 'e.g. Summer 2025',
                controller: _semester,
                prefixIcon: PhosphorIconsRegular.calendarBlank,
              ),
              AppSpacing.mdGap,
              UTextField(
                label: 'Teaching weeks in the term',
                hint: '14',
                controller: _weeks,
                keyboardType: TextInputType.number,
                prefixIcon: PhosphorIconsRegular.calendarBlank,
              ),
              AppSpacing.xsGap,
              Text(
                'Turns each course’s whole-term class count into weekly '
                'classes. 28 classes over 14 weeks means two a week; over 10 '
                'weeks it becomes three.',
                style: AppTextStyles.caption,
              ),
              AppSpacing.mdGap,
              _workingDaysCard(),
              AppSpacing.sectionGap,
              Row(
                children: [
                  Expanded(
                      child: Text('CLASS PERIODS',
                          style: AppTextStyles.labelCaps)),
                  if (_periods.length < _kPeriodColumns.length)
                    UChip(
                      label: 'Add period',
                      isActive: false,
                      onTap: _addPeriod,
                    ),
                ],
              ),
              AppSpacing.smGap,
              Text(
                'Used for both summer and winter timings — edit them here '
                'rather than rebuilding the app. The printed workbook has '
                '${_kPeriodColumns.length} period columns, so that is the '
                'maximum.',
                style: AppTextStyles.caption,
              ),
              AppSpacing.mdGap,
              for (var i = 0; i < _periods.length; i++) ...[
                _periodCard(i),
                AppSpacing.mdGap,
              ],
              _onlineCard(),
              AppSpacing.sectionGap,
              Text('RULES', style: AppTextStyles.labelCaps),
              AppSpacing.smGap,
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
              if (_formError != null) ...[
                Text(_formError!, style: AppTextStyles.bodyError),
                AppSpacing.smGap,
              ],
              if (_controller.errorMessage != null) ...[
                Text(_controller.errorMessage!, style: AppTextStyles.bodyError),
                AppSpacing.smGap,
              ],
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

  Widget _workingDaysCard() {
    return UCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Working days', style: AppTextStyles.bodyMedium),
          AppSpacing.xsGap,
          Text('Days the department teaches. The engine schedules into these '
              'only.', style: AppTextStyles.caption),
          AppSpacing.smGap,
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (var i = 0; i < AppConstants.weekDays.length; i++)
                UChip(
                  label: AppConstants.weekDaysShort[i],
                  isActive: _workingDays.contains(AppConstants.weekDays[i]),
                  onTap: () => setState(() {
                    final day = AppConstants.weekDays[i];
                    _workingDays.contains(day)
                        ? _workingDays.remove(day)
                        : _workingDays.add(day);
                  }),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _periodCard(int i) {
    final p = _periods[i];
    return UCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Period ${p.idx}', style: AppTextStyles.bodyMedium),
              ),
              IconButton(
                icon: const Icon(PhosphorIconsRegular.trash,
                    size: AppSpacing.iconMd, color: AppColors.error),
                tooltip: 'Remove period ${p.idx}',
                onPressed: () => _removePeriod(i),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: UTextField(
                  label: 'Starts',
                  hint: '08:50',
                  controller: p.start,
                ),
              ),
              AppSpacing.mdGap,
              Expanded(
                child: UTextField(
                  label: 'Ends',
                  hint: '10:05',
                  controller: p.end,
                ),
              ),
            ],
          ),
          AppSpacing.smGap,
          Text('Not taught on', style: AppTextStyles.caption),
          AppSpacing.xsGap,
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (var d = 0; d < AppConstants.weekDays.length; d++)
                UChip(
                  label: AppConstants.weekDaysShort[d],
                  isActive: p.blockedOn.contains(AppConstants.weekDays[d]),
                  onTap: () => setState(() {
                    final day = AppConstants.weekDays[d];
                    p.blockedOn.contains(day)
                        ? p.blockedOn.remove(day)
                        : p.blockedOn.add(day);
                  }),
                ),
            ],
          ),
          AppSpacing.smGap,
          Row(children: [
            Expanded(
              child: Text(
                'Online / reserve slot',
                style: AppTextStyles.bodySm,
              ),
            ),
            UChip(
              label: p.online ? 'Yes' : 'No',
              isActive: p.online,
              onTap: () => setState(() => p.online = !p.online),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _onlineCard() {
    return UCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Schedule into online / reserve periods',
              style: AppTextStyles.bodyMedium),
          AppSpacing.xsGap,
          Text(
            'Off by default: the evening slot exists on the printed grid but '
            'the department keeps it in reserve. Turn it on to let the solver '
            'use every period marked as online above.',
            style: AppTextStyles.caption,
          ),
          AppSpacing.smGap,
          Row(children: [
            UChip(
              label: 'On',
              isActive: _allowOnline,
              onTap: () => setState(() => _allowOnline = true),
            ),
            AppSpacing.smHGap,
            UChip(
              label: 'Off',
              isActive: !_allowOnline,
              onTap: () => setState(() => _allowOnline = false),
            ),
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
