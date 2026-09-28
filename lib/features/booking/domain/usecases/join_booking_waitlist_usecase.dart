import 'package:dartz/dartz.dart';
import 'package:playspot/core/error/failures.dart';
import '../repositories/booking_waitlist_repository.dart';

class JoinBookingWaitlistUseCase {
  final BookingWaitlistRepository repository;

  const JoinBookingWaitlistUseCase(this.repository);

  Future<Either<Failure, String>> call({
    required String roomId,
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    final result = await repository.join(
      roomId: roomId,
      startAt: startAt,
      endAt: endAt,
    );
    return result.fold(
      (failure) => Left(failure),
      (payload) {
        if (payload['success'] != true) {
          return Left(ServerFailure(
            payload['error_code']?.toString() ?? 'WAITLIST_FAILED',
          ));
        }
        final id = payload['waitlist_id']?.toString();
        if (id == null || id.isEmpty) {
          return const Left(ServerFailure('WAITLIST_FAILED'));
        }
        return Right(id);
      },
    );
  }
}
