import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/active_session_repository.dart';

class RequestStaffAssistanceUseCase {
  final ActiveSessionRepository repository;

  RequestStaffAssistanceUseCase(this.repository);

  Future<Either<Failure, void>> call({
    required String bookingId,
    required String callType,
    String? notes,
  }) {
    return repository.requestStaffAssistance(
      bookingId: bookingId,
      callType: callType,
      notes: notes,
    );
  }
}
