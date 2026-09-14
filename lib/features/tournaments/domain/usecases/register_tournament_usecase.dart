import 'package:dartz/dartz.dart';
import 'package:playspot/core/error/failures.dart';
import '../repositories/tournaments_repository.dart';

class RegisterTournamentUseCase {
  final TournamentsRepository repository;

  RegisterTournamentUseCase(this.repository);

  Future<Either<Failure, Map<String, dynamic>>> call(String tournamentId) {
    return repository.registerForTournament(tournamentId);
  }
}
