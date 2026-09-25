import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/repositories/favorites_repository.dart';
import 'favorites_state.dart';

class FavoritesCubit extends Cubit<FavoritesState> {
  final FavoritesRepository _repository;

  FavoritesCubit(this._repository) : super(const FavoritesState()) {
    getFavoriteIds();
  }

  Future<void> getFavoriteIds() async {
    final result = await _repository.getFavoriteIds();
    if (isClosed) return;
    result.fold(
      (failure) => null,
      (ids) => emit(state.copyWith(favoriteIds: ids)),
    );
  }

  Future<void> getFavoriteLounges() async {
    if (!isClosed) emit(state.copyWith(status: FavoritesStatus.loading));
    final result = await _repository.getFavorites();
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(
        status: FavoritesStatus.failure,
        errorMessage: failure.message,
      )),
      (lounges) => emit(state.copyWith(
        status: FavoritesStatus.success,
        favoriteLounges: lounges,
        favoriteIds: lounges.map((l) => l.id).toList(),
      )),
    );
  }

  Future<void> toggleFavorite(String loungeId, [dynamic lounge]) async {
    final previousIds = List<String>.from(state.favoriteIds);
    final previousLounges = List<dynamic>.from(state.favoriteLounges);
    final isFavorite = previousIds.contains(loungeId);
    
    final updatedIds = List<String>.from(previousIds);
    final updatedLounges = List<dynamic>.from(previousLounges);

    if (isFavorite) {
      updatedIds.remove(loungeId);
      updatedLounges.removeWhere((l) => l.id == loungeId);
    } else {
      updatedIds.add(loungeId);
      if (lounge != null && !updatedLounges.any((l) => l.id == loungeId)) {
        updatedLounges.add(lounge);
      }
    }
    if (!isClosed) {
      emit(state.copyWith(
        favoriteIds: updatedIds,
        favoriteLounges: List.from(updatedLounges),
      ));
    }

    final result = isFavorite 
        ? await _repository.removeFavorite(loungeId)
        : await _repository.addFavorite(loungeId);

    if (isClosed) return;

    result.fold(
      (failure) {
        if (!isClosed) {
          emit(state.copyWith(
            favoriteIds: previousIds,
            favoriteLounges: List.from(previousLounges),
          ));
        }
      },
      (_) {
        if (!isClosed && state.status == FavoritesStatus.success) {
           getFavoriteLounges();
        }
      },
    );
  }

  bool isFavorite(String loungeId) => state.favoriteIds.contains(loungeId);
}
