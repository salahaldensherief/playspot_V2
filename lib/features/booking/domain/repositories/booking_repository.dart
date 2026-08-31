import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../data/models/booking_params.dart';

abstract class BookingRepository {
  Future<Either<Failure, List<Map<String, dynamic>>>> getRoomBookingsForDate(String loungeId, DateTime date);
  Future<Either<Failure, Map<String, dynamic>>> createBooking(CreateBookingParams params);
}
