import 'package:flutter/services.dart';
import '../../art_core/utils/app_logger.dart';

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
    } catch (e, st) {
      AppLogger.error('Error invoking native custom notification', e, st);
    }
  }

  Future<void> cancelCustomNotification() async {
    try {
      await _channel.invokeMethod('cancelCustomNotification');
    } catch (e, st) {
      AppLogger.error('Error canceling native custom notification', e, st);
    }
  }
}
