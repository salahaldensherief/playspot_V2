import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/router/app_router.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'notification_action_strategy.dart';

class ActiveSessionNotificationStrategy implements NotificationActionStrategy {
  const ActiveSessionNotificationStrategy();

  @override
  bool canHandle(Map<String, dynamic> data) {
    final type = data['type']?.toString().toLowerCase();
    final sessionId = data['session_id'];
    return type == 'session' || type == 'active_session' || sessionId != null;
  }

  @override
  bool handle(Map<String, dynamic> data) {
    final context = AppRouter.navigatorKey.currentContext;
    if (context == null) return false;

    final sessionId = data['session_id']?.toString() ?? data['id']?.toString();
    if (sessionId != null && sessionId.isNotEmpty) {
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
