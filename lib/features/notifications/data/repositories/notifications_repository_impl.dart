import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/repository_helper.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../datasources/remote/notifications_remote_data_source.dart';
import '../models/notification_model.dart';

class NotificationsRepositoryImpl with RepositoryHelper implements NotificationsRepository {
  final NotificationsRemoteDataSource _remoteDataSource;

  NotificationsRepositoryImpl(this._remoteDataSource);

  @override
  Future<Either<Failure, List<NotificationModel>>> getNotifications(
    String lang, {
    int limit = 15,
    int offset = 0,
  }) async {
    return await callRepository(
      () => _remoteDataSource.getNotifications(lang, limit: limit, offset: offset),
    );
  }

  @override
  Future<Either<Failure, void>> markAsRead(String notificationId) async {
    return await callRepository(() => _remoteDataSource.markAsRead(notificationId));
  }

  @override
  Future<Either<Failure, void>> markAllAsRead() async {
    return await callRepository(() => _remoteDataSource.markAllAsRead());
  }

  @override
  Stream<Map<String, dynamic>> subscribeToNewNotifications() {
    return _remoteDataSource.subscribeToNewNotifications();
  }
}
