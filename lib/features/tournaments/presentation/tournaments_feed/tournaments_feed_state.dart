import 'package:equatable/equatable.dart';
import '../../domain/entities/tournament_entity.dart';

enum TournamentsFeedStatus { initial, loading, success, failure }

class TournamentsFeedState extends Equatable {
  final TournamentsFeedStatus status;
  final List<TournamentEntity> tournaments;
  final String? selectedGame;
  final String? selectedCityId;
  final String? selectedStatus;
  final String searchQuery;
  final String? errorMessage;

  const TournamentsFeedState({
    this.status = TournamentsFeedStatus.initial,
    this.tournaments = const [],
    this.selectedGame,
    this.selectedCityId,
    this.selectedStatus,
    this.searchQuery = '',
    this.errorMessage,
  });

  TournamentsFeedState copyWith({
    TournamentsFeedStatus? status,
    List<TournamentEntity>? tournaments,
    String? selectedGame,
    String? selectedCityId,
    String? selectedStatus,
    String? searchQuery,
    String? errorMessage,
  }) {
    return TournamentsFeedState(
      status: status ?? this.status,
      tournaments: tournaments ?? this.tournaments,
      selectedGame: selectedGame ?? this.selectedGame,
      selectedCityId: selectedCityId ?? this.selectedCityId,
      selectedStatus: selectedStatus ?? this.selectedStatus,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        tournaments,
        selectedGame,
        selectedCityId,
        selectedStatus,
        searchQuery,
        errorMessage,
      ];
}
