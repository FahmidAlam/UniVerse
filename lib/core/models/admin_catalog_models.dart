// PHASE A: Admin Core Catalog & Entity Models (Courses, Batches, Joint Sections, Offerings, RoomClassifications)
import 'package:flutter/material.dart';
import 'package:universe/core/theme/app_colors.dart';

/// Explicit room classifications mapping to Routine Committee Rules R10, R11, and R14.
enum RoomClassification {
  generalClassroom,
  cseComputerLab,
  eclLab,
  physicsLab,
  lectureGallery;

  String get displayName {
    switch (this) {
      case RoomClassification.generalClassroom:
        return 'General Classroom [R14]';
      case RoomClassification.cseComputerLab:
        return 'CSE Computer Lab';
      case RoomClassification.eclLab:
        return 'ECL Lab (EEE Dept — Rule R10)';
      case RoomClassification.physicsLab:
        return 'Physics Lab (Rule R11)';
      case RoomClassification.lectureGallery:
        return 'Lecture Gallery';
    }
  }

  String get shortName {
    switch (this) {
      case RoomClassification.generalClassroom:
        return 'General [R14]';
      case RoomClassification.cseComputerLab:
        return 'CSE Lab';
      case RoomClassification.eclLab:
        return 'ECL Lab [R10]';
      case RoomClassification.physicsLab:
        return 'Physics Lab [R11]';
      case RoomClassification.lectureGallery:
        return 'Gallery';
    }
  }

  bool get isLab =>
      this == RoomClassification.cseComputerLab ||
      this == RoomClassification.eclLab ||
      this == RoomClassification.physicsLab;

  static RoomClassification fromString(String? val) {
    if (val == null) return RoomClassification.generalClassroom;
    final s = val.toLowerCase().trim();
    if (s.contains('gallery')) return RoomClassification.lectureGallery;
    if (s.contains('physics') || s.contains('phy')) return RoomClassification.physicsLab;
    if (s.contains('ecl') || s.contains('eee')) return RoomClassification.eclLab;
    if (s.contains('cse') || s.contains('comp') || s.contains('lab')) {
      return RoomClassification.cseComputerLab;
    }
    return RoomClassification.generalClassroom;
  }
}

/// Course definition in the unified Admin Course Catalog.
class CatalogCourse {
  final String id;
  final String code; // e.g., 'CSE-3101'
  final String title; // e.g., 'Database Systems'
  final double credits; // 1.0, 1.5, 2.0, 3.0
  final String courseType; // 'theory' | 'sessional'
  final String category; // 'CSE', 'GED', 'ENG', 'PHY', 'CHE', 'EEE', 'MAT'
  final String? companionCourseCode; // Links Theory <-> Sessional
  final List<String> prerequisiteCodes;
  final int? weeklyMeetingsOverride;
  final RoomClassification preferredRoomClassification;
  final bool isRetake;
  final bool isActive;

  const CatalogCourse({
    required this.id,
    required this.code,
    required this.title,
    required this.credits,
    required this.courseType,
    this.category = 'CSE',
    this.companionCourseCode,
    this.prerequisiteCodes = const [],
    this.weeklyMeetingsOverride,
    this.preferredRoomClassification = RoomClassification.generalClassroom,
    this.isRetake = false,
    this.isActive = true,
  });

  /// Rule R12: Sessional credits <= 1.5 -> 2 lab slots/wk; credits > 1.5 -> 3 slots/wk.
  /// Rule R13: CSE theory credits <= 2.0 -> 2 slots/wk in 1 day block; credits > 2.0 -> 3 slots/wk (or standard 2-3).
  int get defaultWeeklyMeetings {
    if (courseType == 'sessional') {
      return credits <= 1.5 ? 2 : 3;
    }
    return credits <= 2.0 ? 2 : 3;
  }

  int get weeklyMeetings => weeklyMeetingsOverride ?? defaultWeeklyMeetings;

