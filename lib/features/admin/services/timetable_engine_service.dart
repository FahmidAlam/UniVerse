// ============================================================
// FILE: lib/features/admin/services/timetable_engine_service.dart
// PURPOSE: The ONLY layer that talks to the FastAPI/OR-Tools
// timetable engine (HTTP) and publishes its output to Supabase.
// The engine returns rows already shaped like the `routines`
// table, so publishing makes the existing student/teacher routine
// viewers display the generated schedule with no extra code.
// Admin controller calls this; the screen never touches HTTP/Supabase.
// ============================================================

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universe_v1/core/constants/app_constants.dart';
import 'package:universe_v1/core/models/routine_model.dart';

/// One poll of a generate job.
class TimetableJobStatus {
  final String state; // queued | solving | done | failed
  final double progress; // 0.0 → 1.0
  final String? error;
  final Map<String, dynamic>? stats;
  final Map<String, dynamic>? validation;

  const TimetableJobStatus({
    required this.state,
    required this.progress,
    this.error,
    this.stats,
    this.validation,
  });

  bool get isDone => state == 'done';
  bool get isFailed => state == 'failed';

  factory TimetableJobStatus.fromMap(Map<String, dynamic> m) => TimetableJobStatus(
        state: (m['state'] as String?) ?? 'queued',
        progress: ((m['progress'] as num?) ?? 0).toDouble(),
        error: m['error'] as String?,
        stats: (m['stats'] as Map?)?.cast<String, dynamic>(),
        validation: (m['validation'] as Map?)?.cast<String, dynamic>(),
      );
}

/// The finished timetable plus solver metadata.
class TimetableResult {
  final List<RoutineEntry> rows;
  final Map<String, dynamic> stats;
  final Map<String, dynamic> validation;

  const TimetableResult({
    required this.rows,
    required this.stats,
    required this.validation,
  });
}

class TimetableEngineService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String get _base => AppConstants.timetableBaseUrl;

  // ─── Engine HTTP API ──────────────────────────────────────
  Future<String> generate() async {
    final res = await http.post(
      Uri.parse('$_base/api/timetable/generate'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(const {}),
    );
    if (res.statusCode != 200) {
      throw Exception('Engine returned ${res.statusCode}. Is the server reachable?');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final jobId = body['job_id'] as String?;
    if (jobId == null) throw Exception('Engine did not return a job id.');
    return jobId;
  }

  Future<TimetableJobStatus> pollStatus(String jobId) async {
    final res = await http.get(Uri.parse('$_base/api/timetable/status/$jobId'));
    if (res.statusCode != 200) {
      throw Exception('Could not read job status (${res.statusCode}).');
    }
    return TimetableJobStatus.fromMap(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<TimetableResult> fetchResult(String jobId) async {
    final res = await http.get(Uri.parse('$_base/api/timetable/result/$jobId'));
    if (res.statusCode != 200) {
      throw Exception('Could not fetch the generated timetable (${res.statusCode}).');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final rows = (body['rows'] as List)
        .map((r) => RoutineEntry.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
    return TimetableResult(
      rows: rows,
      stats: (body['stats'] as Map?)?.cast<String, dynamic>() ?? const {},
      validation: (body['validation'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  // ─── Publish → Supabase `routines` ────────────────────────
  /// Writes generated rows into `routines` so the existing routine
  /// viewers show them. Idempotent per cohort: clears any prior rows
  /// for each generated batch first (engine uses a fresh batch, e.g.
  /// 63, so the seeded batch 62 is never touched). Returns row count.
  Future<int> publishToRoutines(List<RoutineEntry> rows) async {
    if (rows.isEmpty) return 0;
    final batches = rows.map((r) => r.batch).toSet();
    for (final batch in batches) {
      await _supabase
          .from(AppConstants.tableRoutines)
          .delete()
          .eq('batch', batch);
    }
    final payload = rows.map((r) => r.toMap()).toList();
    await _supabase.from(AppConstants.tableRoutines).insert(payload);
    return rows.length;
  }
}
