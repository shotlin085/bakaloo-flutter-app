import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bakaloo_flutter_app/core/notifications/local_notification_service.dart';
import 'package:bakaloo_flutter_app/core/notifications/notification_router.dart';
import 'package:bakaloo_flutter_app/routing/app_router.dart';

part 'fcm_service.g.dart';

final localNotificationServiceProvider = Provider<LocalNotificationService>((
  Ref ref,
) {
  return LocalNotificationService();
});

@Riverpod(keepAlive: true)
FCMService fcmService(Ref ref) {
  final service = FCMService(
    localNotifications: ref.watch(localNotificationServiceProvider),
    router: ref.watch(appRouterProvider),
  );
  ref.onDispose(service.dispose);
  return service;
}

@Riverpod(keepAlive: true)
Future<void> initializeFcm(Ref ref) async {
  await ref.watch(fcmServiceProvider).init();
}

class FCMService {
  FCMService({
    required LocalNotificationService localNotifications,
    required GoRouter router,
    FirebaseMessaging? messaging,
  })  : _localNotifications = localNotifications,
        _router = router,
        _messaging = messaging ?? FirebaseMessaging.instance;

  final LocalNotificationService _localNotifications;
  final GoRouter _router;
  final FirebaseMessaging _messaging;

  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) {
      return;
    }

    await _localNotifications.initialize(onTap: _handleNotificationTap);
    await requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    _subscriptions
      ..add(
        FirebaseMessaging.onMessage.listen((message) {
          unawaited(_localNotifications.show(message));
        }),
      )
      ..add(
        FirebaseMessaging.onMessageOpenedApp.listen((message) {
          _handleNotificationTap(message.data);
        }),
      );

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage.data);
    }

    _initialized = true;
  }

  Future<NotificationSettings> requestPermission({
    required bool alert,
    required bool badge,
    required bool sound,
  }) {
    return _messaging.requestPermission(
      alert: alert,
      badge: badge,
      sound: sound,
    );
  }

  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _initialized = false;
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    final path = NotificationRouter.getPath(data);
    if (path == null || path.isEmpty) {
      return;
    }
    _router.go(path);
  }
}
