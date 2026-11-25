// PHASE A: BatchesController managing CohortBatch entities, sections, joint sections, and R1/R2 rules
import 'package:universe/core/models/admin_catalog_models.dart';
import 'package:universe/core/utils/safe_change_notifier.dart';
import 'package:universe/features/admin/services/timetable_config_service.dart';

class BatchesController extends SafeChangeNotifier {
  final TimetableConfigService _service;

  BatchesController({
    TimetableConfigService? service,
    List<CohortBatch>? initialBatches,
  })  : _service = service ?? TimetableConfigService(),
        _all = initialBatches ?? [];

  List<CohortBatch> _all;
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';
  String _semesterFilter = 'All';
  CohortBatch? _selectedBatch;

  List<CohortBatch> get allBatches => _all;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  String get semesterFilter => _semesterFilter;
  CohortBatch? get selectedBatch => _selectedBatch;
  int get totalBatches => _all.length;
  int get totalSections =>
      _all.fold(0, (sum, b) => sum + b.sections.length);

  List<CohortBatch> get filteredBatches {
    var list = _all;
    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((b) {
        return b.batchName.toLowerCase().contains(q) ||
            b.semesterLabel.toLowerCase().contains(q);
      }).toList();
    }

    if (_semesterFilter != 'All') {
      list = list
          .where((b) => b.semesterLabel.toLowerCase().contains(_semesterFilter.toLowerCase()))
          .toList();
    }

    return list;
  }

  int get filteredCount => filteredBatches.length;

  Future<void> load() async {
    if (_all.isNotEmpty) {
      notifyListeners();
      return;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _all = await _service.fetchBatches();
      if (_all.isNotEmpty && _selectedBatch == null) {
        _selectedBatch = _all.first;
      }
    } catch (_) {
      _errorMessage = 'Could not load batches catalog.';
    }
    _isLoading = false;
    notifyListeners();
  }

  void setQuery(String q) {
    _searchQuery = q;
    notifyListeners();
  }

  void setSemesterFilter(String sem) {
    _semesterFilter = sem;
    notifyListeners();
  }

  void selectBatch(CohortBatch? batch) {
    _selectedBatch = batch;
    notifyListeners();
  }

  Future<bool> saveBatch(CohortBatch batch) async {
    try {
      await _service.createBatch(batch);
      final idx = _all.indexWhere((b) => b.id == batch.id || b.batchName == batch.batchName);
      if (idx != -1) {
        _all[idx] = batch;
      } else {
        _all.add(batch);
      }
      _selectedBatch = batch;
      notifyListeners();
      return true;
    } catch (_) {
      _errorMessage = 'Failed to save batch.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteBatch(String id) async {
    try {
      await _service.deleteBatch(id);
      _all.removeWhere((b) => b.id == id || b.batchName == id);
      if (_selectedBatch?.id == id || _selectedBatch?.batchName == id) {
        _selectedBatch = _all.isNotEmpty ? _all.first : null;
      }
      notifyListeners();
      return true;
    } catch (_) {
      _errorMessage = 'Failed to delete batch.';
      notifyListeners();
      return false;
    }
  }
}
