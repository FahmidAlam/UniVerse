import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/models/timetable_config_model.dart';
import 'package:universe/core/utils/clock_time.dart';

class TimetableConfigService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<TimetableRoom>> fetchRooms() async {
    final rows = await _supabase
        .from(AppConstants.tableTimetableRooms)
        .select()
        .order('is_lab', ascending: false)
        .order('name');
    return (rows as List)
        .map((r) => TimetableRoom.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> createRoom(Map<String, dynamic> data) async {
    await _supabase.from(AppConstants.tableTimetableRooms).insert(data);
  }

  Future<void> updateRoom(String id, Map<String, dynamic> data) async {
    await _supabase
        .from(AppConstants.tableTimetableRooms)
        .update(data)
        .eq('id', id);
  }

  Future<void> deleteRoom(String id) async {
    await _supabase
        .from(AppConstants.tableTimetableRooms)
        .delete()
        .eq('id', id);
  }

  Future<List<TimetableFaculty>> fetchFaculty() async {
    final rows = await _supabase
        .from(AppConstants.tableTimetableFaculty)
        .select()
        .order('acronym');
    return (rows as List)
        .map((r) => TimetableFaculty.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateFaculty(String id, Map<String, dynamic> data) async {
    await _supabase
        .from(AppConstants.tableTimetableFaculty)
        .update(data)
        .eq('id', id);
  }

  Future<List<TimetableCourseEligibility>> fetchEligibility() async {
    final rows = await _supabase
        .from(AppConstants.tableTimetableEligibility)
        .select()
        .order('acronym')
        .order('priority', nullsFirst: false)
        .order('course_code');
    return (rows as List)
        .map((r) =>
            TimetableCourseEligibility.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Replace one teacher's whole course list in a single round trip.
  ///
  /// The admin screen edits a teacher at a time, so a delete-then-insert of
  /// that teacher's rows is both the simplest correct update and the only one
  /// that removes courses the admin unticked. Scoped to `acronym` so it can
  /// never touch another teacher's configuration.
  Future<void> saveEligibilityFor(
    String acronym,
    List<TimetableCourseEligibility> entries,
  ) async {
    await _supabase
        .from(AppConstants.tableTimetableEligibility)
        .delete()
        .eq('acronym', acronym);
    final payload = [
      for (final e in entries.where((e) => e.isEligible))
        {...e.toMap(), 'acronym': acronym},
    ];
    if (payload.isNotEmpty) {
      await _supabase
          .from(AppConstants.tableTimetableEligibility)
          .insert(payload);
    }
  }

  /// Course codes the admin can mark a teacher eligible for.
  ///
  /// There is no course catalog table: the Course Distribution workbook is the
  /// authority on what is offered, and it changes every term. The closest
  /// durable list the app owns is the currently published routine, so the
  /// catalog is derived from it and merged with anything already configured —
  /// so a course that has since left the routine does not silently vanish from
  /// a teacher's saved eligibility.
  Future<List<({String code, String title})>> fetchCourseCatalog() async {
    final rows = await _supabase
        .from(AppConstants.tableRoutines)
        .select('subject_code, subject');
    final byCode = <String, String>{};
    for (final r in (rows as List)) {
      final m = r as Map<String, dynamic>;
      final code = (m['subject_code'] as String?)?.trim();
      if (code == null || code.isEmpty) continue;
      byCode.putIfAbsent(code, () => (m['subject'] as String?)?.trim() ?? code);
    }
    for (final e in await fetchEligibility()) {
      byCode.putIfAbsent(e.courseCode, () => e.courseCode);
    }
    final out = byCode.entries
        .map((e) => (code: e.key, title: e.value))
        .toList()
      ..sort((a, b) => a.code.compareTo(b.code));
    return out;
  }

  Future<TimetableSettings> fetchSettings() async {
    final row = await _supabase
        .from(AppConstants.tableTimetableSettings)
        .select()
        .eq('id', 1)
        .maybeSingle();
    return row == null
        ? const TimetableSettings()
        : TimetableSettings.fromMap(row);
  }

  Future<void> saveSettings(TimetableSettings s) async {
    await _supabase
        .from(AppConstants.tableTimetableSettings)
        .upsert(s.toMap());
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
          {'name': r.name, 'is_lab': r.isLab, 'is_gallery': r.isGallery},
      ],
      // Only faculty who still teach here. `is_active` existed on the table
      // and on the model but was never applied, so a teacher who had left was
      // still shipped to the engine every run. Their historical routines are
      // unaffected — those rows are already published and are never
      // regenerated from this list.
      'teachers': [
        for (final f in faculty.where((f) => f.isActive))
          {
            'acronym': f.acronym,
            'full_name': f.fullName,
            // A teacher's HOME department. It is deliberately independent of
            // the department that owns the course they teach: a CSE lecturer
            // may take a GED course, and the engine treats both as the same
            // person's time either way.
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
      // Days taught. Omitted rather than sent empty so the engine keeps its
      // Sun–Sat default instead of scheduling into nothing.
      if (settings.workingDays.isNotEmpty) 'days': settings.workingDays,
      'settings': {
        'semester_label': settings.semesterLabel,
        'periods': _normalizePeriods(settings.periods),
        // Every university rule below used to be a literal in solver.py.
        'weeks_in_term': settings.weeksInTerm,
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

  /// Rewrites every period boundary to a canonical 24-hour clock before the
  /// engine sees it. `timetable_settings.periods` is typed in by hand from the
  /// department's workbook, so an afternoon slot often arrives as a bare
  /// "1:50" — which the engine would emit, and Postgres would store, as 01:50
  /// (1:50 AM). Both producers of `routines` rows normalize the same way; see
  /// `ClockTime`. Entries are repaired in teaching order, so a slot that ends
  /// up earlier than the one before it is pushed into the afternoon too.
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
          // `HH:MM`, never `HH:MM:SS` — the engine's render.py unpacks these
          // with `h, m = hhmm.split(":")` and a third field crashes the job.
          'start': ClockTime.toHm(repaired[i].start),
          'end': ClockTime.toHm(repaired[i].end),
        },
    ];
  }
}
