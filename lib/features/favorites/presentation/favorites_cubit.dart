import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/repos/favorites_repo.dart';
import 'favorites_state.dart';

class FavoritesCubit extends Cubit<FavoritesState> {
  final FavoritesRepository _repository;

  FavoritesCubit(this._repository) : super(const FavoritesState());

  Future<void> getFavoriteIds() async {
    final result = await _repository.getFavoriteIds();
    result.fold(
      (failure) => null,
      (ids) => emit(state.copyWith(favoriteIds: ids)),
    );
  }

  Future<void> getFavoriteLounges() async {
    emit(state.copyWith(status: FavoritesStatus.loading));
    final result = await _repository.getFavorites();
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

  Future<void> toggleFavorite(String loungeId) async {
    final previousIds = List<String>.from(state.favoriteIds);
    final isFavorite = previousIds.contains(loungeId);
    
    final updatedIds = List<String>.from(previousIds);
    if (isFavorite) {
      updatedIds.remove(loungeId);
    } else {
      updatedIds.add(loungeId);
    }
    emit(state.copyWith(favoriteIds: updatedIds));

    final result = isFavorite 
        ? await _repository.removeFavorite(loungeId)
        : await _repository.addFavorite(loungeId);

    result.fold(
      (failure) {
        emit(state.copyWith(favoriteIds: previousIds));
      },
      (_) {
        if (state.status == FavoritesStatus.success) {
           getFavoriteLounges();
        }
      },
    );
  }

  bool isFavorite(String loungeId) => state.favoriteIds.contains(loungeId);
}
