import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/repository_helper.dart';
import '../data_source/remote/notifications_remote_data_source.dart';
import '../models/notification_model.dart';

abstract class NotificationsRepository {
  Future<Either<Failure, List<NotificationModel>>> getNotifications(String lang);
  Future<Either<Failure, void>> markAsRead(String notificationId);
  Future<Either<Failure, void>> markAllAsRead();
}

class NotificationsRepositoryImpl with RepositoryHelper implements NotificationsRepository {
  final NotificationsRemoteDataSource _remoteDataSource;

  NotificationsRepositoryImpl(this._remoteDataSource);

  @override
  Future<Either<Failure, List<NotificationModel>>> getNotifications(String lang) async {
    return await callRepository(() => _remoteDataSource.getNotifications(lang));
  }

  @override
  Future<Either<Failure, void>> markAsRead(String notificationId) async {
    return await callRepository(() => _remoteDataSource.markAsRead(notificationId));
  }

  @override
  Future<Either<Failure, void>> markAllAsRead() async {
    return await callRepository(() => _remoteDataSource.markAllAsRead());
  }
}
