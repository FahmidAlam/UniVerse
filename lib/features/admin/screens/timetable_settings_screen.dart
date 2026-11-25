// Timetable Settings — Visual Studio for Institutional Scheduling & Committee Policy Rules.
//
// Everything on this screen configures the university's 7-day academic week,
// R15 6/7-slot period grid, Jummah prayer hard constraints, committee rules (R1–R14),
// and CP-SAT soft objective weights.
//
//     Admin UI  ->  timetable_settings  ->  buildEngineConfig()  ->  solver

import 'package:flutter/material.dart';
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/models/timetable_config_model.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/core/utils/clock_time.dart';
import 'package:universe/features/admin/controllers/timetable_settings_controller.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/shared/widgets/desktop_shell_scope.dart';
import 'package:universe/shared/widgets/u_app_bar.dart';
import 'package:universe/shared/widgets/u_button.dart';
import 'package:universe/shared/widgets/u_card.dart';
import 'package:universe/shared/widgets/u_chip.dart';
import 'package:universe/shared/widgets/u_loading.dart';
import 'package:universe/shared/widgets/u_segmented_control.dart';
import 'package:universe/shared/widgets/u_text_field.dart';

const Map<String, String> _kWeights = {
  'different_days': 'Spread course across different days (Rule R13)',
  'compactness': 'Fewer class-days per section & gap avoidance (Rule R3)',
  'spread': 'Balance daily teaching load across days',
  'late_slot': 'Avoid scheduling into late/evening period (Rule R15)',
};

const Map<String, int> _kWeightDefaults = {
  'different_days': 8,
  'compactness': 3,
  'spread': 2,
  'late_slot': 1,
};

/// Spreadsheet columns the printed template reserves for periods (G is the break column).
const List<String> _kPeriodColumns = ['D', 'E', 'F', 'H', 'I', 'J', 'K'];

/// One editable period row draft.
class _PeriodDraft {
  int idx;
  final TextEditingController start;
  final TextEditingController end;
  String col;
  bool online;
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
  State<TimetableSettingsScreen> createState() => _TimetableSettingsScreenState();
}

class _TimetableSettingsScreenState extends State<TimetableSettingsScreen> {
  late final TimetableSettingsController _controller;
  final _semester = TextEditingController();
  final _weeks = TextEditingController();
  final _fixedSessions = TextEditingController();
  final Map<String, TextEditingController> _weightCtrls = {
    for (final k in _kWeights.keys) k: TextEditingController(),
  };

  List<_PeriodDraft> _periods = [];
  Set<String> _workingDays = {};
  bool _allowOnline = false;
  String _serviceScope = 'resource_only';
  bool _loaded = false;
  String? _formError;
  int _activeTab = 0; // 0: Term Clock & R15, 1: Committee Rules (R1–R14), 2: Optimization Profiles
  bool _isDirty = false;
  int _slotMode = 6; // R15 toggle: 6 Slots / Day vs 7 Slots / Day

  @override
  void initState() {
    super.initState();
    _controller = TimetableSettingsController();
    _controller.load().then((_) => _hydrate());
    _semester.addListener(_markDirty);
    _weeks.addListener(_markDirty);
    _fixedSessions.addListener(_markDirty);
    for (final c in _weightCtrls.values) {
      c.addListener(_markDirty);
    }
  }

  void _markDirty() {
    if (!_isDirty && _loaded && mounted) {
      setState(() => _isDirty = true);
    }
  }

