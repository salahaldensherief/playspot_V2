import 'package:dartz/dartz.dart';
import 'package:playspot/core/error/failures.dart';
import 'package:playspot/features/tournaments/domain/entities/user_tournament_participation_entity.dart';
import 'package:playspot/features/tournaments/domain/repositories/tournaments_repository.dart';

class GetMyActiveTournamentUseCase {
  final TournamentsRepository repository;

  GetMyActiveTournamentUseCase(this.repository);

  Future<Either<Failure, UserTournamentParticipationEntity?>> call() {
    return repository.getMyActiveTournament();
  }
}
