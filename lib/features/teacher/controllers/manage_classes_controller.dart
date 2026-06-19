// ============================================================
// FILE: lib/features/teacher/controllers/manage_classes_controller.dart
// PURPOSE: State for the teacher Manage Classes screen. Loads the
// teacher's weekly classes + their upcoming cancellations, tracks
// the selected day, and drives the cancel / undo / post-notice
// actions through TeacherService.
// ============================================================

import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/constants/app_enums.dart';
import 'package:universe/core/models/profile_model.dart';
import 'package:universe/core/models/routine_model.dart';
import 'package:universe/core/utils/safe_change_notifier.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/features/routine/services/routine_service.dart';
import 'package:universe/features/teacher/services/teacher_service.dart';

class ManageClassesController extends SafeChangeNotifier {
  final RoutineService _routineService = RoutineService();
  final TeacherService _teacherService = TeacherService();
  final AuthController authController;

  ManageClassesController({required this.authController});

  List<RoutineEntry> _all = [];
  Set<String> _cancelledKeys = <String>{};
  bool _isLoading = false;
  bool _hasLoaded = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  late String _selectedDay = _todayShort();

  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  String get selectedDay => _selectedDay;

  Profile? get _me {
    final map = authController.profile;
    return map == null ? null : Profile.fromMap(map);
  }

  // ─── Day helpers ──────────────────────────────────────────
  static String _todayShort() {
    const map = {
      7: 'Sun', 1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat',
    };
    return map[DateTime.now().weekday] ?? 'Sun';
  }

  static const Map<String, int> _fullDayToWeekday = {
    'Sunday': 7,
    'Monday': 1,
    'Tuesday': 2,
    'Wednesday': 3,
    'Thursday': 4,
    'Friday': 5,
    'Saturday': 6,
  };

  String get _selectedFullDay {
    final i = AppConstants.weekDaysShort.indexOf(_selectedDay);
    return i >= 0 ? AppConstants.weekDays[i] : _selectedDay;
  }

  bool get isSelectedDayToday => _selectedDay == _todayShort();

  List<RoutineEntry> get entriesForSelectedDay {
    final full = _selectedFullDay;
    return _all.where((e) => e.day == full).toList()
      ..sort((a, b) => a.timeStart.compareTo(b.timeStart));
  }

  int countForDay(String shortDay) {
    final i = AppConstants.weekDaysShort.indexOf(shortDay);
    if (i < 0) return 0;
    final full = AppConstants.weekDays[i];
    return _all.where((e) => e.day == full).length;
  }

  /// The next calendar date (>= today) whose weekday matches [fullDay].
  /// A cancellation targets this concrete occurrence.
  DateTime occurrenceDate(String fullDay) {
    final tw = _fullDayToWeekday[fullDay];
    final base = DateTime.now();
    final today = DateTime(base.year, base.month, base.day);
    if (tw == null) return today;
    for (var i = 0; i < 7; i++) {
      final d = today.add(Duration(days: i));
      if (d.weekday == tw) return d;
    }
    return today;
  }

  /// The occurrence date for the day currently selected in the UI.
  DateTime get selectedOccurrenceDate => occurrenceDate(_selectedFullDay);

  bool isCancelled(RoutineEntry e) {
    final key = '${e.id}|${TeacherService.dateKey(occurrenceDate(e.day))}';
    return _cancelledKeys.contains(key);
  }

  // ─── Load ─────────────────────────────────────────────────
  Future<void> load() async {
    final me = _me;
    if (me == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _all = me.teacherCode == null
          ? <RoutineEntry>[]
          : await _routineService.fetchForTeacher(me.teacherCode!);
      _cancelledKeys = await _teacherService
          .fetchUpcomingCancellationKeys(_all.map((e) => e.id).toList());
    } catch (e) {
      _errorMessage = 'Could not load your classes.';
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

  // ─── Actions ──────────────────────────────────────────────
  Future<bool> cancelClass(RoutineEntry e, String reason) async {
    final me = _me;
    if (me == null) return false;

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    final date = occurrenceDate(e.day);
    try {
      await _teacherService.cancelClass(
        entry: e,
        date: date,
        reason: reason,
        userId: me.id,
      );
      _cancelledKeys.add('${e.id}|${TeacherService.dateKey(date)}');
      return _finishSubmit(true);
    } catch (err) {
      _errorMessage = 'Cancel failed: '
          '${err.toString().replaceFirst('Exception: ', '')}';
      return _finishSubmit(false);
    }
  }

  Future<bool> undoCancel(RoutineEntry e) async {
    final me = _me;
    if (me == null) return false;

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    final date = occurrenceDate(e.day);
    try {
      await _teacherService.undoCancel(
        routineId: e.id,
        date: date,
        userId: me.id,
      );
      _cancelledKeys.remove('${e.id}|${TeacherService.dateKey(date)}');
      return _finishSubmit(true);
    } catch (err) {
      _errorMessage = 'Could not undo the cancellation.';
      return _finishSubmit(false);
    }
  }

  Future<bool> postNotice(
    RoutineEntry e, {
    required NotifType type,
    required String title,
    required String body,
  }) async {
    final me = _me;
    if (me == null) return false;

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _teacherService.postNotice(
        type: type,
        title: title,
        body: body,
        entry: e,
        userId: me.id,
      );
      return _finishSubmit(true);
    } catch (err) {
      _errorMessage = 'Could not post the update.';
      return _finishSubmit(false);
    }
  }

  bool _finishSubmit(bool ok) {
    _isSubmitting = false;
    notifyListeners();
    return ok;
  }
}
