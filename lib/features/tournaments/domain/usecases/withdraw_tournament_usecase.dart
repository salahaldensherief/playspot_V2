import 'package:dartz/dartz.dart';
import 'package:playspot/core/error/failures.dart';
import '../entities/tournament_entity.dart';
import '../repositories/tournaments_repository.dart';

class WithdrawTournamentUseCase {
  final TournamentsRepository repository;

  WithdrawTournamentUseCase(this.repository);

  Future<Either<Failure, TournamentParticipantEntity?>> call(String participantId, {String? tournamentId}) {
    return repository.withdrawFromTournament(participantId, tournamentId: tournamentId);
  }
}
