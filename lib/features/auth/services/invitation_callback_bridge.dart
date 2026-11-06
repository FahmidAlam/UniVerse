import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/features/auth/services/auth_callback_policy.dart';

/// Admin invitations carry implicit tokens, even when ordinary sign-in uses
/// PKCE. Verify those tokens separately without changing the application's
/// PKCE flow. The caller may enable bounded password setup only on success.
/// This class never treats a URL's `type=invite` as authenticated authority.
class InvitationCallbackBridge {
  InvitationCallbackBridge({
    required GoTrueClient auth,
    required GoTrueClient Function() verifierFactory,
    required AuthCallbackPolicy callbacks,
    http.Client Function()? refreshClientFactory,
    int Function()? operationEpoch,
    this.timeout = const Duration(seconds: 15),
  })  : _auth = auth,
        _verifierFactory = verifierFactory,
        _callbacks = callbacks,
        _refreshClientFactory = refreshClientFactory ?? http.Client.new,
        _operationEpoch = operationEpoch ?? (() => 0);

  factory InvitationCallbackBridge.current({int Function()? operationEpoch}) =>
      InvitationCallbackBridge(
        auth: Supabase.instance.client.auth,
        callbacks: AuthCallbackPolicy.current,
        operationEpoch: operationEpoch,
        verifierFactory: () => GoTrueClient(
          url: '${AppConstants.supabaseUrl}/auth/v1',
          headers: {'apikey': AppConstants.supabaseAnonKey},
          autoRefreshToken: false,
          flowType: AuthFlowType.implicit,
        ),
      );

  final GoTrueClient _auth;
  final GoTrueClient Function() _verifierFactory;
  final AuthCallbackPolicy _callbacks;
  final http.Client Function() _refreshClientFactory;
  final int Function() _operationEpoch;
  final Duration timeout;

  /// Returns null for non-invitation links, leaving normal PKCE handling alone.
  /// Native callers must supply an actual OS-delivered URI; this service does
  /// not intercept private plugin channels or invent a native deep-link hook.
  Future<Session?> consume(Uri uri) async {
    final epoch = _operationEpoch();
    final Map<String, String> parameters;
    try {
      parameters = Uri.splitQueryString(uri.fragment);
    } on FormatException {
      throw const AuthException('Invalid invitation callback.');
    }
    if (parameters['type'] != 'invite') return null;
    final String approved;
    try {
      approved = _callbacks.invitationCallback;
    } catch (_) {
      throw const AuthException('Invitation callback is not approved.');
    }
    final destination = uri
        .replace(query: '', fragment: '')
        .toString()
        .replaceFirst(RegExp(r'[?#]+$'), '');
    if (destination != approved ||
        uri.hasQuery ||
        parameters['access_token']?.isNotEmpty != true ||
        parameters['refresh_token']?.isNotEmpty != true ||
        parameters['token_type'] != 'bearer' ||
        (int.tryParse(parameters['expires_in'] ?? '') ?? 0) <= 0) {
      throw const AuthException('Invalid invitation callback.');
    }

    final verifier = _verifierFactory();
    try {
      // Public SDK implicit parsing calls /user to verify the access token.
      // Do not persist or broadcast the temporary verifier session.
      final verified = await verifier
          .getSessionFromUrl(uri, storeSession: false)
          .timeout(timeout);
      final user = verified.session.user;
      if (verified.redirectType != 'invite' ||
          user.invitedAt == null ||
          user.emailConfirmedAt == null) {
        throw const AuthException('This session is not a verified invitation.');
      }
      // Refresh without mutating or broadcasting any SDK session. A timed-out
      // SDK setSession future can otherwise sign in later despite the timeout.
      final client = _refreshClientFactory();
      final http.Response response;
      try {
        response = await client
            .post(
              Uri.parse(
                  '${AppConstants.supabaseUrl}/auth/v1/token?grant_type=refresh_token'),
              headers: {
                'apikey': AppConstants.supabaseAnonKey,
                'Content-Type': 'application/json'
              },
              body:
                  jsonEncode({'refresh_token': verified.session.refreshToken}),
            )
            .timeout(timeout);
      } finally {
        client.close();
      }
      if (response.statusCode != 200) {
        throw const AuthException('Invitation session could not be verified.');
      }
      final Session? session;
      try {
        session =
            Session.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      } catch (_) {
        throw const AuthException('Invalid invitation session response.');
      }
      final minimumExpiry = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 60;
      if (session == null ||
          session.user.id != user.id ||
          (session.expiresAt ?? 0) <= minimumExpiry ||
          session.refreshToken?.isNotEmpty != true) {
        throw const AuthException('Invitation session identity did not match.');
      }
      if (_operationEpoch() != epoch) {
        throw const AuthException('Invitation completion was cancelled.');
      }
      // The remotely verified token has over a minute remaining. Installed SDK
      // recoverSession adopts it synchronously without a refresh/network await,
      // so sign-out cannot race a late network completion into a new session.
      final established =
          await _auth.recoverSession(jsonEncode(session.toJson()));
      return established.session;
    } finally {
      verifier.dispose();
    }
  }
}
