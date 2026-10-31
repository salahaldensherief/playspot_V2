import 'package:dartz/dartz.dart';
import 'package:playspot/core/error/failures.dart';
import 'package:playspot/core/utils/repository_helper.dart';
import '../../domain/repositories/booking_waitlist_repository.dart';
import '../datasources/remote/booking_waitlist_remote_data_source.dart';

class BookingWaitlistRepositoryImpl
    with RepositoryHelper
    implements BookingWaitlistRepository {
  final BookingWaitlistRemoteDataSource dataSource;

  BookingWaitlistRepositoryImpl(this.dataSource);

  @override
  Future<Either<Failure, String?>> activeRequest({
    required String roomId,
    required DateTime startAt,
    required DateTime endAt,
  }) => callRepository(
    () => dataSource.activeRequest(
      roomId: roomId,
      startAt: startAt,
      endAt: endAt,
    ),
  );

  @override
  Future<Either<Failure, Map<String, dynamic>>> join({
    required String roomId,
    required DateTime startAt,
    required DateTime endAt,
  }) => callRepository(
    () => dataSource.join(roomId: roomId, startAt: startAt, endAt: endAt),
  );

  @override
  Future<Either<Failure, bool>> cancel(String requestId) =>
      callRepository(() => dataSource.cancel(requestId));
}
