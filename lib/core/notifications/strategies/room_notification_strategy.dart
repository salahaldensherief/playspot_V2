import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/router/app_router.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'notification_action_strategy.dart';

class RoomNotificationStrategy implements NotificationActionStrategy {
  const RoomNotificationStrategy();

  @override
  bool canHandle(Map<String, dynamic> data) {
    return NotificationStrategyHelper.getRoomId(data) != null;
  }

  @override
  bool handle(Map<String, dynamic> data) {
    final context = AppRouter.navigatorKey.currentContext;
    if (context == null) return false;

    if (!NotificationStrategyHelper.isAuthenticated()) {
      context.goNamed(RouterKeys.signIn);
      return true;
    }

    final roomId = NotificationStrategyHelper.getRoomId(data);
    if (roomId != null) {
      context.pushNamed(
        RouterKeys.roomDetails,
        pathParameters: {'roomId': roomId},
      );
      return true;
    }
    return false;
  }
}
