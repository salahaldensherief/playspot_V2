import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../data/models/extra_model.dart';
import '../../data/models/room_model.dart';
import '../../data/models/review_model.dart';
import '../../../home/data/models/category_model.dart';

abstract class LoungeDetailsRepository {
  Future<Either<Failure, List<RoomModel>>> getRoomsByLoungeId(String loungeId, {String? categoryId});
  Future<Either<Failure, List<ExtraModel>>> getExtras(String loungeId);
  Future<Either<Failure, List<CategoryModel>>> getLoungeCategories(String loungeId);
  Future<Either<Failure, List<ReviewModel>>> getLoungeReviews(String loungeId);
}
