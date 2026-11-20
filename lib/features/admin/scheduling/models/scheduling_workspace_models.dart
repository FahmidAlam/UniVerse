import 'package:flutter/foundation.dart';

/// Models for Phase 2B Scheduling Workspace.
/// Defines Course Distribution records, audited corrections, revision context,
/// policy configuration items, readiness blockers, and CP-SAT solver results.

enum DistributionRecordStatus {
  verified,
  corrected,
  conflict,
  pendingTeacher,
}

enum ReadinessSeverity {
  critical,
  warning,
  info,
}

/// Documented CP-SAT solver outcomes from Master Plan §7.2 and Python solver.py.
enum SolverRunState {
  idle,
  running,
  optimal,
  feasible,
  infeasible,
  unknown,
  timeLimitExhausted,
  inputError,
  // Backwards-compatible aliases
  ready,
  solving,
  error;

  bool get isSuccessful => this == optimal || this == feasible;
  bool get isNonFeasible =>
      this == infeasible ||
      this == timeLimitExhausted ||
      this == inputError ||
      this == error;
}

enum ArtifactStatus {
  current,
  stale,
  missing;

  bool get isStale => this == stale;
  bool get isCurrent => this == current;
}

/// Tracks provenance freshness for the 3 course_distribution_artifacts kinds:
/// 1. normalized_input
/// 2. validation_report
/// 3. generation_output
@immutable
class ArtifactFreshnessSummary {
  final ArtifactStatus normalizedInputStatus;
  final ArtifactStatus validationReportStatus;
  final ArtifactStatus generationOutputStatus;
  final int? validatedAgainstVersion;

  const ArtifactFreshnessSummary({
    this.normalizedInputStatus = ArtifactStatus.current,
    this.validationReportStatus = ArtifactStatus.current,
    this.generationOutputStatus = ArtifactStatus.current,
    this.validatedAgainstVersion,
  });

  bool get hasStaleArtifacts =>
      normalizedInputStatus == ArtifactStatus.stale ||
      validationReportStatus == ArtifactStatus.stale ||
      generationOutputStatus == ArtifactStatus.stale;

  bool get canPublish =>
      generationOutputStatus == ArtifactStatus.current &&
      validationReportStatus == ArtifactStatus.current;

  ArtifactFreshnessSummary copyWith({
    ArtifactStatus? normalizedInputStatus,
    ArtifactStatus? validationReportStatus,
    ArtifactStatus? generationOutputStatus,
    int? validatedAgainstVersion,
  }) {
    return ArtifactFreshnessSummary(
      normalizedInputStatus:
          normalizedInputStatus ?? this.normalizedInputStatus,
      validationReportStatus:
          validationReportStatus ?? this.validationReportStatus,
      generationOutputStatus:
          generationOutputStatus ?? this.generationOutputStatus,
      validatedAgainstVersion:
          validatedAgainstVersion ?? this.validatedAgainstVersion,
    );
  }
}

/// Granular progressive capability gates (A–D) for live backend integration.
/// In production, all gates default to locked (fail-closed) until explicitly enabled.
@immutable
class WorkspaceCapabilityState {
  /// Gate A: Scoped revision selection and read_course_distribution_revision RPC wired.
  final bool gateAScopedSourceReadReady;

  /// Gate B: append_course_distribution_correction RPC + 40001 optimistic concurrency wired.
  final bool gateBAuditedCorrectionReady;

  /// Gate C: Revision-bound PolicySnapshot + server/engine validation_report artifact wired.
  final bool gateCPolicyAndValidationReady;

  /// Gate D: Real FastAPI CP-SAT job execution + atomic re-validating publication RPC wired.
  final bool gateDSolverAndPublishReady;

  const WorkspaceCapabilityState({
    this.gateAScopedSourceReadReady = false,
    this.gateBAuditedCorrectionReady = false,
    this.gateCPolicyAndValidationReady = false,
    this.gateDSolverAndPublishReady = false,
  });

  static const WorkspaceCapabilityState allLocked = WorkspaceCapabilityState();

  bool get isFullyOperational =>
      gateAScopedSourceReadReady &&
      gateBAuditedCorrectionReady &&
      gateCPolicyAndValidationReady &&
      gateDSolverAndPublishReady;

