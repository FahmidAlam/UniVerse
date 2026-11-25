import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/constants/app_enums.dart';
import 'package:universe/core/models/profile_model.dart';
import 'package:universe/core/models/routine_model.dart';
import 'package:universe/core/utils/safe_change_notifier.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/features/routine/services/routine_service.dart';
import 'package:universe/features/teacher/services/teacher_service.dart';

// PHASE 4: Status filter for ManageClassesScreen master list.
enum ManageClassFilter { all, scheduled, cancelled }

// PHASE 4: ManageClassesController with lazy Supabase services, DI seams, master-detail selection,
// and truthful two-step cancellation / partial-failure / restoration feedback.
class ManageClassesController extends SafeChangeNotifier {
  RoutineService? _routineServiceInstance;
  RoutineService get _routineService =>
      _routineServiceInstance ??= RoutineService();

  TeacherService? _teacherServiceInstance;
  TeacherService get _teacherService =>
      _teacherServiceInstance ??= TeacherService();

  final AuthController authController;
  final Future<List<RoutineEntry>> Function(String teacherCode)? routineLoader;
  final Future<Set<String>> Function(List<String> routineIds)?
      cancellationKeysLoader;
  final Future<CancellationOutcome> Function(
    RoutineEntry entry,
    DateTime date,
    String reason,
  )? cancelClassHandler;
  final Future<bool> Function(RoutineEntry entry, DateTime date)?
      undoCancelHandler;
  final Future<bool> Function(
    RoutineEntry entry,
    NotifType type,
    String title,
    String body,
  )? postNoticeHandler;
  final DateTime Function()? _clock;

  ManageClassesController({
    required this.authController,
    this.routineLoader,
    this.cancellationKeysLoader,
    this.cancelClassHandler,
    this.undoCancelHandler,
    this.postNoticeHandler,
    DateTime Function()? clock,
    List<RoutineEntry>? initialEntries,
    Set<String>? initialCancelledKeys,
    String? initialSelectedDay,
  }) : _clock = clock {
    _selectedDay = initialSelectedDay ?? _todayShortFor(now);
    if (initialEntries != null) {
      _all = List<RoutineEntry>.of(initialEntries);
      _hasLoaded = true;
    }
    if (initialCancelledKeys != null) {
      _cancelledKeys = Set<String>.of(initialCancelledKeys);
    }
    _syncSelectedEntry();
  }

  List<RoutineEntry> _all = [];
  Set<String> _cancelledKeys = <String>{};
  final Set<String> _restoredNoticeEligibleIds = <String>{};
  bool _isLoading = false;
  bool _hasLoaded = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _feedbackBannerMessage;
  bool _isFeedbackWarning = false;
  CancellationOutcome? _lastCancellationOutcome;
  ManageClassFilter _activeFilter = ManageClassFilter.all;
  String? _selectedEntryId;
  late String _selectedDay;

  DateTime get now => _clock?.call() ?? DateTime.now();
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  String? get feedbackBannerMessage => _feedbackBannerMessage;
  bool get isFeedbackWarning => _isFeedbackWarning;
  CancellationOutcome? get lastCancellationOutcome => _lastCancellationOutcome;
  ManageClassFilter get activeFilter => _activeFilter;
  String get selectedDay => _selectedDay;

  Profile? get _me {
    final map = authController.profile;
    return map == null ? null : Profile.fromMap(map);
  }

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

  static const Map<String, int> _fullDayToWeekday = {
    'Sunday': 7,
    'Monday': 1,
    'Tuesday': 2,
    'Wednesday': 3,
    'Thursday': 4,
    'Friday': 5,
    'Saturday': 6,
  };

  String get selectedFullDay {
    final i = AppConstants.weekDaysShort.indexOf(_selectedDay);
    return i >= 0 ? AppConstants.weekDays[i] : _selectedDay;
  }

  String get _selectedFullDay => selectedFullDay;

  bool get isSelectedDayToday => _selectedDay == _todayShortFor(now);

  List<RoutineEntry> get entriesForSelectedDay {
    final full = _selectedFullDay;
    return _all.where((e) => e.day == full).toList()
      ..sort((a, b) => a.timeStart.compareTo(b.timeStart));
  }

  List<RoutineEntry> get filteredEntriesForSelectedDay {
    final base = entriesForSelectedDay;
    switch (_activeFilter) {
      case ManageClassFilter.all:
        return base;
      case ManageClassFilter.scheduled:
        return base.where((e) => !isCancelled(e)).toList();
      case ManageClassFilter.cancelled:
        return base.where(isCancelled).toList();
    }
  }

