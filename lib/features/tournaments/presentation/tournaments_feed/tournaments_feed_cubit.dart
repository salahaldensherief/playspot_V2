import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/tournaments_repository.dart';
import 'tournaments_feed_state.dart';

class TournamentsFeedCubit extends Cubit<TournamentsFeedState> {
  final TournamentsRepository _repository;
  Timer? _debounceTimer;

  TournamentsFeedCubit(this._repository) : super(const TournamentsFeedState());

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    return super.close();
  }

  Future<void> loadTournaments({bool isRefresh = false}) async {
    if (!isRefresh && state.status == TournamentsFeedStatus.loading) return;

    emit(state.copyWith(status: TournamentsFeedStatus.loading, errorMessage: null));

    final result = await _repository.getTournaments(
      game: state.selectedGame,
      cityId: state.selectedCityId,
      statusFilter: state.selectedStatus,
      searchQuery: state.searchQuery,
    );

    result.fold(
      (failure) {
        emit(state.copyWith(
          status: TournamentsFeedStatus.failure,
          errorMessage: failure.message,
        ));
      },
      (tournaments) {
        emit(state.copyWith(
          status: TournamentsFeedStatus.success,
          tournaments: tournaments,
        ));
      },
    );
  }

  void onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      emit(state.copyWith(searchQuery: query));
      loadTournaments(isRefresh: true);
    });
  }

  void filterByGame(String? game) {
    if (state.selectedGame == game) return;
    emit(state.copyWith(selectedGame: game));
    loadTournaments(isRefresh: true);
  }

  void filterByCity(String? cityId) {
    if (state.selectedCityId == cityId) return;
    emit(state.copyWith(selectedCityId: cityId));
    loadTournaments(isRefresh: true);
  }

  void filterByStatus(String? status) {
    if (state.selectedStatus == status) return;
    emit(state.copyWith(selectedStatus: status));
    loadTournaments(isRefresh: true);
  }
}