  WorkspaceCapabilityState copyWith({
    bool? gateAScopedSourceReadReady,
    bool? gateBAuditedCorrectionReady,
    bool? gateCPolicyAndValidationReady,
    bool? gateDSolverAndPublishReady,
  }) {
    return WorkspaceCapabilityState(
      gateAScopedSourceReadReady:
          gateAScopedSourceReadReady ?? this.gateAScopedSourceReadReady,
      gateBAuditedCorrectionReady:
          gateBAuditedCorrectionReady ?? this.gateBAuditedCorrectionReady,
      gateCPolicyAndValidationReady:
          gateCPolicyAndValidationReady ?? this.gateCPolicyAndValidationReady,
      gateDSolverAndPublishReady:
          gateDSolverAndPublishReady ?? this.gateDSolverAndPublishReady,
    );
  }
}

/// Raised when append_course_distribution_correction reports PostgreSQL error 40001
/// (optimistic concurrency version conflict).
class StaleRevisionException implements Exception {
  final String message;
  final int expectedVersion;
  final int? actualVersion;

  const StaleRevisionException(
    this.message, {
    required this.expectedVersion,
    this.actualVersion,
  });

  @override
  String toString() =>
      'StaleRevisionException: $message (expected: v$expectedVersion)';
}

/// Structured diagnostic returned when CP-SAT solver fails to find a feasible solution.
@immutable
class SolverConflictDiagnostic {
  final String constraintId; // e.g. R10_ECL_WINDOW, R1_TEACHER_OVERLAP, R4_FACULTY_COMMITMENT
  final String title;
  final String humanExplanation;
  final List<String> affectedEntities;
  final int targetTab; // 0=Distribution, 1=Configuration
  final int? targetRow;
  final String? _suggestedAction;

  const SolverConflictDiagnostic({
    required this.constraintId,
    required this.title,
    required this.humanExplanation,
    required this.affectedEntities,
    required this.targetTab,
    this.targetRow,
    String? suggestedAction,
  }) : _suggestedAction = suggestedAction;

  String get ruleCode => constraintId;
  String get summary => humanExplanation.isNotEmpty ? humanExplanation : title;
  String get suggestedAction =>
      _suggestedAction ??
      (targetRow != null
          ? 'Inspect affected row in Distribution ($targetRow)'
          : 'Review and adjust rule constraints in Configuration');
  List<String> get involvedEntities => affectedEntities;
}

/// An individual audited cell correction overlay on an immutable source row.
@immutable
class DistributionCorrection {
  final String id;
  final int row;
  final String column;
  final String originalValue;
  final String effectiveValue;
  final String reason;
  final String author;
  final DateTime timestamp;
  final int revisionVersion;

  const DistributionCorrection({
    required this.id,
    required this.row,
    required this.column,
    required this.originalValue,
    required this.effectiveValue,
    required this.reason,
    required this.author,
    required this.timestamp,
    required this.revisionVersion,
  });

  DistributionCorrection copyWith({
    String? id,
    int? row,
    String? column,
    String? originalValue,
    String? effectiveValue,
    String? reason,
    String? author,
    DateTime? timestamp,
    int? revisionVersion,
  }) {
    return DistributionCorrection(
      id: id ?? this.id,
      row: row ?? this.row,
      column: column ?? this.column,
      originalValue: originalValue ?? this.originalValue,
      effectiveValue: effectiveValue ?? this.effectiveValue,
      reason: reason ?? this.reason,
      author: author ?? this.author,
      timestamp: timestamp ?? this.timestamp,
      revisionVersion: revisionVersion ?? this.revisionVersion,
    );
  }
}

/// A single row from the authoritative Course Distribution workbook (Columns A through L).
@immutable
class DistributionSourceRecord {
  final int row;
  final String batch; // Column A
  final String section; // Column B
  final String courseCode; // Column C
  final String courseTitle; // Column D
  final double credit; // Column E
  final String? prerequisite; // Column F
  final String conductingDept; // Column G
  final int? studentCount; // Column H (null means Unknown)
  final String teacher; // Column I (acronyms or Pending)
  final int classes; // Column J
  final int durationMinutes; // Column K
  final int classesPerWeek; // Column L
  final String? formulaJ;
  final String? formulaL;
  final dynamic cachedJ;
  final dynamic cachedL;
  final List<DistributionCorrection> corrections;
  final List<String> conflicts;

