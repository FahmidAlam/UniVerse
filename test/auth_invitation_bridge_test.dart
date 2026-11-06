import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universe/features/auth/services/auth_callback_policy.dart';
import 'package:universe/features/auth/services/invitation_callback_bridge.dart';

const callback = 'http://127.0.0.1:8765/';
final inviteUri = Uri.parse(
    '$callback#type=invite&access_token=synthetic-access&refresh_token=synthetic-refresh&expires_in=3600&token_type=bearer');

User invitedUser(String id, {bool invited = true}) => User(
      id: id,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-11-05T00:00:00Z',
      email: '$id@example.invalid',
      emailConfirmedAt: '2026-11-05T00:00:00Z',
      invitedAt: invited ? '2026-11-05T00:00:00Z' : null,
    );

Session session(User user) => Session(
    accessToken: 'verified-access',
    refreshToken: 'verified-refresh',
    tokenType: 'bearer',
    user: user);

Session refreshedSession(User user, {int seconds = 3600}) {
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  String encode(Map<String, dynamic> value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final token = '${encode({'alg': 'HS256'})}.${encode({
        'sub': user.id,
        'iat': now,
        'exp': now + seconds
      })}.synthetic';
  return Session(
      accessToken: token,
      refreshToken: 'rotated-synthetic',
      tokenType: 'bearer',
      user: user);
}

class TestAuth extends GoTrueClient {
  TestAuth()
      : super(url: 'http://127.0.0.1:1/auth/v1', autoRefreshToken: false);
  User verifiedUser = invitedUser('invited');
  User refreshedUser = invitedUser('invited');
  bool failVerification = false;
  bool failRefresh = false;
  bool? stored;
  int adoptions = 0;
  int verifications = 0;
  int signOuts = 0;
  @override
  Future<AuthSessionUrlResponse> getSessionFromUrl(Uri url,
      {bool storeSession = true}) async {
    verifications++;
    stored = storeSession;
    if (failVerification) throw const AuthException('Invalid invitation token');
    return AuthSessionUrlResponse(
        session: session(verifiedUser), redirectType: 'invite');
  }

  @override
  Future<AuthResponse> recoverSession(String json) async {
    adoptions++;
    return AuthResponse(session: Session.fromJson(jsonDecode(json)));
  }

  @override
  Future<void> signOut({SignOutScope scope = SignOutScope.local}) async {
    signOuts++;
  }
}

