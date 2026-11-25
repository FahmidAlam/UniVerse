// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' show window;

/// Remove invitation credentials from this history entry before verification.
/// The caller has already captured the URI; ordinary PKCE URLs remain SDK-owned.
void clearInvitationLocation(Uri uri) {
  try {
    if (Uri.splitQueryString(uri.fragment)['type'] != 'invite') return;
    window.history.replaceState(
        null, '', uri.replace(query: '', fragment: '').toString());
  } catch (_) {
    // This utility never logs raw callback URLs or credentials.
  }
}
