import 'package:dartz/dartz.dart';
import 'package:playspot/core/error/failures.dart';
import '../repositories/tournaments_repository.dart';

class CheckInParticipantUseCase {
  final TournamentsRepository repository;

  CheckInParticipantUseCase(this.repository);

  Future<Either<Failure, void>> call(String participantId) {
    return repository.checkInParticipant(participantId);
  }
}
