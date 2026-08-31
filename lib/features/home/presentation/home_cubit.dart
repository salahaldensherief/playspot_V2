import 'dart:convert';
import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/cache/preference_manager.dart';
import '../../../core/di.dart';
import '../../../core/error/failures.dart';
import '../../../core/services/location_service.dart';
import '../domain/repositories/home_repository.dart';
import 'home_state.dart';
import '../data/models/lounge_model.dart';
import '../data/models/category_model.dart';
import '../data/models/promo_model.dart';
import '../data/models/home_params.dart';

class HomeCubit extends Cubit<HomeState> {
  final HomeRepository _homeRepository;
  final LocationService _locationService;
  StreamSubscription<Position>? _positionSubscription;
  final _pref = sl<PreferenceManager>();

  // آخر موقع استخدمناه فعلياً في نداء getHomeData، عشان نقارن بيه ونمنع
  // نداءات مكررة لو الموقع اتغير شوية بسيطة مش مؤثرة.
  double? _lastUsedLat;
  double? _lastUsedLng;

  HomeCubit(this._homeRepository, this._locationService) : super(const HomeState());

  Future<void> init() async {
    _loadCachedHomeData();

    final userId = _pref.userId();
    final hasCachedData = state.nearestLounges.isNotEmpty;

    // لو معندناش أي بيانات كاش خالص، دي أول مرة فعلاً يفتح فيها التطبيق،
    // فمفيش مفر من شاشة تحميل حقيقية. لو عندنا كاش، بنستخدم حالة "تحديث
    // في الخلفية" عشان البيانات القديمة تفضل ظاهرة للمستخدم مش تتغطى فجأة.
    emit(state.copyWith(
      status: hasCachedData ? HomeStatus.refreshing : HomeStatus.loading,
    ));

    // البيانات الوصفية (مدن، عروض، تصنيفات، نقاط) بتتجاب مرة واحدة بس هنا.
    final meta = await Future.wait([
      _homeRepository.getAvailableCities(),
      _homeRepository.getPromotions(),
      _homeRepository.getCategories(),
      if (userId != null && userId.isNotEmpty) _homeRepository.getUserPoints(userId),
    ]);

    final cities = (meta[0] as Either<Failure, List<Map<String, dynamic>>>)
        .fold((l) => <Map<String, dynamic>>[], (r) => r);
    final points = meta.length > 3
        ? (meta[3] as Either<Failure, int>).fold((l) => 0, (r) => r)
        : 0;

    final promotions =
    (meta[1] as Either<Failure, List<PromoModel>>).fold((l) => <PromoModel>[], (r) => r);
    final categories =
    (meta[2] as Either<Failure, List<CategoryModel>>).fold((l) => <CategoryModel>[], (r) => r);

    emit(state.copyWith(
      availableCities: cities,
      promotions: promotions,
      categories: categories,
      pointsBalance: points,
    ));

    _cacheMetaData(promotions, categories);

    // 🔑 التغيير الأساسي: مبقيناش بننتظر تحديد الموقع الكامل (GPS + تحويل
    // لعنوان نصي) قبل ما نجيب الصالات. لو عندنا lat/lng محفوظين من قبل،
    // نجيب الصالات بيهم فوراً، وفي نفس الوقت (بالتوازي) نطلب موقع أحدث.
    final savedLat = double.tryParse(_pref.latitude());
    final savedLng = double.tryParse(_pref.longitude());
    final hasSavedLocation = savedLat != null && savedLng != null;

    if (hasSavedLocation) {
      // نجيب الصالات فوراً من غير أي انتظار للموقع الجديد أو للعنوان النصي.
      unawaited(getHomeData());
    }

    // تحديد الموقع الفعلي (GPS الجديد + تحويله لعنوان نصي) بيشتغل بالتوازي،
    // مش قبل جلب الصالات. الفنكشن نفسها هي اللي هتقرر تنادي getHomeData
    // تاني لو لقيت إن الموقع اتغير فرق مؤثر عن اللي كان محفوظ.
    await _detectLocation(cities, shouldRefreshLounges: !hasSavedLocation);

    // fallback: لو معندناش موقع محفوظ خالص من الأساس (أول مرة حقيقية)،
    // getHomeData هتتنادى من جوه _detectLocation نفسها بعد ما يوصلها موقع.
  }

  void _loadCachedHomeData() {
    final cachedPromos = _pref.getValue('CACHED_PROMOS');
    final cachedCats = _pref.getValue('CACHED_CATEGORIES');
    final cachedLounges = _pref.getValue('CACHED_LOUNGES');

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
    _pref.saveValue('CACHED_PROMOS', jsonEncode(promos.map((e) => e.toJson()).toList()));
    _pref.saveValue('CACHED_CATEGORIES', jsonEncode(cats.map((e) => e.toJson()).toList()));
  }

  Future<void> getHomeData({bool isLoadMore = false, bool forceLoading = false}) async {
    final lat = double.tryParse(_pref.latitude());
    final lng = double.tryParse(_pref.longitude());

    if (lat == null || lng == null) return;
    if (isLoadMore && (state.hasReachedMax || state.status == HomeStatus.loadingMore)) return;

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
          _pref.saveValue('CACHED_LOUNGES', jsonEncode(updatedLounges.map((e) => e.toJson()).toList()));
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

    // لو الموقع الجديد بعيد بشكل مؤثر عن اللي استخدمناه فعلياً في آخر نداء
    // للصالات (أو معندناش موقع كان مستخدم من الأساس)، نحدّث الصالات.
    final movedSignificantly = _hasMovedSignificantly(pos.latitude, pos.longitude);
    if (shouldRefreshLounges || movedSignificantly) {
      unawaited(getHomeData());
    }

    // تحويل الإحداثيات لعنوان نصي (لعرض "انت في: القاهرة" وتحديد الـ
    // Dropdown) — ده مش لازم لجلب الصالات خالص، فمنفصل تماماً وبعدها.
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
      currentAddress: displayLocation,
    ));
  }

  /// بيرجع true لو الموقع الجديد اختلف عن آخر موقع استخدمناه فعلياً بمسافة
  /// مؤثرة (~500 متر تقريباً)، مش أي فرق بسيط في آخر رقمين عشري.
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

      // بفضل distanceFilter: 500 فوق، الـ stream نفسه مش هيبعت event
      // إلا لو المستخدم اتحرك 500 متر فعلاً، فمفيش داعي لفحص إضافي هنا.
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