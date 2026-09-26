import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/router/app_router.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'notification_action_strategy.dart';

class ActiveSessionNotificationStrategy implements NotificationActionStrategy {
  const ActiveSessionNotificationStrategy();

  @override
  bool canHandle(Map<String, dynamic> data) {
    final type = NotificationStrategyHelper.cleanString(data['type'])?.toLowerCase();
    final sessionId = NotificationStrategyHelper.getSessionId(data);
    final reminderKey = NotificationStrategyHelper.extractFirst(
      data,
      const ['reminder_key', 'reminderKey'],
    );
    return type == 'session' ||
        type == 'active_session' ||
        type == 'active-session' ||
        reminderKey == 'extension_offer' ||
        sessionId != null;
  }

  @override
  bool handle(Map<String, dynamic> data) {
    final context = AppRouter.navigatorKey.currentContext;
    if (context == null) return false;

    if (!NotificationStrategyHelper.isAuthenticated()) {
      context.goNamed(RouterKeys.signIn);
      return true;
    }

    final reminderKey = NotificationStrategyHelper.extractFirst(
      data,
      const ['reminder_key', 'reminderKey'],
    );
    if (reminderKey == 'extension_offer') {
      final bookingId = NotificationStrategyHelper.getBookingId(data) ?? '';
      final extensionMinutes = int.tryParse(
            NotificationStrategyHelper.extractFirst(
              data,
              const ['extension_minutes', 'extensionMinutes'],
            ) ??
            '',
          ) ??
          60;
      if (bookingId.isNotEmpty) {
        context.pushNamed(
          RouterKeys.activeSession,
          extra: {'booking_id': bookingId, 'extension_minutes': extensionMinutes},
        );
      } else {
        context.pushNamed(RouterKeys.activeSession);
      }
      return true;
    }

    final sessionId = NotificationStrategyHelper.getSessionId(data);
    if (sessionId != null) {
      context.pushNamed(
        RouterKeys.activeSession,
        extra: {'booking_id': sessionId},
      );
    } else {
      context.pushNamed(RouterKeys.activeSession);
    }
    return true;
  }
}

