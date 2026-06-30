import 'package:flutter/material.dart';
import 'package:universe/core/models/timetable_config_model.dart';
import 'package:universe/features/admin/services/timetable_config_service.dart';

class TimetableFacultyController extends ChangeNotifier {
  final TimetableConfigService _service = TimetableConfigService();

  List<TimetableFaculty> _all = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _query = '';

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get total => _all.length;
  int get withOffDays => _all.where((f) => f.offDays.isNotEmpty).length;

  List<TimetableFaculty> get filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return _all
        .where((f) =>
            f.acronym.toLowerCase().contains(q) ||
            (f.fullName?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _all = await _service.fetchFaculty();
    } catch (_) {
      _errorMessage = 'Could not load faculty.';
    }
    _isLoading = false;
    notifyListeners();
  }

  void setQuery(String q) {
    _query = q;
    notifyListeners();
  }

  Future<bool> save(TimetableFaculty f,
      {String? fullName, required List<String> offDays}) async {
    try {
      await _service.updateFaculty(f.id, {
        'full_name': fullName ?? f.fullName,
        'off_days': offDays,
      });
      final i = _all.indexWhere((x) => x.id == f.id);
      if (i != -1) {
        _all[i] = f.copyWith(fullName: fullName, offDays: offDays);
      }
      notifyListeners();
      return true;
    } catch (_) {
      _errorMessage = 'Could not save the teacher.';
      notifyListeners();
      return false;
    }
  }
}
