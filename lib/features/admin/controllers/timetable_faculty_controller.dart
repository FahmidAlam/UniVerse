// PHASE A: TimetableFacultyController with full Profile CRUD & R4-R9/R15 persistence
import 'package:flutter/material.dart';
import 'package:universe/core/models/timetable_config_model.dart';
import 'package:universe/features/admin/services/timetable_config_service.dart';

class TimetableFacultyController extends ChangeNotifier {
  final TimetableConfigService _service;

  TimetableFacultyController({
    TimetableConfigService? service,
    List<TimetableFaculty>? initialFaculty,
  })  : _service = service ?? TimetableConfigService(),
        _all = initialFaculty ?? [];

  List<TimetableFaculty> _all;
  bool _isLoading = false;
  String? _errorMessage;
  String _query = '';

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get total => _all.length;
  int get withOffDays => _all.where((f) => f.offDays.isNotEmpty).length;
  List<TimetableFaculty> get allFaculty => _all;

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
    if (_all.isNotEmpty) {
      notifyListeners();
      return;
    }
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

  Future<bool> saveFaculty(TimetableFaculty faculty) async {
    try {
      final exists = _all.any((f) => f.id == faculty.id || f.acronym == faculty.acronym);
      if (exists) {
        await _service.updateFaculty(faculty.id, faculty.toMap());
        final i = _all.indexWhere((x) => x.id == faculty.id || x.acronym == faculty.acronym);
        if (i != -1) {
          _all[i] = faculty;
        }
      } else {
        await _service.createFaculty(faculty.toMap());
        _all.add(faculty);
      }
      notifyListeners();
      return true;
    } catch (_) {
      _errorMessage = 'Could not save the faculty profile.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteFaculty(String id) async {
    try {
      await _service.deleteFaculty(id);
      _all.removeWhere((f) => f.id == id || f.acronym == id);
      notifyListeners();
      return true;
    } catch (_) {
      _errorMessage = 'Could not delete faculty.';
      notifyListeners();
      return false;
    }
  }

  /// Backwards-compatible save for legacy tests and callers
  Future<bool> save(TimetableFaculty f,
      {String? fullName, required List<String> offDays}) async {
    try {
      final updated = f.copyWith(fullName: fullName, offDays: offDays);
      await _service.updateFaculty(f.id, {
        'full_name': fullName ?? f.fullName,
        'off_days': offDays,
      });
      final i = _all.indexWhere((x) => x.id == f.id);
      if (i != -1) {
        _all[i] = updated;
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

