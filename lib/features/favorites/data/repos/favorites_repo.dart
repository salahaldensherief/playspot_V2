import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/repository_helper.dart';
import '../../../home/data/models/lounge_model.dart';
import '../data_source/remote/favorites_remote_data_source.dart';

abstract class FavoritesRepository {
  Future<Either<Failure, List<LoungeModel>>> getFavorites();
  Future<Either<Failure, void>> addFavorite(String loungeId);
  Future<Either<Failure, void>> removeFavorite(String loungeId);
  Future<Either<Failure, List<String>>> getFavoriteIds();
}

class FavoritesRepositoryImpl with RepositoryHelper implements FavoritesRepository {
  final FavoritesRemoteDataSource _remoteDataSource;

  FavoritesRepositoryImpl(this._remoteDataSource);

  @override
  Future<Either<Failure, List<LoungeModel>>> getFavorites() async {
    return await callRepository(() => _remoteDataSource.getFavorites());
  }

  @override
  Future<Either<Failure, void>> addFavorite(String loungeId) async {
    return await callRepository(() => _remoteDataSource.addFavorite(loungeId));
  }

  @override
  Future<Either<Failure, void>> removeFavorite(String loungeId) async {
    return await callRepository(() => _remoteDataSource.removeFavorite(loungeId));
  }

  @override
  Future<Either<Failure, List<String>>> getFavoriteIds() async {
    return await callRepository(() => _remoteDataSource.getFavoriteIds());
  }
}
