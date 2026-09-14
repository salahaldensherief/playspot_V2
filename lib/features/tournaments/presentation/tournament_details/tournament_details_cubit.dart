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

    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    final results = await Future.wait([
      _getTournamentDetailsUseCase.getTournamentById(tournamentId),
      _getTournamentDetailsUseCase.getPrizes(tournamentId),
      _getTournamentDetailsUseCase.getMatches(tournamentId),
      if (currentUserId != null)
        _getTournamentDetailsUseCase.getUserParticipant(tournamentId, currentUserId)
      else
        Future.value(null),
    ]);

    final tournamentRes = results[0] as Either<Failure, TournamentEntity>;
    final prizesRes = results[1] as Either<Failure, List<TournamentPrizeEntity>>;
    final matchesRes = results[2] as Either<Failure, List<TournamentMatchEntity>>;
    final participantRes = results.length > 3
        ? results[3] as Either<Failure, TournamentParticipantEntity?>?
        : null;

    tournamentRes.fold(
      (failure) => emit(state.copyWith(
        status: TournamentDetailsStatus.failure,
        errorMessage: failure.message,
      )),
      (tournament) {
        prizesRes.fold((_) {}, (prizes) {
          matchesRes.fold((_) {}, (matches) {
            final participant = participantRes != null
                ? (participantRes.fold((_) => null, (p) => p))
                : null;

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
      (data) async {
        final currentUserId = Supabase.instance.client.auth.currentUser?.id;
        if (currentUserId != null && _activeTournamentId != null) {
          final pRes = await _getTournamentDetailsUseCase.getUserParticipant(_activeTournamentId!, currentUserId);
          pRes.fold((_) {}, (participant) {
            emit(state.copyWith(
              isRegistering: false,
              userParticipant: participant,
              successMessage: 'registeredSuccessfully',
            ));
          });
        } else {
          emit(state.copyWith(
            isRegistering: false,
            successMessage: 'registeredSuccessfully',
          ));
        }
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

    final result = await _submitTournamentPaymentUseCase(
      participantId: state.userParticipant!.id,
      tournamentId: state.tournament!.id,
      userId: currentUser.id,
      amount: state.tournament!.entryFee,
      paymentMethod: paymentMethod,
      receiptFile: receiptFile,
    );

    result.fold(
      (failure) {
        emit(state.copyWith(
          isSubmittingPayment: false,
          errorMessage: failure.message,
        ));
      },
      (_) async {
        if (_activeTournamentId != null) {
          final pRes = await _getTournamentDetailsUseCase.getUserParticipant(_activeTournamentId!, currentUser.id);
          pRes.fold((_) {}, (participant) {
            emit(state.copyWith(
              isSubmittingPayment: false,
              userParticipant: participant,
              successMessage: 'paymentSubmittedSuccess',
            ));
          });
        }
      },
    );
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
      (_) async {
        final currentUser = Supabase.instance.client.auth.currentUser;
        if (currentUser != null && _activeTournamentId != null) {
          final pRes = await _getTournamentDetailsUseCase.getUserParticipant(_activeTournamentId!, currentUser.id);
          pRes.fold((_) {}, (participant) {
            emit(state.copyWith(
              isCheckingIn: false,
              userParticipant: participant,
              successMessage: 'checkInSuccess',
            ));
          });
        }
      },
    );
  }

  Future<void> withdrawFromTournament() async {
    if (state.userParticipant == null || state.isWithdrawing) return;

    emit(state.copyWith(isWithdrawing: true));

    final result = await _withdrawTournamentUseCase(state.userParticipant!.id);

    result.fold(
      (failure) {
        emit(state.copyWith(
          isWithdrawing: false,
          errorMessage: failure.message,
        ));
      },
      (_) async {
        final currentUser = Supabase.instance.client.auth.currentUser;
        if (currentUser != null && _activeTournamentId != null) {
          final pRes = await _getTournamentDetailsUseCase.getUserParticipant(_activeTournamentId!, currentUser.id);
          pRes.fold((_) {}, (participant) {
            emit(state.copyWith(
              isWithdrawing: false,
              userParticipant: participant,
              successMessage: 'withdrawSuccess',
            ));
          });
        }
      },
    );
  }
}
