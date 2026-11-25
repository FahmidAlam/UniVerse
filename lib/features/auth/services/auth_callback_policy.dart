import 'package:flutter/foundation.dart' show kIsWeb;

/// Exact callback URLs must also be approved in the target Auth server.
/// No server Site URL fallback and no wildcard preview origins.
class AuthCallbackPolicy {
  AuthCallbackPolicy({
    required this.isWeb,
    this.browserUri,
    this.approvedWebCallbacks = const [],
  });

  final bool isWeb;
  final Uri? browserUri;
  final List<String> approvedWebCallbacks;

  static AuthCallbackPolicy get current => AuthCallbackPolicy(
        isWeb: kIsWeb,
        browserUri: kIsWeb ? Uri.base : null,
        approvedWebCallbacks:
            const String.fromEnvironment('AUTH_WEB_CALLBACK_URLS')
                .split(',')
                .where((value) => value.isNotEmpty)
                .toList(),
      );

  String get loginCallback =>
      isWeb ? _browserCallback() : 'com.example.universe://login-callback/';
  String get recoveryCallback =>
      isWeb ? _browserCallback() : 'com.example.universe://reset-callback/';
  String get invitationCallback => recoveryCallback;

  String _browserCallback() {
    final base = browserUri;
    if (base == null) throw StateError('Browser callback is unavailable.');
    final candidate = base
        .replace(query: '', fragment: '')
        .toString()
        .replaceFirst(RegExp(r'[?#]+$'), '');
    final uri = Uri.parse(candidate);
    final loopback = const ['localhost', '127.0.0.1', '::1'].contains(uri.host);
    final secure = uri.scheme == 'https' || (uri.scheme == 'http' && loopback);
    if (!secure ||
        uri.userInfo.isNotEmpty ||
        uri.host.isEmpty ||
        !approvedWebCallbacks.contains(candidate)) {
      throw StateError('This browser callback is not approved. Configure '
          'AUTH_WEB_CALLBACK_URLS and the Auth server callback allowlist.');
    }
    return candidate;
  }
}
