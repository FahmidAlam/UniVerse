import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/constants/app_enums.dart';
import 'package:universe/core/models/profile_model.dart';
import 'package:universe/core/models/routine_model.dart';
import 'package:universe/core/utils/date_utils.dart';
import 'package:universe/core/utils/safe_change_notifier.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/features/routine/services/routine_service.dart';
import 'package:universe/features/teacher/services/teacher_service.dart';

// PHASE 4: Student dashboard controller with lazy Supabase service access, deterministic clock,
// date-scoped cancellation awareness, joint-section summary, and tomorrow first-class preview.
class StudentDashboardController extends SafeChangeNotifier {
  RoutineService? _service;
  RoutineService get _routineService => _service ??= RoutineService();

  final AuthController authController;
  final Future<List<RoutineEntry>> Function(String batch, String section)?
      routineLoader;
  final Future<Set<String>> Function(List<String> routineIds)?
      cancellationKeysLoader;
  final DateTime Function()? _clock;

  StudentDashboardController({
    required this.authController,
    this.routineLoader,
    this.cancellationKeysLoader,
    DateTime Function()? clock,
    List<RoutineEntry>? initialEntries,
    Set<String>? initialCancelledKeys,
  }) : _clock = clock {
    if (initialEntries != null) {
      _all = List<RoutineEntry>.of(initialEntries);
      _hasLoaded = true;
    }
    if (initialCancelledKeys != null) {
      _cancelledKeys = Set<String>.of(initialCancelledKeys);
    }
  }

  List<RoutineEntry> _all = [];
  Set<String> _cancelledKeys = <String>{};
  bool _isLoading = false;
  String? _errorMessage;
  bool _hasLoaded = false;

  DateTime get now => _clock?.call() ?? DateTime.now();
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasLoaded => _hasLoaded;
  List<RoutineEntry> get allEntries => List.unmodifiable(_all);

  Profile? get me {
    final map = authController.profile;
    return map == null ? null : Profile.fromMap(map);
  }

  static const Map<int, String> _weekdayFull = {
    7: 'Sunday',
    1: 'Monday',
    2: 'Tuesday',
    3: 'Wednesday',
    4: 'Thursday',
    5: 'Friday',
    6: 'Saturday',
  };

  static String _dateKey(DateTime d) => AppDateUtils.dateKey(d);

  String? get _todayFull => _weekdayFull[now.weekday];
  String get todayFullName => _todayFull ?? 'Today';

  List<RoutineEntry> get todaysClasses {
    final day = _todayFull;
    if (day == null) return const [];
    final list = _all.where((e) => e.day == day).toList()
      ..sort((a, b) => a.timeStart.compareTo(b.timeStart));
    return list;
  }

  bool get isWeekendToday {
    // Dynamic section weekend / off-day based on whether there are zero scheduled classes today
    return todaysClasses.isEmpty;
  }

  bool get isClassDayToday => !isWeekendToday;

  /// Scans across the full 7-day cycle to find the next upcoming class session.
  ({RoutineEntry entry, int daysAhead, String dayName})? get nextUpcomingClass {
    final current = now;
    for (var i = 1; i <= 7; i++) {
      final target = current.add(Duration(days: i));
      final dayName = _weekdayFull[target.weekday];
      if (dayName == null) continue;
      final list = _all.where((e) => e.day == dayName).toList()
        ..sort((a, b) => a.timeStart.compareTo(b.timeStart));
      if (list.isNotEmpty) {
        return (entry: list.first, daysAhead: i, dayName: dayName);
      }
    }
    return null;
  }

  // PHASE 4: Joint sections (e.g., B+C) matched by RoutineEntry.matchesStudent are surfaced in the cohort strip.
  List<String> get jointSections {
    final sections = _all
        .map((e) => e.section.trim())
        .where((s) => s.contains('+'))
        .toSet()
        .toList()
      ..sort();
    return sections;
  }

