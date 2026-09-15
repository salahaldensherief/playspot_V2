import 'package:equatable/equatable.dart';
import '../../domain/entities/user_tournament_participation_entity.dart';

enum TournamentHistoryStatus { initial, loading, success, failure }

class TournamentHistoryState extends Equatable {
  final TournamentHistoryStatus status;
  final List<UserTournamentParticipationEntity> participations;
  final String? errorMessage;

  const TournamentHistoryState({
    this.status = TournamentHistoryStatus.initial,
    this.participations = const [],
    this.errorMessage,
  });

  TournamentHistoryState copyWith({
    TournamentHistoryStatus? status,
    List<UserTournamentParticipationEntity>? participations,
    String? errorMessage,
  }) {
    return TournamentHistoryState(
      status: status ?? this.status,
      participations: participations ?? this.participations,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, participations, errorMessage];
}
