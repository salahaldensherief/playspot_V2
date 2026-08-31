import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../data/models/booking_model.dart';

abstract class MyBookingsRepository {
  Future<Either<Failure, List<BookingModel>>> getMyBookings();
  Future<Either<Failure, void>> cancelBooking(String bookingId);
}
