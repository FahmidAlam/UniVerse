import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/models/routine_model.dart';
import 'package:universe/core/utils/safe_change_notifier.dart';
import 'package:universe/features/routine/services/routine_service.dart';

class RoutineAdminController extends SafeChangeNotifier {
  final RoutineService _service;

  List<RoutineEntry> _all = [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _errorMessage;
  String? _dayFilter;

  // PHASE 5: Optional DI seams for deterministic offline widget testing.
  RoutineAdminController({
    RoutineService? service,
    List<RoutineEntry>? initialEntries,
  }) : _service = service ?? RoutineService() {
    if (initialEntries != null) {
      _all = List<RoutineEntry>.of(initialEntries);
      _hasLoaded = true;
    }
  }

  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get errorMessage => _errorMessage;
  String? get dayFilter => _dayFilter;
  int get totalCount => _all.length;
  List<RoutineEntry> get allRows => _all;

  List<RoutineEntry> get filtered => _dayFilter == null
      ? _all
      : _all.where((r) => r.day == _dayFilter).toList();

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final list = await _service.fetchAll();
      list.sort((a, b) {
        final byDay = _dayIndex(a.day).compareTo(_dayIndex(b.day));
        return byDay != 0 ? byDay : a.timeStart.compareTo(b.timeStart);
      });
      _all = list;
      _hasLoaded = true;
    } catch (_) {
      _errorMessage = 'Could not load routines.';
    }

    _isLoading = false;
    notifyListeners();
  }

  int _dayIndex(String day) {
    final i = AppConstants.weekDays.indexOf(day);
    return i == -1 ? 99 : i;
  }

  void setDayFilter(String? day) {
    if (_dayFilter == day) return;
    _dayFilter = day;
    notifyListeners();
  }

  Future<bool> save({
    RoutineEntry? existing,
    required Map<String, dynamic> data,
  }) async {
    try {
      if (existing == null) {
        await _service.create(data);
      } else {
        await _service.update(existing.id, data);
      }
      await load();
      return true;
    } catch (_) {
      _errorMessage = 'Could not save the routine entry.';
      notifyListeners();
      return false;
    }
  }

  Future<void> delete(String id) async {
    try {
      await _service.delete(id);
      _all.removeWhere((r) => r.id == id);
      notifyListeners();
    } catch (_) {
      _errorMessage = 'Could not delete the entry.';
      notifyListeners();
    }
  }
}
