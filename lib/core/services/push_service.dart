// ============================================================
// FILE: lib/core/services/push_service.dart
// PURPOSE: Firebase Cloud Messaging (FCM) integration — the ONLY
// layer that talks to firebase_messaging + flutter_local_notifications
// and persists the device's FCM token to Supabase `device_tokens`.
//
// WHAT IT ADDS over the existing Supabase Realtime feed:
//   • OS-level push pop-ups that arrive even when the app is
//     backgrounded or killed (Realtime can't wake a closed app).
//   • A heads-up banner in the foreground (FCM does NOT auto-display
//     notifications while the app is open on Android — we draw it).
//
// LIFECYCLE:
//   main() → PushService.instance.init()        (once, before runApp)
//   on sign-in  → registerToken(userId)         (save token to Supabase)
//   on sign-out → unregisterToken()             (delete token)
//
// The send-push Edge Function reads `device_tokens` and delivers the
// actual push when an admin inserts a broadcast.
// ============================================================

import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universe_v1/core/constants/app_constants.dart';

/// Top-level background handler — REQUIRED to be a free function with
/// this annotation; it runs in its own isolate when a message arrives
/// while the app is backgrounded/terminated. For "notification" messages
/// Android renders the tray entry itself, so there's nothing to do here;
/// this exists so data-only messages don't get dropped.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  // Intentionally minimal. The OS shows notification-type messages using
  // the default channel declared in AndroidManifest.
  debugPrint('[push] background message: ${message.messageId}');
}

class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  SupabaseClient get _supabase => Supabase.instance.client;

  bool _initialized = false;
  String? _lastToken;

  /// Called by main.dart when a notification is tapped, so the app can
  /// route to the notifications screen. Set from main() where the router
  /// is in scope. Receives the message `data` map.
  void Function(Map<String, dynamic> data)? onNotificationTap;

  // ─── One-time setup ───────────────────────────────────────
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // 1) Local notifications: init + Android high-importance channel so
    //    foreground pop-ups (and background tray entries) are heads-up.
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _local.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (resp) {
        final payload = resp.payload;
        if (payload != null && payload.isNotEmpty) {
          _handleTapPayload(payload);
        }
      },
    );

    const channel = AndroidNotificationChannel(
      AppConstants.pushChannelId,
      AppConstants.pushChannelName,
      description: AppConstants.pushChannelDesc,
      importance: Importance.high,
    );
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // 2) Ask for notification permission (Android 13+ / iOS).
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // 3) Register the background isolate handler.
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

    // 4) Foreground messages → draw a local heads-up banner ourselves.
    FirebaseMessaging.onMessage.listen(_showForeground);

    // 5) App opened by tapping a notification (from background).
    FirebaseMessaging.onMessageOpenedApp.listen((m) {
      onNotificationTap?.call(m.data);
    });

    // 6) App launched cold by tapping a notification (from terminated).
    final initial = await _fcm.getInitialMessage();
    if (initial != null) {
      onNotificationTap?.call(initial.data);
    }
  }

  // ─── Token persistence ────────────────────────────────────
  /// Save this device's FCM token for [userId] and keep it fresh.
  Future<void> registerToken(String userId) async {
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        _lastToken = token;
        await _upsertToken(userId, token);
      }
      // Tokens rotate; persist refreshes for the same user.
      _fcm.onTokenRefresh.listen((t) {
        _lastToken = t;
        _upsertToken(userId, t);
      });
    } catch (e) {
      debugPrint('[push] registerToken failed: $e');
    }
  }

  Future<void> _upsertToken(String userId, String token) async {
    await _supabase.from(AppConstants.tableDeviceTokens).upsert(
      {
        'token': token,
        'user_id': userId,
        'platform': 'android',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'token',
    );
  }

  /// Remove this device's token on sign-out so a signed-out phone
  /// stops receiving pushes for the previous user.
  Future<void> unregisterToken() async {
    try {
      final token = _lastToken ?? await _fcm.getToken();
      if (token != null) {
        await _supabase
            .from(AppConstants.tableDeviceTokens)
            .delete()
            .eq('token', token);
      }
      await _fcm.deleteToken();
      _lastToken = null;
    } catch (e) {
      debugPrint('[push] unregisterToken failed: $e');
    }
  }

  // ─── Foreground rendering ─────────────────────────────────
  Future<void> _showForeground(RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return; // data-only: nothing to display

    await _local.show(
      n.hashCode,
      n.title,
      n.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          AppConstants.pushChannelId,
          AppConstants.pushChannelName,
          channelDescription: AppConstants.pushChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _handleTapPayload(String payload) {
    try {
      final data = (jsonDecode(payload) as Map).cast<String, dynamic>();
      onNotificationTap?.call(data);
    } catch (_) {
      /* ignore malformed payload */
    }
  }
}
