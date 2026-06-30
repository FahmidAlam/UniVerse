import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/models/routine_model.dart';

class RoutineService {
  final SupabaseClient _supabase = Supabase.instance.client;

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

  Future<List<RoutineEntry>> fetchAll() async {
    final rows = await _supabase
        .from(AppConstants.tableRoutines)
        .select()
        .order('time_start', ascending: true);
    return _map(rows);
  }

  Future<void> create(Map<String, dynamic> data) async {
    await _supabase.from(AppConstants.tableRoutines).insert(data);
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    await _supabase
        .from(AppConstants.tableRoutines)
        .update(data)
        .eq('id', id);
  }

  Future<void> delete(String id) async {
    await _supabase.from(AppConstants.tableRoutines).delete().eq('id', id);
  }

  List<RoutineEntry> _map(List<dynamic> rows) => rows
      .map((r) => RoutineEntry.fromMap(r as Map<String, dynamic>))
      .toList();
}
