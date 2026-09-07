import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/models/routine_model.dart';

class TimetableJobStatus {
  final String
  state; // queued | ingesting | solving | rendering | done | failed
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

  factory TimetableJobStatus.fromMap(Map<String, dynamic> m) =>
      TimetableJobStatus(
        state: (m['state'] as String?) ?? 'queued',
        progress: ((m['progress'] as num?) ?? 0).toDouble(),
        error: m['error'] as String?,
        stats: (m['stats'] as Map?)?.cast<String, dynamic>(),
        validation: (m['validation'] as Map?)?.cast<String, dynamic>(),
      );
}

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

/// Outcome of an atomic routine publish.
class RoutinePublishResult {
  /// The `routine_versions` row now marked active.
  final String versionId;
  final int rowCount;

  const RoutinePublishResult({required this.versionId, required this.rowCount});
}

class TimetableResult {
  final List<RoutineEntry> rows;
  /// Service / non-CSE classes. Not part of a CSE cohort's routine, but they
  /// occupy real teachers and rooms, so they are published alongside `rows`.
  final List<RoutineEntry> serviceRows;
  final Map<String, dynamic> stats;
  final Map<String, dynamic> validation;
  final TimetableReport report;

  /// Everything that must reach `routines`: the printed routine plus the
  /// service classes that hold teacher and room time.
  List<RoutineEntry> get allRows => [...rows, ...serviceRows];

  const TimetableResult({
    required this.rows,
    this.serviceRows = const [],
    required this.stats,
    required this.validation,
    required this.report,
  });
}

class TimetableEngineService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String get _base => AppConstants.timetableBaseUrl;

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
    req.files.add(
      http.MultipartFile.fromBytes('file', fileBytes, filename: filename),
    );
    if (config != null) req.fields['config'] = jsonEncode(config);
    req.fields['time_limit_s'] = timeLimitS.toString();

    final res = await http.Response.fromStream(await req.send());
    if (res.statusCode != 200) {
      throw Exception(
        'Engine returned ${res.statusCode}. Is the server reachable?',
      );
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
    return TimetableJobStatus.fromMap(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  Future<TimetableResult> fetchResult(String jobId) async {
    final res = await http.get(Uri.parse('$_base/api/timetable/result/$jobId'));
    if (res.statusCode != 200) {
      throw Exception(
        'Could not fetch the generated timetable (${res.statusCode}).',
      );
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    List<RoutineEntry> parse(String key) => ((body[key] as List?) ?? const [])
        .map((r) => RoutineEntry.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
    return TimetableResult(
      rows: parse('rows'),
      serviceRows: parse('service_rows'),
      stats: (body['stats'] as Map?)?.cast<String, dynamic>() ?? const {},
      validation:
          (body['validation'] as Map?)?.cast<String, dynamic>() ?? const {},
      report: TimetableReport.fromMap(
        (body['report'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
    );
  }

  Future<Uint8List> downloadWorkbook(String jobId) async {
    final res = await http.get(
      Uri.parse('$_base/api/timetable/download/$jobId'),
    );
    if (res.statusCode != 200) {
      throw Exception('Could not download the workbook (${res.statusCode}).');
    }
    return res.bodyBytes;
  }

  Future<String> uploadWorkbook(Uint8List bytes, String? semesterLabel) async {
    final safe = (semesterLabel ?? 'timetable').replaceAll(RegExp(r'\s+'), '_');
    final path =
        'CSE_Routine_${safe}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    await _supabase.storage
        .from(AppConstants.bucketTimetables)
        .uploadBinary(
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

  /// Replaces the entire active routine with [rows].
  ///
  /// This is a replacement, never a merge. The old implementation deleted only
  /// the batches present in the incoming payload, so publishing routine B after
  /// routine A left every batch that existed only in A still live and students
  /// saw the two merged. It was also a delete-loop followed by a separate
  /// insert, so a failure in between left a half-cleared routine.
  ///
  /// The work now happens inside the `publish_routine` RPC (migration 011), so
  /// clearing the old routine and inserting the new one are one transaction:
  /// either the new routine is live or the old one is untouched.
  ///
  /// Pass [rows] including service/non-CSE classes — they hold teacher and room
  /// time that Room Availability and Find Teacher must see.
  Future<RoutinePublishResult> publishToRoutines(
    List<RoutineEntry> rows, {
    String? semesterLabel,
    String source = 'engine',
    Map<String, dynamic> stats = const {},
    Map<String, dynamic> validation = const {},
    String? notes,
  }) async {
    if (rows.isEmpty) {
      throw Exception('Refusing to publish an empty routine.');
    }
    final res = await _supabase.rpc(
      'publish_routine',
      params: {
        'p_rows': rows.map((r) => r.toMap()).toList(),
        'p_semester_label': semesterLabel,
        'p_source': source,
        'p_stats': stats,
        'p_validation': validation,
        'p_notes': notes,
      },
    );
    final map = (res as Map).cast<String, dynamic>();
    return RoutinePublishResult(
      versionId: map['version_id']?.toString() ?? '',
      rowCount: (map['row_count'] as num?)?.toInt() ?? 0,
    );
  }

  /// The routine currently served to students and teachers, if any.
  Future<Map<String, dynamic>?> fetchActiveVersion() async {
    final row = await _supabase
        .from(AppConstants.tableRoutineVersions)
        .select()
        .eq('is_active', true)
        .maybeSingle();
    return row?.cast<String, dynamic>();
  }

  /// Existing course names are the best source when importing a rendered
  /// workbook, because the workbook cells only store code/teacher/room.
  Future<Map<String, String>> fetchSubjectTitleMap() async {
    final rows = await _supabase
        .from(AppConstants.tableRoutines)
        .select('subject_code, subject')
        .not('subject_code', 'is', null);
    final out = <String, String>{};
    for (final row in rows as List) {
      final map = row as Map<String, dynamic>;
      final code = (map['subject_code'] as String?)?.trim();
      final subject = (map['subject'] as String?)?.trim();
      if (code != null &&
          code.isNotEmpty &&
          subject != null &&
          subject.isNotEmpty) {
        out.putIfAbsent(code.toUpperCase(), () => subject);
      }
    }
    return out;
  }

  /// Records a generation/publish in `timetable_runs` for history.
  Future<void> recordRun({
    String? semesterLabel,
    String? filePath,
    required Map<String, dynamic> stats,
    required Map<String, dynamic> validation,
    required int rowCount,
    required String status,
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
