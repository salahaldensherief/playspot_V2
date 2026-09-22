import 'package:equatable/equatable.dart';
import '../../domain/entities/tournament_entity.dart';

enum TournamentsFeedStatus { initial, loading, success, failure }

class TournamentsFeedState extends Equatable {
  final TournamentsFeedStatus status;
  final List<TournamentEntity> tournaments;
  final List<String> availableGames;
  final String? selectedGame;
  final String? selectedCityId;
  final String? selectedStatus;
  final String searchQuery;
  final bool isLocationDisabled;
  final String? errorMessage;

  const TournamentsFeedState({
    this.status = TournamentsFeedStatus.initial,
    this.tournaments = const [],
    this.availableGames = const [],
    this.selectedGame,
    this.selectedCityId,
    this.selectedStatus,
    this.searchQuery = '',
    this.isLocationDisabled = false,
    this.errorMessage,
  });

  TournamentsFeedState copyWith({
    TournamentsFeedStatus? status,
    List<TournamentEntity>? tournaments,
    List<String>? availableGames,
    String? selectedGame,
    String? selectedCityId,
    String? selectedStatus,
    String? searchQuery,
    bool? isLocationDisabled,
    String? errorMessage,
  }) {
    return TournamentsFeedState(
      status: status ?? this.status,
      tournaments: tournaments ?? this.tournaments,
      availableGames: availableGames ?? this.availableGames,
      selectedGame: selectedGame ?? this.selectedGame,
      selectedCityId: selectedCityId ?? this.selectedCityId,
      selectedStatus: selectedStatus ?? this.selectedStatus,
      searchQuery: searchQuery ?? this.searchQuery,
      isLocationDisabled: isLocationDisabled ?? this.isLocationDisabled,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        tournaments,
        availableGames,
        selectedGame,
        selectedCityId,
        selectedStatus,
        searchQuery,
        isLocationDisabled,
        errorMessage,
      ];
}
