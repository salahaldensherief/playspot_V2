import 'package:playspot/art_core/utils/app_logger.dart';
import 'notification_action_strategy.dart';

/// Registry / Context manager for Notification Action Strategies.
/// Selects and executes the appropriate strategy for any FCM notification payload.
class NotificationStrategyRegistry {
  final List<NotificationActionStrategy> _strategies;
  final NotificationActionStrategy _fallbackStrategy;

  NotificationStrategyRegistry({
    required List<NotificationActionStrategy> strategies,
    required NotificationActionStrategy fallbackStrategy,
  })  : _strategies = strategies,
        _fallbackStrategy = fallbackStrategy;

  /// Routes and handles notification payload using the matching strategy
  bool handleNotification(Map<String, dynamic> data) {
    try {
      for (final strategy in _strategies) {
        if (strategy.canHandle(data)) {
          return strategy.handle(data);
        }
      }
      return _fallbackStrategy.handle(data);
    } catch (e, st) {
      AppLogger.error('Error executing notification strategy in registry', e, st);
      return false;
    }
  }
}

