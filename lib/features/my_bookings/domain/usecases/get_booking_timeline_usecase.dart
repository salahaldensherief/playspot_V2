import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/booking_timeline_item.dart';
import '../repositories/my_bookings_repository.dart';

class GetBookingTimelineUseCase {
  final MyBookingsRepository repository;

  GetBookingTimelineUseCase(this.repository);

  Future<Either<Failure, List<BookingTimelineItem>>> call(String bookingId) async {
    return await repository.getBookingTimeline(bookingId);
  }
}
