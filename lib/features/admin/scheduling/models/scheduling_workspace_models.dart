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

enum SolverRunState {
  ready,
  solving,
  optimal,
  feasible,
  infeasible,
  timeLimitExhausted,
  error,
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
  });
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

/// Parameters for running the CP-SAT engine.
@immutable
class SolverParameterConfig {
  final double timeLimitSeconds;
  final double teacherIdleWeight;
  final double roomTravelWeight;
  final double distributionSpreadWeight;
  final double teacherPreferenceWeight;
  final bool enableSessionalBreakCrossing;
  final String engineProfile;

  const SolverParameterConfig({
    this.timeLimitSeconds = 60.0,
    this.teacherIdleWeight = 0.8,
    this.roomTravelWeight = 0.6,
    this.distributionSpreadWeight = 0.9,
    this.teacherPreferenceWeight = 0.7,
    this.enableSessionalBreakCrossing = false,
    this.engineProfile = 'Standard Academic Balance (OR-Tools CP-SAT v9.8)',
  });

  SolverParameterConfig copyWith({
    double? timeLimitSeconds,
    double? teacherIdleWeight,
    double? roomTravelWeight,
    double? distributionSpreadWeight,
    double? teacherPreferenceWeight,
    bool? enableSessionalBreakCrossing,
    String? engineProfile,
  }) {
    return SolverParameterConfig(
      timeLimitSeconds: timeLimitSeconds ?? this.timeLimitSeconds,
      teacherIdleWeight: teacherIdleWeight ?? this.teacherIdleWeight,
      roomTravelWeight: roomTravelWeight ?? this.roomTravelWeight,
      distributionSpreadWeight:
          distributionSpreadWeight ?? this.distributionSpreadWeight,
      teacherPreferenceWeight:
          teacherPreferenceWeight ?? this.teacherPreferenceWeight,
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
  final Map<String, dynamic> diagnostics;

  const SolverExecutionResult({
    required this.state,
    required this.outcomeLabel,
    required this.hardViolations,
    required this.softScorePercent,
    required this.variablesExplored,
    required this.elapsedSeconds,
    this.conflictDetails = const [],
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
}