void main() {
  late TestAuth auth;
  late TestAuth verifier;
  late InvitationCallbackBridge bridge;
  setUp(() {
    auth = TestAuth();
    verifier = TestAuth();
    bridge = InvitationCallbackBridge(
        auth: auth,
        verifierFactory: () => verifier,
        refreshClientFactory: () => MockClient((request) async => http.Response(
            jsonEncode(refreshedSession(auth.refreshedUser).toJson()),
            auth.failRefresh ? 401 : 200)),
        callbacks: AuthCallbackPolicy(
            isWeb: true,
            browserUri: Uri.parse(callback),
            approvedWebCallbacks: const [callback]));
  });
  tearDown(() {
    auth.dispose();
    verifier.dispose();
  });
  test('ordinary routes and password recovery are left to PKCE', () async {
    expect(await bridge.consume(Uri.parse(callback)), isNull);
    expect(await bridge.consume(Uri.parse('$callback?code=synthetic')), isNull);
    expect(await bridge.consume(Uri.parse('$callback#type=recovery')), isNull);
    expect(verifier.verifications, 0);
    expect(auth.adoptions, 0);
  });
  test('verified invitation establishes matching server-refreshed identity',
      () async {
    final result = await bridge.consume(inviteUri);
    expect(result?.user.id, 'invited');
    expect(verifier.stored, isFalse);
    expect(auth.adoptions, 1);
  });
  test('invitation URL alone cannot authorize password setup', () async {
    await expectLater(bridge.consume(Uri.parse('$callback#type=invite')),
        throwsA(isA<AuthException>()));
    expect(verifier.verifications, 0);
    expect(auth.adoptions, 0);
  });
  test('unapproved callback rejected before token verification', () async {
    await expectLater(bridge.consume(inviteUri.replace(host: 'evil.invalid')),
        throwsA(isA<AuthException>()));
    expect(verifier.verifications, 0);
    expect(auth.adoptions, 0);
  });
  test('invalid access token cannot establish application session', () async {
    verifier.failVerification = true;
    await expectLater(bridge.consume(inviteUri), throwsA(isA<AuthException>()));
    expect(auth.adoptions, 0);
  });
  test('non-invited identity cannot authorize invitation completion', () async {
    verifier.verifiedUser = invitedUser('ordinary', invited: false);
    await expectLater(bridge.consume(inviteUri), throwsA(isA<AuthException>()));
    expect(auth.adoptions, 0);
  });
  test('refresh failure does not return an authorized session', () async {
    auth.failRefresh = true;
    await expectLater(bridge.consume(inviteUri), throwsA(isA<AuthException>()));
  });
  test('mismatched verified and refreshed identities are rejected', () async {
    auth.refreshedUser = invitedUser('other');
    await expectLater(bridge.consume(inviteUri), throwsA(isA<AuthException>()));
    expect(auth.adoptions, 0, reason: 'Never adopt a mismatched identity');
  });
  test('late refresh after timeout never mutates application authentication',
      () async {
    final response = Completer<http.Response>();
    final instance = InvitationCallbackBridge(
        auth: auth,
        verifierFactory: () => verifier,
        callbacks: AuthCallbackPolicy(
            isWeb: true,
            browserUri: Uri.parse(callback),
            approvedWebCallbacks: const [callback]),
        refreshClientFactory: () => MockClient((_) => response.future),
        timeout: const Duration(milliseconds: 10));
    await expectLater(
        instance.consume(inviteUri), throwsA(isA<TimeoutException>()));
    response.complete(http.Response(
        jsonEncode(refreshedSession(invitedUser('invited')).toJson()), 200));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(auth.adoptions, 0);
  });
  test('sign-out epoch change cancels pending invitation before adoption',
      () async {
    var epoch = 0;
    final response = Completer<http.Response>();
    final requested = Completer<void>();
    final instance = InvitationCallbackBridge(
        auth: auth,
        verifierFactory: () => verifier,
        callbacks: AuthCallbackPolicy(
            isWeb: true,
            browserUri: Uri.parse(callback),
            approvedWebCallbacks: const [callback]),
        operationEpoch: () => epoch,
        refreshClientFactory: () => MockClient((_) {
              requested.complete();
              return response.future;
            }));
    final result = instance.consume(inviteUri);
    final assertion = expectLater(result, throwsA(isA<AuthException>()));
    await requested.future;
    epoch++;
    response.complete(http.Response(
        jsonEncode(refreshedSession(invitedUser('invited')).toJson()), 200));
    await assertion;
    expect(auth.adoptions, 0);
  });
  test('near-expired refresh cannot trigger implicit SDK network adoption',
      () async {
    final instance = InvitationCallbackBridge(
        auth: auth,
        verifierFactory: () => verifier,
        callbacks: AuthCallbackPolicy(
            isWeb: true,
            browserUri: Uri.parse(callback),
            approvedWebCallbacks: const [callback]),
        refreshClientFactory: () => MockClient((_) async => http.Response(
            jsonEncode(
                refreshedSession(invitedUser('invited'), seconds: 30).toJson()),
            200)));
    await expectLater(
        instance.consume(inviteUri), throwsA(isA<AuthException>()));
    expect(auth.adoptions, 0);
  });
  test('actual SDK verifies /user then refreshes through /token', () async {
    final requests = <http.Request>[];
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    String encode(Map<String, dynamic> value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    final token = '${encode({'alg': 'HS256'})}.${encode({
          'sub': 'invited',
          'iat': now,
          'exp': now + 3600
        })}.synthetic';
    final user = invitedUser('invited');
    final transport = MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/user')) {
        expect(request.headers['authorization'], 'Bearer synthetic-access');
        return http.Response(jsonEncode(user.toJson()), 200);
      }
      expect(request.url.path, '/auth/v1/token');
      expect(request.url.queryParameters['grant_type'], 'refresh_token');
      expect(jsonDecode(request.body)['refresh_token'], 'synthetic-refresh');
      return http.Response(
          jsonEncode({
            'access_token': token,
            'refresh_token': 'rotated-synthetic',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': user.toJson(),
          }),
          200);
    });
    final actualAuth = GoTrueClient(
        url: 'http://127.0.0.1:1/auth/v1',
        httpClient: transport,
        autoRefreshToken: false);
    final actualBridge = InvitationCallbackBridge(
        auth: actualAuth,
        callbacks: AuthCallbackPolicy(
            isWeb: true,
            browserUri: Uri.parse(callback),
            approvedWebCallbacks: const [callback]),
        refreshClientFactory: () => transport,
        verifierFactory: () => GoTrueClient(
            url: 'http://127.0.0.1:1/auth/v1',
            httpClient: transport,
            autoRefreshToken: false,
            flowType: AuthFlowType.implicit));
    try {
      final result = await actualBridge.consume(inviteUri);
      expect(result?.user.id, 'invited');
      expect(actualAuth.currentUser?.id, 'invited');
      expect(requests.map((request) => request.url.path),
          ['/auth/v1/user', '/auth/v1/token']);
    } finally {
      actualAuth.dispose();
      transport.close();
    }
  });
}
