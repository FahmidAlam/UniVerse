import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/models/routine_model.dart';

class RoomStatusService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<RoutineEntry>> fetchAllRoutines() async {
    final rows = await _supabase
        .from(AppConstants.tableRoutines)
        .select()
        .eq('is_active', true)
        .order('time_start', ascending: true);
    return _map(rows);
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
