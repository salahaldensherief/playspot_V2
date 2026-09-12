import 'package:dartz/dartz.dart';
import 'package:playspot/core/error/failures.dart';
import 'package:playspot/core/models/paginated_response.dart';
import 'package:playspot/core/utils/repository_helper.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../datasources/remote/notifications_remote_data_source.dart';
import '../models/notification_model.dart';

class NotificationsRepositoryImpl with RepositoryHelper implements NotificationsRepository {
  final NotificationsRemoteDataSource _remoteDataSource;

  NotificationsRepositoryImpl(this._remoteDataSource);

  @override
  Future<Either<Failure, PaginatedResponse<NotificationModel>>> getNotifications(
    String lang, {
    int page = 1,
    int pageSize = 20,
  }) async {
    return await callRepository(
      () => _remoteDataSource.getNotifications(lang, page: page, pageSize: pageSize),
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
