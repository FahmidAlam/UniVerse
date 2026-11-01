import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:universe/core/utils/room_identity.dart';

/// Explicit source-bound rehearsal configuration. CRC detects accidental file
/// mismatch; it is not authentication or academic approval. Never updates DB.
class GenerationProfile {
  final String label;
  final String provenance;
  final String countPolicy;
  final int _crc;
  final int _length;
  final Map<String, dynamic> _config;
  const GenerationProfile._(this.label, this.provenance, this.countPolicy,
      this._crc, this._length, this._config);
  bool get previewOnly => true;
  Map<String, dynamic> get engineConfig =>
      (jsonDecode(jsonEncode(_config)) as Map).cast<String, dynamic>();

  factory GenerationProfile.parse(String text) {
    if (utf8.encode(text).length > 1024 * 1024) {
      throw const FormatException('Run profile is too large.');
    }
    final value = jsonDecode(text);
    if (value is! Map ||
        value['format'] != 'universe-generation-profile-v1' ||
        value['label'] is! String ||
        (value['label'] as String).trim().isEmpty ||
        value['provenance'] is! String ||
        (value['provenance'] as String).trim().isEmpty ||
        value['source_crc32'] is! int ||
        value['source_bytes'] is! int ||
        value['config'] is! Map) {
      throw const FormatException('Incomplete run profile.');
    }
    final policy = value['meeting_count_policy'];
    if (policy != 'distribution' && policy != 'fixed') {
      throw const FormatException('Select an explicit meeting-count policy.');
    }
    final config = Map<String, dynamic>.from(value['config'] as Map);
    if (config['settings'] is! Map ||
        config['rooms'] is! List ||
        (config['rooms'] as List).isEmpty ||
        config['teachers'] is! List ||
        config['days'] is! List ||
        (config['days'] as List).isEmpty) {
      throw const FormatException(
          'Run profile needs rooms, faculty, days and settings.');
    }
    final settings = Map<String, dynamic>.from(config['settings'] as Map);
    final periods = settings['periods'];
    if (periods is! List || periods.isEmpty) {
      throw const FormatException('Run profile needs explicit periods.');
    }
    final ids = <int>{}, columns = <String>{};
    for (final p in periods) {
      if (p is! Map ||
          p['idx'] is! int ||
          !ids.add(p['idx'] as int) ||
          p['col'] is! String ||
          !RegExp(r'^[A-Z]+$').hasMatch(p['col']) ||
          !columns.add(p['col'] as String)) {
        throw const FormatException(
            'Period identifiers/columns must be explicit and unique.');
      }
      int clock(dynamic v) {
        if (v is! String || !RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(v)) {
          throw const FormatException('Use explicit 24-hour HH:MM clocks.');
        }
        final parts = v.split(':');
        return int.parse(parts[0]) * 60 + int.parse(parts[1]);
      }

      if (clock(p['end']) <= clock(p['start'])) {
        throw const FormatException('Periods must end after their start.');
      }
    }
    if (settings['weeks_in_term'] is! int || settings['weeks_in_term'] < 1) {
      throw const FormatException(
          'Run profile needs a positive week-count basis.');
    }
    if (policy == 'distribution') {
      settings['fixed_sessions_per_week'] = null;
    } else if (settings['fixed_sessions_per_week'] is! int ||
        settings['fixed_sessions_per_week'] < 1) {
      throw const FormatException('Fixed-count policy needs a positive count.');
    }
    final aliases =
        Map<String, String>.from(config['room_aliases'] as Map? ?? {});
    for (final key in aliases.keys) {
      RoomIdentity.key(key, aliases: aliases);
    }
    config['settings'] = settings;
    return GenerationProfile._(value['label'], value['provenance'], policy,
        value['source_crc32'], value['source_bytes'], config);
  }

  void verifySource(Uint8List bytes) {
    if (bytes.length != _length || getCrc32(bytes) != _crc) {
      throw const FormatException(
          'This run profile belongs to a different distribution file.');
    }
  }
}
