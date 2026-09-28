import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../features/app_status/data/datasources/remote/app_status_remote_data_source.dart';
import '../../../features/app_status/data/repositories/app_status_repository_impl.dart';
import '../../../features/app_status/domain/repositories/app_status_repository.dart';
import '../../../features/app_status/domain/usecases/check_app_status_usecase.dart';
import '../../../features/app_status/domain/usecases/stream_app_status_usecase.dart';
import '../../../features/app_status/presentation/cubit/app_status_cubit.dart';
import '../../di.dart';

void initAppStatusModule() {
  // Data Source
  sl.registerLazySingleton<AppStatusRemoteDataSource>(
    () => AppStatusRemoteDataSourceImpl(sl<SupabaseClient>()),
  );

  // Repository
  sl.registerLazySingleton<AppStatusRepository>(
    () => AppStatusRepositoryImpl(sl<AppStatusRemoteDataSource>()),
  );

  // UseCases
  sl.registerLazySingleton(() => CheckAppStatusUseCase(sl<AppStatusRepository>()));
  sl.registerLazySingleton(() => StreamAppStatusUseCase(sl<AppStatusRepository>()));

  // Cubit (LazySingleton so app status can be observed globally)
  sl.registerLazySingleton(
    () => AppStatusCubit(
      checkAppStatusUseCase: sl<CheckAppStatusUseCase>(),
      streamAppStatusUseCase: sl<StreamAppStatusUseCase>(),
    ),
  );
}
