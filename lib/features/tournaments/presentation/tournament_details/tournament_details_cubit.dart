import 'dart:async';
import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/tournament_entity.dart';
import '../../domain/usecases/check_in_participant_usecase.dart';
import '../../domain/usecases/get_tournament_details_usecase.dart';
import '../../domain/usecases/register_tournament_usecase.dart';
import '../../domain/usecases/submit_tournament_payment_usecase.dart';
import '../../domain/usecases/watch_tournament_matches_usecase.dart';
import '../../domain/usecases/withdraw_tournament_usecase.dart';
import 'tournament_details_state.dart';

class TournamentDetailsCubit extends Cubit<TournamentDetailsState> {
  final GetTournamentDetailsUseCase _getTournamentDetailsUseCase;
  final RegisterTournamentUseCase _registerTournamentUseCase;
  final SubmitTournamentPaymentUseCase _submitTournamentPaymentUseCase;
  final CheckInParticipantUseCase _checkInParticipantUseCase;
  final WatchTournamentMatchesUseCase _watchTournamentMatchesUseCase;
  final WithdrawTournamentUseCase _withdrawTournamentUseCase;

  StreamSubscription? _matchesSubscription;
  String? _activeTournamentId;

  TournamentDetailsCubit(
    this._getTournamentDetailsUseCase,
    this._registerTournamentUseCase,
    this._submitTournamentPaymentUseCase,
    this._checkInParticipantUseCase,
    this._watchTournamentMatchesUseCase,
    this._withdrawTournamentUseCase,
  ) : super(const TournamentDetailsState());

  @override
  Future<void> close() {
    _matchesSubscription?.cancel();
    return super.close();
  }

  Future<void> init(String tournamentId) async {
    _activeTournamentId = tournamentId;
    emit(state.copyWith(status: TournamentDetailsStatus.loading));

    final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? 'demo_user';

    final results = await Future.wait([
      _getTournamentDetailsUseCase.getTournamentById(tournamentId),
      _getTournamentDetailsUseCase.getPrizes(tournamentId),
      _getTournamentDetailsUseCase.getMatches(tournamentId),
      _getTournamentDetailsUseCase.getUserParticipant(tournamentId, currentUserId),
    ]);

    final tournamentRes = results[0] as Either<Failure, TournamentEntity>;
    final prizesRes = results[1] as Either<Failure, List<TournamentPrizeEntity>>;
    final matchesRes = results[2] as Either<Failure, List<TournamentMatchEntity>>;
    final participantRes = results[3] as Either<Failure, TournamentParticipantEntity?>;

    tournamentRes.fold(
      (failure) => emit(state.copyWith(
        status: TournamentDetailsStatus.failure,
        errorMessage: failure.message,
      )),
      (tournament) {
        prizesRes.fold((_) {}, (prizes) {
          matchesRes.fold((_) {}, (matches) {
            final participant = participantRes.fold((_) => null, (p) => p);

            emit(state.copyWith(
              status: TournamentDetailsStatus.success,
              tournament: tournament,
              prizes: prizes,
              matches: matches,
              userParticipant: participant,
            ));

            _startWatchingMatches(tournamentId);
          });
        });
      },
    );
  }

  void _startWatchingMatches(String tournamentId) {
    _matchesSubscription?.cancel();
    _matchesSubscription = _watchTournamentMatchesUseCase(tournamentId).listen(
      (updatedMatches) {
        if (!isClosed) {
          emit(state.copyWith(matches: updatedMatches));
        }
      },
      onError: (err) {},
    );
  }

  Future<void> registerForTournament() async {
    if (state.tournament == null || state.isRegistering) return;

    emit(state.copyWith(isRegistering: true));

    final result = await _registerTournamentUseCase(state.tournament!.id);

    result.fold(
      (failure) {
        emit(state.copyWith(
          isRegistering: false,
          errorMessage: failure.message,
        ));
      },
      (participant) {
        emit(state.copyWith(
          isRegistering: false,
          userParticipant: participant ?? state.userParticipant,
          successMessage: 'registeredSuccessfully',
        ));
      },
    );
  }

  Future<void> submitPayment({
    required String paymentMethod,
    required File receiptFile,
  }) async {
    if (state.tournament == null || state.userParticipant == null) return;

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    emit(state.copyWith(isSubmittingPayment: true));

    try {
      final result = await _submitTournamentPaymentUseCase(
        participantId: state.userParticipant!.id,
        tournamentId: state.tournament!.id,
        userId: currentUser.id,
        amount: state.tournament!.entryFee,
        paymentMethod: paymentMethod,
        receiptFile: receiptFile,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => Left(ServerFailure('Connection timed out while uploading receipt. Please try again.')),
      );

      result.fold(
        (failure) {
          emit(state.copyWith(
            isSubmittingPayment: false,
            errorMessage: failure.message,
          ));
        },
        (participant) {
          emit(state.copyWith(
            isSubmittingPayment: false,
            userParticipant: participant ?? state.userParticipant,
            successMessage: 'paymentSubmittedSuccess',
          ));
        },
      );
    } catch (_) {
      emit(state.copyWith(
        isSubmittingPayment: false,
        errorMessage: 'Connection timed out while uploading receipt. Please check your network and try again.',
      ));
    }
  }

  Future<void> checkIn() async {
    if (state.userParticipant == null || !state.canCheckIn) return;

    emit(state.copyWith(isCheckingIn: true));

    final result = await _checkInParticipantUseCase(state.userParticipant!.id);

    result.fold(
      (failure) {
        emit(state.copyWith(
          isCheckingIn: false,
          errorMessage: failure.message,
        ));
      },
      (participant) {
        emit(state.copyWith(
          isCheckingIn: false,
          userParticipant: participant ?? state.userParticipant,
          successMessage: 'checkInSuccess',
        ));
      },
    );
  }

  Future<void> withdrawFromTournament() async {
    if (state.userParticipant == null || state.isWithdrawing) return;

    emit(state.copyWith(isWithdrawing: true));

    final result = await _withdrawTournamentUseCase(
      state.userParticipant!.id,
      tournamentId: state.tournament?.id ?? _activeTournamentId,
    );

    result.fold(
      (failure) {
        emit(state.copyWith(
          isWithdrawing: false,
          errorMessage: failure.message,
        ));
      },
      (participant) {
        emit(state.copyWith(
          isWithdrawing: false,
          userParticipant: participant ?? state.userParticipant,
          successMessage: 'withdrawSuccess',
        ));
      },
    );
  }
}
