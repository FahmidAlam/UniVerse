// ============================================================
// FILE: lib/features/admin/services/timetable_config_service.dart
// PURPOSE: The ONLY Supabase layer for the timetable engine config
// tables — `timetable_rooms`, `timetable_faculty`, `timetable_settings`.
// Also assembles the JSON config payload the OR-Tools engine consumes
// on generate (buildEngineConfig). Admin controllers call this; screens
// never touch Supabase.
// ============================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universe_v1/core/constants/app_constants.dart';
import 'package:universe_v1/core/models/timetable_config_model.dart';

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
        'periods': settings.periods,
        'friday_no_p4': settings.fridayNoP4,
        'service_scope': settings.serviceScope,
        'weights': settings.weights,
      },
    };
  }
}
