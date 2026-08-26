import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universe/core/constants/app_constants.dart';

/// Title/body for a message, whichever half of it carries them.
///
/// FCM messages come in two shapes. A *notification* message has a
/// `notification` block and Android draws it for us when the app is in the
/// background. A *data-only* message has nothing but `data` — Android draws
/// NOTHING for it, in background or foreground, so the app must render it
/// itself or the push silently disappears. We handle both.
({String? title, String? body})? _contentOf(RemoteMessage message) {
  final n = message.notification;
  final title = n?.title ?? message.data['title'] as String?;
  final body = n?.body ?? message.data['body'] as String?;
  if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
    return null;
  }
  return (title: title, body: body);
}

/// Draws a heads-up notification through the local plugin.
Future<void> _displayLocal(
  FlutterLocalNotificationsPlugin plugin,
  RemoteMessage message,
) async {
  final content = _contentOf(message);
  if (content == null) return;

  await plugin.show(
    message.hashCode,
    content.title,
    content.body,
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

@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  debugPrint('[push] background message: ${message.messageId}');

  // A notification message was already drawn by the system — drawing it
  // again here would show the user two copies of the same alert.
  if (message.notification != null) return;

  // Data-only: nothing is on screen yet, and this runs in its own isolate,
  // so the plugin and channel have to be set up from scratch.
  final local = FlutterLocalNotificationsPlugin();
  await local.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );
  await local
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(
        const AndroidNotificationChannel(
          AppConstants.pushChannelId,
          AppConstants.pushChannelName,
          description: AppConstants.pushChannelDesc,
          importance: Importance.high,
        ),
      );

  await _displayLocal(local, message);
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
  StreamSubscription<String>? _refreshSub;

  void Function(Map<String, dynamic> data)? onNotificationTap;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

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

    // 2) Ask for notification permission (Android 13+ / iOS). Request from
    // both plugins: FCM handles remote pushes, local_notifications handles
    // foreground heads-up banners that we draw ourselves.
    await _fcm.requestPermission(alert: true, badge: true, sound: true);
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

    FirebaseMessaging.onMessage.listen(_showForeground);

    FirebaseMessaging.onMessageOpenedApp.listen((m) {
      onNotificationTap?.call(m.data);
    });

    final initial = await _fcm.getInitialMessage();
    if (initial != null) {
      onNotificationTap?.call(initial.data);
    }
  }

  /// True once a token has been stored for this session. An empty
  /// `device_tokens` table makes delivery impossible, and the failure is
  /// otherwise invisible — every error here used to be swallowed.
  bool get hasRegisteredToken => _lastToken != null;

  Future<void> registerToken(String userId) async {
    try {
      final token = await _fcm.getToken();
      if (token == null) {
        debugPrint('[push] no FCM token issued — is Google Play Services '
            'available on this device?');
      }
      if (token != null) {
        _lastToken = token;
        await _upsertToken(userId, token);
        debugPrint('[push] token registered for $userId '
            '(…${token.substring(token.length - 8)})');
      }
      await _refreshSub?.cancel();
      _refreshSub = _fcm.onTokenRefresh.listen((t) async {
        _lastToken = t;
        try {
          await _upsertToken(userId, t);
        } catch (e) {
          debugPrint('[push] refresh upsert failed: $e');
        }
      });
    } catch (e) {
      debugPrint('[push] registerToken failed: $e');
    }
  }

  Future<void> _upsertToken(String userId, String token) async {
    try {
      await _supabase.rpc('register_device_token', params: {
        'p_token': token,
        'p_platform': 'android',
      });
    } on PostgrestException catch (e) {
      if (e.code != 'PGRST202') rethrow;
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
  }

  Future<void> unregisterToken() async {
    try {
      await _refreshSub?.cancel();
      _refreshSub = null;
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

  /// Android never draws a push while the app is in the foreground, so every
  /// foreground message is rendered here — data-only ones included, which
  /// used to be dropped outright when they carried no `notification` block.
  Future<void> _showForeground(RemoteMessage message) async {
    debugPrint('[push] foreground message: ${message.messageId}');
    await _displayLocal(_local, message);
  }

  void _handleTapPayload(String payload) {
    try {
      final data = (jsonDecode(payload) as Map).cast<String, dynamic>();
      onNotificationTap?.call(data);
    } catch (_) {
    }
  }
}
