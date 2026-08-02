import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/cache/preference_manager.dart';
import '../../../core/di.dart';
import '../../../core/error/failures.dart';
import '../data/repos/home_repos.dart';
import 'home_state.dart';
import '../data/models/lounge_model.dart';

class HomeCubit extends Cubit<HomeState> {
  final HomeRepository _homeRepository;
  HomeCubit(this._homeRepository) : super(const HomeState());

  Future<void> getHomeData() async {
    // Only show loading if we don't have data yet
    if (state.nearestLounges.isEmpty) {
      emit(state.copyWith(status: HomeStatus.loading));
    }

    final pref = sl<PreferenceManager>();
    final latStr = pref.latitude();
    final lngStr = pref.longitude();
    
    final lat = latStr.isNotEmpty ? double.tryParse(latStr) : null;
    final lng = lngStr.isNotEmpty ? double.tryParse(lngStr) : null;

    try {
      // 1. Prepare requests
      final List<Future> futures = [
        _homeRepository.getLounges(
          lat: lat,
          lng: lng,
          city: state.selectedCity,
        ),
      ];

      // Only fetch cities if we haven't already
      if (state.availableCities.isEmpty) {
        futures.add(_homeRepository.getAvailableCities());
      }

      // 2. Fetch in parallel
      final results = await Future.wait(futures);

      final loungesResult = results[0] as Either<Failure, List<LoungeModel>>;
      List<Map<String, dynamic>> cities = state.availableCities;

      if (results.length > 1) {
        final citiesResult = results[1] as Either<Failure, List<Map<String, dynamic>>>;
        cities = citiesResult.fold((l) => state.availableCities, (r) => r);
      }

      loungesResult.fold(
        (failure) => emit(state.copyWith(status: HomeStatus.failure)),
        (allLounges) {
          final topRatedLounges = List<LoungeModel>.from(allLounges)
            ..sort((a, b) => b.rating.compareTo(a.rating));

          emit(state.copyWith(
            status: HomeStatus.success,
            availableCities: cities,
            nearestLounges: allLounges,
            topRatedLounges: topRatedLounges.take(5).toList(),
          ));
        },
      );
    } catch (e) {
      emit(state.copyWith(status: HomeStatus.failure));
    }
  }

  Future<void> selectCity(String? city) async {
    if (city == state.selectedCity) return;
    
    if (city == null || city.isEmpty) {
      emit(state.copyWith(clearCity: true));
    } else {
      emit(state.copyWith(selectedCity: city));
    }
    
    await getHomeData();
  }
}
