import '../../domain/entities/user_tournament_participation_entity.dart';
import 'tournament_model.dart';

class UserTournamentParticipationModel extends UserTournamentParticipationEntity {
  const UserTournamentParticipationModel({
    required super.participant,
    super.tournament,
  });

  factory UserTournamentParticipationModel.fromJson(Map<String, dynamic> json) {
    final participant = TournamentParticipantModel.fromJson(json);
    final tournamentJson = json['tournaments'] as Map<String, dynamic>?;
    final tournament = tournamentJson != null ? TournamentModel.fromJson(tournamentJson) : null;

    return UserTournamentParticipationModel(
      participant: participant,
      tournament: tournament,
    );
  }
}
