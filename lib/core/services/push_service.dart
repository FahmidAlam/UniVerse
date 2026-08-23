import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universe/core/constants/app_constants.dart';

@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
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

<<<<<<< HEAD
    // 2) Ask for notification permission (Android 13+ / iOS). Request from
    // both plugins: FCM handles remote pushes, local_notifications handles
    // foreground heads-up banners that we draw ourselves.
=======
>>>>>>> origin/main
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

  Future<void> registerToken(String userId) async {
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        _lastToken = token;
        await _upsertToken(userId, token);
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

  Future<void> _showForeground(RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return;

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
    }
  }
}
