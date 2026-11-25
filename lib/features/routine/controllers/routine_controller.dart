import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/constants/app_enums.dart';
import 'package:universe/core/models/profile_model.dart';
import 'package:universe/core/models/routine_model.dart';
import 'package:universe/core/utils/safe_change_notifier.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/features/routine/services/routine_service.dart';
import 'package:universe/features/teacher/services/teacher_service.dart';

// PHASE 4: Routine controller with lazy service initialization, deterministic clock,
// active lens summary, date-scoped cancellation awareness, and swipe day-stepping.
class RoutineController extends SafeChangeNotifier {
  RoutineService? _service;
  RoutineService get _routineService => _service ??= RoutineService();

  final AuthController authController;
  final Future<List<RoutineEntry>> Function()? routineLoader;
  final Future<Set<String>> Function(List<String> routineIds)?
      cancellationKeysLoader;
  final DateTime Function()? _clock;

  RoutineController({
    required this.authController,
    this.routineLoader,
    this.cancellationKeysLoader,
    DateTime Function()? clock,
    List<RoutineEntry>? initialEntries,
    Set<String>? initialCancelledKeys,
    String? initialSelectedDay,
  }) : _clock = clock {
    _selectedDay = initialSelectedDay ?? _todayShortFor(now);
    if (initialEntries != null) {
      _entries = List<RoutineEntry>.of(initialEntries);
      _hasLoaded = true;
    }
    if (initialCancelledKeys != null) {
      _cancelledKeys = Set<String>.of(initialCancelledKeys);
    }
  }

  List<RoutineEntry> _entries = [];
  Set<String> _cancelledKeys = <String>{};
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _errorMessage;
  late String _selectedDay;

  DateTime get now => _clock?.call() ?? DateTime.now();
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get errorMessage => _errorMessage;
  String get selectedDay => _selectedDay;

  Profile? get me {
    final map = authController.profile;
    return map == null ? null : Profile.fromMap(map);
  }

  Profile? get _me => me;

  bool get isTeacherView => _me?.isTeacher ?? false;

  static String _todayShortFor(DateTime dt) {
    const map = {
      7: 'Sun',
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
    };
    return map[dt.weekday] ?? 'Sun';
  }

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String get selectedFullDay {
    final i = AppConstants.weekDaysShort.indexOf(_selectedDay);
    return i >= 0 ? AppConstants.weekDays[i] : _selectedDay;
  }

  String get todayFullDay {
    final short = _todayShortFor(now);
    final i = AppConstants.weekDaysShort.indexOf(short);
    return i >= 0 ? AppConstants.weekDays[i] : 'Sunday';
  }

  bool get isSelectedDayToday => _selectedDay == _todayShortFor(now);

  List<String> get jointSections {
    final sections = _entries
        .map((e) => e.section.trim())
        .where((s) => s.contains('+'))
        .toSet()
        .toList()
      ..sort();
    return sections;
  }

  // PHASE 4: Unified routine lens label for the Connected Filter & View Context Bar.
  String get activeLensLabel {
    final m = _me;
    if (isTeacherView) {
      final code = (m?.teacherCode?.trim().isNotEmpty ?? false)
          ? m!.teacherCode!.trim()
          : 'FACULTY';
      return 'Faculty Schedule · $code';
    }
    final batch = (m?.batch?.trim().isNotEmpty ?? false) ? m!.batch!.trim() : '—';
    final section =
        (m?.section?.trim().isNotEmpty ?? false) ? m!.section!.trim() : '—';
    final joints = jointSections;
    if (joints.isNotEmpty) {
      return 'Batch $batch · Section $section & Joint Sections (${joints.join(", ")})';
    }
    return 'Batch $batch · Section $section & Joint Sections';
  }

  bool isCancelledToday(RoutineEntry e) {
    final key = '${e.id}|${_dateKey(now)}';
    return _cancelledKeys.contains(key);
  }

  Set<String> get cancelledEntryIdsToday {
    final todaySuffix = '|${_dateKey(now)}';
    return _cancelledKeys
        .where((k) => k.endsWith(todaySuffix))
        .map((k) => k.split('|').first)
        .toSet();
  }

  ClassStatus statusForEntry(RoutineEntry e, {required bool isToday}) {
    if (isToday && isCancelledToday(e)) return ClassStatus.cancelled;
    return e.statusOn(now, isToday: isToday);
  }

  List<RoutineEntry> get entriesForSelectedDay {
    final full = selectedFullDay;
    final list = _entries.where((e) => e.day == full).toList()
      ..sort((a, b) => a.timeStart.compareTo(b.timeStart));
    return list;
  }

  // PHASE 1 RECONCILE: The matrix consumes the same already role-filtered entries as Day List.
  List<RoutineEntry> get entries => List.unmodifiable(_entries);

  int countForDay(String shortDay) {
    final i = AppConstants.weekDaysShort.indexOf(shortDay);
    if (i < 0) return 0;
    final full = AppConstants.weekDays[i];
    return _entries.where((e) => e.day == full).length;
  }

  Future<void> load() async {
    final m = _me;
    if (m == null && routineLoader == null) {
      _hasLoaded = true;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (routineLoader != null) {
        final loaded = await routineLoader!();
        if (m != null && m.isTeacher) {
          final code = m.teacherCode?.trim() ?? '';
          _entries = code.isEmpty
              ? loaded
              : loaded.where((r) => r.matchesTeacher(code)).toList();
        } else if (m != null &&
            (m.batch?.isNotEmpty ?? false) &&
            (m.section?.isNotEmpty ?? false)) {
          _entries = loaded
              .where((r) => r.matchesStudent(m.batch!, m.section!))
              .toList();
        } else {
          _entries = loaded;
        }
      } else if (m!.isTeacher) {
        _entries = m.teacherCode == null
            ? []
            : await _routineService.fetchForTeacher(m.teacherCode!);
      } else {
        _entries = await _routineService.fetchForStudent(
          batch: m.batch ?? '',
          section: m.section ?? '',
        );
      }

      if (cancellationKeysLoader != null) {
        _cancelledKeys =
            await cancellationKeysLoader!(_entries.map((e) => e.id).toList());
      } else if (routineLoader == null && _entries.isNotEmpty) {
        try {
          _cancelledKeys = await TeacherService().fetchUpcomingCancellationKeys(
            _entries.map((e) => e.id).toList(),
          );
        } catch (_) {
          // Best-effort cancellation lookup.
        }
      }
    } catch (e) {
      _errorMessage = 'Could not load routine.';
    }

    _isLoading = false;
    _hasLoaded = true;
    notifyListeners();
  }

  void setDay(String shortDay) {
    if (_selectedDay == shortDay) return;
    _selectedDay = shortDay;
    notifyListeners();
  }

  // PHASE 4: Step forward/backward across weekDaysShort for swipeable Day List navigation.
  // Supports circular wrapping across the 7-day institutional week.
  bool stepDay(int delta, {bool circular = true}) {
    final currentIndex = AppConstants.weekDaysShort.indexOf(_selectedDay);
    if (currentIndex < 0) return false;
    final total = AppConstants.weekDaysShort.length;
    int nextIndex = currentIndex + delta;
    if (circular) {
      nextIndex = (nextIndex % total + total) % total;
    } else if (nextIndex < 0 || nextIndex >= total) {
      return false;
    }
    _selectedDay = AppConstants.weekDaysShort[nextIndex];
    notifyListeners();
    return true;
  }
}
