import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/tournament_entity.dart';
import '../../domain/repositories/tournaments_repository.dart';
import 'tournament_match_state.dart';

class TournamentMatchCubit extends Cubit<TournamentMatchState> {
  final TournamentsRepository _repository;

  TournamentMatchCubit(this._repository) : super(const TournamentMatchState());

  Future<void> loadMatch({required String tournamentId, required String matchId}) async {
    emit(state.copyWith(status: MatchScreenStatus.loading));

    final result = await _repository.getTournamentMatches(tournamentId);

    result.fold(
      (failure) {
        emit(state.copyWith(
          status: MatchScreenStatus.failure,
          errorMessage: failure.message,
        ));
      },
      (matches) {
        if (matches.isEmpty) {
          emit(state.copyWith(
            status: MatchScreenStatus.failure,
            errorMessage: 'No matches found',
          ));
          return;
        }

        final List<TournamentMatchEntity> safeMatches = List<TournamentMatchEntity>.from(matches);
        final match = safeMatches.firstWhere(
          (m) => m.id == matchId,
          orElse: () => safeMatches.first,
        );

        emit(state.copyWith(
          status: MatchScreenStatus.success,
          match: match,
          player1Score: match.player1Score ?? 0,
          player2Score: match.player2Score ?? 0,
        ));
      },
    );
  }

  void updatePlayer1Score(int score) {
    emit(state.copyWith(player1Score: score < 0 ? 0 : score));
  }

  void updatePlayer2Score(int score) {
    emit(state.copyWith(player2Score: score < 0 ? 0 : score));
  }

  void setProofFile(File? file) {
    emit(state.copyWith(proofFile: file));
  }

  Future<void> submitResult() async {
    if (state.match == null || state.isSubmittingResult) return;

    emit(state.copyWith(isSubmittingResult: true));

    final result = await _repository.submitMatchResult(
      matchId: state.match!.id,
      tournamentId: state.match!.tournamentId,
      player1Score: state.player1Score,
      player2Score: state.player2Score,
      proofFile: state.proofFile,
    );

    result.fold(
      (failure) {
        emit(state.copyWith(
          isSubmittingResult: false,
          errorMessage: failure.message,
        ));
      },
      (_) {
        emit(state.copyWith(
          isSubmittingResult: false,
          successMessage: 'resultSubmittedSuccess',
        ));
        loadMatch(
          tournamentId: state.match!.tournamentId,
          matchId: state.match!.id,
        );
      },
    );
  }

  Future<void> confirmResult() async {
    if (state.match == null || state.isConfirmingResult) return;

    emit(state.copyWith(isConfirmingResult: true));

    final result = await _repository.confirmMatchResult(state.match!.id);

    result.fold(
      (failure) {
        emit(state.copyWith(
          isConfirmingResult: false,
          errorMessage: failure.message,
        ));
      },
      (_) {
        emit(state.copyWith(
          isConfirmingResult: false,
          successMessage: 'resultConfirmedSuccess',
        ));
        loadMatch(
          tournamentId: state.match!.tournamentId,
          matchId: state.match!.id,
        );
      },
    );
  }

  Future<void> disputeResult(String reason) async {
    if (state.match == null || state.isSubmittingDispute || reason.trim().isEmpty) return;

    emit(state.copyWith(isSubmittingDispute: true));

    final result = await _repository.disputeMatchResult(
      matchId: state.match!.id,
      disputeReason: reason.trim(),
    );

    result.fold(
      (failure) {
        emit(state.copyWith(
          isSubmittingDispute: false,
          errorMessage: failure.message,
        ));
      },
      (_) {
        emit(state.copyWith(
          isSubmittingDispute: false,
          successMessage: 'disputeSubmittedSuccess',
        ));
        loadMatch(
          tournamentId: state.match!.tournamentId,
          matchId: state.match!.id,
        );
      },
    );
  }
}
