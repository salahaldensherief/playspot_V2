import 'package:get_it/get_it.dart';
import '../../../features/lounge_details/data/data_source/remote/lounge_details_remote_data_source.dart';
import '../../../features/lounge_details/data/repos/lounge_details_repo.dart';
import '../../../features/lounge_details/presentation/lounge_details_cubit.dart';

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
