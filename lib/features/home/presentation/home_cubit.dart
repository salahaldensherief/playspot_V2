import 'dart:convert';
import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import '../../../art_core/extension/globlX.dart';
import '../../../core/cache/caching_key.dart';
import '../../../core/cache/preference_manager.dart';
import '../../../core/di.dart';
import '../../../core/error/failures.dart';
import '../../../core/services/location_service.dart';
import '../../tournaments/domain/usecases/get_tournaments_usecase.dart';
import '../../tournaments/domain/usecases/get_home_tournament_usecase.dart';
import '../../tournaments/domain/usecases/get_my_active_tournament_usecase.dart';
import '../../tournaments/domain/entities/tournament_entity.dart';
import '../domain/repositories/home_repository.dart';
import 'home_state.dart';
import '../data/models/lounge_model.dart';
import '../data/models/category_model.dart';
import '../data/models/promo_model.dart';
import '../data/models/home_params.dart';

class _MetaDataResult {
  final List<Map<String, dynamic>> cities;
  final List<PromoModel> promotions;
  final List<CategoryModel> categories;
  final int points;

  const _MetaDataResult({
    required this.cities,
    required this.promotions,
    required this.categories,
    required this.points,
  });
}

class HomeCubit extends Cubit<HomeState> {
  final HomeRepository _homeRepository;
  final LocationService _locationService;
  final GetTournamentsUseCase _getTournamentsUseCase;
  final GetHomeTournamentUseCase _getHomeTournamentUseCase;
  final GetMyActiveTournamentUseCase _getMyActiveTournamentUseCase;

  StreamSubscription<Position>? _positionSubscription;
  final _pref = sl<PreferenceManager>();

  // Token to handle race conditions for getHomeData calls
  int _homeDataFetchToken = 0;

  double? _lastUsedLat;
  double? _lastUsedLng;

  HomeCubit(
    this._homeRepository,
    this._locationService,
    this._getTournamentsUseCase,
    this._getHomeTournamentUseCase,
    this._getMyActiveTournamentUseCase,
  ) : super(const HomeState());

  Future<void> init() async {
    _loadCachedHomeData();

    final userId = _pref.userId();
    final hasCachedData = state.nearestLounges.isNotEmpty;

    emit(state.copyWith(
      status: hasCachedData ? HomeStatus.refreshing : HomeStatus.loading,
    ));

    final meta = await _fetchMetaData(userId);

    emit(state.copyWith(
      availableCities: meta.cities,
      promotions: meta.promotions,
      categories: meta.categories,
      pointsBalance: meta.points,
    ));

    _cacheMetaData(meta.promotions, meta.categories);

    unawaited(fetchTournamentsData());

    final savedLat = double.tryParse(_pref.latitude());
    final savedLng = double.tryParse(_pref.longitude());
    final hasSavedLocation = savedLat != null && savedLng != null;

    if (hasSavedLocation) {
      unawaited(getHomeData());
    }

    await _detectLocation(meta.cities, shouldRefreshLounges: !hasSavedLocation);
  }

  Future<_MetaDataResult> _fetchMetaData(String? userId) async {
    final meta = await Future.wait([
      _homeRepository.getAvailableCities(),
      _homeRepository.getPromotions(loungeId: null),
      _homeRepository.getCategories(),
      if (userId != null && userId.isNotEmpty) _homeRepository.getUserPoints(userId),
    ]);

    final cities = (meta[0] as Either<Failure, List<Map<String, dynamic>>>)
        .fold((l) => <Map<String, dynamic>>[], (r) => r);
    final promotions =
        (meta[1] as Either<Failure, List<PromoModel>>).fold((l) => <PromoModel>[], (r) => r);
    final categories =
        (meta[2] as Either<Failure, List<CategoryModel>>).fold((l) => <CategoryModel>[], (r) => r);
    final points = meta.length > 3
        ? (meta[3] as Either<Failure, int>).fold((l) => 0, (r) => r)
        : state.pointsBalance;

    return _MetaDataResult(
      cities: cities,
      promotions: promotions,
      categories: categories,
      points: points,
    );
  }

