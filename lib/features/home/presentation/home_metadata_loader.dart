import 'dart:convert';
import 'package:playspot/art_core/utils/app_logger.dart';
import 'package:playspot/core/cache/caching_key.dart';
import 'package:playspot/core/cache/preference_manager.dart';
import '../domain/repositories/home_repository.dart';
import '../data/models/lounge_model.dart';
import '../data/models/category_model.dart';
import '../data/models/promo_model.dart';
import 'home_state.dart';

class HomeMetadataLoader {
  final HomeRepository repository;
  final PreferenceManager pref;
  final HomeState Function() readState;
  final void Function(HomeState) update;
  HomeMetadataLoader(this.repository, this.pref, this.readState, this.update);
  HomeState get state => readState();
  static const String _citiesCacheKey = 'CITIES_CACHE';
  static const String _citiesCacheTimeKey = 'CITIES_CACHE_TIME';
  static const String _categoriesCacheTimeKey = 'CATEGORIES_CACHE_TIME';
  static const Duration _metaTtl = Duration(hours: 24);

  bool _isCacheValid(String timeKey) {
    final timestampStr = pref.getValue(timeKey);
    if (timestampStr.isEmpty) return false;
    final timestamp = int.tryParse(timestampStr);
    if (timestamp == null) return false;
    final age = DateTime.now().millisecondsSinceEpoch - timestamp;
    return age < _metaTtl.inMilliseconds;
  }

  List<Map<String, dynamic>> _getCachedCities() {
    final raw = pref.getValue(_citiesCacheKey);
    if (raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  List<CategoryModel> _getCachedCategories() {
    final raw = pref.getValue(CachingKey.CATEGORIES_CACHE);
    if (raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map(
            (e) => CategoryModel.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> loadCities() async {
    if (_isCacheValid(_citiesCacheTimeKey)) {
      final cached = _getCachedCities();
      if (cached.isNotEmpty) {
        update(state.copyWith(availableCities: cached));
        return cached;
      }
    }
    final res = await repository.getAvailableCities();
    return res.fold((_) => <Map<String, dynamic>>[], (cities) {
      if (cities.isNotEmpty) {
        update(state.copyWith(availableCities: cities));
        pref.saveValue(_citiesCacheKey, jsonEncode(cities));
        pref.saveValue(
          _citiesCacheTimeKey,
          DateTime.now().millisecondsSinceEpoch.toString(),
        );
      }
      return cities;
    });
  }

  Future<void> loadCategories() async {
    if (_isCacheValid(_categoriesCacheTimeKey)) {
      final cached = _getCachedCategories();
      if (cached.isNotEmpty) {
        update(state.copyWith(categories: cached, isCategoriesLoading: false));
        return;
      }
    }
    final res = await repository.getCategories();
    res.fold((_) => update(state.copyWith(isCategoriesLoading: false)), (cats) {
      if (cats.isEmpty) {
        update(state.copyWith(isCategoriesLoading: false));
        return;
      }
      update(state.copyWith(categories: cats, isCategoriesLoading: false));
      pref.saveValue(
        CachingKey.CATEGORIES_CACHE,
        jsonEncode(cats.map((e) => e.toJson()).toList()),
      );
      pref.saveValue(
        _categoriesCacheTimeKey,
        DateTime.now().millisecondsSinceEpoch.toString(),
      );
    });
  }

  Future<void> loadPromotions() async {
    final res = await repository.getPromotions(loungeId: null);
    res.fold((_) => update(state.copyWith(isPromosLoading: false)), (promos) {
      update(state.copyWith(promotions: promos, isPromosLoading: false));
      if (promos.isNotEmpty) {
        pref.saveValue(
          CachingKey.PROMOTIONS_CACHE,
          jsonEncode(promos.map((e) => e.toJson()).toList()),
        );
      }
    });
  }

  Future<void> loadPoints(String? userId) async {
    if (userId == null || userId.isEmpty) return;
    final res = await repository.getUserPoints(userId);
    res.fold((_) {}, (p) => update(state.copyWith(pointsBalance: p)));
  }

  void loadCached() {
    final cachedPromos = pref.getValue(CachingKey.PROMOTIONS_CACHE);
    final cachedCats = pref.getValue(CachingKey.CATEGORIES_CACHE);
    final cachedLounges = pref.getValue(CachingKey.CACHED_LOUNGES);

    if (cachedPromos.isNotEmpty ||
        cachedCats.isNotEmpty ||
        cachedLounges.isNotEmpty) {
      try {
        final List<PromoModel> promos = cachedPromos.isNotEmpty
            ? (jsonDecode(cachedPromos) as List)
                  .map((e) => PromoModel.fromJson(e))
                  .toList()
            : <PromoModel>[];
        final List<CategoryModel> cats = cachedCats.isNotEmpty
            ? (jsonDecode(cachedCats) as List)
                  .map((e) => CategoryModel.fromJson(e))
                  .toList()
            : <CategoryModel>[];
        final List<LoungeModel> lounges = cachedLounges.isNotEmpty
            ? (jsonDecode(cachedLounges) as List)
                  .map((e) => LoungeModel.fromJson(e))
                  .toList()
            : <LoungeModel>[];

        update(
          state.copyWith(
            promotions: promos,
            categories: cats,
            nearestLounges: lounges,
            topRatedLounges: List<LoungeModel>.from(lounges)
              ..sort((a, b) => b.rating.compareTo(a.rating)),
          ),
        );
      } catch (e) {
        AppLogger.debug("CACHE_LOAD_ERROR: $e");
      }
    }
  }
}
