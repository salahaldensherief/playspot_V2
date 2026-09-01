import 'package:get_it/get_it.dart';
import '../../../features/lounge_details/data/datasources/remote/lounge_details_remote_data_source.dart';
import '../../../features/lounge_details/domain/repositories/lounge_details_repository.dart';
import '../../../features/lounge_details/data/repositories/lounge_details_repository_impl.dart';
import '../../../features/lounge_details/presentation/lounge_details/lounge_details_cubit.dart';

final sl = GetIt.instance;

void initLoungeModule() {
  sl.registerLazySingleton<LoungeDetailsRemoteDataSource>(
    () => LoungeDetailsRemoteDataSourceImpl(sl()),
  );

  sl.registerLazySingleton<LoungeDetailsRepository>(
    () => LoungeDetailsRepositoryImpl(sl()),
  );

  sl.registerFactory<LoungeDetailsCubit>(
    () => LoungeDetailsCubit(sl(), sl(), sl()),
  );
}
