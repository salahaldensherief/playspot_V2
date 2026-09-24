import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import '../../../art_core/extension/globlX.dart';
import '../../../core/cache/caching_key.dart';
import '../../../core/cache/preference_manager.dart';
import '../../../core/di.dart';
import '../../../core/services/location_service.dart';
import '../../tournaments/domain/usecases/get_tournaments_usecase.dart';
import '../../tournaments/domain/usecases/get_home_tournament_usecase.dart';
import '../../tournaments/domain/usecases/get_my_active_tournament_usecase.dart';
import '../../tournaments/domain/entities/tournament_entity.dart';
import 'package:playspot/features/profile/domain/repositories/profile_repository.dart';
import '../domain/repositories/home_repository.dart';
import 'home_state.dart';
import '../data/models/lounge_model.dart';
import '../data/models/category_model.dart';
import '../data/models/promo_model.dart';
import '../data/models/home_params.dart';

class HomeCubit extends Cubit<HomeState> {
  final HomeRepository _homeRepository;
  final LocationService _locationService;
  final GetTournamentsUseCase _getTournamentsUseCase;
  final GetHomeTournamentUseCase _getHomeTournamentUseCase;
  final GetMyActiveTournamentUseCase _getMyActiveTournamentUseCase;

  final PreferenceManager _pref;
  final ProfileRepository? _profileRepository;

  StreamSubscription<Position>? _positionSubscription;

  // Token to handle race conditions for getHomeData calls
  int _homeDataFetchToken = 0;

  double? _lastUsedLat;
  double? _lastUsedLng;

  HomeCubit(
    this._homeRepository,
    this._locationService,
    this._getTournamentsUseCase,
    this._getHomeTournamentUseCase,
    this._getMyActiveTournamentUseCase, {
    PreferenceManager? preferenceManager,
    ProfileRepository? profileRepository,
  })  : _pref = preferenceManager ?? sl<PreferenceManager>(),
        _profileRepository = profileRepository ?? (sl.isRegistered<ProfileRepository>() ? sl<ProfileRepository>() : null),
        super(const HomeState());

  void _safeEmit(HomeState s) {
    if (!isClosed) emit(s);
  }

  Future<void> init() async {
    _loadCachedHomeData();

    final userId = _pref.userId();
    final hasCachedData = state.nearestLounges.isNotEmpty;

    _safeEmit(state.copyWith(
      status: hasCachedData ? HomeStatus.refreshing : HomeStatus.loading,
      isLoungesLoading: !hasCachedData,
      isPromosLoading: state.promotions.isEmpty,
      isCategoriesLoading: state.categories.isEmpty,
    ));

    final savedLat = double.tryParse(_pref.latitude());
    final savedLng = double.tryParse(_pref.longitude());
    var hasSavedLocation = savedLat != null && savedLng != null;

    if (!hasSavedLocation) {
      try {
        final lastPos = await Geolocator.getLastKnownPosition();
        if (lastPos != null) {
          await _pref.saveLatitude(lastPos.latitude);
          await _pref.saveLongitude(lastPos.longitude);
          hasSavedLocation = true;
          unawaited(getHomeData());
        }
      } catch (_) {}
    }

    final citiesFuture = _loadCities();
    unawaited(_loadPromotions());
    unawaited(_loadCategories());
    unawaited(_loadPoints(userId));
    unawaited(fetchTournamentsData());
    if (hasSavedLocation && state.nearestLounges.isEmpty) {
      unawaited(getHomeData());
    }

    await _detectLocation(
      citiesFuture,
      shouldRefreshLounges: !hasSavedLocation,
    );
  }

  static const String _citiesCacheKey = 'CITIES_CACHE';
  static const String _citiesCacheTimeKey = 'CITIES_CACHE_TIME';
  static const String _categoriesCacheTimeKey = 'CATEGORIES_CACHE_TIME';
  static const Duration _metaTtl = Duration(hours: 24);

  bool _isCacheValid(String timeKey) {
    final timestampStr = _pref.getValue(timeKey);
    if (timestampStr.isEmpty) return false;
    final timestamp = int.tryParse(timestampStr);
    if (timestamp == null) return false;
    final age = DateTime.now().millisecondsSinceEpoch - timestamp;
    return age < _metaTtl.inMilliseconds;
  }

