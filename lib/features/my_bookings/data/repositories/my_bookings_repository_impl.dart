import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
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
  Future<Either<Failure, void>> cancelBooking(String bookingId) async {
    return await callRepository(() => _remoteDataSource.cancelBooking(bookingId));
  }
}
