import 'package:get_it/get_it.dart';
import '../../../features/home/data/data_source/remote/home_remote_data_source.dart';
import '../../../features/home/data/repos/home_repos.dart';
import '../../../features/home/presentation/home_cubit.dart';

final sl = GetIt.instance;

void initHomeModule() {
  sl.registerLazySingleton<HomeRemoteDataSource>(
    () => HomeRemoteDataSourceImpl(sl()),
  );

  sl.registerLazySingleton<HomeRepository>(
    () => HomeRepositoryImpl(sl()),
  );

  sl.registerFactory<HomeCubit>(
    () => HomeCubit(sl(), sl()),
  );
}
