import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/active_session_repository.dart';

class RecordUpsellEventUseCase {
  final ActiveSessionRepository repository;

  RecordUpsellEventUseCase(this.repository);

  Future<Either<Failure, void>> call({
    required String ruleId,
    required String bookingId,
    required String event,
    String? canteenOrderId,
    double? amount,
  }) {
    return repository.recordUpsellEvent(
      ruleId: ruleId,
      bookingId: bookingId,
      event: event,
      canteenOrderId: canteenOrderId,
      amount: amount,
    );
  }
}
