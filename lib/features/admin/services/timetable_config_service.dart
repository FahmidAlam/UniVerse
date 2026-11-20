// PHASE A: TimetableConfigService with Admin Core Catalog Seeding & Persistence Seams
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/models/admin_catalog_models.dart';
import 'package:universe/core/models/timetable_config_model.dart';
import 'package:universe/core/utils/clock_time.dart';
import 'package:universe/core/models/academic_model.dart';
import 'package:universe/features/admin/services/academic_config_service.dart';
import 'package:universe/features/admin/scheduling/models/scheduling_workspace_models.dart';

class TimetableConfigService {
  final SupabaseClient? _injectedClient;

  TimetableConfigService({SupabaseClient? client}) : _injectedClient = client;

  SupabaseClient? get _supabase {
    if (_injectedClient != null) return _injectedClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  // In-memory catalog stores providing offline/test fallback and Phase A staging
  static final List<CatalogCourse> _inMemoryCourses = _seedInitialCourses();
  static final List<CohortBatch> _inMemoryBatches = _seedInitialBatches();
  static final List<TimetableRoom> _inMemoryRooms = _seedInitialRooms();
  static final List<TimetableFaculty> _inMemoryFaculty = _seedInitialFaculty();

  /// Explicit opt-in canonical snapshot.
  Future<AcademicCatalog> fetchAcademicCatalog() {
    final client = _supabase;
    if (client == null) {
      return Future.value(AcademicCatalog.fromMap(const {
        'schema_version': 1,
        'departments': [],
        'calendars': [],
        'academic_years': [],
        'programs': [],
        'terms': [],
        'cohorts': [],
        'student_groups': [],
        'cohort_terms': [],
        'faculty': [],
        'rooms': [],
        'scopes': [],
        'group_aliases': [],
      }));
    }
    return AcademicConfigService(client: client).fetchCatalog();
  }

  // ==========================================
  // COURSES CATALOG CRUD (Phase A)
  // ==========================================

  Future<List<CatalogCourse>> fetchCatalogCourses() async {
    return List<CatalogCourse>.from(_inMemoryCourses);
  }

  Future<void> createCatalogCourse(CatalogCourse course) async {
    final index = _inMemoryCourses.indexWhere((c) => c.code == course.code || c.id == course.id);
    if (index != -1) {
      _inMemoryCourses[index] = course;
    } else {
      _inMemoryCourses.add(course);
    }
  }

  Future<void> updateCatalogCourse(CatalogCourse course) async {
    final index = _inMemoryCourses.indexWhere((c) => c.id == course.id || c.code == course.code);
    if (index != -1) {
      _inMemoryCourses[index] = course;
    } else {
      _inMemoryCourses.add(course);
    }
  }

  Future<void> deleteCatalogCourse(String id) async {
    _inMemoryCourses.removeWhere((c) => c.id == id || c.code == id);
  }

  // ==========================================
  // BATCHES & SECTIONS CRUD (Phase A)
  // ==========================================

  Future<List<CohortBatch>> fetchBatches() async {
    return List<CohortBatch>.from(_inMemoryBatches);
  }

  Future<void> createBatch(CohortBatch batch) async {
    final index = _inMemoryBatches.indexWhere((b) => b.id == batch.id || b.batchName == batch.batchName);
    if (index != -1) {
      _inMemoryBatches[index] = batch;
    } else {
      _inMemoryBatches.add(batch);
    }
  }

  Future<void> updateBatch(CohortBatch batch) async {
    final index = _inMemoryBatches.indexWhere((b) => b.id == batch.id || b.batchName == batch.batchName);
    if (index != -1) {
      _inMemoryBatches[index] = batch;
    } else {
      _inMemoryBatches.add(batch);
    }
  }

  Future<void> deleteBatch(String id) async {
    _inMemoryBatches.removeWhere((b) => b.id == id || b.batchName == id);
  }

  // ==========================================
  // ROOMS CRUD & CLASSIFICATIONS (Phase A)
  // ==========================================

  Future<List<TimetableRoom>> fetchRooms() async {
    final client = _supabase;
    if (client != null) {
      try {
        final rows = await client
            .from(AppConstants.tableTimetableRooms)
            .select()
            .order('is_lab', ascending: false)
            .order('name');
        final fetched = (rows as List)
            .map((r) => TimetableRoom.fromMap(r as Map<String, dynamic>))
            .toList();
        if (fetched.isNotEmpty) {
          // Sync in-memory store with fetched rooms
          for (final room in fetched) {
            final idx = _inMemoryRooms.indexWhere((r) => r.id == room.id || r.name == room.name);
            if (idx != -1) {
              // Preserve extended Phase A classification/matrix if present in memory
              _inMemoryRooms[idx] = room.copyWith(
                classification: _inMemoryRooms[idx].classification,
                boundCourseCodes: _inMemoryRooms[idx].boundCourseCodes,
                declaredWindowMatrix: _inMemoryRooms[idx].declaredWindowMatrix,
              );
            } else {
              _inMemoryRooms.add(room);
            }
          }
          return List<TimetableRoom>.from(_inMemoryRooms);
        }
      } catch (_) {
        // Fall back to in-memory seeded rooms
      }
    }
    return List<TimetableRoom>.from(_inMemoryRooms);
  }

  Future<void> createRoom(Map<String, dynamic> data) async {
    final newRoom = TimetableRoom.fromMap({
      'id': data['id'] ?? 'room-${DateTime.now().millisecondsSinceEpoch}',
      ...data,
    });
    final idx = _inMemoryRooms.indexWhere((r) => r.name == newRoom.name || r.id == newRoom.id);
    if (idx != -1) {
      _inMemoryRooms[idx] = newRoom;
    } else {
      _inMemoryRooms.add(newRoom);
    }

    final client = _supabase;
    if (client != null) {
      try {
        await client.from(AppConstants.tableTimetableRooms).insert(data);
      } catch (_) {}
    }
  }

  Future<void> updateRoom(String id, Map<String, dynamic> data) async {
    final idx = _inMemoryRooms.indexWhere((r) => r.id == id || r.name == id);
    if (idx != -1) {
      final existing = _inMemoryRooms[idx];
      _inMemoryRooms[idx] = TimetableRoom.fromMap({
        ...existing.toMap(),
        ...data,
        'id': existing.id,
      });
    }

    final client = _supabase;
    if (client != null) {
      try {
        await client
            .from(AppConstants.tableTimetableRooms)
            .update(data)
            .eq('id', id);
      } catch (_) {}
    }
  }

  Future<void> deleteRoom(String id) async {
    _inMemoryRooms.removeWhere((r) => r.id == id || r.name == id);
    final client = _supabase;
    if (client != null) {
      try {
        await client
            .from(AppConstants.tableTimetableRooms)
            .delete()
            .eq('id', id);
      } catch (_) {}
    }
  }

  // ==========================================
  // FACULTY CRUD & R4-R9 MATRICES (Phase A)
  // ==========================================

  Future<List<TimetableFaculty>> fetchFaculty() async {
    final client = _supabase;
    if (client != null) {
      try {
        final rows = await client
            .from(AppConstants.tableTimetableFaculty)
            .select()
            .order('acronym');
        final fetched = (rows as List)
            .map((r) => TimetableFaculty.fromMap(r as Map<String, dynamic>))
            .toList();
        if (fetched.isNotEmpty) {
          for (final fac in fetched) {
            final idx = _inMemoryFaculty.indexWhere((f) => f.id == fac.id || f.acronym == fac.acronym);
            if (idx != -1) {
              _inMemoryFaculty[idx] = fac.copyWith(
                employmentType: _inMemoryFaculty[idx].employmentType,
                isSustAdjunctExplicit: _inMemoryFaculty[idx].isSustAdjunctExplicit,
                sustCompactnessMode: _inMemoryFaculty[idx].sustCompactnessMode,
                isExternalGuestExplicit: _inMemoryFaculty[idx].isExternalGuestExplicit,
                hasExternalBlockExplicit: _inMemoryFaculty[idx].hasExternalBlockExplicit,
                slotMatrix: _inMemoryFaculty[idx].slotMatrix,
              );
            } else {
              _inMemoryFaculty.add(fac);
            }
          }
          return List<TimetableFaculty>.from(_inMemoryFaculty);
        }
      } catch (_) {
        // Fall back to in-memory seeded faculty
      }
    }
    return List<TimetableFaculty>.from(_inMemoryFaculty);
  }

  Future<void> createFaculty(Map<String, dynamic> data) async {
    final newFac = TimetableFaculty.fromMap({
      'id': data['id'] ?? 'fac-${DateTime.now().millisecondsSinceEpoch}',
      ...data,
    });
    final idx = _inMemoryFaculty.indexWhere((f) => f.acronym == newFac.acronym || f.id == newFac.id);
    if (idx != -1) {
      _inMemoryFaculty[idx] = newFac;
    } else {
      _inMemoryFaculty.add(newFac);
    }

    final client = _supabase;
    if (client != null) {
      try {
        await client.from(AppConstants.tableTimetableFaculty).insert(data);
      } catch (_) {}
    }
  }

  Future<void> updateFaculty(String id, Map<String, dynamic> data) async {
    final idx = _inMemoryFaculty.indexWhere((f) => f.id == id || f.acronym == id);
    if (idx != -1) {
      final existing = _inMemoryFaculty[idx];
      _inMemoryFaculty[idx] = TimetableFaculty.fromMap({
        ...existing.toMap(),
        ...data,
        'id': existing.id,
      });
    }

    final client = _supabase;
    if (client != null) {
      try {
        await client
            .from(AppConstants.tableTimetableFaculty)
            .update(data)
            .eq('id', id);
      } catch (_) {}
    }
  }

  Future<void> deleteFaculty(String id) async {
    _inMemoryFaculty.removeWhere((f) => f.id == id || f.acronym == id);
    final client = _supabase;
    if (client != null) {
      try {
        await client
            .from(AppConstants.tableTimetableFaculty)
            .delete()
            .eq('id', id);
      } catch (_) {}
    }
  }

  // ==========================================
  // ELIGIBILITY & UNIFIED CATALOG (Phase A)
  // ==========================================

  Future<List<TimetableCourseEligibility>> fetchEligibility() async {
    final client = _supabase;
    if (client != null) {
      try {
        final rows = await client
            .from(AppConstants.tableTimetableEligibility)
            .select()
            .order('acronym')
            .order('priority', nullsFirst: false)
            .order('course_code');
        return (rows as List)
            .map((r) =>
                TimetableCourseEligibility.fromMap(r as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }
    return const [];
  }

  Future<void> saveEligibilityFor(
    String acronym,
    List<TimetableCourseEligibility> entries,
  ) async {
    final client = _supabase;
    if (client != null) {
      try {
        await client
            .from(AppConstants.tableTimetableEligibility)
            .delete()
            .eq('acronym', acronym);
        final payload = [
          for (final e in entries.where((e) => e.isEligible))
            {...e.toMap(), 'acronym': acronym},
        ];
        if (payload.isNotEmpty) {
          await client
              .from(AppConstants.tableTimetableEligibility)
              .insert(payload);
        }
      } catch (_) {}
    }
  }

  /// Course codes the admin can mark a teacher eligible for.
  /// PHASE A: Reads from the unified `CatalogCourse` list first, merging any extra
  /// codes found in `routines` and existing eligibility rows.
  Future<List<({String code, String title})>> fetchCourseCatalog() async {
    final catalog = await fetchCatalogCourses();
    final byCode = <String, String>{};
    for (final c in catalog) {
      byCode[c.code] = c.title;
    }

    final client = _supabase;
    if (client != null) {
      try {
        final rows = await client
            .from(AppConstants.tableRoutines)
            .select('subject_code, subject');
        for (final r in (rows as List)) {
          final m = r as Map<String, dynamic>;
          final code = (m['subject_code'] as String?)?.trim();
          if (code == null || code.isEmpty) continue;
          byCode.putIfAbsent(code, () => (m['subject'] as String?)?.trim() ?? code);
        }
      } catch (_) {}

      try {
        for (final e in await fetchEligibility()) {
          byCode.putIfAbsent(e.courseCode, () => e.courseCode);
        }
      } catch (_) {}
    }

    final out = byCode.entries
        .map((e) => (code: e.key, title: e.value))
        .toList()
      ..sort((a, b) => a.code.compareTo(b.code));
    return out;
  }

  // ==========================================
  // PHASE B: NATIVE UI CATALOG ↔ .XLSX CO-EXISTENCE BRIDGE
  // ==========================================

  /// Synthesizes authoritative Course Distribution rows (Columns A–L) directly from
  /// native UI catalog stores (Batches, Offerings, Courses, Faculty, Rooms),
  /// enabling routine generation without requiring an external .xlsx workbook.
  Future<List<DistributionSourceRecord>> synthesizeDistributionFromCatalog() async {
    final batches = await fetchBatches();
    final courses = await fetchCatalogCourses();
    final courseMap = {for (final c in courses) c.code: c};

    final List<DistributionSourceRecord> records = [];
    int rowIndex = 5; // standard Course Distribution row start (Rows 1-4 are headers)

    for (final batch in batches) {
      for (final offering in batch.offerings) {
        final course = courseMap[offering.courseCode];
        final isSessional = course?.courseType == 'sessional';
        final credits = offering.credits ?? course?.credits ?? 3.0;
        final classesPerWeek = course?.weeklyMeetings ??
            (isSessional ? (credits <= 1.5 ? 2 : 3) : 2);
        final durationMinutes = isSessional ? 100 : 50;

        final teacherAcronyms = [
          if (offering.primaryTeacherAcronym != null && offering.primaryTeacherAcronym!.isNotEmpty)
            offering.primaryTeacherAcronym!,
          ...offering.coTeacherAcronyms,
        ];
        final teacherString = teacherAcronyms.isNotEmpty
            ? teacherAcronyms.join(' + ')
            : 'Pending';

        records.add(DistributionSourceRecord(
          row: rowIndex++,
          batch: batch.batchName,
          section: offering.targetSection,
          courseCode: offering.courseCode,
          courseTitle: course?.title ?? offering.courseCode,
          credit: credits,
          prerequisite: course?.prerequisiteCodes.isNotEmpty == true
              ? course!.prerequisiteCodes.join(', ')
              : null,
          conductingDept: course?.category ?? 'CSE',
          studentCount: offering.studentCount ?? 40,
          teacher: teacherString,
          classes: classesPerWeek,
          durationMinutes: durationMinutes,
          classesPerWeek: classesPerWeek,
          formulaJ: '=E$rowIndex',
          formulaL: '=J$rowIndex',
          cachedJ: classesPerWeek,
          cachedL: classesPerWeek,
        ));
      }
    }
    return records;
  }

  /// Hydrates the native UI catalog stores from parsed .xlsx distribution rows.
  Future<void> importCatalogFromDistributionRows(List<DistributionSourceRecord> rows) async {
    for (final r in rows) {
      // Upsert Course
      final existingCourse = _inMemoryCourses.firstWhere(
        (c) => c.code == r.courseCode,
        orElse: () => CatalogCourse(
          id: r.courseCode.toLowerCase(),
          code: r.courseCode,
          title: r.courseTitle,
          credits: r.credit,
          courseType: r.durationMinutes > 60 ? 'sessional' : 'theory',
          category: r.conductingDept,
        ),
      );
      await createCatalogCourse(existingCourse);

      // Upsert Batch & Offering
      final batchIdx = _inMemoryBatches.indexWhere((b) => b.batchName == r.batch);
      final offering = BatchCourseOffering(
        courseCode: r.courseCode,
        targetSection: r.section,
        credits: r.credit,
        primaryTeacherAcronym: r.teacher != 'Pending' ? r.teacher.split('+').first.trim() : null,
      );

      if (batchIdx != -1) {
        final b = _inMemoryBatches[batchIdx];
        final sections = Set<String>.from(b.sections)..add(r.section);
        final offerings = List<BatchCourseOffering>.from(b.offerings);
        if (!offerings.any((o) => o.courseCode == r.courseCode && o.targetSection == r.section)) {
          offerings.add(offering);
        }
        _inMemoryBatches[batchIdx] = b.copyWith(
          sections: sections.toList(),
          offerings: offerings,
        );
      } else {
        _inMemoryBatches.add(CohortBatch(
          id: 'batch-${r.batch.toLowerCase()}',
          batchName: r.batch,
          semesterLabel: 'Batch ${r.batch}',
          sections: [r.section],
          offerings: [offering],
        ));
      }
    }
  }

  /// Exports current UI catalog configuration into an audited summary map.
  Future<Map<String, dynamic>> exportCatalogToWorkbookSummary() async {
    final records = await synthesizeDistributionFromCatalog();
    final batches = await fetchBatches();
    final courses = await fetchCatalogCourses();
    final faculty = await fetchFaculty();
    final rooms = await fetchRooms();

    return {
      'totalRecords': records.length,
      'totalBatches': batches.length,
      'totalSections': batches.fold<int>(0, (sum, b) => sum + b.sections.length),
      'totalCourses': courses.length,
      'totalFaculty': faculty.length,
      'totalRooms': rooms.length,
      'generatedAt': DateTime.now().toIso8601String(),
      'records': records.map((r) => {
        'row': r.row,
        'batch': r.batch,
        'section': r.section,
        'courseCode': r.courseCode,
        'courseTitle': r.courseTitle,
        'credit': r.credit,
        'teacher': r.teacher,
        'classes': r.classes,
      }).toList(),
    };
  }

  Future<TimetableSettings> fetchSettings() async {
    final client = _supabase;
    if (client != null) {
      try {
        final row = await client
            .from(AppConstants.tableTimetableSettings)
            .select()
            .eq('id', 1)
            .maybeSingle();
        if (row != null) {
          return TimetableSettings.fromMap(row);
        }
      } catch (_) {}
    }
    return const TimetableSettings();
  }

  Future<void> saveSettings(TimetableSettings s) async {
    final client = _supabase;
    if (client != null) {
      try {
        await client.from(AppConstants.tableTimetableSettings).upsert(s.toMap());
      } catch (_) {}
    }
  }

  Future<Map<String, dynamic>> buildEngineConfig() async {
    final results = await Future.wait([
      fetchRooms(),
      fetchFaculty(),
      fetchSettings(),
      fetchEligibility(),
    ]);
    final rooms = results[0] as List<TimetableRoom>;
    final faculty = results[1] as List<TimetableFaculty>;
    final settings = results[2] as TimetableSettings;
    final eligibility = results[3] as List<TimetableCourseEligibility>;

    return {
      'rooms': [
        for (final r in rooms.where((r) => r.isActive))
          {
            'name': r.name,
            'is_lab': r.isLab,
            'is_gallery': r.isGallery,
            if (r.capacity != null) 'capacity': r.capacity
          },
      ],
      'teachers': [
        for (final f in faculty.where((f) => f.isActive))
          {
            'acronym': f.acronym,
            'full_name': f.fullName,
            'dept': f.dept,
            'off_days': f.offDays,
          },
      ],
      'eligibility': [
        for (final e in eligibility)
          {
            'acronym': e.acronym,
            'course_code': e.courseCode,
            'eligible': e.isEligible,
            'priority': e.priority,
          },
      ],
      if (settings.workingDays.isNotEmpty) 'days': settings.workingDays,
      'settings': {
        'semester_label': settings.semesterLabel,
        'periods': _normalizePeriods(settings.periods),
        'weeks_in_term': settings.weeksInTerm,
        if ((settings.fixedSessionsPerWeek ?? 0) > 0)
          'fixed_sessions_per_week': settings.fixedSessionsPerWeek,
        'blocked_periods': settings.blockedPeriods,
        'online_periods': settings.onlinePeriods,
        'allow_online_periods': settings.allowOnlinePeriods,
        'excluded_periods': settings.excludedPeriods,
        'semester_map': settings.semesterMap,
        'friday_no_p4': settings.fridayNoP4,
        'service_scope': settings.serviceScope,
        'weights': settings.weights,
      },
    };
  }

  List<dynamic> _normalizePeriods(List<dynamic> periods) {
    final maps = periods.whereType<Map>().toList();
    if (maps.isEmpty) return periods;

    final repaired = ClockTime.repairSequence([
      for (final p in maps)
        (
          start: ClockTime.normalizeOr(p['start']?.toString() ?? ''),
          end: ClockTime.normalizeOr(p['end']?.toString() ?? ''),
        ),
    ]);

    return [
      for (var i = 0; i < maps.length; i++)
        {
          ...maps[i].cast<String, dynamic>(),
          'start': ClockTime.toHm(repaired[i].start),
          'end': ClockTime.toHm(repaired[i].end),
        },
    ];
  }

  // ==========================================
  // SEEDED CATALOG INITIALIZERS
  // ==========================================

  static List<CatalogCourse> _seedInitialCourses() => [
        const CatalogCourse(
          id: 'cse-1101',
          code: 'CSE-1101',
          title: 'Structured Programming Language',
          credits: 3.0,
          courseType: 'theory',
          category: 'CSE',
          companionCourseCode: 'CSE-1102',
          preferredRoomClassification: RoomClassification.generalClassroom,
        ),
        const CatalogCourse(
          id: 'cse-1102',
          code: 'CSE-1102',
          title: 'Structured Programming Language Lab',
          credits: 1.5,
          courseType: 'sessional',
          category: 'CSE',
          companionCourseCode: 'CSE-1101',
          preferredRoomClassification: RoomClassification.cseComputerLab,
        ),
        const CatalogCourse(
          id: 'cse-2101',
          code: 'CSE-2101',
          title: 'Data Structures',
          credits: 3.0,
          courseType: 'theory',
          category: 'CSE',
          companionCourseCode: 'CSE-2102',
          prerequisiteCodes: ['CSE-1101'],
          preferredRoomClassification: RoomClassification.generalClassroom,
        ),
        const CatalogCourse(
          id: 'cse-2102',
          code: 'CSE-2102',
          title: 'Data Structures Lab',
          credits: 1.5,
          courseType: 'sessional',
          category: 'CSE',
          companionCourseCode: 'CSE-2101',
          preferredRoomClassification: RoomClassification.cseComputerLab,
        ),
        const CatalogCourse(
          id: 'cse-2103',
          code: 'CSE-2103',
          title: 'Discrete Mathematics',
          credits: 3.0,
          courseType: 'theory',
          category: 'CSE',
          preferredRoomClassification: RoomClassification.generalClassroom,
        ),
        const CatalogCourse(
          id: 'cse-2200',
          code: 'CSE-2200',
          title: 'Object-Oriented Concept Workshop',
          credits: 2.0,
          courseType: 'theory',
          category: 'CSE',
          preferredRoomClassification: RoomClassification.generalClassroom,
        ),
        const CatalogCourse(
          id: 'cse-3101',
          code: 'CSE-3101',
          title: 'Database Systems',
          credits: 3.0,
          courseType: 'theory',
          category: 'CSE',
          companionCourseCode: 'CSE-3102',
          prerequisiteCodes: ['CSE-2101'],
          preferredRoomClassification: RoomClassification.generalClassroom,
        ),
        const CatalogCourse(
          id: 'cse-3102',
          code: 'CSE-3102',
          title: 'Database Systems Lab',
          credits: 1.5,
          courseType: 'sessional',
          category: 'CSE',
          companionCourseCode: 'CSE-3101',
          preferredRoomClassification: RoomClassification.cseComputerLab,
        ),
        const CatalogCourse(
          id: 'cse-3105',
          code: 'CSE-3105',
          title: 'Microprocessors & Assembly Language',
          credits: 3.0,
          courseType: 'theory',
          category: 'CSE',
          companionCourseCode: 'CSE-3106',
          preferredRoomClassification: RoomClassification.lectureGallery,
        ),
        const CatalogCourse(
          id: 'cse-3106',
          code: 'CSE-3106',
          title: 'Microprocessors & Assembly Lab',
          credits: 1.5,
          courseType: 'sessional',
          category: 'CSE',
          companionCourseCode: 'CSE-3105',
          preferredRoomClassification: RoomClassification.cseComputerLab,
        ),
        const CatalogCourse(
          id: 'eee-2101',
          code: 'EEE-2101',
          title: 'Electronic Devices and Circuits',
          credits: 3.0,
          courseType: 'theory',
          category: 'EEE',
          companionCourseCode: 'EEE-2102',
          preferredRoomClassification: RoomClassification.generalClassroom,
        ),
        const CatalogCourse(
          id: 'eee-2102',
          code: 'EEE-2102',
          title: 'Electronic Devices & Circuits Lab',
          credits: 1.5,
          courseType: 'sessional',
          category: 'EEE',
          companionCourseCode: 'EEE-2101',
          preferredRoomClassification: RoomClassification.eclLab,
        ),
        const CatalogCourse(
          id: 'phy-1101',
          code: 'PHY-1101',
          title: 'Physics',
          credits: 3.0,
          courseType: 'theory',
          category: 'PHY',
          companionCourseCode: 'PHY-1102',
          preferredRoomClassification: RoomClassification.generalClassroom,
        ),
        const CatalogCourse(
          id: 'phy-1102',
          code: 'PHY-1102',
          title: 'Physics Lab',
          credits: 1.5,
          courseType: 'sessional',
          category: 'PHY',
          companionCourseCode: 'PHY-1101',
          preferredRoomClassification: RoomClassification.physicsLab,
        ),
        const CatalogCourse(
          id: 'mat-1101',
          code: 'MAT-1101',
          title: 'Differential and Integral Calculus',
          credits: 3.0,
          courseType: 'theory',
          category: 'MAT',
          preferredRoomClassification: RoomClassification.generalClassroom,
        ),
        const CatalogCourse(
          id: 'eng-1101',
          code: 'ENG-1101',
          title: 'English Language Skills',
          credits: 3.0,
          courseType: 'theory',
          category: 'ENG',
          preferredRoomClassification: RoomClassification.generalClassroom,
        ),
        const CatalogCourse(
          id: 'ged-1101',
          code: 'GED-1101',
          title: 'Bangladesh Studies',
          credits: 3.0,
          courseType: 'theory',
          category: 'GED',
          preferredRoomClassification: RoomClassification.generalClassroom,
        ),
      ];

  static List<CohortBatch> _seedInitialBatches() => [
        const CohortBatch(
          id: 'batch-58',
          batchName: 'Batch 58',
          semesterLabel: '5th Semester',
          sections: ['A', 'B', 'C'],
          combinedSections: ['B+C'],
          sectionWeekends: {
            'A': ['Thu', 'Fri'],
            'B': ['Thu', 'Fri'],
            'C': ['Sun', 'Mon'],
          },
          sectionWeeklyDaysOffCount: {
            'A': 2,
            'B': 2,
            'C': 3,
          },
          offerings: [
            BatchCourseOffering(
              courseCode: 'CSE-3101',
              targetSection: 'A',
              primaryTeacherAcronym: 'MSA',
              studentCount: 48,
              credits: 3.0,
            ),
            BatchCourseOffering(
              courseCode: 'CSE-3102',
              targetSection: 'A',
              primaryTeacherAcronym: 'MSA',
              coTeacherAcronyms: ['NJ'],
              preferredRoomName: 'CSE Lab 1',
              studentCount: 48,
              credits: 1.5,
            ),
            BatchCourseOffering(
              courseCode: 'CSE-3101',
              targetSection: 'B',
              primaryTeacherAcronym: 'FK',
              studentCount: 46,
              credits: 3.0,
            ),
            BatchCourseOffering(
              courseCode: 'CSE-3102',
              targetSection: 'B',
              primaryTeacherAcronym: 'FK',
              coTeacherAcronyms: ['SR'],
              preferredRoomName: 'CSE Lab 1',
              studentCount: 46,
              credits: 1.5,
            ),
            BatchCourseOffering(
              courseCode: 'CSE-3101',
              targetSection: 'C',
              primaryTeacherAcronym: 'MSR',
              studentCount: 45,
              credits: 3.0,
            ),
            BatchCourseOffering(
              courseCode: 'CSE-3102',
              targetSection: 'C',
              primaryTeacherAcronym: 'MSR',
              coTeacherAcronyms: ['ZI'],
              preferredRoomName: 'CSE Lab 2',
              studentCount: 45,
              credits: 1.5,
            ),
            BatchCourseOffering(
              courseCode: 'CSE-3105',
              targetSection: 'B+C',
              primaryTeacherAcronym: 'FA',
              preferredRoomName: 'Gallery 1',
              studentCount: 91,
              credits: 3.0,
            ),
          ],
        ),
        const CohortBatch(
          id: 'batch-59',
          batchName: 'Batch 59',
          semesterLabel: '4th Semester',
          sections: ['A', 'B'],
          combinedSections: [],
          sectionWeekends: {
            'A': ['Fri', 'Sat'],
            'B': ['Fri', 'Sat'],
          },
          sectionWeeklyDaysOffCount: {
            'A': 2,
            'B': 2,
          },
          offerings: [
            BatchCourseOffering(
              courseCode: 'CSE-2101',
              targetSection: 'A',
              primaryTeacherAcronym: 'SR',
              studentCount: 50,
              credits: 3.0,
            ),
            BatchCourseOffering(
              courseCode: 'CSE-2102',
              targetSection: 'A',
              primaryTeacherAcronym: 'SR',
              preferredRoomName: 'CSE Lab 2',
              studentCount: 50,
              credits: 1.5,
            ),
          ],
        ),
        const CohortBatch(
          id: 'batch-60',
          batchName: 'Batch 60',
          semesterLabel: '3rd Semester',
          sections: ['A', 'B', 'C'],
          combinedSections: ['A+B'],
          sectionWeekends: {
            'A': ['Thu', 'Fri'],
            'B': ['Thu', 'Fri'],
            'C': ['Thu', 'Fri'],
          },
          sectionWeeklyDaysOffCount: {
            'A': 2,
            'B': 2,
            'C': 2,
          },
          offerings: [
            BatchCourseOffering(
              courseCode: 'CSE-1101',
              targetSection: 'A',
              primaryTeacherAcronym: 'MSA',
              studentCount: 52,
              credits: 3.0,
            ),
            BatchCourseOffering(
              courseCode: 'CSE-1102',
              targetSection: 'A',
              primaryTeacherAcronym: 'MSA',
              coTeacherAcronyms: ['NJ'],
              preferredRoomName: 'CSE Lab 1',
              studentCount: 52,
              credits: 1.5,
            ),
          ],
        ),
      ];

  static List<TimetableRoom> _seedInitialRooms() => [
        const TimetableRoom(
          id: 'room-301',
          name: 'Room 301',
          building: 'Academic Building A',
          capacity: 60,
          inActiveSemesterPool: true,
          classification: RoomClassification.generalClassroom,
        ),
        const TimetableRoom(
          id: 'room-302',
          name: 'Room 302',
          building: 'Academic Building A',
          capacity: 55,
          inActiveSemesterPool: true,
          classification: RoomClassification.generalClassroom,
        ),
        const TimetableRoom(
          id: 'room-303',
          name: 'Room 303',
          building: 'Academic Building A',
          capacity: 50,
          inActiveSemesterPool: true,
          classification: RoomClassification.generalClassroom,
        ),
        const TimetableRoom(
          id: 'cse-lab-1',
          name: 'CSE Lab 1',
          building: 'Academic Building B',
          isLab: true,
          capacity: 45,
          inActiveSemesterPool: true,
          classification: RoomClassification.cseComputerLab,
        ),
        const TimetableRoom(
          id: 'cse-lab-2',
          name: 'CSE Lab 2',
          building: 'Academic Building B',
          isLab: true,
          capacity: 45,
          inActiveSemesterPool: true,
          classification: RoomClassification.cseComputerLab,
        ),
        const TimetableRoom(
          id: 'ecl-lab-1',
          name: 'ECL Lab 1',
          building: 'EEE Building C',
          isLab: true,
          capacity: 40,
          inActiveSemesterPool: true,
          classification: RoomClassification.eclLab,
          declaredWindowMatrix: {
            'Sun:0': true,
            'Sun:1': true,
            'Mon:2': true,
            'Mon:3': true,
          },
        ),
        const TimetableRoom(
          id: 'physics-lab-1',
          name: 'Physics Lab',
          building: 'Science Building C',
          isLab: true,
          capacity: 40,
          inActiveSemesterPool: true,
          classification: RoomClassification.physicsLab,
          boundCourseCodes: ['PHY-1102', 'PHY-1202'],
        ),
        const TimetableRoom(
          id: 'gallery-1',
          name: 'Gallery 1',
          building: 'Academic Building A',
          isGallery: true,
          capacity: 120,
          inActiveSemesterPool: true,
          classification: RoomClassification.lectureGallery,
        ),
      ];

  static List<TimetableFaculty> _seedInitialFaculty() => [
        const TimetableFaculty(
          id: 'fac-msr',
          acronym: 'MSR',
          fullName: 'Prof. Dr. M. S. Rahman',
          dept: 'CSE',
          designation: 'Professor',
          employmentType: 'permanent',
          offDays: ['Fri', 'Sat'],
          slotMatrix: {
            'Sun:0': 'preferred_r8',
            'Sun:1': 'preferred_r8',
          },
        ),
        const TimetableFaculty(
          id: 'fac-msa',
          acronym: 'MSA',
          fullName: 'Md. Sajjad Ali',
          dept: 'CSE',
          designation: 'Assistant Professor',
          employmentType: 'permanent',
          offDays: ['Fri', 'Sat'],
          hasExternalBlockExplicit: true,
          slotMatrix: {
            'Mon:1': 'external_block_r4',
          },
        ),
        const TimetableFaculty(
          id: 'fac-fa',
          acronym: 'FA',
          fullName: 'Fahim Ahmed',
          dept: 'CSE',
          designation: 'Senior Lecturer',
          employmentType: 'permanent',
          offDays: ['Thu', 'Fri'],
          hasExternalBlockExplicit: true,
        ),
        const TimetableFaculty(
          id: 'fac-fk',
          acronym: 'FK',
          fullName: 'Farhana Khanam',
          dept: 'CSE',
          designation: 'Lecturer',
          employmentType: 'adjunct',
          isSustAdjunctExplicit: true,
          sustCompactnessMode: 'before_break',
          offDays: ['Sun', 'Mon', 'Wed'],
        ),
        const TimetableFaculty(
          id: 'fac-nj',
          acronym: 'NJ',
          fullName: 'Nazmul Jamil',
          dept: 'CSE',
          designation: 'Lecturer',
          employmentType: 'adjunct',
          isSustAdjunctExplicit: true,
          sustCompactnessMode: 'after_break',
          offDays: ['Sun', 'Tue', 'Wed'],
        ),
        const TimetableFaculty(
          id: 'fac-sr',
          acronym: 'SR',
          fullName: 'Shakil Rifat',
          dept: 'CSE',
          designation: 'Lecturer',
          employmentType: 'permanent',
          offDays: ['Fri', 'Sat'],
        ),
        const TimetableFaculty(
          id: 'fac-zi',
          acronym: 'ZI',
          fullName: 'Zahidul Islam',
          dept: 'CSE',
          designation: 'Lecturer',
          employmentType: 'permanent',
          offDays: ['Fri', 'Sat'],
        ),
        const TimetableFaculty(
          id: 'fac-sh',
          acronym: 'SH',
          fullName: 'Dr. S. H. Chowdhury',
          dept: 'EEE',
          designation: 'Professor',
          employmentType: 'adjunct',
          isExternalGuestExplicit: true,
          offDays: ['Sun', 'Mon', 'Wed', 'Thu'],
          slotMatrix: {
            'Tue:0': 'guest_window_r5',
            'Tue:1': 'guest_window_r5',
          },
        ),
      ];
}
