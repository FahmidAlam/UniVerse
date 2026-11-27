import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/models/timetable_config_model.dart';

/// Mobile-safe R8 preferred teaching-day service for signed-in faculty profiles.
class TeacherR8PreferenceService {
  final SupabaseClient? _client;

  TeacherR8PreferenceService({SupabaseClient? client}) : _client = client;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  /// True when PostgREST denies access under RLS/grants (`42501`).
  @visibleForTesting
  static bool isPermissionDenied(Object error) =>
      error is PostgrestException && error.code == '42501';

  Future<List<TimetableFaculty>> fetchFaculty() async {
    try {
      final rows = await _supabase
          .from(AppConstants.tableTimetableFaculty)
          .select()
          .order('acronym');
      return (rows as List)
          .map((r) => TimetableFaculty.fromMap(r as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (error) {
      if (isPermissionDenied(error)) {
        // Non-admin teachers are denied admin-only timetable_faculty RLS; fall back cleanly.
        return const <TimetableFaculty>[];
      }
      rethrow;
    }
  }

  Future<void> updateFacultySlotMatrix(
    String id,
    Map<String, String> slotMatrix,
  ) async {
    await _supabase
        .from(AppConstants.tableTimetableFaculty)
        .update({'slot_matrix': slotMatrix})
        .eq('id', id);
  }
}
