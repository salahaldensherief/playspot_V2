import 'home_metadata_loader.dart';
import 'home_tournaments_loader.dart';
import 'home_location_tracker.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/cache/caching_key.dart';
import '../../../core/cache/preference_manager.dart';
import '../../../core/di.dart';
import '../../../core/services/location_service.dart';
import '../../tournaments/domain/usecases/get_tournaments_usecase.dart';
import '../../tournaments/domain/usecases/get_home_tournament_usecase.dart';
import '../../tournaments/domain/usecases/get_my_active_tournament_usecase.dart';
import '../domain/repositories/home_repository.dart';
import '../domain/usecases/discover_lounges_usecase.dart';
import '../domain/usecases/recalculate_lounge_distances_usecase.dart';
import 'home_state.dart';
import '../data/models/lounge_model.dart';
import '../data/models/home_params.dart';

class HomeCubit extends Cubit<HomeState> {
  final HomeRepository _homeRepository;
  final DiscoverLoungesUseCase _discover;
  final RecalculateLoungeDistancesUseCase _recalculate;
  final LocationService _locationService;
  final PreferenceManager _pref;
  late final HomeMetadataLoader _metadata = HomeMetadataLoader(
    _homeRepository,
    _pref,
    () => state,
    _safeEmit,
  );
  late final HomeTournamentsLoader _tournaments;
  late final HomeLocationTracker _location = HomeLocationTracker(_pref);
  final Stream<Position> Function() _positions;
  StreamSubscription<Position>? _positionSubscription;
  int _homeDataFetchToken = 0;
  int _locationReadToken = 0;

  HomeCubit(
    this._homeRepository,
    this._locationService,
    GetTournamentsUseCase tournaments,
    GetHomeTournamentUseCase homeTournament,
    GetMyActiveTournamentUseCase activeTournament, {
    PreferenceManager? preferenceManager,
    DiscoverLoungesUseCase? discover,
    RecalculateLoungeDistancesUseCase recalculate =
        const RecalculateLoungeDistancesUseCase(),
    Stream<Position> Function()? positions,
  }) : _pref = preferenceManager ?? sl<PreferenceManager>(),
       _discover = discover ?? DiscoverLoungesUseCase(_homeRepository),
       _recalculate = recalculate,
       _positions = positions ?? HomeLocationTracker.platformPositions,
       super(const HomeState()) {
    _tournaments = HomeTournamentsLoader(
      tournaments,
      homeTournament,
      activeTournament,
      _pref,
      () => state,
      _safeEmit,
    );
  }

  void _safeEmit(HomeState s) {
    if (!isClosed) emit(s);
  }

  Future<void> init() async {
    if (isClosed) return;
    _metadata.loadCached();
    _applyDistanceEstimates();
    final cached = state.nearestLounges.isNotEmpty;
    _safeEmit(
      state.copyWith(
        status: cached ? HomeStatus.success : HomeStatus.loading,
        isLoungesLoading: !cached,
        isPromosLoading: state.promotions.isEmpty,
        isCategoriesLoading: state.categories.isEmpty,
      ),
    );
    final cities = _metadata.loadCities();
    unawaited(_metadata.loadPromotions());
    unawaited(_metadata.loadCategories());
    unawaited(_metadata.loadPoints(_pref.userId()));
    unawaited(_tournaments.load());
    if (!cached) unawaited(getHomeData());
    await _detectLocation(cities);
  }

  Future<void> refreshHome() async {
    _safeEmit(state.copyWith(status: HomeStatus.refreshing));
    await Future.wait([
      _metadata.loadCities(),
      _metadata.loadPromotions(),
      _metadata.loadCategories(),
      _metadata.loadPoints(_pref.userId()),
      _tournaments.load(),
      getHomeData(forceLoading: false),
    ]);
  }

  Future<void> getHomeData({
    bool isLoadMore = false,
    bool forceLoading = false,
  }) async {
    if (isClosed) return;
    if (isLoadMore &&
        (state.hasReachedMax || state.status == HomeStatus.loadingMore)) {
      return;
    }
    final coordinates = _location.coordinates;
    _applyDistanceEstimates();
    final token = ++_homeDataFetchToken;
    _location.lastRequested = coordinates;
    final nextPage = isLoadMore ? state.currentPage + 1 : 0;
    final background =
        state.nearestLounges.isNotEmpty &&
        !isLoadMore &&
        !forceLoading &&
        !state.isLoungesLoading;
    _prepareLoungesRequest(isLoadMore, background, nextPage);
    final result = await _discover(
      GetLoungesParams(
        lat: coordinates?.latitude,
        lng: coordinates?.longitude,
        city: state.selectedCity,
        categoryIds: state.selectedCategoryIds,
        sortType: state.sortType == LoungeSortType.topRated
            ? 'top_rated'
            : 'nearest',
        limit: 10,
        offset: nextPage * 10,
      ),
    );
    if (token != _homeDataFetchToken || isClosed) return;
    result.fold(
      (f) => _safeEmit(
        state.copyWith(status: HomeStatus.failure, isLoungesLoading: false),
      ),
      (lounges) => _applyLounges(lounges, isLoadMore),
    );
  }

