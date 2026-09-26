import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:playspot/art_core/utils/app_logger.dart';
import 'package:playspot/features/profile/domain/repositories/profile_repository.dart';

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

  StreamSubscription<RemoteMessage>? _onMessageSubscription;
  StreamSubscription<RemoteMessage>? _onMessageOpenedAppSubscription;
  StreamSubscription<String>? _onTokenRefreshSubscription;

  bool _initialized = false;
  ProfileRepository? _profileRepository;

  FirebaseMessaging? get _messaging {
    try {
      if (Firebase.apps.isEmpty) return null;
      return FirebaseMessaging.instance;
    } catch (_) {
      return null;
    }
  }

  Stream<RemoteNotificationContent> get notificationEvents =>
      _notificationEvents.stream;

  Stream<String> get tokenChanges => _tokenChanges.stream;

  Future<void> initialize({
    required LocalNotificationService localNotifications,
    ProfileRepository? profileRepository,
  }) async {
    if (_initialized) return;
    _initialized = true;
    _profileRepository = profileRepository;

    try {
      final messaging = _messaging;
      if (messaging == null) {
        AppLogger.debug('[FCM] Firebase not initialized, skipping FCM setup');
        return;
      }

      await messaging.setAutoInitEnabled(true);
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      _cancelSubscriptions();

      _onMessageSubscription = FirebaseMessaging.onMessage.listen(
        (message) => _handleForegroundMessage(message, localNotifications),
      );
      _onMessageOpenedAppSubscription = FirebaseMessaging.onMessageOpenedApp
          .listen(_handleOpenedMessage);

      _onTokenRefreshSubscription = messaging.onTokenRefresh.listen((token) {
        _tokenChanges.add(token);
        _syncToken(token);
      });

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleOpenedMessage(initialMessage);
      }

      // Initial token sync
      final token = await getToken();
      if (token != null) {
        _syncToken(token);
      }

      // Subscribe to default broadcast topics
      await toggleTopicSubscription(topic: 'all_users', enable: true);
      await toggleTopicSubscription(topic: 'announcements', enable: true);
    } catch (error, stackTrace) {
      AppLogger.error('FCM initialization error', error, stackTrace);
    }
  }

  void _cancelSubscriptions() {
    _onMessageSubscription?.cancel();
    _onMessageSubscription = null;
    _onMessageOpenedAppSubscription?.cancel();
    _onMessageOpenedAppSubscription = null;
    _onTokenRefreshSubscription?.cancel();
    _onTokenRefreshSubscription = null;
  }

  void dispose() {
    _cancelSubscriptions();
    _initialized = false;
  }

  void _syncToken(String token) {
    try {
      _profileRepository?.updateFcmToken(token);
    } catch (e, st) {
      AppLogger.error('Error syncing FCM token with repository', e, st);
    }
  }

  Future<void> deleteToken() async {
    try {
      final messaging = _messaging;
      if (messaging == null) return;
      await messaging.deleteToken();
      AppLogger.debug('[FCM] Token deleted successfully');
    } catch (e, st) {
      AppLogger.error('Error deleting FCM token', e, st);
    }
  }

  Future<void> toggleTopicSubscription({
    required String topic,
    required bool enable,
  }) async {
    try {
      final messaging = _messaging;
      if (messaging == null) {
        AppLogger.debug(
          '[FCM] Firebase not initialized, skipping topic subscription: $topic',
        );
        return;
      }

      // 1. التحقق من جاهزية APNs Token لنظام iOS لتفادي الخطأ
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        final apnsToken = await messaging.getAPNSToken();
        if (apnsToken == null) {
          AppLogger.warning(
            '[FCM] APNS token is not ready yet, skipping topic: $topic',
          );
          return;
        }
      }

      // 2. تنفيذ الاشتراك أو الإلغاء بأمان
      if (enable) {
        await messaging.subscribeToTopic(topic);
        AppLogger.debug('[FCM] Subscribed to topic: $topic');
      } else {
        await messaging.unsubscribeFromTopic(topic);
        AppLogger.debug('[FCM] Unsubscribed from topic: $topic');
      }
    } catch (e, st) {
      AppLogger.error('⛔ [FCM] Error toggling topic $topic', e, st);
    }
  }

  Future<void> syncAllTopicsFromPreferences(Map<String, bool> prefs) async {
    for (final entry in prefs.entries) {
      await toggleTopicSubscription(topic: entry.key, enable: entry.value);
    }
  }

  Future<String?> getToken() async {
    try {
      final messaging = _messaging;
      if (messaging == null) return null;

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        final apnsToken = await _waitForApnsToken();
        if (apnsToken == null) return null;
      }
      final token = await messaging.getToken();
      if (token != null) {
        AppLogger.debug('FCM token fetched successfully');
      }
      return token;
    } catch (e, st) {
      AppLogger.error('FCM Token Error', e, st);
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

    // iOS auto-presents notification payloads in the foreground via
    // setForegroundNotificationPresentationOptions; Android does not, so a
    // local notification is required there or the message is invisible.
    final shouldShowLocal = !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? true
        : message.notification == null;
    if (shouldShowLocal) {
      await localNotifications.showNotification(
        id: content.id,
        title: content.title,
        body: content.body,
        data: content.data,
      );
    }
  }

  void _handleOpenedMessage(RemoteMessage message) {
    final content = RemoteNotificationContent.fromMessage(message);
    _notificationEvents.add(content);
    NotificationRouter.navigate(Map<String, dynamic>.from(message.data));
  }

  Future<String?> _waitForApnsToken() async {
    final messaging = _messaging;
    if (messaging == null) return null;

    for (var attempt = 0; attempt < 8; attempt++) {
      final token = await messaging.getAPNSToken();
      if (token != null && token.isNotEmpty) return token;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    return null;
  }
}
