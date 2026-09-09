import 'package:universe/core/models/timetable_config_model.dart';
import 'package:universe/core/utils/safe_change_notifier.dart';
import 'package:universe/features/admin/services/timetable_config_service.dart';

/// Admin state for faculty ↔ course eligibility and preference.
///
/// Eligibility is a check on the **distribution**, not an instruction to the
/// scheduler: the workbook names the teacher for every offering and the
/// engine's CP-SAT model only chooses (day, period). What this configures is
/// the gate that refuses to publish a routine in which a course was handed to
/// a teacher who is not qualified for it.
///
/// A teacher with no rows here is treated by the engine as *unconfigured*, not
/// as ineligible for everything — so filling this in one teacher at a time is
/// safe and never fails a routine for the teachers not done yet.
class CourseEligibilityController extends SafeChangeNotifier {
  final TimetableConfigService _service = TimetableConfigService();

  List<TimetableFaculty> _faculty = [];
  List<({String code, String title})> _catalog = [];
  List<TimetableCourseEligibility> _all = [];

  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  String _facultyQuery = '';
  String _courseQuery = '';
  String? _selectedAcronym;

  /// Working copy for the selected teacher: course code → priority (null = no
  /// preference set). Membership means eligible; absence means not eligible.
  final Map<String, int?> _draft = {};

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  String? get selectedAcronym => _selectedAcronym;
  List<({String code, String title})> get catalog => _catalog;

  /// Teachers who still teach here. An inactive teacher keeps their historical
  /// routines but is not offered for new configuration.
  List<TimetableFaculty> get faculty {
    final q = _facultyQuery.trim().toLowerCase();
    final active = _faculty.where((f) => f.isActive);
    if (q.isEmpty) return active.toList();
    return active
        .where((f) =>
            f.acronym.toLowerCase().contains(q) ||
            (f.fullName?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  List<({String code, String title})> get courses {
    final q = _courseQuery.trim().toLowerCase();
    if (q.isEmpty) return _catalog;
    return _catalog
        .where((c) =>
            c.code.toLowerCase().contains(q) ||
            c.title.toLowerCase().contains(q))
        .toList();
  }

  int configuredCountFor(String acronym) =>
      _all.where((e) => e.acronym == acronym && e.isEligible).length;

  bool isEligible(String code) => _draft.containsKey(code);

  int? priorityOf(String code) => _draft[code];

  int get selectedCount => _draft.length;

  bool get hasUnsavedChanges {
    final saved = {
      for (final e in _all.where(
          (e) => e.acronym == _selectedAcronym && e.isEligible))
        e.courseCode: e.priority,
    };
    if (saved.length != _draft.length) return true;
    for (final entry in _draft.entries) {
      if (!saved.containsKey(entry.key)) return true;
      if (saved[entry.key] != entry.value) return true;
    }
    return false;
  }

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _service.fetchFaculty(),
        _service.fetchCourseCatalog(),
        _service.fetchEligibility(),
      ]);
      _faculty = results[0] as List<TimetableFaculty>;
      _catalog = results[1] as List<({String code, String title})>;
      _all = results[2] as List<TimetableCourseEligibility>;
    } catch (_) {
      _errorMessage = 'Could not load faculty or courses.';
    }
    _isLoading = false;
    notifyListeners();
  }

  void setFacultyQuery(String q) {
    _facultyQuery = q;
    notifyListeners();
  }

  void setCourseQuery(String q) {
    _courseQuery = q;
    notifyListeners();
  }

  void select(String? acronym) {
    _selectedAcronym = acronym;
    _courseQuery = '';
    _draft
      ..clear()
      ..addEntries(_all
          .where((e) => e.acronym == acronym && e.isEligible)
          .map((e) => MapEntry(e.courseCode, e.priority)));
    notifyListeners();
  }

  void toggle(String code) {
    if (_draft.containsKey(code)) {
      _draft.remove(code);
    } else {
      _draft[code] = null;
    }
    notifyListeners();
  }

  /// Set or clear a preference rank. Ticking eligibility is implied — a
  /// priority on a course the teacher may not teach would be meaningless.
  void setPriority(String code, int? priority) {
    _draft[code] = (priority != null && priority > 0) ? priority : null;
    notifyListeners();
  }

  Future<bool> save() async {
    final acronym = _selectedAcronym;
    if (acronym == null) return false;
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final entries = [
        for (final e in _draft.entries)
          TimetableCourseEligibility(
            id: '',
            acronym: acronym,
            courseCode: e.key,
            isEligible: true,
            priority: e.value,
          ),
      ];
      await _service.saveEligibilityFor(acronym, entries);
      _all
        ..removeWhere((e) => e.acronym == acronym)
        ..addAll(entries);
      _isSaving = false;
      notifyListeners();
      return true;
    } catch (_) {
      _errorMessage = 'Could not save. Check your connection and try again.';
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }
}