  void _prepareLoungesRequest(bool isLoadMore, bool background, int nextPage) {
    _safeEmit(
      state.copyWith(
        status: isLoadMore
            ? HomeStatus.loadingMore
            : background
            ? HomeStatus.refreshing
            : HomeStatus.loading,
        isLoungesLoading: !isLoadMore && !background,
        currentPage: nextPage,
        hasReachedMax: isLoadMore ? state.hasReachedMax : false,
      ),
    );
  }

  void _applyLounges(List<LoungeModel> lounges, bool isLoadMore) {
    final updated = isLoadMore
        ? [...state.nearestLounges, ...lounges]
        : lounges;
    _safeEmit(
      state.copyWith(
        status: HomeStatus.success,
        isLoungesLoading: false,
        nearestLounges: updated,
        hasReachedMax: lounges.length < 10,
      ),
    );
    if (!isLoadMore) {
      _pref.saveValue(
        CachingKey.CACHED_LOUNGES,
        jsonEncode(updated.map((e) => e.toJson()).toList()),
      );
    }
  }

  void _applyDistanceEstimates() {
    if (state.nearestLounges.isEmpty) return;
    final lounges = _recalculate(
      state.nearestLounges,
      _location.coordinates,
      sortByDistance: state.sortType == LoungeSortType.nearest,
    );
    final next = state.copyWith(nearestLounges: lounges);
    if (next == state) return;
    _safeEmit(next);
    _pref.saveValue(
      CachingKey.CACHED_LOUNGES,
      jsonEncode(lounges.map((lounge) => lounge.toJson()).toList()),
    );
  }

  void changeSortType(LoungeSortType type) {
    if (state.sortType == type) return;
    _safeEmit(state.copyWith(sortType: type, isLoungesLoading: true));
    getHomeData();
  }

  void loadMore() => getHomeData(isLoadMore: true);

  Future<void> _detectLocation(
    Future<List<Map<String, dynamic>>> citiesFuture,
  ) async {
    final token = ++_locationReadToken;
    final pos = await _locationService.getCurrentLocation();
    if (pos == null || isClosed || token != _locationReadToken) return;
    final moved = _location.hasMoved(pos);
    if (!await _location.save(pos) || isClosed || token != _locationReadToken) {
      return;
    }
    if (moved) unawaited(getHomeData());

    final address = await _locationService.getAddressFromLatLng(
      pos.latitude,
      pos.longitude,
    );
    if (address == null || isClosed || token != _locationReadToken) return;
    await citiesFuture;

    if (isClosed || token != _locationReadToken) return;
    await _pref.saveValue(CachingKey.CURRENT_ADDRESS, address);
    if (isClosed || token != _locationReadToken) return;
    _safeEmit(state.copyWith(currentAddress: address));
  }

  Future<void> fetchTournamentsData() => _tournaments.load();

  void startLocationListening() {
    if (isClosed || _positionSubscription != null) return;
    _positionSubscription = _positions().listen(
      _onPosition,
      onError: (Object error) {
        stopLocationListening();
      },
    );
  }

  Future<void> _onPosition(Position position) async {
    if (isClosed || !_location.isValid(position)) return;
    final token = ++_locationReadToken;
    final moved = _location.hasMoved(position);
    if (await _location.save(position) &&
        moved &&
        !isClosed &&
        token == _locationReadToken) {
      await getHomeData();
    }
  }

  void stopLocationListening() {
    ++_locationReadToken;
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  Future<void> selectCity(String? city) async {
    if (city == state.selectedCity) return;
    _safeEmit(
      city == null || city.isEmpty
          ? state.copyWith(clearCity: true, isLoungesLoading: true)
          : state.copyWith(selectedCity: city, isLoungesLoading: true),
    );
    await getHomeData();
  }

  void toggleCategory(String categoryId) async {
    final currentSelected = List<String>.from(state.selectedCategoryIds);
    if (currentSelected.contains(categoryId)) {
      currentSelected.remove(categoryId);
    } else {
      currentSelected.add(categoryId);
    }

    _safeEmit(
      state.copyWith(
        selectedCategoryIds: currentSelected,
        isLoungesLoading: true,
      ),
    );

    await getHomeData();
  }

  @override
  Future<void> close() {
    ++_homeDataFetchToken;
    ++_locationReadToken;
    stopLocationListening();
    return super.close();
  }
}