  int get scheduledCountForSelectedDay =>
      entriesForSelectedDay.where((e) => !isCancelled(e)).length;

  int get cancelledCountForSelectedDay =>
      entriesForSelectedDay.where(isCancelled).length;

  RoutineEntry? get selectedEntry {
    final dayEntries = entriesForSelectedDay;
    if (dayEntries.isEmpty) return null;
    if (_selectedEntryId != null) {
      for (final e in dayEntries) {
        if (e.id == _selectedEntryId) return e;
      }
    }
    final filtered = filteredEntriesForSelectedDay;
    return filtered.isNotEmpty ? filtered.first : dayEntries.first;
  }

  void selectEntry(RoutineEntry entry) {
    if (_selectedEntryId == entry.id) return;
    _selectedEntryId = entry.id;
    notifyListeners();
  }

  void setFilter(ManageClassFilter filter) {
    if (_activeFilter == filter) return;
    _activeFilter = filter;
    _syncSelectedEntry();
    notifyListeners();
  }

  void clearFilter() => setFilter(ManageClassFilter.all);

  void dismissFeedbackBanner() {
    if (_feedbackBannerMessage == null) return;
    _feedbackBannerMessage = null;
    _isFeedbackWarning = false;
    notifyListeners();
  }

  void _syncSelectedEntry() {
    final dayEntries = entriesForSelectedDay;
    if (dayEntries.isEmpty) {
      _selectedEntryId = null;
      return;
    }
    if (_selectedEntryId == null ||
        !dayEntries.any((e) => e.id == _selectedEntryId)) {
      _selectedEntryId = dayEntries.first.id;
    }
  }

  int countForDay(String shortDay) {
    final i = AppConstants.weekDaysShort.indexOf(shortDay);
    if (i < 0) return 0;
    final full = AppConstants.weekDays[i];
    return _all.where((e) => e.day == full).length;
  }

  static String _formatMonthDay(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }

  DateTime occurrenceDate(String fullDay) {
    final tw = _fullDayToWeekday[fullDay];
    final base = now;
    final today = DateTime(base.year, base.month, base.day);
    if (tw == null) return today;
    for (var i = 0; i < 7; i++) {
      final d = today.add(Duration(days: i));
      if (d.weekday == tw) return d;
    }
    return today;
  }

  DateTime get selectedOccurrenceDate => occurrenceDate(_selectedFullDay);

  bool isCancelled(RoutineEntry e) {
    final key = '${e.id}|${TeacherService.dateKey(occurrenceDate(e.day))}';
    return _cancelledKeys.contains(key);
  }

  bool isRestoredNoticeEligible(RoutineEntry e) =>
      _restoredNoticeEligibleIds.contains(e.id);

  Future<void> load() async {
    final me = _me;
    if (me == null && routineLoader == null) {
      _hasLoaded = true;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final code = me?.teacherCode?.trim() ?? '';
      if (routineLoader != null) {
        final rows = await routineLoader!(code);
        _all = code.isEmpty
            ? rows
            : rows.where((r) => r.matchesTeacher(code)).toList();
      } else {
        _all = code.isEmpty
            ? <RoutineEntry>[]
            : await _routineService.fetchForTeacher(code);
      }

      if (cancellationKeysLoader != null) {
        _cancelledKeys =
            await cancellationKeysLoader!(_all.map((e) => e.id).toList());
      } else if (routineLoader == null && _all.isNotEmpty) {
        _cancelledKeys = await _teacherService
            .fetchUpcomingCancellationKeys(_all.map((e) => e.id).toList());
      }
      _syncSelectedEntry();
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
    _syncSelectedEntry();
    notifyListeners();
  }

  /// Step forward or backward across the 7-day week with circular wrapping.
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
    setDay(AppConstants.weekDaysShort[nextIndex]);
    return true;
  }

  /// Jump directly to today's active day.
  void goToToday() {
    setDay(_todayShortFor(now));
  }

