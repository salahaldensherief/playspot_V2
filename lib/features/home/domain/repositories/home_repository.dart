import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../data/models/lounge_model.dart';
import '../../data/models/promo_model.dart';
import '../../data/models/category_model.dart';
import '../../data/models/home_params.dart';

abstract class HomeRepository {
  Future<Either<Failure, List<LoungeModel>>> getLounges(GetLoungesParams params);
  Future<Either<Failure, List<Map<String, dynamic>>>> getAvailableCities();
  Future<Either<Failure, List<PromoModel>>> getPromotions({String? loungeId});
  Future<Either<Failure, List<CategoryModel>>> getCategories();
  Future<Either<Failure, int>> getUserPoints(String userId);
  Future<Either<Failure, LoungeModel?>> getLoungeById(String id);
}
