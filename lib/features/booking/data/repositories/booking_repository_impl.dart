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

  @override
  Future<Either<Failure, void>> extendSession({
    required String bookingId,
    required int additionalMinutes,
    required double additionalCost,
  }) async {
    return await callRepository(() => _remoteDataSource.extendSession(
          bookingId: bookingId,
          additionalMinutes: additionalMinutes,
          additionalCost: additionalCost,
        ));
  }

  @override
  Future<Either<Failure, void>> callStaff({
    required String loungeId,
    required String bookingId,
    required String reason,
    required String note,
  }) async {
    return await callRepository(() => _remoteDataSource.callStaff(
          loungeId: loungeId,
          bookingId: bookingId,
          reason: reason,
          note: note,
        ));
  }

  @override
  Future<Either<Failure, void>> placeCanteenOrder({
    required String bookingId,
    required String loungeId,
    required String userId,
    required List<Map<String, dynamic>> items,
    required double totalPrice,
    required String note,
  }) async {
    return await callRepository(() => _remoteDataSource.placeCanteenOrder(
          bookingId: bookingId,
          loungeId: loungeId,
          userId: userId,
          items: items,
          totalPrice: totalPrice,
          note: note,
        ));
  }
}
