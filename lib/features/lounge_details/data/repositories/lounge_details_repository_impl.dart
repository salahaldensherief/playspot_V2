import 'package:dartz/dartz.dart';
import '../../../../core/datasources/local/app_cache_local_data_source.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/repository_helper.dart';
import '../../domain/repositories/lounge_details_repository.dart';
import '../datasources/remote/lounge_details_remote_data_source.dart';
import '../models/extra_model.dart';
import '../models/room_model.dart';
import '../models/review_model.dart';
import '../../../home/data/models/category_model.dart';

class LoungeDetailsRepositoryImpl with RepositoryHelper implements LoungeDetailsRepository {
  final LoungeDetailsRemoteDataSource _remoteDataSource;
  final AppCacheLocalDataSource _cacheLocalDataSource;

  LoungeDetailsRepositoryImpl(
    this._remoteDataSource,
    this._cacheLocalDataSource,
  );

  @override
  Future<Either<Failure, List<RoomModel>>> getRoomsByLoungeId(
    String loungeId, {
    String? categoryId,
    bool forceRefresh = false,
  }) async {
    final bool isUnfiltered = categoryId == null || categoryId.isEmpty || categoryId.toLowerCase() == 'all';

    if (!forceRefresh && isUnfiltered) {
      final cached = _cacheLocalDataSource.getCachedLoungeRooms(loungeId);
      if (cached != null && cached.isNotEmpty) {
        // Background fetch to refresh local cache
        _remoteDataSource.getRoomsByLoungeId(loungeId, categoryId: categoryId).then((rooms) {
          if (rooms.isNotEmpty) {
            _cacheLocalDataSource.cacheLoungeRooms(loungeId, rooms);
          }
        }).catchError((_) {});

        return Right(cached);
      }
    }

    final result = await callRepository(
      () => _remoteDataSource.getRoomsByLoungeId(loungeId, categoryId: categoryId),
    );

    result.fold(
      (_) {
        if (isUnfiltered) {
          final cached = _cacheLocalDataSource.getCachedLoungeRooms(loungeId);
          if (cached != null && cached.isNotEmpty) {
            return Right(cached);
          }
        }
      },
      (rooms) {
        if (isUnfiltered && rooms.isNotEmpty) {
          _cacheLocalDataSource.cacheLoungeRooms(loungeId, rooms);
        }
      },
    );

    return result;
  }

  @override
  Future<Either<Failure, List<ExtraModel>>> getExtras(
    String loungeId, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = _cacheLocalDataSource.getCachedLoungeMenu(loungeId);
      if (cached != null && cached.isNotEmpty) {
        // Background fetch to keep local cache updated
        _remoteDataSource.getExtras(loungeId).then((extras) {
          if (extras.isNotEmpty) {
            _cacheLocalDataSource.cacheLoungeMenu(loungeId, extras);
          }
        }).catchError((_) {});

        return Right(cached);
      }
    }

    final result = await callRepository(() => _remoteDataSource.getExtras(loungeId));

    result.fold(
      (_) {
        final cached = _cacheLocalDataSource.getCachedLoungeMenu(loungeId);
        if (cached != null && cached.isNotEmpty) {
          return Right(cached);
        }
      },
      (extras) {
        if (extras.isNotEmpty) {
          _cacheLocalDataSource.cacheLoungeMenu(loungeId, extras);
        }
      },
    );

    return result;
  }

  @override
  Future<Either<Failure, List<CategoryModel>>> getLoungeCategories(
    String loungeId, {
    bool forceRefresh = false,
  }) async {
    return await callRepository(() => _remoteDataSource.getLoungeCategories(loungeId));
  }

  @override
  Future<Either<Failure, List<ReviewModel>>> getLoungeReviews(
    String loungeId, {
    bool forceRefresh = false,
  }) async {
    return await callRepository(() => _remoteDataSource.getLoungeReviews(loungeId));
  }

  @override
  Future<Either<Failure, RoomModel?>> getRoomById(
    String roomId, {
    bool forceRefresh = false,
  }) async {
    return await callRepository(() => _remoteDataSource.getRoomById(roomId));
  }
}
