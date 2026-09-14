import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:playspot/core/services/location_service.dart';
import 'package:playspot/features/profile/domain/repositories/profile_repository.dart';
import '../../domain/usecases/get_tournaments_usecase.dart';
import 'tournaments_feed_state.dart';

class TournamentsFeedCubit extends Cubit<TournamentsFeedState> {
  final GetTournamentsUseCase _getTournamentsUseCase;
  final LocationService _locationService;
  final ProfileRepository? _profileRepository;
  Timer? _debounceTimer;

  TournamentsFeedCubit(
    this._getTournamentsUseCase,
    this._locationService, [
    this._profileRepository,
  ]) : super(const TournamentsFeedState());

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    return super.close();
  }

  Future<void> loadTournaments({bool isRefresh = false}) async {
    if (!isRefresh && state.status == TournamentsFeedStatus.loading) return;

    emit(state.copyWith(status: TournamentsFeedStatus.loading, errorMessage: null));

    Position? position;
    try {
      position = await _locationService.getCurrentLocation();
    } catch (_) {}

    final bool locationDisabled = position == null;
    final String? userCityId = _profileRepository?.getCurrentUser()?.cityId;
    final String? effectiveCity = state.selectedCityId ?? (locationDisabled ? userCityId : null);

    final result = await _getTournamentsUseCase(
      game: state.selectedGame,
      cityId: effectiveCity,
      statusFilter: state.selectedStatus,
      searchQuery: state.searchQuery,
      latitude: position?.latitude,
      longitude: position?.longitude,
    );

    result.fold(
      (failure) {
        emit(state.copyWith(
          status: TournamentsFeedStatus.failure,
          isLocationDisabled: locationDisabled,
          errorMessage: failure.message,
        ));
      },
      (tournaments) {
        emit(state.copyWith(
          status: TournamentsFeedStatus.success,
          isLocationDisabled: locationDisabled,
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
