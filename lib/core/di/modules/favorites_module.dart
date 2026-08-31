import 'package:get_it/get_it.dart';
import '../../../features/favorites/data/datasources/remote/favorites_remote_data_source.dart';
import '../../../features/favorites/domain/repositories/favorites_repository.dart';
import '../../../features/favorites/data/repositories/favorites_repository_impl.dart';
import '../../../features/favorites/presentation/favorites_cubit.dart';

final sl = GetIt.instance;

void initFavoritesModule() {
  sl.registerLazySingleton<FavoritesRemoteDataSource>(
    () => FavoritesRemoteDataSourceImpl(sl()),
  );

  sl.registerLazySingleton<FavoritesRepository>(
    () => FavoritesRepositoryImpl(sl()),
  );

  sl.registerLazySingleton<FavoritesCubit>(
    () => FavoritesCubit(sl()),
  );
}