  const DistributionSourceRecord({
    required this.row,
    required this.batch,
    required this.section,
    required this.courseCode,
    required this.courseTitle,
    required this.credit,
    this.prerequisite,
    required this.conductingDept,
    this.studentCount,
    required this.teacher,
    required this.classes,
    required this.durationMinutes,
    required this.classesPerWeek,
    this.formulaJ,
    this.formulaL,
    this.cachedJ,
    this.cachedL,
    this.corrections = const [],
    this.conflicts = const [],
  });

  bool get hasConflict => conflicts.isNotEmpty;
  bool get hasCorrection => corrections.isNotEmpty;
  bool get isTeacherPending =>
      teacher.toLowerCase().contains('pending') || teacher == 'TBA';

  DistributionRecordStatus get status {
    if (hasConflict) return DistributionRecordStatus.conflict;
    if (isTeacherPending) return DistributionRecordStatus.pendingTeacher;
    if (hasCorrection) return DistributionRecordStatus.corrected;
    return DistributionRecordStatus.verified;
  }

  /// Returns the effective value after applying any accepted correction overlays.
  String effectiveValue(String column) {
    for (final c in corrections) {
      if (c.column.toUpperCase() == column.toUpperCase()) {
        return c.effectiveValue;
      }
    }
    switch (column.toUpperCase()) {
      case 'A':
        return batch;
      case 'B':
        return section;
      case 'C':
        return courseCode;
      case 'D':
        return courseTitle;
      case 'E':
        return credit.toString();
      case 'F':
        return prerequisite ?? 'None';
      case 'G':
        return conductingDept;
      case 'H':
        return studentCount != null ? studentCount.toString() : 'Unknown';
      case 'I':
        return teacher;
      case 'J':
        return classes.toString();
      case 'K':
        return '$durationMinutes min';
      case 'L':
        return classesPerWeek.toString();
      default:
        return '';
    }
  }

  /// Returns the original uncorrected source value.
  String originalValue(String column) {
    switch (column.toUpperCase()) {
      case 'A':
        return batch;
      case 'B':
        return section;
      case 'C':
        return courseCode;
      case 'D':
        return courseTitle;
      case 'E':
        return credit.toString();
      case 'F':
        return prerequisite ?? 'None';
      case 'G':
        return conductingDept;
      case 'H':
        return studentCount != null ? studentCount.toString() : 'Unknown';
      case 'I':
        return teacher;
      case 'J':
        return classes.toString();
      case 'K':
        return '$durationMinutes min';
      case 'L':
        return classesPerWeek.toString();
      default:
        return '';
    }
  }

  DistributionSourceRecord copyWith({
    int? row,
    String? batch,
    String? section,
    String? courseCode,
    String? courseTitle,
    double? credit,
    String? prerequisite,
    String? conductingDept,
    int? studentCount,
    String? teacher,
    int? classes,
    int durationMinutes = 50,
    int? classesPerWeek,
    String? formulaJ,
    String? formulaL,
    dynamic cachedJ,
    dynamic cachedL,
    List<DistributionCorrection>? corrections,
    List<String>? conflicts,
  }) {
    return DistributionSourceRecord(
      row: row ?? this.row,
      batch: batch ?? this.batch,
      section: section ?? this.section,
      courseCode: courseCode ?? this.courseCode,
      courseTitle: courseTitle ?? this.courseTitle,
      credit: credit ?? this.credit,
      prerequisite: prerequisite ?? this.prerequisite,
      conductingDept: conductingDept ?? this.conductingDept,
      studentCount: studentCount ?? this.studentCount,
      teacher: teacher ?? this.teacher,
      classes: classes ?? this.classes,
      durationMinutes: durationMinutes,
      classesPerWeek: classesPerWeek ?? this.classesPerWeek,
      formulaJ: formulaJ ?? this.formulaJ,
      formulaL: formulaL ?? this.formulaL,
      cachedJ: cachedJ ?? this.cachedJ,
      cachedL: cachedL ?? this.cachedL,
      corrections: corrections ?? this.corrections,
      conflicts: conflicts ?? this.conflicts,
    );
  }
}

