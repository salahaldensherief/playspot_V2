import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/active_session_repository.dart';

class ExtendSessionTimeUseCase {
  final ActiveSessionRepository repository;

  ExtendSessionTimeUseCase(this.repository);

  Future<Either<Failure, void>> call({
    required String bookingId,
    required int additionalMinutes,
    required double additionalCost,
  }) {
    return repository.extendTime(bookingId, additionalMinutes, additionalCost);
  }
}
