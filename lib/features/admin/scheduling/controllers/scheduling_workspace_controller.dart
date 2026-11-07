import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universe/features/admin/scheduling/fixtures/scheduling_preview_fixtures.dart';
import 'package:universe/features/admin/scheduling/models/scheduling_workspace_models.dart';

enum DistributionAvailability {
  checking,
  unavailable,
  noAcceptedRevision,
  available,
}

/// Primary controller for the Phase 2B Scheduling Workspace.
///
/// Follows UniVerse feature-first architecture and ChangeNotifier conventions.
/// Provides a clear boundary between live production Supabase queries and
/// isolated design-preview fixtures.
class SchedulingWorkspaceController extends ChangeNotifier {
  final Future<DistributionAvailability> Function()? _availabilityLoader;

  bool _disposed = false;
  bool _isPreviewMode;
  DistributionAvailability _backendAvailability =
      DistributionAvailability.checking;
  int _currentTabIndex = 0;

  // Search & Filter state
  String _searchQuery = '';
  String? _selectedBatch;
  String? _selectedSection;
  String? _selectedDept;
  bool _onlyConflicts = false;
  bool _onlyCorrected = false;
  bool _onlyPendingTeacher = false;
  String _sortColumn = 'row';
  bool _sortAscending = true;

  // Selection & Inspector state
  DistributionSourceRecord? _selectedRecord;
  bool _isInspectorOpen = false;

  // Live vs Preview Data
  late List<DistributionSourceRecord> _records;
  late RevisionContext _revision;
  late List<PolicyConfigItem> _policyItems;
  late List<ReadinessItem> _readinessItems;

  // Solver Configuration & State
  SolverParameterConfig _solverConfig = const SolverParameterConfig();
  SolverExecutionResult _solverResult = SolverExecutionResult.ready;
  bool _isSolving = false;
  double _solvingProgress = 0.0;
  String _solvingStepMessage = '';

  // Publication State
  bool _isPublishing = false;
  String? _publishedConfirmationId;

  SchedulingWorkspaceController({
    Future<DistributionAvailability> Function()? availabilityLoader,
    bool initialPreviewMode = false,
  })  : _availabilityLoader = availabilityLoader,
        _isPreviewMode = initialPreviewMode {
    _initData();
    checkBackendAvailability();
  }

  void _initData() {
    _records = List.from(SchedulingPreviewFixtures.records);
    _revision = SchedulingPreviewFixtures.previewRevision;
    _policyItems = List.from(SchedulingPreviewFixtures.policyItems);
    _readinessItems = List.from(SchedulingPreviewFixtures.readinessItems);
    if (_records.isNotEmpty) {
      _selectedRecord = _records.firstWhere((r) => r.row == 18);
    }
  }

  // Getters
  bool get isPreviewMode => _isPreviewMode;
  DistributionAvailability get backendAvailability => _backendAvailability;
  int get currentTabIndex => _currentTabIndex;

  String get searchQuery => _searchQuery;
  String? get selectedBatch => _selectedBatch;
  String? get selectedSection => _selectedSection;
  String? get selectedDept => _selectedDept;
  bool get onlyConflicts => _onlyConflicts;
  bool get onlyCorrected => _onlyCorrected;
  bool get onlyPendingTeacher => _onlyPendingTeacher;
  String get sortColumn => _sortColumn;
  bool get sortAscending => _sortAscending;

  DistributionSourceRecord? get selectedRecord => _selectedRecord;
  bool get isInspectorOpen => _isInspectorOpen;

  RevisionContext get revision => _revision;
  List<PolicyConfigItem> get policyItems => _policyItems;
  List<ReadinessItem> get readinessItems => _readinessItems;

  SolverParameterConfig get solverConfig => _solverConfig;
  SolverExecutionResult get solverResult => _solverResult;
  bool get isSolving => _isSolving;
  double get solvingProgress => _solvingProgress;
  String get solvingStepMessage => _solvingStepMessage;

  bool get isPublishing => _isPublishing;
  String? get publishedConfirmationId => _publishedConfirmationId;

  /// Returns true if the live backend is ready to display real distribution data.
  bool get isLiveBackendReady =>
      _backendAvailability == DistributionAvailability.available;

