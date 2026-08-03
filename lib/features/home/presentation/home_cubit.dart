import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/cache/preference_manager.dart';
import '../../../core/di.dart';
import '../../../core/error/failures.dart';
import '../../../core/services/location_service.dart';
import '../data/repos/home_repos.dart';
import 'home_state.dart';
import '../data/models/lounge_model.dart';
import '../data/models/category_model.dart';
import '../data/models/promo_model.dart';

class HomeCubit extends Cubit<HomeState> {
  final HomeRepository _homeRepository;
  final LocationService _locationService;
  StreamSubscription<Position>? _positionSubscription;

  HomeCubit(this._homeRepository, this._locationService) : super(const HomeState());

  Future<void> init() async {
    emit(state.copyWith(status: HomeStatus.loading));
    
    final meta = await Future.wait([
      _homeRepository.getAvailableCities(),
      _homeRepository.getPromotions(),
      _homeRepository.getCategories(),
    ]);

    final cities = (meta[0] as Either<Failure, List<Map<String, dynamic>>>).fold((l) => [], (r) => r);
    
    emit(state.copyWith(
      availableCities: cities as List<Map<String, dynamic>>,
      promotions: (meta[1] as Either<Failure, List<PromoModel>>).fold((l) => [], (r) => r),
      categories: (meta[2] as Either<Failure, List<CategoryModel>>).fold((l) => [], (r) => r),
    ));

    await _detectLocation(cities);
    await getHomeData();
  }

  Future<void> getHomeData() async {
    final pref = sl<PreferenceManager>();
    final lat = double.tryParse(pref.latitude());
    final lng = double.tryParse(pref.longitude());

    final res = await _homeRepository.getLounges(lat: lat, lng: lng, city: state.selectedCity);

    res.fold(
      (f) => emit(state.copyWith(status: HomeStatus.failure)),
      (lounges) {
        final top = List<LoungeModel>.from(lounges)..sort((a, b) => b.rating.compareTo(a.rating));
        emit(state.copyWith(
          status: HomeStatus.success,
          nearestLounges: lounges,
          topRatedLounges: top.take(5).toList(),
        ));
      },
    );
  }

  Future<void> _detectLocation(List<Map<String, dynamic>> cities) async {
    final pos = await _locationService.getCurrentLocation();
    if (pos == null) return;

    final pref = sl<PreferenceManager>();
    await pref.saveLatitude(pos.latitude);
    await pref.saveLongitude(pos.longitude);

    final address = await _locationService.getAddressFromLatLng(pos.latitude, pos.longitude);
    if (address == null) return;

    await pref.saveValue('CURRENT_ADDRESS', address);
    final city = address.split(',').last.trim();
    final supported = cities.any((c) => c['city'].toString().toLowerCase() == city.toLowerCase());

    emit(state.copyWith(selectedCity: supported ? city : null, currentAddress: address));
  }

  void startLocationListening() {
    _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, distanceFilter: 500),
    ).listen((p) async {
      final pref = sl<PreferenceManager>();
      await pref.saveLatitude(p.latitude);
      await pref.saveLongitude(p.longitude);
      await getHomeData();
    });
  }

  Future<void> selectCity(String? city) async {
    if (city == state.selectedCity) return;
    emit(city == null || city.isEmpty ? state.copyWith(clearCity: true) : state.copyWith(selectedCity: city));
    await getHomeData();
  }

  @override
  Future<void> close() {
    _positionSubscription?.cancel();
    return super.close();
  }
}
