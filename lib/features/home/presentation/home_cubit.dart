import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/repos/home_repos.dart';
import 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  final HomeRepository _homeRepository;
  HomeCubit(this._homeRepository) : super(const HomeState());

  Future<void> getHomeData() async {
    emit(state.copyWith(status: HomeStatus.loading));

    final result = await _homeRepository.getLounges();

    result.fold(
      (failure) => emit(state.copyWith(status: HomeStatus.failure)),
      (allLounges) => emit(state.copyWith(
        status: HomeStatus.success,
        nearestLounges: allLounges,
        topRatedLounges: allLounges,
      )),
    );
  }
}
