import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../home/data/models/lounge_model.dart';

abstract class FavoritesRepository {
  Future<Either<Failure, List<LoungeModel>>> getFavorites();
  Future<Either<Failure, void>> addFavorite(String loungeId);
  Future<Either<Failure, void>> removeFavorite(String loungeId);
  Future<Either<Failure, List<String>>> getFavoriteIds();
}
