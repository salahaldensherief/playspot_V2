import 'dart:io';
import 'package:equatable/equatable.dart';
import '../../domain/entities/tournament_entity.dart';

/// Parameters for querying the tournaments feed
class FetchTournamentsParams extends Equatable {
  final String? game;
  final String? cityId;
  final String? statusFilter;
  final String? searchQuery;

  const FetchTournamentsParams({
    this.game,
    this.cityId,
    this.statusFilter,
    this.searchQuery,
  });

  @override
  List<Object?> get props => [game, cityId, statusFilter, searchQuery];
}

/// Parameters for registering a user for a tournament
class RegisterTournamentParams extends Equatable {
  final String tournamentId;

  const RegisterTournamentParams({required this.tournamentId});

  @override
  List<Object?> get props => [tournamentId];
}

/// Parameters for submitting payment receipts
class SubmitTournamentPaymentParams extends Equatable {
  final String participantId;
  final String tournamentId;
  final String userId;
  final double amount;
  final String paymentMethod;
  final File receiptFile;

  const SubmitTournamentPaymentParams({
    required this.participantId,
    required this.tournamentId,
    required this.userId,
    required this.amount,
    required this.paymentMethod,
    required this.receiptFile,
  });

  @override
  List<Object?> get props => [
        participantId,
        tournamentId,
        userId,
        amount,
        paymentMethod,
        receiptFile,
      ];
}

/// Parameters for submitting match score and proof
class SubmitMatchResultParams extends Equatable {
  final String matchId;
  final String tournamentId;
  final int player1Score;
  final int player2Score;
  final File? proofFile;

  const SubmitMatchResultParams({
    required this.matchId,
    required this.tournamentId,
    required this.player1Score,
    required this.player2Score,
    this.proofFile,
  });

  @override
  List<Object?> get props => [
        matchId,
        tournamentId,
        player1Score,
        player2Score,
        proofFile,
      ];
}

/// Parameters for disputing a match result
class DisputeMatchResultParams extends Equatable {
  final String matchId;
  final String disputeReason;

  const DisputeMatchResultParams({
    required this.matchId,
    required this.disputeReason,
  });

  @override
  List<Object?> get props => [matchId, disputeReason];
}

/// Navigation parameters for Tournament Details
class TournamentDetailsNavParams extends Equatable {
  final String tournamentId;
  final TournamentEntity? tournament;

  const TournamentDetailsNavParams({
    required this.tournamentId,
    this.tournament,
  });

  @override
  List<Object?> get props => [tournamentId, tournament];

  factory TournamentDetailsNavParams.fromMap(Map<String, dynamic> map) {
    return TournamentDetailsNavParams(
      tournamentId: map['tournamentId']?.toString() ?? '',
      tournament: map['tournament'] as TournamentEntity?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tournamentId': tournamentId,
      'tournament': tournament,
    };
  }
}

/// Navigation parameters for Live Match Details
class TournamentMatchNavParams extends Equatable {
  final String tournamentId;
  final String matchId;
  final TournamentMatchEntity? match;

  const TournamentMatchNavParams({
    required this.tournamentId,
    required this.matchId,
    this.match,
  });

  @override
  List<Object?> get props => [tournamentId, matchId, match];

  factory TournamentMatchNavParams.fromMap(Map<String, dynamic> map) {
    return TournamentMatchNavParams(
      tournamentId: map['tournamentId']?.toString() ?? '',
      matchId: map['matchId']?.toString() ?? '',
      match: map['match'] as TournamentMatchEntity?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tournamentId': tournamentId,
      'matchId': matchId,
      'match': match,
    };
  }
}
