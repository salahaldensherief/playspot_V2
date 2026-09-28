import 'package:dartz/dartz.dart';
import 'package:playspot/core/error/failures.dart';
import '../entities/tournament_entity.dart';
import '../repositories/tournaments_repository.dart';

class RegisterTournamentUseCase {
  final TournamentsRepository repository;

  RegisterTournamentUseCase(this.repository);

  Future<Either<Failure, TournamentParticipantEntity?>> call(String tournamentId) {
    return repository.registerForTournament(tournamentId);
  }
}
