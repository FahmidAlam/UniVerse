// ============================================================
// FILE: lib/features/admin/controllers/admin_dashboard_controller.dart
// PURPOSE: State between AdminService and the admin dashboard.
// Loads aggregate counts for the stat strip. ChangeNotifier —
// the screen rebuilds via ListenableBuilder.
// ============================================================

import 'package:flutter/material.dart';
import 'package:universe_v1/features/admin/services/admin_service.dart';

class AdminDashboardController extends ChangeNotifier {
  final AdminService _service = AdminService();

  AdminCounts _counts = const AdminCounts();
  bool _isLoading = false;
  String? _errorMessage;

  AdminCounts get counts => _counts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _counts = await _service.counts();
    } catch (e) {
      _errorMessage = 'Could not load dashboard stats.';
    }

    _isLoading = false;
    notifyListeners();
  }
}
