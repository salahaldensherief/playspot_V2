import 'package:flutter/material.dart';
import 'package:playspot/features/notifications/data/models/notification_model.dart';
import 'strategies/active_session_notification_strategy.dart';
import 'strategies/booking_notification_strategy.dart';
import 'strategies/default_notification_strategy.dart';
import 'strategies/loyalty_notification_strategy.dart';
import 'strategies/notification_strategy_registry.dart';
import 'strategies/offer_notification_strategy.dart';
import 'strategies/tournament_notification_strategy.dart';

typedef NotificationNavigationHandler = bool Function(Map<String, dynamic> data);

class NotificationRouter {
  NotificationRouter._();

  static NotificationNavigationHandler? _handler;
  static Map<String, dynamic>? _pendingData;

  static final NotificationStrategyRegistry registry = NotificationStrategyRegistry(
    strategies: [
      const BookingNotificationStrategy(),
      const ActiveSessionNotificationStrategy(),
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
    final customHandler = _handler;

    if (customHandler != null && customHandler(data)) {
      _pendingData = null;
      return;
    }

    final handledByRegistry = registry.handleNotification(data);
    if (!handledByRegistry) {
      _pendingData = data;
    } else {
      _pendingData = null;
    }
  }

  /// Converts a [NotificationModel] into a normalized payload map and delegates routing to Strategy Registry.
  static void navigateFromModel(NotificationModel notification, [BuildContext? context]) {
    final Map<String, dynamic> payload = {
      'type': notification.type.name,
      'title': notification.title,
      'body': notification.body,
      'id': notification.id,
      ...?notification.data,
    };

    navigate(payload);
  }

  static void handlePending() {
    final pendingData = _pendingData;
    if (pendingData == null) return;

    final customHandler = _handler;
    if (customHandler != null && customHandler(pendingData)) {
      _pendingData = null;
      return;
    }

    if (registry.handleNotification(pendingData)) {
      _pendingData = null;
    }
  }
}
