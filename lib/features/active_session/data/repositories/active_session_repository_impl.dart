import 'package:dartz/dartz.dart';
import '../../../../core/datasources/local/app_cache_local_data_source.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/repository_helper.dart';
import '../../domain/repositories/active_session_repository.dart';
import '../datasources/remote/active_session_remote_data_source.dart';
import '../models/active_session_model.dart';
import '../models/order_item_model.dart';
import '../../../lounge_details/data/models/extra_model.dart';

class ActiveSessionRepositoryImpl with RepositoryHelper implements ActiveSessionRepository {
  final ActiveSessionRemoteDataSource _remoteDataSource;
  final AppCacheLocalDataSource _cacheLocalDataSource;

  ActiveSessionRepositoryImpl(
    this._remoteDataSource,
    this._cacheLocalDataSource,
  );

  @override
  Future<Either<Failure, ActiveSessionModel?>> getActiveSession({String? bookingId}) async {
    return await callRepository(() => _remoteDataSource.getActiveSession(bookingId: bookingId));
  }

  @override
  Stream<ActiveSessionModel> streamActiveSession(String bookingId) {
    return _remoteDataSource.streamActiveSession(bookingId);
  }

  @override
  Stream<ActiveSessionModel?> watchUserActiveSession() {
    return _remoteDataSource.watchUserActiveSession();
  }

  @override
  Future<Either<Failure, void>> extendTime(String bookingId, int additionalMinutes, double additionalCost) async {
    return await callRepository(() => _remoteDataSource.extendTime(bookingId, additionalMinutes, additionalCost));
  }

  @override
  Future<Either<Failure, void>> requestExtension({
    required String bookingId,
    required int requestedMinutes,
  }) async {
    return await callRepository(() => _remoteDataSource.requestExtension(
          bookingId: bookingId,
          requestedMinutes: requestedMinutes,
        ));
  }

  @override
  Future<Either<Failure, void>> placeOrder(String bookingId, List<OrderItemModel> items) async {
    return await callRepository(() => _remoteDataSource.placeOrder(bookingId, items));
  }

  @override
  Future<Either<Failure, List<ExtraModel>>> getLoungeMenu(
    String loungeId, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = _cacheLocalDataSource.getCachedLoungeMenu(loungeId);
      if (cached != null && cached.isNotEmpty) {
        // Background fetch to update cache
        _remoteDataSource.getLoungeMenu(loungeId).then((menu) {
          if (menu.isNotEmpty) {
            _cacheLocalDataSource.cacheLoungeMenu(loungeId, menu);
          }
        }).catchError((_) {});

        return Right(cached);
      }
    }

    final result = await callRepository(() => _remoteDataSource.getLoungeMenu(loungeId));

    result.fold(
      (_) {
        final cached = _cacheLocalDataSource.getCachedLoungeMenu(loungeId);
        if (cached != null && cached.isNotEmpty) {
          return Right(cached);
        }
      },
      (menu) {
        if (menu.isNotEmpty) {
          _cacheLocalDataSource.cacheLoungeMenu(loungeId, menu);
        }
      },
    );

    return result;
  }

  @override
  Future<Either<Failure, void>> requestStaffAssistance({
    required String bookingId,
    required String callType,
    String? notes,
  }) async {
    return await callRepository(() => _remoteDataSource.requestStaffAssistance(
      bookingId: bookingId,
      callType: callType,
      notes: notes,
    ));
  }

  @override
  Future<Either<Failure, void>> submitLoungeReview({
    required String loungeId,
    required String bookingId,
    required double rating,
    String? comment,
  }) async {
    return await callRepository(() => _remoteDataSource.submitLoungeReview(
      loungeId: loungeId,
      bookingId: bookingId,
      rating: rating,
      comment: comment,
    ));
  }
}
