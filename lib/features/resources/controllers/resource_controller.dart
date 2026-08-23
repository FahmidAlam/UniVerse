import 'package:universe/core/models/profile_model.dart';
import 'package:universe/core/models/resource_model.dart';
import 'package:universe/core/utils/safe_change_notifier.dart';
import 'package:universe/features/auth/controllers/auth_controller.dart';
import 'package:universe/features/resources/services/resource_service.dart';

class ResourceController extends SafeChangeNotifier {
  final ResourceService _service = ResourceService();
  final AuthController authController;

  ResourceController({required this.authController});

  static const String allCategory = 'All';

  List<Resource> _items = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _activeCategory = allCategory;
  int? _openSemester;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get activeCategory => _activeCategory;
  int? get openSemester => _openSemester;

  int? get mySemester => _me?.semester;

  int countForSemester(int semester) =>
      _items.where((r) => r.semester == semester).length;

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
