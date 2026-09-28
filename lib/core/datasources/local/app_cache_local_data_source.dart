import 'package:get_storage/get_storage.dart';
import '../../cache/caching_key.dart';
import '../../../features/home/data/models/lounge_model.dart';
import '../../../features/home/data/models/category_model.dart';
import '../../../features/home/data/models/promo_model.dart';
import '../../../features/lounge_details/data/models/room_model.dart';
import '../../../features/lounge_details/data/models/extra_model.dart';

abstract class AppCacheLocalDataSource {
  // Lounge Profile Cache
  Future<void> cacheLoungeProfile(String loungeId, LoungeModel lounge);
  LoungeModel? getCachedLoungeProfile(String loungeId);
  Future<void> invalidateLoungeProfile(String loungeId);

  // Lounge Rooms Cache
  Future<void> cacheLoungeRooms(String loungeId, List<RoomModel> rooms);
  List<RoomModel>? getCachedLoungeRooms(String loungeId);
  Future<void> invalidateLoungeRooms(String loungeId);

  // Lounge Extras / Menu Cache
  Future<void> cacheLoungeMenu(String loungeId, List<ExtraModel> extras);
  List<ExtraModel>? getCachedLoungeMenu(String loungeId);
  Future<void> invalidateLoungeMenu(String loungeId);

  // Categories Cache
  Future<void> cacheCategories(List<CategoryModel> categories);
  List<CategoryModel>? getCachedCategories();
  Future<void> invalidateCategories();

  // Promotions Cache
  Future<void> cachePromotions(List<PromoModel> promotions);
  List<PromoModel>? getCachedPromotions();
  Future<void> invalidatePromotions();

  // Clear all cache on Logout
  Future<void> clearAllCache();
}

class AppCacheLocalDataSourceImpl implements AppCacheLocalDataSource {
  final GetStorage _box;

  AppCacheLocalDataSourceImpl([GetStorage? box]) : _box = box ?? GetStorage();

  String _loungeKey(String id) => '${CachingKey.LOUNGE_PROFILES_PREFIX}$id';
  String _roomsKey(String id) => '${CachingKey.LOUNGE_ROOMS_PREFIX}$id';
  String _extrasKey(String id) => '${CachingKey.LOUNGE_EXTRAS_PREFIX}$id';

  @override
  Future<void> cacheLoungeProfile(String loungeId, LoungeModel lounge) async {
    await _box.write(_loungeKey(loungeId), lounge.toJson());
  }

  @override
  LoungeModel? getCachedLoungeProfile(String loungeId) {
    final raw = _box.read(_loungeKey(loungeId));
    if (raw == null) return null;
    try {
      return LoungeModel.fromJson(Map<String, dynamic>.from(raw));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> invalidateLoungeProfile(String loungeId) async {
    await _box.remove(_loungeKey(loungeId));
  }

  @override
  Future<void> cacheLoungeRooms(String loungeId, List<RoomModel> rooms) async {
    final jsonList = rooms.map((r) => r.toJson()).toList();
    await _box.write(_roomsKey(loungeId), jsonList);
  }

  @override
  List<RoomModel>? getCachedLoungeRooms(String loungeId) {
    final rawList = _box.read(_roomsKey(loungeId));
    if (rawList == null || rawList is! List) return null;
    try {
      return rawList
          .map((e) => RoomModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> invalidateLoungeRooms(String loungeId) async {
    await _box.remove(_roomsKey(loungeId));
  }

  @override
  Future<void> cacheLoungeMenu(String loungeId, List<ExtraModel> extras) async {
    final jsonList = extras.map((e) => e.toJson()).toList();
    await _box.write(_extrasKey(loungeId), jsonList);
  }

  @override
  List<ExtraModel>? getCachedLoungeMenu(String loungeId) {
    final rawList = _box.read(_extrasKey(loungeId));
    if (rawList == null || rawList is! List) return null;
    try {
      return rawList
          .map((e) => ExtraModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> invalidateLoungeMenu(String loungeId) async {
    await _box.remove(_extrasKey(loungeId));
  }

  @override
  Future<void> cacheCategories(List<CategoryModel> categories) async {
    final jsonList = categories.map((c) => c.toJson()).toList();
    await _box.write(CachingKey.CATEGORIES_CACHE, jsonList);
  }

  @override
  List<CategoryModel>? getCachedCategories() {
    final rawList = _box.read(CachingKey.CATEGORIES_CACHE);
    if (rawList == null || rawList is! List) return null;
    try {
      return rawList
          .map((e) => CategoryModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> invalidateCategories() async {
    await _box.remove(CachingKey.CATEGORIES_CACHE);
  }

  @override
  Future<void> cachePromotions(List<PromoModel> promotions) async {
    final jsonList = promotions.map((p) => p.toJson()).toList();
    await _box.write(CachingKey.PROMOTIONS_CACHE, jsonList);
  }

  @override
  List<PromoModel>? getCachedPromotions() {
    final rawList = _box.read(CachingKey.PROMOTIONS_CACHE);
    if (rawList == null || rawList is! List) return null;
    try {
      return rawList
          .map((e) => PromoModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> invalidatePromotions() async {
    await _box.remove(CachingKey.PROMOTIONS_CACHE);
  }

  @override
  Future<void> clearAllCache() async {
    final keys = _box.getKeys<Iterable<String>>();
    final keysToRemove = keys.where((k) =>
        k.startsWith(CachingKey.LOUNGE_PROFILES_PREFIX) ||
        k.startsWith(CachingKey.LOUNGE_ROOMS_PREFIX) ||
        k.startsWith(CachingKey.LOUNGE_EXTRAS_PREFIX) ||
        k == CachingKey.CATEGORIES_CACHE ||
        k == CachingKey.PROMOTIONS_CACHE).toList();

    for (final key in keysToRemove) {
      await _box.remove(key);
    }
  }
}