  void _hydrate() {
    final s = _controller.settings;
    _semester.text = s.semesterLabel ?? '';
    _weeks.text = s.weeksInTerm.toString();
    _fixedSessions.text = (s.fixedSessionsPerWeek ?? 0) > 0
        ? s.fixedSessionsPerWeek.toString()
        : '';
    _serviceScope = s.serviceScope;
    _allowOnline = s.allowOnlinePeriods;
    _workingDays = s.workingDays.isEmpty
        ? AppConstants.weekDays.toSet()
        : s.workingDays.toSet();

    for (final k in _kWeights.keys) {
      _weightCtrls[k]!.text = s.weight(k, _kWeightDefaults[k] ?? 1).toString();
    }

    final blockedFor = <int, Set<String>>{};
    s.blockedPeriods.forEach((day, idxs) {
      for (final i in idxs) {
        blockedFor.putIfAbsent(i, () => <String>{}).add(day);
      }
    });

    if (s.fridayNoP4) {
      blockedFor.putIfAbsent(4, () => <String>{}).add('Friday');
    }
    final online = {...s.onlinePeriods, ...s.excludedPeriods};

    _periods = [
      for (var i = 0; i < s.periods.length; i++)
        if (s.periods[i] is Map)
          _buildDraft((s.periods[i] as Map).cast<String, dynamic>(), i, blockedFor, online),
    ];

    if (_periods.isEmpty) {
      // Seed standard default R15 6-period grid with Period 4 as break/Jummah
      _periods = [
        _PeriodDraft(idx: 1, start: '08:50', end: '10:05', col: 'D'),
        _PeriodDraft(idx: 2, start: '10:10', end: '11:25', col: 'E'),
        _PeriodDraft(idx: 3, start: '11:30', end: '12:45', col: 'F'),
        _PeriodDraft(
          idx: 4,
          start: '12:50',
          end: '02:05',
          col: 'H',
          blockedOn: {'Friday'},
        ),
        _PeriodDraft(idx: 5, start: '02:10', end: '03:25', col: 'I'),
        _PeriodDraft(idx: 6, start: '03:30', end: '04:45', col: 'J'),
      ];
    }

    for (final p in _periods) {
      p.start.addListener(_markDirty);
      p.end.addListener(_markDirty);
    }

    _slotMode = _periods.length >= 7 ? 7 : 6;
    if (!mounted) return;
    setState(() {
      _loaded = true;
      _isDirty = false;
    });
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
    _fixedSessions.dispose();
    for (final c in _weightCtrls.values) {
      c.dispose();
    }
    for (final p in _periods) {
      p.dispose();
    }
    super.dispose();
  }

  void _toggleSlotCount(int targetSlots) {
    if (_slotMode == targetSlots) return;
    setState(() {
      _slotMode = targetSlots;
      if (targetSlots == 7 && _periods.length < 7) {
        final last = _periods.isEmpty ? null : _periods.last;
        final p7 = _PeriodDraft(
          idx: 7,
          start: last?.end.text.isNotEmpty == true ? last!.end.text : '04:50',
          end: '06:05',
          col: _nextColumn(6),
        );
        p7.start.addListener(_markDirty);
        p7.end.addListener(_markDirty);
        _periods.add(p7);
      } else if (targetSlots == 6 && _periods.length >= 7) {
        final removed = _periods.removeLast();
        removed.dispose();
      }
      _isDirty = true;
    });
  }

