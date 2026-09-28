import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/models/paginated_response.dart';
import '../entities/active_session.dart';
import '../entities/order_item.dart';
import '../../../lounge_details/data/models/extra_model.dart';

abstract class ActiveSessionRepository {
  Future<Either<Failure, ActiveSession?>> getActiveSession({String? bookingId});
  Stream<ActiveSession> streamActiveSession(String bookingId);
  Stream<ActiveSession?> watchUserActiveSession();
  Future<Either<Failure, void>> extendTime(String bookingId, int additionalMinutes, double additionalCost);
  Future<Either<Failure, void>> requestExtension({
    required String bookingId,
    required int requestedMinutes,
  });
  Future<Either<Failure, void>> placeOrder(String bookingId, List<OrderItem> items);
  Future<Either<Failure, List<ExtraModel>>> getLoungeMenu(
    String loungeId, {
    bool forceRefresh = false,
  });
  Future<Either<Failure, void>> requestStaffAssistance({
    required String bookingId,
    required String callType,
    String? notes,
  });
  Future<Either<Failure, void>> submitLoungeReview({
    required String loungeId,
    required String bookingId,
    required double rating,
    String? comment,
  });
  Future<Either<Failure, PaginatedResponse<Map<String, dynamic>>>> getActiveLoungeRequestsPage({
    required String loungeId,
    int page = 1,
    int pageSize = 20,
  });
}
