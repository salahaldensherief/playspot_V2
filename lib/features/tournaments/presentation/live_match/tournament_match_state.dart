import 'dart:io';
import 'package:equatable/equatable.dart';
import '../../domain/entities/tournament_entity.dart';

enum MatchScreenStatus { initial, loading, success, failure }

class TournamentMatchState extends Equatable {
  final MatchScreenStatus status;
  final TournamentMatchEntity? match;
  final int player1Score;
  final int player2Score;
  final File? proofFile;
  final bool isSubmittingResult;
  final bool isConfirmingResult;
  final bool isSubmittingDispute;
  final String? errorMessage;
  final String? successMessage;

  const TournamentMatchState({
    this.status = MatchScreenStatus.initial,
    this.match,
    this.player1Score = 0,
    this.player2Score = 0,
    this.proofFile,
    this.isSubmittingResult = false,
    this.isConfirmingResult = false,
    this.isSubmittingDispute = false,
    this.errorMessage,
    this.successMessage,
  });

  TournamentMatchState copyWith({
    MatchScreenStatus? status,
    TournamentMatchEntity? match,
    int? player1Score,
    int? player2Score,
    File? proofFile,
    bool? isSubmittingResult,
    bool? isConfirmingResult,
    bool? isSubmittingDispute,
    String? errorMessage,
    String? successMessage,
  }) {
    return TournamentMatchState(
      status: status ?? this.status,
      match: match ?? this.match,
      player1Score: player1Score ?? this.player1Score,
      player2Score: player2Score ?? this.player2Score,
      proofFile: proofFile ?? this.proofFile,
      isSubmittingResult: isSubmittingResult ?? this.isSubmittingResult,
      isConfirmingResult: isConfirmingResult ?? this.isConfirmingResult,
      isSubmittingDispute: isSubmittingDispute ?? this.isSubmittingDispute,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        match,
        player1Score,
        player2Score,
        proofFile,
        isSubmittingResult,
        isConfirmingResult,
        isSubmittingDispute,
        errorMessage,
        successMessage,
      ];
}