  List<Map<String, dynamic>> _getCachedCities() {
    final raw = _pref.getValue(_citiesCacheKey);
    if (raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  List<CategoryModel> _getCachedCategories() {
    final raw = _pref.getValue(CachingKey.CATEGORIES_CACHE);
    if (raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => CategoryModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _loadCities() async {
    if (_isCacheValid(_citiesCacheTimeKey)) {
      final cached = _getCachedCities();
      if (cached.isNotEmpty) {
        _safeEmit(state.copyWith(availableCities: cached));
        return cached;
      }
    }
    final res = await _homeRepository.getAvailableCities();
    return res.fold((_) => <Map<String, dynamic>>[], (cities) {
      if (cities.isNotEmpty) {
        _safeEmit(state.copyWith(availableCities: cities));
        _pref.saveValue(_citiesCacheKey, jsonEncode(cities));
        _pref.saveValue(_citiesCacheTimeKey,
            DateTime.now().millisecondsSinceEpoch.toString());
      }
      return cities;
    });
  }

  Future<void> _loadCategories() async {
    if (_isCacheValid(_categoriesCacheTimeKey)) {
      final cached = _getCachedCategories();
      if (cached.isNotEmpty) {
        _safeEmit(state.copyWith(categories: cached, isCategoriesLoading: false));
        return;
      }
    }
    final res = await _homeRepository.getCategories();
    res.fold(
      (_) => _safeEmit(state.copyWith(isCategoriesLoading: false)),
      (cats) {
        if (cats.isEmpty) {
          _safeEmit(state.copyWith(isCategoriesLoading: false));
          return;
        }
        _safeEmit(state.copyWith(categories: cats, isCategoriesLoading: false));
        _pref.saveValue(CachingKey.CATEGORIES_CACHE,
            jsonEncode(cats.map((e) => e.toJson()).toList()));
        _pref.saveValue(_categoriesCacheTimeKey,
            DateTime.now().millisecondsSinceEpoch.toString());
      },
    );
  }

  Future<void> _loadPromotions() async {
    final res = await _homeRepository.getPromotions(loungeId: null);
    res.fold(
      (_) => _safeEmit(state.copyWith(isPromosLoading: false)),
      (promos) {
        _safeEmit(state.copyWith(
          promotions: promos,
          isPromosLoading: false,
        ));
        if (promos.isNotEmpty) {
          _pref.saveValue(CachingKey.PROMOTIONS_CACHE,
              jsonEncode(promos.map((e) => e.toJson()).toList()));
        }
      },
    );
  }

  Future<void> _loadPoints(String? userId) async {
    if (userId == null || userId.isEmpty) return;
    final res = await _homeRepository.getUserPoints(userId);
    res.fold((_) {}, (p) => _safeEmit(state.copyWith(pointsBalance: p)));
  }

  Future<void> fetchTournamentsData() async {
    await Future.wait([_loadHomeTournament(), _loadActiveTournament()]);
  }

  Future<void> _loadHomeTournament() async {
    final result = await _getHomeTournamentUseCase();
    await result.fold(
      (_) async {
        final lat = double.tryParse(_pref.latitude());
        final lng = double.tryParse(_pref.longitude());
        final res = await _getTournamentsUseCase(latitude: lat, longitude: lng);
        res.fold((_) {}, (tournaments) {
          final nearest = tournaments.firstWhereOrNull((t) =>
                  t.status == TournamentStatus.registrationOpen ||
                  t.status == TournamentStatus.published) ??
              tournaments.firstOrNull;
          _safeEmit(state.copyWith(
            nearbyTournament: nearest,
            clearNearbyTournament: nearest == null,
          ));
        });
      },
      (t) async => _safeEmit(state.copyWith(
        nearbyTournament: t,
        clearNearbyTournament: t == null,
      )),
    );
  }

  Future<void> _loadActiveTournament() async {
    final userId = _pref.userId();
    if (userId == null || userId.isEmpty) return;
    final result = await _getMyActiveTournamentUseCase();
    result.fold((_) {}, (p) {
      _safeEmit(state.copyWith(
        activeRegisteredTournament: p?.tournament,
        clearActiveRegisteredTournament: p?.tournament == null,
        activeUserParticipant: p?.participant,
        clearActiveUserParticipant: p?.participant == null,
      ));
    });
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

  Future<void> refreshHome() async {
    _safeEmit(state.copyWith(status: HomeStatus.refreshing));
    await Future.wait([
      _loadCities(),
      _loadPromotions(),
      _loadCategories(),
      _loadPoints(_pref.userId()),
      fetchTournamentsData(),
      getHomeData(forceLoading: false),
    ]);
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

    final isBackgroundRefresh = state.nearestLounges.isNotEmpty && !isLoadMore && !forceLoading && !state.isLoungesLoading;
    
    _safeEmit(state.copyWith(
      status: isLoadMore 
          ? HomeStatus.loadingMore
          : (isBackgroundRefresh ? HomeStatus.refreshing : HomeStatus.loading),
      isLoungesLoading: !isLoadMore && !isBackgroundRefresh,
      currentPage: nextPage,
      hasReachedMax: isLoadMore ? state.hasReachedMax : false,
      nearestLounges: (forceLoading || (!isLoadMore && !isBackgroundRefresh && state.nearestLounges.isEmpty)) ? [] : state.nearestLounges,
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
      (f) => _safeEmit(state.copyWith(
        status: HomeStatus.failure,
        isLoungesLoading: false,
      )),
      (newLounges) {
        final List<LoungeModel> updatedLounges = isLoadMore 
            ? [...state.nearestLounges, ...newLounges]
            : newLounges;

        _safeEmit(state.copyWith(
          status: HomeStatus.success,
          isLoungesLoading: false,
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
    _safeEmit(state.copyWith(sortType: type, isLoungesLoading: true));
    getHomeData();
  }

  void loadMore() => getHomeData(isLoadMore: true);

  Future<void> _detectLocation(
    Future<List<Map<String, dynamic>>> citiesFuture, {
    required bool shouldRefreshLounges,
  }) async {
    final pos = await _locationService.getCurrentLocation();
    if (pos == null) {
      if (state.status == HomeStatus.loading) {
        _safeEmit(state.copyWith(status: HomeStatus.failure));
      }
      return;
    }

    await _pref.saveLatitude(pos.latitude);
    await _pref.saveLongitude(pos.longitude);

    // Invoke update-user-location Edge Function in background
    try {
      if (_profileRepository != null) {
        unawaited(_profileRepository.updateUserLocation());
      }
    } catch (_) {}

    final movedSignificantly = _hasMovedSignificantly(pos.latitude, pos.longitude);
    if (shouldRefreshLounges || movedSignificantly) {
      unawaited(getHomeData());
    }

    final address = await _locationService.getAddressFromLatLng(pos.latitude, pos.longitude);
    if (address == null) return;
    await citiesFuture;

    final isInEgypt = address.toLowerCase().contains("egypt") || address.toLowerCase().contains("مصر");

    await _pref.saveValue(CachingKey.CURRENT_ADDRESS, address);

    String displayLocation = address;
    if (isInEgypt) {
      final parts = address.split(',');
      final area = parts.first.trim();
      displayLocation = "$area, Egypt";
    }

    _safeEmit(state.copyWith(
      currentAddress: displayLocation,
    ));
  }

  bool _hasMovedSignificantly(double newLat, double newLng) {
    final lastLat = _lastUsedLat;
    final lastLng = _lastUsedLng;
    if (lastLat == null || lastLng == null) return true;
    final distanceInMeters = Geolocator.distanceBetween(
      lastLat,
      lastLng,
      newLat,
      newLng,
    );
    return distanceInMeters > 500;
  }

  void startLocationListening() {
    if (_positionSubscription != null) return;
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 500,
      ),
    ).listen((p) async {
      final moved = _hasMovedSignificantly(p.latitude, p.longitude);
      await _pref.saveLatitude(p.latitude);
      await _pref.saveLongitude(p.longitude);

      if (moved) {
        await getHomeData();
      }
    });
  }

  void stopLocationListening() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  Future<void> selectCity(String? city) async {
    if (city == state.selectedCity) return;
    _safeEmit(city == null || city.isEmpty
        ? state.copyWith(clearCity: true, isLoungesLoading: true)
        : state.copyWith(selectedCity: city, isLoungesLoading: true));
    await getHomeData();
  }

  void toggleCategory(String categoryId) async {
    final currentSelected = List<String>.from(state.selectedCategoryIds);
    if (currentSelected.contains(categoryId)) {
      currentSelected.remove(categoryId);
    } else {
      currentSelected.add(categoryId);
    }

    _safeEmit(state.copyWith(
      selectedCategoryIds: currentSelected,
      isLoungesLoading: true,
    ));

    await getHomeData();
  }

  @override
  Future<void> close() {
    stopLocationListening();
    return super.close();
  }
}
