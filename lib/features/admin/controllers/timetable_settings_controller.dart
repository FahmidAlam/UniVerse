import 'package:flutter/material.dart';
import 'package:universe/core/models/timetable_config_model.dart';
import 'package:universe/features/admin/services/timetable_config_service.dart';

class TimetableSettingsController extends ChangeNotifier {
  final TimetableConfigService _service = TimetableConfigService();

  TimetableSettings _settings = const TimetableSettings();
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  TimetableSettings get settings => _settings;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _settings = await _service.fetchSettings();
    } catch (_) {
      _errorMessage = 'Could not load settings.';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> save(TimetableSettings updated) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    var ok = true;
    try {
      await _service.saveSettings(updated);
      _settings = updated;
    } catch (_) {
      _errorMessage = 'Could not save settings.';
      ok = false;
    }
    _isSaving = false;
    notifyListeners();
    return ok;
  }
}