  void _applyOptimizationPreset(String preset) {
    setState(() {
      if (preset == 'strict') {
        _weightCtrls['different_days']!.text = '10';
        _weightCtrls['compactness']!.text = '6';
        _weightCtrls['spread']!.text = '4';
        _weightCtrls['late_slot']!.text = '2';
      } else if (preset == 'balanced') {
        _weightCtrls['different_days']!.text = '8';
        _weightCtrls['compactness']!.text = '3';
        _weightCtrls['spread']!.text = '2';
        _weightCtrls['late_slot']!.text = '1';
      } else if (preset == 'relaxed') {
        _weightCtrls['different_days']!.text = '5';
        _weightCtrls['compactness']!.text = '2';
        _weightCtrls['spread']!.text = '1';
        _weightCtrls['late_slot']!.text = '0';
      }
      _isDirty = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Applied optimization preset: $preset'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _restoreDefaultWeights() {
    setState(() {
      for (final k in _kWeights.keys) {
        _weightCtrls[k]!.text = (_kWeightDefaults[k] ?? 1).toString();
      }
      _isDirty = true;
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

    final fixedText = _fixedSessions.text.trim();
    int? fixedSessions;
    if (fixedText.isNotEmpty) {
      fixedSessions = int.tryParse(fixedText);
      if (fixedSessions == null ||
          fixedSessions < 1 ||
          fixedSessions > AppConstants.weekDays.length) {
        setState(() => _formError =
            'Classes per week must be between 1 and '
            '${AppConstants.weekDays.length}, or empty to work it out per course.');
        return;
      }
    }
    setState(() => _formError = null);

    final blocked = <String, List<int>>{};
    for (final p in _periods) {
      for (final day in p.blockedOn) {
        blocked.putIfAbsent(day, () => <int>[]).add(p.idx);
      }
    }

    final updated = TimetableSettings(
      semesterLabel: _semester.text.trim().isEmpty ? null : _semester.text.trim(),
      periods: periods,
      workingDays: [
        for (final d in AppConstants.weekDays)
          if (_workingDays.contains(d)) d,
      ],
      weeksInTerm: weeks,
      fixedSessionsPerWeek: fixedSessions,
      blockedPeriods: blocked,
      onlinePeriods: [
        for (final p in _periods)
          if (p.online) p.idx,
      ],
      allowOnlinePeriods: _allowOnline,
      excludedPeriods: const [],
      semesterMap: _controller.settings.semesterMap,
      fridayNoP4: blocked['Friday']?.contains(4) ?? true,
      serviceScope: _serviceScope,
      weights: {
        for (final k in _kWeights.keys)
          k: int.tryParse(_weightCtrls[k]!.text.trim()) ?? _kWeightDefaults[k] ?? 1,
      },
    );

    final ok = await _controller.save(updated);
    if (!mounted) return;
    if (ok) {
      setState(() => _isDirty = false);
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? 'Settings saved. Solver will generate with updated institutional rules.'
          : 'Could not save settings.'),
      backgroundColor: ok ? AppColors.roleTeacher : AppColors.error,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDesktopShell = DesktopShellScope.isDesktopOf(context);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: isDesktopShell
          ? null
          : const UAppBar(
              title: 'Timetable Settings',
              subtitle: '7-Day Term Clock, Committee Rules & Engine Weights',
            ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.isLoading || !_loaded) {
            return const Center(child: ULoading.spinner());
          }

          return Column(
            children: [
              // Studio Tab Navigator
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  AppSpacing.md,
                  AppSpacing.screenH,
                  AppSpacing.sm,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: USegmentedControl<int>(
                      selected: _activeTab,
                      onChanged: (idx) => setState(() => _activeTab = idx),
                      segments: const [
                        USegment(
                          value: 0,
                          label: '7-Day Clock & R15 Timeline',
                          icon: PhosphorIconsRegular.clock,
                        ),
                        USegment(
                          value: 1,
                          label: 'Committee Rules (R1–R14)',
                          icon: PhosphorIconsRegular.shieldCheck,
                        ),
                        USegment(
                          value: 2,
                          label: 'Engine Profiles & Weights',
                          icon: PhosphorIconsRegular.slidersHorizontal,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Studio Tab Views
              Expanded(
                child: ListView(
                  padding: AppSpacing.screenPadding,
                  children: [
                    if (_formError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        margin: const EdgeInsets.only(bottom: AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.15),
                          borderRadius: AppSpacing.radiusMd,
                          border: Border.all(color: AppColors.error),
                        ),
                        child: Text(_formError!, style: AppTextStyles.bodyError),
                      ),
                    ],

                    if (_activeTab == 0) _buildTab0ClockAndTimeline(),
                    if (_activeTab == 1) _buildTab1CommitteeRules(),
                    if (_activeTab == 2) _buildTab2OptimizationProfiles(),

                    const SizedBox(height: 80), // spacer for sticky bottom dirty bar
                  ],
                ),
              ),

              // Bottom Dirty State Save Bar
              if (_isDirty) _buildStickyDirtyBar(),
            ],
          );
        },
      ),
    );
  }

  // =========================================================================
  // TAB 0: 7-DAY TERM CLOCK & R15 TIMELINE
  // =========================================================================
  Widget _buildTab0ClockAndTimeline() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(PhosphorIconsRegular.calendar, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              'SECTION 1 · CORE TERM GRID & TIMINGS (R15)',
              style: AppTextStyles.labelCaps.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        UCard(
          isTopLit: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Academic Term Parameters', style: AppTextStyles.h4),
              const SizedBox(height: 4),
              Text(
                'Define institutional term length, course class cadence, and active teaching days.',
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
              ),
              AppSpacing.mdGap,
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: UTextField(
                      label: 'Semester Label',
                      hint: 'e.g. Summer 2025',
                      controller: _semester,
                      prefixIcon: PhosphorIconsRegular.calendarBlank,
                    ),
                  ),
                  AppSpacing.mdGap,
                  Expanded(
                    child: UTextField(
                      label: 'Teaching Weeks',
                      hint: '14',
                      controller: _weeks,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  AppSpacing.mdGap,
                  Expanded(
                    child: UTextField(
                      label: 'Classes/Wk Override',
                      hint: 'Empty = automatic',
                      controller: _fixedSessions,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        AppSpacing.mdGap,

        // 7-Day Institutional Working Days Strip
        _workingDaysCard(),
        AppSpacing.mdGap,

        // R15 Slot Count Toggle
        UCard(
          isTopLit: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('R15 Daily Period Structure', style: AppTextStyles.bodyMedium),
                        const SizedBox(height: 2),
                        Text(
                          'Configure daily periods per academic day (6 vs 7 slots). Period 4 is reserved for Lunch/Jummah Prayer.',
                          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  USegmentedControl<int>(
                    compact: true,
                    selected: _slotMode,
                    onChanged: _toggleSlotCount,
                    segments: const [
                      USegment(value: 6, label: '6 Slots / Day (Standard R15)'),
                      USegment(value: 7, label: '7 Slots / Day (Extended)'),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        AppSpacing.mdGap,

        // Daily Periods Timeline Cards
        for (var i = 0; i < _periods.length; i++) ...[
          _periodCard(i),
          AppSpacing.mdGap,
        ],

        _onlineCard(),
        AppSpacing.lgGap,
        Row(
          children: [
            const Icon(Icons.balance_outlined, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              'SECTION 2 · COMMITTEE SOLVER RULES & WEIGHTS (R1–R14)',
              style: AppTextStyles.labelCaps.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'View or manage complete rule governance across cohorts, faculty, and room pools.',
          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        ),
        AppSpacing.smGap,
        _serviceScopeCard(),
      ],
    );
  }

  // =========================================================================
  // TAB 1: COMMITTEE POLICY RULES (R1–R14)
  // =========================================================================
  Widget _buildTab1CommitteeRules() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UCard(
          isTopLit: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(PhosphorIconsRegular.shieldCheck, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text('Routine Committee Policy Rules (R1–R14)', style: AppTextStyles.h4),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Comprehensive rule governance enforcing solver constraints across cohorts, faculty availability, and room classifications.',
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        AppSpacing.mdGap,

        // Group 1: Cohort & Section Weekend Rules (R1–R3)
        _buildRuleGroup(
          title: 'Cohort & Section Weekend Governance (Rules R1–R3)',
          description: 'Enforces student rest cycles, parity across sections, and lecture compactness.',
          rules: [
            _RuleItem(
              code: 'R1',
              title: 'Staggered Section Weekends (2 Consecutive Days Off)',
              description: 'Each section receives 2 consecutive days off out of the 7-day week (e.g., Thu+Fri or Sun+Mon).',
              statusText: 'Enforced Active',
              isSemantic: false,
            ),
            _RuleItem(
              code: 'R2',
              title: 'Section Day-Off Parity (max variance ≤ 1 day)',
              description: 'All sections within the same batch must have approximately equal total weekly days off.',
              statusText: 'Enforced Active',
              isSemantic: false,
            ),
            _RuleItem(
              code: 'R3',
              title: 'Cohort Class Compactness & Gap Minimization',
              description: 'Minimizes scattered idle gaps between lectures for student cohorts on scheduled days.',
              statusText: 'Engine Soft Objective',
              isSemantic: true,
            ),
          ],
        ),
        AppSpacing.mdGap,

        // Group 2: Faculty Availability & Workload Rules (R4–R9)
        _buildRuleGroup(
          title: 'Faculty Availability & Workload Matrix (Rules R4–R9)',
          description: 'Governs service blocks, traveling adjunct windows, and weekly teaching limits.',
          rules: [
            _RuleItem(
              code: 'R4',
              title: 'External Service Blocks (Non-CSE Service Classes)',
              description: 'Blocks CSE faculty teaching time when they conduct service classes in Law, BuA, EEE, or English.',
              statusText: _serviceScope == 'resource_only' ? 'Resource-Only Active' : 'Ignored',
              isSemantic: _serviceScope != 'resource_only',
              customControl: _serviceScopeCard(),
            ),
            _RuleItem(
              code: 'R5',
              title: 'External Guest Faculty Declared Windows',
              description: 'Guest faculty slots are strictly restricted to their declared 2-day teaching availability windows.',
              statusText: 'Enforced Active',
              isSemantic: false,
            ),
            _RuleItem(
              code: 'R6',
              title: '7-Day Faculty Teaching Days (4–5 Working Days)',
              description: 'Permanent faculty work 4 to 5 days across the 7-day operational week.',
              statusText: '4–5 Days / Week',
              isSemantic: false,
            ),
            _RuleItem(
              code: 'R7',
              title: '7-Day Faculty Day-Off Allocation (2–3 Days Off)',
              description: 'Permanent faculty receive 2 to 3 days off per week (4+3=7 or 5+2=7).',
              statusText: '2–3 Days Off',
              isSemantic: false,
            ),
            _RuleItem(
              code: 'R8',
              title: 'Faculty Preferred Slots Priority',
              description: 'Soft priority given to faculty-declared preferred teaching slots during solver placement.',
              statusText: 'Weighted Priority',
              isSemantic: true,
            ),
            _RuleItem(
              code: 'R9',
              title: 'SUST Adjunct Half-Day Compactness',
              description: 'Traveling SUST adjunct faculty sessions are clustered before or after the 1:00 PM prayer break.',
              statusText: 'Before/After Break',
              isSemantic: true,
            ),
          ],
        ),
        AppSpacing.mdGap,

        // Group 3: Room & Course Rules (R10–R14)
        _buildRuleGroup(
          title: 'Room & Course Classification Rules (Rules R10–R14)',
          description: 'Enforces lab exclusivity, single-day theory blocks, and physical capacity constraints.',
          rules: [
            _RuleItem(
              code: 'R10',
              title: 'ECL Lab Exclusivity (EEE Dept Lab)',
              description: 'EEE department sessional courses are strictly assigned to the ECL lab.',
              statusText: 'Hard Exclusivity',
              isSemantic: false,
            ),
            _RuleItem(
              code: 'R11',
              title: 'Physics Lab Exclusivity',
              description: 'PHY-1102 and PHY-1202 courses are strictly bound to the Physics Lab.',
              statusText: 'Hard Exclusivity',
              isSemantic: false,
            ),
            _RuleItem(
              code: 'R12',
              title: 'Sessional Consecutive Slots (1.5 Cr vs >1.5 Cr)',
              description: '≤1.5 Cr sessionals = 2 lab slots; >1.5 Cr = 3 slots with at least 2 consecutive.',
              statusText: 'Consecutive Lab Rule',
              isSemantic: false,
            ),
            _RuleItem(
              code: 'R13',
              title: '1–2 Credit CSE Theory Block (Same Day, Same Room)',
              description: '1–2 Cr CSE theory courses are scheduled on 1 day with 2 consecutive slots in the same room.',
              statusText: '1-Day Block Rule',
              isSemantic: true,
            ),
            _RuleItem(
              code: 'R14',
              title: 'Room Capacity & Pool Integrity',
              description: 'Cohort enrollment must never exceed assigned room capacity.',
              statusText: 'Capacity Bound',
              isSemantic: false,
            ),
          ],
        ),
      ],
    );
  }

  // =========================================================================
  // TAB 2: ENGINE OPTIMIZATION PROFILE (CP-SAT WEIGHTS)
  // =========================================================================
  Widget _buildTab2OptimizationProfiles() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UCard(
          isTopLit: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(PhosphorIconsRegular.magicWand, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text('Engine Optimization Profiles (CP-SAT Solver Weights)', style: AppTextStyles.h4),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Configure mathematical penalty weights guiding the OR-Tools CP-SAT solver. '
                'Higher values heavily penalize violations of soft quality objectives.',
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
              ),
              AppSpacing.mdGap,

              // 3 Optimization Preset Cards
              Text('SOLVER PRESETS', style: AppTextStyles.labelCaps.copyWith(fontSize: 10)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildPresetCard(
                      title: 'Strict Compliance',
                      desc: 'Heavily penalizes gaps and schedule spread. Max rule enforcement.',
                      presetKey: 'strict',
                      icon: PhosphorIconsRegular.shieldCheck,
                    ),
                  ),
                  AppSpacing.smGap,
                  Expanded(
                    child: _buildPresetCard(
                      title: 'Balanced (Default)',
                      desc: 'Optimized balance of student compactness and faculty preferences.',
                      presetKey: 'balanced',
                      icon: PhosphorIconsRegular.sparkle,
                      isDefault: true,
                    ),
                  ),
                  AppSpacing.smGap,
                  Expanded(
                    child: _buildPresetCard(
                      title: 'Relaxed Feasibility',
                      desc: 'Faster solver convergence with lower penalty thresholds.',
                      presetKey: 'relaxed',
                      icon: PhosphorIconsRegular.sliders,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        AppSpacing.mdGap,

        // Soft-Constraint Sliders & Inputs
        UCard(
          isTopLit: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Soft-Constraint Objective Weights', style: AppTextStyles.bodyMedium),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _restoreDefaultWeights,
                    icon: const Icon(PhosphorIconsRegular.arrowCounterClockwise, size: 14),
                    label: const Text('Restore Defaults'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Adjust relative importance (0 = disabled, 10 = maximum penalty).',
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
              ),
              AppSpacing.mdGap,
              for (final entry in _kWeights.entries) ...[
                _buildWeightSliderRow(entry.key, entry.value),
                const Divider(color: AppColors.border, height: AppSpacing.lg),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPresetCard({
    required String title,
    required String desc,
    required String presetKey,
    required IconData icon,
    bool isDefault = false,
  }) {
    return InkWell(
      onTap: () => _applyOptimizationPreset(presetKey),
      borderRadius: AppSpacing.radiusMd,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: AppSpacing.radiusMd,
          border: Border.all(
            color: isDefault ? AppColors.primary.withValues(alpha: 0.6) : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: isDefault ? AppColors.primary : AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: AppTextStyles.bodySmMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDefault ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(desc, style: AppTextStyles.caption.copyWith(fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightSliderRow(String key, String description) {
    final ctrl = _weightCtrls[key]!;
    final int currentVal = int.tryParse(ctrl.text.trim()) ?? 1;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(description, style: AppTextStyles.bodySmMedium),
                Text('Engine weight key: $key', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
              ],
            ),
          ),
          AppSpacing.mdGap,
          Expanded(
            flex: 2,
            child: Slider(
              value: currentVal.clamp(0, 10).toDouble(),
              min: 0,
              max: 10,
              divisions: 10,
              activeColor: AppColors.primary,
              onChanged: (v) {
                setState(() {
                  ctrl.text = v.round().toString();
                  _isDirty = true;
                });
              },
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              '$currentVal',
              textAlign: TextAlign.center,
              style: AppTextStyles.numeric.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleGroup({
    required String title,
    required String description,
    required List<_RuleItem> rules,
  }) {
    return UCard(
      isTopLit: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.bodyMedium),
          const SizedBox(height: 2),
          Text(description, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.md),
          for (final rule in rules) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: rule.isSemantic
                              ? AppColors.info.withValues(alpha: 0.15)
                              : AppColors.surfaceElevated,
                          borderRadius: AppSpacing.radiusSm,
                        ),
                        child: Text(
                          rule.code,
                          style: AppTextStyles.caption.copyWith(
                            fontWeight: FontWeight.bold,
                            color: rule.isSemantic ? AppColors.info : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          rule.title,
                          style: AppTextStyles.bodySmMedium.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: AppSpacing.radiusSm,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          rule.statusText,
                          style: AppTextStyles.caption.copyWith(fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 32),
                    child: Text(
                      rule.description,
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                  if (rule.customControl != null) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 32),
                      child: rule.customControl!,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // =========================================================================
  // HELPER CARDS (Working Days, Period Card, Online Card, Service Scope)
  // =========================================================================
  Widget _workingDaysCard() {
    return UCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Working days', style: AppTextStyles.bodyMedium),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: AppSpacing.radiusSm,
                ),
                child: Text(
                  '7-Day Operational Week (Sun–Sat)',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.xsGap,
          Text(
            'Days the department teaches across the full 7-day institutional week. '
            'The engine schedules classes across Sunday through Saturday. Friday Jummah Prayer (Period 4) is hard-blocked.',
            style: AppTextStyles.caption,
          ),
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
                    _isDirty = true;
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
                onPressed: () {
                  setState(() {
                    _periods.removeAt(i).dispose();
                    for (var j = 0; j < _periods.length; j++) {
                      _periods[j]
                        ..idx = j + 1
                        ..col = _nextColumn(j);
                    }
                    _isDirty = true;
                  });
                },
              ),
            ],
          ),
          if (p.idx == 4) ...[
            AppSpacing.xsGap,
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: AppSpacing.radiusSm,
                border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  const Icon(PhosphorIconsRegular.lock, size: 14, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Hard Constraint: Friday Jummah Prayer Block (friday_no_p4 — Zero classes permitted during Friday Jummah window)',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
                    _isDirty = true;
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
              onTap: () => setState(() {
                p.online = !p.online;
                _isDirty = true;
              }),
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
          Text('Schedule into online / reserve periods', style: AppTextStyles.bodyMedium),
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
              onTap: () => setState(() {
                _allowOnline = true;
                _isDirty = true;
              }),
            ),
            AppSpacing.smHGap,
            UChip(
              label: 'Off',
              isActive: !_allowOnline,
              onTap: () => setState(() {
                _allowOnline = false;
                _isDirty = true;
              }),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _serviceScopeCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: AppSpacing.radiusSm,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text('Service Class Scope:', style: AppTextStyles.bodySm),
          ),
          UChip(
            label: 'Resource-only',
            isActive: _serviceScope == 'resource_only',
            onTap: () => setState(() {
              _serviceScope = 'resource_only';
              _isDirty = true;
            }),
          ),
          AppSpacing.smHGap,
          UChip(
            label: 'Ignore',
            isActive: _serviceScope == 'ignore',
            onTap: () => setState(() {
              _serviceScope = 'ignore';
              _isDirty = true;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyDirtyBar() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenH,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        border: const Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.warning,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Unsaved Modifications · Review changes before generating',
              style: AppTextStyles.bodySmMedium.copyWith(color: AppColors.warning),
            ),
          ),
          TextButton(
            onPressed: () {
              _hydrate();
              setState(() => _isDirty = false);
            },
            child: Text('Discard', style: AppTextStyles.button.copyWith(color: AppColors.textSecondary)),
          ),
          AppSpacing.smHGap,
          UButton(
            label: 'Save Settings',
            icon: PhosphorIconsRegular.floppyDisk,
            isLoading: _controller.isSaving,
            fullWidth: false,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}

class _RuleItem {
  final String code;
  final String title;
  final String description;
  final String statusText;
  final bool isSemantic;
  final Widget? customControl;

  _RuleItem({
    required this.code,
    required this.title,
    required this.description,
    required this.statusText,
    this.isSemantic = false,
    this.customControl,
  });
}
