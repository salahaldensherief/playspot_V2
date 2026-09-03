import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../data/models/booking_params.dart';

abstract class BookingRepository {
  Future<Either<Failure, List<Map<String, dynamic>>>> getRoomBookingsForDate(String loungeId, DateTime date);
  Future<Either<Failure, Map<String, dynamic>>> createBooking(CreateBookingParams params);
  Future<Either<Failure, void>> extendSession({
    required String bookingId,
    required int additionalMinutes,
    required double additionalCost,
  });
  Future<Either<Failure, void>> callStaff({
    required String loungeId,
    required String bookingId,
    required String reason,
    required String note,
  });
  Future<Either<Failure, void>> placeCanteenOrder({
    required String bookingId,
    required String loungeId,
    required String userId,
    required List<Map<String, dynamic>> items,
    required double totalPrice,
    required String note,
  });
}
