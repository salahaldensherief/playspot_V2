import 'package:flutter/material.dart';
import 'package:playspot/art_core/utils/app_logger.dart';
import 'package:playspot/features/notifications/data/models/notification_model.dart';
import 'strategies/active_session_notification_strategy.dart';
import 'strategies/announcement_notification_strategy.dart';
import 'strategies/room_notification_strategy.dart';
import 'strategies/booking_notification_strategy.dart';
import 'strategies/default_notification_strategy.dart';
import 'strategies/loyalty_notification_strategy.dart';
import 'strategies/notification_action_strategy.dart';
import 'strategies/notification_strategy_registry.dart';
import 'strategies/offer_notification_strategy.dart';
import 'strategies/tournament_notification_strategy.dart';

typedef NotificationNavigationHandler = bool Function(Map<String, dynamic> data);

class NotificationRouter {
  NotificationRouter._();

  static NotificationNavigationHandler? _handler;
  static Map<String, dynamic>? _pendingData;

  /// Order matters: announcement payloads carry generic `title`/`body` keys,
  /// and session payloads carry a `booking_id` — both must be matched before
  /// the strategies with looser conditions below them.
  static final NotificationStrategyRegistry registry = NotificationStrategyRegistry(
    strategies: [
      const AnnouncementNotificationStrategy(),
      const ActiveSessionNotificationStrategy(),
      const BookingNotificationStrategy(),
      const RoomNotificationStrategy(),
      const OfferNotificationStrategy(),
      const LoyaltyNotificationStrategy(),
      const TournamentNotificationStrategy(),
    ],
    fallbackStrategy: const DefaultNotificationStrategy(),
  );

  static void configure(NotificationNavigationHandler handler) {
    _handler = handler;
    handlePending();
  }

  static void navigate(Map<String, dynamic> data) {
    try {
      final customHandler = _handler;

      if (customHandler != null && customHandler(data)) {
        _pendingData = null;
        return;
      }

      final handledByRegistry = registry.handleNotification(data);
      if (!handledByRegistry) {
        _pendingData = Map<String, dynamic>.from(data);
      } else {
        _pendingData = null;
      }
    } catch (e, st) {
      AppLogger.error('Error during notification routing navigation', e, st);
    }
  }

  /// Converts a [NotificationModel] into a normalized payload map and delegates routing to Strategy Registry.
  static void navigateFromModel(NotificationModel notification, [BuildContext? context]) {
    try {
      final Map<String, dynamic> payload = {
        'type': notification.type.name,
        'title': notification.title,
        'body': notification.body,
        'notification_id': notification.id,
        ...?notification.data,
      };

      final cleanType = NotificationStrategyHelper.cleanString(payload['type']);
      if (cleanType != null) {
        payload['type'] = cleanType;
      }

      navigate(payload);
    } catch (e, st) {
      AppLogger.error('Error creating payload from NotificationModel', e, st);
    }
  }

  static void handlePending() {
    final pendingData = _pendingData;
    if (pendingData == null) return;

    try {
      final customHandler = _handler;
      if (customHandler != null && customHandler(pendingData)) {
        _pendingData = null;
        return;
      }

      if (registry.handleNotification(pendingData)) {
        _pendingData = null;
      }
    } catch (e, st) {
      AppLogger.error('Error executing pending notification routing', e, st);
    }
  }

  static void clearPending() {
    _pendingData = null;
  }
}
