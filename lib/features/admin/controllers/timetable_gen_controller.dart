import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universe/core/constants/app_enums.dart';
import 'package:universe/core/utils/safe_change_notifier.dart';
import 'package:universe/features/admin/services/timetable_config_service.dart';
import 'package:universe/features/admin/services/timetable_engine_service.dart';
import 'package:universe/features/admin/services/generation_profile.dart';
import 'package:universe/features/notifications/services/notification_service.dart';

enum GenPhase { idle, generating, polling, done, error }

class TimetableGenController extends SafeChangeNotifier {
  final TimetableEngineService _service;
  final TimetableConfigService _configService;
  final bool previewOnly;
  final Future<Directory> Function() _temporaryDirectory;
  final Future<void> Function(String) _openFile;
  final Duration _pollInterval;
  TimetableGenController(
      {TimetableEngineService? service,
      TimetableConfigService? configService,
      this.previewOnly = false,
      Future<Directory> Function()? temporaryDirectory,
      Future<void> Function(String)? openFile,
      Duration pollInterval = const Duration(seconds: 2)})
      : _service = service ?? TimetableEngineService(),
        _configService = configService ?? TimetableConfigService(),
        _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
        _openFile = openFile ?? _openWorkbook,
        _pollInterval = pollInterval;
  static Future<void> _openWorkbook(String path) async {
    await OpenFilex.open(path);
  }

  GenerationProfile? _runProfile;
  Map<String, dynamic>? _generationConfig;
  bool _runWasPrivate = false;
  GenerationProfile? get runProfile => _runProfile;
  String? _profileError;
  String? get profileError => _profileError;
  bool get isPrivatePreview => previewOnly || _runProfile != null;

  /// CP-SAT budget, in seconds.
  ///
  /// 60s was too little on the deployed engine. Render's free tier runs
  /// `SOLVER_WORKERS=2` on a slow shared CPU, and the solver returns FEASIBLE
  /// rather than OPTIMAL — so the soft penalties are only partly paid down and
  /// courses start doubling up on one day. Reproduced locally: at 2 workers,
  /// 60s leaves same-day sessions behind and 180s clears them. Correctness is
  /// unaffected either way (the hard constraints always hold); this buys
  /// solution quality.
  static const double _solveTimeLimitS = 180;

  /// Poll ceiling, `_maxPolls * _pollInterval`. Must comfortably exceed
  /// ingest + solve + render, so it is sized off the solve budget rather than
  /// left as a bare constant that silently becomes too small when that grows.
  static const int _maxPolls =
      (_solveTimeLimitS ~/ 2) + 150; // 180s solve -> 240 polls = 8 min

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
  bool get isBusy =>
      _phase == GenPhase.generating || _phase == GenPhase.polling;

