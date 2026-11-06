import 'package:flutter_test/flutter_test.dart';
import 'package:universe/features/auth/services/auth_callback_policy.dart';

void main() {
  test('native callbacks retain their registered schemes', () {
    final policy = AuthCallbackPolicy(isWeb: false);
    expect(policy.loginCallback, 'com.example.universe://login-callback/');
    expect(policy.recoveryCallback, 'com.example.universe://reset-callback/');
    expect(policy.invitationCallback, policy.recoveryCallback);
  });
  test('approved browser callback strips callback credentials and route', () {
    final policy = AuthCallbackPolicy(
      isWeb: true,
      browserUri: Uri.parse('http://127.0.0.1:8765/?code=secret#/admin'),
      approvedWebCallbacks: const ['http://127.0.0.1:8765/'],
    );
    expect(policy.loginCallback, 'http://127.0.0.1:8765/');
    expect(policy.recoveryCallback, policy.loginCallback);
  });
  test('unapproved and insecure browser callbacks fail closed', () {
    for (final url in ['https://evil.example/', 'http://example.com/']) {
      final policy = AuthCallbackPolicy(
        isWeb: true,
        browserUri: Uri.parse(url),
        approvedWebCallbacks: [
          url == 'https://evil.example/' ? 'https://approved.example/' : url
        ],
      );
      expect(() => policy.invitationCallback, throwsStateError);
    }
  });
  test('approval is exact including port and base path', () {
    final policy = AuthCallbackPolicy(
      isWeb: true,
      browserUri: Uri.parse('https://approved.example/app/'),
      approvedWebCallbacks: const ['https://approved.example/'],
    );
    expect(() => policy.loginCallback, throwsStateError);
  });
}
