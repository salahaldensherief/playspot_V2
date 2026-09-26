import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/router/app_router.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'notification_action_strategy.dart';

class BookingNotificationStrategy implements NotificationActionStrategy {
  const BookingNotificationStrategy();

  @override
  bool canHandle(Map<String, dynamic> data) {
    final type = NotificationStrategyHelper.cleanString(data['type'])?.toLowerCase();
    final bookingId = NotificationStrategyHelper.getBookingId(data);
    return (type != null && type.contains('booking')) || bookingId != null;
  }

  @override
  bool handle(Map<String, dynamic> data) {
    final context = AppRouter.navigatorKey.currentContext;
    if (context == null) return false;

    if (!NotificationStrategyHelper.isAuthenticated()) {
      context.goNamed(RouterKeys.signIn);
      return true;
    }

    final bookingId = NotificationStrategyHelper.getBookingId(data);
    if (bookingId != null) {
      context.pushNamed(
        RouterKeys.bookingDetails,
        pathParameters: {'id': bookingId},
      );
    } else {
      context.goNamed(RouterKeys.myBookings);
    }
    return true;
  }
}

