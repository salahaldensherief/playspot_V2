import 'package:equatable/equatable.dart';
import '../../domain/entities/tournament_entity.dart';

enum TournamentsFeedStatus { initial, loading, success, failure }

const _unchangedFilter = Object();

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
    Object? selectedGame = _unchangedFilter,
    Object? selectedCityId = _unchangedFilter,
    Object? selectedStatus = _unchangedFilter,
    String? searchQuery,
    bool? isLocationDisabled,
    String? errorMessage,
  }) {
    return TournamentsFeedState(
      status: status ?? this.status,
      tournaments: tournaments ?? this.tournaments,
      availableGames: availableGames ?? this.availableGames,
      selectedGame: identical(selectedGame, _unchangedFilter)
          ? this.selectedGame
          : selectedGame as String?,
      selectedCityId: identical(selectedCityId, _unchangedFilter)
          ? this.selectedCityId
          : selectedCityId as String?,
      selectedStatus: identical(selectedStatus, _unchangedFilter)
          ? this.selectedStatus
          : selectedStatus as String?,
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
