// ============================================================
// FILE: lib/features/routine/services/routine_service.dart
// PURPOSE: The ONLY layer that touches Supabase for routines.
// Two read paths over the same table: students filter by
// batch + section, teachers filter by their teacher_code.
// Shared by the student and teacher routine screens.
// ============================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universe_v1/core/constants/app_constants.dart';
import 'package:universe_v1/core/models/routine_model.dart';

class RoutineService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // A batch+section cohort is only ever in one semester at a time, so
  // batch+section uniquely identifies their routine. We deliberately do
  // NOT filter by semester here — that would only create mismatches when
  // a profile's semester drifts out of sync with the seeded data.
  Future<List<RoutineEntry>> fetchForStudent({
    required String batch,
    required String section,
  }) async {
    final rows = await _supabase
        .from(AppConstants.tableRoutines)
        .select()
        .eq('is_active', true)
        .eq('batch', batch)
        .eq('section', section)
        .order('time_start', ascending: true);
    return _map(rows);
  }

  Future<List<RoutineEntry>> fetchForTeacher(String teacherCode) async {
    final rows = await _supabase
        .from(AppConstants.tableRoutines)
        .select()
        .eq('is_active', true)
        .eq('teacher_code', teacherCode)
        .order('time_start', ascending: true);
    return _map(rows);
  }

  List<RoutineEntry> _map(List<dynamic> rows) => rows
      .map((r) => RoutineEntry.fromMap(r as Map<String, dynamic>))
      .toList();
}
