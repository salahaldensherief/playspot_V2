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
    final status = NotificationStrategyHelper.cleanString(data['status'])?.toLowerCase();
    final type = NotificationStrategyHelper.cleanString(data['type'])?.toLowerCase();
    final action = NotificationStrategyHelper.cleanString(data['action'])?.toLowerCase();
    final title = data['title']?.toString().toLowerCase() ?? '';
    final body = data['body']?.toString().toLowerCase() ?? '';

    final isCancelled = status == 'cancelled' ||
        status == 'rejected' ||
        status == 'declined' ||
        (type?.contains('cancel') ?? false) ||
        (action?.contains('cancel') ?? false) ||
        title.contains('cancel') ||
        body.contains('cancel') ||
        title.contains('إلغاء') ||
        body.contains('إلغاء') ||
        title.contains('ملغ') ||
        body.contains('ملغ') ||
        title.contains('رفض') ||
        body.contains('رفض');

    final initialTab = isCancelled ? 2 : null;

    if (bookingId != null) {
      context.pushNamed(
        RouterKeys.bookingDetails,
        pathParameters: {'id': bookingId},
        extra: {'initialTab': initialTab},
      );
    } else {
      context.goNamed(
        RouterKeys.myBookings,
        extra: {'initialTab': initialTab},
      );
    }
    return true;
  }
}

