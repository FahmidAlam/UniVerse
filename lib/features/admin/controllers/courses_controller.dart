// PHASE A: CoursesController managing CatalogCourse entities and filters
import 'package:universe/core/models/admin_catalog_models.dart';
import 'package:universe/core/utils/safe_change_notifier.dart';
import 'package:universe/features/admin/services/timetable_config_service.dart';

class CoursesController extends SafeChangeNotifier {
  final TimetableConfigService _service;

  CoursesController({
    TimetableConfigService? service,
    List<CatalogCourse>? initialCourses,
  })  : _service = service ?? TimetableConfigService(),
        _all = initialCourses ?? [];

  List<CatalogCourse> _all;
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';
  String _categoryFilter = 'All'; // All, CSE, GED, ENG, PHY, CHE, EEE, MAT
  String _typeFilter = 'All'; // All, Theory, Sessional
  CatalogCourse? _selectedCourse;

  List<CatalogCourse> get allCourses => _all;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  String get categoryFilter => _categoryFilter;
  String get typeFilter => _typeFilter;
  CatalogCourse? get selectedCourse => _selectedCourse;
  int get totalCount => _all.length;

  List<CatalogCourse> get filteredCourses {
    var list = _all;
    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((c) {
        return c.code.toLowerCase().contains(q) ||
            c.title.toLowerCase().contains(q);
      }).toList();
    }

    if (_categoryFilter != 'All') {
      list = list.where((c) => c.category.toUpperCase() == _categoryFilter.toUpperCase()).toList();
    }

    if (_typeFilter != 'All') {
      list = list.where((c) => c.courseType.toLowerCase() == _typeFilter.toLowerCase()).toList();
    }

    return list;
  }

  int get filteredCount => filteredCourses.length;

  Future<void> load() async {
    if (_all.isNotEmpty) {
      notifyListeners();
      return;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _all = await _service.fetchCatalogCourses();
      if (_all.isNotEmpty && _selectedCourse == null) {
        _selectedCourse = _all.first;
      }
    } catch (_) {
      _errorMessage = 'Could not load courses catalog.';
    }
    _isLoading = false;
    notifyListeners();
  }

  void setQuery(String q) {
    _searchQuery = q;
    notifyListeners();
  }

  void setCategoryFilter(String cat) {
    _categoryFilter = cat;
    notifyListeners();
  }

  void setTypeFilter(String type) {
    _typeFilter = type;
    notifyListeners();
  }

  void selectCourse(CatalogCourse? course) {
    _selectedCourse = course;
    notifyListeners();
  }

  Future<bool> saveCourse(CatalogCourse course, {bool reciprocalLink = true}) async {
    try {
      await _service.createCatalogCourse(course);
      final idx = _all.indexWhere((c) => c.id == course.id || c.code == course.code);
      if (idx != -1) {
        _all[idx] = course;
      } else {
        _all.add(course);
      }

      // 1-tap reciprocal companion course linking
      if (reciprocalLink && course.companionCourseCode != null) {
        final compCode = course.companionCourseCode!;
        final compIdx = _all.indexWhere((c) => c.code == compCode);
        if (compIdx != -1) {
          final existingCompanion = _all[compIdx];
          if (existingCompanion.companionCourseCode != course.code) {
            final updatedCompanion = existingCompanion.copyWith(
              companionCourseCode: course.code,
            );
            await _service.createCatalogCourse(updatedCompanion);
            _all[compIdx] = updatedCompanion;
          }
        }
      }

      _selectedCourse = course;
      notifyListeners();
      return true;
    } catch (_) {
      _errorMessage = 'Failed to save course.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteCourse(String id) async {
    try {
      await _service.deleteCatalogCourse(id);
      _all.removeWhere((c) => c.id == id || c.code == id);
      if (_selectedCourse?.id == id || _selectedCourse?.code == id) {
        _selectedCourse = _all.isNotEmpty ? _all.first : null;
      }
      notifyListeners();
      return true;
    } catch (_) {
      _errorMessage = 'Failed to delete course.';
      notifyListeners();
      return false;
    }
  }
}
