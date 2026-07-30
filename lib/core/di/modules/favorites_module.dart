import 'package:get_it/get_it.dart';
import '../../../features/favorites/data/data_source/remote/favorites_remote_data_source.dart';
import '../../../features/favorites/data/repos/favorites_repo.dart';
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
