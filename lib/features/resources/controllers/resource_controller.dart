// ============================================================
// FILE: lib/features/resources/controllers/resource_controller.dart
// PURPOSE: State between ResourceService and the resources screen.
// Loads ALL resources once and groups them into semester folders,
// so anyone can browse any semester (not just their own). Inside an
// open folder, filters by category (All / PYQ / Notes / Slides /
// Assignments) client-side.
// ============================================================

import 'package:universe_v1/core/models/profile_model.dart';
import 'package:universe_v1/core/models/resource_model.dart';
import 'package:universe_v1/core/utils/safe_change_notifier.dart';
import 'package:universe_v1/features/auth/controllers/auth_controller.dart';
import 'package:universe_v1/features/resources/services/resource_service.dart';

class ResourceController extends SafeChangeNotifier {
  final ResourceService _service = ResourceService();
  final AuthController authController;

  ResourceController({required this.authController});

  static const String allCategory = 'All';

  List<Resource> _items = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _activeCategory = allCategory;
  int? _openSemester; // null = showing the semester folders

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get activeCategory => _activeCategory;
  int? get openSemester => _openSemester;

  /// The signed-in student's own semester (for the "Yours" folder badge).
  int? get mySemester => _me?.semester;

  /// Resource count in a given semester folder.
  int countForSemester(int semester) =>
      _items.where((r) => r.semester == semester).length;

  /// Items inside the currently-open semester folder, category-filtered.
  List<Resource> get filtered {
    final s = _openSemester;
    if (s == null) return const [];
    final inSemester = _items.where((r) => r.semester == s);
    if (_activeCategory == allCategory) return inSemester.toList();
    return inSemester.where((r) => r.category == _activeCategory).toList();
  }

  void openFolder(int semester) {
    _openSemester = semester;
    _activeCategory = allCategory;
    notifyListeners();
  }

  void closeFolder() {
    if (_openSemester == null) return;
    _openSemester = null;
    notifyListeners();
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
      _items = await _service.fetchAll();
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
