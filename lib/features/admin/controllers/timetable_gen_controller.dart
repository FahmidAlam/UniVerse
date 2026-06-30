import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universe/core/constants/app_enums.dart';
import 'package:universe/features/admin/services/timetable_config_service.dart';
import 'package:universe/features/admin/services/timetable_engine_service.dart';
import 'package:universe/features/notifications/services/notification_service.dart';

enum GenPhase { idle, generating, polling, done, error }

class TimetableGenController extends ChangeNotifier {
  final TimetableEngineService _service = TimetableEngineService();
  final TimetableConfigService _configService = TimetableConfigService();

  static const Duration _pollInterval = Duration(seconds: 2);
  static const int _maxPolls = 120;

  Uint8List? _fileBytes;
  String? _fileName;
  String? get fileName => _fileName;
  bool get hasFile => _fileBytes != null;

  GenPhase _phase = GenPhase.idle;
  double _progress = 0;
  String? _errorMessage;
  TimetableResult? _result;
  String? _jobId;
  String? _semesterLabel;

  Uint8List? _workbookBytes;
  String? _workbookPath;
  bool _isDownloading = false;
  String? _downloadError;
  bool _isPublishing = false;
  int? _publishedCount;
  String? _publishError;

  GenPhase get phase => _phase;
  double get progress => _progress;
  String? get errorMessage => _errorMessage;
  TimetableResult? get result => _result;
  bool get isDownloading => _isDownloading;
  String? get downloadError => _downloadError;
  bool get isPublishing => _isPublishing;
  int? get publishedCount => _publishedCount;
  String? get publishError => _publishError;
  bool get isBusy => _phase == GenPhase.generating || _phase == GenPhase.polling;

  Future<void> pickFile() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'xls'],
      withData: true,
    );
    final file = res?.files.singleOrNull;
    if (file == null || file.bytes == null) return;
    _fileBytes = file.bytes;
    _fileName = file.name;
    notifyListeners();
  }

  Future<void> generate() async {
    if (_fileBytes == null) return;
    _phase = GenPhase.generating;
    _progress = 0;
    _errorMessage = null;
    _result = null;
    _jobId = null;
    _workbookBytes = null;
    _workbookPath = null;
    _publishedCount = null;
    _publishError = null;
    _downloadError = null;
    notifyListeners();

    try {
      final config = await _configService.buildEngineConfig();
      _semesterLabel =
          (config['settings'] as Map?)?['semester_label'] as String?;

      final jobId = await _service.generate(
        fileBytes: _fileBytes!,
        filename: _fileName ?? 'distribution.xlsx',
        config: config,
      );
      _jobId = jobId;
      _phase = GenPhase.polling;
      notifyListeners();

      for (var i = 0; i < _maxPolls; i++) {
        final status = await _service.pollStatus(jobId);
        _progress = status.progress;
        notifyListeners();

        if (status.isFailed) {
          throw Exception(status.error ?? 'The solver could not build a timetable.');
        }
        if (status.isDone) {
          _result = await _service.fetchResult(jobId);
          _phase = GenPhase.done;
          _progress = 1;
          notifyListeners();
          return;
        }
        await Future.delayed(_pollInterval);
      }
      throw Exception('Timed out waiting for the timetable.');
    } catch (e) {
      _phase = GenPhase.error;
      _errorMessage = _clean(e);
      notifyListeners();
    }
  }

  Future<String?> downloadAndOpen() async {
    final jobId = _jobId;
    if (jobId == null) return null;
    _isDownloading = true;
    _downloadError = null;
    notifyListeners();
    try {
      _workbookBytes ??= await _service.downloadWorkbook(jobId);
      final dir = await getTemporaryDirectory();
      final safe = (_semesterLabel ?? 'timetable').replaceAll(RegExp(r'\s+'), '_');
      final path = '${dir.path}/CSE_Routine_$safe.xlsx';
      await File(path).writeAsBytes(_workbookBytes!, flush: true);
      _workbookPath ??=
          await _service.uploadWorkbook(_workbookBytes!, _semesterLabel);
      await OpenFilex.open(path);
      _isDownloading = false;
      notifyListeners();
      return path;
    } catch (e) {
      _downloadError = _clean(e);
      _isDownloading = false;
      notifyListeners();
      return null;
    }
  }

  Future<void> publish() async {
    final res = _result;
    if (res == null || res.rows.isEmpty) return;
    _isPublishing = true;
    _publishError = null;
    notifyListeners();

    try {
      if (_workbookPath == null && _jobId != null) {
        _workbookBytes ??= await _service.downloadWorkbook(_jobId!);
        _workbookPath =
            await _service.uploadWorkbook(_workbookBytes!, _semesterLabel);
      }
      _publishedCount = await _service.publishToRoutines(res.rows);
      await _service.recordRun(
        semesterLabel: _semesterLabel,
        filePath: _workbookPath,
        stats: res.stats,
        validation: res.validation,
        rowCount: _publishedCount ?? res.rows.length,
        status: 'published',
      );

      try {
        await NotificationService().createBroadcast(
          type: NotifType.university,
          title: 'New class routine published',
          body: '${_semesterLabel ?? 'The new'} class routine is now live. '
              'Open your routine to see the updated schedule.',
        );
      } catch (_) {}
    } catch (e) {
      _publishError = _clean(e);
    }

    _isPublishing = false;
    notifyListeners();
  }

  void reset() {
    _phase = GenPhase.idle;
    _progress = 0;
    _errorMessage = null;
    _result = null;
    _jobId = null;
    _workbookBytes = null;
    _workbookPath = null;
    _publishedCount = null;
    _publishError = null;
    _downloadError = null;
    notifyListeners();
  }

  String _clean(Object e) => e.toString().replaceFirst('Exception: ', '');
}
