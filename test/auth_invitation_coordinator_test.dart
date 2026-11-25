import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universe/features/auth/services/invitation_callback_coordinator.dart';

Session verified(String id) => Session(
    accessToken: 'synthetic',
    tokenType: 'bearer',
    user: User(
        id: id,
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: ''));
Uri invite(String id) => Uri.parse(
    'com.example.universe://reset-callback/#type=invite&access_token=$id');
void main() {
  test('cold and warm native invitation URIs verified before bounded setup',
      () async {
    final events = <String>[];
    int epoch = 0;
    late InvitationCallbackCoordinator coordinator;
    coordinator = InvitationCallbackCoordinator(
      consume: (uri) async {
        expect(coordinator.isProcessing, isTrue);
        events.add('verify');
        return verified('$epoch');
      },
      onStart: () {
        events.add('start');
        return ++epoch;
      },
      onVerified: (session, token) async {
        expect(token, epoch);
        events.add('setup');
      },
      onFailure: (_) => fail('Unexpected callback failure'),
    );
    await coordinator.handle(invite('cold'));
    await coordinator.handle(invite('warm'));
    expect(events, ['start', 'verify', 'setup', 'start', 'verify', 'setup']);
    expect(coordinator.isProcessing, isFalse);
  });
  test('initial stream duplicate does not redeem rotating refresh token twice',
      () async {
    int reads = 0;
    final coordinator = InvitationCallbackCoordinator(
        consume: (_) async {
          reads++;
          return verified('invited');
        },
        onStart: () => 1,
        onVerified: (_, __) async {},
        onFailure: (_) => fail('Unexpected failure'));
    await Future.wait([
      coordinator.handle(invite('same')),
      coordinator.handle(invite('same'))
    ]);
    expect(reads, 1);
  });
  test('ordinary PKCE/recovery links remain owned by the SDK', () async {
    final coordinator = InvitationCallbackCoordinator(
        consume: (_) async => throw StateError('Must not intercept'),
        onStart: () => throw StateError('Must not start'),
        onVerified: (_, __) async {},
        onFailure: (_) => fail('Must not fail'));
    await coordinator.handle(
        Uri.parse('com.example.universe://login-callback/?code=pkce-code'));
    await coordinator.handle(
        Uri.parse('com.example.universe://reset-callback/#type=recovery'));
  });
  test('failed verification never calls setup and releases callback state',
      () async {
    final errors = <int>[];
    final coordinator = InvitationCallbackCoordinator(
        consume: (_) async => throw const AuthException('rejected'),
        onStart: () => 7,
        onVerified: (_, __) async => fail('Unverified setup'),
        onFailure: errors.add);
    await coordinator.handle(invite('failed'));
    expect(errors, [7]);
    expect(coordinator.isProcessing, isFalse);
  });
  test('queued invitation received before signout is dropped before redemption',
      () async {
    final pending = Completer<Session?>();
    int epoch = 0;
    int calls = 0;
    final coordinator = InvitationCallbackCoordinator(
      operationEpoch: () => epoch,
      consume: (_) async {
        calls++;
        return calls == 1 ? await pending.future : verified('queued');
      },
      onStart: () => ++epoch,
      onVerified: (_, __) async {},
      onFailure: (_) {},
    );
    final first = coordinator.handle(invite('in-flight'));
    await Future<void>.delayed(Duration.zero);
    final queued = coordinator.handle(invite('queued-before-logout'));
    epoch++; // a sign-out invalidates both pending callbacks
    pending.complete(verified('cancelled'));
    await Future.wait([first, queued]);
    expect(calls, 1,
        reason: 'Do not redeem a queued link from before sign-out');
    await coordinator.handle(invite('queued-before-logout'));
    expect(calls, 2, reason: 'An explicitly reopened callback can start anew');
  });
  test('different concurrent callbacks run serially', () async {
    final pending = Completer<Session?>();
    int calls = 0;
    int active = 0;
    final coordinator = InvitationCallbackCoordinator(
        consume: (_) async {
          active++;
          expect(active, 1);
          calls++;
          final result = calls == 1 ? await pending.future : verified('next');
          active--;
          return result;
        },
        onStart: () => calls,
        onVerified: (_, __) async {},
        onFailure: (_) => fail('Unexpected failure'));
    final first = coordinator.handle(invite('one'));
    final second = coordinator.handle(invite('two'));
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
    pending.complete(verified('first'));
    await Future.wait([first, second]);
    expect(calls, 2);
  });
}
