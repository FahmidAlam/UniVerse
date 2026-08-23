// ============================================================
// FILE: lib/features/admin/controllers/routine_upload_controller.dart
// PURPOSE: State for Admin Upload Routine. Picks a rendered UniVerse
// routine workbook, parses it into `routines` rows, previews stats, and
// publishes those rows through the same service path as generated output.
// ============================================================

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:universe/core/constants/app_enums.dart';
import 'package:universe/features/admin/services/routine_workbook_parser.dart';
import 'package:universe/features/admin/services/timetable_config_service.dart';
import 'package:universe/features/admin/services/timetable_engine_service.dart';
import 'package:universe/features/notifications/services/notification_service.dart';

enum RoutineUploadPhase { idle, parsing, ready, publishing, published, error }

class RoutineUploadController extends ChangeNotifier {
  final TimetableConfigService _configService = TimetableConfigService();
  final TimetableEngineService _engineService = TimetableEngineService();
  final RoutineWorkbookParser _parser = RoutineWorkbookParser();

  Uint8List? _fileBytes;
  String? _fileName;
  RoutineUploadPhase _phase = RoutineUploadPhase.idle;
  RoutineWorkbookParseResult? _result;
  String? _errorMessage;
  int? _publishedCount;
  String? _semesterLabel;
  String? _workbookPath;

  String? get fileName => _fileName;
  bool get hasFile => _fileBytes != null;
  RoutineUploadPhase get phase => _phase;
  RoutineWorkbookParseResult? get result => _result;
  String? get errorMessage => _errorMessage;
  int? get publishedCount => _publishedCount;
  bool get isBusy =>
      _phase == RoutineUploadPhase.parsing ||
      _phase == RoutineUploadPhase.publishing;

  Future<void> pickFile() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
      withData: true,
    );
    final file = res?.files.singleOrNull;
    if (file == null || file.bytes == null) return;
    _fileBytes = file.bytes;
    _fileName = file.name;
    _result = null;
    _errorMessage = null;
    _publishedCount = null;
    _workbookPath = null;
    _phase = RoutineUploadPhase.idle;
    notifyListeners();
  }

  Future<void> parse() async {
    final bytes = _fileBytes;
    if (bytes == null) return;

    _phase = RoutineUploadPhase.parsing;
    _errorMessage = null;
    _result = null;
    _publishedCount = null;
    notifyListeners();

    try {
      final config = await _configService.buildEngineConfig();
      final settings =
          (config['settings'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      final faculty = ((config['teachers'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => m.cast<String, dynamic>());

      _semesterLabel = settings['semester_label'] as String?;
      final teacherNames = <String, String>{
        for (final f in faculty)
          if ((f['acronym'] as String?)?.trim().isNotEmpty == true &&
              (f['full_name'] as String?)?.trim().isNotEmpty == true)
            (f['acronym'] as String).trim().toUpperCase():
                (f['full_name'] as String).trim(),
      };
      final subjectTitles = await _engineService.fetchSubjectTitleMap();

      _result = _parser.parse(
        bytes: bytes,
        periods: (settings['periods'] as List?) ?? const [],
        teacherNames: teacherNames,
        subjectTitles: subjectTitles,
      );
      _phase = RoutineUploadPhase.ready;
    } catch (e) {
      _phase = RoutineUploadPhase.error;
      _errorMessage = _clean(e);
    }
    notifyListeners();
  }

  Future<void> publish() async {
    final parsed = _result;
    final bytes = _fileBytes;
    if (parsed == null || parsed.rows.isEmpty || bytes == null) return;

    _phase = RoutineUploadPhase.publishing;
    _errorMessage = null;
    notifyListeners();

    try {
      _workbookPath ??= await _engineService.uploadWorkbook(
        bytes,
        _semesterLabel ?? _fileName,
      );
      _publishedCount = await _engineService.publishToRoutines(parsed.rows);
      await _engineService.recordRun(
        semesterLabel: _semesterLabel,
        filePath: _workbookPath,
        stats: parsed.stats,
        validation: parsed.validation,
        rowCount: _publishedCount ?? parsed.rows.length,
        status: 'published',
      );

      try {
        await NotificationService().createBroadcast(
          type: NotifType.university,
          title: 'New class routine published',
          body:
              '${_semesterLabel ?? 'The uploaded'} class routine is now live. '
              'Open your routine to see the updated schedule.',
        );
      } catch (_) {
        /* best-effort */
      }

      _phase = RoutineUploadPhase.published;
    } catch (e) {
      _phase = RoutineUploadPhase.ready;
      _errorMessage = _clean(e);
    }
    notifyListeners();
  }

  void reset() {
    _fileBytes = null;
    _fileName = null;
    _phase = RoutineUploadPhase.idle;
    _result = null;
    _errorMessage = null;
    _publishedCount = null;
    _workbookPath = null;
    notifyListeners();
  }

  String _clean(Object e) => e.toString().replaceFirst('Exception: ', '');
}
