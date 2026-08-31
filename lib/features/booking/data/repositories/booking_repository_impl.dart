import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/repository_helper.dart';
import '../../domain/repositories/booking_repository.dart';
import '../datasources/remote/booking_remote_data_source.dart';
import '../models/booking_params.dart';

class BookingRepositoryImpl with RepositoryHelper implements BookingRepository {
  final BookingRemoteDataSource _remoteDataSource;

  BookingRepositoryImpl(this._remoteDataSource);

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getRoomBookingsForDate(String loungeId, DateTime date) async {
    return await callRepository(() => _remoteDataSource.getRoomBookingsForDate(loungeId, date));
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> createBooking(CreateBookingParams params) async {
    return await callRepository(() => _remoteDataSource.createBooking(params));
  }
}
