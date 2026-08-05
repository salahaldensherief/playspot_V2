import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/repository_helper.dart';
import '../data_source/remote/lounge_details_remote_data_source.dart';
import '../models/extra_model.dart';
import '../models/room_model.dart';
import '../models/review_model.dart';
import '../../../home/data/models/category_model.dart';

abstract class LoungeDetailsRepository {
  Future<Either<Failure, List<RoomModel>>> getRoomsByLoungeId(String loungeId, {String? categoryId});
  Future<Either<Failure, List<ExtraModel>>> getExtras(String loungeId);
  Future<Either<Failure, List<CategoryModel>>> getLoungeCategories(String loungeId);
  Future<Either<Failure, List<ReviewModel>>> getLoungeReviews(String loungeId);
}

class LoungeDetailsRepositoryImpl with RepositoryHelper implements LoungeDetailsRepository {
  final LoungeDetailsRemoteDataSource _remoteDataSource;

  LoungeDetailsRepositoryImpl(this._remoteDataSource);

  @override
  Future<Either<Failure, List<RoomModel>>> getRoomsByLoungeId(String loungeId, {String? categoryId}) async {
    return await callRepository(() => _remoteDataSource.getRoomsByLoungeId(loungeId, categoryId: categoryId));
  }

  @override
  Future<Either<Failure, List<ExtraModel>>> getExtras(String loungeId) async {
    return await callRepository(() => _remoteDataSource.getExtras(loungeId));
  }

  @override
  Future<Either<Failure, List<CategoryModel>>> getLoungeCategories(String loungeId) async {
    return await callRepository(() => _remoteDataSource.getLoungeCategories(loungeId));
  }

  @override
  Future<Either<Failure, List<ReviewModel>>> getLoungeReviews(String loungeId) async {
    return await callRepository(() => _remoteDataSource.getLoungeReviews(loungeId));
  }
}
