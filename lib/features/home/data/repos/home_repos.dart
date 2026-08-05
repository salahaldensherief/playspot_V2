import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/repository_helper.dart';
import '../data_source/remote/home_remote_data_source.dart';
import '../models/lounge_model.dart';
import '../models/promo_model.dart';
import '../models/category_model.dart';

abstract class HomeRepository {
  Future<Either<Failure, List<LoungeModel>>> getLounges({
    double? lat,
    double? lng,
    String? city,
    List<String>? categoryIds,
  });
  Future<Either<Failure, List<Map<String, dynamic>>>> getAvailableCities();
  Future<Either<Failure, List<PromoModel>>> getPromotions();
  Future<Either<Failure, List<CategoryModel>>> getCategories();
  Future<Either<Failure, int>> getUserPoints(String userId);
}

class HomeRepositoryImpl with RepositoryHelper implements HomeRepository {
  final HomeRemoteDataSource _remoteDataSource;

  HomeRepositoryImpl(this._remoteDataSource);

  @override
  Future<Either<Failure, int>> getUserPoints(String userId) async {
    return await callRepository(() => _remoteDataSource.getUserPoints(userId));
  }

  @override
  Future<Either<Failure, List<LoungeModel>>> getLounges({
    double? lat,
    double? lng,
    String? city,
    List<String>? categoryIds,
  }) async {
    return await callRepository(() => _remoteDataSource.getLounges(
          lat: lat,
          lng: lng,
          city: city,
          categoryIds: categoryIds,
        ));
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getAvailableCities() async {
    return await callRepository(() => _remoteDataSource.getAvailableCities());
  }

  @override
  Future<Either<Failure, List<PromoModel>>> getPromotions() async {
    return await callRepository(() => _remoteDataSource.getPromotions());
  }

  @override
  Future<Either<Failure, List<CategoryModel>>> getCategories() async {
    return await callRepository(() => _remoteDataSource.getCategories());
  }
}

