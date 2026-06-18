// ============================================================
// FILE: lib/features/dashboard/controllers/student_dashboard_controller.dart
// PURPOSE: Aggregates the student Home screen from the routine
// table (via RoutineService). Derives today's classes, the live
// class, the next upcoming class, and the simple counts shown in
// the stat strip. Read-only — no new backend, no writes.
// ============================================================

import 'package:universe_v1/core/constants/app_enums.dart';
import 'package:universe_v1/core/models/profile_model.dart';
import 'package:universe_v1/core/models/routine_model.dart';
import 'package:universe_v1/core/utils/safe_change_notifier.dart';
import 'package:universe_v1/features/auth/controllers/auth_controller.dart';
import 'package:universe_v1/features/routine/services/routine_service.dart';

class StudentDashboardController extends SafeChangeNotifier {
  final RoutineService _service = RoutineService();
  final AuthController authController;

  StudentDashboardController({required this.authController});

  List<RoutineEntry> _all = [];
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasLoaded => _hasLoaded;
  bool _hasLoaded = false;

  Profile? get me {
    final map = authController.profile;
    return map == null ? null : Profile.fromMap(map);
  }

  // Leading University runs all 7 days (DateTime.weekday: Mon=1 … Sun=7).
  static const Map<int, String> _weekdayFull = {
    7: 'Sunday',
    1: 'Monday',
    2: 'Tuesday',
    3: 'Wednesday',
    4: 'Thursday',
    5: 'Friday',
    6: 'Saturday',
  };

  String? get _todayFull => _weekdayFull[DateTime.now().weekday];

  /// Every weekday is a class day here, so this is always true. Kept so
  /// the dashboard hero can still distinguish "no class today" gracefully.
  bool get isClassDayToday => _todayFull != null;

  /// Today's classes, sorted by start time.
  List<RoutineEntry> get todaysClasses {
    final day = _todayFull;
    if (day == null) return const [];
    final list = _all.where((e) => e.day == day).toList()
      ..sort((a, b) => a.timeStart.compareTo(b.timeStart));
    return list;
  }

  int get weeklyCount => _all.length;
  int get todayCount => todaysClasses.length;

  /// The class running right now, if any.
  RoutineEntry? get liveClass {
    final now = DateTime.now();
    for (final e in todaysClasses) {
      if (e.statusOn(now, isToday: true) == ClassStatus.live) return e;
    }
    return null;
  }

  /// The first class today that hasn't started yet.
  RoutineEntry? get nextClass {
    final now = DateTime.now();
    for (final e in todaysClasses) {
      if (e.startOn(now).isAfter(now)) return e;
    }
    return null;
  }

  /// Classes today that haven't finished yet (live + upcoming).
  int get remainingToday {
    final now = DateTime.now();
    return todaysClasses.where((e) => e.endOn(now).isAfter(now)).length;
  }

  Future<void> load() async {
    final m = me;
    if (m == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _all = await _service.fetchForStudent(
        batch: m.batch ?? '',
        section: m.section ?? '',
      );
    } catch (e) {
      _errorMessage = 'Could not load your dashboard.';
    }

    _isLoading = false;
    _hasLoaded = true;
    notifyListeners();
  }
}