  Future<void> fetchTournamentsData() async {
    // 1) Fetch featured home promo tournament via RPC get_home_tournament
    final homeTournamentResult = await _getHomeTournamentUseCase();
    await homeTournamentResult.fold(
      (failure) async {
        // Fallback if RPC fails
        final lat = double.tryParse(_pref.latitude());
        final lng = double.tryParse(_pref.longitude());
        final tournamentsResult = await _getTournamentsUseCase(latitude: lat, longitude: lng);
        tournamentsResult.fold(
          (failure) {},
          (tournaments) {
            final nearest = tournaments.firstWhereOrNull(
              (t) => t.status == TournamentStatus.registrationOpen || t.status == TournamentStatus.published,
            ) ?? tournaments.firstOrNull;
            emit(state.copyWith(
              nearbyTournament: nearest,
              clearNearbyTournament: nearest == null,
            ));
          },
        );
      },
      (tournament) async {
        emit(state.copyWith(
          nearbyTournament: tournament,
          clearNearbyTournament: tournament == null,
        ));
      },
    );

    // 2) Fetch user active tournament via RPC get_my_active_tournament
    final userId = _pref.userId();
    if (userId != null && userId.isNotEmpty) {
      final activeResult = await _getMyActiveTournamentUseCase();
      activeResult.fold(
        (failure) {},
        (participation) {
          emit(state.copyWith(
            activeRegisteredTournament: participation?.tournament,
            clearActiveRegisteredTournament: participation?.tournament == null,
            activeUserParticipant: participation?.participant,
            clearActiveUserParticipant: participation?.participant == null,
          ));
        },
      );
    }
  }

  void _loadCachedHomeData() {
    final cachedPromos = _pref.getValue(CachingKey.PROMOTIONS_CACHE);
    final cachedCats = _pref.getValue(CachingKey.CATEGORIES_CACHE);
    final cachedLounges = _pref.getValue(CachingKey.CACHED_LOUNGES);

    if (cachedPromos.isNotEmpty || cachedCats.isNotEmpty || cachedLounges.isNotEmpty) {
      try {
        final List<PromoModel> promos = cachedPromos.isNotEmpty
            ? (jsonDecode(cachedPromos) as List).map((e) => PromoModel.fromJson(e)).toList()
            : <PromoModel>[];
        final List<CategoryModel> cats = cachedCats.isNotEmpty
            ? (jsonDecode(cachedCats) as List).map((e) => CategoryModel.fromJson(e)).toList()
            : <CategoryModel>[];
        final List<LoungeModel> lounges = cachedLounges.isNotEmpty
            ? (jsonDecode(cachedLounges) as List).map((e) => LoungeModel.fromJson(e)).toList()
            : <LoungeModel>[];

        emit(state.copyWith(
          promotions: promos,
          categories: cats,
          nearestLounges: lounges,
          topRatedLounges: List<LoungeModel>.from(lounges)
            ..sort((a, b) => b.rating.compareTo(a.rating)),
        ));
      } catch (e) {
        debugPrint("CACHE_LOAD_ERROR: $e");
      }
    }
  }

  void _cacheMetaData(List<PromoModel> promos, List<CategoryModel> cats) {
    _pref.saveValue(CachingKey.PROMOTIONS_CACHE, jsonEncode(promos.map((e) => e.toJson()).toList()));
    _pref.saveValue(CachingKey.CATEGORIES_CACHE, jsonEncode(cats.map((e) => e.toJson()).toList()));
  }

  Future<void> refreshHome() async {
    final userId = _pref.userId();
    
    emit(state.copyWith(status: HomeStatus.refreshing));

    final meta = await _fetchMetaData(userId);

    emit(state.copyWith(
      availableCities: meta.cities,
      promotions: meta.promotions,
      categories: meta.categories,
      pointsBalance: meta.points,
    ));

    _cacheMetaData(meta.promotions, meta.categories);

    unawaited(fetchTournamentsData());

    await getHomeData(forceLoading: false);
  }

