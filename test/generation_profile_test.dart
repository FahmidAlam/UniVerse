import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universe/features/admin/services/generation_profile.dart';

void main() {
  final bytes = Uint8List.fromList([1, 2, 3]);
  Map<String, dynamic> profile() => {
        'format': 'universe-generation-profile-v1',
        'label': 'Reviewed source rehearsal',
        'provenance': 'Observed only; faculty availability unverified',
        'source_crc32': getCrc32(bytes),
        'source_bytes': bytes.length,
        'meeting_count_policy': 'distribution',
        'config': {
          'days': ['Monday', 'Tuesday'],
          'rooms': [
            {'name': 'RAB-106', 'is_lab': true}
          ],
          'teachers': [],
          'room_aliases': {'PHY LAB': 'RAB-106'},
          'unavailable_rooms': ['RAB-104'],
          'settings': {
            'periods': [
              {'idx': 1, 'start': '11:50', 'end': '12:50', 'col': 'G'}
            ],
            'weeks_in_term': 14,
            'fixed_sessions_per_week': 2,
            'break_col': 'H',
            'allow_same_day_sessions': true,
            'same_day_exempt_courses': ['CSE-1001']
          }
        }
      };
  test(
      'profile preserves scoped policies and uses source counts instead of fixed two',
      () {
    final p = GenerationProfile.parse(jsonEncode(profile()));
    p.verifySource(bytes);
    final c = p.engineConfig;
    expect((c['settings'] as Map)['fixed_sessions_per_week'], isNull);
    expect((c['settings'] as Map)['break_col'], 'H');
    expect((c['settings'] as Map)['allow_same_day_sessions'], isTrue);
    expect(c['room_aliases'], {'PHY LAB': 'RAB-106'});
    expect(c['unavailable_rooms'], ['RAB-104']);
    expect(p.previewOnly, isTrue);
  });
  test(
      'wrong workbook is refused rather than silently reusing a seasonal profile',
      () {
    final p = GenerationProfile.parse(jsonEncode(profile()));
    expect(() => p.verifySource(Uint8List.fromList([3, 2, 1])),
        throwsFormatException);
  });
  test('invalid count policy or ambiguous clocks are rejected', () {
    final a = profile()..['meeting_count_policy'] = 'guess';
    expect(() => GenerationProfile.parse(jsonEncode(a)), throwsFormatException);
    final b = profile();
    ((b['config'] as Map)['settings'] as Map)['periods'] = [
      {'idx': 1, 'start': '1:00', 'end': '02:00', 'col': 'D'}
    ];
    expect(() => GenerationProfile.parse(jsonEncode(b)), throwsFormatException);
  });
}
