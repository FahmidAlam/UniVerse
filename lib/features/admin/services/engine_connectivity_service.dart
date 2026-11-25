import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:universe/core/constants/app_constants.dart';

enum EngineConnectivity { checking, connected, unavailable, unknown }

/// Checks only HTTP health; a healthy process does not guarantee a solve.
class EngineConnectivityService {
  final http.Client _client;
  final bool _ownsClient;
  final String baseUrl;
  final Duration timeout;
  EngineConnectivityService(
      {http.Client? client,
      String? baseUrl,
      this.timeout = const Duration(seconds: 5)})
      : _client = client ?? http.Client(),
        _ownsClient = client == null,
        baseUrl = baseUrl ?? AppConstants.timetableBaseUrl;

  Future<EngineConnectivity> check() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/').resolve('/'))
          .timeout(timeout);
      if (response.statusCode != 200) return EngineConnectivity.unavailable;
      final body = jsonDecode(response.body);
      return body is Map &&
              body['ok'] == true &&
              body['service'] == 'universe-timetable-engine'
          ? EngineConnectivity.connected
          : EngineConnectivity.unknown;
    } on TimeoutException {
      return EngineConnectivity.unavailable;
    } on http.ClientException {
      return EngineConnectivity.unavailable;
    } catch (_) {
      return EngineConnectivity.unknown;
    }
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}
