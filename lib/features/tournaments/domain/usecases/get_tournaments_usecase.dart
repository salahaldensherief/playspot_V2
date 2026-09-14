import 'package:dartz/dartz.dart';
import 'package:playspot/core/error/failures.dart';
import '../entities/tournament_entity.dart';
import '../repositories/tournaments_repository.dart';

class GetTournamentsUseCase {
  final TournamentsRepository repository;

  GetTournamentsUseCase(this.repository);

  Future<Either<Failure, List<TournamentEntity>>> call({
    String? game,
    String? cityId,
    String? statusFilter,
    String? searchQuery,
    double? latitude,
    double? longitude,
  }) {
    return repository.getTournaments(
      game: game,
      cityId: cityId,
      statusFilter: statusFilter,
      searchQuery: searchQuery,
      latitude: latitude,
      longitude: longitude,
    );
  }
}
