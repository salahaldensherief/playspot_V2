import 'dart:convert';
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
  final _pref = sl<PreferenceManager>();

  HomeCubit(this._homeRepository, this._locationService) : super(const HomeState());

  Future<void> init() async {
    // 📦 1. تحميل الداتا من الـ Cache فوراً عشان السرعة (Instant Load)
    _loadCachedHomeData();

    emit(state.copyWith(status: HomeStatus.loading));
    
    final userId = _pref.userId();

    final meta = await Future.wait([
      _homeRepository.getAvailableCities(),
      _homeRepository.getPromotions(),
      _homeRepository.getCategories(),
      if (userId != null && userId.isNotEmpty) _homeRepository.getUserPoints(userId),
    ]);

    final cities = (meta[0] as Either<Failure, List<Map<String, dynamic>>>).fold((l) => [], (r) => r);
    final points = meta.length > 3 ? (meta[3] as Either<Failure, int>).fold((l) => 0, (r) => r) : 0;
    
    final promotions = (meta[1] as Either<Failure, List<PromoModel>>).fold((l) => [], (r) => r);
    final categories = (meta[2] as Either<Failure, List<CategoryModel>>).fold((l) => [], (r) => r);

    emit(state.copyWith(
      availableCities: cities as List<Map<String, dynamic>>,
      promotions: promotions,
      categories: categories,
      pointsBalance: points,
    ));

    // 💾 حفظ الداتا الأساسية في الـ Cache
    _cacheMetaData(promotions, categories);

    await _detectLocation(cities);
    await getHomeData();
  }

  void _loadCachedHomeData() {
    final cachedPromos = _pref.getValue('CACHED_PROMOS');
    final cachedCats = _pref.getValue('CACHED_CATEGORIES');
    final cachedLounges = _pref.getValue('CACHED_LOUNGES');

    if (cachedPromos.isNotEmpty || cachedCats.isNotEmpty || cachedLounges.isNotEmpty) {
      try {
        final List<PromoModel> promos = cachedPromos.isNotEmpty 
            ? (jsonDecode(cachedPromos) as List).map((e) => PromoModel.fromJson(e)).toList() 
            : [];
        final List<CategoryModel> cats = cachedCats.isNotEmpty 
            ? (jsonDecode(cachedCats) as List).map((e) => CategoryModel.fromJson(e)).toList() 
            : [];
        final List<LoungeModel> lounges = cachedLounges.isNotEmpty 
            ? (jsonDecode(cachedLounges) as List).map((e) => LoungeModel.fromJson(e)).toList() 
            : [];

        emit(state.copyWith(
          promotions: promos,
          categories: cats,
          nearestLounges: lounges,
          topRatedLounges: List<LoungeModel>.from(lounges)..sort((a, b) => b.rating.compareTo(a.rating)),
        ));
      } catch (e) {
        debugPrint("CACHE_LOAD_ERROR: $e");
      }
    }
  }

  void _cacheMetaData(List<PromoModel> promos, List<CategoryModel> cats) {
    _pref.saveValue('CACHED_PROMOS', jsonEncode(promos.map((e) => e.toJson()).toList()));
    _pref.saveValue('CACHED_CATEGORIES', jsonEncode(cats.map((e) => e.toJson()).toList()));
  }

  Future<void> getHomeData() async {
    final userId = _pref.userId();
    final lat = double.tryParse(_pref.latitude());
    final lng = double.tryParse(_pref.longitude());

    final results = await Future.wait([
      _homeRepository.getLounges(
        lat: lat,
        lng: lng,
        city: state.selectedCity,
        categoryIds: state.selectedCategoryIds,
      ),
      if (userId != null && userId.isNotEmpty) _homeRepository.getUserPoints(userId),
    ]);

    final res = results[0] as Either<Failure, List<LoungeModel>>;
    final points = results.length > 1 ? (results[1] as Either<Failure, int>).fold((l) => state.pointsBalance, (r) => r) : state.pointsBalance;

    res.fold(
      (f) => emit(state.copyWith(status: HomeStatus.failure)),
      (lounges) {
        final top = List<LoungeModel>.from(lounges)..sort((a, b) => b.rating.compareTo(a.rating));
        emit(state.copyWith(
          status: HomeStatus.success,
          nearestLounges: lounges,
          topRatedLounges: top.take(5).toList(),
          pointsBalance: points,
        ));
        // 💾 تحديث كاش الصالات بآخر داتا حقيقية
        _pref.saveValue('CACHED_LOUNGES', jsonEncode(lounges.map((e) => e.toJson()).toList()));
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

    final lowerAddress = address.toLowerCase();
    final isInEgypt = lowerAddress.contains("egypt") || lowerAddress.contains("مصر");
    
    await pref.saveValue('CURRENT_ADDRESS', address);
    
    String? matchedCity;
    for (var c in cities) {
      final cityName = c['city'].toString();
      if (lowerAddress.contains(cityName.toLowerCase())) {
        matchedCity = cityName;
        break;
      }
    }

    String displayLocation = address;
    if (isInEgypt) {
      final parts = address.split(',');
      final area = parts.first.trim();
      displayLocation = "$area, Egypt";
    }

    emit(state.copyWith(
      selectedCity: matchedCity, 
      currentAddress: displayLocation
    ));
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
    emit(city == null || city.isEmpty 
        ? state.copyWith(clearCity: true, status: HomeStatus.loading) 
        : state.copyWith(selectedCity: city, status: HomeStatus.loading));
    await getHomeData();
  }

  void toggleCategory(String categoryId) async {
    final currentSelected = List<String>.from(state.selectedCategoryIds);
    if (currentSelected.contains(categoryId)) {
      currentSelected.remove(categoryId);
    } else {
      currentSelected.add(categoryId);
    }
    
    emit(state.copyWith(
      selectedCategoryIds: currentSelected,
      status: HomeStatus.loading,
    ));

    await getHomeData();
  }

  @override
  Future<void> close() {
    _positionSubscription?.cancel();
    return super.close();
  }
}
