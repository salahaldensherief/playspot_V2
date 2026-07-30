import 'dart:developer';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/repos/favorites_repo.dart';
import 'favorites_state.dart';

class FavoritesCubit extends Cubit<FavoritesState> {
  final FavoritesRepository _repository;

  FavoritesCubit(this._repository) : super(const FavoritesState());

  Future<void> getFavoriteIds() async {
    log("FAVORITES_CUBIT: Fetching favorite IDs...");
    final result = await _repository.getFavoriteIds();
    result.fold(
      (failure) => log("FAVORITES_CUBIT: Failed to fetch IDs: ${failure.message}"),
      (ids) {
        log("FAVORITES_CUBIT: Successfully fetched ${ids.length} IDs: $ids");
        emit(state.copyWith(favoriteIds: ids));
      },
    );
  }

  Future<void> getFavoriteLounges() async {
    log("FAVORITES_CUBIT: Fetching full favorite lounges...");
    emit(state.copyWith(status: FavoritesStatus.loading));
    final result = await _repository.getFavorites();
    result.fold(
      (failure) {
        log("FAVORITES_CUBIT: Failed to fetch lounges: ${failure.message}");
        emit(state.copyWith(
          status: FavoritesStatus.failure,
          errorMessage: failure.message,
        ));
      },
      (lounges) {
        log("FAVORITES_CUBIT: Successfully fetched ${lounges.length} lounges");
        emit(state.copyWith(
          status: FavoritesStatus.success,
          favoriteLounges: lounges,
          favoriteIds: lounges.map((l) => l.id).toList(),
        ));
      },
    );
  }

  Future<void> toggleFavorite(String loungeId) async {
    final previousIds = List<String>.from(state.favoriteIds);
    final isFavorite = previousIds.contains(loungeId);
    log("FAVORITES_CUBIT: Toggling favorite for $loungeId. Current state: ${isFavorite ? 'Favorite' : 'Not Favorite'}");
    
    // Optimistic UI update
    final updatedIds = List<String>.from(previousIds);
    if (isFavorite) {
      updatedIds.remove(loungeId);
    } else {
      updatedIds.add(loungeId);
    }
    emit(state.copyWith(favoriteIds: updatedIds));
    log("FAVORITES_CUBIT: Optimistic update done. New IDs: $updatedIds");

    final result = isFavorite 
        ? await _repository.removeFavorite(loungeId)
        : await _repository.addFavorite(loungeId);

    result.fold(
      (failure) {
        log("FAVORITES_CUBIT: Toggle failed: ${failure.message}. Rolling back.");
        // Rollback to previous state on failure
        emit(state.copyWith(favoriteIds: previousIds));
      },
      (_) {
        log("FAVORITES_CUBIT: Toggle successful on server");
        // Refresh full list if we are currently displaying favorite lounges
        if (state.status == FavoritesStatus.success) {
           log("FAVORITES_CUBIT: Refreshing full list as we are in Success state");
           getFavoriteLounges();
        }
      },
    );
  }

  bool isFavorite(String loungeId) => state.favoriteIds.contains(loungeId);
}
