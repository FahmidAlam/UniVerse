// ============================================================
// FILE: lib/features/admin/services/timetable_engine_service.dart
// PURPOSE: The ONLY layer that talks to the FastAPI/OR-Tools timetable
// engine (HTTP) and to Supabase for publishing/recording its output.
// Flutter uploads the Main Distribution .xlsx + DB-sourced config, polls
// the job, fetches rows + report, downloads the rendered workbook (and
// stores it in the `timetables` bucket), publishes rows to `routines`,
// and records the run in `timetable_runs`.
// Admin controller calls this; the screen never touches HTTP/Supabase.
// ============================================================

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universe_v1/core/constants/app_constants.dart';
import 'package:universe_v1/core/models/routine_model.dart';

/// One poll of a generate job.
class TimetableJobStatus {
  final String state; // queued | ingesting | solving | rendering | done | failed
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

/// Ingest report shown before/with the solved result.
class TimetableReport {
  final List<String> cohorts;
  final Map<String, dynamic> meta;
  final List<Map<String, dynamic>> excluded;
  final List<String> warnings;

  const TimetableReport({
    this.cohorts = const [],
    this.meta = const {},
    this.excluded = const [],
    this.warnings = const [],
  });

  factory TimetableReport.fromMap(Map<String, dynamic> m) => TimetableReport(
        cohorts: ((m['cohorts'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        meta: (m['meta'] as Map?)?.cast<String, dynamic>() ?? const {},
        excluded: ((m['excluded'] as List?) ?? const [])
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList(),
        warnings: ((m['warnings'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
      );
}

/// The finished timetable plus solver metadata and ingest report.
class TimetableResult {
  final List<RoutineEntry> rows;
  final Map<String, dynamic> stats;
  final Map<String, dynamic> validation;
  final TimetableReport report;

  const TimetableResult({
    required this.rows,
    required this.stats,
    required this.validation,
    required this.report,
  });
}

class TimetableEngineService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String get _base => AppConstants.timetableBaseUrl;

  // ─── Engine HTTP API ──────────────────────────────────────
  /// Uploads the distribution workbook + config; returns the job id.
  Future<String> generate({
    required Uint8List fileBytes,
    required String filename,
    Map<String, dynamic>? config,
    double timeLimitS = 60,
  }) async {
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('$_base/api/timetable/generate'),
    );
    req.files.add(http.MultipartFile.fromBytes('file', fileBytes,
        filename: filename));
    if (config != null) req.fields['config'] = jsonEncode(config);
    req.fields['time_limit_s'] = timeLimitS.toString();

    final res = await http.Response.fromStream(await req.send());
    if (res.statusCode != 200) {
      throw Exception(
          'Engine returned ${res.statusCode}. Is the server reachable?');
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
      report: TimetableReport.fromMap(
          (body['report'] as Map?)?.cast<String, dynamic>() ?? const {}),
    );
  }

  /// Downloads the rendered .xlsx bytes for a finished job.
  Future<Uint8List> downloadWorkbook(String jobId) async {
    final res = await http.get(Uri.parse('$_base/api/timetable/download/$jobId'));
    if (res.statusCode != 200) {
      throw Exception('Could not download the workbook (${res.statusCode}).');
    }
    return res.bodyBytes;
  }

  // ─── Supabase: storage + publish + run record ─────────────
  /// Stores the workbook in the `timetables` bucket; returns its path.
  Future<String> uploadWorkbook(Uint8List bytes, String? semesterLabel) async {
    final safe = (semesterLabel ?? 'timetable').replaceAll(RegExp(r'\s+'), '_');
    final path = 'CSE_Routine_${safe}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    await _supabase.storage.from(AppConstants.bucketTimetables).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            upsert: true,
            contentType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        );
    return path;
  }

  /// Writes generated rows into `routines` so the existing viewers show
  /// them. Idempotent per cohort: clears prior rows for each generated
  /// batch first. Returns the row count.
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

  /// Records a generation/publish in `timetable_runs` for history.
  Future<void> recordRun({
    String? semesterLabel,
    String? filePath,
    required Map<String, dynamic> stats,
    required Map<String, dynamic> validation,
    required int rowCount,
    required String status, // 'generated' | 'published'
  }) async {
    await _supabase.from(AppConstants.tableTimetableRuns).insert({
      'semester_label': semesterLabel,
      'file_path': filePath,
      'stats': stats,
      'validation': validation,
      'row_count': rowCount,
      'status': status,
      'created_by': _supabase.auth.currentUser?.id,
    });
  }
}