  String get cohortHeaderLabel {
    final m = me;
    final batch = m?.batch;
    final section = m?.section;
    if (batch == null || section == null || batch.isEmpty || section.isEmpty) {
      return m?.roleLabel ?? 'Student Cohort';
    }
    final joints = jointSections;
    if (joints.isNotEmpty) {
      return 'Batch $batch · Section $section (+ ${joints.join(", ")} Joint)';
    }
    return 'Batch $batch · Section $section (+ Joint Sections)';
  }

  bool isCancelledToday(RoutineEntry e) {
    final key = '${e.id}|${_dateKey(now)}';
    return _cancelledKeys.contains(key);
  }

  ClassStatus statusForToday(RoutineEntry e) {
    if (isCancelledToday(e)) return ClassStatus.cancelled;
    return e.statusOn(now, isToday: true);
  }

  int get weeklyCount => _all.length;
  int get todayCount => todaysClasses.length;

  /// 7-day distribution of scheduled classes across Sunday–Saturday.
  Map<String, int> get classesCountPerDay {
    final counts = <String, int>{
      'Sun': 0,
      'Mon': 0,
      'Tue': 0,
      'Wed': 0,
      'Thu': 0,
      'Fri': 0,
      'Sat': 0,
    };
    for (final e in _all) {
      final idx = AppConstants.weekDays.indexOf(e.day);
      if (idx >= 0 && idx < AppConstants.weekDaysShort.length) {
        final short = AppConstants.weekDaysShort[idx];
        counts[short] = (counts[short] ?? 0) + 1;
      }
    }
    return counts;
  }

  int get completedTodayCount => todaysClasses
      .where(
        (e) =>
            !isCancelledToday(e) &&
            e.statusOn(now, isToday: true) == ClassStatus.done,
      )
      .length;

  int get cancelledTodayCount => todaysClasses.where(isCancelledToday).length;

  RoutineEntry? get liveClass {
    final current = now;
    for (final e in todaysClasses) {
      if (isCancelledToday(e)) continue;
      if (e.statusOn(current, isToday: true) == ClassStatus.live) return e;
    }
    return null;
  }

  RoutineEntry? get nextClass {
    final current = now;
    for (final e in todaysClasses) {
      if (isCancelledToday(e)) continue;
      if (e.startOn(current).isAfter(current)) return e;
    }
    return null;
  }

  int get remainingToday {
    final current = now;
    return todaysClasses
        .where((e) => !isCancelledToday(e) && e.endOn(current).isAfter(current))
        .length;
  }

  RoutineEntry? get tomorrowFirstClass {
    final tomorrow = now.add(const Duration(days: 1));
    final dayName = _weekdayFull[tomorrow.weekday];
    if (dayName == null) return null;
    final list = _all.where((e) => e.day == dayName).toList()
      ..sort((a, b) => a.timeStart.compareTo(b.timeStart));
    return list.isEmpty ? null : list.first;
  }

  Future<void> load() async {
    final m = me;
    if (m == null) {
      _hasLoaded = true;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final batch = m.batch ?? '';
      final section = m.section ?? '';
      if (routineLoader != null) {
        final rows = await routineLoader!(batch, section);
        _all = rows
            .where(
              (r) =>
                  batch.isEmpty ||
                  section.isEmpty ||
                  r.matchesStudent(batch, section),
            )
            .toList()
          ..sort((a, b) => a.timeStart.compareTo(b.timeStart));
      } else {
        _all = await _routineService.fetchForStudent(
          batch: batch,
          section: section,
        );
      }

      if (cancellationKeysLoader != null) {
        _cancelledKeys =
            await cancellationKeysLoader!(_all.map((e) => e.id).toList());
      } else if (routineLoader == null) {
        try {
          _cancelledKeys = await TeacherService().fetchUpcomingCancellationKeys(
            _all.map((e) => e.id).toList(),
          );
        } catch (_) {
          // Best-effort cancellation lookup; do not fail routine consultation.
        }
      }
    } catch (e) {
      _errorMessage = 'Could not load your dashboard.';
    }

    _isLoading = false;
    _hasLoaded = true;
    notifyListeners();
  }
}
