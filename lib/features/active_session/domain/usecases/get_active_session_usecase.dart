import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/active_session.dart';
import '../repositories/active_session_repository.dart';

class GetActiveSessionUseCase {
  final ActiveSessionRepository repository;

  GetActiveSessionUseCase(this.repository);

  Future<Either<Failure, ActiveSession?>> call({String? bookingId}) {
    return repository.getActiveSession(bookingId: bookingId);
  }
}
