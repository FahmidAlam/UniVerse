// ============================================================
// FILE: lib/features/admin/services/timetable_config_service.dart
// PURPOSE: The ONLY Supabase layer for the timetable engine config
// tables — `timetable_rooms`, `timetable_faculty`, `timetable_settings`.
// Also assembles the JSON config payload the OR-Tools engine consumes
// on generate (buildEngineConfig). Admin controllers call this; screens
// never touch Supabase.
// ============================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/models/timetable_config_model.dart';
import 'package:universe/core/utils/clock_time.dart';

class TimetableConfigService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ─── Rooms ────────────────────────────────────────────────
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

  // ─── Faculty ──────────────────────────────────────────────
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

  // ─── Settings (single row, id = 1) ────────────────────────
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

  // ─── Engine config payload ────────────────────────────────
  /// Assembles the JSON config the engine's `_normalize_config` accepts:
  /// active rooms (pools), all faculty (off-days), and settings
  /// (periods / friday rule / service scope / weights / semester label).
  Future<Map<String, dynamic>> buildEngineConfig() async {
    final results = await Future.wait([
      fetchRooms(),
      fetchFaculty(),
      fetchSettings(),
    ]);
    final rooms = results[0] as List<TimetableRoom>;
    final faculty = results[1] as List<TimetableFaculty>;
    final settings = results[2] as TimetableSettings;

    return {
      'rooms': [
        for (final r in rooms.where((r) => r.isActive))
          {'name': r.name, 'is_lab': r.isLab, 'is_gallery': r.isGallery},
      ],
      'teachers': [
        for (final f in faculty)
          {
            'acronym': f.acronym,
            'full_name': f.fullName,
            'off_days': f.offDays,
          },
      ],
      'settings': {
        'semester_label': settings.semesterLabel,
        'periods': _normalizePeriods(settings.periods),
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
          'start': repaired[i].start,
          'end': repaired[i].end,
        },
    ];
  }
}
