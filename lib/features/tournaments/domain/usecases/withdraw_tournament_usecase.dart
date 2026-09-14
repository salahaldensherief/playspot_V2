import 'package:dartz/dartz.dart';
import 'package:playspot/core/error/failures.dart';
import '../repositories/tournaments_repository.dart';

class WithdrawTournamentUseCase {
  final TournamentsRepository repository;

  WithdrawTournamentUseCase(this.repository);

  Future<Either<Failure, void>> call(String participantId) {
    return repository.withdrawFromTournament(participantId);
  }
}
