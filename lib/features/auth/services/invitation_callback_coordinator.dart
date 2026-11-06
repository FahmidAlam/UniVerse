import 'package:supabase_flutter/supabase_flutter.dart' show Session;

/// Serializes OS/browser invitation callbacks and rejects queued callbacks
/// after intervening authentication changes.
class InvitationCallbackCoordinator {
  InvitationCallbackCoordinator({
    required this.consume,
    required this.onStart,
    required this.onVerified,
    required this.onFailure,
    this.operationEpoch,
  });
  final Future<Session?> Function(Uri uri) consume;
  final int Function() onStart;
  final Future<void> Function(Session session, int epoch) onVerified;
  final void Function(int epoch) onFailure;
  final int Function()? operationEpoch;
  Future<void> _pending = Future<void>.value();
  int? _lastFingerprint;
  bool isProcessing = false;

  Future<void> handle(Uri uri) {
    try {
      if (Uri.splitQueryString(uri.fragment)['type'] != 'invite') {
        return Future<void>.value();
      }
    } catch (_) {
      return Future<void>.value();
    }
    // app_links can deliver the initial URI both through getInitialLink and
    // its broadcast stream. Do not redeem the same rotating refresh token twice.
    if (_lastFingerprint == uri.hashCode) return _pending;
    _lastFingerprint = uri.hashCode;
    final receivedEpoch = operationEpoch?.call();
    return _pending = _pending.then((_) async {
      // Capture when the OS delivered the link, rather than when its queued
      // verification starts. Sign-out must cancel already queued callbacks.
      if (operationEpoch != null && receivedEpoch != operationEpoch!()) {
        if (_lastFingerprint == uri.hashCode) _lastFingerprint = null;
        return;
      }
      isProcessing = true;
      final epoch = onStart();
      try {
        final session = await consume(uri);
        if (session == null) throw StateError('Invitation was not verified');
        await onVerified(session, epoch);
      } catch (_) {
        onFailure(epoch);
      } finally {
        isProcessing = false;
      }
    });
  }
}
