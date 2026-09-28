import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/models/paginated_response.dart';
import '../../data/models/booking_model.dart';

abstract class MyBookingsRepository {
  Future<Either<Failure, List<BookingModel>>> getMyBookings();
  Future<Either<Failure, PaginatedResponse<BookingModel>>> getLoungeBookingsPage({
    required String loungeId,
    int page = 1,
    int pageSize = 20,
  });
  Future<Either<Failure, void>> cancelBooking(String bookingId);
}
