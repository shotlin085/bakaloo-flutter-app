import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  LocalNotificationService({
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _androidChannelId = 'bakaloo_notifications';
  static const _androidChannelName = 'Bakaloo Notifications';
  static const _androidChannelDescription = 'Order, payment and app updates';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  Future<void> initialize({
    void Function(Map<String, dynamic> payload)? onTap,
  }) async {
    if (_initialized) {
      return;
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty || onTap == null) {
          return;
        }

        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map) {
            onTap(Map<String, dynamic>.from(decoded));
          }
        } catch (_) {
          // Ignore malformed payloads.
        }
      },
    );

    const channel = AndroidNotificationChannel(
      _androidChannelId,
      _androidChannelName,
      description: _androidChannelDescription,
      importance: Importance.max,
    );
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(channel);

    _initialized = true;
  }

  Future<void> show(RemoteMessage message) async {
    final title = _stringValue(message.data['title']) ??
        message.notification?.title ??
        'Bakaloo';
    final body =
        _stringValue(message.data['body']) ?? message.notification?.body ?? '';

    if (title.isEmpty && body.isEmpty) {
      return;
    }

    final idSeed = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final notificationId = idSeed.remainder(2147483647);

    await _plugin.show(
      notificationId,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannelId,
          _androidChannelName,
          channelDescription: _androidChannelDescription,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  String? _stringValue(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }
}
