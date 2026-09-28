import 'package:dartz/dartz.dart';
import 'package:playspot/core/error/failures.dart';
import 'package:playspot/core/models/paginated_response.dart';
import 'package:playspot/features/notifications/data/models/notification_model.dart';

abstract class NotificationsRepository {
  Future<Either<Failure, PaginatedResponse<NotificationModel>>> getNotifications(
    String lang, {
    int page = 1,
    int pageSize = 20,
  });
  Future<Either<Failure, void>> markAsRead(String notificationId);
  Future<Either<Failure, void>> markAllAsRead();
  Stream<Map<String, dynamic>> subscribeToNewNotifications();
}
