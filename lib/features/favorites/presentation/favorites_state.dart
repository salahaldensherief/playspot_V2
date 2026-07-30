import 'package:equatable/equatable.dart';
import '../../home/data/models/lounge_model.dart';

enum FavoritesStatus { initial, loading, success, failure }

class FavoritesState extends Equatable {
  final List<String> favoriteIds;
  final List<LoungeModel> favoriteLounges;
  final FavoritesStatus status;
  final String? errorMessage;

  const FavoritesState({
    this.favoriteIds = const [],
    this.favoriteLounges = const [],
    this.status = FavoritesStatus.initial,
    this.errorMessage,
  });

  FavoritesState copyWith({
    List<String>? favoriteIds,
    List<LoungeModel>? favoriteLounges,
    FavoritesStatus? status,
    String? errorMessage,
  }) {
    return FavoritesState(
      favoriteIds: favoriteIds ?? this.favoriteIds,
      favoriteLounges: favoriteLounges ?? this.favoriteLounges,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [favoriteIds, favoriteLounges, status, errorMessage];
}
