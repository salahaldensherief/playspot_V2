import 'package:dartz/dartz.dart';
import 'package:playspot/core/error/failures.dart';
import '../entities/lounge_price_range.dart';
import '../repositories/booking_repository.dart';

class GetLoungePriceRangeUseCase {
  final BookingRepository _repository;

  GetLoungePriceRangeUseCase(this._repository);

  Future<Either<Failure, LoungePriceRange>> call(String loungeId) {
    return _repository.getLoungePriceRange(loungeId);
  }
}
