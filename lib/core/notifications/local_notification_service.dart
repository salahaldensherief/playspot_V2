import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_router.dart';

class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String channelId = 'high_importance_channel';

  static const String channelName = 'High Importance Notifications';

  static const String channelDescription =
      'Important application notifications';

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    channelId,
    channelName,
    description: channelDescription,
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  String? _pendingInitialPayload;
  bool _initialized = false;

  Future<void> initialize({bool readInitialNotification = true}) async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    await _createAndroidChannel();

    if (readInitialNotification) {
      await _readInitialLocalNotification();
    }

    _initialized = true;
  }

  Future<void> _createAndroidChannel() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.createNotificationChannel(_channel);
  }

  Future<void> _readInitialLocalNotification() async {
    final details = await _plugin.getNotificationAppLaunchDetails();

    if (details?.didNotificationLaunchApp ?? false) {
      _pendingInitialPayload = details?.notificationResponse?.payload;
    }
  }

  void handlePendingInitialNotification() {
    final payload = _pendingInitialPayload;

    if (payload == null || payload.isEmpty) {
      return;
    }

    _pendingInitialPayload = null;

    _handlePayload(payload);
  }

  void _onNotificationResponse(NotificationResponse response) {
    _handlePayload(response.payload);
  }

  void _handlePayload(String? payload) {
    if (payload == null || payload.isEmpty) {
      NotificationRouter.navigate({});
      return;
    }

    try {
      final decoded = jsonDecode(payload);

      if (decoded is Map) {
        final data = Map<String, dynamic>.from(decoded);

        NotificationRouter.navigate(data);
        return;
      }

      NotificationRouter.navigate({});
    } catch (_) {
      NotificationRouter.navigate({});
    }
  }

  Future<void> showNotification({
    required int id,
    required String? title,
    required String? body,
    Map<String, dynamic>? data,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: data == null ? null : jsonEncode(data),
    );
  }
}
