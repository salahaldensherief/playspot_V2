import 'package:dartz/dartz.dart';
import 'package:playspot/core/error/failures.dart';
import 'package:playspot/features/tournaments/domain/entities/tournament_entity.dart';
import 'package:playspot/features/tournaments/domain/repositories/tournaments_repository.dart';

class GetHomeTournamentUseCase {
  final TournamentsRepository repository;

  GetHomeTournamentUseCase(this.repository);

  Future<Either<Failure, TournamentEntity?>> call() {
    return repository.getHomeTournament();
  }
}