/// Metadata describing the active accepted distribution revision context.
@immutable
class RevisionContext {
  final String scopeId;
  final String department;
  final String semester;
  final int revisionNumber;
  final int revisionVersion;
  final String status;
  final String sourceHash;
  final String sourceFileName;
  final DateTime acceptedAt;
  final String acceptedBy;
  final bool isFresh;
  final int totalRows;
  final int correctionCount;
  final int conflictCount;

  const RevisionContext({
    required this.scopeId,
    required this.department,
    required this.semester,
    required this.revisionNumber,
    required this.revisionVersion,
    required this.status,
    required this.sourceHash,
    required this.sourceFileName,
    required this.acceptedAt,
    required this.acceptedBy,
    required this.isFresh,
    required this.totalRows,
    required this.correctionCount,
    required this.conflictCount,
  });
}

/// Value control type for typed R1–R16 policy configuration inputs.
enum PolicyValueType {
  weekendPairSelector,
  intStepper,
  dayBandMatrix,
  timeWindowList,
  booleanToggle,
  slotGridSelector,
  textRule,
}

/// A policy configuration item in the revision-bound scheduling settings.
@immutable
class PolicyConfigItem {
  final String category;
  final String ruleId;
  final String label;
  final String description;
  final String defaultValue;
  final String overrideValue;
  final String effectiveValue;
  final bool isLocked;
  final String snapshotRequirement;
  final PolicyValueType valueType;
  final Map<String, dynamic> typedPayload;

  const PolicyConfigItem({
    required this.category,
    required this.ruleId,
    required this.label,
    required this.description,
    required this.defaultValue,
    required this.overrideValue,
    required this.effectiveValue,
    required this.isLocked,
    required this.snapshotRequirement,
    this.valueType = PolicyValueType.textRule,
    this.typedPayload = const {},
  });

  PolicyConfigItem copyWith({
    String? category,
    String? ruleId,
    String? label,
    String? description,
    String? defaultValue,
    String? overrideValue,
    String? effectiveValue,
    bool? isLocked,
    String? snapshotRequirement,
    PolicyValueType? valueType,
    Map<String, dynamic>? typedPayload,
  }) {
    return PolicyConfigItem(
      category: category ?? this.category,
      ruleId: ruleId ?? this.ruleId,
      label: label ?? this.label,
      description: description ?? this.description,
      defaultValue: defaultValue ?? this.defaultValue,
      overrideValue: overrideValue ?? this.overrideValue,
      effectiveValue: effectiveValue ?? this.effectiveValue,
      isLocked: isLocked ?? this.isLocked,
      snapshotRequirement: snapshotRequirement ?? this.snapshotRequirement,
      valueType: valueType ?? this.valueType,
      typedPayload: typedPayload ?? this.typedPayload,
    );
  }
}

/// A preflight readiness blocker or verification checkpoint before CP-SAT generation.
@immutable
class ReadinessItem {
  final String id;
  final String category;
  final String title;
  final String description;
  final ReadinessSeverity severity;
  final List<String> affectedEntities;
  final int targetTab;
  final int? targetRow;
  final bool isResolved;

  const ReadinessItem({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.severity,
    required this.affectedEntities,
    required this.targetTab,
    this.targetRow,
    this.isResolved = false,
  });

  ReadinessItem copyWith({
    String? id,
    String? category,
    String? title,
    String? description,
    ReadinessSeverity? severity,
    List<String>? affectedEntities,
    int? targetTab,
    int? targetRow,
    bool? isResolved,
  }) {
    return ReadinessItem(
      id: id ?? this.id,
      category: category ?? this.category,
      title: title ?? this.title,
      description: description ?? this.description,
      severity: severity ?? this.severity,
      affectedEntities: affectedEntities ?? this.affectedEntities,
      targetTab: targetTab ?? this.targetTab,
      targetRow: targetRow ?? this.targetRow,
      isResolved: isResolved ?? this.isResolved,
    );
  }
}

