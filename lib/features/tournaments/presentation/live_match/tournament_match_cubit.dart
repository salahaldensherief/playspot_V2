import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:playspot/art_core/app_strings.dart';
import 'package:playspot/core/error/failures.dart';

import '../../domain/repositories/tournaments_repository.dart';
import '../../domain/usecases/get_tournament_details_usecase.dart';
import '../../domain/usecases/submit_match_result_usecase.dart';
import 'tournament_match_state.dart';

class TournamentMatchCubit extends Cubit<TournamentMatchState> {
  final TournamentsRepository _repository;
  final GetTournamentDetailsUseCase _getTournamentDetailsUseCase;
  final SubmitMatchResultUseCase _submitMatchResultUseCase;

  TournamentMatchCubit(
    this._repository,
    this._getTournamentDetailsUseCase,
    this._submitMatchResultUseCase,
  ) : super(const TournamentMatchState());

  Future<void> loadMatch({
    required String tournamentId,
    required String matchId,
  }) async {
    emit(state.copyWith(status: MatchScreenStatus.loading));

    final result = await _getTournamentDetailsUseCase.getMatchById(
      tournamentId,
      matchId,
    );

    result.fold(
      (failure) {
        emit(
          state.copyWith(
            status: MatchScreenStatus.failure,
            errorMessage: failure.message,
          ),
        );
      },
      (match) {
        if (match == null) {
          emit(
            state.copyWith(
              status: MatchScreenStatus.failure,
              errorMessage: 'No matches found',
            ),
          );
          return;
        }

        emit(
          state.copyWith(
            status: MatchScreenStatus.success,
            match: match,
            player1Score: match.player1Score ?? 0,
            player2Score: match.player2Score ?? 0,
          ),
        );
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

    if (state.player1Score == state.player2Score) {
      emit(
        state.copyWith(
          errorMessage: AppStrings.tieNotAllowedInTournaments.tr(),
        ),
      );
      return;
    }

    emit(state.copyWith(isSubmittingResult: true));

    try {
      final result =
          await _submitMatchResultUseCase(
            matchId: state.match!.id,
            tournamentId: state.match!.tournamentId,
            player1Score: state.player1Score,
            player2Score: state.player2Score,
            proofFile: state.proofFile,
          ).timeout(
            const Duration(seconds: 30),
            onTimeout: () => Left(
              ServerFailure(
                'Connection timed out while uploading proof file. Please try again.',
              ),
            ),
          );

      result.fold(
        (failure) {
          emit(
            state.copyWith(
              isSubmittingResult: false,
              errorMessage: failure.message,
            ),
          );
        },
        (_) {
          emit(
            state.copyWith(
              isSubmittingResult: false,
              successMessage: 'resultSubmittedSuccess',
            ),
          );
          loadMatch(
            tournamentId: state.match!.tournamentId,
            matchId: state.match!.id,
          );
        },
      );
    } catch (_) {
      emit(
        state.copyWith(
          isSubmittingResult: false,
          errorMessage:
              'Connection timed out while uploading match result. Please check your network and try again.',
        ),
      );
    }
  }

  Future<void> confirmResult() async {
    if (state.match == null || state.isConfirmingResult) return;

    emit(state.copyWith(isConfirmingResult: true));

    final result = await _repository.confirmMatchResult(state.match!.id);

    result.fold(
      (failure) {
        emit(
          state.copyWith(
            isConfirmingResult: false,
            errorMessage: failure.message,
          ),
        );
      },
      (_) {
        emit(
          state.copyWith(
            isConfirmingResult: false,
            successMessage: 'resultConfirmedSuccess',
          ),
        );
        loadMatch(
          tournamentId: state.match!.tournamentId,
          matchId: state.match!.id,
        );
      },
    );
  }

  Future<void> disputeResult(String reason) async {
    if (state.match == null ||
        state.isSubmittingDispute ||
        reason.trim().isEmpty)
      return;

    emit(state.copyWith(isSubmittingDispute: true));

    final result = await _repository.disputeMatchResult(
      matchId: state.match!.id,
      disputeReason: reason.trim(),
    );

    result.fold(
      (failure) {
        emit(
          state.copyWith(
            isSubmittingDispute: false,
            errorMessage: failure.message,
          ),
        );
      },
      (_) {
        emit(
          state.copyWith(
            isSubmittingDispute: false,
            successMessage: 'disputeSubmittedSuccess',
          ),
        );
        loadMatch(
          tournamentId: state.match!.tournamentId,
          matchId: state.match!.id,
        );
      },
    );
  }
}
