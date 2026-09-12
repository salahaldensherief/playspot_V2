import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:playspot/core/error/failures.dart';
import 'package:playspot/core/models/paginated_response.dart';
import 'package:playspot/features/tournaments/domain/entities/tournament_entity.dart';

abstract class TournamentsRepository {
  Future<Either<Failure, List<TournamentEntity>>> getTournaments({
    String? game,
    String? cityId,
    String? statusFilter,
    String? searchQuery,
  });

  Future<Either<Failure, TournamentEntity>> getTournamentById(String tournamentId);

  Future<Either<Failure, List<TournamentPrizeEntity>>> getTournamentPrizes(String tournamentId);

  Future<Either<Failure, List<TournamentMatchEntity>>> getTournamentMatches(String tournamentId);

  Future<Either<Failure, TournamentParticipantEntity?>> getUserParticipant(
    String tournamentId,
    String userId,
  );

  Future<Either<Failure, Map<String, dynamic>>> registerForTournament(String tournamentId);

  Future<Either<Failure, void>> submitTournamentPayment({
    required String participantId,
    required String tournamentId,
    required String userId,
    required double amount,
    required String paymentMethod,
    required File receiptFile,
  });

  Future<Either<Failure, void>> checkInParticipant(String participantId);

  Future<Either<Failure, void>> submitMatchResult({
    required String matchId,
    required String tournamentId,
    required int player1Score,
    required int player2Score,
    File? proofFile,
  });

  Future<Either<Failure, void>> confirmMatchResult(String matchId);

  Future<Either<Failure, void>> disputeMatchResult({
    required String matchId,
    required String disputeReason,
  });

  Stream<List<TournamentMatchEntity>> watchTournamentMatches(String tournamentId);

  Future<Either<Failure, PaginatedResponse<Map<String, dynamic>>>> getTournamentAuditLogsPage({
    required String tournamentId,
    int page = 1,
    int pageSize = 50,
  });

  Future<void> updateFcmToken(String token);
}
