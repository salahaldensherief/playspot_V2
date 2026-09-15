import 'package:equatable/equatable.dart';
import 'tournament_entity.dart';

class UserTournamentParticipationEntity extends Equatable {
  final TournamentParticipantEntity participant;
  final TournamentEntity? tournament;

  const UserTournamentParticipationEntity({
    required this.participant,
    this.tournament,
  });

  @override
  List<Object?> get props => [participant, tournament];
}
