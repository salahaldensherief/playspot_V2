import 'package:equatable/equatable.dart';
import '../../domain/entities/tournament_entity.dart';

enum TournamentDetailsStatus { initial, loading, success, failure }

class TournamentDetailsState extends Equatable {
  final TournamentDetailsStatus status;
  final TournamentEntity? tournament;
  final TournamentParticipantEntity? userParticipant;
  final List<TournamentPrizeEntity> prizes;
  final List<TournamentMatchEntity> matches;
  final bool isRegistering;
  final bool isSubmittingPayment;
  final bool isCheckingIn;
  final String? errorMessage;
  final String? successMessage;

  const TournamentDetailsState({
    this.status = TournamentDetailsStatus.initial,
    this.tournament,
    this.userParticipant,
    this.prizes = const [],
    this.matches = const [],
    this.isRegistering = false,
    this.isSubmittingPayment = false,
    this.isCheckingIn = false,
    this.errorMessage,
    this.successMessage,
  });

  bool get canCheckIn {
    if (tournament == null || userParticipant == null) return false;
    return tournament!.status == TournamentStatus.checkInOpen &&
        userParticipant!.status == ParticipantStatus.confirmed &&
        userParticipant!.paymentStatus == PaymentStatus.paid &&
        !userParticipant!.checkedIn;
  }

  TournamentDetailsState copyWith({
    TournamentDetailsStatus? status,
    TournamentEntity? tournament,
    TournamentParticipantEntity? userParticipant,
    List<TournamentPrizeEntity>? prizes,
    List<TournamentMatchEntity>? matches,
    bool? isRegistering,
    bool? isSubmittingPayment,
    bool? isCheckingIn,
    String? errorMessage,
    String? successMessage,
  }) {
    return TournamentDetailsState(
      status: status ?? this.status,
      tournament: tournament ?? this.tournament,
      userParticipant: userParticipant ?? this.userParticipant,
      prizes: prizes ?? this.prizes,
      matches: matches ?? this.matches,
      isRegistering: isRegistering ?? this.isRegistering,
      isSubmittingPayment: isSubmittingPayment ?? this.isSubmittingPayment,
      isCheckingIn: isCheckingIn ?? this.isCheckingIn,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        tournament,
        userParticipant,
        prizes,
        matches,
        isRegistering,
        isSubmittingPayment,
        isCheckingIn,
        errorMessage,
        successMessage,
      ];
}
