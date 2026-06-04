// ============================================================
// FILE: lib/features/resources/controllers/resource_controller.dart
// PURPOSE: State between ResourceService and the resources screen.
// Loads the student's semester resources once, then filters by
// category (All / PYQ / Notes / Slides / Assignments) client-side.
// ============================================================

import 'package:flutter/material.dart';
import 'package:universe_v1/core/models/profile_model.dart';
import 'package:universe_v1/core/models/resource_model.dart';
import 'package:universe_v1/features/auth/controllers/auth_controller.dart';
import 'package:universe_v1/features/resources/services/resource_service.dart';

class ResourceController extends ChangeNotifier {
  final ResourceService _service = ResourceService();
  final AuthController authController;

  ResourceController({required this.authController});

  static const String allCategory = 'All';

  List<Resource> _items = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _activeCategory = allCategory;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get activeCategory => _activeCategory;

  List<Resource> get filtered {
    if (_activeCategory == allCategory) return _items;
    return _items.where((r) => r.category == _activeCategory).toList();
  }

  Profile? get _me {
    final map = authController.profile;
    return map == null ? null : Profile.fromMap(map);
  }

  Future<void> load() async {
    final me = _me;
    if (me == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _items = await _service.fetchForSemester(me.semester ?? 0);
    } catch (e) {
      _errorMessage = 'Could not load resources.';
    }

    _isLoading = false;
    notifyListeners();
  }

  void setCategory(String category) {
    if (_activeCategory == category) return;
    _activeCategory = category;
    notifyListeners();
  }
}
