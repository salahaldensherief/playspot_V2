import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import 'package:playspot/features/active_session/data/models/active_session_model.dart';
import 'package:playspot/features/active_session/data/models/order_item_model.dart';
import 'package:playspot/features/lounge_details/data/models/extra_model.dart';

abstract class ActiveSessionRepository {
  Future<Either<Failure, ActiveSessionModel?>> getActiveSession();
  Stream<ActiveSessionModel> streamActiveSession(String bookingId);
  Future<Either<Failure, void>> extendTime(String bookingId, int additionalMinutes, double additionalCost);
  Future<Either<Failure, void>> placeOrder(String bookingId, List<OrderItemModel> items);
  Future<Either<Failure, List<ExtraModel>>> getLoungeMenu(String loungeId);
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
}