  Future<void> pickFile() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
      withData: true,
    );
    final file = res?.files.singleOrNull;
    if (file == null || file.bytes == null) return;
    selectDistribution(file.bytes!, file.name);
  }

  void selectDistribution(Uint8List bytes, String name) {
    final selectedProfile = _runProfile;
    reset();
    _fileBytes = Uint8List.fromList(bytes);
    _fileName = name;
    _runProfile = selectedProfile;
    _profileError = null;
    try {
      selectedProfile?.verifySource(_fileBytes!);
    } catch (e) {
      _profileError = _clean(e);
    }
    notifyListeners();
  }

  void selectRunProfile(String text) {
    final profile = GenerationProfile.parse(text);
    if (_fileBytes != null) profile.verifySource(_fileBytes!);
    _runProfile = profile;
    _result = null;
    _jobId = null;
    _phase = GenPhase.idle;
    _profileError = null;
    notifyListeners();
  }

  Future<void> pickRunProfile() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['json'],
          withData: true);
      final data = picked?.files.singleOrNull?.bytes;
      if (data != null) selectRunProfile(utf8.decode(data));
    } catch (e) {
      _profileError = _clean(e);
      notifyListeners();
    }
  }

  void clearRunProfile() {
    _runProfile = null;
    _result = null;
    _jobId = null;
    _phase = GenPhase.idle;
    _profileError = null;
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
      if (_profileError != null) throw FormatException(_profileError!);
      _runProfile?.verifySource(_fileBytes!);
      _runWasPrivate = isPrivatePreview;
      final config =
          _runProfile?.engineConfig ?? await _configService.buildEngineConfig();
      _generationConfig = config;
      _semesterLabel =
          (config['settings'] as Map?)?['semester_label'] as String?;

      final jobId = await _service.generate(
        fileBytes: _fileBytes!,
        filename: _fileName ?? 'distribution.xlsx',
        config: config,
        timeLimitS: _solveTimeLimitS,
      );
      _jobId = jobId;
      _phase = GenPhase.polling;
      notifyListeners();

      var consecutivePollErrors = 0;
      for (var i = 0; i < _maxPolls; i++) {
        TimetableJobStatus? status;
        try {
          status = await _service.pollStatus(jobId);
          consecutivePollErrors = 0;
        } catch (e) {
          consecutivePollErrors++;
          // Tolerates up to 5 consecutive transient network errors (~10s) before failing.
          if (consecutivePollErrors >= 5) rethrow;
        }

        if (status != null) {
          _progress = status.progress;
          notifyListeners();

          if (status.isFailed) {
            throw Exception(
                status.error ?? 'The solver could not build a timetable.');
          }
          if (status.isDone) {
            _result = await _service.fetchResult(jobId);
            _phase = GenPhase.done;
            _progress = 1;
            notifyListeners();
            return;
          }
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
    final privateRun = _runWasPrivate;
    final label = _semesterLabel;
    _isDownloading = true;
    _downloadError = null;
    notifyListeners();
    try {
      final bytes = _workbookBytes ?? await _service.downloadWorkbook(jobId);
      if (_jobId == jobId) _workbookBytes = bytes;
      final dir = await _temporaryDirectory();
      final safe = (label ?? 'timetable').replaceAll(RegExp(r'\s+'), '_');
      final path = '${dir.path}/CSE_Routine_$safe.xlsx';
      await File(path).writeAsBytes(bytes, flush: true);
      if (!privateRun && _jobId == jobId) {
        _workbookPath ??= await _service.uploadWorkbook(bytes, label);
      }
      await _openFile(path);
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

  /// Why this routine must not go live, or null when it is academically valid.
  ///
  /// The distribution is a hard constraint: a routine that lost a required
  /// course, or gave one the wrong amount of teaching time, is a generation
  /// failure. Publishing it anyway would put a wrong schedule in front of every
  /// student, so it is blocked here rather than merely reported.
  /// Why this routine may not be published, or null if it may.
  String? get blockingValidationError {
    final invalid = blockingValidationErrorFor(_result?.validation);
    if (invalid != null) return invalid;
    if (isPrivatePreview) {
      return 'Private preview only: source profile is a rehearsal, not publication approval.';
    }
    if (_result?.allRows.any((r) => r.requiresSharedTeacherStorage) == true) {
      return 'Shared faculty must be saved in a draft; current hosted storage cannot retain every teacher.';
    }
    return null;
  }

  Future<String?> saveDraft() async {
    if (_result == null) return null;
    final snapshot = draftMap();
    final dir = await getApplicationDocumentsDirectory();
    final path =
        '${dir.path}/routine_draft_${DateTime.now().millisecondsSinceEpoch}.json';
    await File(path).writeAsString(jsonEncode(snapshot), flush: true);
    return path;
  }

  Map<String, dynamic> draftMap() => {
        'format': 'universe-routine-draft-v1',
        'preview_only': true,
        'profile_label': _runProfile?.label,
        'provenance': _runProfile?.provenance,
        'config': _generationConfig,
        'validation': _result?.validation,
        'rows': _result?.allRows.map((r) => r.toDraftMap()).toList() ?? [],
      };

  Future<void> publish() async {
    final res = _result;
    if (res == null || res.rows.isEmpty) return;

    final blocker = blockingValidationError;
    if (blocker != null) {
      _publishError = blocker;
      notifyListeners();
      return;
    }

    _isPublishing = true;
    _publishError = null;
    notifyListeners();

    try {
      if (_workbookPath == null && _jobId != null) {
        _workbookBytes ??= await _service.downloadWorkbook(_jobId!);
        _workbookPath =
            await _service.uploadWorkbook(_workbookBytes!, _semesterLabel);
      }
      // Publish the service classes too: they are not on the printed grid but
      // they hold teacher and room time that Find Teacher / Room Availability
      // must see. This replaces the whole routine in one transaction.
      final published = await _service.publishToRoutines(
        res.allRows,
        semesterLabel: _semesterLabel,
        source: 'engine',
        stats: res.stats,
        validation: res.validation,
      );
      _publishedCount = published.rowCount;
      await _service.recordRun(
        semesterLabel: _semesterLabel,
        filePath: _workbookPath,
        stats: res.stats,
        validation: res.validation,
        rowCount: published.rowCount,
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
    _generationConfig = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _service.close();
    super.dispose();
  }

  String _clean(Object e) => e.toString().replaceFirst(
      RegExp(r'^(?:FormatException|ClientException|Exception):\s*'), '');
}

/// Why a routine may not be published, or null if it may.
///
/// Pure so it can be tested without a Supabase session — the controller that
/// used to own this logic builds its services eagerly in field initialisers.
String? blockingValidationErrorFor(Map<String, dynamic>? v) {
  if (v == null || v['ok'] is! bool) {
    return 'Validation is missing or incomplete. Review the routine before publishing.';
  }
  int n(String key) => (v[key] as num?)?.toInt() ?? 0;

  // Every hard failure the engine can report. This list used to cover only
  // eight of them, so a routine the engine had already marked `ok: false` —
  // an unplaced room, a class on a teacher's day off, a lab in a lecture
  // room — was still publishable from here. The gate and the engine's own
  // verdict must agree, so `ok` is the backstop at the end.
  final problems = <String>[
    if (n('missing_courses') > 0)
      '${n('missing_courses')} course(s) from the distribution are missing',
    if (n('under_scheduled') > 0)
      '${n('under_scheduled')} course(s) have too few classes for their credit',
    if (n('over_scheduled') > 0)
      '${n('over_scheduled')} course(s) have too many classes',
    if (n('unexpected_courses') > 0)
      '${n('unexpected_courses')} course(s) are not in the distribution',
    if (n('teacher_clashes') > 0) '${n('teacher_clashes')} teacher clash(es)',
    if (n('cohort_clashes') > 0) '${n('cohort_clashes')} section clash(es)',
    if (n('room_clashes') > 0) '${n('room_clashes')} room clash(es)',
    if (n('same_day_sessions') > 0)
      '${n('same_day_sessions')} course(s) scheduled twice on the same day',
    if (n('ineligible_assignments') > 0)
      '${n('ineligible_assignments')} class(es) assigned to a teacher who is '
          'not eligible for that course',
    if (n('dayoff_violations') > 0)
      '${n('dayoff_violations')} class(es) on a day off',
    if (n('blocked_period_violations') > 0)
      '${n('blocked_period_violations')} class(es) in a blocked period',
    if (n('lab_room_violations') > 0)
      '${n('lab_room_violations')} lab(s) in a non-lab room',
    if (n('unplaced_rooms') > 0)
      '${n('unplaced_rooms')} class(es) with no room assigned',
    if (n('lab_theory_violations') > 0)
      '${n('lab_theory_violations')} lab(s) not adjacent to their theory class',
    if (n('invalid_time_slots') > 0)
      '${n('invalid_time_slots')} class(es) at an unconfigured time',
    if (n('invalid_days') > 0)
      '${n('invalid_days')} class(es) on a day that is not taught',
    if (n('teacher_assignment_mismatches') > 0)
      '${n('teacher_assignment_mismatches')} teacher assignment(s) differ from the distribution',
    if (n('unknown_rooms') > 0)
      '${n('unknown_rooms')} class(es) use an unconfigured room',
    if (n('room_capacity_violations') > 0)
      '${n('room_capacity_violations')} class(es) exceed known room capacity',
    if (n('unresolved_teachers') > 0)
      '${n('unresolved_teachers')} teacher assignment(s) need faculty verification',
  ];
  if (problems.isEmpty) {
    // The engine found something this list does not name yet. Refuse rather
    // than publish a routine its own validator rejected.
    if (v['ok'] == false) {
      return 'The engine reported this routine as invalid. Open the '
          'validation details, fix the cause, and generate again.';
    }
    return null;
  }
  return 'This routine does not match the distribution: '
      '${problems.join(', ')}. Fix the distribution or the settings and '
      'generate again.';
}
