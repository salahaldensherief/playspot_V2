import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/router/app_router.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'notification_action_strategy.dart';

class LoyaltyNotificationStrategy implements NotificationActionStrategy {
  const LoyaltyNotificationStrategy();

  @override
  bool canHandle(Map<String, dynamic> data) {
    final type = data['type']?.toString().toLowerCase() ?? '';
    return type.contains('loyalty') || type.contains('points') || type.contains('reward');
  }

  @override
  bool handle(Map<String, dynamic> data) {
    final context = AppRouter.navigatorKey.currentContext;
    if (context == null) return false;

    context.pushNamed(RouterKeys.redeemPoints);
    return true;
  }
}
