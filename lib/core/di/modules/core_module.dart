import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../cache/preference_manager.dart';
import '../../datasources/local/app_cache_local_data_source.dart';
import '../../services/supabase_storage_service.dart';
import '../../services/social_auth_service.dart';
import '../../services/location_service.dart';
import '../../../art_core/presentation/locale_cubit.dart';

final sl = GetIt.instance;

Future<void> initCoreModule() async {
  // Cache
  await PreferenceManager.init();
  sl.registerLazySingleton(() => PreferenceManager());
  sl.registerLazySingleton<AppCacheLocalDataSource>(
    () => AppCacheLocalDataSourceImpl(),
  );

  // Locale Cubit
  sl.registerLazySingleton(() => LocaleCubit());

  // Supabase
  sl.registerLazySingleton<SupabaseClient>(
    () => Supabase.instance.client,
  );

  // Services
  sl.registerLazySingleton<StorageService>(
    () => SupabaseStorageServiceImpl(sl()),
  );
  sl.registerLazySingleton<SocialAuthService>(
    () => SocialAuthServiceImpl(),
  );
  sl.registerLazySingleton<LocationService>(
    () => LocationServiceImpl(),
  );
}
