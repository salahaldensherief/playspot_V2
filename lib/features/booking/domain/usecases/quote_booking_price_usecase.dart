import 'package:dartz/dartz.dart';
import 'package:playspot/core/error/failures.dart';
import '../entities/booking_price_quote.dart';
import '../repositories/booking_repository.dart';

class QuoteBookingPriceUseCase {
  final BookingRepository _repository;

  QuoteBookingPriceUseCase(this._repository);

  Future<Either<Failure, BookingPriceQuote>> call({
    required String roomId,
    required String date,
    required String startTime,
    required String endTime,
    String playMode = 'single',
    int extraControllers = 0,
    String? couponCode,
  }) {
    return _repository.quoteBookingPrice(
      roomId: roomId,
      date: date,
      startTime: startTime,
      endTime: endTime,
      playMode: playMode,
      extraControllers: extraControllers,
      couponCode: couponCode,
    );
  }
}
