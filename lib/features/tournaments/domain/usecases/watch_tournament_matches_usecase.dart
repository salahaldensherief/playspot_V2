import '../entities/tournament_entity.dart';
import '../repositories/tournaments_repository.dart';

class WatchTournamentMatchesUseCase {
  final TournamentsRepository repository;

  WatchTournamentMatchesUseCase(this.repository);

  Stream<List<TournamentMatchEntity>> call(String tournamentId) {
    return repository.watchTournamentMatches(tournamentId);
  }
}
