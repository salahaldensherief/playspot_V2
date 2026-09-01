import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../../features/profile/domain/repositories/profile_repository.dart';

import 'local_notification_service.dart';
import 'notification_router.dart';
import 'remote_notification_content.dart';

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final StreamController<RemoteNotificationContent> _notificationEvents =
      StreamController<RemoteNotificationContent>.broadcast(sync: true);
  final StreamController<String> _tokenChanges =
      StreamController<String>.broadcast(sync: true);

  bool _initialized = false;
  ProfileRepository? _profileRepository;

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  Stream<RemoteNotificationContent> get notificationEvents => _notificationEvents.stream;

  Stream<String> get tokenChanges => _tokenChanges.stream;

  Future<void> initialize({
    required LocalNotificationService localNotifications,
    ProfileRepository? profileRepository,
  }) async {
    if (_initialized) return;
    _initialized = true;
    _profileRepository = profileRepository;

    try {
      await _messaging.setAutoInitEnabled(true);
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );

      FirebaseMessaging.onMessage.listen(
        (message) => _handleForegroundMessage(message, localNotifications),
      );
      FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);
      
      _messaging.onTokenRefresh.listen((token) {
        _tokenChanges.add(token);
        _syncToken(token);
      });

      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleOpenedMessage(initialMessage);
      }

      // Initial token sync
      final token = await getToken();
      if (token != null) {
        _syncToken(token);
      }
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('FCM initialization error: $error\n$stackTrace');
      }
    }
  }

  void _syncToken(String token) {
    _profileRepository?.updateFcmToken(token);
  }

  Future<void> toggleTopicSubscription({required String topic, required bool enable}) async {
    try {
      if (enable) {
        await _messaging.subscribeToTopic(topic);
        debugPrint(' [FCM] Subscribed to topic: $topic');
      } else {
        await _messaging.unsubscribeFromTopic(topic);
        debugPrint(' [FCM] Unsubscribed from topic: $topic');
      }
    } catch (e) {
      debugPrint(' [FCM] Error toggling topic $topic: $e');
    }
  }

  Future<void> syncAllTopicsFromPreferences(Map<String, bool> prefs) async {
    for (final entry in prefs.entries) {
      await toggleTopicSubscription(topic: entry.key, enable: entry.value);
    }
  }

  Future<String?> getToken() async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        final apnsToken = await _waitForApnsToken();
        if (apnsToken == null) return null;
      }
      return await _messaging.getToken();
    } catch (_) {
      return null;
    }
  }

  Future<void> _handleForegroundMessage(
    RemoteMessage message,
    LocalNotificationService localNotifications,
  ) async {
    final content = RemoteNotificationContent.fromMessage(message);
    _notificationEvents.add(content);

    if (!content.hasVisibleContent) return;

    await localNotifications.showNotification(
      id: content.id,
      title: content.title,
      body: content.body,
      data: content.data,
    );
  }

  void _handleOpenedMessage(RemoteMessage message) {
    final content = RemoteNotificationContent.fromMessage(message);
    _notificationEvents.add(content);
    NotificationRouter.navigate(Map<String, dynamic>.from(message.data));
  }

  Future<String?> _waitForApnsToken() async {
    for (var attempt = 0; attempt < 8; attempt++) {
      final token = await _messaging.getAPNSToken();
      if (token != null && token.isNotEmpty) return token;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    return null;
  }
}
