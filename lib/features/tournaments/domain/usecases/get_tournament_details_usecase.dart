import 'package:dartz/dartz.dart';
import 'package:playspot/core/error/failures.dart';
import '../entities/tournament_entity.dart';
import '../repositories/tournaments_repository.dart';

class GetTournamentDetailsUseCase {
  final TournamentsRepository repository;

  GetTournamentDetailsUseCase(this.repository);

  Future<Either<Failure, TournamentEntity>> getTournamentById(String tournamentId) {
    return repository.getTournamentById(tournamentId);
  }

  Future<Either<Failure, List<TournamentPrizeEntity>>> getPrizes(String tournamentId) {
    return repository.getTournamentPrizes(tournamentId);
  }

  Future<Either<Failure, List<TournamentMatchEntity>>> getMatches(String tournamentId) {
    return repository.getTournamentMatches(tournamentId);
  }

  Future<Either<Failure, TournamentParticipantEntity?>> getUserParticipant(
    String tournamentId,
    String userId,
  ) {
    return repository.getUserParticipant(tournamentId, userId);
  }
}