/// Parameters for running the CP-SAT engine, aligned to engine/solver.py tiered soft objectives.
@immutable
class SolverParameterConfig {
  final double timeLimitSeconds;
  /// Tier 1: Minimize internal student/section gaps (R3 / R9).
  final double cohortCompactnessWeight;
  /// Tier 2: Honor faculty stated preferred slot windows (R8 / R9).
  final double facultyPreferenceWeight;
  /// Tier 3: Spread 3-credit theory courses evenly across non-adjacent days (R13 / D2).
  final double theorySpreadWeight;
  /// Tier 4: Penalize assigning core sessions to late-afternoon / final periods (R15).
  final double latePeriodAvoidanceWeight;
  final bool enableSessionalBreakCrossing;
  final String engineProfile;

  const SolverParameterConfig({
    this.timeLimitSeconds = 60.0,
    this.cohortCompactnessWeight = 0.8,
    this.facultyPreferenceWeight = 0.7,
    this.theorySpreadWeight = 0.9,
    this.latePeriodAvoidanceWeight = 0.6,
    this.enableSessionalBreakCrossing = false,
    this.engineProfile = 'Standard Academic Balance (OR-Tools CP-SAT v9.8)',
  });

  // Backwards-compatible aliases
  double get teacherIdleWeight => cohortCompactnessWeight;
  double get roomTravelWeight => latePeriodAvoidanceWeight;
  double get distributionSpreadWeight => theorySpreadWeight;
  double get teacherPreferenceWeight => facultyPreferenceWeight;

  SolverParameterConfig copyWith({
    double? timeLimitSeconds,
    double? cohortCompactnessWeight,
    double? facultyPreferenceWeight,
    double? theorySpreadWeight,
    double? latePeriodAvoidanceWeight,
    bool? enableSessionalBreakCrossing,
    String? engineProfile,
    // Backwards-compatible param aliases
    double? teacherIdleWeight,
    double? roomTravelWeight,
    double? distributionSpreadWeight,
    double? teacherPreferenceWeight,
  }) {
    return SolverParameterConfig(
      timeLimitSeconds: timeLimitSeconds ?? this.timeLimitSeconds,
      cohortCompactnessWeight: cohortCompactnessWeight ??
          teacherIdleWeight ??
          this.cohortCompactnessWeight,
      facultyPreferenceWeight: facultyPreferenceWeight ??
          teacherPreferenceWeight ??
          this.facultyPreferenceWeight,
      theorySpreadWeight: theorySpreadWeight ??
          distributionSpreadWeight ??
          this.theorySpreadWeight,
      latePeriodAvoidanceWeight: latePeriodAvoidanceWeight ??
          roomTravelWeight ??
          this.latePeriodAvoidanceWeight,
      enableSessionalBreakCrossing:
          enableSessionalBreakCrossing ?? this.enableSessionalBreakCrossing,
      engineProfile: engineProfile ?? this.engineProfile,
    );
  }
}

/// Diagnostic output from a CP-SAT solver execution.
@immutable
class SolverExecutionResult {
  final SolverRunState state;
  final String outcomeLabel;
  final int hardViolations;
  final double softScorePercent;
  final int variablesExplored;
  final double elapsedSeconds;
  final List<String> conflictDetails;
  final List<SolverConflictDiagnostic> conflictDiagnostics;
  final Map<String, dynamic> diagnostics;

  const SolverExecutionResult({
    required this.state,
    required this.outcomeLabel,
    required this.hardViolations,
    required this.softScorePercent,
    required this.variablesExplored,
    required this.elapsedSeconds,
    this.conflictDetails = const [],
    this.conflictDiagnostics = const [],
    this.diagnostics = const {},
  });

  static const SolverExecutionResult ready = SolverExecutionResult(
    state: SolverRunState.ready,
    outcomeLabel: 'Engine Ready',
    hardViolations: 0,
    softScorePercent: 0,
    variablesExplored: 0,
    elapsedSeconds: 0,
  );

  bool get isNonFeasible =>
      state == SolverRunState.infeasible || hardViolations > 0;
}
