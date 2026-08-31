import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../data/models/notification_model.dart';

abstract class NotificationsRepository {
  Future<Either<Failure, List<NotificationModel>>> getNotifications(String lang);
  Future<Either<Failure, void>> markAsRead(String notificationId);
  Future<Either<Failure, void>> markAllAsRead();
}
