import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/router/app_router.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'notification_action_strategy.dart';

class DefaultNotificationStrategy implements NotificationActionStrategy {
  const DefaultNotificationStrategy();

  @override
  bool canHandle(Map<String, dynamic> data) => true;

  @override
  bool handle(Map<String, dynamic> data) {
    final context = AppRouter.navigatorKey.currentContext;
    if (context == null) return false;

    context.pushNamed(RouterKeys.notifications);
    return true;
  }
}
