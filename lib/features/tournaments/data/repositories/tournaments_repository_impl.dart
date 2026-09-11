import 'dart:io';
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/repository_helper.dart';
import '../../domain/entities/tournament_entity.dart';
import '../../domain/repositories/tournaments_repository.dart';
import '../datasources/remote/tournaments_remote_data_source.dart';

class TournamentsRepositoryImpl with RepositoryHelper implements TournamentsRepository {
  final TournamentsRemoteDataSource _remoteDataSource;

  TournamentsRepositoryImpl(this._remoteDataSource);

  @override
  Future<Either<Failure, List<TournamentEntity>>> getTournaments({
    String? game,
    String? cityId,
    String? statusFilter,
    String? searchQuery,
  }) {
    return callRepository(() => _remoteDataSource.getTournaments(
          game: game,
          cityId: cityId,
          statusFilter: statusFilter,
          searchQuery: searchQuery,
        ));
  }

  @override
  Future<Either<Failure, TournamentEntity>> getTournamentById(String tournamentId) {
    return callRepository(() => _remoteDataSource.getTournamentById(tournamentId));
  }

  @override
  Future<Either<Failure, List<TournamentPrizeEntity>>> getTournamentPrizes(String tournamentId) {
    return callRepository(() => _remoteDataSource.getTournamentPrizes(tournamentId));
  }

  @override
  Future<Either<Failure, List<TournamentMatchEntity>>> getTournamentMatches(String tournamentId) {
    return callRepository(() => _remoteDataSource.getTournamentMatches(tournamentId));
  }

  @override
  Future<Either<Failure, TournamentParticipantEntity?>> getUserParticipant(
    String tournamentId,
    String userId,
  ) {
    return callRepository(() => _remoteDataSource.getUserParticipant(tournamentId, userId));
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> registerForTournament(String tournamentId) {
    return callRepository(() => _remoteDataSource.registerForTournament(tournamentId));
  }

  @override
  Future<Either<Failure, void>> submitTournamentPayment({
    required String participantId,
    required String tournamentId,
    required String userId,
    required double amount,
    required String paymentMethod,
    required File receiptFile,
  }) {
    return callRepository(() => _remoteDataSource.submitTournamentPayment(
          participantId: participantId,
          tournamentId: tournamentId,
          userId: userId,
          amount: amount,
          paymentMethod: paymentMethod,
          receiptFile: receiptFile,
        ));
  }

  @override
  Future<Either<Failure, void>> checkInParticipant(String participantId) {
    return callRepository(() => _remoteDataSource.checkInParticipant(participantId));
  }

  @override
  Future<Either<Failure, void>> submitMatchResult({
    required String matchId,
    required String tournamentId,
    required int player1Score,
    required int player2Score,
    File? proofFile,
  }) {
    return callRepository(() => _remoteDataSource.submitMatchResult(
          matchId: matchId,
          tournamentId: tournamentId,
          player1Score: player1Score,
          player2Score: player2Score,
          proofFile: proofFile,
        ));
  }

  @override
  Future<Either<Failure, void>> confirmMatchResult(String matchId) {
    return callRepository(() => _remoteDataSource.confirmMatchResult(matchId));
  }

  @override
  Future<Either<Failure, void>> disputeMatchResult({
    required String matchId,
    required String disputeReason,
  }) {
    return callRepository(() => _remoteDataSource.disputeMatchResult(
          matchId: matchId,
          disputeReason: disputeReason,
        ));
  }

  @override
  Stream<List<TournamentMatchEntity>> watchTournamentMatches(String tournamentId) {
    return _remoteDataSource.watchTournamentMatches(tournamentId);
  }

  @override
  Future<void> updateFcmToken(String token) {
    return _remoteDataSource.updateFcmToken(token);
  }
}
