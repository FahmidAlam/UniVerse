import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/models/routine_model.dart';

class RoutineService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<RoutineEntry>> fetchForStudent({
    required String batch,
    required String section,
  }) async {
    final rows = await _fetchActive(batch: batch);
    return rows.where((r) => r.matchesStudent(batch, section)).toList();
  }

  Future<List<RoutineEntry>> fetchForTeacher(String teacherCode) async {
    final rows = await _fetchActive();
    return rows.where((r) => r.matchesTeacher(teacherCode)).toList();
  }

  Future<List<RoutineEntry>> _fetchActive({String? batch}) async {
    final all = <RoutineEntry>[];
    for (var offset = 0;; offset += 250) {
      var query = _supabase
          .from(AppConstants.tableRoutines)
          .select()
          .eq('is_active', true);
      if (batch != null) query = query.eq('batch', batch);
      final page = await query.order('id').range(offset, offset + 249);
      all.addAll(_map(page));
      if (page.length < 250) break;
    }
    all.sort((a, b) => a.timeStart.compareTo(b.timeStart));
    return all;
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
    await _supabase.from(AppConstants.tableRoutines).update(data).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _supabase.from(AppConstants.tableRoutines).delete().eq('id', id);
  }

  List<RoutineEntry> _map(List<dynamic> rows) =>
      rows.map((r) => RoutineEntry.fromMap(r as Map<String, dynamic>)).toList();
}
