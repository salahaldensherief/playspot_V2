import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

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

  static const String sessionChannelId = 'session_expiry_channel';
  static const String sessionChannelName = 'Session Expiry Alerts';
  static const String sessionChannelDescription =
      'Alerts when your active gaming session is about to expire';

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    channelId,
    channelName,
    description: channelDescription,
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static const AndroidNotificationChannel _sessionChannel = AndroidNotificationChannel(
    sessionChannelId,
    sessionChannelName,
    description: sessionChannelDescription,
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  String? _pendingInitialPayload;
  bool _initialized = false;

  Future<void> initialize({bool readInitialNotification = true}) async {
    if (_initialized) return;

    tz.initializeTimeZones();

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

    await _createAndroidChannels();

    if (readInitialNotification) {
      await _readInitialLocalNotification();
    }

    _initialized = true;
  }

  Future<void> _createAndroidChannels() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.createNotificationChannel(_channel);
    await androidPlugin?.createNotificationChannel(_sessionChannel);
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

  Future<void> scheduleSessionExpiryWarning({
    required int id,
    required String loungeName,
    required DateTime expiryTime,
  }) async {
    try {
      final warningTime = expiryTime.subtract(const Duration(minutes: 5));
      if (warningTime.isBefore(DateTime.now())) {
        return; // Already past warning window
      }

      const androidDetails = AndroidNotificationDetails(
        sessionChannelId,
        sessionChannelName,
        channelDescription: sessionChannelDescription,
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

      await _plugin.zonedSchedule(
        id: id,
        title: 'Session Expiring Soon!',
        body: 'Your gaming session at $loungeName will expire in 5 minutes.',
        scheduledDate: tz.TZDateTime.from(warningTime, tz.local),
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: jsonEncode({'type': 'active_session'}),
      );
    } catch (e) {
      debugPrint('Error scheduling session expiry notification: $e');
    }
  }
}
