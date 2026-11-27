import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/models/routine_model.dart';

class TeacherLocationService {
  final SupabaseClient? _client;
  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  TeacherLocationService({SupabaseClient? client}) : _client = client;

  Future<List<RoutineEntry>> fetchAllRoutines() async {
    final rows = await _supabase
        .from(AppConstants.tableRoutines)
        .select()
        .eq('is_active', true)
        .order('time_start', ascending: true);
    return _map(rows);
  }

  Future<List<String>> fetchUniqueTeachers() async {
    List<dynamic> rows;
    try {
      rows = await _supabase
          .from(AppConstants.tableRoutines)
          .select('teacher_code, teacher_codes, teacher_name')
          .eq('is_active', true);
    } on PostgrestException {
      rows = await _supabase
          .from(AppConstants.tableRoutines)
          .select('teacher_code, teacher_name')
          .eq('is_active', true)
          .neq('teacher_code', '');
    }

    final teacherMap = <String, String>{};
    for (final rawRow in rows) {
      final row = rawRow as Map<String, dynamic>;
      final name = row['teacher_name'] as String?;
      final scalar = (row['teacher_code'] as String?)?.trim();
      final list = ((row['teacher_codes'] as List?) ?? const [])
          .map((c) => c.toString().trim())
          .where((c) => c.isNotEmpty)
          .toList(growable: false);
      final combined = {
        if (scalar != null && scalar.isNotEmpty) scalar,
        ...list,
      };
      for (final code in combined) {
        teacherMap.putIfAbsent(
          code,
          () => combined.length == 1 && name != null && name.isNotEmpty
              ? name
              : code,
        );
      }
    }

    return teacherMap.keys.toList()..sort();
  }

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
