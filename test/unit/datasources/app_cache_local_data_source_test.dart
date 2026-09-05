import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';
import 'package:playspot/core/datasources/local/app_cache_local_data_source.dart';
import 'package:playspot/features/home/data/models/lounge_model.dart';
import 'package:playspot/features/home/data/models/category_model.dart';
import 'package:playspot/features/lounge_details/data/models/extra_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
    return '.';
  });

  late AppCacheLocalDataSource localDataSource;

  setUp(() async {
    await GetStorage.init('test_cache_box');
    final box = GetStorage('test_cache_box');
    try {
      await box.erase();
    } catch (_) {}
    localDataSource = AppCacheLocalDataSourceImpl(box);
  });

  group('AppCacheLocalDataSource Cache-First & Invalidation Tests', () {
    const testLounge = LoungeModel(
      id: 'lounge_123',
      name: 'Test Lounge',
      imageUrl: 'http://test.com/image.png',
      rating: 4.8,
      distance: 2.5,
      pricePerHour: 150.0,
      isOpen: true,
      opensAt: '10:00',
      closesAt: '02:00',
    );

    const testExtra = ExtraModel(
      id: 'extra_1',
      name: 'Coffee',
      price: 30.0,
      category: 'Drinks',
    );

    const testCategory = CategoryModel(
      id: 'cat_1',
      nameAr: 'بلايستيشن',
      nameEn: 'PlayStation',
      iconKey: 'videogame_asset',
    );

    test('caches and retrieves Lounge Profile correctly', () async {
      expect(localDataSource.getCachedLoungeProfile('lounge_123'), null);

      await localDataSource.cacheLoungeProfile('lounge_123', testLounge);

      final cached = localDataSource.getCachedLoungeProfile('lounge_123');
      expect(cached, isNotNull);
      expect(cached?.id, 'lounge_123');
      expect(cached?.name, 'Test Lounge');
      expect(cached?.rating, 4.8);
    });

    test('invalidates Lounge Profile on mutation', () async {
      await localDataSource.cacheLoungeProfile('lounge_123', testLounge);
      expect(localDataSource.getCachedLoungeProfile('lounge_123'), isNotNull);

      await localDataSource.invalidateLoungeProfile('lounge_123');
      expect(localDataSource.getCachedLoungeProfile('lounge_123'), null);
    });

    test('caches and retrieves Lounge Menu / Extras correctly', () async {
      expect(localDataSource.getCachedLoungeMenu('lounge_123'), null);

      await localDataSource.cacheLoungeMenu('lounge_123', [testExtra]);

      final cachedMenu = localDataSource.getCachedLoungeMenu('lounge_123');
      expect(cachedMenu, isNotNull);
      expect(cachedMenu?.length, 1);
      expect(cachedMenu?.first.name, 'Coffee');
      expect(cachedMenu?.first.price, 30.0);
    });

    test('caches and retrieves Categories correctly', () async {
      await localDataSource.cacheCategories([testCategory]);

      final cachedCats = localDataSource.getCachedCategories();
      expect(cachedCats, isNotNull);
      expect(cachedCats?.length, 1);
      expect(cachedCats?.first.nameEn, 'PlayStation');
    });

    test('clearAllCache removes all cached entity data on logout', () async {
      await localDataSource.cacheLoungeProfile('lounge_123', testLounge);
      await localDataSource.cacheLoungeMenu('lounge_123', [testExtra]);
      await localDataSource.cacheCategories([testCategory]);

      expect(localDataSource.getCachedLoungeProfile('lounge_123'), isNotNull);
      expect(localDataSource.getCachedLoungeMenu('lounge_123'), isNotNull);
      expect(localDataSource.getCachedCategories(), isNotNull);

      await localDataSource.clearAllCache();

      expect(localDataSource.getCachedLoungeProfile('lounge_123'), null);
      expect(localDataSource.getCachedLoungeMenu('lounge_123'), null);
      expect(localDataSource.getCachedCategories(), null);
    });
  });
}