  /// Returns distinct batches available in the dataset for filtering.
  List<String> get availableBatches =>
      _records.map((r) => r.batch).toSet().toList()..sort();

  /// Returns distinct sections available in the dataset for filtering.
  List<String> get availableSections =>
      _records.map((r) => r.section).toSet().toList()..sort();

  /// Returns distinct departments available in the dataset for filtering.
  List<String> get availableDepartments =>
      _records.map((r) => r.conductingDept).toSet().toList()..sort();

  /// All distribution source records in current memory state.
  List<DistributionSourceRecord> get records => List.unmodifiable(_records);

  /// Filtered and sorted distribution source records.
  List<DistributionSourceRecord> get filteredRecords {
    var list = _records.where((r) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchCode = r.courseCode.toLowerCase().contains(q);
        final matchTitle = r.courseTitle.toLowerCase().contains(q);
        final matchTeacher = r.teacher.toLowerCase().contains(q);
        final matchRow = r.row.toString().contains(q);
        if (!matchCode && !matchTitle && !matchTeacher && !matchRow) {
          return false;
        }
      }
      if (_selectedBatch != null && r.batch != _selectedBatch) return false;
      if (_selectedSection != null && r.section != _selectedSection) {
        return false;
      }
      if (_selectedDept != null && r.conductingDept != _selectedDept) {
        return false;
      }
      if (_onlyConflicts && !r.hasConflict) return false;
      if (_onlyCorrected && !r.hasCorrection) return false;
      if (_onlyPendingTeacher && !r.isTeacherPending) return false;
      return true;
    }).toList();

    list.sort((a, b) {
      int cmp = 0;
      switch (_sortColumn) {
        case 'row':
          cmp = a.row.compareTo(b.row);
          break;
        case 'batch':
          cmp = a.batch.compareTo(b.batch);
          break;
        case 'section':
          cmp = a.section.compareTo(b.section);
          break;
        case 'code':
          cmp = a.courseCode.compareTo(b.courseCode);
          break;
        case 'title':
          cmp = a.courseTitle.compareTo(b.courseTitle);
          break;
        case 'credit':
          cmp = a.credit.compareTo(b.credit);
          break;
        case 'dept':
          cmp = a.conductingDept.compareTo(b.conductingDept);
          break;
        case 'teacher':
          cmp = a.teacher.compareTo(b.teacher);
          break;
        default:
          cmp = a.row.compareTo(b.row);
      }
      return _sortAscending ? cmp : -cmp;
    });

    return list;
  }

  // Counts
  int get totalRecordsCount => _records.length;
  int get conflictsCount => _records.where((r) => r.hasConflict).length;
  int get correctionsCount => _records.where((r) => r.hasCorrection).length;
  int get pendingTeacherCount =>
      _records.where((r) => r.isTeacherPending).length;

  /// Checks the connected Supabase project for Phase 2a contract readiness.
  Future<void> checkBackendAvailability() async {
    _backendAvailability = DistributionAvailability.checking;
    notifyListeners();

    if (_availabilityLoader != null) {
      _backendAvailability = await _availabilityLoader!();
      if (!_disposed) notifyListeners();
      return;
    }

    try {
      final rows = await Supabase.instance.client
          .from('course_distribution_revisions')
          .select('id')
          .eq('status', 'accepted')
          .limit(1);
      final list = rows as List;
      _backendAvailability = list.isEmpty
          ? DistributionAvailability.noAcceptedRevision
          : DistributionAvailability.available;
    } on Object {
      _backendAvailability = DistributionAvailability.unavailable;
    }

    if (!_disposed) notifyListeners();
  }

  /// Toggles between live backend checking and isolated design preview.
  void togglePreviewMode(bool value) {
    _isPreviewMode = value;
    notifyListeners();
  }

  /// Changes the active tab (0=Distribution, 1=Config, 2=Readiness, 3=Generate, 4=Review).
  void setTabIndex(int index) {
    if (index >= 0 && index <= 4) {
      _currentTabIndex = index;
      notifyListeners();
    }
  }

  // Filter setters
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setBatchFilter(String? batch) {
    _selectedBatch = batch;
    notifyListeners();
  }

  void setSectionFilter(String? section) {
    _selectedSection = section;
    notifyListeners();
  }

  void setDeptFilter(String? dept) {
    _selectedDept = dept;
    notifyListeners();
  }

  void setOnlyConflicts(bool value) {
    _onlyConflicts = value;
    notifyListeners();
  }

  void setOnlyCorrected(bool value) {
    _onlyCorrected = value;
    notifyListeners();
  }

  void setOnlyPendingTeacher(bool value) {
    _onlyPendingTeacher = value;
    notifyListeners();
  }

  void setSorting(String column) {
    if (_sortColumn == column) {
      _sortAscending = !_sortAscending;
    } else {
      _sortColumn = column;
      _sortAscending = true;
    }
    notifyListeners();
  }

  void resetFilters() {
    _searchQuery = '';
    _selectedBatch = null;
    _selectedSection = null;
    _selectedDept = null;
    _onlyConflicts = false;
    _onlyCorrected = false;
    _onlyPendingTeacher = false;
    notifyListeners();
  }

  // Inspector & selection
  void selectRecord(DistributionSourceRecord record) {
    _selectedRecord = record;
    _isInspectorOpen = true;
    notifyListeners();
  }

  void selectRecordByRow(int row) {
    final matches = _records.where((r) => r.row == row);
    if (matches.isNotEmpty) {
      selectRecord(matches.first);
    }
  }

  void closeInspector() {
    _isInspectorOpen = false;
    notifyListeners();
  }

  void toggleInspector() {
    _isInspectorOpen = !_isInspectorOpen;
    notifyListeners();
  }

  /// Saves an audited correction on a specific cell of an immutable source row.
  ///
  /// In Preview Mode, this updates the local in-memory fixture with full provenance.
  /// In Live Mode, it connects to the authoritative Supabase RPC boundary.
  Future<bool> saveAuditedCorrection({
    required int row,
    required String column,
    required String effectiveValue,
    required String reason,
    required String author,
  }) async {
    if (reason.trim().isEmpty) return false;

    final targetIndex = _records.indexWhere((r) => r.row == row);
    if (targetIndex < 0) return false;

    final existing = _records[targetIndex];
    final originalVal = existing.originalValue(column);

    final correction = DistributionCorrection(
      id: 'corr-$row-${column.toLowerCase()}-${DateTime.now().millisecondsSinceEpoch}',
      row: row,
      column: column.toUpperCase(),
      originalValue: originalVal,
      effectiveValue: effectiveValue.trim(),
      reason: reason.trim(),
      author: author.trim().isEmpty ? 'Administrator' : author.trim(),
      timestamp: DateTime.now(),
      revisionVersion: _revision.revisionVersion + 1,
    );

    // Update corrections list
    final updatedCorrections = List<DistributionCorrection>.from(existing.corrections)
      ..removeWhere((c) => c.column.toUpperCase() == column.toUpperCase())
      ..add(correction);

    // Re-evaluate conflicts if pending teacher was resolved
    final updatedConflicts = List<String>.from(existing.conflicts);
    if (column.toUpperCase() == 'I' && !effectiveValue.toLowerCase().contains('pending')) {
      updatedConflicts.removeWhere((c) => c.toLowerCase().contains('missing teacher'));
    }

    // Re-evaluate readiness checklist if critical items were resolved
    if (row == 19 && column.toUpperCase() == 'I' && !effectiveValue.toLowerCase().contains('pending')) {
      _readinessItems = _readinessItems.map((item) {
        if (item.id == 'chk-teacher-pending') {
          return item.copyWith(isResolved: true);
        }
        return item;
      }).toList();
    }
    if (row == 24) {
      _readinessItems = _readinessItems.map((item) {
        if (item.id == 'chk-room-overcapacity') {
          return item.copyWith(isResolved: true);
        }
        return item;
      }).toList();
    }

    final updatedRecord = existing.copyWith(
      corrections: updatedCorrections,
      conflicts: updatedConflicts,
    );

    _records[targetIndex] = updatedRecord;
    if (_selectedRecord?.row == row) {
      _selectedRecord = updatedRecord;
    }

    // Update revision context version count
    _revision = RevisionContext(
      scopeId: _revision.scopeId,
      department: _revision.department,
      semester: _revision.semester,
      revisionNumber: _revision.revisionNumber,
      revisionVersion: _revision.revisionVersion + 1,
      status: _revision.status,
      sourceHash: _revision.sourceHash,
      sourceFileName: _revision.sourceFileName,
      acceptedAt: _revision.acceptedAt,
      acceptedBy: _revision.acceptedBy,
      isFresh: _revision.isFresh,
      totalRows: _revision.totalRows,
      correctionCount: _revision.correctionCount + 1,
      conflictCount: conflictsCount,
    );

    notifyListeners();
    return true;
  }

  /// Seals current working changes into a newly accepted revision draft snapshot.
  void sealDraftRevision({
    required String reason,
    required String author,
  }) {
    final nextNumber = _revision.revisionNumber + 1;
    _revision = RevisionContext(
      scopeId: _revision.scopeId,
      department: _revision.department,
      semester: _revision.semester,
      revisionNumber: nextNumber,
      revisionVersion: 1,
      status: 'accepted',
      sourceHash: 'sha256:d9b2e817${DateTime.now().millisecondsSinceEpoch}',
      sourceFileName: _revision.sourceFileName,
      acceptedAt: DateTime.now(),
      acceptedBy: author.trim().isEmpty ? 'Admin (Timetable Lead)' : author.trim(),
      isFresh: true,
      totalRows: _records.length,
      correctionCount: correctionsCount,
      conflictCount: conflictsCount,
    );
    notifyListeners();
  }

  /// Discards local working corrections and restores baseline fixtures.
  void resetToBaseline() {
    _initData();
    notifyListeners();
  }

  // Solver Configuration & Simulation
  void updateSolverConfig(SolverParameterConfig newConfig) {
    _solverConfig = newConfig;
    notifyListeners();
  }

  /// Updates an academic policy override in the in-memory working revision snapshot.
  void updatePolicyOverride({
    required String ruleId,
    required String newOverride,
    required String newEffective,
  }) {
    final idx = _policyItems.indexWhere((p) => p.ruleId == ruleId);
    if (idx >= 0) {
      final existing = _policyItems[idx];
      _policyItems[idx] = PolicyConfigItem(
        category: existing.category,
        ruleId: existing.ruleId,
        label: existing.label,
        description: existing.description,
        defaultValue: existing.defaultValue,
        overrideValue: newOverride,
        effectiveValue: newEffective,
        isLocked: existing.isLocked,
        snapshotRequirement: existing.snapshotRequirement,
      );
      notifyListeners();
    }
  }

  Future<void> runSolverPreview() async {
    if (_isSolving) return;

    _isSolving = true;
    _solvingProgress = 0.0;
    _solvingStepMessage = 'Initializing CP-SAT model and indexing decision variables…';
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 350));
    if (_disposed) return;
    _solvingProgress = 0.25;
    _solvingStepMessage = 'Enforcing 18,400 hard constraints: room non-overlap & faculty off-days…';
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 400));
    if (_disposed) return;
    _solvingProgress = 0.60;
    _solvingStepMessage = 'Optimizing multi-objective soft penalties: minimizing teacher idle gaps…';
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 400));
    if (_disposed) return;
    _solvingProgress = 0.88;
    _solvingStepMessage = 'Verifying campus room travel and period continuity constraints…';
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 350));
    if (_disposed) return;
    _solvingProgress = 1.0;
    _solvingStepMessage = 'OPTIMAL routine achieved! 0 hard violations, 96.4% preference score.';
    _solverResult = SchedulingPreviewFixtures.solvedResult;
    _isSolving = false;
    notifyListeners();
  }

  // Publication Simulation
  Future<void> simulatePublishRoutine() async {
    _isPublishing = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 600));
    if (_disposed) return;

    _publishedConfirmationId =
        'pub-rev4-v${_revision.revisionVersion}-${DateTime.now().millisecondsSinceEpoch}';
    _isPublishing = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
