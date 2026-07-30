import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/cache/preference_manager.dart';
import '../../../core/di.dart';
import '../../../core/di/modules/auth_module.dart';
import '../data/repos/home_repos.dart';
import 'home_state.dart';
import '../data/models/lounge_model.dart';

class HomeCubit extends Cubit<HomeState> {
  final HomeRepository _homeRepository;
  HomeCubit(this._homeRepository) : super(const HomeState());

  Future<void> getHomeData() async {
    emit(state.copyWith(status: HomeStatus.loading));

    final pref = sl<PreferenceManager>();
    final latStr = pref.latitude();
    final lngStr = pref.longitude();
    
    final lat = latStr.isNotEmpty ? double.tryParse(latStr) : null;
    final lng = lngStr.isNotEmpty ? double.tryParse(lngStr) : null;

    final result = await _homeRepository.getLounges(
      lat: lat,
      lng: lng,
    );

    result.fold(
      (failure) => emit(state.copyWith(status: HomeStatus.failure)),
      (allLounges) {
        // Nearest lounges are already sorted by the RPC if lat/lng are provided.
        // If not, we just use the list as is.
        final nearestLounges = allLounges;

        // Top rated can be a filtered version of allLounges
        final topRatedLounges = List<LoungeModel>.from(allLounges)
          ..sort((a, b) => b.rating.compareTo(a.rating));

        emit(state.copyWith(
          status: HomeStatus.success,
          nearestLounges: nearestLounges,
          topRatedLounges: topRatedLounges.take(5).toList(),
        ));
      },
    );
  }
}