  // PHASE 4: Truthful two-step cancellation feedback distinguishing full success vs. saved cancellation with failed alert.
  Future<CancellationOutcome> cancelClassWithOutcome(
    RoutineEntry e,
    String reason,
  ) async {
    final me = _me;
    if (me == null && cancelClassHandler == null) {
      return CancellationOutcome.failed;
    }

    _isSubmitting = true;
    _errorMessage = null;
    _feedbackBannerMessage = null;
    _isFeedbackWarning = false;
    notifyListeners();

    final date = occurrenceDate(e.day);
    final dateStr = _formatMonthDay(date);
    try {
      final outcome = cancelClassHandler != null
          ? await cancelClassHandler!(e, date, reason)
          : await _teacherService.cancelClassWithOutcome(
              entry: e,
              date: date,
              reason: reason,
              userId: me?.id ?? 'teacher',
            );

      _lastCancellationOutcome = outcome;

      if (outcome == CancellationOutcome.fullSuccess) {
        _cancelledKeys.add('${e.id}|${TeacherService.dateKey(date)}');
        _restoredNoticeEligibleIds.remove(e.id);
        _feedbackBannerMessage =
            'Class occurrence cancelled for $dateStr and cohort notification sent.';
        _isFeedbackWarning = false;
      } else if (outcome ==
          CancellationOutcome.partialSuccessNotificationFailed) {
        _cancelledKeys.add('${e.id}|${TeacherService.dateKey(date)}');
        _restoredNoticeEligibleIds.remove(e.id);
        _feedbackBannerMessage =
            'Class cancelled for $dateStr, but the cohort alert could not be sent. Your cancellation is saved.';
        _isFeedbackWarning = true;
      } else {
        _errorMessage = 'Could not cancel class occurrence for $dateStr.';
      }
      _isSubmitting = false;
      notifyListeners();
      return outcome;
    } catch (err) {
      _lastCancellationOutcome = CancellationOutcome.failed;
      _errorMessage = 'Cancel failed: '
          '${err.toString().replaceFirst('Exception: ', '')}';
      _isSubmitting = false;
      notifyListeners();
      return CancellationOutcome.failed;
    }
  }

  Future<bool> cancelClass(RoutineEntry e, String reason) async {
    final outcome = await cancelClassWithOutcome(e, reason);
    return outcome != CancellationOutcome.failed;
  }

  Future<bool> undoCancel(RoutineEntry e) async {
    final me = _me;
    if (me == null && undoCancelHandler == null) return false;

    _isSubmitting = true;
    _errorMessage = null;
    _feedbackBannerMessage = null;
    _isFeedbackWarning = false;
    notifyListeners();

    final date = occurrenceDate(e.day);
    final dateStr = _formatMonthDay(date);
    try {
      if (undoCancelHandler != null) {
        final ok = await undoCancelHandler!(e, date);
        if (!ok) {
          _errorMessage = 'Could not undo the cancellation.';
          return _finishSubmit(false);
        }
      } else {
        await _teacherService.undoCancel(
          routineId: e.id,
          date: date,
          userId: me?.id ?? 'teacher',
        );
      }
      _cancelledKeys.remove('${e.id}|${TeacherService.dateKey(date)}');
      _restoredNoticeEligibleIds.add(e.id);
      _feedbackBannerMessage =
          'Restored ${e.subject} for $dateStr (cancellation badge removed). Previously sent push alerts are not retracted automatically.';
      _isFeedbackWarning = false;
      return _finishSubmit(true);
    } catch (err) {
      _errorMessage = 'Could not undo the cancellation.';
      return _finishSubmit(false);
    }
  }

  // PHASE 4: 1-tap follow-up notice after restoring a cancelled class occurrence.
  Future<bool> sendClassRestoredNotice(RoutineEntry e) async {
    final date = occurrenceDate(e.day);
    final dateStr = _formatMonthDay(date);
    final ok = await postNotice(
      e,
      type: NotifType.university,
      title: 'Class Restored: ${e.subject}',
      body:
          '${e.subject} (${e.timeLabel}) on ${e.day}, $dateStr has been restored and will take place as scheduled in Room ${e.room}.',
    );
    if (ok) {
      _restoredNoticeEligibleIds.remove(e.id);
      _feedbackBannerMessage =
          "Sent 'Class Restored' notice to Batch ${e.batch} · Sec ${e.section} for $dateStr.";
      _isFeedbackWarning = false;
      notifyListeners();
    }
    return ok;
  }

  Future<bool> postNotice(
    RoutineEntry e, {
    required NotifType type,
    required String title,
    required String body,
  }) async {
    final me = _me;
    if (me == null && postNoticeHandler == null) return false;

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (postNoticeHandler != null) {
        final ok = await postNoticeHandler!(e, type, title, body);
        if (!ok) {
          _errorMessage = 'Could not post the update.';
          return _finishSubmit(false);
        }
      } else {
        await _teacherService.postNotice(
          type: type,
          title: title,
          body: body,
          entry: e,
          userId: me?.id ?? 'teacher',
        );
      }
      _feedbackBannerMessage =
          'Cohort update sent to Batch ${e.batch} · Sec ${e.section}.';
      _isFeedbackWarning = false;
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