  /// Rule R13: 1–2 Cr CSE theory completed in 1 day, 2 consecutive slots, same room.
  bool get isR13SingleDayBlock =>
      courseType == 'theory' && category == 'CSE' && credits <= 2.0;

  bool get isTheory => courseType == 'theory';
  bool get isSessional => courseType == 'sessional';

  String get r12OrR13BadgeLabel {
    if (courseType == 'sessional') {
      return credits <= 1.5
          ? 'R12 · 2 Lab Slots/Wk'
          : 'R12 · 3 Lab Slots/Wk (2 Consec Pref)';
    }
    if (isR13SingleDayBlock) {
      return 'R13 · 1-Day 2-Slot Block';
    }
    return 'Standard 3x/Wk';
  }

  Color get ruleBadgeColor {
    if (courseType == 'sessional') {
      return AppColors.roleTeacher; // Emerald #10B981
    }
    if (isR13SingleDayBlock) {
      return AppColors.info; // Cyan #38BDF8
    }
    return AppColors.textSecondary; // Calm slate-gray
  }

  factory CatalogCourse.fromMap(Map<String, dynamic> m) {
    return CatalogCourse(
      id: (m['id'] as String?) ?? (m['code'] as String? ?? ''),
      code: (m['code'] as String?) ?? '',
      title: (m['title'] as String?) ?? '',
      credits: (m['credits'] as num?)?.toDouble() ?? 3.0,
      courseType: (m['course_type'] as String?) ?? 'theory',
      category: (m['category'] as String?) ?? 'CSE',
      companionCourseCode: m['companion_course_code'] as String?,
      prerequisiteCodes: ((m['prerequisite_codes'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      weeklyMeetingsOverride: (m['weekly_meetings'] as num?)?.toInt(),
      preferredRoomClassification:
          RoomClassification.fromString(m['preferred_room_classification'] as String?),
      isRetake: (m['is_retake'] as bool?) ?? false,
      isActive: (m['is_active'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'code': code,
        'title': title,
        'credits': credits,
        'course_type': courseType,
        'category': category,
        'companion_course_code': companionCourseCode,
        'prerequisite_codes': prerequisiteCodes,
        'weekly_meetings': weeklyMeetings,
        'preferred_room_classification': preferredRoomClassification.name,
        'is_retake': isRetake,
        'is_active': isActive,
      };

  CatalogCourse copyWith({
    String? id,
    String? code,
    String? title,
    double? credits,
    String? courseType,
    String? category,
    String? companionCourseCode,
    bool clearCompanion = false,
    List<String>? prerequisiteCodes,
    int? weeklyMeetingsOverride,
    bool clearWeeklyMeetingsOverride = false,
    RoomClassification? preferredRoomClassification,
    bool? isRetake,
    bool? isActive,
  }) {
    return CatalogCourse(
      id: id ?? this.id,
      code: code ?? this.code,
      title: title ?? this.title,
      credits: credits ?? this.credits,
      courseType: courseType ?? this.courseType,
      category: category ?? this.category,
      companionCourseCode: clearCompanion
          ? null
          : (companionCourseCode ?? this.companionCourseCode),
      prerequisiteCodes: prerequisiteCodes ?? this.prerequisiteCodes,
      weeklyMeetingsOverride: clearWeeklyMeetingsOverride
          ? null
          : (weeklyMeetingsOverride ?? this.weeklyMeetingsOverride),
      preferredRoomClassification:
          preferredRoomClassification ?? this.preferredRoomClassification,
      isRetake: isRetake ?? this.isRetake,
      isActive: isActive ?? this.isActive,
    );
  }
}

/// Course offering bound to a specific cohort batch section or joint section.
class BatchCourseOffering {
  final String courseCode;
  final String targetSection; // 'A', 'B', or combined 'B+C'
  final String? primaryTeacherAcronym;
  final List<String> coTeacherAcronyms;
  final String? preferredRoomName;
  final int? studentCount;
  final bool isRetakeSection;
  final double? credits;

  const BatchCourseOffering({
    required this.courseCode,
    required this.targetSection,
    this.primaryTeacherAcronym,
    this.coTeacherAcronyms = const [],
    this.preferredRoomName,
    this.studentCount,
    this.isRetakeSection = false,
    this.credits,
  });

  factory BatchCourseOffering.fromMap(Map<String, dynamic> m) {
    return BatchCourseOffering(
      courseCode: (m['course_code'] as String?) ?? '',
      targetSection: (m['target_section'] as String?) ?? 'A',
      primaryTeacherAcronym: m['primary_teacher_acronym'] as String?,
      coTeacherAcronyms: ((m['co_teacher_acronyms'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      preferredRoomName: m['preferred_room_name'] as String?,
      studentCount: (m['student_count'] as num?)?.toInt(),
      isRetakeSection: (m['is_retake_section'] as bool?) ?? false,
      credits: (m['credits'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'course_code': courseCode,
        'target_section': targetSection,
        'primary_teacher_acronym': primaryTeacherAcronym,
        'co_teacher_acronyms': coTeacherAcronyms,
        'preferred_room_name': preferredRoomName,
        'student_count': studentCount,
        'is_retake_section': isRetakeSection,
        if (credits != null) 'credits': credits,
      };

  BatchCourseOffering copyWith({
    String? courseCode,
    String? targetSection,
    String? primaryTeacherAcronym,
    List<String>? coTeacherAcronyms,
    String? preferredRoomName,
    int? studentCount,
    bool? isRetakeSection,
    double? credits,
  }) {
    return BatchCourseOffering(
      courseCode: courseCode ?? this.courseCode,
      targetSection: targetSection ?? this.targetSection,
      primaryTeacherAcronym:
          primaryTeacherAcronym ?? this.primaryTeacherAcronym,
      coTeacherAcronyms: coTeacherAcronyms ?? this.coTeacherAcronyms,
      preferredRoomName: preferredRoomName ?? this.preferredRoomName,
      studentCount: studentCount ?? this.studentCount,
      isRetakeSection: isRetakeSection ?? this.isRetakeSection,
      credits: credits ?? this.credits,
    );
  }
}

/// Cohort Batch with Section structure and Committee Rules R1 and R2 verification.
class CohortBatch {
  final String id;
  final String batchName; // e.g., 'Batch 58'
  final String semesterLabel; // e.g., '5th Semester'
  final List<String> sections; // e.g., ['A', 'B', 'C']
  final List<String> combinedSections; // e.g., ['B+C']
  final Map<String, List<String>> sectionWeekends; // e.g., {'A': ['Thu', 'Fri'], 'B': ['Thu', 'Fri'], 'C': ['Sun', 'Mon']}
  final Map<String, int> sectionWeeklyDaysOffCount; // for Rule R2 parity check
  final List<BatchCourseOffering> offerings;

  const CohortBatch({
    required this.id,
    required this.batchName,
    required this.semesterLabel,
    this.sections = const ['A'],
    this.combinedSections = const [],
    this.sectionWeekends = const {},
    this.sectionWeeklyDaysOffCount = const {},
    this.offerings = const [],
  });

  /// Total distinct credits assigned across offerings in this batch.
  double get totalCreditsOffered {
    final distinct = <String, double>{};
    for (final o in offerings) {
      if (o.credits != null && !distinct.containsKey(o.courseCode)) {
        distinct[o.courseCode] = o.credits!;
      }
    }
    if (distinct.isNotEmpty) {
      return distinct.values.fold(0.0, (sum, c) => sum + c);
    }
    return offerings.length * 3.0; // fallback if credit metadata absent
  }

  /// Max difference of days off between any two sections in this batch.
  int get daysOffVariance {
    if (sectionWeeklyDaysOffCount.isEmpty) return 0;
    final values = sectionWeeklyDaysOffCount.values.toList();
    if (values.length <= 1) return 0;
    final maxD = values.reduce((a, b) => a > b ? a : b);
    final minD = values.reduce((a, b) => a < b ? a : b);
    return maxD - minD;
  }

  /// Rule R2: Max 1 day difference between sections in the same batch.
  bool get satisfiesR2Parity => daysOffVariance <= 1;

  /// Rule R1: Verifies the section has 2 consecutive days off in the weekly cycle.
  bool satisfiesR1ConsecutiveWeekend(String section) {
    final days = sectionWeekends[section];
    if (days == null || days.length < 2) return true; // Unset / default baseline
    const cycle = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
    final d0 = days[0].trim().toLowerCase();
    final d1 = days[1].trim().toLowerCase();
    final s0 = d0.length >= 3 ? d0.substring(0, 3) : d0;
    final s1 = d1.length >= 3 ? d1.substring(0, 3) : d1;
    final i1 = cycle.indexOf(s0);
    final i2 = cycle.indexOf(s1);
    if (i1 == -1 || i2 == -1) return false;
    final diff = (i1 - i2).abs();
    return diff == 1 || diff == 6; // Adjacent or Sun(0) & Sat(6)
  }

  bool get satisfiesAllR1Weekends {
    for (final sec in sections) {
      if (!satisfiesR1ConsecutiveWeekend(sec)) return false;
    }
    return true;
  }

  factory CohortBatch.fromMap(Map<String, dynamic> m) {
    final rawWeekends = m['section_weekends'] as Map?;
    final weekends = <String, List<String>>{};
    if (rawWeekends != null) {
      for (final entry in rawWeekends.entries) {
        weekends[entry.key.toString()] = ((entry.value as List?) ?? const [])
            .map((e) => e.toString())
            .toList();
      }
    }

    final rawDaysOff = m['section_weekly_days_off_count'] as Map?;
    final daysOff = <String, int>{};
    if (rawDaysOff != null) {
      for (final entry in rawDaysOff.entries) {
        final val = entry.value;
        if (val is num) daysOff[entry.key.toString()] = val.toInt();
      }
    }

    final rawOfferings = (m['offerings'] as List?) ?? const [];
    final offerings = rawOfferings
        .whereType<Map<String, dynamic>>()
        .map((e) => BatchCourseOffering.fromMap(e))
        .toList();

    return CohortBatch(
      id: (m['id'] as String?) ?? (m['batch_name'] as String? ?? ''),
      batchName: (m['batch_name'] as String?) ?? '',
      semesterLabel: (m['semester_label'] as String?) ?? '',
      sections: ((m['sections'] as List?) ?? const ['A'])
          .map((e) => e.toString())
          .toList(),
      combinedSections: ((m['combined_sections'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      sectionWeekends: weekends,
      sectionWeeklyDaysOffCount: daysOff,
      offerings: offerings,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'batch_name': batchName,
        'semester_label': semesterLabel,
        'sections': sections,
        'combined_sections': combinedSections,
        'section_weekends': sectionWeekends,
        'section_weekly_days_off_count': sectionWeeklyDaysOffCount,
        'offerings': offerings.map((o) => o.toMap()).toList(),
      };

  CohortBatch copyWith({
    String? id,
    String? batchName,
    String? semesterLabel,
    List<String>? sections,
    List<String>? combinedSections,
    Map<String, List<String>>? sectionWeekends,
    Map<String, int>? sectionWeeklyDaysOffCount,
    List<BatchCourseOffering>? offerings,
  }) {
    return CohortBatch(
      id: id ?? this.id,
      batchName: batchName ?? this.batchName,
      semesterLabel: semesterLabel ?? this.semesterLabel,
      sections: sections ?? this.sections,
      combinedSections: combinedSections ?? this.combinedSections,
      sectionWeekends: sectionWeekends ?? this.sectionWeekends,
      sectionWeeklyDaysOffCount:
          sectionWeeklyDaysOffCount ?? this.sectionWeeklyDaysOffCount,
      offerings: offerings ?? this.offerings,
    );
  }
}
