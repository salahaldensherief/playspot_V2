import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/repos/home_repos.dart';
import 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  final HomeRepository _homeRepository;
  HomeCubit(this._homeRepository) : super(const HomeState());

  // Future<void> getHomeData() async {
  //   emit(state.copyWith(status: HomeStatus.loading));
  //
  //   try {
  //     final allLounges = await _homeRepository.getLounges();
  //
  //     // Split them for the UI logic
  //     final nearest = allLounges.where((l) => l.distance < 2.0).toList();
  //     final topRated = allLounges.where((l) => l.rating >= 4.7).toList();
  //
  //     emit(state.copyWith(
  //       status: HomeStatus.success,
  //       nearestLounges: nearest,
  //       topRatedLounges: topRated,
  //     ));
  //   } catch (e) {
  //     emit(state.copyWith(status: HomeStatus.failure));
  //   }
  // }
  Future<void> getHomeData() async {
    emit(state.copyWith(status: HomeStatus.loading));

    try {
      final allLounges = await _homeRepository.getLounges();

      emit(state.copyWith(
        status: HomeStatus.success,
        nearestLounges: allLounges,
        topRatedLounges: allLounges,
      ));
    } catch (e) {
      emit(state.copyWith(status: HomeStatus.failure));
    }
  }

}
