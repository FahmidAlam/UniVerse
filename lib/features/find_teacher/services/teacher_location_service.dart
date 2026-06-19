// ============================================================
// FILE: lib/features/find_teacher/services/teacher_location_service.dart
// PURPOSE: The ONLY layer that touches Supabase to find teacher location.
// Fetches all active routines to determine where a teacher currently is
// (in which room, or free if not in a class).
// ============================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/models/routine_model.dart';

class TeacherLocationService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetch ALL active routines to cross-reference teachers.
  /// Used to find a teacher's current location and schedule.
  Future<List<RoutineEntry>> fetchAllRoutines() async {
    final rows = await _supabase
        .from(AppConstants.tableRoutines)
        .select()
        .eq('is_active', true)
        .order('time_start', ascending: true);
    return _map(rows);
  }

  /// Get all unique teacher codes (for the find/search list).
  Future<List<String>> fetchUniqueTeachers() async {
    final rows = await _supabase
        .from(AppConstants.tableRoutines)
        .select('teacher_code, teacher_name')
        .eq('is_active', true)
        .neq('teacher_code', '');

    // Extract unique teachers by code
    final teacherMap = <String, String>{};
    for (final row in rows) {
      final code = row['teacher_code'] as String?;
      final name = row['teacher_name'] as String?;
      if (code != null && code.isNotEmpty) {
        teacherMap[code] = name ?? code;
      }
    }

    return teacherMap.keys.toList()..sort();
  }

  /// Get a real-time subscription to all active routines.
  /// Useful for live teacher location updates.
  Stream<List<RoutineEntry>> streamAllRoutines() {
    return _supabase
        .from(AppConstants.tableRoutines)
        .stream(primaryKey: ['id'])
        .eq('is_active', true)
        .map((rows) => _map(rows));
  }

  List<RoutineEntry> _map(List<dynamic> rows) =>
      rows.map((r) => RoutineEntry.fromMap(r as Map<String, dynamic>)).toList();
}
