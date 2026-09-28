import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:playspot/core/error/failures.dart';
import '../repositories/tournaments_repository.dart';

class SubmitMatchResultUseCase {
  final TournamentsRepository repository;

  SubmitMatchResultUseCase(this.repository);

  Future<Either<Failure, void>> call({
    required String matchId,
    required String tournamentId,
    required int player1Score,
    required int player2Score,
    File? proofFile,
  }) {
    return repository.submitMatchResult(
      matchId: matchId,
      tournamentId: tournamentId,
      player1Score: player1Score,
      player2Score: player2Score,
      proofFile: proofFile,
    );
  }
}
