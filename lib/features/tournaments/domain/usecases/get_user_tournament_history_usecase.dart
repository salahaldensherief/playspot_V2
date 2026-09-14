import 'package:dartz/dartz.dart';
import 'package:playspot/core/error/failures.dart';
import '../repositories/tournaments_repository.dart';

class GetUserTournamentHistoryUseCase {
  final TournamentsRepository repository;

  GetUserTournamentHistoryUseCase(this.repository);

  Future<Either<Failure, List<Map<String, dynamic>>>> call(String userId) {
    return repository.getUserTournamentHistory(userId);
  }
}
