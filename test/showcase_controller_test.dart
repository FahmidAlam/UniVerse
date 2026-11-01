import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universe/core/models/routine_model.dart';
import 'package:universe/features/admin/controllers/timetable_gen_controller.dart';
import 'package:universe/features/admin/services/timetable_config_service.dart';
import 'package:universe/features/admin/services/timetable_engine_service.dart';

class NoDatabase extends TimetableConfigService {
  @override
  Future<Map<String, dynamic>> buildEngineConfig() async =>
      throw StateError('No database read expected');
}

class Engine extends TimetableEngineService {
  Map<String, dynamic>? received;
  bool valid = true;
  final download = Completer<Uint8List>();
  int uploads = 0;
  @override
  Future<Uint8List> downloadWorkbook(String id) => download.future;
  @override
  Future<String> uploadWorkbook(Uint8List bytes, String? label) async {
    uploads++;
    return 'hosted.xlsx';
  }

  @override
  Future<String> generate(
      {required Uint8List fileBytes,
      required String filename,
      Map<String, dynamic>? config,
      double timeLimitS = 60}) async {
    received = config;
    return 'job';
  }

  @override
  Future<TimetableJobStatus> pollStatus(String id) async =>
      const TimetableJobStatus(state: 'done', progress: 1);
  @override
  Future<TimetableResult> fetchResult(String id) async =>
      TimetableResult(rows: [
        RoutineEntry.fromMap({
          'subject_code': 'CSE-1001',
          'batch': '93',
          'section': 'B+C',
          'teacher_code': 'AAA',
          'teachers': ['AAA', 'BBB'],
          'room': 'PHY LAB'
        })
      ], stats: {}, validation: {
        'ok': valid,
        'room_clashes': valid ? 0 : 1
      }, report: const TimetableReport());
}

void main() {
  test(
      'actual controller sends selected profile and keeps preview publication blocked',
      () async {
    final e = Engine();
    final c = TimetableGenController(service: e, configService: FakeConfig(), pollInterval: Duration.zero);
    final bytes = Uint8List.fromList([1, 2, 3]);
    // The UI offers profile import before the workbook picker.
    c.selectRunProfile(jsonEncode({
      'format': 'universe-generation-profile-v1',
      'label': 'Season rehearsal',
      'provenance': 'Unapproved observed requirements',
      'source_crc32': getCrc32(bytes),
      'source_bytes': 3,
      'meeting_count_policy': 'distribution',
      'config': {
        'days': ['Monday'],
        'rooms': [
          {'name': 'R-1', 'is_lab': false}
        ],
        'teachers': [],
        'settings': {
          'weeks_in_term': 14,
          'periods': [
            {'idx': 1, 'start': '11:50', 'end': '12:50', 'col': 'G'}
          ],
          'break_col': 'H',
          'fixed_sessions_per_week': 2
        }
      }
    }));
    c.selectDistribution(bytes, 'distribution.xlsx');
    await c.generate();
    expect(c.phase, GenPhase.done);
    expect((e.received!['settings'] as Map)['fixed_sessions_per_week'], isNull);
    expect((e.received!['settings'] as Map)['break_col'], 'H');
    expect(c.result!.rows.single.teacherCodes, ['AAA', 'BBB']);
    expect(c.blockingValidationError, contains('preview'));
    await c.publish();
    expect(c.publishedCount, isNull);
    e.valid = false;
    await c.generate();
    expect(c.blockingValidationError, contains('room clash'));
    c.selectDistribution(Uint8List.fromList([9]), 'different.xlsx');
    await c.generate();
    expect(c.errorMessage, startsWith('This run profile belongs'));
    c.dispose();
  });
  test(
      'private download cannot become a hosted upload when profile is cleared mid-flight',
      () async {
    final e = Engine();
    final dir = await Directory.systemTemp.createTemp('universe-preview-test-');
    final c = TimetableGenController(
        service: e,
        configService: FakeConfig(),
        temporaryDirectory: () async => dir,
        openFile: (_) async {});
    final bytes = Uint8List.fromList([1]);
    c.selectDistribution(bytes, 'a.xlsx');
    c.selectRunProfile(jsonEncode({
      'format': 'universe-generation-profile-v1',
      'label': 'Private rehearsal',
      'provenance': 'Not approved for publication',
      'source_crc32': getCrc32(bytes),
      'source_bytes': bytes.length,
      'meeting_count_policy': 'distribution',
      'config': {
        'days': ['Monday'],
        'rooms': [
          {'name': 'R-1', 'is_lab': false}
        ],
        'teachers': [],
        'settings': {
          'weeks_in_term': 14,
          'periods': [
            {'idx': 1, 'start': '09:00', 'end': '10:00', 'col': 'D'}
          ]
        }
      }
    }));
    await c.generate();
    final pending = c.downloadAndOpen();
    c.clearRunProfile();
    e.download.complete(Uint8List.fromList([1, 2]));
    final path = await pending;
    expect(path, isNotNull);
    expect(e.uploads, 0);
    await File(path!).delete();
    await dir.delete();
    c.dispose();
  });


  test('controller recovers from transient network glitches during polling', () async {
    final e = _FlakyEngine(failuresBeforeSuccess: 2);
    final c = TimetableGenController(service: e, configService: FakeConfig(), pollInterval: Duration.zero);
    c.selectDistribution(Uint8List.fromList([1]), 'a.xlsx');
    await c.generate();
    expect(c.phase, GenPhase.done);
    expect(e.pollAttempts, 3);
    c.dispose();
  });

  test('controller aborts when network failure exceeds retry threshold', () async {
    final e = _FlakyEngine(failuresBeforeSuccess: 5);
    final c = TimetableGenController(service: e, configService: FakeConfig(), pollInterval: Duration.zero);
    c.selectDistribution(Uint8List.fromList([1]), 'a.xlsx');
    await c.generate();
    expect(c.phase, GenPhase.error);
    expect(c.errorMessage, contains('Temporary connection glitch'));
    c.dispose();
  });
}

class FakeConfig extends TimetableConfigService {
  @override
  Future<Map<String, dynamic>> buildEngineConfig() async => {
        'settings': {'semester_label': 'Test Semester'}
      };
}

class _FlakyEngine extends Engine {
  int pollAttempts = 0;
  final int failuresBeforeSuccess;
  _FlakyEngine({this.failuresBeforeSuccess = 2});

  @override
  Future<TimetableJobStatus> pollStatus(String id) async {
    pollAttempts++;
    if (pollAttempts <= failuresBeforeSuccess) {
      throw Exception('Temporary connection glitch');
    }
    return const TimetableJobStatus(state: 'done', progress: 1);
  }
}
