import 'package:get_it/get_it.dart';
import '../../../features/home/data/datasources/remote/home_remote_data_source.dart';
import '../../../features/home/domain/repositories/home_repository.dart';
import '../../../features/home/data/repositories/home_repository_impl.dart';
import '../../../features/home/presentation/home_cubit.dart';
import '../../../features/home/domain/usecases/discover_lounges_usecase.dart';
import '../../../features/home/domain/usecases/recalculate_lounge_distances_usecase.dart';

final sl = GetIt.instance;

void initHomeModule() {
  sl.registerLazySingleton<HomeRemoteDataSource>(
    () => HomeRemoteDataSourceImpl(sl()),
  );

  sl.registerLazySingleton<HomeRepository>(
    () => HomeRepositoryImpl(sl(), sl()),
  );

  sl.registerLazySingleton(() => DiscoverLoungesUseCase(sl<HomeRepository>()));

  sl.registerFactory<HomeCubit>(
    () => HomeCubit(
      sl(),
      sl(),
      sl(),
      sl(),
      sl(),
      preferenceManager: sl(),
      discover: sl(),
      recalculate: sl(),
    ),
  );
  sl.registerLazySingleton<RecalculateLoungeDistancesUseCase>(
    () => const RecalculateLoungeDistancesUseCase(),
  );
}
