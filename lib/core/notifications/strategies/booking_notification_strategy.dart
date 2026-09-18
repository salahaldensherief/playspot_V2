import 'package:go_router/go_router.dart';
import 'package:playspot/art_core/router/app_router.dart';
import 'package:playspot/art_core/router/router_keys.dart';
import 'notification_action_strategy.dart';

class BookingNotificationStrategy implements NotificationActionStrategy {
  const BookingNotificationStrategy();

  @override
  bool canHandle(Map<String, dynamic> data) {
    final type = data['type']?.toString().toLowerCase();
    final bookingId = data['booking_id'] ?? data['id'];
    return (type != null && type.contains('booking')) || bookingId != null;
  }

  @override
  bool handle(Map<String, dynamic> data) {
    final context = AppRouter.navigatorKey.currentContext;
    if (context == null) return false;

    final bookingId = data['booking_id']?.toString() ?? data['id']?.toString();
    if (bookingId != null && bookingId.isNotEmpty) {
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
