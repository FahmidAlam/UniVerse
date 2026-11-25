import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:universe/features/admin/services/timetable_engine_service.dart';

void main() {
  test('TimetableEngineService attaches Bearer token to all /api/timetable/* calls', () async {
    final recorded = <({String method, String path, Map<String, String> headers})>[];

    final mockClient = MockClient((request) async {
      recorded.add((
        method: request.method,
        path: request.url.path,
        headers: Map<String, String>.from(request.headers),
      ));

      if (request.url.path == '/api/timetable/generate') {
        return http.Response(jsonEncode({'job_id': 'job-123'}), 200);
      }
      if (request.url.path == '/api/timetable/status/job-123') {
        return http.Response(
          jsonEncode({'job_id': 'job-123', 'state': 'done', 'progress': 1.0}),
          200,
        );
      }
      if (request.url.path == '/api/timetable/result/job-123') {
        return http.Response(
          jsonEncode({
            'job_id': 'job-123',
            'rows': [],
            'service_rows': [],
            'stats': {'status': 'OPTIMAL'},
            'validation': {'ok': true},
            'report': {},
          }),
          200,
        );
      }
      if (request.url.path == '/api/timetable/download/job-123') {
        return http.Response.bytes(Uint8List.fromList([0x50, 0x4b, 0x03, 0x04]), 200);
      }
      return http.Response('Not found', 404);
    });

    final service = TimetableEngineService(
      client: mockClient,
      baseUrl: 'https://engine.example.test',
      accessTokenProvider: () => 'test-jwt-token-abc',
    );

    final jobId = await service.generate(
      fileBytes: Uint8List.fromList([1, 2, 3]),
      filename: 'dist.xlsx',
    );
    expect(jobId, 'job-123');

    final status = await service.pollStatus(jobId);
    expect(status.isDone, isTrue);

    final result = await service.fetchResult(jobId);
    expect(result.rows, isEmpty);

    final bytes = await service.downloadWorkbook(jobId);
    expect(bytes, isNotEmpty);

    expect(recorded, hasLength(4));
    for (final call in recorded) {
      expect(
        call.headers['Authorization'],
        'Bearer test-jwt-token-abc',
        reason: 'Expected Bearer header on ${call.method} ${call.path}',
      );
    }

    service.close();
  });

  test('TimetableEngineService omits Authorization header when no session token exists', () async {
    final recordedHeaders = <Map<String, String>>[];
    final mockClient = MockClient((request) async {
      recordedHeaders.add(Map<String, String>.from(request.headers));
      return http.Response(
        jsonEncode({'job_id': 'job-1', 'state': 'queued', 'progress': 0.0}),
        200,
      );
    });

    final service = TimetableEngineService(
      client: mockClient,
      baseUrl: 'https://engine.example.test',
      accessTokenProvider: () => null,
    );

    await service.pollStatus('job-1');
    expect(recordedHeaders.single.containsKey('Authorization'), isFalse);
    service.close();
  });
}
