import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/active_session_repository.dart';

class RequestSessionExtensionUseCase {
  final ActiveSessionRepository repository;

  RequestSessionExtensionUseCase(this.repository);

  Future<Either<Failure, void>> call({
    required String bookingId,
    required int requestedMinutes,
  }) {
    return repository.requestExtension(
      bookingId: bookingId,
      requestedMinutes: requestedMinutes,
    );
  }
}
