// ============================================================
// FILE: lib/features/routine/controllers/routine_controller.dart
// PURPOSE: State between RoutineService and the routine screens.
// Role-aware: loads the student's section routine or the teacher's
// own classes from the same controller. Tracks the selected day
// and exposes the entries for that day.
// ============================================================

import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/models/profile_model.dart';
import 'package:universe/core/models/routine_model.dart';
import 'package:universe/core/utils/safe_change_notifier.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/features/routine/services/routine_service.dart';

class RoutineController extends SafeChangeNotifier {
  final RoutineService _service = RoutineService();
  final AuthController authController;

  RoutineController({required this.authController});

  List<RoutineEntry> _entries = [];
  bool _isLoading = false;
  String? _errorMessage;
  late String _selectedDay = _todayShort();

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get selectedDay => _selectedDay;

  Profile? get _me {
    final map = authController.profile;
    return map == null ? null : Profile.fromMap(map);
  }

  bool get isTeacherView => _me?.isTeacher ?? false;

  /// Today's short day name. All 7 days are class days here.
  static String _todayShort() {
    // DateTime.weekday: Mon=1 … Sun=7
    const map = {
      7: 'Sun', 1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat',
    };
    return map[DateTime.now().weekday] ?? 'Sun';
  }

  String get _selectedFullDay {
    final i = AppConstants.weekDaysShort.indexOf(_selectedDay);
    return i >= 0 ? AppConstants.weekDays[i] : _selectedDay;
  }

  bool get isSelectedDayToday => _selectedDay == _todayShort();

  List<RoutineEntry> get entriesForSelectedDay {
    final full = _selectedFullDay;
    return _entries.where((e) => e.day == full).toList();
  }

  int countForDay(String shortDay) {
    final i = AppConstants.weekDaysShort.indexOf(shortDay);
    if (i < 0) return 0;
    final full = AppConstants.weekDays[i];
    return _entries.where((e) => e.day == full).length;
  }

  Future<void> load() async {
    final me = _me;
    if (me == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (me.isTeacher) {
        _entries = me.teacherCode == null
            ? []
            : await _service.fetchForTeacher(me.teacherCode!);
      } else {
        _entries = await _service.fetchForStudent(
          batch: me.batch ?? '',
          section: me.section ?? '',
        );
      }
    } catch (e) {
      _errorMessage = 'Could not load routine.';
    }

    _isLoading = false;
    notifyListeners();
  }

  void setDay(String shortDay) {
    if (_selectedDay == shortDay) return;
    _selectedDay = shortDay;
    notifyListeners();
  }
}