  Future<void> getHomeData({bool isLoadMore = false, bool forceLoading = false}) async {
    final lat = double.tryParse(_pref.latitude());
    final lng = double.tryParse(_pref.longitude());

    if (lat == null || lng == null) return;
    if (isLoadMore && (state.hasReachedMax || state.status == HomeStatus.loadingMore)) return;

    final currentFetchToken = ++_homeDataFetchToken;

    _lastUsedLat = lat;
    _lastUsedLng = lng;

    final nextPage = isLoadMore ? state.currentPage + 1 : 0;
    const pageSize = 10;

    final isBackgroundRefresh = state.nearestLounges.isNotEmpty && !isLoadMore && !forceLoading;
    
    emit(state.copyWith(
      status: isLoadMore 
          ? HomeStatus.loadingMore
          : (isBackgroundRefresh ? HomeStatus.refreshing : HomeStatus.loading),
      currentPage: nextPage,
      hasReachedMax: isLoadMore ? state.hasReachedMax : false,
      nearestLounges: forceLoading ? [] : state.nearestLounges,
    ));

    final result = await _homeRepository.getLounges(
      GetLoungesParams(
        lat: lat,
        lng: lng,
        city: state.selectedCity,
        categoryIds: state.selectedCategoryIds,
        sortType: state.sortType == LoungeSortType.topRated ? 'top_rated' : 'nearest',
        limit: pageSize,
        offset: nextPage * pageSize,
      )
    );

    // Stale request check: Ignore response if a newer getHomeData request was triggered
    if (currentFetchToken != _homeDataFetchToken) return;

    result.fold(
      (f) => emit(state.copyWith(status: HomeStatus.failure)),
      (newLounges) {
        final List<LoungeModel> updatedLounges = isLoadMore 
            ? [...state.nearestLounges, ...newLounges]
            : newLounges;

        emit(state.copyWith(
          status: HomeStatus.success,
          nearestLounges: updatedLounges,
          hasReachedMax: newLounges.length < pageSize,
        ));

        if (!isLoadMore) {
          _pref.saveValue(CachingKey.CACHED_LOUNGES, jsonEncode(updatedLounges.map((e) => e.toJson()).toList()));
        }
      },
    );
  }

  void changeSortType(LoungeSortType type) {
    if (state.sortType == type) return;
    emit(state.copyWith(sortType: type));
    getHomeData();
  }

  void loadMore() => getHomeData(isLoadMore: true);

  Future<void> _detectLocation(
      List<Map<String, dynamic>> cities, {
        required bool shouldRefreshLounges,
      }) async {
    final pos = await _locationService.getCurrentLocation();
    if (pos == null) return;

    final pref = sl<PreferenceManager>();
    await pref.saveLatitude(pos.latitude);
    await pref.saveLongitude(pos.longitude);

    final movedSignificantly = _hasMovedSignificantly(pos.latitude, pos.longitude);
    if (shouldRefreshLounges || movedSignificantly) {
      unawaited(getHomeData());
    }

    final address = await _locationService.getAddressFromLatLng(pos.latitude, pos.longitude);
    if (address == null) return;

    final lowerAddress = address.toLowerCase();
    final isInEgypt = lowerAddress.contains("egypt") || lowerAddress.contains("مصر");

    await pref.saveValue(CachingKey.CURRENT_ADDRESS, address);

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
      currentAddress: displayLocation,
    ));
  }

  bool _hasMovedSignificantly(double newLat, double newLng) {
    if (_lastUsedLat == null || _lastUsedLng == null) return true;
    final distanceInMeters = Geolocator.distanceBetween(
      _lastUsedLat!,
      _lastUsedLng!,
      newLat,
      newLng,
    );
    return distanceInMeters > 500;
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
    ));

    await getHomeData(forceLoading: true);
  }

  @override
  Future<void> close() {
    _positionSubscription?.cancel();
    return super.close();
  }
}
