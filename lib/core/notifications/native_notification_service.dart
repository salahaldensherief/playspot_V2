import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NativeNotificationService {
  NativeNotificationService._();
  static final NativeNotificationService instance = NativeNotificationService._();

  static const MethodChannel _channel = MethodChannel('com.playspot.app/native_notification');

  Future<void> showCustomNotification({
    required String loungeName,
    required String deviceName,
    required String timeText,
  }) async {
    try {
      await _channel.invokeMethod('showCustomNotification', {
        'loungeName': loungeName,
        'deviceName': deviceName,
        'timeText': timeText,
      });
    } catch (e) {
      debugPrint('Error invoking native custom notification: $e');
    }
  }

  Future<void> cancelCustomNotification() async {
    try {
      await _channel.invokeMethod('cancelCustomNotification');
    } catch (e) {
      debugPrint('Error canceling native custom notification: $e');
    }
  }
}
