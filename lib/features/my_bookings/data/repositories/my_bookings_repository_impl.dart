import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/models/paginated_response.dart';
import '../../../../core/utils/repository_helper.dart';
import '../../domain/repositories/my_bookings_repository.dart';
import '../datasources/remote/my_bookings_remote_data_source.dart';
import '../models/booking_model.dart';

class MyBookingsRepositoryImpl with RepositoryHelper implements MyBookingsRepository {
  final MyBookingsRemoteDataSource _remoteDataSource;

  MyBookingsRepositoryImpl(this._remoteDataSource);

  @override
  Future<Either<Failure, List<BookingModel>>> getMyBookings() async {
    return await callRepository(() => _remoteDataSource.getMyBookings());
  }

  @override
  Future<Either<Failure, PaginatedResponse<BookingModel>>> getLoungeBookingsPage({
    required String loungeId,
    int page = 1,
    int pageSize = 20,
  }) async {
    return await callRepository(
      () => _remoteDataSource.getLoungeBookingsPage(loungeId: loungeId, page: page, pageSize: pageSize),
    );
  }

  @override
  Future<Either<Failure, void>> cancelBooking(String bookingId) async {
    return await callRepository(() => _remoteDataSource.cancelBooking(bookingId));
  }
}
