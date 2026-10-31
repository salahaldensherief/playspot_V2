import 'package:dartz/dartz.dart';
import 'package:playspot/core/error/failures.dart';

abstract class BookingWaitlistRepository {
  Future<Either<Failure, String?>> activeRequest({
    required String roomId,
    required DateTime startAt,
    required DateTime endAt,
  });
  Future<Either<Failure, Map<String, dynamic>>> join({
    required String roomId,
    required DateTime startAt,
    required DateTime endAt,
  });
  Future<Either<Failure, bool>> cancel(String requestId);
}
