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

    final coreFutures = await Future.wait([
      _getTournamentDetailsUseCase.getTournamentById(tournamentId),
      _getTournamentDetailsUseCase.getPrizes(tournamentId),
      _getTournamentDetailsUseCase.getMatches(tournamentId),
    ]);

    final tournamentRes = coreFutures[0] as Either<Failure, TournamentEntity>;
    final prizesRes = coreFutures[1] as Either<Failure, List<TournamentPrizeEntity>>;
    final matchesRes = coreFutures[2] as Either<Failure, List<TournamentMatchEntity>>;

    // Only fetch participant if the user is authenticated.
    TournamentParticipantEntity? participant;
    if (currentUserId != null) {
      final participantRes = await _getTournamentDetailsUseCase.getUserParticipant(
        tournamentId,
        currentUserId,
      );
      participant = participantRes.fold((_) => null, (p) => p);
    }

    tournamentRes.fold(
      (failure) => emit(state.copyWith(
        status: TournamentDetailsStatus.failure,
        errorMessage: failure.message,
      )),
      (tournament) {
        prizesRes.fold((_) {}, (prizes) {
          matchesRes.fold((_) {}, (matches) {
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
    final tournament = state.tournament;
    if (tournament == null || state.isRegistering) return;

    emit(state.copyWith(isRegistering: true));

    final result = await _registerTournamentUseCase(tournament.id);

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
    final tournament = state.tournament;
    final userParticipant = state.userParticipant;
    if (tournament == null || userParticipant == null) return;

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    // Check if participant is already payment_submitted or paid
    if (userParticipant.paymentStatus == PaymentStatus.pending ||
        userParticipant.paymentStatus == PaymentStatus.approved ||
        userParticipant.status == ParticipantStatus.confirmed) {
      emit(state.copyWith(
        isSubmittingPayment: false,
        successMessage: 'paymentSubmittedSuccess',
      ));
      return;
    }

    // Server status re-check to handle previous timeout recovery
    try {
      final participantRes = await _getTournamentDetailsUseCase.getUserParticipant(
        tournament.id,
        currentUser.id,
      );
      final latestParticipant = participantRes.fold((_) => null, (p) => p);
      if (latestParticipant != null) {
        if (latestParticipant.paymentStatus == PaymentStatus.pending ||
            latestParticipant.paymentStatus == PaymentStatus.approved ||
            latestParticipant.status == ParticipantStatus.confirmed) {
          emit(state.copyWith(
            isSubmittingPayment: false,
            userParticipant: latestParticipant,
            successMessage: 'paymentSubmittedSuccess',
          ));
          return;
        }
      }
    } catch (_) {}

    emit(state.copyWith(isSubmittingPayment: true));

    try {
      final result = await _submitTournamentPaymentUseCase(
        participantId: userParticipant.id,
        tournamentId: tournament.id,
        userId: currentUser.id,
        amount: tournament.entryFee,
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
    final userParticipant = state.userParticipant;
    if (userParticipant == null || !state.canCheckIn) return;

    emit(state.copyWith(isCheckingIn: true));

    final result = await _checkInParticipantUseCase(userParticipant.id);

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
    final userParticipant = state.userParticipant;
    if (userParticipant == null || state.isWithdrawing) return;

    emit(state.copyWith(isWithdrawing: true));

    final result = await _withdrawTournamentUseCase(
      userParticipant.id,
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
