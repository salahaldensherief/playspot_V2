import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/models/paginated_response.dart';
import '../../data/models/extra_model.dart';
import '../../data/models/room_model.dart';
import '../../data/models/review_model.dart';
import '../../../home/data/models/category_model.dart';

abstract class LoungeDetailsRepository {
  Future<Either<Failure, List<RoomModel>>> getRoomsByLoungeId(
    String loungeId, {
    String? categoryId,
    bool forceRefresh = false,
  });
  Future<Either<Failure, List<ExtraModel>>> getExtras(
    String loungeId, {
    bool forceRefresh = false,
  });
  Future<Either<Failure, List<CategoryModel>>> getLoungeCategories(
    String loungeId, {
    bool forceRefresh = false,
  });
  Future<Either<Failure, List<ReviewModel>>> getLoungeReviews(
    String loungeId, {
    bool forceRefresh = false,
  });
  Future<Either<Failure, PaginatedResponse<ReviewModel>>> getLoungeReviewsPage(
    String loungeId, {
    int page = 1,
    int pageSize = 20,
  });
  Future<Either<Failure, PaginatedResponse<Map<String, dynamic>>>> getLoungeRolePermissionsPage(
    String loungeId, {
    int page = 1,
    int pageSize = 50,
  });
  Future<Either<Failure, RoomModel?>> getRoomById(
    String roomId, {
    bool forceRefresh = false,
  });
}
