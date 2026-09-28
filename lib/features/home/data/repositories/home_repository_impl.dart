import 'package:dartz/dartz.dart';
import '../../../../core/datasources/local/app_cache_local_data_source.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/repository_helper.dart';
import '../../domain/repositories/home_repository.dart';
import '../datasources/remote/home_remote_data_source.dart';
import '../models/lounge_model.dart';
import '../models/promo_model.dart';
import '../models/category_model.dart';
import '../models/home_params.dart';

class HomeRepositoryImpl with RepositoryHelper implements HomeRepository {
  final HomeRemoteDataSource _remoteDataSource;
  final AppCacheLocalDataSource _cacheLocalDataSource;

  HomeRepositoryImpl(
    this._remoteDataSource,
    this._cacheLocalDataSource,
  );

  @override
  Future<Either<Failure, int>> getUserPoints(String userId) async {
    return await callRepository(() => _remoteDataSource.getUserPoints(userId));
  }

  @override
  Future<Either<Failure, List<LoungeModel>>> getLounges(GetLoungesParams params) async {
    return await callRepository(() => _remoteDataSource.getLounges(params));
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getAvailableCities() async {
    return await callRepository(() => _remoteDataSource.getAvailableCities());
  }

  @override
  Future<Either<Failure, List<PromoModel>>> getPromotions({
    String? loungeId,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && loungeId == null) {
      final cached = _cacheLocalDataSource.getCachedPromotions();
      if (cached != null && cached.isNotEmpty) {
        // Background fetch to keep cache fresh
        _remoteDataSource.getPromotions(loungeId: loungeId).then((promos) {
          if (promos.isNotEmpty) {
            _cacheLocalDataSource.cachePromotions(promos);
          }
        }).catchError((_) {});

        return Right(cached);
      }
    }

    final result = await callRepository(() => _remoteDataSource.getPromotions(loungeId: loungeId));
    result.fold(
      (_) {
        // Fallback to local cache if network fails
        if (loungeId == null) {
          final cached = _cacheLocalDataSource.getCachedPromotions();
          if (cached != null && cached.isNotEmpty) {
            return Right(cached);
          }
        }
      },
      (promos) {
        if (loungeId == null && promos.isNotEmpty) {
          _cacheLocalDataSource.cachePromotions(promos);
        }
      },
    );
    return result;
  }

  @override
  Future<Either<Failure, List<CategoryModel>>> getCategories({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = _cacheLocalDataSource.getCachedCategories();
      if (cached != null && cached.isNotEmpty) {
        // Background fetch to keep cache fresh
        _remoteDataSource.getCategories().then((categories) {
          if (categories.isNotEmpty) {
            _cacheLocalDataSource.cacheCategories(categories);
          }
        }).catchError((_) {});

        return Right(cached);
      }
    }

    final result = await callRepository(() => _remoteDataSource.getCategories());
    result.fold(
      (_) {
        final cached = _cacheLocalDataSource.getCachedCategories();
        if (cached != null && cached.isNotEmpty) {
          return Right(cached);
        }
      },
      (categories) {
        if (categories.isNotEmpty) {
          _cacheLocalDataSource.cacheCategories(categories);
        }
      },
    );
    return result;
  }

  @override
  Future<Either<Failure, LoungeModel?>> getLoungeById(
    String id, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = _cacheLocalDataSource.getCachedLoungeProfile(id);
      if (cached != null) {
        // Background fetch to keep cache fresh
        _remoteDataSource.getLoungeById(id).then((lounge) {
          if (lounge != null) {
            _cacheLocalDataSource.cacheLoungeProfile(id, lounge);
          }
        }).catchError((_) {});

        return Right(cached);
      }
    }

    final result = await callRepository(() => _remoteDataSource.getLoungeById(id));
    result.fold(
      (_) {
        final cached = _cacheLocalDataSource.getCachedLoungeProfile(id);
        if (cached != null) {
          return Right(cached);
        }
      },
      (lounge) {
        if (lounge != null) {
          _cacheLocalDataSource.cacheLoungeProfile(id, lounge);
        }
      },
    );
    return result;
  }
}
